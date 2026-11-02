import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../../design/neon_widgets.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../design/motion.dart';
import '../../design/neon_tokens.dart';
import 'quote_of_day.dart';

/// THE DAY'S LINE AS PICTURES (2026-10-18): a tap on the home quote opens
/// this sheet — the line set over each of the server's pictures (one set
/// a day, shared by everyone), swiped through, shared as a PNG. A plain
/// card drawn on the phone is always last, so there is something to share
/// even before the pictures exist or when the network is away.
Future<void> showQuoteCardsSheet(BuildContext context) {
  return showAppSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Neon.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => const _QuoteCardsSheet(),
  );
}

class _QuoteCardsSheet extends StatefulWidget {
  const _QuoteCardsSheet();

  @override
  State<_QuoteCardsSheet> createState() => _QuoteCardsSheetState();
}

class _QuoteCardsSheetState extends State<_QuoteCardsSheet> {
  final _pages = PageController(viewportFraction: 0.82);
  final _keys = <String, GlobalKey>{};
  final _loaded = <String>{};
  final _failed = <String>{};
  Timer? _poll;
  DateTime _opened = DateTime.now();
  int _page = 0;
  bool _sharing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _opened = DateTime.now();
    QuoteOfDay.current.addListener(_changed);
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    QuoteOfDay.current.removeListener(_changed);
    _pages.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  QuoteDay? get _day {
    final d = QuoteOfDay.current.value;
    return d != null && d.date == QuoteOfDay.indiaToday() ? d : null;
  }

  Future<void> _load() async {
    await QuoteOfDay.refresh();
    if (!mounted) return;
    _precache();
    _schedulePoll();
  }

  /// While the server is still making pictures, look again every few
  /// seconds — for five minutes at most.
  void _schedulePoll() {
    _poll?.cancel();
    final d = _day;
    if (d == null || !d.generating) return;
    if (DateTime.now().difference(_opened) > const Duration(minutes: 5)) return;
    _poll = Timer(const Duration(seconds: 8), () async {
      await QuoteOfDay.refresh();
      if (!mounted) return;
      _precache();
      _schedulePoll();
    });
  }

  void _precache() {
    for (final c in _day?.cards ?? const <QuoteCard>[]) {
      if (_loaded.contains(c.url) || _failed.contains(c.url)) continue;
      precacheImage(NetworkImage(c.url), context, onError: (_, __) {
        if (mounted) setState(() => _failed.add(c.url));
      }).then((_) {
        if (mounted && !_failed.contains(c.url)) setState(() => _loaded.add(c.url));
      });
    }
  }

  GlobalKey _keyFor(String id) => _keys.putIfAbsent(id, () => GlobalKey());

