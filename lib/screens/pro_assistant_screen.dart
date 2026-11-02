import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/apple_kit.dart';
import '../design/neon_tokens.dart';
import '../features/assistant/state/assistant_engine.dart';
import '../features/assistant/state/assistant_state.dart';
import 'clients_screen.dart';
import 'finance_screen.dart';

/// THE PROFESSIONAL ASSISTANTS (client, 2026-11-01: "in that place you can
/// add Doctor's, Advocates & Business, below write 'Assistant'").
///
/// One page per profession, built on what the app already does for each:
/// the case-file workspace (ClientsScreen), and the assistant's own tools —
/// patient dues and follow-up visits, case notes and Indian law, the record
/// book and finance. An action either opens the screen for it or asks the
/// assistant, who answers out loud (sending or paying still asks for a yes).
enum ProKind { doctor, advocate, business }

class ProAction {
  const ProAction(this.title, this.detail, this.icon, {this.ask, this.page});
  final String title;
  final String detail;
  final IconData icon;

  /// Said to the assistant.
  final String? ask;

  /// Or opened.
  final Widget Function()? page;
}

class ProProfile {
  const ProProfile(
      this.kind, this.name, this.icon, this.tint, this.lead, this.actions);
  final ProKind kind;
  final String name;
  final IconData icon;
  final Color Function() tint;
  final String lead;
  final List<ProAction> actions;

  /// The profession's photo (assets/pro/, Pexels licence — see CREDITS.md).
  String get photo => 'assets/pro/${kind.name}.jpg';

  static ProProfile of(ProKind k) => switch (k) {
        ProKind.doctor => ProProfile(
            k,
            "Doctor's",
            Icons.medical_services_rounded,
            () => Neon.cyan,
            'Your patients, their visits and dues, kept for you.',
            [
              ProAction('Patients', 'Each patient\'s file, notes and reports',
                  Icons.folder_shared_rounded,
                  page: () => const ClientsScreen()),
              const ProAction('Who has dues pending?',
                  'Patients with payments still due', Icons.payments_rounded,
                  ask: 'Which of my patients have dues pending?'),
              const ProAction('Follow-up visits', 'Recalls coming up',
                  Icons.event_repeat_rounded,
                  ask: 'Which patient follow-up visits are coming up?'),
              const ProAction('Note a payment', 'Record what a patient paid',
                  Icons.receipt_long_rounded,
                  ask: 'I want to record a payment from a patient.'),
            ],
          ),
        ProKind.advocate => ProProfile(
            k,
            "Advocate's",
            Icons.gavel_rounded,
            () => Neon.violet,
            'Your cases, hearings and the law, at hand.',
            [
              ProAction('Case files', 'Each client\'s case, notes and papers',
                  Icons.folder_shared_rounded,
                  page: () => const ClientsScreen()),
              const ProAction('Hearings coming up',
                  'From your cases and calendar', Icons.event_note_rounded,
                  ask: 'What hearings do I have coming up?'),
              const ProAction(
                  'Look up the law',
                  'Indian acts and sections, explained',
                  Icons.menu_book_rounded,
                  ask: 'I want to look up a section of Indian law.'),
              const ProAction(
                  'Draft a notice',
                  'A legal notice or letter, written for you',
                  Icons.edit_note_rounded,
                  ask: 'Help me draft a legal notice.'),
            ],
          ),
        ProKind.business => ProProfile(
            k,
            'Business',
            Icons.storefront_rounded,
            () => Neon.pink,
            'Your clients, money and records in one place.',
            [
              ProAction('Clients', 'Each customer\'s file, notes and documents',
                  Icons.folder_shared_rounded,
                  page: () => const ClientsScreen()),
              ProAction('Money', 'Income, spending and what is due',
                  Icons.account_balance_wallet_rounded,
                  page: () => const FinanceScreen()),
              const ProAction('Record book', 'Add or check an entry',
                  Icons.menu_book_rounded,
                  ask: 'Show me the latest entries in my record book.'),
              const ProAction('Write to a customer',
                  'A quote, a reminder or a thank-you', Icons.mail_rounded,
                  ask: 'Help me write a message to a customer.'),
            ],
          ),
      };
}

class ProAssistantScreen extends StatelessWidget {
  const ProAssistantScreen({super.key, required this.kind});
  final ProKind kind;

