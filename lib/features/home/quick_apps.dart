import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:simple_icons/simple_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/log.dart';
import '../../design/motion.dart';
import '../../design/neon_tokens.dart';
import 'quick_app_store.dart';

/// QUICK APPS (2026-11-08): the apps people open most, one tap away on
/// Home — where the "Order and shop" banners used to be. Each opens the
/// installed app; when it is not installed, its Play Store page (App
/// Store on an iPhone, for the apps that name their [iosScheme]).
class QuickApp {
  const QuickApp(this.name, this.pkgs, this.mark, this.color,
      {this.badge, this.iosScheme, this.iosStoreId});

  final String name;

  /// Candidate packages, first installed wins (Gallery differs by maker).
  final List<String> pkgs;
  final IconData mark;
  final Color color;

  /// The app's own icon, drawn, for when it is not installed ([mark] on
  /// white otherwise).
  final Widget Function(double size)? badge;

  /// iPhone: the app's URL scheme ('paypal'), which opens it and tells
  /// whether it is installed. Must also be listed under
  /// LSApplicationQueriesSchemes in ios/Runner/Info.plist.
  final String? iosScheme;

  /// iPhone: its App Store id (apps.apple.com/app/id<this>).
  final String? iosStoreId;
}

bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// Paytm's app icon: light blue over navy, a white circle, the wordmark.
Widget _paytmBadge(double size) => Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF00BAF2),
            Color(0xFF00BAF2),
            Color(0xFF002E6E),
            Color(0xFF002E6E)
          ],
          stops: [0, 0.5, 0.5, 1],
        ),
      ),
      alignment: Alignment.center,
      child: Container(
        width: size * 0.78,
        height: size * 0.78,
        decoration:
            const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Icon(SimpleIcons.paytm,
            color: const Color(0xFF002E6E), size: size * 0.6),
      ),
    );

/// LinkedIn's app icon (no LinkedIn mark ships in simple_icons): "in" in
/// white on LinkedIn blue.
Widget _linkedinBadge(double size) => Container(
      width: size,
      height: size,
      color: const Color(0xFF0A66C2),
      alignment: Alignment.center,
      child: Text('in',
          style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.55,
              fontWeight: FontWeight.w800,
              height: 1,
              letterSpacing: -size * 0.02)),
    );

/// Snapchat's app icon: the black ghost on yellow (its yellow mark would
/// vanish on the white tile).
Widget _snapchatBadge(double size) => Container(
      width: size,
      height: size,
      color: SimpleIconColors.snapchat,
      alignment: Alignment.center,
      child: Icon(SimpleIcons.snapchat, color: Colors.black, size: size * 0.6),
    );

/// PAYMENTS (2026-11-22): the payment apps, in their own Home section
/// above Quick Apps.
const paymentApps = <QuickApp>[
  QuickApp('GPay', ['com.google.android.apps.nbu.paisa.user'],
      SimpleIcons.googlepay, SimpleIconColors.googlepay),
  QuickApp('PhonePe', ['com.phonepe.app'], SimpleIcons.phonepe,
      SimpleIconColors.phonepe),
  QuickApp(
      'Paytm', ['net.one97.paytm'], SimpleIcons.paytm, SimpleIconColors.paytm,
      badge: _paytmBadge),
  QuickApp('PayPal', ['com.paypal.android.p2pmobile'], SimpleIcons.paypal,
      SimpleIconColors.paypal,
      iosScheme: 'paypal', iosStoreId: '283646709'),
];

