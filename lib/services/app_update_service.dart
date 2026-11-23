import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:convert/convert.dart' show AccumulatorSink;
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import '../design/neon_widgets.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/log.dart';
import '../design/motion.dart';
import '../design/neon_tokens.dart';
import '../models/remote_config.dart';
import 'api_service.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  SELF-UPDATE — the app is its own distribution channel while it is
///  sideloaded. On launch it asks the backend for the newest published
///  build; if that is newer than what's running, it downloads the APK,
///  verifies its sha256, and hands it to Android's installer.
///
///  QUIETLY (owner, 2026-11-23: "update silently without the user
///  knowing"): an automatic check downloads on Wi-Fi with nothing on
///  screen and installs once the app has been in the background for
///  [_quietFor]; Android 12+ replaces the app with no prompt and it opens
///  as the new version next time. The sheet below is only for a phone that
///  cannot update quietly (Android 11 or older, or one where Android asked
///  for a confirmation), a forced update, or "update the app" by voice.
///
///  Server side: POST /admin/apk publishes; GET /config advertises
///  latestVersionCode + apkUrl + apkSha256; GET /app/latest.apk serves.
/// ─────────────────────────────────────────────────────────────────────────
class AppUpdateService {
  /// SELF-UPDATE IS ON, QUIETLY (owner, 2026-11-23). It was off from
  /// 2026-11-03 ("turn off auto update features completely"); false turns
  /// the whole flow off again — no check, download or install anywhere.
  static const bool enabled = true;

  /// How an available update is taken. The sheet whenever the user asked,
  /// the update is forced, or this phone cannot install without a prompt;
  /// otherwise quietly — but never a ~70 MB download on mobile data.
  @visibleForTesting
  static UpdatePath choosePath({
    required bool userAsked,
    required bool forced,
    required bool silentPossible,
    required bool metered,
  }) {
    if (userAsked || forced || !silentPossible) return UpdatePath.sheet;
    return metered ? UpdatePath.waitForWifi : UpdatePath.quiet;
  }

  /// Set per check(): the sheet starts the update on its own. Only ever
  /// true on a connection the user is not paying for by the megabyte —
  /// a ~200 MB download that begins without being asked is not a feature
  /// on mobile data.
  static bool _autoStart = false;
  static bool get autoStart => _autoStart;
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();

  int _lastCheckMs = 0;
  bool _sheetShowing = false;

  /// The in-flight download, so closing the sheet actually stops it.
  /// Without this, "Later" popped the sheet and left the request running:
  /// bytes kept arriving, the file kept growing, and the install fired
  /// anyway on a build the user had just declined.
  http.Client? _client;
  bool _cancelled = false;

  /// Once the installer has the file, closing the sheet must NOT snooze
  /// or cancel — Android is already replacing the app.
  bool _installStarted = false;

  /// "LATER" LASTS UNTIL THE NEXT OPEN (owner, 2026-11-01: "the in-app
  /// update should pop up every time the user opens the app if he is on an
  /// old version"). It used to be a 12-hour snooze saved on the phone. Now
  /// it is held in memory only: a restart forgets it, and so does coming
  /// back after at least [_awayResets] in the background. A quick return
  /// (the camera, a permission dialog) does not bring the sheet back.
  final Map<int, int> _snoozes = {};
  static const _awayResets = Duration(minutes: 1);
  DateTime? _backgroundedAt;
  bool _watching = false;

  void _watchLifecycle() {
    if (_watching) return;
    _watching = true;
    WidgetsBinding.instance.addObserver(_UpdateLifecycle(this));
  }

  void _onLifecycle(AppLifecycleState s, {DateTime? now}) {
    final t = now ?? DateTime.now();
    if (s == AppLifecycleState.paused || s == AppLifecycleState.hidden) {
      _backgroundedAt ??= t;
      // A quietly downloaded build installs once the app has been left.
      if (_readyApk != null && _installTimer == null) _scheduleInstall();
    } else if (s == AppLifecycleState.resumed) {
      // Back in use before the quiet wait ran out: never replace the app
      // under the user. The next time it is left, the wait starts again.
      _installTimer?.cancel();
      _installTimer = null;
      final away = _backgroundedAt;
      _backgroundedAt = null;
      if (away != null && t.difference(away) >= _awayResets && _snoozes.isNotEmpty) {
        _snoozes.clear();
        _lastCheckMs = 0; // the sheet may come straight back
        AppLog.add('update', 'opened again: "Later" forgotten');
      }
    }
  }

