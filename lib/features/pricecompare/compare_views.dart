import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/motion.dart';
import '../../design/neon_tokens.dart';
import 'price_models.dart';
import 'price_widgets.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  EACH COMPARISON IN ITS OWN SHAPE (2026-11-07, Manish: "all the compare
///  pages should be a unique UI design with more detailed information").
///  The shared page (best price, the AI's verdict, alerts, sources) keeps
///  its parts; what is compared is shown the way that kind is chosen:
///
///   • Product — the specs, highlights and rating; each store's delivery,
///     EMI, exchange, warranty and seller.
///   • Hotel   — hotel cards: stars, guest rating, area, room, amenities,
///     free cancellation and breakfast, per night and for the stay.
///   • Ride    — the route (distance, time, traffic), quick picks, and the
///     apps' fares grouped by ride type with pickup time and surge.
///   • Grocery — the delivery race, price per kg/l, delivery fee and the
///     total to pay, and a saving tip.
///
///  Everything shown comes from the answer; what it left out is left out.
/// ─────────────────────────────────────────────────────────────────────────

typedef LogoOf = Widget Function(String store, double size);

/// Opens the offer's page, or null when it has none.
typedef OpenOf = VoidCallback? Function(PriceOffer o);

Widget _section(String title, {String? trailing, IconData? icon}) => Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Row(
        children: [
          if (icon != null) ...[Icon(icon, size: 19, color: Neon.violet), const SizedBox(width: 8)],
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title,
                  style: NeonType.manrope(17, FontWeight.w800).copyWith(color: Neon.textHi, letterSpacing: -0.3)),
            ),
          ),
          if (trailing != null)
            Flexible(
              child: Text(trailing,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(color: Neon.textDim, fontSize: 12.5)),
            ),
        ],
      ),
    );

Widget _chip(IconData icon, String text, Color c, {bool filled = false}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: filled ? (Neon.isDark ? 0.20 : 0.12) : 0.0),
        borderRadius: BorderRadius.circular(Neon.rPill),
        border: Border.all(color: c.withValues(alpha: filled ? 0.0 : 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: c),
          const SizedBox(width: 5),
          Flexible(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: filled ? c : Neon.textHi, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

Widget _tag(String text, Color c) => PriceBadge(text, c);

Widget _tappable({required Widget child, VoidCallback? onTap, String? label}) => onTap == null
    ? child
    : Semantics(
        button: true,
        label: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(Neon.rLg),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: child,
        ),
      );

String _mins(double m) => m >= 60 ? '${m ~/ 60} h ${(m % 60).round()} min' : '${m.round()} min';

// ═════════════════════════════════════════════════════════════════════════
//  PRODUCT
// ═════════════════════════════════════════════════════════════════════════

/// About the product: its photo, brand, rating, highlights and key specs.
class ProductDetailsCard extends StatelessWidget {
  const ProductDetailsCard({super.key, required this.result});
  final PriceResult result;

  static bool hasAny(PriceResult r) {
    final f = r.facts;
    return f.pairs('specs').isNotEmpty || f.strs('highlights').isNotEmpty || f.num('rating') != null;
  }

  @override
  Widget build(BuildContext context) {
    final f = result.facts;
    final specs = f.pairs('specs');
    final highlights = f.strs('highlights', max: 4);
    final rating = f.num('rating');
    final reviews = f.num('reviews');
    final brand = f.str('brand');
    final image = f.str('image');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _section('About this product', icon: Icons.info_outline_rounded),
        Container(
          decoration: Neon.glassBox(Neon.rCard),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (image.startsWith('https://')) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: 84,
                          height: 84,
                          color: Colors.white,
                          padding: const EdgeInsets.all(6),
                          child: Image.network(image,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) =>
                                  Icon(Icons.inventory_2_rounded, color: Neon.textDim, size: 36)),
                        ),
                      ),
                      const SizedBox(width: 14),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (brand.isNotEmpty)
                            Text(brand.toUpperCase(),
                                style: NeonType.eyebrow.copyWith(color: Neon.violet, letterSpacing: 1.2)),
                          if (rating != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: rating >= 4 ? Neon.success : (rating >= 3 ? Neon.warning : Neon.error),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(rating.toStringAsFixed(1),
                                          style: NeonType.manrope(14, FontWeight.w900).copyWith(color: Colors.white)),
                                      const SizedBox(width: 3),
                                      const Icon(Icons.star_rounded, size: 14, color: Colors.white),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(reviews == null ? 'Rating' : '${_count(reviews)} ratings & reviews',
                                      style: TextStyle(color: Neon.textLo, fontSize: 12.5)),
                                ),
                              ],
                            ),
                          ],
                          for (final h in highlights)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.check_circle_rounded, size: 15, color: Neon.success),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(h, style: TextStyle(color: Neon.textHi, fontSize: 13, height: 1.3)),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (specs.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  color: Neon.violet.withValues(alpha: Neon.isDark ? 0.10 : 0.06),
                  child: Text('KEY SPECIFICATIONS', style: NeonType.eyebrow.copyWith(color: Neon.textLo)),
                ),
                for (final (i, (k, v)) in specs.indexed)
                  Container(
                    color: i.isOdd ? Neon.surfaceHigh.withValues(alpha: 0.35) : null,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 110,
                          child: Text(k, style: TextStyle(color: Neon.textLo, fontSize: 13)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(v,
                              style: TextStyle(
                                  color: Neon.textHi, fontSize: 13, fontWeight: FontWeight.w600, height: 1.3)),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 6),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static String _count(double n) => n >= 100000
      ? '${(n / 100000).toStringAsFixed(1)}L'
      : (n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}K' : '${n.round()}');
}

