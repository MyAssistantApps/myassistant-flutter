import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:simple_icons/simple_icons.dart';

import '../design/apple_kit.dart';
import '../design/motion.dart';
import '../design/neon_tokens.dart';
import '../design/neon_widgets.dart';
import '../services/api_service.dart';
import '../services/app_feedback.dart';
import '../services/auth_service.dart';
import '../services/connections_service.dart';
import 'email_setup_screen.dart';

/// CONNECTED APPS (build 120) — link the apps the user already uses, in one
/// place. Google links through the phone's own sign-in; mail keeps its own
/// screen.
class ConnectedAppsScreen extends StatefulWidget {
  const ConnectedAppsScreen({super.key});

  @override
  State<ConnectedAppsScreen> createState() => _ConnectedAppsScreenState();
}

class _ConnectedAppsScreenState extends State<ConnectedAppsScreen> {
  final _svc = ConnectionsService.instance;
  bool? _mailLinked;
  bool? _googleLinked;

  /// The app being linked or unlinked right now (one at a time).
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _loadMail();
  }

  Future<void> _loadMail() async {
    final r = await Future.wait([_svc.mailLinked(), _svc.googleLinked()]);
    if (!mounted) return;
    setState(() {
      _mailLinked = r[0];
      _googleLinked = r[1];
    });
  }

  // ── Google ─────────────────────────────────────────────────────────────

  Future<void> _toggleGoogle() async {
    if (_busyId != null) return;
    HapticFeedback.selectionClick();
    final linked = _googleLinked == true;
    if (linked && !await _confirmUnlink('Google')) return;
    setState(() => _busyId = 'google');
    var ok = false;
    String? msg;
    try {
      if (linked) {
        ok = await ApiService.disconnectGoogle();
      } else {
        await AuthService.instance.linkGoogleData();
        ok = true;
      }
    } on AuthException catch (e) {
      msg = e.message;
    } catch (_) {}
    await _loadMail();
    if (!mounted) return;
    setState(() => _busyId = null);
    _toast(msg ??
        (ok
            ? (linked ? 'Google is disconnected.' : 'Google is connected.')
            : "Unable to complete the request. Please try again."));
  }

  Future<bool> _confirmUnlink(String name) async =>
      await showAppDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text('Disconnect $name'),
          content: const Text("Your assistant will stop using it on your behalf. Nothing in it is deleted."),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Keep')),
            FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Disconnect')),
          ],
        ),
      ) ==
      true;

  Widget _appRow({
    required String id,
    required String name,
    required String subtitle,
    required bool connected,
    required bool available,
    required VoidCallback onTap,
  }) {
    final busy = _busyId == id;
    return AppleRow(
      leading: BrandLogo(id),
      title: name,
      subtitle: subtitle,
      onTap: available && !busy ? onTap : null,
      trailing: busy
          ? const NeonLoader.inline()
          : !available
              ? Text('Soon', style: TextStyle(color: Neon.textDim, fontSize: NeonType.caption))
              : Text(connected ? 'Connected' : 'Connect',
                  style: TextStyle(
                      color: connected ? Neon.successInk : Neon.violet,
                      fontWeight: FontWeight.w700,
                      fontSize: NeonType.footnote)),
    );
  }

  void _toast(String text) {
    if (!mounted) return;
    AppFeedback.show(text, context: context);
  }

  @override
  Widget build(BuildContext context) {
    return NeonScaffold(
      appBar: appleAppBar(context, 'Connected Apps'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 18),
            child: Text(
              'Link the apps you already use so your assistant can work within them. '
              'Unlink any time.',
              style: TextStyle(color: Neon.textLo, fontSize: 14, height: 1.4),
            ),
          ),
          const GroupLabel('Google'),
          GroupedCard(dividerInset: 60, children: [
            _appRow(
              id: 'google',
              name: 'Google',
              subtitle: _googleLinked == true
                  ? 'Gmail and Calendar are linked. Tap to disconnect.'
                  : 'Gmail and Google Calendar — one sign-in',
              connected: _googleLinked == true,
              available: _googleLinked != null,
              onTap: _toggleGoogle,
            ),
          ]),
          const SizedBox(height: 24),
          const GroupLabel('Mail & Calendar'),
          GroupedCard(
            dividerInset: 60,
            children: [
              AppleRow(
                leading:
                    IconTile(Icons.alternate_email_rounded, AppleColors.green),
                title: 'Email',
                subtitle: _mailLinked == null
                    ? ' '
                    : (_mailLinked! ? 'Linked' : 'Not linked'),
                trailing: Icon(Icons.chevron_right_rounded,
                    color: Neon.textDim, size: 20),
                onTap: () async {
                  await Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const EmailSetupScreen()));
                  _loadMail();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// THE APP'S OWN LOGO (owner, 2026-10-04): the real brand mark in its brand
/// colour on a plain white tile — no tinted icon.
class BrandLogo extends StatelessWidget {
  const BrandLogo(this.id, {super.key, this.size = 34});
  final String id;
  final double size;

  static const _marks = <String, (IconData, Color)>{
    'google': (SimpleIcons.google, SimpleIconColors.google),
  };

  @override
  Widget build(BuildContext context) {
    final mark = _marks[id];
    final inner = Icon(mark?.$1 ?? Icons.apps_rounded,
        color: mark?.$2 ?? Colors.black54, size: size * 0.6);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: inner,
    );
  }
}