  void _run(BuildContext context, ProAction a) {
    HapticFeedback.selectionClick();
    final page = a.page;
    if (page != null) {
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => page()));
      return;
    }
    final ask = a.ask;
    if (ask == null) return;
    // A chat opens here, the question already asked (owner, 2026-11-02).
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) =>
            ProChatScreen(profile: ProProfile.of(kind), first: ask)));
  }

  void _chat(BuildContext context) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ProChatScreen(profile: ProProfile.of(kind))));
  }

  @override
  Widget build(BuildContext context) {
    final p = ProProfile.of(kind);
    final tint = p.tint();
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: Neon.bg,
      body: CustomScrollView(
        slivers: [
          // THE HERO: the profession's photo, fading into the page, with
          // the name and what it does over it.
          SliverAppBar(
            pinned: true,
            stretch: true,
            expandedHeight: 330,
            backgroundColor: Neon.bg,
            surfaceTintColor: Colors.transparent,
            foregroundColor: Colors.white,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.35)),
                child: const BackButton(color: Colors.white),
              ),
            ),
            flexibleSpace: LayoutBuilder(builder: (context, box) {
              // The small title shows only once the hero has scrolled away.
              final open = box.maxHeight > kToolbarHeight + top + 40;
              return FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                stretchModes: const [StretchMode.zoomBackground],
                expandedTitleScale: 1,
                titlePadding: const EdgeInsetsDirectional.only(
                    start: 64, bottom: 16, end: 16),
                title: open
                    ? null
                    : Text('${p.name} Assistant',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: NeonType.manrope(17, FontWeight.w800)
                            .copyWith(color: Neon.textHi)),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(p.photo,
                        fit: BoxFit.cover,
                        alignment: const Alignment(0, -0.6)),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0, 0.3, 0.72, 1],
                          colors: [
                            Colors.black.withValues(alpha: 0.45),
                            Colors.transparent,
                            Neon.bg.withValues(alpha: 0.75),
                            Neon.bg,
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 18,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: tint.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: tint.withValues(alpha: 0.6)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(p.icon, size: 14, color: tint),
                                const SizedBox(width: 6),
                                Text('ASSISTANT',
                                    style: NeonType.manrope(
                                            11, FontWeight.w800)
                                        .copyWith(
                                            color: Colors.white,
                                            letterSpacing: 1.4)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(p.name,
                              style: NeonType.manrope(34, FontWeight.w800)
                                  .copyWith(
                                      color: Colors.white,
                                      letterSpacing: -0.6,
                                      height: 1.05)),
                          const SizedBox(height: 6),
                          Text(p.lead,
                              style: NeonType.manrope(15, FontWeight.w600)
                                  .copyWith(
                                      color: Colors.white
                                          .withValues(alpha: 0.82),
                                      height: 1.35)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 10),
                child: Text('WHAT I CAN DO',
                    style: NeonType.eyebrow.copyWith(color: Neon.textLo)),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                mainAxisExtent: 148,
              ),
              delegate: SliverChildBuilderDelegate(
                (_, i) => _ActionCard(
                    action: p.actions[i],
                    tint: tint,
                    onTap: () => _run(context, p.actions[i])),
                childCount: p.actions.length,
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
                16, 20, 16, 40 + MediaQuery.paddingOf(context).bottom),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ChatButton(
                      label: 'Chat with the ${p.name} Assistant',
                      tint: tint,
                      onTap: () => _chat(context)),
                  const SizedBox(height: 12),
                  Text(
                      'Or just ask — for example "add a note to Ramesh\'s file".',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Neon.textDim, fontSize: NeonType.footnote)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One thing the assistant does: a tinted card, the icon in a disc, the
/// name and a line under it; a chat bubble when it asks, an arrow when it
/// opens a page.
class _ActionCard extends StatelessWidget {
  const _ActionCard(
      {required this.action, required this.tint, required this.onTap});
  final ProAction action;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final a = action;
    final r = BorderRadius.circular(20);
    final night = Color.lerp(Neon.bg, Colors.black, 0.25)!;
    return Semantics(
      button: true,
      label: '${a.title}. ${a.detail}',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: r,
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 12),
            decoration: BoxDecoration(
              borderRadius: r,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.alphaBlend(tint.withValues(alpha: 0.16), night),
                  night,
                ],
              ),
              border: Border.all(color: tint.withValues(alpha: 0.30)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: tint.withValues(alpha: 0.18),
                        boxShadow: [
                          BoxShadow(
                              color: tint.withValues(alpha: 0.25),
                              blurRadius: 12)
                        ],
                      ),
                      child: Icon(a.icon, color: tint, size: 21),
                    ),
                    const Spacer(),
                    Icon(
                        a.page != null
                            ? Icons.arrow_forward_rounded
                            : Icons.chat_bubble_outline_rounded,
                        color: Neon.textDim,
                        size: 18),
                  ],
                ),
                const Spacer(),
                Text(a.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: NeonType.manrope(15, FontWeight.w800)
                        .copyWith(color: Neon.textHi, height: 1.2)),
                const SizedBox(height: 3),
                Text(a.detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Neon.textLo, fontSize: 12.5, height: 1.25)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The page's one big button: open a chat with this assistant.
