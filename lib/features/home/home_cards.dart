import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/log.dart';
import '../../design/motion.dart';
import '../../design/neon_tokens.dart';
import '../../design/neon_widgets.dart';
import '../../models/brief.dart';
import '../../models/news_item.dart';
import '../../screens/calendar_screen.dart';
import '../../screens/documents_screen.dart';
import '../../screens/finance_screen.dart';
import '../../screens/news_screen.dart';
import '../../screens/news_story_screen.dart';
import '../../screens/pro_assistant_screen.dart';
import '../../screens/reminders_screen.dart';
import '../../services/app_feedback.dart';
import '../../services/auth_service.dart';
import '../../services/brief_service.dart';
import '../../services/call_history.dart';
import '../../services/missed_calls_service.dart';
import '../../widgets/neon_cards.dart';
import '../../widgets/whats_new_card.dart';
import '../assistant/state/assistant_engine.dart';
import '../briefing/brief_player.dart';
import '../meeting_prep/meeting_prep_sheet.dart';
import '../shopping/shopping_list_screen.dart';
import '../shopping/shopping_service.dart';
import 'deal_banners.dart';
import 'home_extras.dart';
import 'home_redesign.dart';
import 'try_now_cards.dart';
import 'home_feed.dart';
import 'home_memory.dart';

/// A button's background work failed: logged, and said in a toast (there is
/// no screen context down here).
void _said(String what, Object e) {
  AppLog.add('home', '$what -> $e');
  AppFeedback.show(what, tone: FeedbackTone.error);
}

/// What Home's buttons do. The real ones by default; tests hand in their
/// own, so a widget test never reaches the network, the dialer or the mic.
class HomeActions {
  const HomeActions();

  Future<bool> completeReminder(AgendaItem a) =>
      BriefService.instance.completeReminder(a);
  Future<bool> moveReminder(AgendaItem a, DateTime to) =>
      BriefService.instance.moveReminder(a, to);
  Future<bool> completePromise(PromiseItem p) =>
      BriefService.instance.completePromise(p);

  /// The owner's tap is the go-ahead: it dials straight away (the Missed
  /// calls card always worked this way).
  void callBack(CallEntry c) => unawaited(AssistantEngine.instance
      .callBackMissed(c)
      .catchError((Object e) => _said("Couldn't start the call.", e)));
  void dropCall(CallEntry c) => MissedCallsService.instance.remove(c);

  /// The assistant says them, which marks them read; the refresh then
  /// takes the card away.
  Future<void> hearMessages() async {
    await AssistantEngine.instance.announceIncomingMessages();
    await BriefService.instance.refresh(force: true);
  }

  /// A request handed to the assistant, answered out loud — sending,
  /// calling or paying still asks for a yes, as any spoken request does.
  void ask(String request) => unawaited(AssistantEngine.instance
      .askAssistant(request)
      .catchError((Object e) => _said("Couldn't ask that.", e)));
  void talk() => unawaited(AssistantEngine.instance
      .beginInlineConversation(name: AuthService.instance.user?.name)
      .catchError((Object e) => _said("Couldn't start the chat.", e)));
  void hide(HomeCard c) => unawaited(HomeMemory.instance.hide(c.id));
  void open(BuildContext context, Widget page) => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => page));

  /// "Play my morning" (2026-09-30): the day read aloud, its strip in the
  /// root overlay. A second tap pauses or resumes.
  void playBrief(BuildContext context) {
    final p = BriefPlayer.instance;
    if (p.state == BriefPlayState.playing || p.state == BriefPlayState.paused) {
      p.toggle();
      return;
    }
    unawaited(p.play(overlay: Overlay.maybeOf(context, rootOverlay: true)));
  }

  /// The meeting card's Prepare (2026-09-30): Meeting Prep for exactly
  /// that event.
  Future<void> prepareMeeting(BuildContext context, AgendaItem item) =>
      showMeetingPrep(context, meetingId: item.eventId);

  /// Where the spoken brief is (the Play button follows it).
  BriefPlayer get brief => BriefPlayer.instance;
}

/// ─────────────────────────────────────────────────────────────────────────
///  HOME'S FEED (2026-09-29): the Now card, up to two Also cards, three
///  lines of the day with the way into the calendar, and quick actions —
///  under the greeting ([leading]) and over the mic. Which cards, and why:
///  home_feed.dart. Loading shows the shape of the feed; offline shows the
///  saved day and says how old it is; nothing to do says so, calmly.
/// ─────────────────────────────────────────────────────────────────────────
class HomeFeedView extends StatefulWidget {
  const HomeFeedView({
    super.key,
    required this.leading,
    required this.padding,
    this.actions = const HomeActions(),
    this.clock = DateTime.now,
  });

  /// Scrolls as the first item: the greeting and the date.
  final Widget leading;
  final EdgeInsets padding;
  final HomeActions actions;

  /// Test seam for "in 25 min".
  final DateTime Function() clock;

