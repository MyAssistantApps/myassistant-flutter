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
  const QuickApp(this.name, this.pkgs, this.mark, this.color);

  final String name;

  /// Candidate packages, first installed wins (Gallery differs by maker).
  final List<String> pkgs;
  final IconData mark;
  final Color color;
}

const quickApps = <QuickApp>[
  QuickApp('GPay', ['com.google.android.apps.nbu.paisa.user'],
      SimpleIcons.googlepay, SimpleIconColors.googlepay),
  QuickApp('PhonePe', ['com.phonepe.app'], SimpleIcons.phonepe,
      SimpleIconColors.phonepe),
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

Future<(String, Uint8List)?> _lookup(QuickApp a) => _found[a.name] ??= () async {
      for (final pkg in a.pkgs) {
        try {
          final png = await _channel
              .invokeMethod<Uint8List>('appIcon', {'pkg': pkg, 'size': 144});
          if (png != null) return (pkg, png);
        } catch (_) {}
      }
      return null;
    }();

Future<void> _open(QuickApp a) async {
  AppLog.add('home', 'quick app ${a.name}');
  final hit = await _lookup(a);
  if (hit != null) {
    try {
      final opened = await _channel
          .invokeMethod<String>('launchApp', {'name': a.name, 'pkg': hit.$1});
      if (opened != null && opened.isNotEmpty) return;
    } catch (_) {}
  }
  // Not installed: its Play Store page (Gallery → Google Photos).
  final pkg = a.pkgs.last;
  final market = Uri.parse('market://details?id=$pkg');
  if (!await launchUrl(market, mode: LaunchMode.externalApplication)) {
    await launchUrl(
        Uri.parse('https://play.google.com/store/apps/details?id=$pkg'),
        mode: LaunchMode.externalApplication);
  }
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

  @override
  void initState() {
    super.initState();
    _lookup(widget.app).then((hit) {
      if (mounted && hit != null) setState(() => _png = hit.$2);
    });
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.app;
    const size = 48.0;
    final png = _png;
    final icon = ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.26),
      child: png != null
          ? Image.memory(png,
              width: size, height: size, fit: BoxFit.cover, gaplessPlayback: true)
          : Container(
              width: size,
              height: size,
              color: Colors.white,
              alignment: Alignment.center,
              child: Icon(a.mark, color: a.color, size: size * 0.56),
            ),
    );
    return Tappable(
      onTap: () => _open(a),
      semanticLabel: 'Open ${a.name}',
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
                      .copyWith(color: Neon.textLo)),
            ],
          ),
        ),
      ),
    );
  }
}
