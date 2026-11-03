import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../design/apple_kit.dart';
import '../../design/motion.dart';
import '../../design/neon_tokens.dart';
import '../../design/neon_widgets.dart';
import '../../services/api_service.dart';
import '../../services/studio_service.dart';
import '../assistant/widgets/action_cards.dart' show DocumentGalleryScreen;
import 'try_now_cards.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  ONE TRY-ON, ON ITS OWN SCREEN (2026-11-03, owner: "when I click
///  Clothes it should not take me to AI Studio — directly Clothes").
///
///  Everything the look needs and nothing else: your photo, the reference
///  photo, an optional line to make it yours, one button, the result.
///  Behind it is Style Studio's own server recipe (outfit / hair /
///  jewellery / custom), so the result is the same quality and lands in
///  the same files.
///
///  Consent: the studio asks once that the user agrees to their photo being
///  used; here that agreement is the button itself, said plainly above it.
///  The user's photo is kept as their studio photo, so next time it is
///  already filled in.
/// ─────────────────────────────────────────────────────────────────────────
class TryOnScreen extends StatefulWidget {
  const TryOnScreen({super.key, required this.card});
  final TryNowCard card;

  @override
  State<TryOnScreen> createState() => _TryOnScreenState();
}

class _Picked {
  const _Picked(this.bytes, this.mime);
  final Uint8List bytes;
  final String mime;
}

class _TryOnScreenState extends State<TryOnScreen> {
  StudioState? _studio;

  /// The saved studio photo of the user, used until they pick another.
  StudioPhoto? _saved;
  _Picked? _me;
  _Picked? _ref;
  final _notes = TextEditingController();

  bool _running = false;
  int _elapsed = 0;
  Timer? _tick;
  String _error = '';
  StudioResult? _result;