  /// Test seam: a quietly downloaded build, ready to install.
  @visibleForTesting
  void debugQuietReady(File apk, int versionCode) {
    _readyApk = apk;
    _readyVersion = versionCode;
    _quietTried.remove(versionCode);
    _watchLifecycle();
  }

  /// Test seam: a lifecycle change at [now].
  @visibleForTesting
  void debugLifecycle(AppLifecycleState s, DateTime now) => _onLifecycle(s, now: now);

  Future<void> snooze(int versionCode) async {
    _watchLifecycle();
    _snoozes[versionCode] = DateTime.now().millisecondsSinceEpoch;
    AppLog.add('update', 'build $versionCode: later (until the app is opened again)');
  }

  /// Forget a snooze — the user asked for this update by name.
  Future<void> _unsnooze(int versionCode) async {
    if (_snoozes.remove(versionCode) != null) {
      AppLog.add('update', 'build $versionCode un-snoozed (asked for)');
    }
  }

  @visibleForTesting
  Future<bool> debugSnoozed(int versionCode) => _snoozed(versionCode);

  Future<bool> _snoozed(int versionCode) async => _snoozes.containsKey(versionCode);

  // ── QUIET UPDATES ───────────────────────────────────────────────────
  /// The app must have been in the background this long before a quietly
  /// downloaded build replaces it: a camera, a permission page or a quick
  /// switch to another app is not "left".
  static const _quietFor = Duration(minutes: 3);
  bool _quietRunning = false;
  File? _readyApk;
  int _readyVersion = 0;
  Timer? _installTimer;

  /// One quiet install attempt per build per run: a failure is retried
  /// after the next launch, never in a loop while the app sits in the
  /// background.
  final Set<int> _quietTried = {};

