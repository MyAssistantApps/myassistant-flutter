import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/apple_kit.dart';
import '../../design/neon_tokens.dart';
import '../../design/neon_widgets.dart';
import '../../services/app_feedback.dart';
import 'voice_call_contacts.dart';
import 'voice_call_contacts_db.dart';

/// "Calling Contacts": the people the assistant can call by voice, as the
/// phone resolves them — one card per person, with every name that
/// reaches them. Stored on this phone only.
class ResolvedContactsPage extends StatefulWidget {
  const ResolvedContactsPage({super.key});

  @override
  State<ResolvedContactsPage> createState() => _ResolvedContactsPageState();
}

class _ResolvedContactsPageState extends State<ResolvedContactsPage> {
  final _vcc = VoiceCallContacts.instance;
  late final Stream<List<LocalPerson>> _persons;
  String _query = '';
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _vcc.hold();
    _persons = _vcc.watchPersons();
  }

  @override
  void dispose() {
    _vcc.release();
    super.dispose();
  }

  Future<void> _sync() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      final n = await _vcc.syncFromPhone();
      if (!mounted) return;
      if (n == null) {
        AppFeedback.show(
            'Contacts access is disabled. Enable Contacts in Settings, then try again.',
            context: context,
            tone: FeedbackTone.error);
      } else {
        AppFeedback.show('$n contacts synced from this phone.',
            context: context, tone: FeedbackTone.success);
      }
    } catch (_) {
      if (mounted) {
        AppFeedback.show('Unable to read the contacts on this phone. Try again.',
            context: context, tone: FeedbackTone.error);
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _addAlias(LocalPerson p) async {
    final ctrl = TextEditingController();
    final alias = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Neon.surfaceHigh,
        title: Text('Add Alias', style: TextStyle(color: Neon.textHi)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          style: TextStyle(color: Neon.textHi),
          decoration: InputDecoration(
            hintText: 'For example "Boss" or "Uncle"',
            hintStyle: TextStyle(color: Neon.textDim),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Add')),
        ],
      ),
    );
    ctrl.dispose();
    if (alias == null || alias.trim().isEmpty) return;
    await _vcc.addAlias(p.person.id, alias);
    if (mounted) {
      AppFeedback.show('"${alias.trim()}" now reaches ${p.person.label}.',
          context: context, tone: FeedbackTone.success);
    }
  }

  bool _matches(LocalPerson p) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return p.person.primaryName.toLowerCase().contains(q) ||
        p.aliases.any((a) => a.alias.toLowerCase().contains(q)) ||
        p.phones.any((ph) => ph.e164.contains(q.replaceAll(RegExp(r'\s'), '')));
  }

  @override
  Widget build(BuildContext context) {
    return NeonScaffold(
      appBar: appleAppBar(context, 'Calling Contacts'),
      body: SafeArea(
        top: false,
        child: StreamBuilder<List<LocalPerson>>(
          stream: _persons,
          builder: (context, snap) {
            if (snap.hasError) {
              return NeonErrorState(
                  message: 'Unable to load your calling contacts.', onRetry: _sync);
            }
            if (!snap.hasData) {
              return const NeonLoader.page(semanticLabel: 'Loading contacts');
            }
            final all = snap.data!;
            final shown = all.where(_matches).toList();
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
                  child: Text(
                    'The names your assistant recognises when you ask it to call '
                    'someone. Entries that share a number are one person. '
                    'Stored on this phone only.',
                    style: TextStyle(color: Neon.textLo, fontSize: 14, height: 1.4),
                  ),
                ),
                ApplePrimaryButton(
                  label: _syncing ? 'Syncing…' : 'Sync From Phone',
                  icon: Icons.sync_rounded,
                  onPressed: _syncing ? null : _sync,
                ),
                const SizedBox(height: 16),
                if (all.isNotEmpty) ...[
                  AppleSearchField(
                    hint: 'Search names, aliases or numbers',
                    onChanged: (v) => setState(() => _query = v),
                  ),
                  const SizedBox(height: 16),
                ],
                if (all.isEmpty)
                  const NeonEmptyState(
                    icon: Icons.contacts_rounded,
                    title: 'No Contacts Yet',
                    body: 'Tap Sync From Phone to bring in the contacts saved on this phone.',
                  )
                else if (shown.isEmpty)
                  const NeonEmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No Matching Contacts',
                  )
                else
                  for (final p in shown) _PersonCard(person: p, onAddAlias: () => _addAlias(p)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({required this.person, required this.onAddAlias});

  final LocalPerson person;
  final VoidCallback onAddAlias;

  @override
  Widget build(BuildContext context) {
    final p = person.person;
    final chip = TextStyle(color: Neon.textHi, fontSize: 13);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GroupedCard(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(p.label,
                          style: TextStyle(
                              color: Neon.textHi,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                    ),
                    if (p.mergedCount > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Neon.accentFill,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('Merged ${p.mergedCount} Entries',
                            style: TextStyle(color: Neon.onAccent, fontSize: 11)),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                for (final ph in person.phones)
                  Text(
                    '${ph.e164}  ·  ${ph.label}${ph.isPrimary ? '  ·  primary' : ''}',
                    style: TextStyle(color: Neon.textLo, fontSize: 13),
                  ),
                Text(
                  p.callCount == 1 ? 'Called once' : 'Called ${p.callCount} times',
                  style: TextStyle(color: Neon.textDim, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final a in person.aliases)
                      a.origin == originUserCustom
                          ? InputChip(
                              label: Text(a.alias, style: chip),
                              backgroundColor: Neon.accentFill,
                              deleteIconColor: Neon.textLo,
                              onDeleted: () =>
                                  VoiceCallContacts.instance.removeAlias(a.id),
                              tooltip: 'Remove alias',
                            )
                          : Chip(
                              label: Text(a.alias, style: chip),
                              backgroundColor: Neon.surfaceHigh,
                            ),
                    ActionChip(
                      avatar: Icon(Icons.add_rounded, size: 16, color: Neon.textHi),
                      label: Text('Add Alias', style: chip),
                      backgroundColor: Neon.surface,
                      onPressed: onAddAlias,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
