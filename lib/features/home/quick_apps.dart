import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:simple_icons/simple_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/log.dart';
import '../../design/motion.dart';
import '../../design/neon_tokens.dart';

/// QUICK APPS (2026-11-08): the apps people open most, one tap away on
/// Home — where the "Order and shop" banners used to be. Each opens the
/// installed app; when it is not installed, its Play Store page.
class QuickApp {
  const QuickApp(this.name, this.pkgs, this.mark, this.color, {this.badge});

  final String name;

  /// Candidate packages, first installed wins (Gallery differs by maker).
  final List<String> pkgs;
  final IconData mark;
  final Color color;

  /// The app's own icon, drawn, for when it is not installed ([mark] on
  /// white otherwise).
  final Widget Function(double size)? badge;
}

/// Paytm's app icon: light blue over navy, a white circle, the wordmark.
Widget _paytmBadge(double size) => Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF00BAF2),
            Color(0xFF00BAF2),
            Color(0xFF002E6E),
            Color(0xFF002E6E)
          ],
          stops: [0, 0.5, 0.5, 1],
        ),
      ),
      alignment: Alignment.center,
      child: Container(
        width: size * 0.78,
        height: size * 0.78,
        decoration:
            const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Icon(SimpleIcons.paytm,
            color: const Color(0xFF002E6E), size: size * 0.6),
      ),
    );

const quickApps = <QuickApp>[
  QuickApp('GPay', ['com.google.android.apps.nbu.paisa.user'],
      SimpleIcons.googlepay, SimpleIconColors.googlepay),
  QuickApp('PhonePe', ['com.phonepe.app'], SimpleIcons.phonepe,
      SimpleIconColors.phonepe),
  QuickApp(
      'Paytm', ['net.one97.paytm'], SimpleIcons.paytm, SimpleIconColors.paytm,
      badge: _paytmBadge),
  QuickApp('Gmail', ['com.google.android.gm'], SimpleIcons.gmail,
      SimpleIconColors.gmail),
  QuickApp('Google', ['com.google.android.googlequicksearchbox'],
      SimpleIcons.google, SimpleIconColors.google),
  QuickApp(
      'Gallery',
      [
        'com.miui.gallery',
        'com.sec.android.gallery3d',
        'com.coloros.gallery3d',
        'com.oneplus.gallery',
        'com.vivo.gallery',
        'com.android.gallery3d',
        'com.google.android.apps.photos',
      ],
      SimpleIcons.googlephotos,
      SimpleIconColors.googlephotos),
  QuickApp('YouTube', ['com.google.android.youtube'], SimpleIcons.youtube,
      SimpleIconColors.youtube),
  QuickApp('Facebook', ['com.facebook.katana'], SimpleIcons.facebook,
      SimpleIconColors.facebook),
  QuickApp('WhatsApp', ['com.whatsapp'], SimpleIcons.whatsapp,
      SimpleIconColors.whatsapp),
  QuickApp('Instagram', ['com.instagram.android'], SimpleIcons.instagram,
      SimpleIconColors.instagram),
];

const _channel = MethodChannel('hari/intent');

/// The installed package and its icon, read once per run (null: none installed).
final _found = <String, Future<(String, Uint8List)?>>{};

Future<(String, Uint8List)?> _lookup(QuickApp a) =>
    _found[a.name] ??= () async {
      for (final pkg in a.pkgs) {
        try {
          final png = await _channel
              .invokeMethod<Uint8List>('appIcon', {'pkg': pkg, 'size': 144});
          if (png != null) return (pkg, png);
        } catch (_) {}
      }
      // Not remembered: installed from the Play Store, it opens next tap.
      _found.remove(a.name);
      return null;
    }();

/// Opens [a]; false when it is not on this phone.
Future<bool> _launch(QuickApp a) async {
  AppLog.add('home', 'quick app ${a.name}');
  final hit = await _lookup(a);
  if (hit == null) return false;
  try {
    final opened = await _channel
        .invokeMethod<String>('launchApp', {'name': a.name, 'pkg': hit.$1});
    return opened != null && opened.isNotEmpty;
  } catch (_) {
    return false;
  }
}

/// Its Play Store page (Gallery → Google Photos).
Future<void> _store(QuickApp a) async {
  final pkg = a.pkgs.last;
  final market = Uri.parse('market://details?id=$pkg');
  if (!await launchUrl(market, mode: LaunchMode.externalApplication)) {
    await launchUrl(
        Uri.parse('https://play.google.com/store/apps/details?id=$pkg'),
        mode: LaunchMode.externalApplication);
  }
}