/// Everything else on Quick Apps.
const otherApps = <QuickApp>[
  QuickApp('Gmail', ['com.google.android.gm'], SimpleIcons.gmail,
      SimpleIconColors.gmail),
  QuickApp('Google', ['com.google.android.googlequicksearchbox'],
      SimpleIcons.google, SimpleIconColors.google),
  QuickApp(
      'Gallery',
      [
        'com.miui.gallery',
        'com.sec.android.gallery3d',
        'com.coloros.gallery3d',
        'com.oneplus.gallery',
        'com.vivo.gallery',
        'com.android.gallery3d',
        'com.google.android.apps.photos',
      ],
      SimpleIcons.googlephotos,
      SimpleIconColors.googlephotos),
  QuickApp('YouTube', ['com.google.android.youtube'], SimpleIcons.youtube,
      SimpleIconColors.youtube),
  QuickApp('Facebook', ['com.facebook.katana'], SimpleIcons.facebook,
      SimpleIconColors.facebook),
  QuickApp('WhatsApp', ['com.whatsapp'], SimpleIcons.whatsapp,
      SimpleIconColors.whatsapp),
  QuickApp('Instagram', ['com.instagram.android'], SimpleIcons.instagram,
      SimpleIconColors.instagram),
  // The essentials (2026-11-22).
  QuickApp('LinkedIn', ['com.linkedin.android'], Icons.work_rounded,
      Color(0xFF0A66C2),
      badge: _linkedinBadge),
  QuickApp('X', ['com.twitter.android'], SimpleIcons.x, SimpleIconColors.x),
  QuickApp('Telegram', ['org.telegram.messenger'], SimpleIcons.telegram,
      SimpleIconColors.telegram),
  QuickApp('Snapchat', ['com.snapchat.android'], SimpleIcons.snapchat,
      SimpleIconColors.snapchat,
      badge: _snapchatBadge),
  QuickApp('Spotify', ['com.spotify.music'], SimpleIcons.spotify,
      SimpleIconColors.spotify),
  QuickApp('Maps', ['com.google.android.apps.maps'], SimpleIcons.googlemaps,
      SimpleIconColors.googlemaps),
  QuickApp('Chrome', ['com.android.chrome'], SimpleIcons.googlechrome,
      SimpleIconColors.googlechrome),
];

/// Every app on both sections.
const quickApps = <QuickApp>[...paymentApps, ...otherApps];

const _channel = MethodChannel('hari/intent');

/// The installed package and its icon, read once per run (null: none installed).
final _found = <String, Future<(String, Uint8List)?>>{};

Future<(String, Uint8List)?> _lookup(QuickApp a) =>
    _found[a.pkgs.join(',')] ??= () async {
      if (_isIOS) {
        // No icon from another app on iOS: an empty PNG marks "installed"
        // and the tile draws [QuickApp.mark].
        final scheme = a.iosScheme;
        if (scheme != null) {
          try {
            if (await canLaunchUrl(Uri.parse('$scheme://'))) {
              return (scheme, Uint8List(0));
            }
          } catch (_) {}
        }
        _found.remove(a.pkgs.join(','));
        return null;
      }
      for (final pkg in a.pkgs) {
        try {
          final png = await _channel
              .invokeMethod<Uint8List>('appIcon', {'pkg': pkg, 'size': 144});
          if (png != null) return (pkg, png);
        } catch (_) {}
      }
      // Not remembered: installed from the Play Store, it opens next tap.
      _found.remove(a.pkgs.join(','));
      return null;
    }();

/// Opens [a]; false when it is not on this phone.
Future<bool> _launch(QuickApp a) async {
  AppLog.add('home', 'quick app ${a.name}');
  final hit = await _lookup(a);
  if (hit == null) return false;
  if (_isIOS) {
    try {
      return await launchUrl(Uri.parse('${hit.$1}://'),
          mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
  try {
    final opened = await _channel
        .invokeMethod<String>('launchApp', {'name': a.name, 'pkg': hit.$1});
    return opened != null && opened.isNotEmpty;
  } catch (_) {
    return false;
  }
}

/// Its Play Store page (Gallery → Google Photos); on an iPhone, its App
/// Store page.
Future<void> _store(QuickApp a) async {
  if (_isIOS) {
    final id = a.iosStoreId;
    final page = id != null
        ? 'https://apps.apple.com/app/id$id'
        : 'https://apps.apple.com/search?term=${Uri.encodeQueryComponent(a.name)}';
    await launchUrl(Uri.parse(page), mode: LaunchMode.externalApplication);
    return;
  }
  final pkg = a.pkgs.last;
  final market = Uri.parse('market://details?id=$pkg');
  if (!await launchUrl(market, mode: LaunchMode.externalApplication)) {
    await launchUrl(
        Uri.parse('https://play.google.com/store/apps/details?id=$pkg'),
        mode: LaunchMode.externalApplication);
  }
}

/// NOT ON THIS PHONE (2026-11-08): say so, and offer the Play Store,
/// rather than dropping the user into the store unannounced.
Future<void> _notInstalled(BuildContext context, QuickApp a, Widget icon) {
  return showAppSheet<void>(
    context: context,
    backgroundColor: Neon.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(height: 16),
            Text("${a.name} Is Not Installed",
                textAlign: TextAlign.center,
                style: NeonType.manrope(20, FontWeight.w800)
                    .copyWith(color: Neon.textHi)),
            const SizedBox(height: 8),
            Text(
                "${a.name} is not installed on this phone. Please install it from the "
                "$_storeName, then tap it here to open it.",
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: Neon.textLo, fontSize: 14, height: 1.4)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Neon.cyan,
                  foregroundColor: Neon.cyanInk,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.download_rounded),
                label: Text('Install ${a.name}',
                    style: NeonType.manrope(15, FontWeight.w800)),
                onPressed: () {
                  Navigator.of(sheet).pop();
                  _store(a);
                },
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(sheet).pop(),
              child: Text('Not Now', style: TextStyle(color: Neon.textLo)),
            ),
          ],
        ),
      ),
    ),
  );
}

