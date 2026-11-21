import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../design/apple_kit.dart';
import '../../design/neon_tokens.dart';
import '../../design/neon_widgets.dart';
import '../../widgets/glow_cta.dart';
import '../../services/call_history.dart';
import '../../services/contacts_sync_service.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  PERMISSIONS — asked for up front, required only where the app cannot
///  work without it.
///
///  The assistant is useless without a microphone, so that one is a hard
///  stop, here and on any later launch where it has been revoked.
///
///  Everything else is RECOMMENDED. This screen used to refuse to continue
///  until all six were granted and re-appeared whenever any was revoked —
///  so turning the camera off in Settings locked a user out of an app they
///  talk to, which Android's guidelines (and Play review) reject. Denied
///  permissions no longer fail quietly either: the app reports what is
///  granted (every turn carries it to /ai/context), so the assistant explains
///  a blocked feature instead of promising it.
/// ─────────────────────────────────────────────────────────────────────────

class _PermItem {
  const _PermItem(this.p, this.icon, this.color, this.title, this.why,
      {this.check, this.ask});
  final Permission p;
  final IconData icon;
  final Color color;
  final String title;
  final String why;

  /// Replace permission_handler for this row (see [_phoneStatus]).
  final Future<PermissionStatus> Function()? check;
  final Future<PermissionStatus> Function()? ask;

  Future<PermissionStatus> status() => check != null ? check!() : p.status;
  Future<PermissionStatus> request() => ask != null ? ask!() : p.request();
}

// THE "PHONE" ROW IS THE PHONE, NOT CALL HISTORY.
//
// READ_CALL_LOG joined the manifest on 2026-09-24 ("any missed calls?"),
// and permission_handler folds it into Permission.phone: requesting that
// group here showed the call-history dialog to every new owner at
// onboarding, and its status reads "denied" until call history is shared
// too. Call history is asked only the first time the owner asks about his
// calls (with its own one-line explainer), so this row asks for the phone
// permissions alone, natively (CallLogBridge "requestPhone"), and reads
// them one by one. Off Android (no native side) it is the plain group.

Future<PermissionStatus> _phoneStatus() async {
  final exact = await CallHistory.permissions();
  if (exact == null) return Permission.phone.status;
  return exact['phoneState'] == true && exact['callPhone'] == true
      ? PermissionStatus.granted
      : PermissionStatus.denied;
}

Future<PermissionStatus> _phoneRequest() async {
  switch (await CallHistory.requestPhone()) {
    case 'granted':
      return PermissionStatus.granted;
    case 'blocked':
      return PermissionStatus.permanentlyDenied;
    case 'unavailable':
      // Never the group on Android: that is the call-history dialog.
      if (defaultTargetPlatform != TargetPlatform.android) {
        return Permission.phone.request();
      }
      return _phoneStatus();
    default:
      return _phoneStatus();
  }
}

final List<_PermItem> _kRequired = [
  _PermItem(Permission.microphone, Icons.mic_rounded, AppleColors.orange,
      'Microphone', 'Required to talk to your assistant.'),
];

final List<_PermItem> _kRecommended = [
  _PermItem(Permission.contacts, Icons.contacts_rounded, AppleColors.blue,
      'Contacts', 'So "Call Alan" reaches the right person.'),
  _PermItem(Permission.phone, Icons.call_rounded, AppleColors.green, 'Phone',
      'Required to place the calls you request.',
      check: _phoneStatus, ask: _phoneRequest),
  _PermItem(
      Permission.notification,
      Icons.notifications_rounded,
      AppleColors.red,
      'Notifications',
      'Delivers reminders and messages on time.'),
  _PermItem(Permission.camera, Icons.photo_camera_rounded, AppleColors.indigo,
      'Camera', 'Scan documents, receipts and reports.'),
  _PermItem(Permission.locationWhenInUse, Icons.place_rounded, AppleColors.teal,
      'Location', 'For local weather and nearby places.'),
];

List<_PermItem> get _kAll => [..._kRequired, ..._kRecommended];

/// TYPING ONLY (product audit 2026-11-21): a user who declines the
/// microphone still gets the whole app — chat, reminders, the workspace —
/// instead of a gate they cannot pass. The orb asks for the microphone
/// again the first time it is tapped.
const kMicSkippedPref = 'perm_mic_skipped_v1';