  /// Can this phone install an update with no prompt at all? Android 12+,
  /// unless a quiet attempt from this very build turned into a
  /// confirmation request (ApkInstaller records that).
  Future<bool> _silentPossible() async {
    try {
      return await const MethodChannel('hari/updater')
              .invokeMethod<bool>('silentPossible') ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _quietUpdate(RemoteConfig cfg) async {
    final v = cfg.latestVersionCode;
    if (_quietRunning || _quietTried.contains(v) || _readyVersion == v) return;
    _quietRunning = true;
    try {
      final file = await _download(cfg, onProgress: (_) {});
      _readyApk = file;
      _readyVersion = v;
      AppLog.add('update',
          'build $v downloaded quietly; it installs once the app is left');
      _watchLifecycle();
      final state = WidgetsBinding.instance.lifecycleState;
      if (state != null && state != AppLifecycleState.resumed) {
        _backgroundedAt ??= DateTime.now();
        _scheduleInstall();
      }
    } catch (e) {
      AppLog.add('update', 'quiet download of build $v failed: $e');
    } finally {
      _quietRunning = false;
    }
  }

  void _scheduleInstall() {
    _installTimer?.cancel();
    _installTimer = Timer(_quietFor, () {
      _installTimer = null;
      unawaited(_installQuietly());
    });
  }

  Future<void> _installQuietly() async {
    final file = _readyApk;
    final v = _readyVersion;
    if (file == null || _quietTried.contains(v)) return;
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      return; // in use again — wait for the next time it is left
    }
    _quietTried.add(v);
    _readyApk = null;
    AppLog.add('update', 'installing build $v quietly');
    try {
      await const MethodChannel('hari/updater')
          .invokeMethod<bool>('install', {'path': file.path, 'silent': true});
    } catch (e) {
      AppLog.add('update', 'quiet install of build $v failed: $e');
    }
  }

  /// True when the active connection is metered (mobile data, a metered
  /// hotspot) — or when we cannot tell. Guessing "unmetered" spends the
  /// user's data; guessing "metered" costs one tap.
  Future<bool> _metered() async {
    try {
      final m = await const MethodChannel('hari/updater')
          .invokeMethod<bool>('isMetered');
      return m ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Stop an in-flight download and remove the partial file.
  Future<void> cancelDownload() async {
    _cancelled = true;
    try {
      _client?.close();
    } catch (_) {}
    _client = null;
  }

  /// Delete APKs left behind by earlier updates. The install replaces the
  /// process, so nothing ever ran after a successful one — a tester who
  /// took ten builds was carrying ten ~200 MB files in the cache
  /// directory and seeing the app listed as multi-gigabyte.
  Future<void> _sweepOldApks({int? keepVersionCode}) async {
    try {
      final dir = await getTemporaryDirectory();
      for (final f in dir.listSync()) {
        if (f is! File) continue;
        final name = f.path.split('/').last;
        if (!name.startsWith('update-') || !name.endsWith('.apk')) continue;
        if (keepVersionCode != null && name == 'update-$keepVersionCode.apk') {
          continue;
        }
        try {
          await f.delete();
          AppLog.add('update', 'removed stale $name');
        } catch (_) {}
      }
    } catch (_) {}
  }

  /// Compare the running build number with the newest published one and
  /// offer the update. Called on launch AND whenever the app returns to
  /// the foreground — a phone that keeps the app in memory for days used
  /// to never see new releases. Throttled to once per 30 minutes; silent
  /// on any failure — a check must never get in the way of using the app.
  ///
  /// [force] skips the throttle (a push, or the user asking). [userAsked]
  /// means the user asked for the update by voice: that one always shows
  /// the sheet, so they can see it happen.
  Future<bool> check(BuildContext context,
      {bool force = false, bool userAsked = false}) async {
    if (!enabled || !Platform.isAndroid) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_sheetShowing) return false;
    // Short throttle: back-to-back releases used to hide behind a 30-min
    // window, so a resumed app missed the newer one until a full restart.
    if (!force && now - _lastCheckMs < 2 * 60 * 1000) return false;
    _lastCheckMs = now;
    try {
      final r = await http
          .get(Uri.parse('${ApiService.baseUrl}/config'))
          .timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return false;
      final cfg =
          RemoteConfig.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
      if (cfg.apkUrl == null || cfg.apkUrl!.isEmpty) return false;

      final info = await PackageInfo.fromPlatform();
      final current = int.tryParse(info.buildNumber) ?? 0;
      AppLog.add('update',
          'running build $current, published ${cfg.latestVersionCode}');
      if (cfg.latestVersionCode <= current) {
        // ALREADY UP TO DATE — which is exactly when the APK that got us
        // here is still sitting in the cache. The install replaces the
        // process, so nothing ever ran after it to clean up, and a tester
        // who took ten builds was carrying ten ~200 MB files.
        unawaited(_sweepOldApks());
        return false;
      }

      // Anything left over from a build that already installed, or that
      // was abandoned, goes now — before another ~200 MB lands next to it.
      unawaited(_sweepOldApks(keepVersionCode: cfg.latestVersionCode));

      // A SNOOZE MUST NEVER OUTLAST AN EXPLICIT REQUEST.
      //
      // `force` used to bypass only the two-minute throttle, so dismissing
      // the sheet once left the user permanently unable to update: every
      // later "update the app" returned silently here while the assistant
      // said "the new version is ready — opening the installer". Found on
      // a real phone (2026-09-20) stuck four builds behind, having asked
      // five times in a row.
      //
      // Snoozing means "stop nagging me", not "never let me ask again".
      final forced = cfg.forceUpdateBelow > current;
      final metered = await _metered();
      switch (choosePath(
        userAsked: userAsked,
        forced: forced,
        silentPossible: await _silentPossible(),
        metered: metered,
      )) {
        case UpdatePath.waitForWifi:
          AppLog.add('update',
              'build ${cfg.latestVersionCode} waits for Wi-Fi (quiet update)');
          return false;
        case UpdatePath.quiet:
          unawaited(_quietUpdate(cfg));
          return false;
        case UpdatePath.sheet:
          break;
      }
      if (force) {
        await _unsnooze(cfg.latestVersionCode);
      } else if (!forced && await _snoozed(cfg.latestVersionCode)) {
        AppLog.add('update', 'build ${cfg.latestVersionCode} is snoozed');
        return false;
      }
      // HANDS-FREE, BUT NOT ON SOMEONE'S DATA PLAN. On Wi-Fi the sheet
      // still starts on its own — that is the zero-effort path. On mobile
      // data it waits for a tap and says how big the download is.
      // Asked BEFORE the last mounted check so the sheet is never built
      // against a context that went away while we were asking.
      final unmetered = !metered;
      if (!context.mounted) return false;

      _sheetShowing = true;
      _cancelled = false;
      _installStarted = false;
      _autoStart = forced || unmetered;
      await showAppSheet<void>(
        context: context,
        // WITHOUT THIS THE SHEET IS CAPPED AT 56% OF THE SCREEN and
        // anything past that edge is simply clipped — which is how a
        // six-line changelog hid the "Update now" button completely. The
        // sheet now sizes to its content, bounded below.
        isScrollControlled: true,
        isDismissible: !forced,
        enableDrag: !forced,
        backgroundColor: Neon.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => _UpdateSheet(config: cfg, forced: forced),
      );
      // Swiping the sheet away used to pop the UI and leave the request
      // running. Whatever closed it, the download stops here.
      if (!_installStarted) {
        await cancelDownload();
        // Only an UNASKED-FOR sheet earns a snooze. Re-snoozing one the
        // user opened themselves is what created the trap above.
        if (!forced && !force) await snooze(cfg.latestVersionCode);
      }
      _sheetShowing = false;
      return true;
    } catch (e) {
      AppLog.add('update', 'check failed: $e');
      return false;
    }
  }

  /// Streams the APK to the cache dir, verifies the hash, opens the
  /// installer. Progress 0..1 via [onProgress]. Throws on any failure.
  Future<void> downloadAndInstall(
    RemoteConfig cfg, {
    required void Function(double) onProgress,
    void Function()? onInstalling,
  }) async {
    final file = await _download(cfg, onProgress: onProgress);
    if (_cancelled) {
      throw const _UpdateCancelled();
    }
    AppLog.add('update',
        'downloaded build ${cfg.latestVersionCode}, opening installer');
    // Android gates "install unknown apps" PER APP, once. Ask up front:
    // this opens the exact settings page, waits for the user to come
    // back, and then continues into the installer — instead of the
    // installer bouncing them to Settings and losing the flow.
    // Android 8+ gates installs per-app; BELOW API 26 that permission
    // does not exist (unknown-sources is one global toggle) and the
    // permission plugin reports it permanently denied — the old check
    // looped "allow … then Try again" forever on Android 7 phones.
    final sdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
    if (sdk >= 26 && !await Permission.requestInstallPackages.isGranted) {
      AppLog.add('update', 'asking for install permission');
      final granted = await Permission.requestInstallPackages.request();
      if (!granted.isGranted) {
        throw Exception(
            'allow "Install unknown apps" for this app on the settings '
            'page, then return and tap Retry');
      }
    }
    // HANDS-FREE INSTALL. A PackageInstaller session with
    // USER_ACTION_NOT_REQUIRED updates silently on Android 12+ once this
    // app is its own installer of record — which the first such install
    // establishes (that one shows the system's single confirmation).
    // From then on, updates apply themselves; the app simply restarts
    // as the new version.
    AppLog.add('update', 'committing install session');
    _installStarted = true;
    onInstalling?.call();
    final started = await const MethodChannel('hari/updater')
        .invokeMethod<bool>('install', {'path': file.path, 'silent': false});
    if (started != true) {
      // Session refused (odd OEM) — fall back to the tap-through installer.
      final result = await OpenFilex.open(
        file.path,
        type: 'application/vnd.android.package-archive',
      );
      if (result.type != ResultType.done) {
        throw Exception('installer: ${result.message}');
      }
    }
  }

  /// One download per build at a time: the quiet path and the sheet share
  /// it, so two never write the same file.
  Future<File>? _inflight;
  int _inflightVersion = 0;

  /// The verified APK for [cfg]: the file already in the cache when it is
  /// intact (downloaded quietly, or before the app was closed), otherwise
  /// streamed with progress 0..1 and checked against apkSha256.
  Future<File> _download(RemoteConfig cfg,
      {required void Function(double) onProgress}) {
    final running = _inflight;
    if (running != null && _inflightVersion == cfg.latestVersionCode) {
      return running;
    }
    _inflightVersion = cfg.latestVersionCode;
    final f = _fetch(cfg, onProgress: onProgress);
    _inflight = f;
    unawaited(f.then<void>((_) {}, onError: (_) {}).whenComplete(() {
      if (identical(_inflight, f)) _inflight = null;
    }));
    return f;
  }

  Future<File> _fetch(RemoteConfig cfg,
      {required void Function(double) onProgress}) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/update-${cfg.latestVersionCode}.apk');
    await _sweepOldApks(keepVersionCode: cfg.latestVersionCode);
    // REQUIRED, not optional: with no published checksum the file would
    // be installed unverified. The server computes apkSha256 on every
    // publish (routes/appUpdate.js), so its absence means something is
    // wrong — and nothing is downloaded for it.
    final want = cfg.apkSha256?.trim().toLowerCase() ?? '';
    if (want.isEmpty) {
      throw Exception(
          'no checksum was published for this update, so it was not installed');
    }
    if (await file.exists()) {
      try {
        if ((await sha256.bind(file.openRead()).first).toString() == want) {
          onProgress(1);
          return file;
        }
      } catch (_) {}
      await _safeDelete(file);
    }
    _cancelled = false;
    final client = http.Client();
    _client = client;
    try {
      final req = http.Request('GET', Uri.parse(cfg.apkUrl!));
      final res = await client.send(req).timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) throw Exception('download ${res.statusCode}');
      final total = res.contentLength ?? 0;
      var got = 0;
      final sink = file.openWrite();
      final digest = AccumulatorSink<Digest>();
      final hasher = sha256.startChunkedConversion(digest);
      await for (final chunk in res.stream) {
        if (_cancelled) {
          await sink.close();
          await _safeDelete(file);
          throw const _UpdateCancelled();
        }
        sink.add(chunk);
        hasher.add(chunk);
        got += chunk.length;
        if (total > 0) onProgress(got / total);
      }
      await sink.close();
      hasher.close();
      final hash = digest.events.single.toString();
      if (hash.toLowerCase() != want) {
        await _safeDelete(file);
        throw Exception('the download was corrupted (checksum mismatch)');
      }
      if (_cancelled) {
        await _safeDelete(file);
        throw const _UpdateCancelled();
      }
      onProgress(1);
      return file;
    } finally {
      client.close();
      if (identical(_client, client)) _client = null;
    }
  }