  Future<void> _share(String id, String text) async {
    final ctx = _keyFor(id).currentContext;
    final box = ctx?.findRenderObject();
    if (box is! RenderRepaintBoundary) return;
    setState(() {
      _sharing = true;
      _error = null;
    });
    try {
      // 1080 px wide whatever the phone: the size WhatsApp and Instagram
      // show without scaling.
      final ratio = 1080 / box.size.width;
      final image = await box.toImage(pixelRatio: ratio);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) throw StateError('no bytes');
      final dir = await getTemporaryDirectory();
      final name = 'quote-${QuoteOfDay.indiaToday()}-$id.png';
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      await Share.shareXFiles([XFile(file.path, mimeType: 'image/png', name: name)]);
    } catch (_) {
      if (mounted) setState(() => _error = 'The image could not be shared. Please try again.');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _day;
    final text = QuoteOfDay.line();
    final cards = (d?.cards ?? const <QuoteCard>[])
        .where((c) => !_failed.contains(c.url))
        .toList();
    final waiting = d != null && d.generating ? (d.total - d.cards.length).clamp(0, 10) : 0;
    // Pictures, then placeholders for the ones still being made, then the
    // plain card.
    final count = cards.length + waiting + 1;
    final page = _page.clamp(0, count - 1);
    final isCard = page < cards.length;
    final isPlain = page == count - 1;
    final shareId = isCard ? cards[page].style : (isPlain ? 'plain' : null);
    final ready = isPlain || (isCard && _loaded.contains(cards[page].url));
    final label = isCard ? cards[page].label : (isPlain ? 'Classic' : 'Creating');

    final w = MediaQuery.sizeOf(context).width;
    final cardW = w * 0.82 - 16;
    final cardH = cardW * 1.25;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Today's quote",
                style: NeonType.manrope(NeonType.headline, FontWeight.w700)
                    .copyWith(color: Neon.textHi)),
            const SizedBox(height: 4),
            Text('Swipe to choose a style, then share it.',
                style: TextStyle(color: Neon.textLo, fontSize: NeonType.footnote)),
            const SizedBox(height: 16),
            SizedBox(
              height: cardH,
              child: PageView.builder(
                controller: _pages,
                itemCount: count,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) {
                  Widget child;
                  if (i < cards.length) {
                    final c = cards[i];
                    child = RepaintBoundary(
                      key: _keyFor(c.style),
                      child: _QuoteArt(text: text, card: c),
                    );
                  } else if (i == count - 1) {
                    child = RepaintBoundary(
                      key: _keyFor('plain'),
                      child: _QuoteArt(text: text),
                    );
                  } else {
                    child = const _Making();
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: SizedBox(width: cardW, height: cardH, child: child),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < count; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == page ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == page ? Neon.violet : Neon.textDim,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(color: Neon.textLo, fontSize: NeonType.footnote)),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Neon.error, fontSize: NeonType.footnote)),
            ],
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Neon.accentFill,
                    foregroundColor: Neon.onAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: shareId == null || !ready || _sharing
                      ? null
                      : () => _share(shareId, text),
                  icon: _sharing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.share_rounded, size: 20),
                  label: Text(_sharing ? 'Preparing' : 'Share',
                      style: NeonType.manrope(NeonType.rowTitle, FontWeight.w700)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The line set over a picture (or, with no [card], over the app's own
/// gradient). Sizes follow the card's width, so the shared PNG looks the
/// same as the card on screen.
class _QuoteArt extends StatelessWidget {
  const _QuoteArt({required this.text, this.card});

  final String text;
  final QuoteCard? card;

  @override
  Widget build(BuildContext context) {
    final c = card;
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      final long = text.length > 90;
      final size = w * (long ? 0.062 : text.length > 55 ? 0.072 : 0.085);
      final ink = c?.ink ?? Colors.white;
      final light = c?.lightScrim ?? false;
      final lower = c?.lower ?? false;
      final style = TextStyle(
        fontFamily: (c?.serif ?? false) ? 'serif' : 'Manrope',
        fontSize: size,
        height: 1.32,
        fontWeight: (c?.serif ?? false) ? FontWeight.w600 : FontWeight.w800,
        color: ink,
        letterSpacing: 0.2,
        shadows: light
            ? null
            : [Shadow(color: Colors.black.withValues(alpha: 0.55), blurRadius: w * 0.03)],
      );
      return Stack(
        fit: StackFit.expand,
        children: [
          if (c != null)
            Image.network(
              c.url,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              loadingBuilder: (_, child, progress) =>
                  progress == null ? child : const _Making(),
              errorBuilder: (_, __, ___) => const _Making(),
            )
          else
            DecoratedBox(decoration: BoxDecoration(gradient: Neon.gBrand)),
          // A wash so the words read on any picture.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: lower ? const Alignment(0, 0.74) : Alignment.center,
                radius: 0.9,
                colors: light
                    ? [Colors.white.withValues(alpha: 0.55), Colors.white.withValues(alpha: 0.0)]
                    : [Colors.black.withValues(alpha: 0.42), Colors.black.withValues(alpha: 0.12)],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: w * 0.1),
            child: Align(
              alignment: lower ? const Alignment(0, 0.74) : Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: w * 0.12,
                    height: w * 0.008,
                    margin: EdgeInsets.only(bottom: w * 0.05),
                    color: ink.withValues(alpha: 0.85),
                  ),
                  Text(text, textAlign: TextAlign.center, style: style),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }
}

/// A picture the server is still making.
class _Making extends StatelessWidget {
  const _Making();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Neon.surfaceHigh,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const NeonLoader.inline(size: 22, semanticLabel: 'Creating image'),
            const SizedBox(height: 10),
            Text('Creating image',
                style: TextStyle(color: Neon.textLo, fontSize: NeonType.footnote)),
          ],
        ),
      ),
    );
  }
}
