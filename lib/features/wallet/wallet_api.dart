import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:play_install_referrer/play_install_referrer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/log.dart';
import '../../services/api_service.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  THE WALLET, AS THE APP SEES IT (2026-11-22, wallet plan Phases 1–3).
///
///  The server is the only source of truth: this file never adds or
///  subtracts a balance — after anything that moves money it reads
///  GET /wallet again. Amounts are integer paise, as the server sends them.
///  Every write carries its own Idempotency-Key (one per tap), so a retry
///  after a dropped connection never pays or tops up twice.
/// ─────────────────────────────────────────────────────────────────────────

/// "₹1,250" / "₹10.50" from paise, Indian digit grouping.
String rupees(int paise) {
  final neg = paise < 0;
  final p = paise.abs();
  final whole = p ~/ 100;
  final frac = p % 100;
  final s = whole.toString();
  String grouped;
  if (s.length <= 3) {
    grouped = s;
  } else {
    final last3 = s.substring(s.length - 3);
    var rest = s.substring(0, s.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    grouped = '${parts.join(',')},$last3';
  }
  final f = frac == 0 ? '' : '.${frac.toString().padLeft(2, '0')}';
  return '${neg ? '-' : ''}₹$grouped$f';
}

/// Rupees typed by the user → paise, or null when it is not an amount.
int? paiseFromText(String text) {
  final t = text.replaceAll(',', '').replaceAll('₹', '').trim();
  if (!RegExp(r'^\d{1,7}(\.\d{1,2})?$').hasMatch(t)) return null;
  final parts = t.split('.');
  final whole = int.parse(parts[0]);
  final frac = parts.length > 1 ? int.parse(parts[1].padRight(2, '0')) : 0;
  return whole * 100 + frac;
}

class WalletSummary {
  const WalletSummary({
    required this.available,
    this.cash = 0,
    this.bonus = 0,
    this.status = 'active',
    this.minTopup = 1000,
    this.maxTopup = 1000000,
    this.dailyLeft = 0,
    this.capLeft = 0,
    this.paymentsReady = false,
    this.hasPin = false,
    this.stepUpAbove = 200000,
  });

  final bool available;
  final int cash;
  final int bonus;
  final String status;
  final int minTopup;
  final int maxTopup;
  final int dailyLeft;
  final int capLeft;
  final bool paymentsReady;
  final bool hasPin;
  final int stepUpAbove;

  int get total => cash + bonus;
  bool get frozen => status != 'active';

  /// The most that can be added right now.
  int get canAdd => [maxTopup, dailyLeft, capLeft].reduce(min);

  static int _i(Object? v) => v is num ? v.toInt() : 0;

  factory WalletSummary.fromJson(Map<String, dynamic> j) {
    final l = (j['limits'] as Map?)?.cast<String, dynamic>() ?? const {};
    return WalletSummary(
      available: j['available'] == true,
      cash: _i(j['cash_paise']),
      bonus: _i(j['bonus_paise']),
      status: (j['status'] as String?) ?? 'active',
      minTopup: _i(l['min_topup_paise']),
      maxTopup: _i(l['max_topup_paise']),
      dailyLeft: _i(l['daily_left_paise']),
      capLeft: _i(l['cap_left_paise']),
      paymentsReady: j['payments_ready'] == true,
      hasPin: j['has_pin'] == true,
      stepUpAbove: _i(j['step_up_above_paise']) == 0 ? 200000 : _i(j['step_up_above_paise']),
    );
  }
}

class WalletTxn {
  const WalletTxn({
    required this.id,
    required this.type,
    required this.title,
    required this.amount,
    required this.incoming,
    required this.status,
    required this.at,
  });

  final String id;
  final String type;
  final String title;
  final int amount;
  final bool incoming;
  final String status;
  final DateTime at;

  factory WalletTxn.fromJson(Map<String, dynamic> j) => WalletTxn(
        id: '${j['id']}',
        type: '${j['type'] ?? ''}',
        title: (j['title'] as String?)?.trim().isNotEmpty == true ? j['title'] as String : '${j['type']}',
        amount: (j['amount_paise'] as num?)?.toInt() ?? 0,
        incoming: j['direction'] == 'in',
        status: '${j['status'] ?? 'posted'}',
        at: DateTime.fromMillisecondsSinceEpoch((j['created_at'] as num?)?.toInt() ?? 0),
      );
}

class WalletApi {
  WalletApi._();
  static final WalletApi instance = WalletApi._();

  /// The last wallet read (null = not read yet). Screens listen to it.
  final ValueNotifier<WalletSummary?> summary = ValueNotifier(null);

  /// A fresh idempotency key: one per user action, 32 random hex chars.
  static String newKey() {
    final r = Random.secure();
    return List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  Future<WalletSummary?> refresh() async {
    final r = await ApiService.request('GET', '/wallet', timeout: const Duration(seconds: 10));
    if (!r.ok) return summary.value;
    final s = WalletSummary.fromJson(r.body);
    summary.value = s;
    return s;
  }

  Future<ApiResult> createTopup(int paise, String key) => ApiService.request(
      'POST', '/wallet/topups', body: {'amount_paise': paise}, headers: {'Idempotency-Key': key});

  Future<ApiResult> verifyTopup(String topupId, {required String paymentId, required String orderId, required String signature}) =>
      ApiService.request('POST', '/wallet/topups/$topupId/verify', body: {
        'razorpay_payment_id': paymentId,
        'razorpay_order_id': orderId,
        'razorpay_signature': signature,
      });

  Future<ApiResult> topupStatus(String topupId) => ApiService.request('GET', '/wallet/topups/$topupId');

  Future<(List<WalletTxn>, String?)> transactions({String? cursor, int limit = 20}) async {
    final q = cursor == null ? '' : '&cursor=${Uri.encodeQueryComponent(cursor)}';
    final r = await ApiService.request('GET', '/wallet/transactions?limit=$limit$q');
    if (!r.ok) return (const <WalletTxn>[], null);
    final items = (r.body['items'] as List? ?? const [])
        .whereType<Map>()
        .map((m) => WalletTxn.fromJson(m.cast<String, dynamic>()))
        .toList();
    return (items, r.body['next_cursor'] as String?);
  }

  Future<ApiResult> setPin(String pin, {String? current}) =>
      ApiService.request('POST', '/wallet/pin', body: {'pin': pin, if (current != null) 'current_pin': current});

  /// Trades the PIN for a 5-minute step-up token.
  Future<ApiResult> stepUp(String pin) => ApiService.request('POST', '/wallet/step-up', body: {'pin': pin});

  Future<int> refundable() async {
    final r = await ApiService.request('GET', '/wallet/refundable');
    return (r.body['refundable_paise'] as num?)?.toInt() ?? 0;
  }

  Future<ApiResult> requestRefund(int paise, {required String key, required String stepUpToken}) => ApiService.request(
      'POST', '/wallet/refunds',
      body: {'amount_paise': paise}, headers: {'Idempotency-Key': key, 'X-Wallet-Step-Up': stepUpToken});

  Future<ApiResult> refunds() => ApiService.request('GET', '/wallet/refunds');

  /// Pays for one thing the server knows the price of.
  Future<ApiResult> spend(String type, String id, {String? stepUpToken}) => ApiService.request(
      'POST', '/wallet/spend',
      body: {'reference_type': type, 'reference_id': id},
      headers: {if (stepUpToken != null) 'X-Wallet-Step-Up': stepUpToken});

  /* ---------------- referrals ---------------- */

  Future<ApiResult> referralMe() => ApiService.request('GET', '/referrals/me');
  Future<ApiResult> referralHistory() => ApiService.request('GET', '/referrals/history');

  Future<ApiResult> applyCode(String code) async => ApiService.request(
      'POST', '/referrals/apply', body: {'code': code}, headers: {'X-Device-Id': await deviceId()});

  static const _deviceKey = 'wallet_install_id';
  static const _referrerDoneKey = 'wallet_install_referrer_done';

  /// A random id for THIS install, sent (hashed on the server) only when a
  /// referral code is applied, so one phone cannot be referred twice.
  Future<String> deviceId() async {
    final p = await SharedPreferences.getInstance();
    var id = p.getString(_deviceKey);
    if (id == null || id.length < 16) {
      id = 'inst-${newKey()}';
      await p.setString(_deviceKey, id);
    }
    return id;
  }

  /// Once per install, after sign-in: a code that came with the Play Store
  /// install (someone's share link) is applied quietly. Nothing happens
  /// when there is no code, the wallet is off, or it was tried before.
  Future<void> tryInstallReferrer() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final p = await SharedPreferences.getInstance();
    if (p.getBool(_referrerDoneKey) == true) return;
    try {
      final s = await refresh();
      if (s == null || !s.available) return; // try again on a later launch
      final details = await PlayInstallReferrer.installReferrer;
      final raw = details.installReferrer ?? '';
      final code = Uri.splitQueryString(raw)['code'];
      await p.setBool(_referrerDoneKey, true);
      if (code == null || code.isEmpty) return;
      final r = await applyCode(code);
      AppLog.add('wallet', 'install referrer code ${r.ok ? 'applied' : 'not applied (${r.error})'}');
    } catch (e) {
      AppLog.add('wallet', 'install referrer unavailable: $e');
      await p.setBool(_referrerDoneKey, true);
    }
  }
}
