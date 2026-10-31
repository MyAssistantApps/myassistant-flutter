import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../design/dock_metrics.dart';
import '../design/motion.dart';
import '../design/neon_tokens.dart';
import '../features/home/home_cards.dart';
import '../features/home/quote_cards_sheet.dart';
import '../features/home/quote_of_day.dart';
import '../widgets/call_led.dart';
import 'search_screen.dart';

/// HOME TAB — what needs you now (2026-09-29).
///
/// The greeting, then one Now card, up to two smaller ones, the next three
/// things of the day and quick actions (features/home). The mic below is
/// how the user acts on any of it. The month moved to its own page.
class HomeDashboard extends StatelessWidget {
  const HomeDashboard({super.key, this.clock = DateTime.now});

  /// Test seam: the time the greeting, the date and the feed are for.
  final DateTime Function() clock;

  @override
  Widget build(BuildContext context) {
    final now = clock();
    const wk = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
      'Sunday'
    ];
    const mo = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    // THE HEADER SCROLLS WITH THE FEED (2026-09-24, home2.png). Pinned, it
    // took ~250 dp of the screen, and the feed scrolled up under the quote
    // with no gap or ground — the suggestion chips looked like they slid
    // beneath its text. Now greeting, date and quote are simply the top of
    // the list; only the call light stays put.
    final header = Reveal(
        child: Builder(
      builder: (context) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // THE APP'S NAME, LIT (owner, 2026-10-31: no "Good evening",
            // no user name — just MyAssistant), in the light the name had
            // (cyan into magenta), search in a lit ring beside it.
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    label: 'MyAssistant',
                    child: ExcludeSemantics(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: ShaderMask(
                          blendMode: BlendMode.srcIn,
                          shaderCallback: (r) => LinearGradient(
                            colors: [Neon.cyan, Neon.violet, Neon.pink],
                          ).createShader(r),
                          child: Text(
                            'MyAssistant',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: NeonType.largeTitle + 6,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.8,
                              height: 1.1,
                              color: Colors.white,
                              // its own glow, tinted by the gradient
                              shadows: [
                                Shadow(
                                    color: Colors.white.withValues(alpha: 0.55),
                                    blurRadius: 18),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                _SearchRing(
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SearchScreen())),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // The date alone (owner, 2026-09-30: the weather chip beside
            // it "looks bad"). Rain or heat worth knowing about still gets
            // its own card in the feed.
            Text(
              '${wk[now.weekday - 1]}, ${now.day} ${mo[now.month - 1]}',
              style: TextStyle(color: Neon.textLo, fontSize: NeonType.body),
            ),
            // THE DAY'S LINE, right under the date (owner, 2026-09-30: "need
            // motivational quotes right below the date"). No card, no tint:
            // an accent rule down the left, brighter ink, a size up — it
            // reads as something meant, without a background of any kind.
            // A NEW LINE EVERY DAY, AND ITS PICTURES (2026-10-18): the line
            // comes from the server (the same for everyone), the built-in
            // rotation when it has none yet; a tap opens the day's images
            // to share.
            const SizedBox(height: 16),
            ValueListenableBuilder<QuoteDay?>(
              valueListenable: QuoteOfDay.current,
              builder: (context, _, __) {
                QuoteOfDay.ensureFresh();
                return Semantics(
                  button: true,
                  hint: "Opens today's quote as images to share",
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => showQuoteCardsSheet(context),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            width: 3,
                            decoration: BoxDecoration(
                              gradient: Neon.gBrand,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              QuoteOfDay.line(),
                              style: NeonType.manrope(NeonType.rowTitle, FontWeight.w500)
                                  .copyWith(color: Neon.textHi, height: 1.4, letterSpacing: 0.1),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: Icon(Icons.image_outlined, size: 18, color: Neon.textLo),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    ));
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Shows only while the assistant is actually on a call.
          const CallLed(),
          // Missed calls are cards in the feed now, ranked with the rest.
          Expanded(
            child: HomeFeedView(
              leading: header,
              clock: clock,
              // The last card clears the dock and the mic on every phone.
              padding: EdgeInsets.fromLTRB(20, 18, 20, Dock.clearance(context)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchRing extends StatelessWidget {
  const _SearchRing({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          // A hairline of the app's light, no halo (premium pass).
          colors: [for (final c in Neon.rim) c.withValues(alpha: 0.45)],
        ),
        boxShadow: Neon.lift,
      ),
      child: Padding(
        padding: const EdgeInsets.all(1),
        child: Material(
          color: Neon.surface,
          shape: const CircleBorder(),
          child: IconButton(
            tooltip: 'Search',
            onPressed: onTap,
            icon: Icon(Icons.search_rounded, color: Neon.textHi, size: 24),
          ),
        ),
      ),
    );
  }
}
