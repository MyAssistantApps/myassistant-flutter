import 'package:flutter/material.dart';

import '../../design/neon_tokens.dart';
import '../../models/brief.dart';
import '../../screens/chat_screen.dart' show ChatThreadScreen;
import '../../services/api_service.dart';
import '../../services/brief_service.dart';
import '../../widgets/neon_cards.dart';

/// One sender's unread messages, newest first.
class MessageGroup {
  MessageGroup(this.from, this.messages);
  final String from;
  final List<BriefMessage> messages;
  bool get urgent => messages.any((m) => m.urgent);
  /// The newest by time (server order when times are missing).
  BriefMessage get latest => messages.reduce(
      (a, b) => (b.atMs ?? -1) > (a.atMs ?? -1) ? b : a);
  String get phone =>
      messages.map((m) => m.fromPhone).firstWhere((p) => p.isNotEmpty, orElse: () => '');
}

/// Groups unread messages by sender: urgent senders first, then the most
/// recent. Ten people writing at once become ten rows, never ten cards.
List<MessageGroup> groupMessages(List<BriefMessage> all) {
  final by = <String, List<BriefMessage>>{};
  for (final m in all) {
    (by[m.from.trim().isEmpty ? 'Someone' : m.from.trim()] ??= []).add(m);
  }
  final groups = [for (final e in by.entries) MessageGroup(e.key, e.value)];
  int at(MessageGroup g) => g.latest.atMs ?? 0;
  groups.sort((a, b) {
    if (a.urgent != b.urgent) return a.urgent ? -1 : 1;
    return at(b).compareTo(at(a));
  });
  return groups;
}

String _ago(int? ms) {
  if (ms == null) return '';
  final d = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms));
  if (d.inMinutes < 1) return 'Now';
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  if (d.inHours < 24) return '${d.inHours}h';
  return '${d.inDays}d';
}

String _initials(String name) {
  final parts = name
      .replaceAll(RegExp(r'[^\p{L}\s]', unicode: true), ' ')
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  final a = parts.first.characters.first;
  final b = parts.length > 1 ? parts.last.characters.first : '';
  return (a + b).toUpperCase();
}

Widget _avatar(String name, Color tint, {double size = 34}) => Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: tint.withValues(alpha: 0.14),
        border: Border.all(color: tint.withValues(alpha: 0.7), width: 1.4),
      ),
      child: Text(_initials(name),
          style: NeonType.manrope(size * 0.35, FontWeight.w800).copyWith(color: tint)),
    );

Widget _urgentTag() => Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration:
          BoxDecoration(color: Neon.error, borderRadius: BorderRadius.circular(6)),
      child: Text('URGENT',
          style: NeonType.manrope(9.5, FontWeight.w800)
              .copyWith(color: Colors.white, letterSpacing: 0.4)),
    );

/// THE INBOX ON HOME (owner, 2026-11-21): one compact card, urgent senders
/// on top in red, up to [maxRows] people with a one-line preview. Tapping
/// a person opens their messages in full (MessageDetailSheet).
class MessagesCard extends StatelessWidget {
  const MessagesCard({
    super.key,
    required this.messages,
    this.onDismiss,
    this.maxRows = 3,
  });

  final List<BriefMessage> messages;
  final VoidCallback? onDismiss;
  final int maxRows;

