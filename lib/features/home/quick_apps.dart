import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:simple_icons/simple_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/log.dart';
import '../../design/motion.dart';
import '../../design/neon_tokens.dart';

/// QUICK APPS (2026-11-08): the apps people open most, one tap away on
/// Home — where the "Order and shop" banners used to be. Each opens the
/// installed app; when it is not installed, its Play Store page (App
/// Store on an iPhone, for the apps that name their [iosScheme]).
class QuickApp {
  const QuickApp(this.name, this.pkgs, this.mark, this.color,
      {this.badge, this.iosScheme, this.iosStoreId});

  final String name;

  /// Candidate packages, first installed wins (Gallery differs by maker).
  final List<String> pkgs;
  final IconData mark;
  final Color color;

  /// The app's own icon, drawn, for when it is not installed ([mark] on
  /// white otherwise).
  final Widget Function(double size)? badge;

  /// iPhone: the app's URL scheme ('paypal'), which opens it and tells
  /// whether it is installed. Must also be listed under
  /// LSApplicationQueriesSchemes in ios/Runner/Info.plist.
  final String? iosScheme;

  /// iPhone: its App Store id (apps.apple.com/app/id<this>).
  final String? iosStoreId;
}

bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

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

/// PAYMENTS (2026-11-22): the payment apps, in their own Home section
/// above Quick Apps.
const paymentApps = <QuickApp>[
  QuickApp('GPay', ['com.google.android.apps.nbu.paisa.user'],
      SimpleIcons.googlepay, SimpleIconColors.googlepay),
  QuickApp('PhonePe', ['com.phonepe.app'], SimpleIcons.phonepe,
      SimpleIconColors.phonepe),
  QuickApp(
      'Paytm', ['net.one97.paytm'], SimpleIcons.paytm, SimpleIconColors.paytm,
      badge: _paytmBadge),
  QuickApp('PayPal', ['com.paypal.android.p2pmobile'], SimpleIcons.paypal,
      SimpleIconColors.paypal,
      iosScheme: 'paypal', iosStoreId: '283646709'),
];

/// Everything else on Quick Apps.
const otherApps = <QuickApp>[
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

/// Every app on both sections.
const quickApps = <QuickApp>[...paymentApps, ...otherApps];

const _channel = MethodChannel('hari/intent');

/// The installed package and its icon, read once per run (null: none installed).
final _found = <String, Future<(String, Uint8List)?>>{};

Future<(String, Uint8List)?> _lookup(QuickApp a) =>
    _found[a.name] ??= () async {
      if (_isIOS) {
        // No icon from another app on iOS: an empty PNG marks "installed"
        // and the tile draws [QuickApp.mark].
        final scheme = a.iosScheme;
        if (scheme != null) {
          try {
            if (await canLaunchUrl(Uri.parse('$scheme://'))) {
              return (scheme, Uint8List(0));
            }
          } catch (_) {}
        }
        _found.remove(a.name);
        return null;
      }
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
  if (_isIOS) {
    try {
      return await launchUrl(Uri.parse('${hit.$1}://'),
          mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
  try {
    final opened = await _channel
        .invokeMethod<String>('launchApp', {'name': a.name, 'pkg': hit.$1});
    return opened != null && opened.isNotEmpty;
  } catch (_) {
    return false;
  }
}

/// Its Play Store page (Gallery → Google Photos); on an iPhone, its App
/// Store page.
Future<void> _store(QuickApp a) async {
  if (_isIOS) {
    final id = a.iosStoreId;
    final page = id != null
        ? 'https://apps.apple.com/app/id$id'
        : 'https://apps.apple.com/search?term=${Uri.encodeQueryComponent(a.name)}';
    await launchUrl(Uri.parse(page), mode: LaunchMode.externalApplication);
    return;
  }
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
            Text("${a.name} Is Not Installed",
                textAlign: TextAlign.center,
                style: NeonType.manrope(20, FontWeight.w800)
                    .copyWith(color: Neon.textHi)),
            const SizedBox(height: 8),
            Text(
                "${a.name} is not installed on this phone. Please install it from the "
                "$_storeName, then tap it here to open it.",
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
                label: Text('Install ${a.name}',
                    style: NeonType.manrope(15, FontWeight.w800)),
                onPressed: () {
                  Navigator.of(sheet).pop();
                  _store(a);
                },
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(sheet).pop(),
              child: Text('Not Now', style: TextStyle(color: Neon.textLo)),
            ),
          ],
        ),
      ),
    ),
  );
}

String get _storeName => _isIOS ? 'App Store' : 'Play Store';

/// Home's "Quick Apps" section: the apps that are not payment apps.
class QuickApps extends StatelessWidget {
  const QuickApps({super.key});

  @override
  Widget build(BuildContext context) =>
      const _AppGrid(title: 'Quick Apps', apps: otherApps);
}

/// Home's "Payments" section: GPay, PhonePe, Paytm and PayPal.
class PaymentApps extends StatelessWidget {
  const PaymentApps({super.key});

  @override
  Widget build(BuildContext context) =>
      const _AppGrid(title: 'Payments', apps: paymentApps);
}

/// Up to five a row, the rows evened out (four: one row of four; six: two
/// of three) so no app sits alone on a last row.
int tilesPerRow(int n) {
  if (n <= 5) return n < 1 ? 1 : n;
  final rows = (n + 4) ~/ 5;
  return (n + rows - 1) ~/ rows;
}

class _AppGrid extends StatelessWidget {
  const _AppGrid({required this.title, required this.apps});
  final String title;
  final List<QuickApp> apps;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Padding(
            padding: const EdgeInsets.only(left: Neon.s1, bottom: 10),
            child: Text(title,
                style: NeonType.manrope(21, FontWeight.w800)
                    .copyWith(color: Neon.textHi, letterSpacing: -0.6)),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 6),
          decoration: Neon.glassBox(Neon.rLg),
          child: LayoutBuilder(builder: (context, c) {
            final w = c.maxWidth / tilesPerRow(apps.length);
            return Wrap(
              alignment: WrapAlignment.center,
              children: [
                for (final a in apps)
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
      child: png != null && png.isNotEmpty
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
