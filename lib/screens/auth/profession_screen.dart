import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../design/apple_kit.dart';
import '../../design/neon_tokens.dart';
import '../../services/app_feedback.dart';
import '../../services/auth_service.dart';
import '../../services/persona.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  WHAT DO YOU DO? — the first onboarding step after sign-up.
///
///  One tap for most people. Choosing Doctor reveals two optional fields
///  (specialty, clinic name) in place — no extra screen, because every
///  extra screen in onboarding loses people. The choice unlocks the
///  matching workspace (Clinic for doctors) and is changeable later in
///  You → Profession.
///
///  [editing] = opened from Settings: shows a back button and pops on save
///  instead of advancing onboarding.
/// ─────────────────────────────────────────────────────────────────────────
class ProfessionScreen extends StatefulWidget {
  const ProfessionScreen({super.key, required this.onDone, this.editing = false});

  final VoidCallback onDone;
  final bool editing;

  @override
  State<ProfessionScreen> createState() => _ProfessionScreenState();
}

class _ProfessionScreenState extends State<ProfessionScreen> {
  late String? _choice = Persona.isChosen ? Persona.value : null;
  late String _specialty = AuthService.instance.user?.specialty ?? '';
  final _clinic = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _clinic.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final c = _choice;
    if (c == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await Persona.save(c,
        specialty: c == 'doctor' ? _specialty : '',
        clinic: c == 'doctor' ? _clinic.text : '');
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _busy = false;
        _error = "Couldn't save. Check your connection and try again.";
      });
      return;
    }
    // An older server answers OK but stores nothing (no `persona` field).
    // Saying "saved" there and showing "Not set" again looked like a broken
    // button (2026-11-14): say plainly that this server can't keep it.
    if (Persona.value != c) {
      setState(() {
        _busy = false;
        _error = "This server doesn't support professions yet — it needs "
            'the latest backend update. Your choice was not saved.';
      });
      AppFeedback.toast(_error!);
      return;
    }
    HapticFeedback.lightImpact();
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final doctor = _choice == 'doctor';
    return Scaffold(
      backgroundColor: Neon.bg,
      appBar: widget.editing ? appleAppBar(context, 'Profession') : null,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                        20, widget.editing ? 8 : 36, 20, 16),
                    children: [
                      if (!widget.editing) ...[
                        Text(
                          'What do you do?',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: Neon.textHi,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Your assistant shapes itself around your work — '
                          'the screens, the shortcuts and how it handles your '
                          'calls.',
                          style: TextStyle(
                              color: Neon.textLo, fontSize: 14.5, height: 1.45),
                        ),
                        const SizedBox(height: 22),
                      ],
                      for (final o in Persona.options) ...[
                        _OptionCard(
                          option: o,
                          selected: _choice == o.id,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _choice = o.id);
                          },
                        ),
                        const SizedBox(height: 10),
                      ],
                      AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        child: doctor ? _doctorDetails() : const SizedBox.shrink(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!,
                            style: TextStyle(color: Neon.error, fontSize: 13)),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  child: _busy
                      ? const SizedBox(
                          height: 50,
                          child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2.2)))
                      : ApplePrimaryButton(
                          label: widget.editing ? 'Save' : 'Continue',
                          onPressed: _choice == null ? null : _save,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _doctorDetails() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your specialty',
              style: TextStyle(
                  color: Neon.textHi, fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Optional — helps your assistant talk to your patients.',
              style: TextStyle(color: Neon.textDim, fontSize: 12.5)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in Persona.specialties)
                ChoiceChip(
                  label: Text(s),
                  selected: _specialty == s,
                  showCheckmark: false,
                  selectedColor: Neon.violet.withValues(alpha: 0.15),
                  backgroundColor: Neon.surface,
                  side: BorderSide(color: Neon.line),
                  labelStyle: TextStyle(
                      fontWeight:
                          _specialty == s ? FontWeight.w600 : FontWeight.w500,
                      color: _specialty == s ? Neon.violet : Neon.textLo),
                  onSelected: (_) => setState(
                      () => _specialty = _specialty == s ? '' : s),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _clinic,
            textCapitalization: TextCapitalization.words,
            maxLength: 80,
            decoration: const InputDecoration(
              labelText: 'Clinic or hospital name (optional)',
              counterText: '',
              prefixIcon: Icon(Icons.local_hospital_outlined),
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard(
      {required this.option, required this.selected, required this.onTap});

  final PersonaOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Neon.violet.withValues(alpha: 0.08) : Neon.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: selected ? Neon.violet : Neon.line,
                width: selected ? 1.6 : 1),
          ),
          child: Row(
            children: [
              IconTile(option.icon, selected ? Neon.violet : Neon.accentF),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(option.title,
                        style: TextStyle(
                            color: Neon.textHi,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(option.subtitle,
                        style: TextStyle(
                            color: Neon.textLo, fontSize: 12.5, height: 1.3)),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? Neon.violet : Neon.textDim,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