  @override
  Widget build(BuildContext context) {
    final groups = groupMessages(messages);
    final urgentCount = messages.where((m) => m.urgent).length;
    final shown = groups.take(maxRows).toList();
    final more = groups.length - shown.length;
    final red = Neon.error;
    final title = urgentCount > 0
        ? (urgentCount == 1 ? 'Urgent Message' : '$urgentCount Urgent Messages')
        : (messages.length == 1 ? 'New Message' : '${messages.length} New Messages');

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(6, 6, 4, 6),
      glow: urgentCount > 0 ? red : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Row(children: [
              Icon(
                urgentCount > 0
                    ? Icons.priority_high_rounded
                    : Icons.mark_email_unread_rounded,
                size: 18,
                color: urgentCount > 0 ? red : Neon.violet,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: NeonType.manrope(15, FontWeight.w800)
                        .copyWith(color: urgentCount > 0 ? red : Neon.textHi)),
              ),
              if (onDismiss != null)
                IconButton(
                  onPressed: onDismiss,
                  tooltip: 'Not Now',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.close_rounded, size: 18, color: Neon.textLo),
                ),
            ]),
          ),
          for (final g in shown) _row(context, g),
          if (more > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(52, 2, 8, 6),
              child: Text(
                '+ $more more ${more == 1 ? 'person' : 'people'}',
                style: NeonType.manrope(12.5, FontWeight.w600)
                    .copyWith(color: Neon.textLo),
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, MessageGroup g) {
    final n = g.messages.length;
    final tint = g.urgent ? Neon.error : Neon.violet;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => MessageDetailSheet.show(context, g),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: Row(
          children: [
            _avatar(g.from, tint),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text(g.from,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: NeonType.manrope(14, FontWeight.w700)
                              .copyWith(color: Neon.textHi)),
                    ),
                    if (n > 1) ...[
                      const SizedBox(width: 6),
                      Text('$n',
                          style: NeonType.manrope(12, FontWeight.w800)
                              .copyWith(color: tint)),
                    ],
                    if (g.urgent) ...[const SizedBox(width: 6), _urgentTag()],
                  ]),
                  Text(g.latest.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: NeonType.manrope(12.5, FontWeight.w500)
                          .copyWith(color: Neon.textLo)),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text(_ago(g.latest.atMs),
                style: NeonType.manrope(11.5, FontWeight.w600)
                    .copyWith(color: Neon.textLo)),
            Icon(Icons.chevron_right_rounded, size: 18, color: Neon.textLo),
          ],
        ),
      ),
    );
  }
}

/// One person's messages in full: every message, its time, Reply (their
/// chat) and Mark as Read (which also stops an urgent alert ringing).
class MessageDetailSheet extends StatelessWidget {
  const MessageDetailSheet({super.key, required this.group});
  final MessageGroup group;

  static Future<void> show(BuildContext context, MessageGroup g) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Neon.surface,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => MessageDetailSheet(group: g),
      );

  static String _when(int? ms) {
    if (ms == null) return '';
    final t = DateTime.fromMillisecondsSinceEpoch(ms);
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    final ap = t.hour < 12 ? 'am' : 'pm';
    final now = DateTime.now();
    final sameDay = t.year == now.year && t.month == now.month && t.day == now.day;
    return sameDay ? '$h:$m $ap' : '${t.day}/${t.month}, $h:$m $ap';
  }

  Future<void> _markRead(BuildContext context) async {
    // Gone from Home at once; the server is told in the background (it
    // also stops an urgent alert repeating).
    BriefService.instance.markMessagesRead(group.messages);
    if (context.mounted) Navigator.of(context).pop();
    final ids = [for (final m in group.messages) if (m.id != null) m.id!];
    if (ids.isNotEmpty) await ApiService.postJson('/messages/read', {'ids': ids});
  }

  @override
  Widget build(BuildContext context) {
    final g = group;
    final tint = g.urgent ? Neon.error : Neon.violet;
    final maxH = MediaQuery.of(context).size.height * 0.8;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Neon.textLo.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 14),
              Row(children: [
                _avatar(g.from, tint, size: 42),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(g.from,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: NeonType.manrope(17, FontWeight.w800)
                              .copyWith(color: Neon.textHi)),
                      Text(
                          g.messages.length == 1
                              ? '1 message'
                              : '${g.messages.length} messages',
                          style: NeonType.manrope(12.5, FontWeight.w600)
                              .copyWith(color: Neon.textLo)),
                    ],
                  ),
                ),
                if (g.urgent) _urgentTag(),
              ]),
              const SizedBox(height: 14),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: g.messages.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final m = g.messages[i];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: (m.urgent ? Neon.error : Neon.violet)
                            .withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: (m.urgent ? Neon.error : Neon.hairline)
                                .withValues(alpha: m.urgent ? 0.5 : 1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SelectableText(m.text,
                              style: NeonType.manrope(15, FontWeight.w500)
                                  .copyWith(color: Neon.textHi, height: 1.45)),
                          if (m.atMs != null) ...[
                            const SizedBox(height: 6),
                            Text(_when(m.atMs),
                                style: NeonType.manrope(11.5, FontWeight.w600)
                                    .copyWith(color: Neon.textLo)),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              Row(children: [
                if (g.phone.isNotEmpty) ...[
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(MaterialPageRoute<void>(
                            builder: (_) =>
                                ChatThreadScreen(phone: g.phone, name: g.from)));
                      },
                      icon: const Icon(Icons.reply_rounded, size: 18),
                      label: const Text('Reply'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Neon.accentFill,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(48, 46),
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _markRead(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Neon.textHi,
                      minimumSize: const Size(48, 46),
                      side: BorderSide(color: Neon.textLo.withValues(alpha: 0.5)),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text('Mark as Read'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
