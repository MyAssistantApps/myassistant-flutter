import 'dart:io';

import 'package:flutter/material.dart';

import '../design/apple_kit.dart';
import '../design/motion.dart';
import '../design/neon_tokens.dart';
import '../features/home/home_fx.dart';
import '../services/app_feedback.dart';
import '../services/my_photo.dart';
import '../services/studio_service.dart';

/// "UPLOAD MY PHOTO" (owner, 2026-11-16): the card at the top of My
/// Documents where the user sets the one photo of themselves the app uses
/// everywhere: their assistant page and Home banner, Style Studio and
/// Try-on. It shows the photo once set, in a glowing ring, with Change and
/// Remove. A light travels round the edge and the card rises in once.
class MyPhotoCard extends StatefulWidget {
  const MyPhotoCard({super.key});

  @override
  State<MyPhotoCard> createState() => _MyPhotoCardState();
}

class _MyPhotoCardState extends State<MyPhotoCard>
    with SingleTickerProviderStateMixin, LoopFx {
  File? _photo;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    MyPhoto.version.addListener(_refresh);
    _refresh();
    // A reinstall or a new phone: bring the account's photo back.
    MyPhoto.syncFromAccount();
  }

  @override
  void dispose() {
    MyPhoto.version.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _refresh() async {
    final f = await MyPhoto.current();
    if (mounted) setState(() => _photo = f);
  }

  Future<void> _choose() async {
    final has = _photo != null;
    final pick = await showAppSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppleRow(
              leading: IconTile(Icons.photo_camera_rounded, Neon.violet),
              title: 'Take a Selfie',
              subtitle: 'Face and shoulders, in good light',
              trailing: const SizedBox.shrink(),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            AppleRow(
              leading: IconTile(Icons.photo_library_rounded, Neon.pink),
              title: 'Select from Gallery',
              subtitle: 'A clear, recent photo of you',
              trailing: const SizedBox.shrink(),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            if (has)
              AppleRow(
                leading: IconTile(Icons.delete_outline_rounded, Neon.error),
                title: 'Remove My Photo',
                titleColor: Neon.error,
                trailing: const SizedBox.shrink(),
                onTap: () => Navigator.pop(ctx, 'remove'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (pick == null || !mounted) return;
    setState(() => _busy = true);
    try {
      var r = pick == 'remove'
          ? await MyPhoto.remove()
          : await MyPhoto.upload(camera: pick == 'camera');
      if (r.needsConsent && mounted) {
        final agreed = await _askConsent();
        if (!agreed) return;
        try {
          await StudioService.acceptConsent();
        } catch (_) {
          r = const MyPhotoResult.failed(
              'Unable to record your consent. Check your connection and try again.');
        }
        if (r.retry != null) r = await r.retry!();
      }
      if (mounted && r.message.isNotEmpty) {
        AppFeedback.show(r.message, context: context);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The same terms as Style Studio's consent, asked once.
  Future<bool> _askConsent() async {
    Widget point(IconData i, String t) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(i, size: 18, color: Neon.violet),
            const SizedBox(width: 10),
            Expanded(
                child: Text(t,
                    style: TextStyle(
                        color: Neon.textLo, fontSize: 13.5, height: 1.4))),
          ]),
        );
    final ok = await showAppSheet<bool>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Before You Upload',
                  style: NeonType.manrope(19, FontWeight.w800)
                      .copyWith(color: Neon.textHi)),
              const SizedBox(height: 14),
              point(Icons.face_rounded,
                  'Your photo is stored on your own account and used only within this app.'),
              point(Icons.person_outline_rounded,
                  'Use a photo of yourself. Do not upload a photo of someone else.'),
              point(Icons.delete_outline_rounded,
                  'You can remove your photo at any time from this card.'),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Not Now'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('I Agree'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final c = Neon.violet;
    final has = _photo != null;
    final r = BorderRadius.circular(Neon.rLg);
    return EnterOnce(
      duration: const Duration(milliseconds: 520),
      rise: 16,
      scaleFrom: 0.97,
      child: Tappable(
        onTap: _busy ? null : _choose,
        semanticLabel: has
            ? 'My photo. Change or remove it.'
            : 'Upload My Photo. It is used across the app.',
        child: CustomPaint(
          foregroundPainter: AuroraBorderPainter(
              t: loop, radius: Neon.rLg, color: c, cycles: 1, offset: 0.25),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: r,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  c.withValues(alpha: Neon.isDark ? 0.22 : 0.12),
                  c.withValues(alpha: 0.04),
                ],
              ),
              boxShadow: Neon.glassShadow,
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: ClipRRect(
                      borderRadius: r,
                      child: RepaintBoundary(
                        child: CustomPaint(
                            painter: ShimmerPainter(t: loop)),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: ExcludeSemantics(
                    child: Row(
                      children: [
                        _avatar(c),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(has ? 'My Photo' : 'Upload My Photo',
                                  style: NeonType.manrope(17, FontWeight.w800)
                                      .copyWith(
                                          color: Neon.textHi,
                                          letterSpacing: -0.3)),
                              const SizedBox(height: 3),
                              Text(
                                  has
                                      ? 'Shown across the app. Tap to change.'
                                      : 'Set once, used across the app.',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: Neon.textLo,
                                      fontSize: 12.5,
                                      height: 1.3)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        _pill(has),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The photo in a gradient ring, or a person with a camera badge.
  Widget _avatar(Color c) {
    final photo = _photo;
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 64,
            height: 64,
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(colors: [
                Color.lerp(c, Colors.white, 0.4)!,
                Neon.accentFill,
                Neon.pink,
                Color.lerp(c, Colors.white, 0.4)!,
              ]),
              boxShadow: [
                BoxShadow(
                    color: c.withValues(alpha: 0.5),
                    blurRadius: 18,
                    spreadRadius: -4),
              ],
            ),
            child: ClipOval(
              child: AnimatedSwitcher(
                duration: Motion.short,
                child: photo != null
                    ? Image.file(photo,
                        key: ValueKey(photo.path + MyPhoto.version.value.toString()),
                        fit: BoxFit.cover,
                        width: 59,
                        height: 59,
                        gaplessPlayback: true)
                    : Container(
                        key: const ValueKey('none'),
                        color: Color.lerp(Neon.bg, c, 0.25),
                        alignment: Alignment.center,
                        child: Icon(Icons.person_rounded,
                            size: 34, color: Neon.textHi.withValues(alpha: 0.85)),
                      ),
              ),
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Neon.accentFill,
                border: Border.all(color: Neon.bg, width: 2),
              ),
              child: _busy
                  ? const Padding(
                      padding: EdgeInsets.all(4),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Icon(
                      photo != null
                          ? Icons.edit_rounded
                          : Icons.photo_camera_rounded,
                      size: 13,
                      color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(bool has) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          Color.lerp(Neon.accentFill, Colors.white, 0.18)!,
          Neon.accentFill,
        ]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Neon.accentFill.withValues(alpha: 0.45),
              blurRadius: 14,
              spreadRadius: -4)
        ],
      ),
      child: Text(_busy ? 'Saving…' : (has ? 'Change' : 'Upload'),
          style: NeonType.manrope(13, FontWeight.w800)
              .copyWith(color: Colors.white)),
    );
  }
}