/// Launch-time check used by the setup gate: true when every REQUIRED
/// permission (the microphone) is granted, or the user chose to continue
/// by typing. Never prompts.
Future<bool> allRequiredPermissionsGranted() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(kMicSkippedPref) == true) return true;
    for (final item in _kRequired) {
      if (!await item.p.status.isGranted) return false;
    }
    return true;
  } catch (_) {
    // If the platform check itself fails, show the gate — it re-verifies.
    return false;
  }
}

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen>
    with WidgetsBindingObserver {
  final Map<Permission, PermissionStatus> _status = {};
  bool _busy = false;
  bool _blocked = false; // something is permanently denied → Settings
  String? _error;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Coming back from the system Settings screen lands here — re-check so
  /// permissions granted there are picked up without any extra tap.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  bool get _requiredGranted =>
      _kRequired.every((i) => _status[i.p]?.isGranted == true);

  bool get _allGranted => _kAll.every((i) => _status[i.p]?.isGranted == true);

  Future<void> _refresh() async {
    for (final item in _kAll) {
      try {
        _status[item.p] = await item.status();
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {});
    // Everything already allowed (or allowed in Settings just now): go on.
    if (_allGranted) _finish();
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    // Contacts just became readable — sync names to the server now, so the
    // very first "call Alan" can already resolve.
    ContactsSyncService.instance.maybeSync(force: true);
    widget.onDone();
  }

  Future<void> _continueTyping() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kMicSkippedPref, true);
    } catch (_) {}
    _finish();
  }

  Future<void> _requestAll() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _blocked = false;
    });
    for (final item in _kAll) {
      if (_status[item.p]?.isGranted == true) continue;
      try {
        _status[item.p] = await item.request();
      } catch (_) {}
    }
    if (!mounted) return;
    final micBlocked =
        _kRequired.any((i) => _status[i.p]?.isPermanentlyDenied == true);
    setState(() {
      _busy = false;
      if (!_requiredGranted) {
        _blocked = micBlocked;
        _error = micBlocked
            ? 'Microphone access is blocked. Open Settings, allow '
                'Microphone under Permissions, then return to the app.'
            : 'Microphone access is required to talk to your assistant.';
      }
    });
    // Only the microphone is required: whatever else was declined, the
    // app works, and the assistant will say when something needs a
    // permission.
    if (_requiredGranted) _finish();
  }

  @override
  Widget build(BuildContext context) {
    // Under Home's sky, the lit mark and one lit action (2026-09-30).
    return NeonScaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: BrandMark(icon: Icons.verified_user_rounded),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Enable Permissions',
                    style: GoogleFonts.interTight(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Neon.textHi,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your assistant listens, places calls, and scans on your behalf. The '
                    'microphone is essential; the others unlock more '
                    'features. You can change any of them later in '
                    'Settings.',
                    style: TextStyle(
                        color: Neon.textLo, fontSize: 15, height: 1.45),
                  ),
                  const SizedBox(height: 22),
                  const GroupLabel('Required'),
                  GroupedCard(
                    dividerInset: 60,
                    children: [
                      for (final item in _kRequired) _row(item),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const GroupLabel('Recommended'),
                  GroupedCard(
                    dividerInset: 60,
                    children: [
                      for (final item in _kRecommended) _row(item),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Neon.error.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(_error!,
                          style: TextStyle(
                              color: Neon.errorInk, fontSize: 13, height: 1.4)),
                    ),
                  ],
                  const SizedBox(height: 18),
                  GlowCta(
                    label: _blocked ? 'Open Settings' : 'Allow All',
                    busy: _busy,
                    busyLabel: 'Requesting Access',
                    onPressed: _blocked ? openAppSettings : _requestAll,
                  ),
                  // Without the microphone, the app still works by typing.
                  if (!_requiredGranted && _error != null && !_busy) ...[
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: _continueTyping,
                      style: TextButton.styleFrom(
                          minimumSize: const Size.fromHeight(48)),
                      child: Text('Continue With Typing Only',
                          style: TextStyle(color: Neon.textLo, fontSize: 14)),
                    ),
                  ],
                  // With the microphone allowed, the rest are a choice.
                  if (_requiredGranted && !_allGranted && !_busy) ...[
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: _finish,
                      style: TextButton.styleFrom(
                          minimumSize: const Size.fromHeight(48)),
                      child: Text('Skip Remaining Permissions',
                          style: TextStyle(color: Neon.textLo, fontSize: 14)),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    'Contacts remain on your phone. Only names and numbers '
                    'are synchronised, never photos or emails.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Neon.textLo, fontSize: NeonType.caption),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(_PermItem item) {
    final granted = _status[item.p]?.isGranted == true;
    return AppleRow(
      leading: IconTile(item.icon, item.color),
      title: item.title,
      subtitle: item.why,
      trailing: granted
          ? Icon(Icons.check_circle_rounded,
              color: Neon.success, size: 22, semanticLabel: 'Allowed')
          : Text('Allow',
              style: TextStyle(
                  color: Neon.violet,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
      onTap: granted || _busy
          ? null
          : () async {
              try {
                final s = await item.request();
                _status[item.p] = s;
                if (s.isPermanentlyDenied && mounted) {
                  setState(() {
                    // Only a blocked MICROPHONE turns the main button into
                    // "Open Settings"; anything else is optional.
                    _blocked = _kRequired.contains(item);
                    _error =
                        '${item.title} access is blocked by Android. Open Settings '
                        'and allow it there.';
                  });
                }
              } catch (_) {}
              if (mounted) setState(() {});
              if (_allGranted) _finish();
            },
    );
  }
}