class _ChatButton extends StatelessWidget {
  const _ChatButton(
      {required this.label, required this.tint, required this.onTap});
  final String label;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(18);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: r,
          gradient: LinearGradient(
              colors: [tint, Color.lerp(tint, Neon.violet, 0.6)!]),
          boxShadow: [
            BoxShadow(
                color: tint.withValues(alpha: 0.4),
                blurRadius: 20,
                spreadRadius: -6)
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: r,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.chat_bubble_rounded,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: NeonType.manrope(15.5, FontWeight.w800)
                            .copyWith(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// THE ASSISTANT'S CHAT, ON THE PAGE (owner, 2026-11-02: "when I click it
/// comes to the Home page; instead a new chat should open there and work
/// end to end"). A typed conversation with the assistant — the same brain,
/// tools and confirmations as everywhere else (AssistantEngine.
/// sendTypedMessage) — shown as bubbles from when this chat opened. The
/// first message is the action's question; the owner types the rest.
class ProChatScreen extends StatefulWidget {
  const ProChatScreen({super.key, required this.profile, this.first});
  final ProProfile profile;
  final String? first;

  @override
  State<ProChatScreen> createState() => _ProChatScreenState();
}

class _ProChatScreenState extends State<ProChatScreen> {
  final _engine = AssistantEngine.instance;
  final _input = TextEditingController();
  final _scroll = ScrollController();
  late final int _from = _engine.transcript.length;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _engine.addListener(_changed);
    final first = widget.first;
    if (first != null && first.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _send(first));
    }
  }

  @override
  void dispose() {
    _engine.removeListener(_changed);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send(String text) async {
    final t = text.trim();
    if (t.isEmpty || _sending) return;
    HapticFeedback.selectionClick();
    _input.clear();
    setState(() => _sending = true);
    try {
      await _engine.sendTypedMessage(t);
    } catch (_) {
      // The engine puts its own error line in the conversation.
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  List<TranscriptEntry> get _lines {
    final all = _engine.transcript;
    final from = _from.clamp(0, all.length);
    return [
      for (final e in all.sublist(from))
        if (e.role != TranscriptRole.system && e.text.trim().isNotEmpty) e
    ];
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final tint = p.tint();
    final lines = _lines;
    final working = _sending || _engine.phase.busy;
    final doing = _engine.activityLabel.value;
    final ask = _engine.pendingConfirmation;
    return Scaffold(
      backgroundColor: Neon.bg,
      appBar: appleAppBar(context, '${p.name} Assistant'),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: lines.isEmpty && !working
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(p.icon, color: tint, size: 40),
                            const SizedBox(height: 12),
                            Text('Ask anything about your work.',
                                textAlign: TextAlign.center,
                                style: NeonType.manrope(16, FontWeight.w700)
                                    .copyWith(color: Neon.textHi)),
                            const SizedBox(height: 4),
                            Text(p.lead,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Neon.textLo)),
                          ],
                        ),
                      ),
                    )
                  : ListView(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      children: [
                        for (final e in lines) _bubble(e, tint),
                        if (working)
                          Padding(
                            padding: const EdgeInsets.only(top: 6, left: 4),
                            child: Row(
                              children: [
                                SizedBox.square(
                                  dimension: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: tint),
                                ),
                                const SizedBox(width: 10),
                                Text(doing ?? 'Working on it…',
                                    style: TextStyle(
                                        color: Neon.textLo,
                                        fontSize: NeonType.footnote)),
                              ],
                            ),
                          ),
                        if (ask != null)
                          _confirmCard(
                              ask.question ?? 'Shall I go ahead?', tint),
                      ],
                    ),
            ),
            _composer(tint),
          ],
        ),
      ),
    );
  }

  Widget _bubble(TranscriptEntry e, Color tint) {
    final mine = e.role == TranscriptRole.user;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 4),
            bottomRight: Radius.circular(mine ? 4 : 18),
          ),
          color: mine
              ? tint.withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: 0.07),
          border: Border.all(
              color: mine
                  ? tint.withValues(alpha: 0.45)
                  : Colors.white.withValues(alpha: 0.10)),
        ),
        child: SelectableText(
          e.text,
          style: TextStyle(color: Neon.textHi, fontSize: 15, height: 1.4),
        ),
      ),
    );
  }

  Widget _confirmCard(String question, Color tint) => Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.white.withValues(alpha: 0.06),
          border: Border.all(color: tint.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(question,
                style: NeonType.manrope(15, FontWeight.w700)
                    .copyWith(color: Neon.textHi)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                    onPressed: () => _engine.confirm(false),
                    child: const Text('No')),
                const SizedBox(width: 8),
                FilledButton(
                    onPressed: () => _engine.confirm(true),
                    child: const Text('Yes, go ahead')),
              ],
            ),
          ],
        ),
      );

  Widget _composer(Color tint) => Container(
        padding: EdgeInsets.fromLTRB(
            12, 8, 8, 8 + MediaQuery.viewInsetsOf(context).bottom * 0),
        decoration: BoxDecoration(
          color: Color.lerp(Neon.bg, Colors.black, 0.25),
          border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('pro-chat-input'),
                controller: _input,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: _send,
                style: TextStyle(color: Neon.textHi),
                decoration: InputDecoration(
                  hintText: 'Type a message',
                  hintStyle: TextStyle(color: Neon.textDim),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'Send',
              onPressed: () => _send(_input.text),
              style: IconButton.styleFrom(backgroundColor: tint),
              icon: const Icon(Icons.arrow_upward_rounded, color: Colors.black),
            ),
          ],
        ),
      );
}
