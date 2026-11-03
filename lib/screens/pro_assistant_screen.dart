import 'dart:async';

import 'package:flutter/material.dart';
import '../design/neon_widgets.dart';
import 'package:flutter/services.dart';

import '../ai/assistant_role.dart';
import '../ai/listen.dart';
import '../ai/model_port.dart';
import '../models/user_document.dart';
import '../services/api_service.dart';
import '../services/app_feedback.dart';
import '../design/apple_kit.dart';
import '../design/neon_tokens.dart';
import '../features/assistant/state/assistant_engine.dart';
import '../features/assistant/state/assistant_state.dart';
import '../widgets/role_mic_orb.dart';
import 'clients_screen.dart';
import 'documents_screen.dart';
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
  const ProProfile(this.kind, this.name, this.icon, this.lead, this.actions);
  final ProKind kind;
  final String name;
  final IconData icon;
  final String lead;

  /// THE APP'S OWN COLOUR (2026-11-03): every assistant page is drawn in
  /// the theme accent, like the rest of the app — no per-profession tint.
  Color tint() => Neon.violet;
  final List<ProAction> actions;

  /// The profession's photo (assets/pro/, Pexels licence — see CREDITS.md).
  String get photo => 'assets/pro/${kind.name}.jpg';

  /// Where the photo is anchored in the hero: the advocate's (2026-11-03,
  /// supplied by the owner) is framed tight, so it keeps its very top.
  Alignment get photoAlign => kind == ProKind.advocate
      ? const Alignment(0, -1)
      : const Alignment(0, -0.7);

  /// Who the mic orb on the page talks as.
  AssistantRole get role => AssistantRole(
      "the $name Assistant",
      switch (kind) {
        ProKind.doctor => 'You help a doctor run their practice: patients\' '
            'files, notes and reports, follow-up visits, and payments and '
            'dues.',
        ProKind.advocate => 'You help an advocate in India: clients\' case '
            'files, hearings, Indian acts and sections, and drafting legal '
            'notices and letters.',
        ProKind.business => 'You help a business owner: customers and their '
            'files, income and spending, the record book, and messages to '
            'customers.',
      });

  static ProProfile of(ProKind k) => switch (k) {
        ProKind.doctor => ProProfile(
            k,
            "Doctor's",
            Icons.medical_services_rounded,
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

  /// Camera or gallery → saved to My documents → a NEW chat with this
  /// assistant, the photo at the top and the assistant asking what to do
  /// with it (owner, 2026-11-03).
  Future<void> _photo(BuildContext context) async {
    HapticFeedback.selectionClick();
    final doc = await uploadMyDocument(context, photosOnly: true);
    if (doc == null || !context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) =>
            ProChatScreen(profile: ProProfile.of(kind), photo: doc)));
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
    // The hero shows the face whole: tall enough that the name and the
    // lead sit on the shoulders, below the chin, never over the face.
    final heroHeight =
        (MediaQuery.sizeOf(context).height * 0.46).clamp(340.0, 420.0);
    return Scaffold(
      backgroundColor: Neon.bg,
      body: CustomScrollView(
        slivers: [
          // THE HERO: the profession's photo, fading into the page, with
          // the name and what it does over it.
          SliverAppBar(
            pinned: true,
            stretch: true,
            expandedHeight: heroHeight,
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
              // How open the hero is, 1 = fully. The name, lead and orb
              // ride up with the hero's bottom edge and fade out as it
              // closes, instead of being sliced by it.
              final t = ((box.maxHeight - kToolbarHeight - top) /
                      (heroHeight - kToolbarHeight))
                  .clamp(0.0, 1.0);
              final textOpacity = ((t - 0.55) / 0.35).clamp(0.0, 1.0);
              return Stack(
                fit: StackFit.expand,
                children: [
                  FlexibleSpaceBar(
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
                            alignment: p.photoAlign,
                            filterQuality: FilterQuality.medium),
                        // Clear over the face (the top ~55%), then into the
                        // page's own ground where the words sit; a light
                        // dark band at the very top keeps the back button
                        // legible.
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: const [0, 0.22, 0.55, 0.8, 1],
                              colors: [
                                Colors.black.withValues(alpha: 0.35),
                                Colors.transparent,
                                Colors.transparent,
                                Neon.bg.withValues(alpha: 0.88),
                                Neon.bg,
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (textOpacity > 0)
                    Positioned(
                      left: 20,
                      right: 16,
                      bottom: 14,
                      child: Opacity(
                        opacity: textOpacity,
                        child: IgnorePointer(
                          ignoring: textOpacity < 0.5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Color.alphaBlend(
                                      tint.withValues(alpha: 0.22),
                                      Neon.surface),
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
                                                color: Neon.textHi,
                                                letterSpacing: 1.4)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              // The name and its lead on the left; the mic orb
                              // that talks as this assistant (owner,
                              // 2026-11-02) at the right edge, clear of the
                              // face.
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(p.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: NeonType.manrope(
                                                    34, FontWeight.w800)
                                                .copyWith(
                                                    color: Neon.textHi,
                                                    letterSpacing: -0.6,
                                                    height: 1.05)),
                                        const SizedBox(height: 6),
                                        Text(p.lead,
                                            style: NeonType.manrope(
                                                    15, FontWeight.w600)
                                                .copyWith(
                                                    color: Neon.textLo,
                                                    height: 1.35)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // A PHOTO FOR THE ASSISTANT (2026-11-03):
                                  // beside the mic — camera or gallery, then
                                  // a new chat about it opens.
                                  _PhotoButton(
                                      tint: tint, onTap: () => _photo(context)),
                                  const SizedBox(width: 12),
                                  RoleMicOrb(
                                      role: p.role, tint: tint, size: 56),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            }),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 12),
                child: Text('WHAT I CAN DO',
                    style: NeonType.eyebrow.copyWith(color: Neon.textLo)),
              ),
            ),
          ),
          // Two cards a row, each row as tall as its longer card — no
          // fixed height leaving short cards half empty.
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.separated(
              itemCount: (p.actions.length + 1) ~/ 2,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, row) {
                Widget card(int i) => i < p.actions.length
                    ? _ActionCard(
                        action: p.actions[i],
                        tint: tint,
                        onTap: () => _run(context, p.actions[i]))
                    : const SizedBox.shrink();
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: card(row * 2)),
                      const SizedBox(width: 12),
                      Expanded(child: card(row * 2 + 1)),
                    ],
                  ),
                );
              },
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
                16, 20, 16, 24 + MediaQuery.paddingOf(context).bottom),
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

