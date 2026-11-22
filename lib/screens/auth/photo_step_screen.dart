
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../design/apple_kit.dart';
import '../../design/motion.dart';
import '../../design/neon_tokens.dart';
import '../../design/neon_widgets.dart';
import '../../services/auth_service.dart';
import '../../services/my_photo.dart';
import '../../services/persona.dart';
import '../../services/studio_service.dart';
import '../../widgets/glow_cta.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  ADD YOUR PHOTO — the onboarding step after "What do you do?".
///
///  The photo goes on the user's assistant card on Home (MyPhoto). Owner,
///  2026-11-21: the photo should be turned into a professional one by AI,
///  without compromising the face or the quality. So:
///
///   1. They pick a selfie or a gallery photo.
///   2. "Create Professional Headshot" sends it to POST /studio/headshot
///      (medium quality, high face fidelity, dressed for their profession).
///   3. Original and headshot are shown side by side as a toggle; THEY pick
///      which one is used. Nothing is replaced behind their back, and the
///      original is always one tap away.
///
///  Two tries per account (the server enforces it). Storing a face needs
///  the Style Studio consent; it is asked once, in plain words, before the
///  photo leaves the phone. Skippable: the card falls back to the default.
/// ─────────────────────────────────────────────────────────────────────────
class PhotoStepScreen extends StatefulWidget {
  const PhotoStepScreen({super.key, required this.onDone, this.editing = false});

  final VoidCallback onDone;

  /// Opened from Home's card: a back button, and no Skip.
  final bool editing;

  @override
  State<PhotoStepScreen> createState() => _PhotoStepScreenState();
}

enum _View { original, professional }

class _PhotoStepScreenState extends State<PhotoStepScreen> {
  Uint8List? _original;
  String _originalName = 'me.jpg';
  String _originalMime = 'image/jpeg';
  Uint8List? _headshot;
  int? _remaining; // null until the server says
  _View _view = _View.professional;
  bool _generating = false;
  bool _saving = false;
  String? _error;

  Uint8List? get _shown =>
      _view == _View.professional && _headshot != null ? _headshot : _original;

  String get _profession {
    final u = AuthService.instance.user;
    final p = (u?.profession ?? '').trim();
    return p.isNotEmpty ? p : Persona.titleFor(Persona.value);
  }

  Future<void> _pick() async {
    final source = await showAppSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppleRow(
              leading: IconTile(Icons.photo_camera_front_rounded, Neon.violet),
              title: 'Take a Selfie',
              subtitle: 'Face and shoulders, in good light',
              trailing: const SizedBox.shrink(),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            AppleRow(
              leading: IconTile(Icons.photo_library_rounded, Neon.pink),
              title: 'Choose from Gallery',
              subtitle: 'A clear, recent photo of you',
              trailing: const SizedBox.shrink(),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;
    final XFile? shot;
    try {
      shot = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 92,
        preferredCameraDevice: CameraDevice.front,
      );
    } catch (_) {
      _fail('Unable to open the camera or gallery. Please check the app permissions.');
      return;
    }
    if (shot == null || !mounted) return;
    final bytes = await shot.readAsBytes();
    if (!mounted) return;
    setState(() {
      _original = bytes;
      _originalName = shot!.name.isEmpty ? 'me.jpg' : shot.name;
      _originalMime = shot.mimeType ?? 'image/jpeg';
      _headshot = null;
      _view = _View.professional;
      _error = null;
    });
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() => _error = message);
  }