  @override
  State<HomeFeedView> createState() => _HomeFeedViewState();
}

class _HomeFeedViewState extends State<HomeFeedView> {
  /// Cards whose button is waiting on the server.
  final _busy = <String>{};

  /// "In 25 min" stays true: the feed is worked out again every minute.
  Timer? _tick;

  HomeActions get _do => widget.actions;

  @override
  void initState() {
    super.initState();
    unawaited(HomeMemory.instance.load());
    unawaited(HomeNews.instance.load());
    // Play my day's words, fetched ahead so the tap speaks at once.
    unawaited(BriefPlayer.instance.prewarm());
    ShoppingService.instance.ensureLoaded();
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      // The saved headlines are refreshed in the background (News warms
      // them at launch and on return); pick them up.
      unawaited(HomeNews.instance.load());
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final memory = HomeMemory.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([
        BriefService.instance,
        MissedCallsService.instance.pending,
        memory,
        HomeNews.instance,
        ShoppingService.instance,
        _do.brief,
      ]),
      builder: (context, _) {
        final svc = BriefService.instance;
        final now = widget.clock();
        final missed = MissedCallsService.instance.pending.value;
        final feed = HomeRanker.rank(
          brief: svc.brief,
          now: now,
          missed: missed,
          hidden: memory.hiddenAt(now),
          newUser: svc.loaded && memory.isNew(now),
        );
        // Not loaded and it failed: the error, unless missed calls still
        // make a feed worth showing (with a line saying the rest is not
        // there). Never "all clear" about a day that did not load.
        final state = svc.loaded
            ? 'loaded'
            : !svc.failed
                ? 'loading'
                : missed.isEmpty
                    ? 'failed'
                    : 'partial';
        // ALWAYS USEFUL: under what is personal, the context and discovery
        // cards that fit (home_extras.dart) — also when the day could not
        // load: the saved headlines and a tip need no connection.
        final personal = state == 'failed'
            ? 1 // the error card takes the Now card's place
            : (feed.now != null ? 1 : 0) + feed.also.length;
        final toBuy = [
          for (final i in ShoppingService.instance.items)
            if (!i.checked) i.name,
        ];
        // "Born today" was here (2026-10-19 to 2026-11-01): removed at the
        // owner's request; its slot goes back to the other extras.
        // Tips ("Try asking") are gone from Home: they said what the one
        // suggestion row below says (client, 2026-11-01).
        final extras = state == 'loading'
            ? const <HomeExtra>[]
            : HomeExtras.pick(
                room: math.max(
                    0, HomeExtras.room(personal: personal, hasDay: feed.day.isNotEmpty)),
                now: now,
                toBuy: toBuy.length,
                toBuyNames: toBuy.take(3).toList(),
                news: HomeNews.instance.itemsWith(svc.brief.headlines),
                newsOn: memory.newsOn.value,
                hidden: memory.hiddenAt(now),
              ).where((e) => e.tip == null).toList();
        return ListView(
          padding: widget.padding,
          children: [
            // Kept alive: scrolled away and back, it must not replay its
            // entrance.
            _KeepAlive(child: widget.leading),
            const SizedBox(height: 20),
            StateSwitch(
              state: state,
              child: switch (state) {
                'failed' => NeonErrorState(
                    message: "Couldn't load your day",
                    onRetry: () => svc.refresh(force: true),
                  ),
                'loading' => const _Skeleton(),
                _ => _body(feed, svc.brief, now),
              },
            ),
            if (state == 'partial' || (state == 'loaded' && svc.stale))
              _status(svc),
            const SizedBox(height: 28),
            Reveal(delayMs: 130, child: _assistants()),
            // TRY NOW (2026-11-03): Style Studio's try-ons, sliding.
            const SizedBox(height: 26),
            Reveal(
              delayMs: 135,
              child: TryNowSection(onOpen: (page) => _do.open(context, page)),
            ),
            if (extras.isNotEmpty) ...[
              const SizedBox(height: 24),
              Reveal(
                delayMs: 140,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final e in extras)
                      KeyedSubtree(key: ValueKey(e.id), child: _extra(e, svc.brief)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            // A chip that says what today's tip card says is dropped.
            Reveal(
              delayMs: 160,
              child: _asks([
                for (final a in feed.asks)
                  if (!extras.any((e) => e.tip != null && (e.tip!.ask == a.request || e.tip!.say == a.label)))
                    a,
              ]),
            ),
            // The professions' photo banners and the documents box became
            // the Assistants tiles above (light premium, 2026-11-02).
            const SizedBox(height: 20),
            // ORDER AND SHOP (owner, 2026-11-01): food and shopping apps,
            // suggested for the time of day and the shopping list, sliding.
            DealBanners(banners: dealBannersFor(now, toBuy: toBuy)),
            const SizedBox(height: 20),
            // Once per release: what just got better. Below the day, never
            // above what needs the user.
            const WhatsNewCard(),
          ],
        );
      },
    );
  }

  // ── the feed ─────────────────────────────────────────────────────────

  Widget _body(HomeFeed feed, TodayBrief b, DateTime clock) {
    // NO "GET STARTED" CARD (client, 2026-11-01: "remove unnecessary
    // elements"): "Ask me anything / Talk to me" repeated the mic in the
    // dock and the suggestion row below; an empty day shows "all clear".
    final now = feed.now?.kind == HomeCardKind.getStarted ? null : feed.now;
    // LIGHT PREMIUM HOME (owner, 2026-11-02): the Next card, the day in
    // numbers, then ONE mixed feed — what else needs you, then the day.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // A new Next card replaces the last one: it fades and rises in.
        Reveal(
          delayMs: 40,
          child: StateSwitch(
            state: now?.id ?? 'clear',
            child: now == null
                ? _AllClear(later: feed.day.isNotEmpty)
                : _nowCard(now),
          ),
        ),
        const SizedBox(height: 14),
        Reveal(delayMs: 70, child: _numbers(b)),
        const SizedBox(height: 26),
        Reveal(delayMs: 100, child: _laterHeader(feed, clock)),
        const SizedBox(height: 10),
        // Rows leaving or arriving: the space opens and closes, it does
        // not jump.
        AnimatedSize(
          duration: Motion.short,
          curve: Motion.easeMove,
          alignment: Alignment.topCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final c in feed.also)
                KeyedSubtree(key: ValueKey(c.id), child: _alsoRow(c)),
            ],
          ),
        ),
        if (feed.day.isNotEmpty)
          Reveal(delayMs: 120, child: _day(feed)),
        if (feed.also.isEmpty && feed.day.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: Neon.s1, top: 2),
            child: Text('Nothing else on your list.',
                style: TextStyle(color: Neon.textLo, fontSize: NeonType.body)),
          ),
      ],
    );
  }

  /// THE DAY IN NUMBERS: meetings and reminders today, bills due today —
  /// counted from the brief, each opening its page.
  Widget _numbers(TodayBrief b) {
    final meetings = b.agenda.where((a) => a.kind == 'meeting').length;
    final reminders = b.agenda.where((a) => a.kind == 'reminder').length;
    final bills =
        b.dates.where((d) => d.kind == 'payment' && d.when == 'today').length;
    Widget cell(int n, String one, String many, Widget page) => Expanded(
          child: Tappable(
            onTap: () => _do.open(context, page),
            semanticLabel: '$n ${n == 1 ? one : many} today',
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: ExcludeSemantics(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('$n',
                        style: NeonType.manrope(30, FontWeight.w800).copyWith(
                            color: Neon.textHi,
                            letterSpacing: -1.2,
                            height: 1.1,
                            fontFeatures: NeonType.figures)),
                    Text(n == 1 ? one : many,
                        style: NeonType.manrope(NeonType.body, FontWeight.w500)
                            .copyWith(color: Neon.textLo)),
                  ],
                ),
              ),
            ),
          ),
        );
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      child: Row(children: [
        cell(meetings, 'Meeting', 'Meetings', const CalendarScreen()),
        cell(reminders, 'Reminder', 'Reminders', const RemindersScreen()),
        cell(bills, 'Bill due', 'Bills due', const FinanceScreen()),
      ]),
    );
  }

  /// "Later today" (or "Tomorrow"), with Play my day beside it: the day,
  /// read aloud; while it plays the same button pauses and resumes.
  Widget _laterHeader(HomeFeed feed, DateTime clock) {
    final p = _do.brief;
    final morning = clock.hour < 12;
    final (label, icon) = switch (p.state) {
      BriefPlayState.loading => ('Getting it…', Icons.play_arrow_rounded),
      BriefPlayState.playing => ('Pause', Icons.pause_rounded),
      BriefPlayState.paused => ('Resume', Icons.play_arrow_rounded),
      _ => (morning ? 'Play my morning' : 'Play my day', Icons.play_arrow_rounded),
    };
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Padding(
              padding: const EdgeInsets.only(left: Neon.s1),
              child: Text(
                  feed.dayLabel == 'Today' ? 'Later today' : feed.dayLabel,
                  style: NeonType.manrope(21, FontWeight.w800)
                      .copyWith(color: Neon.textHi, letterSpacing: -0.6)),
            ),
          ),
        ),
        NeonPill(
          label: label,
          icon: icon,
          busy: p.state == BriefPlayState.loading,
          onPressed: () => _do.playBrief(context),
        ),
      ],
    );
  }

  /// THE ASSISTANTS (light premium, 2026-11-02): four raised tiles in one
  /// row — the three professions and Documents (upload, keep, ask).
  Widget _assistants() {
    Widget tile(IconData icon, String label, VoidCallback onTap) => Expanded(
          child: Tappable(
            onTap: onTap,
            semanticLabel: label == 'Documents' ? 'Documents' : '$label Assistant',
            child: Container(
              height: 92,
              decoration: Neon.glassBox(Neon.rLg),
              child: ExcludeSemantics(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: Neon.violet, size: 26),
                    const SizedBox(height: 8),
                    Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: NeonType.manrope(NeonType.body, FontWeight.w700)
                            .copyWith(color: Neon.textHi)),
                  ],
                ),
              ),
            ),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Padding(
            padding: const EdgeInsets.only(left: Neon.s1, bottom: 10),
            child: Text('Assistants',
                style: NeonType.manrope(21, FontWeight.w800)
                    .copyWith(color: Neon.textHi, letterSpacing: -0.6)),
          ),
        ),
        Row(children: [
          for (final k in ProKind.values) ...[
            tile(ProProfile.of(k).icon, ProProfile.of(k).name,
                () => _do.open(context, ProAssistantScreen(kind: k))),
            const SizedBox(width: 10),
          ],
          tile(Icons.description_rounded, 'Documents',
              () => _do.open(context, const DocumentsScreen())),
        ]),
      ],
    );
  }

  Widget _nowCard(HomeCard c) {
    final (primary, secondary) = _buttons(c);
    final busy = _busy.contains(c.id);
    final open = _pageFor(c);
    const ink = Colors.white;
    return Semantics(
      container: true,
      label: _spoken(c),
      child: _Tap(
        onTap: open == null ? null : () => _do.open(context, open),
        // THE NEXT CARD (light premium, 2026-11-02): the one raised violet
        // thing on Home. Its violet is the deep fill white words pass on
        // (4.5:1) in both themes, lit a little from the top-left.
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(Neon.accentFill, Colors.white, 0.06)!,
                Color.lerp(Neon.accentFill, Colors.black, 0.18)!,
              ],
            ),
            borderRadius: BorderRadius.circular(Neon.rXl),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            boxShadow: Neon.halo(Neon.violet),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.reason,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: NeonType.manrope(NeonType.callout, FontWeight.w600)
                                .copyWith(color: ink, fontFeatures: NeonType.figures),
                          ),
                        ),
                        const SizedBox(width: Neon.s2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: ink.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(Neon.rPill),
                          ),
                          child: Text(_kindName(c.kind),
                              style: NeonType.manrope(NeonType.footnote, FontWeight.w700)
                                  .copyWith(color: ink)),
                        ),
                      ],
                    ),
                    const SizedBox(height: Neon.s4),
                    Text(
                      c.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: NeonType.manrope(28, FontWeight.w800)
                          .copyWith(color: ink, letterSpacing: -0.9, height: 1.1),
                    ),
                    if (c.detail != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        c.detail!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: ink, fontSize: NeonType.rowTitle, height: 1.4),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (primary != null) _primary(c.id, primary, busy, onBrand: true),
                  if (secondary != null) _secondary(c.id, secondary, busy, onBrand: true),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _alsoRow(HomeCard c) {
    final (primary, secondary) = _buttons(c);
    final act = primary ?? secondary;
    final busy = _busy.contains(c.id);
    final open = _pageFor(c);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        container: true,
        label: _spoken(c),
        child: _Tap(
          onTap: open == null ? null : () => _do.open(context, open),
          child: GlassCard(
            minHeight: 68,
            padding: const EdgeInsets.fromLTRB(Neon.s3, Neon.s2 + 2, Neon.s1, Neon.s2 + 2),
            child: Row(
              children: [
                ExcludeSemantics(child: _tile(c.kind, 40)),
                const SizedBox(width: Neon.s3),
                Expanded(
                  child: ExcludeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          c.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: NeonType.manrope(NeonType.body, FontWeight.w600)
                              .copyWith(color: Neon.textHi),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [c.reason, if (c.detail != null) c.detail!].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Neon.textLo, fontSize: NeonType.footnote,
                              fontFeatures: NeonType.figures),
                        ),
                      ],
                    ),
                  ),
                ),
                if (act != null) _compact(c.id, act, busy, tone: _toneOf(c.kind)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// THE DAY AS A TIMELINE (redesign, 2026-11-01): times down the left, a
  /// rail with a dot per thing. Its heading is "Later today" above the
  /// mixed feed; the month is in the Meetings number and Hub → Calendar.
  Widget _day(HomeFeed feed) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Column(
        children: [
          for (var i = 0; i < feed.day.length; i++)
            _line(feed.day[i], first: i == 0, last: i == feed.day.length - 1),
        ],
      ),
    );
  }

  Widget _line(HomeLine l, {bool first = false, bool last = false}) {
    final page = l.item.kind == 'reminder'
        ? const RemindersScreen()
        : const CalendarScreen();
    return TimelineRow(
      time: l.time,
      title: l.item.title,
      icon: l.item.kind == 'reminder' ? Icons.notifications_none_rounded : Icons.event_outlined,
      first: first,
      last: last,
      onTap: () => _do.open(context, page),
    );
  }

  /// The quick actions: requests handed to the assistant. 48 dp to the
  /// finger, 34 to the eye; not clipped at the page edge (a sliced chip
  /// read as a fault, not as "scroll for more").
  Widget _asks(List<HomeAsk> asks) {
    // ONE ROW OF SUGGESTIONS, wrapped (client, 2026-11-01): the sideways
    // list cut its last chip off at the screen's edge.
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (var i = 0; i < asks.length && i < 4; i++)
          PressScale(
            child: NeonPill(
              label: asks[i].label,
              icon: Icons.graphic_eq_rounded,
              tone: i.isEven ? NeonTone.tip : NeonTone.discovery,
              inkOverride: Neon.textHi,
              quiet: true,
              onPressed: () {
                HapticFeedback.selectionClick();
                _do.ask(asks[i].request);
              },
            ),
          ),
      ],
    );
  }

  Widget _status(BriefService svc) {
    final at = svc.updatedAt;
    final text = !svc.loaded
        ? "Couldn't load your day."
        : at == null
            ? 'Offline · showing your last saved day'
            : 'Offline · updated ${CallHistory.clock(at)}';
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 16, color: Neon.textLo),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(color: Neon.textLo, fontSize: NeonType.footnote)),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Neon.violet,
              minimumSize: const Size(48, 48),
            ),
            onPressed: () => svc.refresh(force: true),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }

  // ── always useful: context and discovery ─────────────────────────────

  Widget _extra(HomeExtra e, TodayBrief b) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: switch (e.kind) {
          HomeExtraKind.weather => _weather(e.weather!, b),
          HomeExtraKind.shopping => _shopping(e),
          HomeExtraKind.news => _news(e.news),
          HomeExtraKind.tip => _tip(e),
        },
      );

  /// A context row: the Also card's shape, with what it is as the second
  /// line.
  Widget _contextRow({
    required String id,
    required NeonTone tone,
    required IconData icon,
    required Color tint,
    required String title,
    required String subtitle,
    _Act? act,
    VoidCallback? onTap,
  }) {
    final busy = _busy.contains(id);
    return Semantics(
      container: true,
      label: '$subtitle: $title',
      child: _Tap(
        onTap: onTap,
        child: GlassCard(
          minHeight: 68,
          padding: const EdgeInsets.fromLTRB(Neon.s3, Neon.s2 + 2, Neon.s1, Neon.s2 + 2),
          child: Row(
            children: [
              ExcludeSemantics(child: _iconTile(icon, tint, 40)),
              const SizedBox(width: Neon.s3),
              Expanded(
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: NeonType.manrope(NeonType.body, FontWeight.w600)
                              .copyWith(color: Neon.textHi)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Neon.textLo, fontSize: NeonType.footnote)),
                    ],
                  ),
                ),
              ),
              if (act != null) _compact(id, act, busy, tone: tone) else const SizedBox(width: Neon.s3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _weather(WeatherNote w, TodayBrief b) {
    final (icon, tint) = switch (w.kind) {
      'rain' => (Icons.umbrella_rounded, Neon.accentC),
      'heat' => (Icons.thermostat_rounded, Neon.accentD),
      _ => (Icons.wb_sunny_rounded, Neon.accentD),
    };
    final from = w.from;
    return _contextRow(
      id: 'weather',
      tone: NeonTone.info,
      icon: icon,
      tint: tint,
      title: w.text,
      subtitle: 'Weather',
      // Rain on its way is worth a reminder; heat and sun are just told.
      act: w.kind == 'rain' && from != null
          ? _Act('Remind me', Icons.alarm_add_rounded, () async {
              _do.ask('Remind me to take an umbrella half an hour before '
                  '${_hour(from)} today.');
              return true;
            })
          : null,
    );
  }

  Widget _shopping(HomeExtra e) => _contextRow(
        id: 'shopping',
        tone: NeonTone.action,
        icon: Icons.shopping_basket_rounded,
        tint: Neon.accentE,
        title: e.toBuy == 1 ? '1 thing to buy' : '${e.toBuy} things to buy',
        subtitle: 'Shopping list · ${e.toBuyNames.join(', ')}',
        onTap: () => _do.open(context, const ShoppingListScreen()),
        act: _Act('Open', Icons.chevron_right_rounded, () async {
          _do.open(context, const ShoppingListScreen());
          return true;
        }),
      );

  /// Two headlines, marked as the news they are — not the assistant's own
  /// words — with where they come from. A tap reads the story; the ✕
  /// takes news off Home (You → Home puts it back).
  Widget _news(List<NewsItem> items) {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(Neon.s4, Neon.s1, Neon.s1, Neon.s1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.newspaper_rounded, size: 16, color: Neon.textLo),
              const SizedBox(width: 8),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text('In the news',
                      style: NeonType.eyebrow.copyWith(color: Neon.textLo)),
                ),
              ),
              IconButton(
                tooltip: 'Hide news on Home',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: _hideNews,
                icon: Icon(Icons.close_rounded, size: 18, color: Neon.textLo),
              ),
            ],
          ),
          for (final n in items)
            Semantics(
              button: true,
              label: '${n.title}. From ${n.source}',
              excludeSemantics: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(Neon.rSm),
                onTap: () => _do.open(context, NewsStoryScreen(item: n)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 6, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(n.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: NeonType.manrope(NeonType.body, FontWeight.w600)
                              .copyWith(color: Neon.textHi, height: 1.3)),
                      const SizedBox(height: 2),
                      Text(
                        [if (n.source.isNotEmpty) n.source, if (n.age.isNotEmpty) n.age]
                            .join(' · '),
                        style: TextStyle(
                            color: Neon.textLo, fontSize: NeonType.footnote),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Neon.violet,
                minimumSize: const Size(48, 48),
                textStyle: NeonType.manrope(NeonType.footnote, FontWeight.w700),
              ),
              onPressed: () => _do.open(context, const NewsScreen()),
              child: const Text('More news'),
            ),
          ),
        ],
      ),
    );
  }

  void _hideNews() {
    HapticFeedback.selectionClick();
    unawaited(HomeMemory.instance.setNewsOn(false));
    unawaited(AppFeedback.showUndo(context, 'News hidden from Home',
        onUndo: () => unawaited(HomeMemory.instance.setNewsOn(true))));
  }

  /// One real thing to try: a question runs with a tap; an action opens
  /// the mic for the user's own words.
  Widget _tip(HomeExtra e) {
    final t = e.tip!;
    final busy = _busy.contains(e.id);
    final ask = t.ask;
    final primary = ask != null
        ? _Act('Try it', Icons.graphic_eq_rounded, () async {
            _do.ask(ask);
            return true;
          })
        : _Act('Talk to me', Icons.mic_rounded, () async {
            _do.talk();
            return true;
          });
    final later = _Act('Not now', null, () async {
      unawaited(HomeMemory.instance.hide(e.id));
      return true;
    });
    return Semantics(
      container: true,
      label: 'Try asking: ${t.say}. ${t.why}',
      child: GlassCard(
        padding: const EdgeInsets.fromLTRB(Neon.s4, Neon.s4, Neon.s2, Neon.s1 + 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded, size: 16, color: Neon.violet),
                      const SizedBox(width: 8),
                      Text('Try asking',
                          style: NeonType.eyebrow.copyWith(color: Neon.textLo)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('“${t.say}”',
                      style: NeonType.manrope(NeonType.rowTitle, FontWeight.w600)
                          .copyWith(color: Neon.textHi)),
                  const SizedBox(height: 2),
                  Text(t.why,
                      style: TextStyle(color: Neon.textLo, fontSize: NeonType.footnote)),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _compact(e.id, primary, busy, tone: NeonTone.tip),
                _secondary(e.id, later, busy),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// "5 pm" from "17:00".
  static String _hour(String hhmm) {
    final n = (int.tryParse(hhmm.split(':').first) ?? 0) % 24;
    return '${n % 12 == 0 ? 12 : n % 12} ${n < 12 ? 'am' : 'pm'}';
  }

  /// A quiet tonal tile (premium pass): the kind in its colour, softly.
  static Widget _iconTile(IconData icon, Color tint, double size) =>
      GlassTile(icon, tint, size: size);

  // ── buttons ──────────────────────────────────────────────────────────

  (_Act?, _Act?) _buttons(HomeCard c) {
    final notNow = _Act('Not now', null, () async {
      _do.hide(c);
      return true;
    });
    switch (c.kind) {
      case HomeCardKind.meeting:
        // PREPARE (2026-09-30): Meeting Prep for this event — who is in
        // it, last time, promises, talking points — instead of a spoken
        // question.
        return (
          _Act('Prepare', Icons.groups_rounded, () async {
            unawaited(_do
                .prepareMeeting(context, c.item!)
                .catchError((Object e) => _said("Couldn't open that.", e)));
            return true;
          }),
          notNow,
        );
      case HomeCardKind.reminder:
        // Without an id there is nothing on the server to change.
        if (c.item?.id == null) return (null, notNow);
        return (
          _Act('Done', Icons.check_rounded, () => _done(c)),
          _Act('Later', Icons.schedule_rounded, () => _later(c)),
        );
      case HomeCardKind.promise:
        return (_Act('Done', Icons.check_rounded, () => _done(c)), notNow);
      case HomeCardKind.missedCall:
        final call = c.call!;
        return (
          call.dialable.isEmpty
              ? null
              : _Act('Call back', Icons.call_rounded, () async {
                  _do.callBack(call);
                  return true;
                }),
          _Act('Not now', null, () async {
            _do.dropCall(call);
            return true;
          }),
        );
      case HomeCardKind.message:
        return (
          _Act('Hear it', Icons.volume_up_rounded, () async {
            await _do.hearMessages();
            return true;
          }),
          notNow,
        );
      case HomeCardKind.birthday:
        final who = c.person ?? c.title;
        return (
          _Act('Send wishes', Icons.celebration_rounded, () async {
            _do.ask('Help me wish $who: it is ${c.title} '
                '${c.reason.toLowerCase()}. Draft a warm message and ask me '
                'before sending it.');
            return true;
          }),
          notNow,
        );
      case HomeCardKind.payment:
        return (
          _Act('Open Finance', Icons.account_balance_wallet_rounded, () async {
            _do.open(context, const FinanceScreen());
            return true;
          }),
          notNow,
        );
      case HomeCardKind.getStarted:
        return (
          _Act('Talk to me', Icons.mic_rounded, () async {
            _do.talk();
            return true;
          }),
          notNow,
        );
    }
  }

  Future<bool> _done(HomeCard c) async {
    final ok = c.promise != null
        ? await _do.completePromise(c.promise!)
        : await _do.completeReminder(c.item!);
    if (!ok) _failed("Couldn't mark it done.", () => _run(c.id, () => _done(c)));
    return ok;
  }

  /// An hour after it was due (or from now, if that has passed), on the
  /// next five minutes.
  Future<bool> _later(HomeCard c) async {
    final now = widget.clock();
    final from = c.at != null && c.at!.isAfter(now) ? c.at! : now;
    final raw = from.add(const Duration(hours: 1));
    final to = DateTime(raw.year, raw.month, raw.day, raw.hour,
        (raw.minute / 5).ceil() * 5);
    final ok = await _do.moveReminder(c.item!, to);
    if (!mounted) return ok;
    if (ok) {
      AppFeedback.show('Moved to ${CallHistory.clock(to)}',
          context: context, tone: FeedbackTone.success);
    } else {
      _failed("Couldn't move it.", () => _run(c.id, () => _later(c)));
    }
    return ok;
  }

  void _failed(String what, VoidCallback retry) {
    if (!mounted) return;
    AppFeedback.showRetry('$what Check your connection.',
        context: context, onRetry: retry);
  }

  /// Runs a button. Only one request per card at a time; the button shows
  /// it is working until the server answers.
  Future<void> _run(String id, Future<bool> Function() act) async {
    if (_busy.contains(id)) return;
    // The touch is answered now (owner, 2026-09-30: "buttons are laggy"):
    // the tick and the card's change come first, the server after.
    HapticFeedback.lightImpact();
    setState(() => _busy.add(id));
    try {
      await act();
    } catch (e) {
      AppLog.add('home', 'button on $id failed: $e');
      _failed("That didn't work.", () => _run(id, act));
    }
    if (!mounted) return;
    setState(() => _busy.remove(id));
  }

  /// [onBrand]: on the violet Next card — a white pill with violet words.
  Widget _primary(String id, _Act a, bool busy, {bool onBrand = false}) {
    final bg = onBrand ? Colors.white : Neon.accentFill;
    final fg = onBrand ? Neon.accentFill : Neon.onAccent;
    return FilledButton.icon(
      onPressed: busy ? null : () => _run(id, a.run),
      icon: busy
          ? const NeonLoader.inline(size: 16, semanticLabel: 'Working')
          : Icon(a.icon ?? Icons.arrow_forward_rounded, size: 18),
      label: Text(a.label),
      style: FilledButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        disabledBackgroundColor: bg.withValues(alpha: 0.6),
        disabledForegroundColor: fg,
        minimumSize: const Size(48, 50),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: const StadiumBorder(),
        textStyle: NeonType.manrope(NeonType.rowTitle, FontWeight.w800),
      ),
    );
  }

  /// [onBrand]: on the violet Next card — white words on a white wash.
  Widget _secondary(String id, _Act a, bool busy, {bool onBrand = false}) =>
      TextButton(
        onPressed: busy ? null : () => _run(id, a.run),
        style: TextButton.styleFrom(
          foregroundColor: onBrand ? Colors.white : Neon.textHi,
          backgroundColor: onBrand ? Colors.white.withValues(alpha: 0.16) : null,
          minimumSize: const Size(48, 50),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: const StadiumBorder(),
          textStyle: NeonType.manrope(NeonType.rowTitle, FontWeight.w700),
        ),
        child: Text(a.label),
      );

  Widget _compact(String id, _Act a, bool busy, {NeonTone tone = NeonTone.brand}) =>
      Padding(
        padding: const EdgeInsets.only(right: 6),
        child: NeonPill(
          label: a.label,
          icon: a.icon,
          tone: tone,
          busy: busy,
          quiet: true,
          onPressed: () => _run(id, a.run),
        ),
      );

  /// What a card's light says it is (NeonTone): information in blue,
  /// something to act on in magenta, something to discover in purple.
  static NeonTone _toneOf(HomeCardKind k) => switch (k) {
        HomeCardKind.meeting => NeonTone.info,
        HomeCardKind.reminder || HomeCardKind.promise || HomeCardKind.birthday => NeonTone.action,
        HomeCardKind.missedCall => NeonTone.danger,
        HomeCardKind.message => NeonTone.discovery,
        HomeCardKind.payment => NeonTone.warning,
        HomeCardKind.getStarted => NeonTone.tip,
      };

  // ── looks and words ──────────────────────────────────────────────────

  Widget? _pageFor(HomeCard c) => switch (c.kind) {
        HomeCardKind.reminder => const RemindersScreen(),
        HomeCardKind.meeting ||
        HomeCardKind.promise ||
        HomeCardKind.birthday =>
          const CalendarScreen(),
        HomeCardKind.payment => const FinanceScreen(),
        _ => null,
      };

  static String _spoken(HomeCard c) =>
      '${_kindName(c.kind)}: ${c.title}. ${c.reason}'
      '${c.detail == null ? '' : '. ${c.detail}'}';

  static String _kindName(HomeCardKind k) => switch (k) {
        HomeCardKind.meeting => 'Meeting',
        HomeCardKind.reminder => 'Reminder',
        HomeCardKind.promise => 'Promise',
        HomeCardKind.missedCall => 'Missed call',
        HomeCardKind.message => 'Message',
        HomeCardKind.birthday => 'Birthday',
        HomeCardKind.payment => 'Bill',
        HomeCardKind.getStarted => 'Get started',
      };

  static (IconData, Color) _look(HomeCardKind k) => switch (k) {
        HomeCardKind.meeting => (Icons.groups_rounded, Neon.accentA),
        HomeCardKind.reminder =>
          (Icons.notifications_active_rounded, Neon.accentA),
        HomeCardKind.promise => (Icons.handshake_rounded, Neon.accentB),
        HomeCardKind.missedCall => (Icons.phone_missed_rounded, Neon.accentB),
        HomeCardKind.message => (Icons.mark_email_unread_rounded, Neon.accentC),
        HomeCardKind.birthday => (Icons.cake_rounded, Neon.accentB),
        HomeCardKind.payment => (Icons.receipt_long_rounded, Neon.accentD),
        HomeCardKind.getStarted => (Icons.graphic_eq_rounded, Neon.accentA),
      };

  static Widget _tile(HomeCardKind k, double size) {
    final (icon, tint) = _look(k);
    return GlassTile(icon, tint, size: size);
  }

}

/// A button: what it says, its icon, and what it does (true when done).
class _Act {
  _Act(this.label, this.icon, this.run);
  final String label;
  final IconData? icon;
  final Future<bool> Function() run;
}

/// A card that opens its page when tapped (the buttons on it win their
/// own taps). Dips a little under the finger, like every tappable surface.
class _Tap extends StatelessWidget {
  const _Tap({required this.onTap, required this.child});
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (onTap == null) return child;
    return Semantics(
      onTapHint: 'open',
      child: PressScale(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: child,
        ),
      ),
    );
  }
}

