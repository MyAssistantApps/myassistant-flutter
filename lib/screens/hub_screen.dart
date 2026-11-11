import '../features/games/games.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../design/apple_kit.dart';
import '../design/dock_metrics.dart';
import '../design/neon_tokens.dart';
import 'clients_screen.dart';
import 'connected_apps_screen.dart';
import 'calendar_screen.dart';
import 'calls_screen.dart';
import 'documents_screen.dart';
import 'finance_screen.dart';
import 'phone/call_notes_screen.dart';
import 'reminders_screen.dart';
import 'shortcuts_screen.dart';
import 'news_screen.dart';
import 'email_setup_screen.dart';
import 'features_screen.dart';
import 'stocks_screen.dart';
import 'studio/studio_screen.dart';
import '../features/home/try_now_cards.dart';
import '../features/shopping/shopping_list_screen.dart';
import '../design/motion.dart';

/// HUB TAB — every feature as a front door.
///
/// Apple-style grouped lists (the iOS Settings pattern): plain ground,
/// white rounded groups, one row per destination with a small solid-color
/// icon tile, hairline separators and a chevron. No decoration that
/// doesn't inform — the calm look is the design.
class HubScreen extends StatefulWidget {
  const HubScreen({super.key});

  @override
  State<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends State<HubScreen> {
  final _featureQuery = TextEditingController();
  bool _foundFeature = false;

  @override
  void dispose() {
    _featureQuery.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _foundFeature = false;
    return SafeArea(
      bottom: false,
      child: ListView(
        // Scrolling the list puts the keyboard away, as on iOS.
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        // The last row clears the dock and the mic on every phone (a fixed
        // 120 left it under the mic with 3-button navigation).
        padding: EdgeInsets.fromLTRB(16, 18, 16, Dock.clearance(context)),
        children: [
          // The same large title every tab uses.
          const LargeTitle('Hub'),
          // TRY NOW, moved here from Home (client, 2026-11-05): clothes,
          // haircut, jewellery and custom try-ons.
          if (_featureQuery.text.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 6),
              child: TryNowSection(
                  onOpen: (page) => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => page))),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: 20, top: 8),
            child: TextField(
              controller: _featureQuery,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              style: TextStyle(color: Neon.textHi, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Find a feature',
                hintStyle: TextStyle(color: Neon.textDim),
                prefixIcon: Icon(Icons.search_rounded, color: Neon.textLo),
                suffixIcon: _featureQuery.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: Icon(Icons.close_rounded, color: Neon.textLo),
                        onPressed: () {
                          FocusScope.of(context).unfocus();
                          _featureQuery.clear();
                          setState(() {});
                        },
                      ),
                filled: true,
                fillColor: Neon.surface,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Neon.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Neon.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide:
                      BorderSide(color: Neon.cyan.withValues(alpha: .7)),
                ),
              ),
            ),
          ),
          _group(context, 'Your day', [
            // The month, moved off Home (2026-09-29): Home shows what is
            // next; everything with a date lives here.
            _Row(
              'Calendar',
              'Reminders, bills and birthdays — by date',
              Icons.calendar_month_rounded,
              Neon.accentF,
              (c) => const CalendarScreen(),
            ),
            // "Office mode" (build 120): made by voice, run from here.
            _Row(
              'Shortcuts',
              'One word does several things — say its name',
              Icons.bolt_rounded,
              Neon.accentD,
              (c) => const ShortcutsScreen(),
            ),
            _Row(
              'Reminders',
              'Everything you asked me to remember',
              Icons.notifications_active_rounded,
              Neon.accentA,
              (c) => const RemindersScreen(),
            ),
            // One list for anything to buy (build 124): groceries, a dress,
            // a charger — "add this to my shopping list" in any conversation.
            _Row(
              'Shopping list',
              'Anything to buy — say “add this to my shopping list”',
              Icons.shopping_basket_rounded,
              Neon.accentE,
              (c) => const ShoppingListScreen(),
              trailing: const ShoppingCountBadge(),
            ),
          ]),
          // News as cards, by topic (2026-09-25).
          _group(context, 'Stay informed', [
            _Row(
              'News',
              "Today's stories as cards — swipe through, tap to read",
              Icons.newspaper_rounded,
              Neon.accentC,
              (c) => const NewsScreen(),
            ),
          ]),
          _group(context, 'Phone', [
            _Row(
              'Calls',
              'Calls I made for you — and what they said back',
              Icons.phone_in_talk_rounded,
              Neon.accentD,
              (c) => const CallsScreen(),
            ),
            _Row(
              'Call notes',
              'Notes and reminders from your recorded calls',
              Icons.call_rounded,
              Neon.accentE,
              (c) => const CallNotesScreen(),
            ),
            _Row(
              'Email',
              'Link your mailbox — then ask me to read or send mail',
              Icons.alternate_email_rounded,
              Neon.accentF,
              (c) => const EmailSetupScreen(),
            ),
          ]),
          _group(context, 'Connections', [
            _Row(
              'Connected apps',
              'Your notes app, mail and more — in one place',
              Icons.hub_rounded,
              Neon.accentA,
              (c) => const ConnectedAppsScreen(),
            ),
          ]),
          _group(context, 'Practice', [
            _Row(
              'Clients & patients',
              'Case files, notes and their documents',
              Icons.folder_shared_rounded,
              Neon.accentF,
              (c) => const ClientsScreen(),
            ),
            _Row(
              'My documents',
              'Your own scans, IDs and files',
              Icons.description_rounded,
              Neon.accentC,
              (c) => const DocumentsScreen(),
            ),
          ]),
          _group(context, 'Looks', [
            _Row(
              'Style Studio',
              'Try on outfits and hairstyles on your own photo',
              Icons.auto_awesome_rounded,
              Neon.accentB,
              (c) => const StudioScreen(),
            ),
          ]),
          _group(context, 'Money', [
            _Row(
              'Finance',
              'EMIs, incomes and payoff plans',
              Icons.account_balance_wallet_rounded,
              Neon.accentB,
              (c) => const FinanceScreen(),
            ),
            _Row(
              'Markets',
              'Live stocks and analysis',
              Icons.trending_up_rounded,
              Neon.accentD,
              (c) => const StocksScreen(),
            ),
          ]),
          // THE GAMES HUB (client, 2026-11-01): short games of our own,
          // offline (features/games/games.dart).
          _group(context, 'Games', [
            _Row(
              'Memory pairs',
              'Flip the cards and find every pair',
              Icons.grid_view_rounded,
              Neon.accentB,
              (c) => const MemoryPairsScreen(),
            ),
            _Row(
              'Quick maths',
              'As many sums as you can in 60 seconds',
              Icons.calculate_rounded,
              Neon.accentA,
              (c) => const QuickMathsScreen(),
            ),
            _Row(
              'Tic-tac-toe with Maya',
              'Three in a row — she plays to win',
              Icons.tag_rounded,
              Neon.accentD,
              (c) => const TicTacToeScreen(),
            ),
            _Row(
              'Light trail',
              'Watch the lights, repeat the trail',
              Icons.lightbulb_rounded,
              Neon.accentC,
              (c) => const LightTrailScreen(),
            ),
          ]),
          _group(context, 'App', [
            _Row(
              'Features',
              "What's live, what's being built, what's next",
              Icons.new_releases_rounded,
              Neon.accentC,
              (c) => const FeaturesScreen(),
            ),
          ]),
          if (_featureQuery.text.trim().isNotEmpty && !_foundFeature)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
              child: Text(
                'No features found. Try a shorter search.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Neon.textLo, fontSize: 14),
              ),
            ),
        ],
      ),
    );
  }

  // THE SAME LABEL AND CARD AS THE YOU TAB (2026-09-24). Hub drew its own
  // section label (accent, 11.5 sp, heavy, wide tracking) beside You's
  // grey one on the neighbouring tab, and its groups had no edge on the
  // ground. GroupLabel and GroupedCard are the shared pieces: one label
  // style, a hairline edge, and the separators inset past the icon tile.
  Widget _group(BuildContext context, String title, List<_Row> rows) {
    final query = _featureQuery.text.trim().toLowerCase();
    final matches = query.isEmpty
        ? rows
        : rows
            .where((r) =>
                '$title ${r.title} ${r.subtitle}'.toLowerCase().contains(query))
            .toList();
    if (matches.isEmpty) return const SizedBox.shrink();
    _foundFeature = true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GroupLabel(title),
          GroupedCard(
            dividerInset: 60,
            children: [for (final r in matches) _rowTile(context, r)],
          ),
        ],
      ),
    );
  }

  // THE ROW DIPS NOW (2026-09-30): the same 0.985 dip and light tick as
  // every AppleRow — a full-width row moves its edges three times as far
  // as a card, so the dip is a third of a card's. (2026-09-24 had no dip:
  // the old 0.97 pulled the row 8 dp in from its card's edges.)
  Widget _rowTile(BuildContext context, _Row r) {
    return PressScale(
      scale: 0.985,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          FocusScope.of(context).unfocus();
          Navigator.of(context).push(MaterialPageRoute(builder: r.builder));
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 11, 12, 11),
          child: Row(
            children: [
              // The shared lit tile (2026-09-30): the brand-built gradient
              // plus the glass sheen every other tile in the app now has.
              IconTile(r.icon, r.color, size: 36),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // The same words become the page's title: they fly into
                    // its bar as it pushes in (motion.dart, titleHeroTag).
                    Hero(
                      tag: titleHeroTag(r.title),
                      flightShuttleBuilder: titleFlight,
                      child: Text(
                        r.title,
                        style: NeonType.row.copyWith(color: Neon.textHi),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      r.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Neon.textLo,
                          fontSize: NeonType.footnote,
                          height: 1.3),
                    ),
                  ],
                ),
              ),
              if (r.trailing != null) ...[
                const SizedBox(width: 8),
                r.trailing!
              ],
              Icon(Icons.chevron_right_rounded, color: Neon.textDim, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget Function(BuildContext) builder;

  /// A live count beside the chevron (the shopping list's things to buy).
  final Widget? trailing;
  const _Row(this.title, this.subtitle, this.icon, this.color, this.builder,
      {this.trailing});
}
