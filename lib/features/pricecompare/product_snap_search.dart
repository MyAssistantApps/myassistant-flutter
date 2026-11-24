import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../ai/listen.dart';
import '../../core/log.dart';
import '../../design/motion.dart';
import '../../design/neon_tokens.dart';
import '../../services/app_feedback.dart';
import '../../widgets/photo_source_sheet.dart';
import 'price_service.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  SEARCH BY CAMERA OR VOICE (2026-11-24): Price Compare's search box
///  gained a camera (photograph the product or upload a photo of it) and a
///  microphone (say its name). Each one ends in the words to search for,
///  or null when the user backs out or nothing could be made out (the
///  reason is shown).
/// ─────────────────────────────────────────────────────────────────────────
abstract final class ProductSnapSearch {
  /// Camera or gallery, then the product in the photo.
  static Future<String?> byPhoto(BuildContext context) async {
    final from = await _askSource(context);
    if (from == null || !context.mounted) return null;
    final PickedPhoto? photo;
    try {
      photo = await PhotoSourceSheet.pick(context, from);
    } on PhotoAccessDenied {
      return null; // The picker already offered Settings.
    }
    if (photo == null || !context.mounted) return null;
    return _working(context, 'Identifying the Product…',
        () => PriceService.instance.productInPhoto(photo!.bytes, photo.mime));
  }

  /// Records until the user taps Search (or 12 seconds pass), then
  /// writes the words down.
  static Future<String?> byVoice(BuildContext context) async {
    final audio = await showAppSheet<RecordedAudio>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Neon.surface,
      showDragHandle: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => const _ListenSheet(),
    );
    if (audio == null || !context.mounted) return null;
    return _working(context, 'Listening to Your Search…',
        () => PriceService.instance.productFromSpeech(audio.bytes, audio.mimeType));
  }

  static Future<String?> _askSource(BuildContext context) => showAppSheet<String>(
        context: context,
        useRootNavigator: true,
        backgroundColor: Neon.surface,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Search by Photo',
                    style: NeonType.manrope(NeonType.title3, FontWeight.w700).copyWith(color: Neon.textHi)),
                const SizedBox(height: 4),
                Text('Photograph the product or its label, or upload a photo of it.',
                    style: TextStyle(color: Neon.textLo, fontSize: NeonType.callout)),
                const SizedBox(height: 14),
                _choice(ctx, Icons.photo_camera_rounded, 'Take a Photo', 'camera'),
                const SizedBox(height: 12),
                _choice(ctx, Icons.photo_library_rounded, 'Upload a Photo', 'gallery'),
              ],
            ),
          ),
        ),
      );

  static Widget _choice(BuildContext ctx, IconData icon, String label, String value) => FilledButton.icon(
        onPressed: () => Navigator.of(ctx).pop(value),
        icon: Icon(icon, size: 24),
        label: Text(label, style: NeonType.manrope(NeonType.rowTitle, FontWeight.w700)),
        style: FilledButton.styleFrom(
          backgroundColor: Neon.accentFill,
          foregroundColor: Neon.onAccent,
          alignment: Alignment.centerLeft,
          minimumSize: const Size.fromHeight(56),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Neon.rMd)),
        ),
      );

  /// A spinner with [label] over the screen while [job] runs; its answer,
  /// or null with the reason shown.
  static Future<String?> _working(BuildContext context, String label, Future<String> Function() job) async {
    final nav = Navigator.of(context, rootNavigator: true);
    unawaited(showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: Neon.surface,
          content: Row(children: [
            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
            const SizedBox(width: 16),
            Expanded(child: Text(label, style: TextStyle(color: Neon.textHi, fontSize: NeonType.rowTitle))),
          ]),
        ),
      ),
    ));
    try {
      return await job();
    } on PriceCompareException catch (e) {
      AppFeedback.show(e.message, tone: FeedbackTone.error);
      return null;
    } catch (e) {
      AppLog.add('price', 'snap search failed: $e');
      AppFeedback.show('The search could not be completed. Please try again.', tone: FeedbackTone.error);
      return null;
    } finally {
      if (nav.mounted) nav.pop();
    }
  }
}

/// "Say the product name" — a pulsing microphone while recording, then
/// Search hands the recording back (Cancel hands back nothing).
class _ListenSheet extends StatefulWidget {
  const _ListenSheet();

  @override
  State<_ListenSheet> createState() => _ListenSheetState();
}

class _ListenSheetState extends State<_ListenSheet> {
  static const _limit = Duration(seconds: 12);
  final _rec = RecordRecorder();
  StreamSubscription<double>? _levels;
  Timer? _timer;
  double _level = 0;
  bool _recording = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    final ok = await _rec.start();
    if (!mounted) {
      if (ok) unawaited(_rec.cancel());
      return;
    }
    if (!ok) {
      AppFeedback.show('Microphone access is required to search by voice. Enable it in Settings.',
          tone: FeedbackTone.error);
      Navigator.of(context).pop();
      return;
    }
    HapticFeedback.lightImpact();
    _levels = _rec.levels.listen((l) {
      if (mounted) setState(() => _level = l);
    });
    _timer = Timer(_limit, _finish);
    setState(() => _recording = true);
  }

  Future<void> _finish() async {
    if (_done || !_recording) return;
    _done = true;
    _timer?.cancel();
    final audio = await _rec.stop();
    if (mounted) Navigator.of(context).pop(audio);
  }

  Future<void> _cancel() async {
    if (_done) return;
    _done = true;
    _timer?.cancel();
    await _rec.cancel();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_levels?.cancel());
    if (!_done) unawaited(_rec.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = 84 + 36 * _level;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Search by Voice',
                textAlign: TextAlign.center,
                style: NeonType.manrope(NeonType.title3, FontWeight.w700).copyWith(color: Neon.textHi)),
            const SizedBox(height: 4),
            Text(_recording ? 'Say the product name, for example "iPhone 16 128GB".' : 'Starting the microphone…',
                textAlign: TextAlign.center,
                style: TextStyle(color: Neon.textLo, fontSize: NeonType.callout)),
            const SizedBox(height: 18),
            SizedBox(
              height: 124,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Neon.accentFill.withValues(alpha: _recording ? 0.22 : 0.1),
                  ),
                  child: Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Neon.accentFill),
                      child: Icon(Icons.mic_rounded, size: 34, color: Neon.onAccent),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _cancel,
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _recording ? _finish : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: Neon.accentFill,
                    foregroundColor: Neon.onAccent,
                  ),
                  child: const Text('Search'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
