import 'package:flutter/foundation.dart';

import '../../services/api_service.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  CASHBACK (owner, 2026-11-27: "the commission which we earn, we want to
///  give that back to the user as a cashback").
///
///  The server keeps the ledger (backend src/cashback/): a purchase made
///  after opening a partner from the app is reported by the affiliate
///  network, shows here as PENDING, becomes AVAILABLE when the store
///  validates it, and is paid to the user's UPI ID when they ask.
///
///  The phone only reads and asks: GET /cashback, POST /cashback/payouts.
///  When the server says `enabled: false` nothing about cashback is shown
///  anywhere in the app.
///
///  Money is in paise, as whole numbers, exactly as the server sends it.
/// ─────────────────────────────────────────────────────────────────────────

enum CashbackStatus { pending, confirmed, rejected }

class CashbackTxn {
  const CashbackTxn({
    required this.id,
    required this.store,
    required this.cashbackPaise,
    required this.salePaise,
    required this.status,
    required this.occurredAt,
  });

  final int id;
  final String store;
  final int cashbackPaise;
  final int salePaise;
  final CashbackStatus status;
  final DateTime? occurredAt;

  static CashbackTxn? fromJson(Object? v) {
    if (v is! Map) return null;
    final id = _int(v['id']);
    final cashback = _int(v['cashbackPaise']);
    if (id == null || cashback == null) return null;
    final at = _int(v['occurredAt']) ?? 0;
    return CashbackTxn(
      id: id,
      store: '${v['store'] ?? ''}'.trim().isEmpty ? 'Store' : '${v['store']}'.trim(),
      cashbackPaise: cashback,
      salePaise: _int(v['salePaise']) ?? 0,
      status: switch ('${v['status']}') {
        'confirmed' => CashbackStatus.confirmed,
        'rejected' => CashbackStatus.rejected,
        _ => CashbackStatus.pending,
      },
      occurredAt: at > 0 ? DateTime.fromMillisecondsSinceEpoch(at) : null,
    );
  }
}

class CashbackPayout {
  const CashbackPayout({
    required this.amountPaise,
    required this.upiId,
    required this.status,
    required this.note,
    required this.requestedAt,
  });

  final int amountPaise;

  /// Already masked by the server ("ra••••@okaxis").
  final String upiId;

  /// requested | paid | rejected
  final String status;
  final String note;
  final DateTime? requestedAt;

  static CashbackPayout? fromJson(Object? v) {
    if (v is! Map) return null;
    final amount = _int(v['amountPaise']);
    if (amount == null) return null;
    final at = _int(v['requestedAt']) ?? 0;
    return CashbackPayout(
      amountPaise: amount,
      upiId: '${v['upiId'] ?? ''}',
      status: '${v['status'] ?? 'requested'}',
      note: '${v['note'] ?? ''}',
      requestedAt: at > 0 ? DateTime.fromMillisecondsSinceEpoch(at) : null,
    );
  }
}

class CashbackStore {
  const CashbackStore({required this.id, required this.name, required this.category, required this.rateText});
  final String id;
  final String name;
  final String category;

  /// "Up to 6%" when the owner set one; empty otherwise.
  final String rateText;

  static CashbackStore? fromJson(Object? v) {
    if (v is! Map || v['id'] == null) return null;
    return CashbackStore(
      id: '${v['id']}',
      name: '${v['name'] ?? v['id']}',
      category: '${v['category'] ?? ''}',
      rateText: '${v['rateText'] ?? ''}'.trim(),
    );
  }
}

class CashbackSummary {
  const CashbackSummary({
    required this.enabled,
    this.pendingPaise = 0,
    this.availablePaise = 0,
    this.paidPaise = 0,
    this.heldPaise = 0,
    this.minPayoutPaise = 0,
    this.canWithdraw = false,
    this.txns = const [],
    this.payouts = const [],
    this.stores = const [],
  });

  /// The server has cashback switched off: show nothing.
  static const off = CashbackSummary(enabled: false);

  final bool enabled;
  final int pendingPaise;
  final int availablePaise;
  final int paidPaise;