/// The camera beside the mic orb: the same size and the same caption
/// line, so the two read as a pair.
class _PhotoButton extends StatelessWidget {
  const _PhotoButton({required this.tint, required this.onTap});
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Add a photo — take one or choose from gallery',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: documentUploading,
              builder: (_, busy, __) => Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: Neon.glassFill,
                  border: Border.all(
                      color: tint.withValues(alpha: 0.7), width: 1.4),
                  boxShadow: Neon.halo(tint, strength: 0.5),
                ),
                child: busy
                    ? const Center(
                        child: NeonLoader.inline(semanticLabel: 'Uploading'))
                    : Icon(Icons.photo_camera_rounded,
                        color: Neon.textHi, size: 24),
              ),
            ),
            const SizedBox(height: 4),
            Text('Add photo',
                style: TextStyle(
                    color: Neon.textHi,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600)),
          ],
        ),
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
            // On the theme's own card surface, washed with the accent —
            // right in both the light and the dark theme.
            decoration: BoxDecoration(
              borderRadius: r,
              // Glass, like Home's cards (2026-11-03): the sky shows
              // through, with a touch of the accent in the corner.
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.alphaBlend(tint.withValues(alpha: 0.10),
                      Neon.glassFill.colors.first),
                  Neon.glassFill.colors.last,
                ],
              ),
              border: Border.all(color: Neon.glassEdge.first),
              boxShadow: Neon.glassShadow,
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
                // Every title starts at the same height, however many
                // lines it takes.
                const SizedBox(height: 12),
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
          gradient: LinearGradient(colors: [
            Color.lerp(Neon.accentFill, Colors.white, 0.12)!,
            Neon.accentFill,
          ]),
          boxShadow: [
            BoxShadow(
                color: Neon.accentFill.withValues(alpha: 0.4),
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
  const ProChatScreen(
      {super.key, required this.profile, this.first, this.photo});
  final ProProfile profile;
  final String? first;

  /// A photo the user just added: the chat opens on it, asking what to do.
  final UserDocument? photo;

  @override
  State<ProChatScreen> createState() => _ProChatScreenState();
}

class _ProChatScreenState extends State<ProChatScreen> {
  final _engine = AssistantEngine.instance;
  final _input = TextEditingController();
  final _scroll = ScrollController();
  late final int _from = _engine.transcript.length;
  bool _sending = false;

  /// VOICE TYPING (2026-11-03): the mic in the message box writes what is
  /// said into it, live; nothing is sent until the user taps send. The
  /// same listener as the rest of the app (on-device recogniser first).
  VoiceListener? _listener;
  VoiceListener get _voice =>
      _listener ??= VoiceListener.standard(ModelPorts.cloud());
  bool _dictating = false;
  final _level = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _engine.addListener(_changed);
    _photo = widget.photo;
    final first = widget.first;
    if (first != null && first.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _send(first));
    }
  }

  @override
  void dispose() {
    _engine.removeListener(_changed);
    unawaited(_listener?.cancel().catchError((_) {}));
    _level.dispose();
    _inputFocus.dispose();
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

  /// Tap to start: what is said is added after whatever is already typed.
  /// Tap again to stop early; a pause in speech also ends it.
  Future<void> _toggleDictation() async {
    if (_dictating) {
      HapticFeedback.selectionClick();
      await _voice.stop();
      return;
    }
    HapticFeedback.mediumImpact();
    final before = _input.text.trimRight();
    final lead = before.isEmpty ? '' : '$before ';
    void show(String words) {
      final t = '$lead${words.trim()}';
      _input.value = TextEditingValue(
          text: t, selection: TextSelection.collapsed(offset: t.length));
    }

    setState(() => _dictating = true);
    var failed = '';
    try {
      // Dictation, not a command: longer pauses are allowed mid-thought.
      await for (final e in _voice.listen(
          listenFor: const Duration(seconds: 60),
          pauseFor: const Duration(milliseconds: 2500))) {
        if (!mounted) break;
        switch (e) {
          case HearPartial(:final text):
            show(text);
          case HearFinal(:final text):
            if (text.trim().isNotEmpty) show(text);
          case HearLevel(:final level):
            _level.value = level;
          case HearError(:final code):
            failed = code;
          case HearEndOfSpeech():
            break;
        }
      }
    } catch (e) {
      failed = '$e';
    }
    if (!mounted) return;
    _level.value = 0;
    setState(() => _dictating = false);
    if (failed.isNotEmpty) {
      AppFeedback.toast(failed == 'permission'
          ? 'Allow the microphone to use voice typing.'
          : "Couldn't hear that — try again, or type it.");
    }
  }

  /// The photo this chat is about (shown at the top, with the assistant's
  /// question under it).
  UserDocument? _photo;

  /// True until the user has said something about [_photo]: their first
  /// message carries its title, which is how the assistant finds it.
  bool _photoPending = true;
  final _inputFocus = FocusNode();

  Future<void> _send(String text) async {
    var t = text.trim();
    if (t.isEmpty || _sending) return;
    final photo = _photo;
    if (photo != null && _photoPending) {
      t = 'About the photo I just added ("${photo.title}"): $t';
      _photoPending = false;
    }
    if (_dictating) unawaited(_voice.cancel().catchError((_) {}));
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

  /// Saves a photo or file, then starts the question about it — the title
  /// is how the assistant finds the document among the user's saved ones.
  Future<void> _attach() async {
    final doc = await uploadMyDocument(context);
    if (doc == null || !mounted) return;
    setState(() {
      _photo = doc;
      _photoPending = true;
    });
    _inputFocus.requestFocus();
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
    return NeonScaffold(
      appBar: appleAppBar(context, '${p.name} Assistant'),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: lines.isEmpty && !working && _photo == null
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
                        if (_photo != null) ..._photoHeader(_photo!),
                        for (final e in lines) _bubble(e, tint),
                        if (working)
                          Padding(
                            padding: const EdgeInsets.only(top: 6, left: 4),
                            child: Row(
                              children: [
                                const NeonLoader.inline(
                                    size: 14, semanticLabel: 'Working'),
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

  /// The photo, as the user's own message, and the assistant asking what
  /// to do with it — the start of a chat about a picture.
  List<Widget> _photoHeader(UserDocument d) => [
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.62,
                maxHeight: 260),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Neon.accentFill, width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: d.mime.startsWith('image/')
                  ? Image.network(ApiService.documentFileUrl(d.id),
                      headers: ApiService.imageHeaders,
                      fit: BoxFit.cover,
                      cacheWidth: 700)
                  : Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(d.title,
                          style: TextStyle(color: Neon.textHi))),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.8),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(18),
              ),
              color: Neon.surface,
              border: Border.all(color: Neon.glassEdge.first),
            ),
            child: Text(
                'Got your photo. What would you like me to do with it? '
                'Ask me to read it, explain it, or file it.',
                style: TextStyle(
                    color: Neon.textHi,
                    fontSize: NeonType.rowTitle,
                    height: 1.45)),
          ),
        ),
      ];

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
          // Light premium (2026-11-02): yours in solid violet, the
          // assistant's on a raised card — both themes.
          color: mine ? Neon.accentFill : Neon.surface,
          border: mine ? null : Border.all(color: Neon.glassEdge.first),
          boxShadow: mine ? null : Neon.halo(Neon.violet, strength: 0.5),
        ),
        child: SelectableText(
          e.text,
          style: TextStyle(
              color: mine ? Colors.white : Neon.textHi,
              fontSize: NeonType.rowTitle,
              height: 1.45),
        ),
      ),
    );
  }

  Widget _confirmCard(String question, Color tint) => Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Neon.surface,
          border: Border.all(color: Neon.violet.withValues(alpha: 0.35)),
          boxShadow: Neon.halo(Neon.violet, strength: 0.6),
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

  /// The mic inside the message box: violet when idle, a pulsing stop
  /// while it is writing down what is said.
  Widget _dictateButton() => ValueListenableBuilder<double>(
        valueListenable: _level,
        builder: (_, level, __) => Padding(
          padding: const EdgeInsets.only(right: 4),
          child: IconButton(
            key: const ValueKey('pro-chat-dictate'),
            tooltip: _dictating ? 'Stop voice typing' : 'Voice typing',
            onPressed: _sending ? null : _toggleDictation,
            icon: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _dictating
                    ? Neon.accentFill
                    : Neon.violet.withValues(alpha: 0.12),
                boxShadow: _dictating
                    ? [
                        BoxShadow(
                            color: Neon.accentFill.withValues(alpha: 0.55),
                            blurRadius: 6 + 18 * level,
                            spreadRadius: 1 + 5 * level)
                      ]
                    : null,
              ),
              child: Icon(
                  _dictating ? Icons.stop_rounded : Icons.mic_rounded,
                  size: 20,
                  color: _dictating ? Colors.white : Neon.violet),
            ),
          ),
        ),
      );

  /// Raised round controls on the page (light premium, 2026-11-02).
  BoxDecoration get _raised => BoxDecoration(
        shape: BoxShape.circle,
        color: Neon.surface,
        border: Border.all(color: Neon.glassEdge.first),
        boxShadow: Neon.halo(Neon.violet, strength: 0.6),
      );

  Widget _composer(Color tint) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // A photo or file to ask about (owner, 2026-11-02): saved to My
            // documents, then the question box names it for the assistant.
            DecoratedBox(
              decoration: _raised,
              child: ValueListenableBuilder<bool>(
                valueListenable: documentUploading,
                builder: (context, busy, _) => IconButton(
                  tooltip: busy ? 'Uploading' : 'Attach a photo or file',
                  constraints:
                      const BoxConstraints.tightFor(width: 50, height: 50),
                  onPressed: busy ? null : _attach,
                  icon: busy
                      ? const NeonLoader.inline(semanticLabel: 'Uploading')
                      : Icon(Icons.attach_file_rounded, color: Neon.violet),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Neon.surface,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Neon.glassEdge.first),
                  boxShadow: Neon.halo(Neon.violet, strength: 0.6),
                ),
                child: TextField(
                  key: const ValueKey('pro-chat-input'),
                  controller: _input,
                  focusNode: _inputFocus,
                  // A chat opened on a photo waits for the user's words.
                  autofocus: widget.photo != null,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: _send,
                  style: TextStyle(
                      color: Neon.textHi, fontSize: NeonType.rowTitle),
                  decoration: InputDecoration(
                    hintText: _dictating ? 'Listening…' : 'Type or speak',
                    hintStyle: TextStyle(color: Neon.textDim),
                    filled: false,
                    contentPadding: const EdgeInsets.fromLTRB(18, 14, 4, 14),
                    suffixIcon: _dictateButton(),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(-0.4, -0.5),
                  radius: 1.1,
                  colors: [
                    Color.lerp(Neon.accentFill, Colors.white, 0.10)!,
                    Color.lerp(Neon.accentFill, Colors.black, 0.18)!,
                  ],
                ),
                boxShadow: Neon.halo(Neon.violet, strength: 0.9),
              ),
              child: IconButton(
                tooltip: 'Send',
                constraints:
                    const BoxConstraints.tightFor(width: 50, height: 50),
                onPressed: () => _send(_input.text),
                icon:
                    const Icon(Icons.arrow_upward_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
      );
}