/// A store's own terms for the product: delivery, EMI, exchange, warranty,
/// seller — shown under its price.
class ProductOfferExtras extends StatelessWidget {
  const ProductOfferExtras({super.key, required this.offer});
  final PriceOffer offer;

  @override
  Widget build(BuildContext context) {
    final i = offer.info;
    final items = <(IconData, String, Color)>[
      if (i.str('delivery').isNotEmpty) (Icons.local_shipping_rounded, i.str('delivery'), Neon.cyan),
      if (i.str('emi').isNotEmpty) (Icons.credit_card_rounded, i.str('emi'), Neon.violet),
      if (i.str('exchange').isNotEmpty) (Icons.swap_horiz_rounded, i.str('exchange'), Neon.success),
      if (i.str('warranty').isNotEmpty) (Icons.verified_user_rounded, i.str('warranty'), Neon.warning),
      if (i.str('seller').isNotEmpty) (Icons.storefront_rounded, 'Sold by ${i.str('seller')}', Neon.textLo),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [for (final (ic, t, c) in items) _chip(ic, t, c, filled: true)],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
//  HOTEL
// ═════════════════════════════════════════════════════════════════════════

/// The stay at a glance: where, when, how many nights and guests.
class HotelStayCard extends StatelessWidget {
  const HotelStayCard({super.key, required this.result});
  final PriceResult result;

  @override
  Widget build(BuildContext context) {
    final f = result.facts;
    final city = f.str('city');
    final inD = f.str('checkIn'), outD = f.str('checkOut');
    final nights = f.num('nights'), guests = f.num('guests');
    final avg = f.num('averagePerNight');
    Widget cell(IconData icon, String label, String value) => Expanded(
          child: Column(
            children: [
              Icon(icon, size: 20, color: Neon.violet),
              const SizedBox(height: 4),
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: NeonType.manrope(14, FontWeight.w800).copyWith(color: Neon.textHi)),
              Text(label, style: TextStyle(color: Neon.textDim, fontSize: 11)),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: Neon.glassBox(Neon.rCard),
      child: Column(
        children: [
          if (city.isNotEmpty || inD.isNotEmpty)
            Row(
              children: [
                Icon(Icons.location_city_rounded, color: Neon.textLo, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    [if (city.isNotEmpty) city, if (inD.isNotEmpty) '$inD${outD.isEmpty ? '' : ' → $outD'}']
                        .join(' · '),
                    style: NeonType.manrope(14.5, FontWeight.w800).copyWith(color: Neon.textHi),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              cell(Icons.nights_stay_rounded, 'nights', nights == null ? '—' : '${nights.round()}'),
              cell(Icons.people_alt_rounded, 'guests', guests == null ? '—' : '${guests.round()}'),
              cell(
                  Icons.hotel_rounded,
                  'hotels',
                  '${{
                    for (final o in result.offers) o.info.str('hotel').isEmpty ? o.title : o.info.str('hotel')
                  }.length}'),
              cell(Icons.payments_rounded, 'avg / night', avg == null ? '—' : rupees(avg)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Every hotel as a card, sortable by price or rating.
class HotelList extends StatefulWidget {
  const HotelList({super.key, required this.result, required this.logo, required this.open});
  final PriceResult result;
  final LogoOf logo;
  final OpenOf open;

  @override
  State<HotelList> createState() => _HotelListState();
}

class _HotelListState extends State<HotelList> {
  bool _byRating = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final list = [...r.offers];
    if (_byRating) list.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
    final cheapest = r.lowest;
    PriceOffer? topRated;
    for (final o in r.offers) {
      if (o.rating != null && (topRated == null || o.rating! > topRated.rating!)) topRated = o;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _section('Hotels', trailing: '${r.offers.length} found', icon: Icons.hotel_rounded)),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final (label, rating) in [('Lowest price', false), ('Top rated', true)])
                ChoiceChip(
                  label: Text(label),
                  selected: _byRating == rating,
                  onSelected: (_) => setState(() => _byRating = rating),
                ),
            ],
          ),
        ),
        for (final o in list) ...[
          _hotel(o, best: identical(o, cheapest), top: identical(o, topRated) && !identical(o, cheapest)),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _hotel(PriceOffer o, {required bool best, required bool top}) {
    final i = o.info;
    final name = i.str('hotel').isNotEmpty ? i.str('hotel') : (o.title.isNotEmpty ? o.title : o.store);
    final stars = i.num('stars');
    final reviews = i.num('reviews');
    final area = [i.str('area'), i.str('distance')].where((t) => t.isNotEmpty).join(' · ');
    final amen = i.strs('amenities', max: 6);
    final total = i.num('total');
    final cancel = i.flag('freeCancellation');
    final breakfast = i.flag('breakfast');
    final rating = o.rating;
    final (word, rc) = rating == null
        ? ('', Neon.textLo)
        : rating >= 4.5
            ? ('Excellent', Neon.success)
            : rating >= 4
                ? ('Very good', Neon.success)
                : rating >= 3.5
                    ? ('Good', Neon.cyan)
                    : ('Average', Neon.warning);
    final open = widget.open(o);
    return _tappable(
      onTap: open,
      label: '$name, ${rupees(o.price)} a night on ${o.store}',
      child: Container(
        decoration: Neon.glassBox(Neon.rCard).copyWith(
          border: best ? Border.all(color: Neon.success.withValues(alpha: 0.6), width: 1.4) : null,
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (best || top)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _tag(best ? 'BEST DEAL' : 'TOP RATED', best ? Neon.success : Neon.violet),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Neon.violet.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.apartment_rounded, color: Neon.violet, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: NeonType.manrope(15.5, FontWeight.w800).copyWith(color: Neon.textHi, height: 1.25)),
                      if (stars != null)
                        Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
                          for (var s = 0; s < stars.round().clamp(1, 5); s++)
                            Icon(Icons.star_rounded, size: 14, color: Neon.warning),
                          const SizedBox(width: 4),
                          Text('${stars.round()}-star hotel', style: TextStyle(color: Neon.textDim, fontSize: 11.5)),
                        ]),
                      if (area.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Row(
                            children: [
                              Icon(Icons.place_rounded, size: 14, color: Neon.textLo),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(area,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: Neon.textLo, fontSize: 12.5)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                if (rating != null) ...[
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: rc, borderRadius: BorderRadius.circular(8)),
                        child: Text(rating.toStringAsFixed(1),
                            style: NeonType.manrope(14, FontWeight.w900).copyWith(color: Colors.white)),
                      ),
                      const SizedBox(height: 2),
                      Text(word, style: NeonType.manrope(11.5, FontWeight.w800).copyWith(color: rc)),
                      if (reviews != null)
                        Text('${reviews.round()} reviews', style: TextStyle(color: Neon.textDim, fontSize: 10.5)),
                    ],
                  ),
                ],
              ],
            ),
            if (i.str('room').isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.bed_rounded, size: 16, color: Neon.textLo),
                  const SizedBox(width: 6),
                  Expanded(child: Text(i.str('room'), style: TextStyle(color: Neon.textHi, fontSize: 13))),
                ],
              ),
            ],
            if (cancel == true || breakfast == true || amen.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (cancel == true)
                    _chip(Icons.event_available_rounded, 'Free cancellation', Neon.success, filled: true),
                  if (breakfast == true)
                    _chip(Icons.free_breakfast_rounded, 'Breakfast included', Neon.warning, filled: true),
                  for (final a in amen) _chip(_amenityIcon(a), a, Neon.textLo),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Divider(height: 1, color: Neon.hairline),
            const SizedBox(height: 12),
            Row(
              children: [
                widget.logo(o.store, 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('on ${o.store}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: NeonType.manrope(13.5, FontWeight.w700).copyWith(color: Neon.textHi)),
                      if (total != null)
                        Text('${rupees(total)} for the stay', style: TextStyle(color: Neon.textLo, fontSize: 12)),
                    ],
                  ),
                ),
                Text.rich(TextSpan(children: [
                  TextSpan(
                      text: rupees(o.price),
                      style: NeonType.manrope(19, FontWeight.w800).copyWith(color: best ? Neon.success : Neon.textHi)),
                  TextSpan(text: ' /night', style: TextStyle(color: Neon.textDim, fontSize: 12)),
                ])),
                if (open != null) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded, color: Neon.textDim),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  static IconData _amenityIcon(String a) {
    final t = a.toLowerCase();
    if (t.contains('pool')) return Icons.pool_rounded;
    if (t.contains('wi')) return Icons.wifi_rounded;
    if (t.contains('park')) return Icons.local_parking_rounded;
    if (t.contains('spa')) return Icons.spa_rounded;
    if (t.contains('gym') || t.contains('fitness')) return Icons.fitness_center_rounded;
    if (t.contains('restaurant') || t.contains('dining')) return Icons.restaurant_rounded;
    if (t.contains('bar')) return Icons.local_bar_rounded;
    if (t.contains('ac') || t.contains('air')) return Icons.ac_unit_rounded;
    if (t.contains('beach') || t.contains('sea')) return Icons.beach_access_rounded;
    if (t.contains('airport') || t.contains('shuttle')) return Icons.airport_shuttle_rounded;
    return Icons.check_rounded;
  }
}

// ═════════════════════════════════════════════════════════════════════════
//  RIDE
// ═════════════════════════════════════════════════════════════════════════

/// The trip: from and to, distance, time and traffic.
class RideRouteCard extends StatelessWidget {
  const RideRouteCard({super.key, required this.result});
  final PriceResult result;

  @override
  Widget build(BuildContext context) {
    final f = result.facts;
    final from = f.str('from'), to = f.str('to');
    final km = f.num('distanceKm'), min = f.num('durationMin');
    final traffic = f.str('traffic').toLowerCase();
    final tc = traffic.startsWith('heavy') ? Neon.error : (traffic.startsWith('moder') ? Neon.warning : Neon.success);
    Widget stop(Color c, String label, String place, {bool last = false}) => Row(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: last ? Colors.transparent : c,
                shape: last ? BoxShape.rectangle : BoxShape.circle,
                border: Border.all(color: c, width: 3),
                borderRadius: last ? BorderRadius.circular(3) : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: NeonType.eyebrow.copyWith(color: Neon.textDim, fontSize: 10)),
                  Text(place.isEmpty ? '—' : place,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: NeonType.manrope(14.5, FontWeight.w800).copyWith(color: Neon.textHi)),
                ],
              ),
            ),
          ],
        );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: Neon.glassBox(Neon.rCard),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          stop(Neon.success, 'PICKUP', from.isEmpty ? result.product : from),
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Container(width: 2, height: 22, color: Neon.hairline),
          ),
          stop(Neon.error, 'DROP', to, last: true),
          if (km != null || min != null || traffic.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (km != null)
                  _chip(Icons.straighten_rounded, '${km.toStringAsFixed(km < 10 ? 1 : 0)} km', Neon.cyan, filled: true),
                if (min != null) _chip(Icons.schedule_rounded, 'about ${_mins(min)}', Neon.violet, filled: true),
                if (traffic.isNotEmpty)
                  _chip(Icons.traffic_rounded, '${traffic[0].toUpperCase()}${traffic.substring(1)} traffic', tc,
                      filled: true),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Quick picks, then every app's fare grouped by ride type.
class RideOptions extends StatelessWidget {
  const RideOptions({super.key, required this.result, required this.logo, required this.open});
  final PriceResult result;
  final LogoOf logo;
  final OpenOf open;

  static const _order = ['Bike', 'Auto', 'Mini', 'Sedan', 'SUV', 'Premium', 'Other'];

  static String _type(PriceOffer o) {
    final t = '${o.info.str('ride')} ${o.title}'.toLowerCase();
    if (t.contains('bike') || t.contains('moto')) return 'Bike';
    if (t.contains('auto')) return 'Auto';
    if (t.contains('suv') || t.contains('xl') || t.contains('innova')) return 'SUV';
    if (t.contains('prem') || t.contains('lux') || t.contains('black')) return 'Premium';
    if (t.contains('sedan') || t.contains('prime') || t.contains('premier')) return 'Sedan';
    if (t.contains('mini') || t.contains('go') || t.contains('hatch') || t.contains('cab')) return 'Mini';
    return 'Other';
  }

  static IconData _icon(String type) => switch (type) {
        'Bike' => Icons.two_wheeler_rounded,
        'Auto' => Icons.electric_rickshaw_rounded,
        'SUV' => Icons.airport_shuttle_rounded,
        'Premium' => Icons.local_taxi_rounded,
        _ => Icons.directions_car_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<PriceOffer>>{};
    for (final o in result.offers) {
      (groups[_type(o)] ??= []).add(o);
    }
    for (final g in groups.values) {
      g.sort((a, b) => a.price.compareTo(b.price));
    }
    final cheapest = result.lowest;
    PriceOffer? fastest;
    for (final o in result.offers) {
      final m = o.info.num('pickupMin');
      if (m != null && (fastest == null || m < fastest.info.num('pickupMin')!)) fastest = o;
    }
    PriceOffer? roomy;
    for (final t in ['SUV', 'Sedan', 'Premium']) {
      if (groups[t]?.isNotEmpty ?? false) {
        roomy = groups[t]!.first;
        break;
      }
    }
    Widget pick(String label, IconData icon, Color c, PriceOffer o) => Expanded(
          child: _tappable(
            onTap: open(o),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.withValues(alpha: Neon.isDark ? 0.14 : 0.08),
                borderRadius: BorderRadius.circular(Neon.rLg),
                border: Border.all(color: c.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(icon, size: 15, color: c),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: NeonType.manrope(11, FontWeight.w900).copyWith(color: c, letterSpacing: 0.6)),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    logo(o.store, 22),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(_type(o),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Neon.textLo, fontSize: 12)),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(rupees(o.price),
                        style: NeonType.manrope(17, FontWeight.w800).copyWith(color: Neon.textHi)),
                  ),
                  if (o.info.num('pickupMin') != null)
                    Text('${o.info.num('pickupMin')!.round()} min away',
                        style: TextStyle(color: Neon.textDim, fontSize: 11)),
                ],
              ),
            ),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _section('Quick picks', icon: Icons.bolt_rounded),
        Row(
          children: [
            if (cheapest != null) pick('CHEAPEST', Icons.savings_rounded, Neon.success, cheapest),
            if (fastest != null) ...[
              const SizedBox(width: 8),
              pick('FASTEST PICKUP', Icons.timer_rounded, Neon.cyan, fastest)
            ],
            if (roomy != null) ...[
              const SizedBox(width: 8),
              pick('MOST ROOM', Icons.weekend_rounded, Neon.violet, roomy)
            ],
          ],
        ),
        const SizedBox(height: 24),
        _section('Fares by ride type', trailing: '${result.offers.length} options', icon: Icons.local_taxi_rounded),
        for (final type in _order)
          if (groups[type] case final g? when g.isNotEmpty) ...[
            Container(
              decoration: Neon.glassBox(Neon.rCard),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                    color: Neon.violet.withValues(alpha: Neon.isDark ? 0.12 : 0.07),
                    child: Row(
                      children: [
                        Icon(_icon(type), color: Neon.violet, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(type == 'Other' ? 'Other rides' : type,
                              style: NeonType.manrope(15, FontWeight.w800).copyWith(color: Neon.textHi)),
                        ),
                        if (g.first.info.num('seats') != null)
                          Row(children: [
                            Icon(Icons.person_rounded, size: 15, color: Neon.textLo),
                            Text(' ${g.first.info.num('seats')!.round()}',
                                style: TextStyle(color: Neon.textLo, fontSize: 12.5)),
                          ]),
                      ],
                    ),
                  ),
                  for (final (k, o) in g.indexed) ...[
                    if (k > 0) Divider(height: 1, indent: 14, endIndent: 14, color: Neon.hairline),
                    _tappable(
                      onTap: open(o),
                      label: '$type on ${o.store}, ${rupees(o.price)}',
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                        child: Row(
                          children: [
                            logo(o.store, 34),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(o.store,
                                      style: NeonType.manrope(14.5, FontWeight.w800).copyWith(color: Neon.textHi)),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 2,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      if (o.title.isNotEmpty)
                                        Text(o.title, style: TextStyle(color: Neon.textLo, fontSize: 12)),
                                      if (o.info.num('pickupMin') != null)
                                        Text('· ${o.info.num('pickupMin')!.round()} min away',
                                            style: TextStyle(color: Neon.textLo, fontSize: 12)),
                                      if (o.info.flag('surge') == true) _tag('SURGE', Neon.error),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Text(rupees(o.price),
                                style: NeonType.manrope(17, FontWeight.w800)
                                    .copyWith(color: k == 0 ? Neon.success : Neon.textHi)),
                            if (open(o) != null) Icon(Icons.chevron_right_rounded, color: Neon.textDim),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
//  GROCERY
// ═════════════════════════════════════════════════════════════════════════

/// The delivery race, then each app's pack, price per kg/l, delivery fee
/// and the total to pay.
class GroceryView extends StatelessWidget {
  const GroceryView({super.key, required this.result, required this.logo, required this.open});
  final PriceResult result;
  final LogoOf logo;
  final OpenOf open;

  double _total(PriceOffer o) => o.price + (o.info.num('deliveryFee') ?? 0);

  @override
  Widget build(BuildContext context) {
    final r = result;
    final offers = [...r.offers]..sort((a, b) => _total(a).compareTo(_total(b)));
    final timed = [
      for (final o in r.offers)
        if (o.info.num('deliveryMin') != null) o
    ]..sort((a, b) => a.info.num('deliveryMin')!.compareTo(b.info.num('deliveryMin')!));
    final slowest = timed.isEmpty ? 0.0 : timed.last.info.num('deliveryMin')!;
    PriceOffer? perUnit;
    for (final o in r.offers) {
      final u = o.info.num('unitPrice');
      if (u != null && (perUnit == null || u < perUnit.info.num('unitPrice')!)) perUnit = o;
    }
    final f = r.facts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (f.str('tip').isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Neon.warning.withValues(alpha: Neon.isDark ? 0.14 : 0.10),
              borderRadius: BorderRadius.circular(Neon.rLg),
              border: Border.all(color: Neon.warning.withValues(alpha: 0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_rounded, color: Neon.warning, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(f.str('tip'), style: TextStyle(color: Neon.textHi, fontSize: 13.5, height: 1.4))),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
        if (timed.isNotEmpty) ...[
          _section('Delivery race', icon: Icons.electric_bolt_rounded, trailing: 'fastest first'),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: Neon.glassBox(Neon.rCard),
            child: Column(
              children: [
                for (final (k, o) in timed.indexed)
                  Padding(
                    padding: EdgeInsets.only(top: k == 0 ? 0 : 12),
                    child: Row(
                      children: [
                        logo(o.store, 30),
                        const SizedBox(width: 10),
                        Expanded(
                          child: LayoutBuilder(builder: (_, c) {
                            final m = o.info.num('deliveryMin')!;
                            final w = slowest <= 0 ? 1.0 : (m / slowest).clamp(0.15, 1.0);
                            return Stack(
                              children: [
                                Container(
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: Neon.hairline,
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                ),
                                AnimatedContainer(
                                  duration: Motion.short,
                                  height: 26,
                                  width: c.maxWidth * w,
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 10),
                                  decoration: BoxDecoration(
                                    color: k == 0 ? Neon.success : Neon.cyan.withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  child: Text(
                                    k == 0 ? '⚡ ${m.round()} min' : '${m.round()} min',
                                    maxLines: 1,
                                    style: NeonType.manrope(12, FontWeight.w900).copyWith(color: Colors.white),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
        _section('What you pay', icon: Icons.shopping_basket_rounded, trailing: 'cheapest total first'),
        for (final (k, o) in offers.indexed) ...[
          _row(o,
              cheapest: k == 0, fastest: timed.isNotEmpty && identical(o, timed.first), perUnit: identical(o, perUnit)),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _row(PriceOffer o, {required bool cheapest, required bool fastest, required bool perUnit}) {
    final i = o.info;
    final fee = i.num('deliveryFee');
    final unit = i.num('unitPrice');
    final u = i.str('unit');
    final pack = i.str('pack');
    final open = this.open(o);
    return _tappable(
      onTap: open,
      label: '${o.store}, ${rupees(_total(o))} total',
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: Neon.glassBox(Neon.rCard).copyWith(
          border: cheapest ? Border.all(color: Neon.success.withValues(alpha: 0.6), width: 1.4) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                logo(o.store, 42),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(o.store, style: NeonType.manrope(15.5, FontWeight.w800).copyWith(color: Neon.textHi)),
                      if (pack.isNotEmpty || o.title.isNotEmpty)
                        Text(pack.isNotEmpty ? pack : o.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Neon.textLo, fontSize: 12.5)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(rupees(_total(o)),
                        style: NeonType.manrope(19, FontWeight.w800)
                            .copyWith(color: cheapest ? Neon.success : Neon.textHi)),
                    Text('to pay', style: TextStyle(color: Neon.textDim, fontSize: 11)),
                  ],
                ),
                if (open != null) Icon(Icons.chevron_right_rounded, color: Neon.textDim),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _cell('Item', rupees(o.price)),
                _cell('Delivery', fee == null ? '—' : (fee == 0 ? 'Free' : rupees(fee)),
                    color: fee == 0 ? Neon.success : null),
                _cell(u.isEmpty ? 'Per unit' : 'Per $u', unit == null ? '—' : rupees(unit)),
                _cell('Arrives', i.num('deliveryMin') == null ? '—' : '${i.num('deliveryMin')!.round()} min'),
              ],
            ),
            if (cheapest || fastest || perUnit || !o.inStock) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (cheapest) _tag('CHEAPEST TOTAL', Neon.success),
                  if (fastest) _tag('FASTEST', Neon.cyan),
                  if (perUnit) _tag('BEST PER ${u.isEmpty ? 'UNIT' : u.toUpperCase()}', Neon.violet),
                  if (!o.inStock) _tag('OUT OF STOCK', Neon.error),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _cell(String label, String value, {Color? color}) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: NeonType.eyebrow.copyWith(color: Neon.textDim, fontSize: 9.5)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: NeonType.manrope(13.5, FontWeight.w800).copyWith(color: color ?? Neon.textHi)),
            ),
          ],
        ),
      );
}