  TryNowCard get c => widget.card;
  bool get _hasMe => _me != null || _saved != null;
  bool get _ready => _hasMe && _ref != null && !_running;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final s = await StudioService.load();
      if (!mounted) return;
      setState(() {
        _studio = s;
        _saved ??= s.defaultPhoto;
      });
    } catch (_) {
      // Offline now: the screen still works; the run reports the error.
    }
  }

  Future<void> _pick({required bool me}) async {
    final src = await showAppSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppleRow(
              leading: IconTile(Icons.photo_camera_rounded, Neon.violet),
              title: me ? 'Take a selfie' : 'Take a photo',
              subtitle: me
                  ? 'Face and shoulders, in good light'
                  : 'Of the ${c.refLabel.toLowerCase()} itself',
              trailing: const SizedBox.shrink(),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            AppleRow(
              leading: IconTile(Icons.photo_library_rounded, Neon.pink),
              title: 'Choose from gallery',
              subtitle: me ? 'A clear photo of you' : 'A screenshot works too',
              trailing: const SizedBox.shrink(),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (src == null) return;
    final shot = await ImagePicker().pickImage(
        source: src,
        imageQuality: 92,
        maxWidth: 2000,
        maxHeight: 2000,
        preferredCameraDevice: me ? CameraDevice.front : CameraDevice.rear);
    if (shot == null) return;
    final bytes = await shot.readAsBytes();
    if (!mounted) return;
    final p = _Picked(bytes, shot.mimeType ?? 'image/jpeg');
    setState(() {
      if (me) {
        _me = p;
      } else {
        _ref = p;
      }
      _result = null;
      _error = '';
    });
  }

  Future<void> _run() async {
    if (!_ready) return;
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();
    setState(() {
      _running = true;
      _error = '';
      _result = null;
      _elapsed = 0;
    });
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed++);
    });
    try {
      // The button is the agreement (said above it): asked once, ever.
      if (_studio?.consented != true) {
        await StudioService.acceptConsent();
      }
      final notes = _notes.text.trim();
      final me = _me;
      final out = await StudioService.run(
        recipe: c.recipe,
        params: {if (notes.isNotEmpty) 'notes': notes},
        photoId: me == null ? _saved?.id : null,
        photoBytes: me?.bytes,
        photoMime: me?.mime,
        // A new photo of the user becomes their studio photo, so it is
        // filled in next time.
        keepPhoto: me != null,
        garmentBytes: _ref!.bytes,
        garmentMime: _ref!.mime,
      );
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() => _result = out);
      unawaited(_load());
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e is StudioException && e.message.isNotEmpty
          ? e.message
          : "That didn't come out. Check your connection and try again.");
    } finally {
      _tick?.cancel();
      if (mounted) setState(() => _running = false);
    }
  }

  String get _progress {
    if (_elapsed < 6) return 'Getting your photos ready…';
    if (_elapsed < 18) return 'Creating your look… ${_elapsed}s';
    if (_elapsed < 45) return 'Getting the details right… ${_elapsed}s';
    return 'Almost there — ${_elapsed}s';
  }

  void _view(StudioResult out) =>
      Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => DocumentGalleryScreen(documents: [out.document]),
      ));

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_running,
      child: NeonScaffold(
        appBar: appleAppBar(context, c.title),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
                16, 4, 16, 32 + MediaQuery.paddingOf(context).bottom),
            children: [
              _header(),
              const SizedBox(height: 18),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _slot(me: true)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Center(
                        child: Icon(Icons.add_rounded,
                            color: Neon.textDim, size: 22),
                      ),
                    ),
                    Expanded(child: _slot(me: false)),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _notesBox(),
              const SizedBox(height: 18),
              if (_studio?.consented != true) ...[
                Text(
                  'Your photos are used only to make this look, kept private '
                  'and labelled AI-generated. Remove them any time in Style '
                  'Studio.',
                  style: TextStyle(
                      color: Neon.textDim,
                      fontSize: NeonType.caption,
                      height: 1.4),
                ),
                const SizedBox(height: 12),
              ],
              if (_error.isNotEmpty) ...[
                _errorBox(),
                const SizedBox(height: 12),
              ],
              _button(),
              if (_result != null) ...[
                const SizedBox(height: 22),
                _resultCard(_result!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() => Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        decoration: Neon.glassBox(Neon.rCard),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.headline,
                      style: NeonType.manrope(19, FontWeight.w800).copyWith(
                          color: Neon.textHi, letterSpacing: -0.4)),
                  const SizedBox(height: 8),
                  for (final (i, step) in [
                    'Add your photo',
                    'Add a photo of ${c.refLabel.toLowerCase()}',
                    'Tap Create — it takes under a minute',
                  ].indexed)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Row(
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Neon.violet.withValues(alpha: 0.18),
                            ),
                            child: Text('${i + 1}',
                                style: NeonType.manrope(10.5, FontWeight.w800)
                                    .copyWith(color: Neon.violet)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(step,
                                style: TextStyle(
                                    color: Neon.textLo,
                                    fontSize: 13,
                                    height: 1.3)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            ExcludeSemantics(
              child: Image.asset('assets/tryon/${c.art}.png',
                  width: 104, height: 104, fit: BoxFit.contain),
            ),
          ],
        ),
      );

  /// A photo slot: empty, it asks; filled, it shows the photo and can be
  /// changed.
  Widget _slot({required bool me}) {
    final picked = me ? _me : _ref;
    final saved = me && _me == null ? _saved : null;
    final filled = picked != null || saved != null;
    final r = BorderRadius.circular(Neon.rCard);
    final label = me ? 'Your photo' : c.refLabel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(label.toUpperCase(),
              style: NeonType.eyebrow.copyWith(color: Neon.textLo)),
        ),
        Expanded(
          child: Semantics(
            button: true,
            label: filled ? 'Change $label' : 'Add $label',
            excludeSemantics: true,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: r,
                onTap: _running ? null : () => _pick(me: me),
                child: Ink(
                  decoration: Neon.glassBox(Neon.rCard).copyWith(
                    border: Border.all(
                        color: filled
                            ? Neon.violet.withValues(alpha: 0.55)
                            : Neon.glassEdge.first,
                        width: filled ? 1.4 : 1),
                  ),
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: ClipRRect(
                      borderRadius: r,
                      child: filled
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                picked != null
                                    ? Image.memory(picked.bytes,
                                        fit: BoxFit.cover, cacheWidth: 600)
                                    : Image.network(saved!.imageUrl,
                                        headers: ApiService.imageHeaders,
                                        fit: BoxFit.cover,
                                        cacheWidth: 600),
                                Positioned(
                                  right: 8,
                                  bottom: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.black.withValues(alpha: 0.55),
                                      borderRadius:
                                          BorderRadius.circular(Neon.rPill),
                                    ),
                                    child: const Text('Change',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700)),
                                  ),
                                ),
                              ],
                            )
                          : Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color:
                                          Neon.violet.withValues(alpha: 0.16),
                                    ),
                                    child: Icon(
                                        me
                                            ? Icons.person_add_alt_1_rounded
                                            : Icons.add_photo_alternate_rounded,
                                        color: Neon.violet,
                                        size: 24),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(me ? 'Add your photo' : 'Add photo',
                                      textAlign: TextAlign.center,
                                      style: NeonType.manrope(
                                              14, FontWeight.w700)
                                          .copyWith(color: Neon.textHi)),
                                  const SizedBox(height: 4),
                                  Text(
                                      me
                                          ? 'Face and shoulders, good light'
                                          : c.refHint,
                                      textAlign: TextAlign.center,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          color: Neon.textDim,
                                          fontSize: 11.5,
                                          height: 1.3)),
                                ],
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _notesBox() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text('MAKE IT YOURS',
                style: NeonType.eyebrow.copyWith(color: Neon.textLo)),
          ),
          Container(
            decoration: Neon.glassBox(18, lift: false),
            child: TextField(
              controller: _notes,
              enabled: !_running,
              minLines: 2,
              maxLines: 4,
              maxLength: 300,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(color: Neon.textHi, fontSize: NeonType.body),
              decoration: InputDecoration(
                hintText: c.notesHint,
                hintStyle: TextStyle(color: Neon.textDim),
                counterText: '',
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
          ),
        ],
      );

  Widget _button() {
    final missing = !_hasMe
        ? 'Add your photo to start'
        : _ref == null
            ? 'Add a photo of ${c.refLabel.toLowerCase()}'
            : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Opacity(
          opacity: _ready || _running ? 1 : 0.5,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(colors: [
                Color.lerp(Neon.accentFill, Colors.white, 0.12)!,
                Neon.accentFill,
              ]),
              boxShadow: _ready
                  ? [
                      BoxShadow(
                          color: Neon.accentFill.withValues(alpha: 0.45),
                          blurRadius: 22,
                          spreadRadius: -6)
                    ]
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: _ready ? _run : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_running)
                        const NeonLoader.inline(
                            size: 18, semanticLabel: 'Creating')
                      else
                        const Icon(Icons.auto_awesome_rounded,
                            color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Text(_running ? _progress : 'Create my look',
                          style: NeonType.manrope(15.5, FontWeight.w800)
                              .copyWith(color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (missing != null && !_running) ...[
          const SizedBox(height: 8),
          Text(missing,
              textAlign: TextAlign.center,
              style: TextStyle(color: Neon.textDim, fontSize: 12.5)),
        ],
      ],
    );
  }

  Widget _errorBox() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Neon.error.withValues(alpha: 0.12),
          border: Border.all(color: Neon.error.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: Neon.error, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(_error,
                  style: TextStyle(color: Neon.textHi, fontSize: 13.5)),
            ),
          ],
        ),
      );

  /// The look, big, with where it was saved and a way to see it full size.
  Widget _resultCard(StudioResult out) => Reveal(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: Neon.glassBox(Neon.rCard).copyWith(
            border: Border.all(color: Neon.success.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                onTap: () => _view(out),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(Neon.rInner),
                  child: AspectRatio(
                    aspectRatio: out.width > 0 && out.height > 0
                        ? out.width / out.height
                        : 3 / 4,
                    child: Image.network(
                      ApiService.documentFileUrl(out.document.id),
                      headers: ApiService.imageHeaders,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.medium,
                      loadingBuilder: (_, child, p) => p == null
                          ? child
                          : const Center(
                              child: NeonLoader.inline(
                                  semanticLabel: 'Loading your look')),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: Neon.success, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('Your look · saved to My documents',
                        style: TextStyle(
                            color: Neon.textHi,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600)),
                  ),
                  TextButton.icon(
                    onPressed: () => _view(out),
                    icon: const Icon(Icons.open_in_full_rounded, size: 16),
                    label: const Text('View'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}