String get _storeName => _isIOS ? 'App Store' : 'Play Store';

/// Home's "Quick Apps" section: the apps that are not payment apps.
class QuickApps extends StatelessWidget {
  const QuickApps({super.key});

  @override
  Widget build(BuildContext context) => const _AppGrid(
      section: 'quick_apps', title: 'Quick Apps', builtIns: otherApps);
}

/// Home's "Payments" section: GPay, PhonePe, Paytm and PayPal.
class PaymentApps extends StatelessWidget {
  const PaymentApps({super.key});

  @override
  Widget build(BuildContext context) => const _AppGrid(
      section: 'payment_apps', title: 'Payments', builtIns: paymentApps);
}

/// A section's apps after the user's edits: the built-ins they kept, then
/// the apps they added (drawn with the phone's own icon).
List<QuickApp> visibleApps(List<QuickApp> builtIns, SectionEdits e) {
  final kept = [
    for (final a in builtIns)
      if (!e.removed.contains(a.name)) a,
  ];
  return [
    ...kept,
    // An added app a kept built-in already shows is not drawn twice.
    for (final a in e.added)
      if (!kept.any((b) => b.pkgs.contains(a.pkg)))
        QuickApp(a.name, [a.pkg], Icons.apps_rounded, Neon.cyan),
  ];
}

/// Up to five a row, the rows evened out (four: one row of four; six: two
/// of three) so no app sits alone on a last row.
int tilesPerRow(int n) {
  if (n <= 5) return n < 1 ? 1 : n;
  final rows = (n + 4) ~/ 5;
  return (n + rows - 1) ~/ rows;
}

class _AppGrid extends StatefulWidget {
  const _AppGrid(
      {required this.section, required this.title, required this.builtIns});
  final String section;
  final String title;
  final List<QuickApp> builtIns;

  @override
  State<_AppGrid> createState() => _AppGridState();
}

class _AppGridState extends State<_AppGrid> {
  @override
  void initState() {
    super.initState();
    QuickAppStore.instance.load();
  }

  Future<void> _add() async {
    final shown = visibleApps(
        widget.builtIns, QuickAppStore.instance.of(widget.section));
    final app = await pickInstalledApp(context,
        exclude: {for (final a in shown) ...a.pkgs});
    if (app != null) await QuickAppStore.instance.add(widget.section, app);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, SectionEdits>>(
      valueListenable: QuickAppStore.instance.edits,
      builder: (context, _, __) {
        final apps = visibleApps(
            widget.builtIns, QuickAppStore.instance.of(widget.section));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: Neon.s1, bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(widget.title,
                          style: NeonType.manrope(21, FontWeight.w800).copyWith(
                              color: Neon.textHi, letterSpacing: -0.6)),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _editSection(context, widget.section,
                        widget.title, widget.builtIns),
                    icon: Icon(Icons.edit_rounded, size: 16, color: Neon.textLo),
                    label: Text('Edit',
                        style: TextStyle(
                            color: Neon.textLo, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(8, 16, 8, 6),
              decoration: Neon.glassBox(Neon.rLg),
              child: LayoutBuilder(builder: (context, c) {
                final w = c.maxWidth / tilesPerRow(apps.length + 1);
                return Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    for (final a in apps)
                      SizedBox(
                          key: ValueKey(a.pkgs.join(',')),
                          width: w,
                          child: _AppTile(app: a)),
                    SizedBox(width: w, child: _AddTile(onTap: _add)),
                  ],
                );
              }),
            ),
          ],
        );
      },
    );
  }
}