  /// Runs [action]; when the server wants the photo consent first, asks
  /// for it once and runs [action] again.
  Future<T?> _withConsent<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on StudioException catch (e) {
      if (!e.needsConsent) rethrow;
      if (!mounted || !await _askConsent()) return null;
      await StudioService.acceptConsent();
      return action();
    }
  }

  Future<void> _generate() async {
    final bytes = _original;
    if (bytes == null || _generating) return;
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      final r = await _withConsent(() => StudioService.headshot(
            bytes: bytes,
            filename: _originalName,
            mimeType: _originalMime,
            profession: _profession,
          ));
      if (r == null || !mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _headshot = Uint8List.fromList(r.bytes);
        _remaining = r.remaining;
        _view = _View.professional;
      });
    } on StudioException catch (e) {
      if (e.code == 'headshot_limit') setState(() => _remaining = 0);
      _fail(e.message.isNotEmpty
          ? e.message
          : 'The headshot could not be created. You can use your photo as it is.');
    } catch (_) {
      _fail('The headshot could not be created. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _use() async {
    final bytes = _shown;
    if (bytes == null || _saving) return;
    final pro = identical(bytes, _headshot);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      var r = await MyPhoto.save(bytes,
          filename: pro ? 'professional-headshot.${_ext(bytes)}' : _originalName,
          mimeType: pro ? _mime(bytes) : _originalMime);
      if (r.needsConsent && mounted) {
        if (!await _askConsent()) return;
        await StudioService.acceptConsent();
        r = await r.retry!();
      }
      if (!r.ok) {
        _fail(r.message.isNotEmpty ? r.message : 'Unable to save the photo.');
        return;
      }
      HapticFeedback.lightImpact();
      widget.onDone();
    } catch (_) {
      _fail('Unable to save the photo. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static bool _isPng(Uint8List b) =>
      b.length > 4 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47;
  static String _mime(Uint8List b) => _isPng(b) ? 'image/png' : 'image/jpeg';
  static String _ext(Uint8List b) => _isPng(b) ? 'png' : 'jpg';

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
              Text('Before We Use Your Photo',
                  style: NeonType.manrope(19, FontWeight.w800)
                      .copyWith(color: Neon.textHi)),
              const SizedBox(height: 14),
              point(Icons.face_rounded,
                  'Your photo is stored on your own account and used only within this app.'),
              point(Icons.auto_awesome_rounded,
                  'If you ask for a professional headshot, an AI creates it from your photo. You choose which one to use.'),
              point(Icons.person_outline_rounded,
                  'Use a photo of yourself. Do not upload a photo of someone else.'),
              point(Icons.delete_outline_rounded,
                  'You can remove your photo at any time from Documents.'),
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
    final has = _original != null;
    final done = _headshot != null;
    final busy = _generating || _saving;
    return NeonScaffold(
      appBar: widget.editing ? appleAppBar(context, 'Your Photo') : null,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(20, widget.editing ? 8 : 28, 20, 12),
                    children: [
                      Text(
                        'Add Your Photo',
                        style: GoogleFonts.interTight(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Neon.textHi,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        done
                            ? 'Your professional headshot is ready. Compare it with your original and choose the one you prefer.'
                            : 'It appears on your assistant card on Home. We can turn a clear selfie into a studio-quality professional headshot.',
                        style: TextStyle(
                            color: Neon.textLo, fontSize: 14.5, height: 1.45),
                      ),
                      const SizedBox(height: 20),
                      if (done) ...[
                        _Toggle(
                          value: _view,
                          onChanged: busy
                              ? null
                              : (v) {
                                  HapticFeedback.selectionClick();
                                  setState(() => _view = v);
                                },
                        ),
                        const SizedBox(height: 14),
                      ],
                      _PhotoFrame(
                        image: _shown,
                        generating: _generating,
                        onTap: busy ? null : _pick,
                        badge: done && _view == _View.professional
                            ? 'AI Headshot'
                            : null,
                      ),
                      if (has && !busy) ...[
                        const SizedBox(height: 10),
                        Center(
                          child: TextButton.icon(
                            onPressed: _pick,
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Choose a Different Photo'),
                          ),
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Neon.error, fontSize: 13)),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _actions(has: has, done: done, busy: busy),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _actions({required bool has, required bool done, required bool busy}) {
    final skip = TextButton(
      onPressed: busy ? null : widget.onDone,
      child: Text(widget.editing ? 'Cancel' : 'Skip for Now',
          style: TextStyle(
              color: Neon.textLo, fontSize: 13.5, fontWeight: FontWeight.w500)),
    );
    if (!has) {
      return [
        GlowCta(label: 'Add a Photo', icon: Icons.add_a_photo_rounded, onPressed: _pick),
        skip,
      ];
    }
    if (!done) {
      final canAi = _remaining != 0;
      return [
        GlowCta(
          label: 'Create Professional Headshot',
          icon: Icons.auto_awesome_rounded,
          busy: _generating,
          busyLabel: 'Creating your headshot',
          onPressed: canAi && !busy ? _generate : null,
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: busy ? null : _use,
          child: _saving
              ? const NeonLoader.inline(semanticLabel: 'Saving')
              : const Text('Use This Photo As It Is'),
        ),
        skip,
      ];
    }
    final pro = _view == _View.professional;
    return [
      GlowCta(
        label: pro ? 'Use Professional Photo' : 'Use Original Photo',
        busy: _saving,
        busyLabel: 'Saving',
        onPressed: busy ? null : _use,
      ),
      if ((_remaining ?? 0) > 0)
        TextButton.icon(
          onPressed: busy ? null : _generate,
          icon: const Icon(Icons.auto_awesome_rounded, size: 18),
          label: Text('Try Again ($_remaining Left)'),
        )
      else
        skip,
    ];
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.value, required this.onChanged});

  final _View value;
  final ValueChanged<_View>? onChanged;

  @override
  Widget build(BuildContext context) {
    Widget seg(_View v, String label, IconData icon) {
      final on = value == v;
      return Expanded(
        child: GestureDetector(
          onTap: onChanged == null ? null : () => onChanged!(v),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              gradient: on ? Neon.gBrand : null,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 17, color: on ? Neon.onBrand : Neon.textLo),
                const SizedBox(width: 7),
                Text(label,
                    style: TextStyle(
                        color: on ? Neon.onBrand : Neon.textLo,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Neon.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Neon.line),
      ),
      child: Row(children: [
        seg(_View.original, 'Original', Icons.photo_rounded),
        const SizedBox(width: 4),
        seg(_View.professional, 'Professional', Icons.auto_awesome_rounded),
      ]),
    );
  }
}

/// A 3:4 portrait frame: the empty invitation, the photo, or the photo
/// under a "creating" veil.
class _PhotoFrame extends StatelessWidget {
  const _PhotoFrame(
      {required this.image, required this.generating, this.onTap, this.badge});

  final Uint8List? image;
  final bool generating;
  final VoidCallback? onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(24);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: Material(
            color: Neon.surface,
            borderRadius: r,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: r,
                  border: Border.all(
                      color: image == null
                          ? Neon.line
                          : Neon.violet.withValues(alpha: 0.55),
                      width: 1.4),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (image == null)
                      _empty()
                    else
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        child: Image.memory(image!,
                            key: ValueKey(image.hashCode),
                            fit: BoxFit.cover,
                            alignment: const Alignment(0, -0.3),
                            filterQuality: FilterQuality.high,
                            gaplessPlayback: true),
                      ),
                    if (badge != null && !generating)
                      Positioned(
                        left: 12,
                        top: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: Neon.gBrand,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.auto_awesome_rounded,
                                size: 13, color: Neon.onBrand),
                            const SizedBox(width: 5),
                            Text(badge!,
                                style: TextStyle(
                                    color: Neon.onBrand,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      ),
                    if (generating) _veil(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _empty() => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Neon.violet.withValues(alpha: 0.12),
            ),
            child: Icon(Icons.person_rounded, size: 38, color: Neon.violet),
          ),
          const SizedBox(height: 14),
          Text('Tap to Add Your Photo',
              style: TextStyle(
                  color: Neon.textHi, fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Face and shoulders, in good light',
              style: TextStyle(color: Neon.textDim, fontSize: 12.5)),
        ],
      );

  Widget _veil() => Container(
        color: Colors.black.withValues(alpha: 0.55),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const NeonLoader(semanticLabel: 'Creating your headshot'),
            const SizedBox(height: 16),
            const Text('Creating Your Headshot',
                style: TextStyle(
                    color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('This takes about 30 seconds',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75), fontSize: 12.5)),
          ],
        ),
      );
}
