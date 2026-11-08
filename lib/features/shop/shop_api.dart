import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../services/api_service.dart';
import '../../services/location_service.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  IN-APP SHOPPING OVER ONDC (2026-11-04) — the app's side of /shop.
///  Groceries and Food are the same flow on different ONDC domains:
///  search → stores & items → cart → quote → address → pay → order.
/// ─────────────────────────────────────────────────────────────────────────
enum ShopDomain { grocery, food }

class ShopError implements Exception {
  ShopError(this.message);
  final String message;
  @override
  String toString() => message;
}

class ShopItem {
  ShopItem.fromJson(Map<String, dynamic> j)
      : id = '${j['id']}',
        name = '${j['name'] ?? ''}',
        description = '${j['description'] ?? ''}',
        image = j['image'] as String?,
        price = (j['price'] as num?)?.toDouble() ?? 0,
        mrp = (j['mrp'] as num?)?.toDouble(),
        unit = '${j['unit'] ?? ''}',
        available = (j['available'] as num?)?.toInt();
  final String id;
  final String name;
  final String description;
  final String? image;
  final double price;
  final double? mrp;
  final String unit;
  final int? available;
  bool get outOfStock => available != null && available! <= 0;
}

class ShopStore {
  ShopStore.fromJson(Map<String, dynamic> j)
      : bppId = '${j['bppId']}',
        bppUri = '${j['bppUri']}',
        sellerApp = j['sellerApp'] as String?,
        providerId = '${j['providerId']}',
        name = '${j['name'] ?? 'Store'}',
        image = j['image'] as String?,
        locality = '${j['locality'] ?? ''}',
        locationId = j['locationId'] as String?,
        items = ((j['items'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => ShopItem.fromJson(m.cast<String, dynamic>()))
            .toList();
  final String bppId;
  final String bppUri;
  final String? sellerApp;
  final String providerId;
  final String name;
  final String? image;
  final String locality;
  final String? locationId;
  final List<ShopItem> items;
  String get key => '$bppId|$providerId';
}

class ShopQuote {
  ShopQuote.fromJson(Map<String, dynamic> j)
      : total = (j['total'] as num?)?.toDouble(),
        error = j['error'] as String?,
        lines = ((j['breakup'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => (
                  title: '${m['title'] ?? ''}',
                  type: m['type'] as String?,
                  quantity: (m['quantity'] as num?)?.toInt(),
                  price: (m['price'] as num?)?.toDouble() ?? 0,
                ))
            .toList(),
        fulfillmentId = ((j['fulfillments'] as List?) ?? const [])
            .whereType<Map>()
            .map((f) => '${f['id']}')
            .firstOrNull,
        deliveryTime = ((j['fulfillments'] as List?) ?? const [])
            .whereType<Map>()
            .map((f) => f['tat'] as String?)
            .whereType<String>()
            .firstOrNull,
        serviceable = ((j['fulfillments'] as List?) ?? const [])
            .whereType<Map>()
            .every((f) => f['serviceable'] != false);
  final double? total;
  final String? error;
  final List<({String title, String? type, int? quantity, double price})> lines;
  final String? fulfillmentId;
  final String? deliveryTime;
  final bool serviceable;
}

class ShopOrder {
  ShopOrder.fromJson(Map<String, dynamic> j)
      : id = (j['id'] as num).toInt(),
        domain = '${j['domain'] ?? ''}',
        store = '${j['store'] ?? 'Store'}',
        state = '${j['state'] ?? ''}',
        fulfillmentState = j['fulfillmentState'] as String?,
        total = (j['total'] as num?)?.toDouble(),
        paid = j['paid'] == true,
        paymentUrl = j['paymentUrl'] as String?,
        trackingUrl = j['trackingUrl'] as String?,
        agentName = (j['agent'] as Map?)?['name'] as String?,
        agentPhone = (j['agent'] as Map?)?['phone'] as String?,
        createdAt = DateTime.fromMillisecondsSinceEpoch(
            (j['createdAt'] as num?)?.toInt() ?? 0),
        items = ((j['items'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => (
                  name: '${m['name'] ?? ''}',
                  quantity: (m['quantity'] as num?)?.toInt() ?? 1,
                  price: (m['price'] as num?)?.toDouble() ?? 0,
                ))
            .toList();
  final int id;
  final String domain;
  final String store;
  final String state;
  final String? fulfillmentState;
  final double? total;
  final bool paid;
  final String? paymentUrl;
  final String? trackingUrl;
  final String? agentName;
  final String? agentPhone;
  final DateTime createdAt;
  final List<({String name, int quantity, double price})> items;

  /// What the user reads.
  String get label {
    final f = (fulfillmentState ?? '').toLowerCase();
    if (f.contains('deliver') && !f.contains('out')) return 'Delivered';
    if (f.contains('out-for-delivery') || f.contains('out for')) {
      return 'Out for delivery';
    }
    if (f.contains('picked')) return 'Picked up';
    if (f.contains('packed')) return 'Packed';
    return switch (state.toLowerCase()) {
      'awaiting_payment' => 'Waiting for payment',
      'paid' => 'Paid — placing order',
      'placed' || 'created' => 'Order placed',
      'accepted' => 'Accepted by store',
      'in-progress' => 'Being prepared',
      'completed' => 'Delivered',
      'cancelled' => 'Cancelled',
      'cancelling' => 'Cancelling',
      _ => state.isEmpty ? 'Processing' : state,
    };
  }
}

class ShopCartLine {
  ShopCartLine(this.item, this.quantity);
  final ShopItem item;
  int quantity;
}

/// One cart: items from ONE store (an ONDC order is one provider).
class ShopCart {
  ShopStore? store;
  final Map<String, ShopCartLine> lines = {};

  int get count => lines.values.fold(0, (a, l) => a + l.quantity);
  double get total =>
      lines.values.fold(0, (a, l) => a + l.item.price * l.quantity);
  bool get isEmpty => lines.isEmpty;

  /// Adding from another store starts a new cart (the caller asks first).
  void add(ShopStore s, ShopItem i) {
    if (store != null && store!.key != s.key) lines.clear();
    store = s;
    lines.update(i.id, (l) => l..quantity += 1,
        ifAbsent: () => ShopCartLine(i, 1));
  }

  void remove(ShopItem i) {
    final l = lines[i.id];
    if (l == null) return;
    l.quantity -= 1;
    if (l.quantity <= 0) lines.remove(i.id);
    if (lines.isEmpty) store = null;
  }

  int qty(ShopItem i) => lines[i.id]?.quantity ?? 0;
  void clear() {
    lines.clear();
    store = null;
  }
}

abstract final class ShopApi {
  static final http.Client _c = http.Client();

  static Future<Map<String, dynamic>> _call(String method, String path,
      [Object? body]) async {
    final uri = Uri.parse('${ApiService.baseUrl}/shop$path');
    final h = {...ApiService.authHeaders, 'Content-Type': 'application/json'};
    final r = await (method == 'GET'
            ? _c.get(uri, headers: h)
            : _c.post(uri, headers: h, body: jsonEncode(body ?? const {})))
        .timeout(const Duration(seconds: 20));
    Map<String, dynamic> j = const {};
    try {
      final d = jsonDecode(r.body);
      if (d is Map<String, dynamic>) j = d;
    } catch (_) {}
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw ShopError((j['error'] ?? 'Something went wrong (${r.statusCode})')
          .toString());
    }
    return j;
  }

  static Future<({bool configured, bool payments})> status() async {
    try {
      final j = await _call('GET', '/status');
      return (
        configured: j['configured'] == true,
        payments: j['payments'] == true
      );
    } catch (_) {
      return (configured: false, payments: false);
    }
  }

  static Future<(double, double)?> _where() async {
    try {
      await LocationService.instance.refresh();
    } catch (_) {}
    final lat = ApiService.geoLat, lng = ApiService.geoLng;
    return lat == null || lng == null ? null : (lat, lng);
  }

  static Future<String> search(ShopDomain d, String q) async {
    final at = await _where();
    if (at == null) {
      throw ShopError('Turn on location so we can find stores near you.');
    }
    final j = await _call('POST', '/search',
        {'domain': d.name, 'q': q, 'lat': at.$1, 'lng': at.$2});
    return '${j['transactionId']}';
  }

  static Future<List<ShopStore>> results(String txn) async {
    final j = await _call('GET', '/search/$txn');
    return ((j['stores'] as List?) ?? const [])
        .whereType<Map>()
        .map((m) => ShopStore.fromJson(m.cast<String, dynamic>()))
        .toList();
  }

  static Map<String, dynamic> _cartBody(
          ShopDomain d, String txn, ShopCart cart) =>
      {
        'domain': d.name,
        'transactionId': txn,
        'bppId': cart.store!.bppId,
        'bppUri': cart.store!.bppUri,
        'providerId': cart.store!.providerId,
        'providerName': cart.store!.name,
        'locationId': cart.store!.locationId,
        'items': [
          for (final l in cart.lines.values)
            {'id': l.item.id, 'quantity': l.quantity}
        ],
        'lat': ApiService.geoLat,
        'lng': ApiService.geoLng,
      };

  static Future<void> select(ShopDomain d, String txn, ShopCart cart) =>
      _call('POST', '/select', _cartBody(d, txn, cart));

  static Future<ShopQuote?> quote(String txn) async {
    final j = await _call('GET', '/quote/$txn');
    final q = j['quote'];
    return q is Map ? ShopQuote.fromJson(q.cast<String, dynamic>()) : null;
  }

  static Future<void> init(ShopDomain d, String txn, ShopCart cart,
          Map<String, dynamic> address, String? fulfillmentId) =>
      _call('POST', '/init', {
        ..._cartBody(d, txn, cart),
        'fulfillmentId': fulfillmentId,
        'billing': {
          'name': address['name'],
          'phone': address['phone'],
          'address': address,
        },
        'delivery': {
          ...address,
          'lat': ApiService.geoLat,
          'lng': ApiService.geoLng,
        },
      });

  /// The store's answer to init: its final total, or its reason.
  static Future<({double? total, String? error})?> initResult(
      String txn) async {
    final j = await _call('GET', '/init/$txn');
    final o = j['order'];
    if (o == null && j['error'] == null) return null;
    final total =
        o is Map ? double.tryParse('${(o['quote'] as Map?)?['price']?['value']}') : null;
    return (total: total, error: j['error'] as String?);
  }

  static Future<({int orderId, String url, double amount})> pay(
      String txn) async {
    final j = await _call('POST', '/pay', {'transactionId': txn});
    return (
      orderId: (j['orderId'] as num).toInt(),
      url: '${j['url']}',
      amount: (j['amount'] as num).toDouble()
    );
  }

  /// Placed once the payment is confirmed by the gateway itself.
  static Future<({String state, bool paid})> confirm(int orderId) async {
    final j = await _call('POST', '/confirm', {'orderId': orderId});
    return (state: '${j['state']}', paid: j['paid'] == true);
  }

  static Future<List<ShopOrder>> orders() async {
    final j = await _call('GET', '/orders');
    return ((j['orders'] as List?) ?? const [])
        .whereType<Map>()
        .map((m) => ShopOrder.fromJson(m.cast<String, dynamic>()))
        .toList();
  }

  static Future<ShopOrder> order(int id, {bool refresh = false}) async {
    final j = refresh
        ? await _call('POST', '/orders/$id/refresh')
        : await _call('GET', '/orders/$id');
    return ShopOrder.fromJson((j['order'] as Map).cast<String, dynamic>());
  }

  static Future<void> cancel(int id) => _call('POST', '/orders/$id/cancel');

  /// Ask again every [every] until [done] or [within] runs out.
  static Future<T?> poll<T>(Future<T?> Function() ask,
      {bool Function(T v)? done,
      Duration every = const Duration(milliseconds: 1500),
      Duration within = const Duration(seconds: 20)}) async {
    final end = DateTime.now().add(within);
    T? last;
    while (DateTime.now().isBefore(end)) {
      last = await ask();
      if (last != null && (done == null || done(last))) return last;
      await Future<void>.delayed(every);
    }
    return last;
  }
}

String rupees(num v) {
  final n = v.round();
  final s = n.abs().toString();
  final last3 = s.length > 3 ? s.substring(s.length - 3) : s;
  var rest = s.length > 3 ? s.substring(0, s.length - 3) : '';
  final parts = <String>[];
  while (rest.length > 2) {
    parts.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  return '₹${[...parts, last3].join(',')}';
}
