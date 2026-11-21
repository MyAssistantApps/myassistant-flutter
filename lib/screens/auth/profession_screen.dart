import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../design/apple_kit.dart';
import '../../design/neon_scaffold.dart';
import '../../design/neon_tokens.dart';
import '../../services/app_feedback.dart';
import '../../services/auth_service.dart';
import '../../services/persona.dart';
import '../../widgets/glow_cta.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  WHAT DO YOU DO? — the first onboarding step after sign-up.
///
///  Any profession, in the user's own words. A dozen quick picks cover
///  most people; a search over ~80 professions covers most of the rest;
///  anything else is typed freely and the server maps it to a workspace
///  (POST /profile/profession/resolve). The six workspace keys behind it
///  (Persona.options) still decide what the app shows and the server
///  allows; the exact profession is saved too, so the assistant knows it.
///
///  Once chosen, a card says which workspace it unlocks and what it gives,
///  so the choice is never a blind one. Doctors get two optional fields
///  (specialty, clinic) in place. Changeable later in You → Profession.
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
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final _clinic = TextEditingController();

  late ProfessionMatch? _match = Persona.isChosen
      ? ProfessionMatch(Persona.titleFor(Persona.value), Persona.value)
      : null;
  late String _specialty = AuthService.instance.user?.specialty ?? '';
  bool _resolving = false;
  bool _busy = false;
  String? _error;

  String get _query => _search.text.trim();

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    _clinic.dispose();
    super.dispose();
  }

  void _pick(ProfessionMatch m) {
    HapticFeedback.selectionClick();
    _searchFocus.unfocus();
    setState(() {
      _match = m;
      _error = null;
      _search.clear();
    });
  }

  /// Typed text the catalog doesn't know: ask the server which workspace
  /// fits. Offline, it becomes a Professional workspace, never a dead end.
  Future<void> _useTyped() async {
    final text = _query;
    if (text.isEmpty || _resolving) return;
    final exact = Persona.professions
        .where((p) => p.label.toLowerCase() == text.toLowerCase())
        .firstOrNull;
    if (exact != null) return _pick(ProfessionMatch(exact.label, exact.persona));
    setState(() => _resolving = true);
    final m = await Persona.resolve(text);
    if (!mounted) return;
    setState(() => _resolving = false);
    _pick(m ?? ProfessionMatch(text, 'professional'));
  }

  Future<void> _save(ProfessionMatch m) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final doctor = m.persona == 'doctor';
    final ok = await Persona.save(m.persona,
        profession: m.label,
        specialty: doctor ? _specialty : '',
        clinic: doctor ? _clinic.text : '');
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _busy = false;
        _error = 'Unable to save. Check your connection and try again.';
      });
      return;
    }
    // An older server answers OK but stores nothing (no `persona` field):
    // say so plainly instead of looking like a broken button (2026-11-14).
    if (Persona.value != m.persona) {
      setState(() {
        _busy = false;
        _error = 'Profession selection requires the latest server update; '
            'your selection was not saved.';
      });
      AppFeedback.toast(_error!);
      return;
    }
    HapticFeedback.lightImpact();
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final m = _match;
    final searching = _query.isNotEmpty;
    return NeonScaffold(
      appBar: widget.editing ? appleAppBar(context, 'Profession') : null,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                        20, widget.editing ? 8 : 28, 20, 16),
                    children: [
                      if (!widget.editing) ...[
                        const _HeaderMark(),
                        const SizedBox(height: 20),
                        Text(
                          'What Do You Do?',
                          style: GoogleFonts.interTight(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Neon.textHi,
                            letterSpacing: -0.6,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your assistant shapes its screens, reminders and '
                          'call handling around your work. Choose a profession '
                          'or type your own.',
                          style: TextStyle(
                              color: Neon.textLo, fontSize: 14.5, height: 1.45),
                        ),
                        const SizedBox(height: 22),
                      ],
                      _SearchField(
                        controller: _search,
                        focusNode: _searchFocus,
                        onSubmitted: _useTyped,
                      ),
                      const SizedBox(height: 16),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        switchInCurve: Curves.easeOutCubic,
                        child: searching
                            ? _Suggestions(
                                key: const ValueKey('search'),
                                query: _query,
                                resolving: _resolving,
                                onPick: (e) =>
                                    _pick(ProfessionMatch(e.label, e.persona)),
                                onUseTyped: _useTyped,
                              )
                            : m == null
                                ? _QuickPicks(
                                    key: const ValueKey('picks'),
                                    onPick: (e) => _pick(
                                        ProfessionMatch(e.label, e.persona)),
                                  )
                                : _ChosenCard(
                                    key: ValueKey('chosen-${m.label}'),
                                    match: m,
                                    onChange: () {
                                      setState(() => _match = null);
                                      _searchFocus.requestFocus();
                                    },
                                  ),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        child: !searching && m?.persona == 'doctor'
                            ? _doctorDetails()
                            : const SizedBox(width: double.infinity),
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
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GlowCta(
                        label: widget.editing ? 'Save' : 'Continue',
                        busy: _busy,
                        busyLabel: 'Saving',
                        onPressed: m == null || searching ? null : () => _save(m),
                      ),
                      if (!widget.editing)
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => _save(const ProfessionMatch('', 'personal')),
                          child: Text(
                            'Skip for Now — Personal Use',
                            style: TextStyle(
                                color: Neon.textLo,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                    ],
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
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your Specialty',
              style: TextStyle(
                  color: Neon.textHi, fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Optional. Helps your assistant speak to patients accurately.',
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
                  side: BorderSide(
                      color: _specialty == s ? Neon.violet : Neon.line),
                  labelStyle: TextStyle(
                      fontWeight:
                          _specialty == s ? FontWeight.w600 : FontWeight.w500,
                      color: _specialty == s ? Neon.violet : Neon.textLo),
                  onSelected: (_) =>
                      setState(() => _specialty = _specialty == s ? '' : s),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _clinic,
            textCapitalization: TextCapitalization.words,
            maxLength: 80,
            decoration: const InputDecoration(
              labelText: 'Clinic or Hospital Name (Optional)',
              counterText: '',
              prefixIcon: Icon(Icons.local_hospital_outlined),
            ),
          ),
        ],
      ),
    );
  }
}