  static Future<void> _safeDelete(File f) async {
    try {
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}

/// The user closed the sheet or tapped Cancel — not a failure, and not
/// something to show them an error about.
class _UpdateCancelled implements Exception {
  const _UpdateCancelled();
  @override
  String toString() => 'cancelled';
}

class _UpdateSheet extends StatefulWidget {
  final RemoteConfig config;
  final bool forced;
  const _UpdateSheet({required this.config, required this.forced});

  @override
  State<_UpdateSheet> createState() => _UpdateSheetState();
}

class _UpdateSheetState extends State<_UpdateSheet> {
  double? _progress; // null = not started
  String? _error;
  // The install itself is silent and takes a while: Android replaces the
  // app, the screen drops to the launcher and the app reopens by itself.
  // Without a visible "installing" state that looked like a crash.
  bool _installing = false;

  @override
  void initState() {
    super.initState();
    // Zero-effort updates: the download starts the moment the sheet
    // appears — no button hunting. The sheet stays as a progress surface.
    if (AppUpdateService.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _progress == null) _update();
      });
    }
  }

  Future<void> _update() async {
    setState(() {
      _progress = 0;
      _error = null;
    });
    try {
      await AppUpdateService.instance.downloadAndInstall(
        widget.config,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
        onInstalling: () {
          if (mounted) setState(() => _installing = true);
        },
      );
      // DO NOT close the sheet. Android is now installing in the
      // background and will restart the app when it finishes; leaving the
      // "Installing…" panel up is what tells the user the screen going
      // dark for a moment is the update, not a crash.
      if (mounted) setState(() => _installing = true);
    } on _UpdateCancelled {
      // The user stopped it. Not an error, and nothing to report.
      if (mounted) {
        setState(() {
          _progress = null;
          _installing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error =
              "Unable to update: ${e.toString().replaceFirst('Exception: ', '')}";
          _progress = null;
          _installing = false;
        });
      }
    }
  }

  Future<void> _cancel() async {
    await AppUpdateService.instance.cancelDownload();
    if (mounted) {
      setState(() {
        _progress = null;
        _installing = false;
      });
    }
  }

  static String _size(int bytes) {
    if (bytes <= 0) return '';
    final mb = bytes / (1024 * 1024);
    return mb >= 1024
        ? '${(mb / 1024).toStringAsFixed(1)} GB'
        : '${mb.toStringAsFixed(0)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final cfg = widget.config;
    final busy = _progress != null;
    return SafeArea(
      child: ConstrainedBox(
        // Never taller than most of the screen; the notes scroll inside it.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.system_update_rounded, color: Neon.cyan, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Update Available: v${cfg.latestVersionName}',
                    style: TextStyle(
                        color: Neon.textHi,
                        fontSize: 17,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ]),
              // THE ONLY PART THAT MAY GROW. The title above and the
              // buttons below are pinned; release notes of any length scroll
              // in here instead of displacing the thing the user opened the
              // sheet to press.
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (cfg.changelog.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        for (final line in cfg.changelog.take(12))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text('•  $line',
                                style: TextStyle(
                                    color: Neon.textLo,
                                    fontSize: 14,
                                    height: 1.35)),
                          ),
                      ],
                      if (widget.forced) ...[
                        const SizedBox(height: 10),
                        Text('This update is required to continue using the app.',
                            style:
                                TextStyle(color: Neon.errorInk, fontSize: 13)),
                      ],
                      if (!busy &&
                          !AppUpdateService.autoStart &&
                          cfg.apkSize > 0) ...[
                        const SizedBox(height: 10),
                        Text(
                          "${_size(cfg.apkSize)} download. You are on mobile data, so "
                          "it will not start until you confirm.",
                          style: TextStyle(
                              color: Neon.textDim,
                              fontSize: 13,
                              height: 1.35),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_installing) ...[
                Row(
                  children: [
                    const NeonLoader.inline(size: 20, semanticLabel: 'Downloading the update'),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Installing the update…',
                        style: TextStyle(
                            color: Neon.textHi,
                            fontSize: 15,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'The app will close and reopen automatically in a moment. '
                  'No data is lost — the update is finishing.',
                  style: TextStyle(
                      color: Neon.textLo, fontSize: 13, height: 1.35),
                ),
              ] else if (busy) ...[
                LinearProgressIndicator(
                  value: _progress == 0 ? null : _progress,
                  color: Neon.violet,
                  backgroundColor: Neon.surfaceHigh,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _progress! >= 1
                            ? 'Verified. Starting installation…'
                            : 'Downloading ${(_progress! * 100).toStringAsFixed(0)}%'
                                '${cfg.apkSize > 0 ? ' of ${_size(cfg.apkSize)}' : ''}',
                        style: TextStyle(color: Neon.textDim, fontSize: 13),
                      ),
                    ),
                    // A download in progress must be stoppable. Closing the
                    // sheet used to leave it running to completion and
                    // install anyway.
                    if (!widget.forced && _progress! < 1)
                      TextButton(
                        onPressed: () async {
                          await _cancel();
                          if (context.mounted) Navigator.of(context).pop();
                        },
                        child: const Text('Cancel'),
                      ),
                  ],
                ),
              ],
              if (_error != null) ...[
                Text(_error!,
                    style: TextStyle(color: Neon.errorInk, fontSize: 13)),
                const SizedBox(height: 10),
              ],
              if (!busy)
                Row(
                  children: [
                    if (!widget.forced)
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Later'),
                      ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: _update,
                      style: FilledButton.styleFrom(
                          backgroundColor: Neon.textHi,
                          foregroundColor: Neon.onInk),
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: Text(_error == null ? 'Update Now' : 'Retry'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpdateLifecycle with WidgetsBindingObserver {
  _UpdateLifecycle(this.service);
  final AppUpdateService service;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => service._onLifecycle(state);
}

/// How an available update is taken (AppUpdateService.choosePath).
enum UpdatePath {
  /// The "Update available" sheet: download with progress, then install.
  sheet,

  /// Downloaded with nothing on screen; installed once the app is left.
  quiet,

  /// Quiet, but on mobile data: nothing until the phone is on Wi-Fi.
  waitForWifi,
}
