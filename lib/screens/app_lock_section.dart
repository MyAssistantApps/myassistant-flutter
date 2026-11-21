import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/apple_kit.dart';
import '../design/neon_tokens.dart';
import '../services/app_lock.dart';
import '../services/app_feedback.dart';
import 'help_improve_row.dart';
import '../design/motion.dart';

/// PRIVACY & SECURITY — the app lock's switch.
///
/// AppLock and LockScreen were built (fingerprint / face, 4-digit PIN as the
/// fallback) but nothing ever turned them on: no row existed. Owner's pick,
/// 2026-09-23 ("App lock with fingerprint").
class AppLockSection extends StatefulWidget {
  const AppLockSection({super.key});

  @override
  State<AppLockSection> createState() => _AppLockSectionState();
}

class _AppLockSectionState extends State<AppLockSection> {
  final _lock = AppLock.instance;

  @override
  void initState() {
    super.initState();
    _lock.addListener(_sync);
  }

  @override
  void dispose() {
    _lock.removeListener(_sync);
    super.dispose();
  }

  void _sync() {
    if (mounted) setState(() {});
  }

  void _snack(String text) {
    if (!mounted) return;
    AppFeedback.show(text, context: context);
  }

  /// Asks for a 4-digit PIN. [confirm] asks twice (setting a new one).
  Future<String?> _askPin({required String title, bool confirm = false}) async {
    Future<String?> once(String heading) => showAppDialog<String>(
          context: context,
          builder: (c) => _PinDialog(title: heading),
        );
    final first = await once(title);
    if (first == null || !confirm) return first;
    final again = await once('Re-enter Your PIN');
    if (again == null) return null;
    if (again != first) {
      _snack("The PINs did not match. Please try again.");
      return null;
    }
    return first;
  }

  Future<void> _turnOn() async {
    final pin = await _askPin(title: 'Create a 4-Digit PIN', confirm: true);
    if (pin == null) return;
    // Fingerprint / face when the phone has it; the PIN is the fallback.
    if (await _lock.deviceHasBiometrics()) {
      final ok = await _lock.tryBiometric();
      if (!ok) {
        _snack("Fingerprint was not confirmed. App lock remains disabled.");
        return;
      }
    }
    await _lock.enable(pin);
    HapticFeedback.mediumImpact();
    _snack('App lock enabled.');
  }

  Future<void> _turnOff() async {
    // Only the owner switches it off: fingerprint, else the PIN.
    var ok = await _lock.tryBiometric();
    if (!ok) {
      final pin = await _askPin(title: 'Enter Your App PIN');
      if (pin == null) return;
      ok = await _lock.tryPin(pin);
    }
    if (!ok) {
      _snack('The PIN entered is incorrect.');
      return;
    }
    await _lock.disable();
    _snack('App lock disabled.');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const GroupLabel('Privacy & Security'),
        GroupedCard(
          dividerInset: 60,
          children: [
            AppleRow(
              leading: IconTile(Icons.fingerprint_rounded, AppleColors.green),
              title: 'App Lock',
              subtitle: 'Fingerprint or PIN required to open the app',
              trailing: Switch(
                value: _lock.enabled,
                onChanged: (v) {
                  HapticFeedback.selectionClick();
                  v ? _turnOn() : _turnOff();
                },
              ),
            ),
            // Build 120: whether our team may review chats to fix mistakes.
            const HelpImproveRow(),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 6, right: 16),
          child: Text(
            'The app locks when you have been away for more than a minute. Your PIN '
            'stays on this phone.\n'
            "When off, voice recordings are not kept and your chats stay "
            'private. The assistant works the same.',
            // textLo (2026-09-30): textDim fell under 4.5:1 on the sky.
            style: TextStyle(color: Neon.textLo, fontSize: NeonType.caption),
          ),
        ),
      ],
    );
  }
}

class _PinDialog extends StatefulWidget {
  final String title;
  const _PinDialog({required this.title});

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _c,
        autofocus: true,
        obscureText: true,
        maxLength: 4,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 24, letterSpacing: 12),
        onChanged: (v) {
          if (v.length == 4) Navigator.pop(context, v);
        },
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      ],
    );
  }
}