/// The last tile on a section: add an app from the phone.
class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const size = 48.0;
    return Tappable(
      onTap: onTap,
      semanticLabel: 'Add an app',
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: ExcludeSemantics(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(size * 0.26),
                  border: Border.all(color: Neon.lineBright, width: 1.5),
                ),
                child: Icon(Icons.add_rounded, color: Neon.textLo, size: 26),
              ),
              const SizedBox(height: 6),
              Text('Add App',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: NeonType.manrope(12, FontWeight.w700)
                      .copyWith(color: Neon.textLo)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The phone's own icon for [pkg], once per run (null: none).
final _pkgIcons = <String, Future<Uint8List?>>{};
Future<Uint8List?> _iconOf(String pkg) => _pkgIcons[pkg] ??= () async {
      try {
        return await _channel
            .invokeMethod<Uint8List>('appIcon', {'pkg': pkg, 'size': 96});
      } catch (_) {
        return null;
      }
    }();

class _PkgIcon extends StatelessWidget {
  const _PkgIcon(this.app);
  final QuickApp app;
  static const size = 36.0;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _iconOf(app.pkgs.first),
      builder: (context, snap) {
        final png = snap.data;
        return ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.26),
          child: png != null && png.isNotEmpty
              ? Image.memory(png, width: size, height: size, gaplessPlayback: true)
              : app.badge != null
                  ? app.badge!(size)
                  : Container(
                      width: size,
                      height: size,
                      color: Colors.white,
                      alignment: Alignment.center,
                      child: Icon(app.mark, color: app.color, size: size * 0.56),
                    ),
        );
      },
    );
  }
}