/// NOT ON THIS PHONE (2026-11-08): say so, and offer the Play Store,
/// rather than dropping the user into the store unannounced.
Future<void> _notInstalled(BuildContext context, QuickApp a, Widget icon) {
  return showAppSheet<void>(
    context: context,
    backgroundColor: Neon.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(height: 16),
            Text("You don't have ${a.name}",
                textAlign: TextAlign.center,
                style: NeonType.manrope(20, FontWeight.w800)
                    .copyWith(color: Neon.textHi)),
            const SizedBox(height: 8),
            Text(
                "${a.name} isn't installed on this phone. Get it from the "
                "Play Store, then tap it here to open it.",
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: Neon.textLo, fontSize: 14, height: 1.4)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Neon.cyan,
                  foregroundColor: Neon.cyanInk,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.download_rounded),
                label: Text('Get ${a.name}',
                    style: NeonType.manrope(15, FontWeight.w800)),
                onPressed: () {
                  Navigator.of(sheet).pop();
                  _store(a);
                },
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(sheet).pop(),
              child: Text('Not now', style: TextStyle(color: Neon.textLo)),
            ),
          ],
        ),
      ),
    ),
  );
}

class QuickApps extends StatelessWidget {
  const QuickApps({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Padding(
            padding: const EdgeInsets.only(left: Neon.s1, bottom: 10),
            child: Text('Quick apps',
                style: NeonType.manrope(21, FontWeight.w800)
                    .copyWith(color: Neon.textHi, letterSpacing: -0.6)),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 6),
          decoration: Neon.glassBox(Neon.rLg),
          child: LayoutBuilder(builder: (context, c) {
            const perRow = 5;
            final w = c.maxWidth / perRow;
            return Wrap(
              alignment: WrapAlignment.center,
              children: [
                for (final a in quickApps)
                  SizedBox(width: w, child: _AppTile(app: a)),
              ],
            );
          }),
        ),
      ],
    );
  }
}

class _AppTile extends StatefulWidget {
  const _AppTile({required this.app});
  final QuickApp app;

  @override
  State<_AppTile> createState() => _AppTileState();
}

class _AppTileState extends State<_AppTile> {
  Uint8List? _png;

  /// Null while the phone is being asked.
  bool? _installed;

  @override
  void initState() {
    super.initState();
    _lookup(widget.app).then((hit) {
      if (!mounted) return;
      setState(() {
        _installed = hit != null;
        _png = hit?.$2;
      });
    });
  }

  Widget _icon(double size) {
    final a = widget.app;
    final png = _png;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.26),
      child: png != null
          ? Image.memory(png,
              width: size,
              height: size,
              fit: BoxFit.cover,
              gaplessPlayback: true)
          : a.badge != null
              ? a.badge!(size)
              : Container(
                  width: size,
                  height: size,
                  color: Colors.white,
                  alignment: Alignment.center,
                  child: Icon(a.mark, color: a.color, size: size * 0.56),
                ),
    );
  }

  Future<void> _tap() async {
    final a = widget.app;
    if (await _launch(a)) {
      // Installed since the tile was drawn: show its real icon now.
      if (_installed != true) {
        final hit = await _lookup(a);
        if (mounted && hit != null) {
          setState(() {
            _installed = true;
            _png = hit.$2;
          });
        }
      }
      return;
    }
    if (!mounted) return;
    await _notInstalled(context, a, _icon(64));
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.app;
    const size = 48.0;
    final missing = _installed == false;
    // Not on this phone: faded, with a small download mark.
    final icon = missing
        ? Stack(
            clipBehavior: Clip.none,
            children: [
              Opacity(opacity: 0.4, child: _icon(size)),
              Positioned(
                right: -4,
                bottom: -4,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Neon.surfaceHigh,
                    shape: BoxShape.circle,
                    border: Border.all(color: Neon.textDim, width: 1),
                  ),
                  child: Icon(Icons.download_rounded,
                      size: 13, color: Neon.textHi),
                ),
              ),
            ],
          )
        : _icon(size);
    return Tappable(
      onTap: _tap,
      semanticLabel: missing ? '${a.name}, not installed' : 'Open ${a.name}',
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: ExcludeSemantics(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              const SizedBox(height: 6),
              Text(a.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: NeonType.manrope(12, FontWeight.w700)
                      .copyWith(color: missing ? Neon.textDim : Neon.textLo)),
            ],
          ),
        ),
      ),
    );
  }
}
