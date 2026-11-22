import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/apple_kit.dart';
import '../../design/motion.dart';
import '../../design/neon_tokens.dart';
import '../../design/neon_widgets.dart';
import '../../services/api_service.dart';
import '../../services/app_feedback.dart';
import '../../services/connect_service.dart';
import 'assistant_call_screen.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  PEOPLE ON MYASSISTANT — the contacts whose own assistant you can talk to.
///
///  The phone's address book (synced, numbers only) is matched to verified
///  app numbers on the server; each row is that person, the name they gave
///  their assistant, and a Talk button that opens [AssistantCallScreen].
///  The shield in the bar sets who may talk to YOUR assistant.
/// ─────────────────────────────────────────────────────────────────────────
class AssistantsScreen extends StatefulWidget {
  const AssistantsScreen({super.key});

  @override
  State<AssistantsScreen> createState() => _AssistantsScreenState();
}

class _AssistantsScreenState extends State<AssistantsScreen> {
  List<AssistantContact>? _people;
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool force = false}) async {
    setState(() => _loading = true);
    final p = await ConnectService.people(force: force);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (p != null) _people = p;
    });
  }

  void _call(AssistantContact c) {
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => AssistantCallScreen(hostId: c.id, preview: c),
    ));
  }

  Future<void> _privacy() async {
    final current = await ConnectService.openMode() ?? 'everyone';
    if (!mounted) return;
    final picked = await showAppSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Text('Who Can Talk to My Assistant',
                    style: NeonType.manrope(19, FontWeight.w800)
                        .copyWith(color: Neon.textHi)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Text(
                    'Your assistant can take messages, urgent alerts and appointments for you. '
                    'It never shares your private information.',
                    style: TextStyle(
                        color: Neon.textLo, fontSize: 13, height: 1.4)),
              ),
              for (final (id, title, sub) in const [
                (
                  'everyone',
                  'Anyone With My Number',
                  'People who have your number saved and use MyAssistant.'
                ),
                (
                  'contacts',
                  'Only My Contacts',
                  'Only people whose number is saved on your phone too.'
                ),
                ('off', 'Nobody', 'Turn off assistant calls.'),
              ])
                AppleRow(
                  leading: Icon(
                      current == id
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      color: current == id ? Neon.violet : Neon.textDim),
                  title: title,
                  subtitle: sub,
                  trailing: const SizedBox.shrink(),
                  onTap: () => Navigator.pop(ctx, id),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || picked == current) return;
    final ok = await ConnectService.setOpenMode(picked);
    AppFeedback.toast(ok ? 'Saved.' : 'Unable to save. Please try again.');
  }

  @override
  Widget build(BuildContext context) {
    final all = _people ?? const <AssistantContact>[];
    final q = _query.trim().toLowerCase();
    final shown = q.isEmpty
        ? all
        : all
            .where((c) =>
                c.ownerName.toLowerCase().contains(q) ||
                c.assistantName.toLowerCase().contains(q))
            .toList();
    return NeonScaffold(
      appBar: appleAppBar(context, 'Talk to an Assistant', actions: [
        IconButton(
          tooltip: 'Who Can Talk to My Assistant',
          icon: const Icon(Icons.shield_outlined),
          onPressed: _privacy,
        ),
      ]),
      body: _loading && _people == null
          ? const Center(child: NeonLoader())
          : _people == null
              ? NeonErrorState(
                  message: 'Unable to Load Your Contacts',
                  onRetry: () => _load(force: true))
              : RefreshIndicator(
                  onRefresh: () => _load(force: true),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    children: [
                      Text(
                        "Talk to a contact's own assistant. It can take a message, pass on something urgent, "
                        'say when they are free and book a time with them.',
                        style: TextStyle(
                            color: Neon.textLo, fontSize: 13.5, height: 1.45),
                      ),
                      const SizedBox(height: 14),
                      if (all.length > 6) ...[
                        TextField(
                          onChanged: (v) => setState(() => _query = v),
                          decoration: const InputDecoration(
                            hintText: 'Search people',
                            prefixIcon: Icon(Icons.search_rounded),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (all.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 40),
                          child: NeonEmptyState(
                            icon: Icons.people_alt_rounded,
                            title: 'No Contacts on MyAssistant Yet',
                            body:
                                'When people in your contacts join MyAssistant, they appear here. Pull down to check again.',
                          ),
                        )
                      else
                        for (final c in shown) ...[
                          _PersonRow(contact: c, onTap: () => _call(c)),
                          const SizedBox(height: 10),
                        ],
                    ],
                  ),
                ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.contact, required this.onTap});
  final AssistantContact contact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = contact;
    final initials = c.ownerName
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();
    return Material(
      color: Neon.surface,
      borderRadius: BorderRadius.circular(Neon.rLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(Neon.rLg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Neon.rLg),
            border: Border.all(color: Neon.line),
          ),
          child: Row(children: [
            Container(
              width: 54,
              height: 54,
              padding: const EdgeInsets.all(2),
              decoration:
                  BoxDecoration(shape: BoxShape.circle, gradient: Neon.gBrand),
              child: ClipOval(
                child: c.hasPhoto
                    ? Image.network(c.photoUrl,
                        headers: ApiService.authHeaders,
                        fit: BoxFit.cover,
                        alignment: const Alignment(0, -0.35),
                        errorBuilder: (_, __, ___) => _Initials(initials))
                    : _Initials(initials),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.ownerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Neon.textHi,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Row(children: [
                      Icon(Icons.auto_awesome_rounded,
                          size: 13, color: Neon.violet),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                            c.profession.isNotEmpty
                                ? '${c.assistantName} · ${c.profession}'
                                : "${c.assistantName}, ${c.firstName}'s assistant",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                TextStyle(color: Neon.textLo, fontSize: 12.5)),
                      ),
                    ]),
                  ]),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 14, 8),
              decoration: BoxDecoration(
                gradient: Neon.gBrand,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.graphic_eq_rounded, size: 16, color: Neon.onBrand),
                const SizedBox(width: 5),
                Text('Talk',
                    style: TextStyle(
                        color: Neon.onBrand,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        color: Neon.surface,
        alignment: Alignment.center,
        child: Text(text.isEmpty ? '?' : text,
            style: TextStyle(
                color: Neon.violet, fontSize: 18, fontWeight: FontWeight.w800)),
      );
}
