import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../design/apple_kit.dart';
import '../../design/motion.dart';
import '../../design/neon_tokens.dart';
import '../../design/neon_widgets.dart';
import '../../services/api_service.dart';
import '../cashback/cashback_screen.dart';
import 'partner_app.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  EVERYDAY SERVICES — Quick tools → Misc (owner, 2026-11-04: "apps we
///  use daily, where we as a company can earn commission"). The partner
///  list comes from the server (GET /go), and every open asks the server
///  for the link (GET /go/:id), which carries our affiliate tracking — so
///  partners and tracking ids change without an app release.
///  Each partner shows its own app icon (assets/brands/, from its site or
///  its Google Play listing), used to identify the partner.
/// ─────────────────────────────────────────────────────────────────────────
class _Partner {
  _Partner(Map<String, dynamic> j)
      : id = '${j['id']}',
        name = '${j['name']}',
        category = '${j['category']}',
        pkg = j['pkg'] as String?,
        cashback = j['cashback'] == true,
        cashbackText = '${j['cashbackText'] ?? ''}'.trim(),
        color = _hex('${j['color'] ?? ''}');
  final String id;

  /// A purchase here earns the user cashback (2026-11-27): opened through
  /// the tracked link, never straight into the installed app.
  final bool cashback;

  /// "Up to 6%" when the owner set a rate; empty otherwise.
  final String cashbackText;
  /// Its Android app: opened when installed, else its Play Store page.
  final String? pkg;
  final String name;
  final String category;
  final Color color;

  static Color _hex(String h) {
    final v = int.tryParse(h.replaceFirst('#', ''), radix: 16);
    return v == null ? const Color(0xFF7C4DFF) : Color(0xFF000000 | v);
  }
}

const _categoryIcons = <String, IconData>{
  'Fashion': Icons.checkroom_rounded,
  'Beauty': Icons.face_retouching_natural_rounded,
  'Shopping': Icons.shopping_bag_rounded,
  'Moving & delivery': Icons.local_shipping_rounded,
  'Home services': Icons.home_repair_service_rounded,
  'Medicines': Icons.medication_rounded,
  'Travel & stays': Icons.luggage_rounded,
  'Movies & events': Icons.local_movies_rounded,
  'Insurance': Icons.health_and_safety_rounded,
  'Gifts': Icons.card_giftcard_rounded,
};

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  List<_Partner>? _all;
  bool _failed = false;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final j = await ApiService.getJson('/go');
    if (!mounted) return;
    setState(() {
      _failed = j == null;
      _all = ((j?['merchants'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => _Partner(m.cast<String, dynamic>()))
          .toList();
    });
  }

  Future<void> _open(_Partner p) async {
    HapticFeedback.selectionClick();
    // Its own app when installed, else its Play Store page (2026-11-13) —
    // unless it earns cashback: then only the tracked link will do.
    if (opensInstalledAppFirst(pkg: p.pkg, cashback: p.cashback) &&
        await openPartnerApp(p.id, p.pkg)) {
      return;
    }
    final j = await ApiService.getJson('/go/${p.id}');
    final url = j?['url'] as String?;
    if (url == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Unable to open ${p.name}.")));
      }
      return;
    }
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final all = _all;
    return NeonScaffold(
      appBar: appleAppBar(context, 'Everyday Services'),
      body: all == null
          ? const Center(
              child: NeonLoader.inline(size: 28, semanticLabel: 'Loading'))
          : _failed
              ? Center(
                  child: TextButton(
                      onPressed: () {
                        setState(() => _all = null);
                        _load();
                      },
                      child: const Text("Unable to load. Retry")))
              : _list(all),
    );
  }

  Widget _list(List<_Partner> all) {
    final q = _q.trim().toLowerCase();
    final shown = q.isEmpty
        ? all
        : all
            .where((p) =>
                p.name.toLowerCase().contains(q) ||
                p.category.toLowerCase().contains(q))
            .toList();
    final cats = <String>[];
    for (final p in shown) {
      if (!cats.contains(p.category)) cats.add(p.category);
    }
    return ListView(
      padding: EdgeInsets.fromLTRB(
          16, 8, 16, 28 + MediaQuery.paddingOf(context).bottom),
      children: [
        Text('All Your Daily Services',
            style: NeonType.manrope(26, FontWeight.w800)
                .copyWith(color: Neon.textHi, letterSpacing: -0.6)),
        const SizedBox(height: 4),
        Text('Shopping, moving, travel and more, in one place.',
            style: TextStyle(color: Neon.textLo, fontSize: 14.5)),
        const SizedBox(height: 14),
        // Cashback (2026-11-27): shown only when the server offers it on
        // at least one partner.
        if (all.any((p) => p.cashback)) ...[
          CashbackBanner(
              onOpen: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const CashbackScreen()))),
          const SizedBox(height: 14),
        ],
        TextField(
          onChanged: (v) => setState(() => _q = v),
          style: TextStyle(color: Neon.textHi),
          decoration: InputDecoration(
            hintText: 'Search for a service',
            prefixIcon: Icon(Icons.search_rounded, color: Neon.textDim),
            filled: true,
            fillColor: Neon.glassFill.colors.first,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Neon.glassEdge.first)),
          ),
        ),
        const SizedBox(height: 8),
        for (final c in cats) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
            child: Row(children: [
              Icon(_categoryIcons[c] ?? Icons.apps_rounded,
                  size: 18, color: Neon.violet),
              const SizedBox(width: 8),
              Text(c.toUpperCase(),
                  style: NeonType.eyebrow.copyWith(color: Neon.textLo)),
            ]),
          ),
          Reveal(
            child: GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 10,
              childAspectRatio: 0.9,
              children: [
                for (final p in shown.where((p) => p.category == c))
                  _tile(p),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _tile(_Partner p) {
    final words = p.name.replaceAll(RegExp(r'[^A-Za-z0-9 ]'), ' ').split(' ')
      ..removeWhere((w) => w.isEmpty);
    final initials = words.length > 1
        ? '${words[0][0]}${words[1][0]}'
        : p.name.substring(0, p.name.length >= 2 ? 2 : 1);
    final ink = p.color.computeLuminance() > 0.5 ? Colors.black : Colors.white;
    return Semantics(
      button: true,
      label: p.cashback
          ? 'Open ${p.name}. Earns cashback${p.cashbackText.isEmpty ? '' : ', ${p.cashbackText}'}'
          : 'Open ${p.name}',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _open(p),
        child: Column(
          children: [
            // THE BRAND'S OWN ICON (owner, 2026-11-04: "use real brand
            // icons"), bundled in assets/brands/; its colour and initials
            // only if the image is ever missing. A small ₹ marks a
            // partner where a purchase earns cashback.
            Stack(clipBehavior: Clip.none, children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: p.color,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.30),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                      spreadRadius: -4),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset('assets/brands/${p.id}.png',
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, __, ___) => Center(
                        child: Text(initials.toUpperCase(),
                            style: NeonType.manrope(19, FontWeight.w800)
                                .copyWith(color: ink, letterSpacing: -0.3)),
                      )),
            ),
            if (p.cashback)
              const Positioned(top: -5, right: -5, child: CashbackDot()),
            ]),
            const SizedBox(height: 7),
            Text(p.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Neon.textHi,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    height: 1.2)),
          ],
        ),
      ),
    );
  }
}
