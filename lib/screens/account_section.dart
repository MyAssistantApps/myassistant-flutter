import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../design/apple_kit.dart';
import '../design/neon_tokens.dart';
import '../design/neon_widgets.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/app_feedback.dart';
import '../design/motion.dart';
import '../services/persona.dart';
import 'auth/profession_screen.dart';

/// ACCOUNT — who is signed in, and the three things anyone must be able to
/// do with their own account: take their data, leave, and erase it.
///
/// The server has served GET /privacy/export and DELETE /privacy/account
/// all along, and ApiService had both calls — nothing in the app used them,
/// and the only sign-out was on the phone-verification screen. Both app
/// stores require in-app account deletion.
class AccountSection extends StatefulWidget {
  const AccountSection({super.key});

  @override
  State<AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends State<AccountSection> {
  bool _busy = false;

  /// The spinner belongs on the row doing the work: on "Signed in as" it
  /// looked like the account was signing in or out.
  bool _exporting = false;

  void _snack(String text) {
    if (!mounted) return;
    AppFeedback.show(text, context: context);
  }

  Future<void> _export() async {
    if (_busy) return;
    setState(() => _busy = _exporting = true);
    try {
      final json = await ApiService.exportMyData();
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/my-assistant-data.json';
      await File(path).writeAsString(json, flush: true);
      await Share.shareXFiles(
        [
          XFile(path,
              mimeType: 'application/json', name: 'my-assistant-data.json')
        ],
        subject: 'MyAssistant Data',
      );
    } catch (_) {
      _snack("Unable to export your data. Check your connection and try again.");
    } finally {
      if (mounted) setState(() => _busy = _exporting = false);
    }
  }

  Future<void> _signOut() async {
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Neon.surface,
        title: const Text('Sign Out'),
        content: const Text(
            'Your data stays with your account. Sign in again at any time to resume.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sign Out')),
        ],
      ),
    );
    if (ok != true) return;
    HapticFeedback.mediumImpact();
    await AuthService.instance.signOut();
    // AuthGate swaps to the sign-in screen; pop anything above it.
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _delete() async {
    final first = await showAppDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Neon.surface,
        title: const Text('Delete Account'),
        content: const Text(
            'This permanently erases everything your assistant holds for you (memories, reminders, '
            'documents, clients, call notes and messages) and disconnects your linked accounts. '
            'This cannot be undone.\n\nTo keep a copy, use "Export My Data" first.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep My Account')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            style: TextButton.styleFrom(foregroundColor: Neon.errorInk),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (first != true || !mounted) return;
    // A second, typed confirmation: this is the one irreversible action in
    // the app, and a mis-tap must not be enough.
    final second = await showAppDialog<bool>(
      context: context,
      builder: (c) => const _TypeToConfirm(word: 'DELETE'),
    );
    if (second != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await AuthService.instance.deleteAccount();
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (_) {
      if (mounted) setState(() => _busy = false);
      _snack("Unable to delete your account. Check your connection and try again.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.user;
    final who = (user?.email?.isNotEmpty ?? false)
        ? user!.email!
        : (user?.phone ?? user?.name ?? 'Signed in');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GroupLabel('Account'),
        GroupedCard(
          children: [
            AppleRow(
              title: 'Signed In As',
              subtitle: who,
              trailing: _busy && !_exporting
                  ? const NeonLoader.inline()
                  : null,
            ),
            // What the user does — decides which assistant and workspace they
            // see (Doctor's assistant + Clinic for doctors). Changeable here.
            ValueListenableBuilder<String>(
              valueListenable: Persona.notifier,
              builder: (_, p, __) {
                final spec = AuthService.instance.user?.specialty ?? '';
                return AppleRow(
                  title: 'Profession',
                  subtitle: Persona.titleFor(p) +
                      (p == 'doctor' && spec.isNotEmpty ? ' · $spec' : ''),
                  trailing: Icon(Icons.chevron_right_rounded,
                      size: 20, color: Neon.textDim),
                  onTap: _busy
                      ? null
                      : () => Navigator.of(context).push(MaterialPageRoute<void>(
                            builder: (ctx) => ProfessionScreen(
                              editing: true,
                              onDone: () => Navigator.of(ctx).pop(),
                            ),
                          )),
                );
              },
            ),
            AppleRow(
              title: 'Export My Data',
              subtitle: 'Download everything your assistant holds for you',
              trailing: _exporting
                  ? const NeonLoader.inline()
                  : Icon(Icons.ios_share_rounded, size: 18, color: Neon.textDim),
              onTap: _busy ? null : _export,
            ),
            AppleRow(
              title: 'Sign Out',
              onTap: _busy ? null : _signOut,
            ),
            AppleRow(
              title: 'Delete Account',
              titleColor: Neon.error,
              onTap: _busy ? null : _delete,
            ),
          ],
        ),
      ],
    );
  }
}

class _TypeToConfirm extends StatefulWidget {
  const _TypeToConfirm({required this.word});
  final String word;

  @override
  State<_TypeToConfirm> createState() => _TypeToConfirmState();
}

class _TypeToConfirmState extends State<_TypeToConfirm> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matches = _controller.text.trim().toUpperCase() == widget.word;
    return AlertDialog(
      title: Text('Type ${widget.word} to Confirm'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        decoration: InputDecoration(hintText: widget.word),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(
          onPressed: matches ? () => Navigator.pop(context, true) : null,
          style: TextButton.styleFrom(foregroundColor: Neon.errorInk),
          child: const Text('Delete Permanently'),
        ),
      ],
    );
  }
}
