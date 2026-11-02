import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/neon_tokens.dart';
import '../../screens/pro_assistant_screen.dart';

/// THE PROFESSIONAL ASSISTANTS, AS BANNERS (owner, 2026-11-02: "need sliding
/// banner like that [Order and shop] and also add a photo of that profession
/// people"). One card per profession — the person on the right, fading into
/// the card; the name, what it does and a button on the left — sliding like
/// the shop banners, every 7 seconds or by swipe.
class ProBanners extends StatefulWidget {
  const ProBanners({super.key, required this.onOpen});

  /// Opens the profession's page.
  final void Function(ProKind kind) onOpen;

  @override
  State<ProBanners> createState() => _ProBannersState();
}

class _ProBannersState extends State<ProBanners> {
  final _page = PageController(viewportFraction: 0.9);
  int _at = 0;
  Timer? _auto;
  bool _held = false;

  static const _kinds = ProKind.values;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _arm();
  }

  void _arm() {
    _auto?.cancel();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still) return;
    _auto = Timer.periodic(const Duration(seconds: 7), (_) {
      if (!mounted || _held || !_page.hasClients) return;
      _page.animateToPage((_at + 1) % _kinds.length,
          duration: const Duration(milliseconds: 560),
          curve: Curves.easeOutCubic);
    });
  }

  @override
  void dispose() {
    _auto?.cancel();
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text('Your work assistants',
              style: NeonType.eyebrow.copyWith(color: Neon.textLo)),
        ),
        Listener(
          onPointerDown: (_) => _held = true,
          onPointerUp: (_) => _held = false,
          onPointerCancel: (_) => _held = false,
          child: SizedBox(
            height: 184,
            child: PageView.builder(
              controller: _page,
              padEnds: false,
              itemCount: _kinds.length,
              onPageChanged: (i) => setState(() => _at = i),
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(right: 10),
                child: ProBannerCard(
                  profile: ProProfile.of(_kinds[i]),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    widget.onOpen(_kinds[i]);
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _kinds.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _at ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: i == _at
                      ? ProProfile.of(_kinds[i]).tint()
                      : Neon.textDim.withValues(alpha: 0.45),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// One profession's banner.
class ProBannerCard extends StatelessWidget {
  const ProBannerCard({super.key, required this.profile, required this.onTap});
  final ProProfile profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final c = p.tint();
    final night = Color.lerp(Neon.bg, Colors.black, 0.35)!;
    final r = BorderRadius.circular(22);
    return Semantics(
      button: true,
      label: '${p.name} Assistant. ${p.lead}',
      excludeSemantics: true,
      child: Material(
        borderRadius: r,
        clipBehavior: Clip.antiAlias,
        color: night,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: r,
              border: Border.all(color: c.withValues(alpha: 0.45)),
            ),
            child: LayoutBuilder(builder: (context, box) => Stack(
              fit: StackFit.expand,
              children: [
                // The person, on the right 52%.
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: 0,
                  width: box.maxWidth * 0.56,
                  // The photo's own left edge fades out, so no seam shows
                  // whatever the photo's background.
                  child: ShaderMask(
                    blendMode: BlendMode.dstIn,
                    shaderCallback: (r) => const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      stops: [0, 0.45, 1],
                      colors: [Colors.transparent, Colors.white, Colors.white],
                    ).createShader(r),
                    child: Image.asset(p.photo,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        gaplessPlayback: true),
                  ),
                ),
                // The card's night, washing over the photo from the left,
                // tinted in the profession's colour.
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      stops: const [0, 0.5, 0.75],
                      colors: [
                        c.withValues(alpha: 0.24),
                        c.withValues(alpha: 0.10),
                        c.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
                // A soft floor, so the photo sits in the card.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 46,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          night.withValues(alpha: 0),
                          night.withValues(alpha: 0.6)
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: 0.6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: c.withValues(alpha: 0.22),
                              ),
                              child: Icon(p.icon, size: 15, color: c),
                            ),
                            const SizedBox(width: 8),
                            Text('ASSISTANT',
                                style: NeonType.manrope(11, FontWeight.w800)
                                    .copyWith(
                                        color: Color.lerp(c, Colors.white, 0.3),
                                        letterSpacing: 1.4)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: NeonType.manrope(22, FontWeight.w800)
                                .copyWith(
                                    color: Neon.textHi,
                                    letterSpacing: -0.3,
                                    height: 1.1)),
                        const SizedBox(height: 4),
                        Expanded(
                          child: Text(p.lead,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: Neon.textLo,
                                  fontSize: 13,
                                  height: 1.3)),
                        ),
                        Container(
                          padding: const EdgeInsets.fromLTRB(14, 7, 10, 7),
                          decoration: BoxDecoration(
                            color: c,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                  color: c.withValues(alpha: 0.45),
                                  blurRadius: 14,
                                  spreadRadius: -4)
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Open',
                                  style: NeonType.manrope(13, FontWeight.w800)
                                      .copyWith(color: _ink(c))),
                              const SizedBox(width: 4),
                              Icon(Icons.arrow_forward_rounded,
                                  size: 16, color: _ink(c)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )),
          ),
        ),
      ),
    );
  }
}

/// Black or white text, whichever reads on [c].
Color _ink(Color c) => c.computeLuminance() > 0.45 ? Colors.black : Colors.white;
