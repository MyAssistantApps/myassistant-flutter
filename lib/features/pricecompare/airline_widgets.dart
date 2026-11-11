import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/neon_scaffold.dart';
import '../../design/neon_tokens.dart';
import 'airlines.dart';
import 'price_widgets.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  THE AIRLINE BANNER (owner, 2026-11-04): the top of Flight compare
///  slides through the airlines on its own — IndiGo, Air India, Akasa,
///  Emirates… — every 4 s. A finger on it pauses it; "Remove animations"
///  stops it. Tapping opens AirlinesScreen on that airline.
/// ─────────────────────────────────────────────────────────────────────────
class AirlineCarousel extends StatefulWidget {
  const AirlineCarousel({super.key, required this.onOpen, this.height = 170});

  /// Opens the airlines page at [index].
  final void Function(int index) onOpen;
  final double height;

  @override
  State<AirlineCarousel> createState() => _AirlineCarouselState();
}

class _AirlineCarouselState extends State<AirlineCarousel> {
  static const _every = Duration(seconds: 4);
  final _pages = PageController();
  Timer? _timer;
  int _at = 0;
  bool _held = false;

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pages.dispose();
    super.dispose();
  }

  void _restart() {
    _timer?.cancel();
    _timer = Timer.periodic(_every, (_) => _advance());
  }

  void _advance() {
    if (!mounted || _held || !_pages.hasClients) return;
    if (MediaQuery.of(context).disableAnimations) return;
    _pages.animateToPage((_at + 1) % airlines.length,
        duration: const Duration(milliseconds: 650), curve: Curves.easeInOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Listener(
          onPointerDown: (_) => _held = true,
          onPointerUp: (_) {
            _held = false;
            _restart();
          },
          onPointerCancel: (_) {
            _held = false;
            _restart();
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Neon.rCard),
            child: SizedBox(
              height: widget.height,
              child: PageView.builder(
                controller: _pages,
                itemCount: airlines.length,
                onPageChanged: (i) => setState(() => _at = i),
                itemBuilder: (_, i) => _Slide(airline: airlines[i], onTap: () => widget.onOpen(i)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < airlines.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _at ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: i == _at ? Neon.violet : Neon.textDim.withValues(alpha: 0.45),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Slide extends StatelessWidget {
  const _Slide({required this.airline, required this.onTap});
  final Airline airline;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final a = airline;
    return Semantics(
      button: true,
      label: '${a.name}. ${a.tagline}. Open airline details',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(a.photo, fit: BoxFit.cover, cacheWidth: 1000),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withValues(alpha: 0.78), Colors.black.withValues(alpha: 0.0)],
                  stops: const [0, 0.7],
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(Neon.rPill),
                ),
                child: Text('FIND THE CHEAPEST FLIGHT',
                    style: NeonType.manrope(10, FontWeight.w800).copyWith(color: Colors.white, letterSpacing: 0.9)),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 14,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(a.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: NeonType.manrope(22, FontWeight.w800)
                                .copyWith(color: Colors.white, letterSpacing: -0.5)),
                        Text(a.tagline,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: 12.5)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.black),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
///  THE AIRLINES, IN FULL: one airline per page, swipe for the next — the
///  photo large, then what kind of airline it is, its home airports,
///  alliance, cabins and what is good to know. "Compare fares on <name>"
///  returns the name to Flight compare as the preferred airline.
/// ─────────────────────────────────────────────────────────────────────────
class AirlinesScreen extends StatefulWidget {
  const AirlinesScreen({super.key, this.initial = 0});
  final int initial;

  @override
  State<AirlinesScreen> createState() => _AirlinesScreenState();
}

/// THE LIGHT LOOK (owner, 2026-11-04: "add some white"): the airlines
/// page is white whatever the app theme — the photo on top, the details
/// on a white sheet that rises over it, dark ink, light grey tiles and
/// each airline's own colour as the accent.
abstract final class _Light {
  static const sheet = Colors.white;
  static const ink = Color(0xFF15131D);
  static const inkLo = Color(0xFF545866);
  static const inkDim = Color(0xFF7E8392);
  static const green = Color(0xFF12804A);
  static const blue = Color(0xFF0A6E96);

  /// White with a little of [c] in it.
  static Color wash(Color c, double amount) => Color.alphaBlend(c.withValues(alpha: amount), sheet);

  /// [c] dark enough to read on white (SIA's gold, Akasa's orange).
  static Color readable(Color c) {
    double contrast(Color x) => 1.05 / (x.computeLuminance() + 0.05);
    var h = HSLColor.fromColor(c);
    while (contrast(h.toColor()) < 4.5 && h.lightness > 0.1) {
      h = h.withLightness(h.lightness - 0.03);
    }
    return h.toColor();
  }
}

class _AirlinesScreenState extends State<AirlinesScreen> {
  late final _pages = PageController(initialPage: widget.initial);
  late int _at = widget.initial;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = airlines[_at];
    // The app's own sky behind the page; white only in the middle.
    return NeonScaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Neon.textHi,
        systemOverlayStyle: Neon.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: Neon.violet.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(Neon.rPill),
            border: Border.all(color: Neon.violet.withValues(alpha: 0.45)),
          ),
          child: Text('Airline ${_at + 1} of ${airlines.length}',
              style: NeonType.manrope(13, FontWeight.w700).copyWith(color: Neon.textHi)),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pages,
              itemCount: airlines.length,
              onPageChanged: (i) {
                HapticFeedback.selectionClick();
                setState(() => _at = i);
              },
              itemBuilder: (_, i) => _AirlinePage(airline: airlines[i]),
            ),
          ),
          // The buttons on the app's own colour: dark glass lit with the
          // accent (owner, 2026-11-04: "the bottom in the app's colour").
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.alphaBlend(Neon.violet.withValues(alpha: 0.22), Neon.surface),
                  Color.alphaBlend(Neon.violet.withValues(alpha: 0.10), Neon.bg),
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(top: BorderSide(color: Neon.violet.withValues(alpha: 0.45))),
              boxShadow: Neon.halo(Neon.violet, strength: 0.5),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => openPriceLink(a.website),
                        icon: const Icon(Icons.public_rounded, size: 18),
                        label: const Text('Website'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Neon.textHi,
                          side: BorderSide(color: Neon.violet.withValues(alpha: 0.6), width: 1.4),
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(context, a.name),
                        icon: const Icon(Icons.compare_arrows_rounded, size: 18),
                        label: Text('Compare ${a.name} fares', maxLines: 1, overflow: TextOverflow.ellipsis),
                        style: FilledButton.styleFrom(
                          backgroundColor: Neon.accentFill,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ONE AIRLINE (owner, 2026-11-05: "more images in every airline, the
/// app theme on top, white in the centre with a matching colour"): the
/// top sits on the app's own sky — the airline's name in the app's ink, the
/// photo in a glowing frame and a strip of more photos (fleet and cabins)
/// to tap through; the middle is a white sheet washed with the airline's
/// own colour; the bottom is the app's colour again.
class _AirlinePage extends StatefulWidget {
  const _AirlinePage({required this.airline});
  final Airline airline;

  @override
  State<_AirlinePage> createState() => _AirlinePageState();
}

class _AirlinePageState extends State<_AirlinePage> {
  int _shown = 0;

  void _open(int i) => Navigator.of(context).push(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullPhoto(airline: widget.airline, initial: i),
      ));

  @override
  Widget build(BuildContext context) {
    final a = widget.airline;
    final brand = _Light.readable(a.color);
    final photos = a.photos;
    final shown = photos[_shown];
    final top = MediaQuery.paddingOf(context).top + kToolbarHeight;
    return ListView(
      padding: EdgeInsets.only(top: top + 4),
      children: [
        // ── The top, on the app's sky ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(a.kind.toUpperCase() + (a.alliance.isNotEmpty ? ' · ${a.alliance.toUpperCase()}' : ''),
                  style: NeonType.eyebrow.copyWith(color: Neon.violet, letterSpacing: 1.1)),
              const SizedBox(height: 2),
              Text(a.name,
                  style: NeonType.manrope(30, FontWeight.w800).copyWith(color: Neon.textHi, letterSpacing: -0.8)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Neon.rCard),
              border: Border.all(color: Neon.violet.withValues(alpha: 0.55), width: 1.4),
              boxShadow: Neon.halo(Neon.violet, strength: 0.6),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Neon.rCard - 1),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    GestureDetector(
                      onTap: () => _open(_shown),
                      child: Hero(
                        tag: 'airline-${a.id}-$_shown',
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 260),
                          child: Image.asset(shown.path,
                              key: ValueKey(shown.path),
                              fit: BoxFit.cover,
                              cacheWidth: 1000,
                              width: double.infinity,
                              height: double.infinity),
                        ),
                      ),
                    ),
                    IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
                            stops: const [0, 0.45],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 10,
                      child: IgnorePointer(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Text(shown.caption,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: NeonType.manrope(13.5, FontWeight.w700).copyWith(color: Colors.white)),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(Neon.rPill),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.zoom_out_map_rounded, size: 12, color: Colors.white),
                                  const SizedBox(width: 4),
                                  Text('${_shown + 1}/${photos.length}',
                                      style: const TextStyle(color: Colors.white, fontSize: 11)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // More photos: tap one to show it above.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (var i = 0; i < photos.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: _thumb(photos[i], i, a.name)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        // ── The middle: white, washed with the airline's colour ──
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: _Light.sheet,
            borderRadius: BorderRadius.circular(28),
            border: Border(top: BorderSide(color: a.color, width: 4)),
            boxShadow: [
              BoxShadow(color: a.color.withValues(alpha: 0.30), blurRadius: 28, offset: const Offset(0, 10)),
            ],
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_Light.wash(a.color, 0.16), _Light.sheet, _Light.sheet, _Light.wash(a.color, 0.08)],
                stops: const [0, 0.22, 0.85, 1],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The name is already on top; the sheet opens with the line.
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: 6,
                          decoration: BoxDecoration(color: a.color, borderRadius: BorderRadius.circular(3)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(a.tagline,
                              style: NeonType.manrope(18, FontWeight.w800)
                                  .copyWith(color: _Light.ink, letterSpacing: -0.3, height: 1.3)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _pill(a.kind, a.kind == 'Low-cost' ? _Light.green : brand),
                      if (a.alliance.isNotEmpty) _pill(a.alliance, _Light.blue),
                      _pill(a.aircraft, brand),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _fact(Icons.location_city_rounded, 'Home airports', a.hubs.join(', '), brand),
                  _fact(Icons.airline_seat_recline_extra_rounded, 'Cabins', a.cabins.join(' · '), brand),
                  const SizedBox(height: 4),
                  _card(
                    brand: brand,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _eyebrow('GOOD TO KNOW'),
                        const SizedBox(height: 8),
                        for (final h in a.highlights)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Icon(Icons.check_circle_rounded, size: 16, color: brand),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(h, style: const TextStyle(color: _Light.ink, fontSize: 14, height: 1.35)),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _AircraftCard(airline: a, brand: brand),
                ],
              ),
            ),
          ),
        ),
        // Below the white: the app's own colour again.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Text(
              'Tap a photo to see it full screen; swipe for more airlines. Aircraft sizes are the maker\'s figures; '
              'seats vary by plane. Details can change — check with the airline before you fly.',
              style: TextStyle(color: Neon.textDim, fontSize: NeonType.caption, height: 1.4)),
        ),
      ],
    );
  }

  Widget _thumb(AirlinePhoto p, int i, String airline) {
    final on = i == _shown;
    return Semantics(
      button: true,
      selected: on,
      label: '$airline photo ${i + 1}: ${p.caption}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          if (on) {
            _open(i);
          } else {
            setState(() => _shown = i);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: on ? Neon.violet : Neon.textDim.withValues(alpha: 0.25), width: on ? 2 : 1),
            boxShadow: on ? Neon.halo(Neon.violet, strength: 0.4) : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: on ? 1 : 0.65,
                child: Image.asset(p.path, fit: BoxFit.cover, cacheWidth: 240),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pill(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(Neon.rPill),
          border: Border.all(color: c.withValues(alpha: 0.35)),
        ),
        child: Text(t, style: NeonType.manrope(12.5, FontWeight.w800).copyWith(color: c)),
      );

  Widget _fact(IconData i, String label, String value, Color brand) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: brand.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)),
              child: Icon(i, size: 19, color: brand),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _eyebrow(label.toUpperCase()),
                  const SizedBox(height: 2),
                  Text(value, style: NeonType.manrope(14.5, FontWeight.w700).copyWith(color: _Light.ink)),
                ],
              ),
            ),
          ],
        ),
      );
}

