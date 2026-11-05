import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../design/neon_tokens.dart';
import '../../services/api_service.dart';
import 'services_screen.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  POPULAR APPS on Home (client, 2026-11-05: "Swiggy, Zomato, Blinkit and
///  other services should be placed in that area… put Uber, Ola and the
///  others in that place"). The partners marked `home` on the server
///  (GET /go), in rows by kind, each opened through /go/:id so the
///  company's tracking rides along. "See all" opens Everyday services.
/// ─────────────────────────────────────────────────────────────────────────
class PopularAppsSection extends StatefulWidget {
  const PopularAppsSection({super.key, required this.onOpen});
  final void Function(Widget page) onOpen;

  @override
  State<PopularAppsSection> createState() => _PopularAppsSectionState();
}

class _App {
  _App(Map<String, dynamic> j)
      : id = '${j['id']}',
        name = '${j['name']}',
        category = '${j['category']}';
  final String id;
  final String name;
  final String category;
}

const _order = ['Food & groceries', 'Rides', 'Shopping'];
const _icons = <String, IconData>{
  'Food & groceries': Icons.fastfood_rounded,
  'Rides': Icons.local_taxi_rounded,
  'Shopping': Icons.shopping_bag_rounded,
};

class _PopularAppsSectionState extends State<PopularAppsSection> {
  List<_App> _apps = const [];

  @override
  void initState() {
    super.initState();
    ApiService.getJson('/go').then((j) {
      if (!mounted || j == null) return;
      setState(() => _apps = ((j['merchants'] as List?) ?? const [])
          .whereType<Map>()
          .where((m) => m['home'] == true)
          .map((m) => _App(m.cast<String, dynamic>()))
          .toList());
    });
  }

  Future<void> _open(_App a) async {
    HapticFeedback.selectionClick();
    final j = await ApiService.getJson('/go/${a.id}');
    final url = j?['url'] as String?;
    if (url != null) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_apps.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: Neon.s1, bottom: 6),
          child: Row(
            children: [
              Text('Popular apps',
                  style: NeonType.manrope(21, FontWeight.w800)
                      .copyWith(color: Neon.textHi, letterSpacing: -0.6)),
              const Spacer(),
              TextButton(
                onPressed: () => widget.onOpen(const ServicesScreen()),
                child: Text('See all',
                    style: TextStyle(
                        color: Neon.violet, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
          decoration: Neon.glassBox(Neon.rCard),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final c in _order)
                if (_apps.any((a) => a.category == c)) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 10),
                    child: Row(children: [
                      Icon(_icons[c], size: 15, color: Neon.violet),
                      const SizedBox(width: 6),
                      Text(c.toUpperCase(),
                          style:
                              NeonType.eyebrow.copyWith(color: Neon.textLo)),
                    ]),
                  ),
                  // Five to a row, each row exactly as tall as its icons
                  // (a grid's fixed aspect left a gap under every row).
                  LayoutBuilder(
                    builder: (context, box) => Wrap(
                      runSpacing: 10,
                      children: [
                        for (final a in _apps.where((a) => a.category == c))
                          SizedBox(width: box.maxWidth / 5, child: _tile(a)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _tile(_App a) => Semantics(
        button: true,
        label: 'Open ${a.name}',
        excludeSemantics: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _open(a),
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                        spreadRadius: -4),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset('assets/brands/${a.id}.png',
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (_, __, ___) => Container(
                        color: Neon.violet,
                        alignment: Alignment.center,
                        child: Text(a.name.substring(0, 1),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800)))),
              ),
              const SizedBox(height: 5),
              Text(a.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Neon.textHi,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
}