/// EDIT A SECTION: remove apps, add apps, or go back to the defaults.
Future<void> _editSection(BuildContext context, String section, String title,
    List<QuickApp> builtIns) {
  final store = QuickAppStore.instance;
  return showAppSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Neon.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (sheet) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheet).size.height * 0.8),
        child: ValueListenableBuilder<Map<String, SectionEdits>>(
          valueListenable: store.edits,
          builder: (sheet, _, __) {
            final edits = store.of(section);
            final apps = visibleApps(builtIns, edits);
            final added = {for (final a in edits.added) a.pkg};
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
                  child: Text('Edit $title',
                      style: NeonType.manrope(20, FontWeight.w800)
                          .copyWith(color: Neon.textHi)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Text(
                      'Remove the apps you do not use, or add any app on your phone. '
                      'Your assistant can open the apps you add by name.',
                      style: TextStyle(
                          color: Neon.textLo, fontSize: 13, height: 1.4)),
                ),
                Flexible(
                  child: apps.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text('No apps here yet. Tap Add App to add one.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Neon.textLo)),
                        )
                      : ListView(
                          shrinkWrap: true,
                          children: [
                            for (final a in apps)
                              ListTile(
                                key: ValueKey(a.pkgs.join(',')),
                                leading: _PkgIcon(a),
                                title: Text(a.name,
                                    style: TextStyle(
                                        color: Neon.textHi,
                                        fontWeight: FontWeight.w600)),
                                trailing: IconButton(
                                  tooltip: 'Remove ${a.name}',
                                  icon: Icon(Icons.remove_circle_outline_rounded,
                                      color: Neon.error),
                                  onPressed: () => added.contains(a.pkgs.first)
                                      ? store.removeAdded(section, a.pkgs.first)
                                      : store.removeBuiltIn(section, a.name),
                                ),
                              ),
                          ],
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Neon.cyan,
                      foregroundColor: Neon.cyanInk,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.add_rounded),
                    label: Text('Add App',
                        style: NeonType.manrope(15, FontWeight.w800)),
                    onPressed: () async {
                      final app = await pickInstalledApp(sheet,
                          exclude: {for (final a in apps) ...a.pkgs});
                      if (app != null) await store.add(section, app);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: edits.removed.isEmpty && edits.added.isEmpty
                            ? null
                            : () => store.reset(section),
                        child: Text('Restore Defaults',
                            style: TextStyle(color: Neon.textLo)),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.of(sheet).pop(),
                        child: Text('Done',
                            style: TextStyle(
                                color: Neon.textHi, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

/// PICK AN APP FROM THE PHONE: every app with a launcher icon, searchable,
/// leaving out [exclude] (already shown). Null when nothing was picked.
Future<AddedApp?> pickInstalledApp(BuildContext context,
    {Set<String> exclude = const {}}) {
  return showAppSheet<AddedApp>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Neon.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (sheet) => _AppPicker(exclude: exclude),
  );
}

/// The installed apps as {name, pkg}; empty when the phone cannot say (iPhone).
Future<List<AddedApp>> installedApps() async {
  try {
    final raw = await _channel.invokeMethod<List<Object?>>('installedApps');
    return [
      for (final r in raw ?? const [])
        if (r is Map)
          if (AddedApp.fromJson({'name': r['label'], 'pkg': r['pkg']})
              case final AddedApp a)
            a,
    ];
  } catch (_) {
    return const [];
  }
}

class _AppPicker extends StatefulWidget {
  const _AppPicker({required this.exclude});
  final Set<String> exclude;

  @override
  State<_AppPicker> createState() => _AppPickerState();
}

class _AppPickerState extends State<_AppPicker> {
  late final Future<List<AddedApp>> _apps = installedApps();
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: inset),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Text('Add an App',
                    style: NeonType.manrope(20, FontWeight.w800)
                        .copyWith(color: Neon.textHi)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  autofocus: false,
                  onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
                  style: TextStyle(color: Neon.textHi),
                  decoration: InputDecoration(
                    hintText: 'Search your apps',
                    hintStyle: TextStyle(color: Neon.textDim),
                    prefixIcon: Icon(Icons.search_rounded, color: Neon.textLo),
                    filled: true,
                    fillColor: Neon.surfaceHigh,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: FutureBuilder<List<AddedApp>>(
                  future: _apps,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final all = snap.data ?? const <AddedApp>[];
                    if (all.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                            'Unable to list the apps on this phone. Adding apps '
                            'works on Android phones.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Neon.textLo)),
                      );
                    }
                    final list = [
                      for (final a in all)
                        if (!widget.exclude.contains(a.pkg) &&
                            (_q.isEmpty || a.name.toLowerCase().contains(_q)))
                          a,
                    ];
                    if (list.isEmpty) {
                      return Center(
                          child: Text('No apps match.',
                              style: TextStyle(color: Neon.textLo)));
                    }
                    return ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final a = list[i];
                        return ListTile(
                          key: ValueKey(a.pkg),
                          leading: _PkgIcon(QuickApp(
                              a.name, [a.pkg], Icons.apps_rounded, Neon.cyan)),
                          title: Text(a.name,
                              style: TextStyle(
                                  color: Neon.textHi,
                                  fontWeight: FontWeight.w600)),
                          trailing: Icon(Icons.add_circle_outline_rounded,
                              color: Neon.cyan),
                          onTap: () => Navigator.of(context).pop(a),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppTile extends StatefulWidget {
  const _AppTile({required this.app});
  final QuickApp app;

  @override
  State<_AppTile> createState() => _AppTileState();
}

class _AppTileState extends State<_AppTile> {
  Uint8List? _png;

  /// Null while the phone is being asked.
  bool? _installed;

  @override
  void initState() {
    super.initState();
    _lookup(widget.app).then((hit) {
      if (!mounted) return;
      setState(() {
        _installed = hit != null;
        _png = hit?.$2;
      });
    });
  }

  Widget _icon(double size) {
    final a = widget.app;
    final png = _png;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.26),
      child: png != null && png.isNotEmpty
          ? Image.memory(png,
              width: size,
              height: size,
              fit: BoxFit.cover,
              gaplessPlayback: true)
          : a.badge != null
              ? a.badge!(size)
              : Container(
                  width: size,
                  height: size,
                  color: Colors.white,
                  alignment: Alignment.center,
                  child: Icon(a.mark, color: a.color, size: size * 0.56),
                ),
    );
  }

  Future<void> _tap() async {
    final a = widget.app;
    if (await _launch(a)) {
      // Installed since the tile was drawn: show its real icon now.
      if (_installed != true) {
        final hit = await _lookup(a);
        if (mounted && hit != null) {
          setState(() {
            _installed = true;
            _png = hit.$2;
          });
        }
      }
      return;
    }
    if (!mounted) return;
    await _notInstalled(context, a, _icon(64));
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.app;
    const size = 48.0;
    final missing = _installed == false;
    // Not on this phone: faded, with a small download mark.
    final icon = missing
        ? Stack(
            clipBehavior: Clip.none,
            children: [
              Opacity(opacity: 0.4, child: _icon(size)),
              Positioned(
                right: -4,
                bottom: -4,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Neon.surfaceHigh,
                    shape: BoxShape.circle,
                    border: Border.all(color: Neon.textDim, width: 1),
                  ),
                  child: Icon(Icons.download_rounded,
                      size: 13, color: Neon.textHi),
                ),
              ),
            ],
          )
        : _icon(size);
    return Tappable(
      onTap: _tap,
      semanticLabel: missing ? '${a.name}, not installed' : 'Open ${a.name}',
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: ExcludeSemantics(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              const SizedBox(height: 6),
              Text(a.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: NeonType.manrope(12, FontWeight.w700)
                      .copyWith(color: missing ? Neon.textDim : Neon.textLo)),
            ],
          ),
        ),
      ),
    );
  }
}