Widget _eyebrow(String t) =>
    Text(t, style: NeonType.eyebrow.copyWith(color: _Light.inkDim, fontSize: 10.5, letterSpacing: 0.9));

/// A light card on the white sheet, edged in the airline's colour.
Widget _card({required Widget child, required Color brand}) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _Light.sheet,
        borderRadius: BorderRadius.circular(Neon.rCard),
        border: Border.all(color: brand.withValues(alpha: 0.20)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: child,
    );

/// ABOUT THIS AIRCRAFT: the plane in the photo — seats, engines, size,
/// range, speed, what the airline flies it on, and one fact.
class _AircraftCard extends StatelessWidget {
  const _AircraftCard({required this.airline, required this.brand});
  final Airline airline;

  /// The airline's colour, dark enough for white.
  final Color brand;

  @override
  Widget build(BuildContext context) {
    final p = airline.plane;
    final specs = <(IconData, String, String)>[
      (Icons.event_seat_rounded, 'Seats', p.seats),
      (Icons.settings_rounded, 'Engines', p.engines),
      (Icons.straighten_rounded, 'Length', p.length),
      (Icons.open_in_full_rounded, 'Wingspan', p.wingspan),
      (Icons.public_rounded, 'Range', p.range),
      (Icons.speed_rounded, 'Cruise speed', p.speed),
    ];
    return _card(
      brand: brand,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _eyebrow('ABOUT THIS AIRCRAFT'),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.flight_rounded, color: brand, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(airline.aircraft,
                    style: NeonType.manrope(19, FontWeight.w800).copyWith(color: _Light.ink, letterSpacing: -0.3)),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(p.usedFor, style: const TextStyle(color: _Light.inkLo, fontSize: 13)),
          const SizedBox(height: 12),
          // Two to a row; each row as tall as its taller tile.
          for (var i = 0; i < specs.length; i += 2) ...[
            if (i > 0) const SizedBox(height: 8),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _spec(specs[i])),
                  const SizedBox(width: 8),
                  Expanded(child: i + 1 < specs.length ? _spec(specs[i + 1]) : const SizedBox.shrink()),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7E6),
              borderRadius: BorderRadius.circular(Neon.rMd),
              border: Border.all(color: const Color(0xFFF5DDA8)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_rounded, size: 18, color: Color(0xFFD08A00)),
                const SizedBox(width: 8),
                Expanded(child: Text(p.fact, style: const TextStyle(color: _Light.ink, fontSize: 13.5, height: 1.4))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _spec((IconData, String, String) s) => Container(
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
        decoration: BoxDecoration(
          color: _Light.wash(brand, 0.07),
          borderRadius: BorderRadius.circular(Neon.rSm),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(s.$1, size: 14, color: brand),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(s.$2.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: NeonType.eyebrow.copyWith(color: _Light.inkDim, fontSize: 10)),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(s.$3, style: NeonType.manrope(13, FontWeight.w700).copyWith(color: _Light.ink, height: 1.3)),
          ],
        ),
      );
}

/// The photos full screen, black around them: swipe through them, pinch to
/// zoom, each with what it shows and who took it.
class _FullPhoto extends StatefulWidget {
  const _FullPhoto({required this.airline, this.initial = 0});
  final Airline airline;
  final int initial;

  @override
  State<_FullPhoto> createState() => _FullPhotoState();
}

class _FullPhotoState extends State<_FullPhoto> {
  late final _pages = PageController(initialPage: widget.initial);
  late int _at = widget.initial;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.airline;
    final photos = a.photos;
    final p = photos[_at];
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${a.name} · ${_at + 1} of ${photos.length}',
            style: NeonType.manrope(15, FontWeight.w700).copyWith(color: Colors.white)),
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pages,
              itemCount: photos.length,
              onPageChanged: (i) => setState(() => _at = i),
              itemBuilder: (_, i) => InteractiveViewer(
                maxScale: 5,
                child: Center(
                  child: Hero(tag: 'airline-${a.id}-$i', child: Image.asset(photos[i].path)),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Column(
                children: [
                  Text(p.caption,
                      textAlign: TextAlign.center,
                      style: NeonType.manrope(14, FontWeight.w700).copyWith(color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('Photo: ${p.credit} · Wikimedia Commons. Swipe for more, pinch to zoom.',
                      textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
