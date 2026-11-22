import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/neon_tokens.dart';
import '../../services/api_service.dart';
import '../../services/app_feedback.dart';
import '../../widgets/neon_cards.dart';

/// An order placed by voice (GET /orders/active): food, groceries,
/// medicines or a parcel.
class ActiveOrder {
  ActiveOrder.fromJson(Map<String, dynamic> j)
      : id = (j['id'] as num?)?.toInt() ?? 0,
        kind = '${j['kind'] ?? 'food'}',
        provider = '${j['providerLabel'] ?? j['provider'] ?? ''}',
        test = j['test'] == true,
        summary = '${j['summary'] ?? ''}',
        total = (j['total'] as num?)?.toDouble(),
        status = '${j['status'] ?? 'placed'}',
        partner = '${(j['partner'] as Map?)?['name'] ?? ''}',
        otp = '${j['otp'] ?? ''}',
        etaMin = (j['etaMin'] as num?)?.toInt();

  final int id;
  final String kind, provider, summary, status, partner, otp;
  final bool test;
  final double? total;
  final int? etaMin;

  IconData get icon => switch (kind) {
        'grocery' => Icons.local_grocery_store_rounded,
        'medicine' => Icons.medication_rounded,
        'parcel' => Icons.inventory_2_rounded,
        _ => Icons.restaurant_rounded,
      };

  String get statusLine => switch (status) {
        'placed' => 'Order placed',
        'confirmed' => 'Confirmed by $provider',
        'preparing' => kind == 'food' ? 'Being prepared' : 'Being packed',
        'picked_up' => 'Picked up',
        'out_for_delivery' =>
          etaMin != null ? 'Out for delivery · $etaMin min' : 'Out for delivery',
        _ => status,
      };

  bool get cancellable => const {'placed', 'confirmed', 'preparing'}.contains(status);
}

class OrderService {
  OrderService._();
  static final OrderService instance = OrderService._();

  final ValueNotifier<List<ActiveOrder>> orders = ValueNotifier(const []);
  Timer? _poll;

  Future<void> refresh() async {
    final j = await ApiService.getJson('/orders/active');
    final list = (j?['orders'] as List?) ?? const [];
    orders.value = [
      for (final o in list)
        if (o is Map) ActiveOrder.fromJson(o.cast<String, dynamic>()),
    ];
    _poll?.cancel();
    if (orders.value.isNotEmpty) _poll = Timer(const Duration(seconds: 30), refresh);
  }

  Future<String?> cancel(ActiveOrder o) async {
    final r = await ApiService.postJson('/orders/${o.id}/cancel', const {});
    await refresh();
    if (r == null) return 'Unable to cancel this order. It may already be on the way.';
    if (r['rejected'] == true) return '${r['error'] ?? 'This order can no longer be cancelled.'}';
    return null;
  }
}

/// YOUR ORDERS on Home (owner, 2026-11-21): each order in progress with
/// its status, the delivery partner and OTP, and Cancel while it can be.
class OrderStrip extends StatefulWidget {
  const OrderStrip({super.key});

  @override
  State<OrderStrip> createState() => _OrderStripState();
}

class _OrderStripState extends State<OrderStrip> {
  @override
  void initState() {
    super.initState();
    OrderService.instance.refresh();
  }

  Future<void> _cancel(ActiveOrder o) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Cancel This Order?'),
        content: Text(o.summary),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Cancel Order')),
        ],
      ),
    );
    if (yes != true) return;
    HapticFeedback.mediumImpact();
    final err = await OrderService.instance.cancel(o);
    AppFeedback.show(err ?? 'Your order has been cancelled.');
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<ActiveOrder>>(
      valueListenable: OrderService.instance.orders,
      builder: (context, list, _) {
        if (list.isEmpty) return const SizedBox.shrink();
        return Column(children: [
          for (final o in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassCard(
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Neon.violet.withValues(alpha: 0.16),
                      ),
                      child: Icon(o.icon, color: Neon.violet, size: 21),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${o.test ? 'Test Order · ' : ''}${o.summary}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: NeonType.manrope(14, FontWeight.w800).copyWith(color: Neon.textHi)),
                        Text(
                            [o.statusLine, if (o.partner.isNotEmpty) o.partner].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: NeonType.manrope(12.5, FontWeight.w600).copyWith(color: Neon.violet)),
                      ]),
                    ),
                    if (o.otp.isNotEmpty)
                      Semantics(
                        label: 'OTP ${o.otp.split('').join(' ')}',
                        child: Column(children: [
                          Text('OTP',
                              style: NeonType.manrope(10, FontWeight.w700).copyWith(color: Neon.textLo)),
                          Text(o.otp,
                              style: NeonType.manrope(18, FontWeight.w900)
                                  .copyWith(color: Neon.textHi, letterSpacing: 2)),
                        ]),
                      ),
                  ]),
                  if (o.cancellable)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => _cancel(o),
                        child: Text('Cancel Order',
                            style: TextStyle(color: Neon.error, fontWeight: FontWeight.w700)),
                      ),
                    ),
                ]),
              ),
            ),
        ]);
      },
    );
  }
}