/// The brand-gradient tile at the top of the step.
class _HeaderMark extends StatelessWidget {
  const _HeaderMark();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          gradient: Neon.gBrand,
          borderRadius: BorderRadius.circular(16),
          boxShadow: Neon.halo(Neon.violet),
        ),
        child: Icon(Icons.work_rounded, color: Neon.onBrand, size: 26),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField(
      {required this.controller,
      required this.focusNode,
      required this.onSubmitted});

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.done,
      maxLength: 80,
      onSubmitted: (_) => onSubmitted(),
      style: TextStyle(color: Neon.textHi, fontSize: 15.5),
      decoration: InputDecoration(
        hintText: 'Search or type your profession',
        counterText: '',
        prefixIcon: Icon(Icons.search_rounded, color: Neon.textLo),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear',
                icon: Icon(Icons.close_rounded, color: Neon.textLo),
                onPressed: controller.clear,
              ),
      ),
    );
  }
}

/// Before any search: the professions most people pick, one tap each.
class _QuickPicks extends StatelessWidget {
  const _QuickPicks({super.key, required this.onPick});

  final ValueChanged<ProfessionEntry> onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Popular'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 10,
          children: [
            for (final e in Persona.popular)
              _PickChip(entry: e, onTap: () => onPick(e)),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.auto_awesome_rounded, size: 16, color: Neon.violet),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Not listed? Type it above. Your assistant understands any '
                'profession and sets up the right workspace.',
                style: TextStyle(
                    color: Neon.textDim, fontSize: 12.5, height: 1.4),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PickChip extends StatelessWidget {
  const _PickChip({required this.entry, required this.onTap});

  final ProfessionEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Neon.surface,
      shape: StadiumBorder(side: BorderSide(color: Neon.line)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(entry.icon, size: 18, color: Neon.violet),
              const SizedBox(width: 8),
              Text(entry.label,
                  style: TextStyle(
                      color: Neon.textHi,
                      fontSize: 14,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

/// While typing: catalog matches, and always the typed text itself.
class _Suggestions extends StatelessWidget {
  const _Suggestions({
    super.key,
    required this.query,
    required this.resolving,
    required this.onPick,
    required this.onUseTyped,
  });

  final String query;
  final bool resolving;
  final ValueChanged<ProfessionEntry> onPick;
  final VoidCallback onUseTyped;

  @override
  Widget build(BuildContext context) {
    final hits = Persona.search(query);
    final exact = hits.any((h) => h.label.toLowerCase() == query.toLowerCase());
    return Container(
      decoration: BoxDecoration(
        color: Neon.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Neon.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final e in hits)
            _SuggestionRow(
              icon: e.icon,
              title: e.label,
              subtitle: Persona.workspaces[e.persona]?.title ?? '',
              onTap: () => onPick(e),
            ),
          if (!exact)
            _SuggestionRow(
              icon: Icons.auto_awesome_rounded,
              title: 'Use “$query”',
              subtitle: 'Your assistant will choose the right workspace',
              accent: true,
              busy: resolving,
              onTap: onUseTyped,
            ),
        ],
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent = false,
    this.busy = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool accent;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: busy ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            IconTile(icon, accent ? Neon.violet : Neon.accentF, size: 36),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: accent ? Neon.violet : Neon.textHi,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(color: Neon.textDim, fontSize: 12.5)),
                  ],
                ],
              ),
            ),
            if (busy)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Neon.violet),
              )
            else
              Icon(Icons.chevron_right_rounded, color: Neon.textDim),
          ],
        ),
      ),
    );
  }
}

/// The choice, and what it unlocks — so it is never a blind one.
class _ChosenCard extends StatelessWidget {
  const _ChosenCard({super.key, required this.match, required this.onChange});

  final ProfessionMatch match;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final ws = Persona.workspaces[match.persona];
    final icon = Persona.professions
            .where((p) => p.label == match.label)
            .map((p) => p.icon)
            .firstOrNull ??
        Persona.options
            .where((o) => o.id == match.persona)
            .map((o) => o.icon)
            .firstOrNull ??
        Icons.work_rounded;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: Neon.violet.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Neon.violet.withValues(alpha: 0.55), width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: Neon.gBrand,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Neon.onBrand, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(match.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Neon.textHi,
                            fontSize: 17,
                            fontWeight: FontWeight.w700)),
                    if (ws != null) ...[
                      const SizedBox(height: 3),
                      Text(ws.title,
                          style: TextStyle(
                              color: Neon.violet,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600)),
                    ],
                  ],
                ),
              ),
              TextButton(onPressed: onChange, child: const Text('Change')),
            ],
          ),
          if (ws != null) ...[
            const SizedBox(height: 14),
            Divider(height: 1, color: Neon.line),
            const SizedBox(height: 14),
            const _SectionLabel('Your Assistant Will Set Up'),
            const SizedBox(height: 10),
            for (final perk in ws.perks)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_rounded,
                        size: 18, color: Neon.success),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(perk,
                          style: TextStyle(
                              color: Neon.textHi, fontSize: 14, height: 1.35)),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
          color: Neon.textDim,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.9),
    );
  }
}