  /// Asked for and not yet paid.
  final int heldPaise;
  final int minPayoutPaise;
  final bool canWithdraw;
  final List<CashbackTxn> txns;
  final List<CashbackPayout> payouts;
  final List<CashbackStore> stores;

  static CashbackSummary fromJson(Map<String, dynamic> j) {
    if (j['enabled'] != true) return off;
    final b = j['balance'] is Map ? j['balance'] as Map : const {};
    List<T> list<T>(Object? v, T? Function(Object?) parse) =>
        [for (final x in (v is List ? v : const [])) parse(x)].whereType<T>().toList();
    return CashbackSummary(
      enabled: true,
      pendingPaise: _int(b['pendingPaise']) ?? 0,
      availablePaise: _int(b['availablePaise']) ?? 0,
      paidPaise: _int(b['paidPaise']) ?? 0,
      heldPaise: _int(b['heldPaise']) ?? 0,
      minPayoutPaise: _int(j['minPayoutPaise']) ?? 0,
      canWithdraw: j['canWithdraw'] == true,
      txns: list(j['txns'], CashbackTxn.fromJson),
      payouts: list(j['payouts'], CashbackPayout.fromJson),
      stores: list(j['stores'], CashbackStore.fromJson),
    );
  }
}

int? _int(Object? v) => v is int ? v : (v is num ? v.round() : int.tryParse('${v ?? ''}'));

class CashbackService {
  CashbackService();
  static final CashbackService instance = CashbackService();

  /// Test seams: the two requests.
  @visibleForTesting
  Future<Map<String, dynamic>?> Function(String path) getJson = ApiService.getJson;
  @visibleForTesting
  Future<Map<String, dynamic>?> Function(String path, Object body) send =
      (path, body) => ApiService.sendJson(path, body: body);

  /// The last summary read, for the banner on Everyday Services.
  final ValueNotifier<CashbackSummary?> summary = ValueNotifier(null);

  /// The user's cashback, or null when it could not be read.
  Future<CashbackSummary?> load() async {
    final j = await getJson('/cashback');
    if (j == null) return null;
    final s = CashbackSummary.fromJson(j);
    summary.value = s;
    return s;
  }

  /// Asks for the available balance to be paid to [upiId]. Null when the
  /// request was taken; otherwise the sentence to show.
  Future<String?> withdraw(String upiId) async {
    final upi = upiId.trim();
    if (!validUpi(upi)) return 'Please enter a valid UPI ID, for example name@bank.';
    final j = await send('/cashback/payouts', {'upiId': upi});
    if (j == null) return 'Unable to request the withdrawal. Please check your connection and try again.';
    if (j['rejected'] == true || j['payout'] == null) {
      final said = '${j['error'] ?? ''}'.trim();
      return said.isEmpty ? 'The withdrawal could not be requested. Please try again.' : said;
    }
    return null;
  }

  /// Nothing of this account stays for the next one on the phone.
  void reset() => summary.value = null;

  static final _upi = RegExp(r'^[a-zA-Z0-9._-]{2,256}@[a-zA-Z][a-zA-Z0-9]{1,64}$');

  /// The same shape the server accepts.
  static bool validUpi(String s) => _upi.hasMatch(s.trim());

  /// ₹1,23,456.50 — rupees the Indian way, paise only when there are any.
  static String inr(int paise) {
    final negative = paise < 0;
    final abs = paise.abs();
    final rupees = abs ~/ 100;
    final rest = abs % 100;
    var digits = '$rupees';
    var out = '';
    if (digits.length > 3) {
      out = ',${digits.substring(digits.length - 3)}';
      digits = digits.substring(0, digits.length - 3);
      while (digits.length > 2) {
        out = ',${digits.substring(digits.length - 2)}$out';
        digits = digits.substring(0, digits.length - 2);
      }
    }
    final whole = '$digits$out';
    final frac = rest == 0 ? '' : '.${rest.toString().padLeft(2, '0')}';
    return '${negative ? '-' : ''}₹$whole$frac';
  }
}