/// Nothing needs the user: says so, briefly — what is useful instead
/// follows it (home_extras.dart).
class _AllClear extends StatelessWidget {
  const _AllClear({required this.later});

  /// Something is still on today's list, just not now.
  final bool later;

  @override
  Widget build(BuildContext context) {
    final ink = NeonTone.success.ink;
    // CALM, NOT LOUD (2026-09-30, premium pass): glass with a faint green
    // light in its corner and a small ring — done and well, felt rather
    // than announced. No neon rim, no halo, no second icon.
    return GlassCard(
      wash: ink,
      padding: const EdgeInsets.fromLTRB(Neon.s5, Neon.s5, Neon.s5, Neon.s5),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ink.withValues(alpha: 0.10),
                border: Border.all(color: ink.withValues(alpha: 0.32)),
              ),
              child: Icon(Icons.check_rounded, size: 22, color: ink),
            ),
          ),
          const SizedBox(width: Neon.s4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("You're all clear",
                    style: NeonType.glassTitle.copyWith(color: Neon.textHi)),
                const SizedBox(height: 2),
                Text(
                  later ? 'Nothing needs you right now.' : 'Nothing needs you today.',
                  style: TextStyle(color: Neon.textLo, fontSize: NeonType.body, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The shape of the feed — the Now card and three lines — breathing gently
/// while the first brief loads. Still under reduced motion.
class _Skeleton extends StatefulWidget {
  const _Skeleton();

  @override
  State<_Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<_Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));
  late final Animation<double> _breath =
      Tween(begin: 0.45, end: 1.0).animate(_pulse);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _pulse
        ..stop()
        ..value = 1.0;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Widget _bar(double widthFactor, double height) => FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: widthFactor,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: Neon.textDim.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading your day',
      child: RepaintBoundary(
        child: FadeTransition(
          opacity: _breath,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Neon.surface,
                  borderRadius: BorderRadius.circular(Neon.rCard),
                  border: Border.all(color: Neon.hairline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _bar(0.3, 14),
                    const SizedBox(height: 14),
                    _bar(0.8, 16),
                    const SizedBox(height: 8),
                    _bar(0.5, 12),
                    const SizedBox(height: 16),
                    _bar(0.35, 36),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _bar(0.25, 14),
              for (final w in const [0.7, 0.55, 0.6]) ...[
                const SizedBox(height: 16),
                _bar(w, 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});
  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
