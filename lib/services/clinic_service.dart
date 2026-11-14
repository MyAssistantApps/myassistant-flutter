import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/clinic.dart';
import '../models/user_document.dart';
import 'api_service.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  CLINIC SERVICE — the doctor's day, shared by every clinic surface.
///
///  One /clinic/today call feeds the Home strip AND the Clinic screen, so
///  ticking off a follow-up in one updates the other without a refetch
///  storm. Last good snapshot is kept on failure: a doctor between rooms
///  with bad signal should see slightly stale numbers, not a blank card.
/// ─────────────────────────────────────────────────────────────────────────
class ClinicService extends ChangeNotifier {
  ClinicService._();
  static final instance = ClinicService._();

  ClinicToday? today;
  bool loading = false;
  bool failed = false;
  DateTime? _fetchedAt;

  Future<void> refresh({bool force = false}) async {
    if (loading) return;
    if (!force &&
        _fetchedAt != null &&
        DateTime.now().difference(_fetchedAt!) < const Duration(seconds: 30)) {
      return;
    }
    loading = true;
    notifyListeners();
    final j = await ApiService.getJson('/clinic/today',
        timeout: const Duration(seconds: 12));
    loading = false;
    if (j != null) {
      today = ClinicToday.fromJson(j);
      failed = false;
      _fetchedAt = DateTime.now();
    } else {
      failed = true;
    }
    notifyListeners();
  }

  /// Sign-out / persona change: nothing from the last account may linger.
  void clear() {
    today = null;
    profile = null;
    failed = false;
    _fetchedAt = null;
    notifyListeners();
  }

  Future<FollowUpBuckets?> followUps() async {
    final j = await ApiService.getJson('/clinic/followups',
        timeout: const Duration(seconds: 12));
    return j == null ? null : FollowUpBuckets.fromJson(j);
  }

  Future<({List<Due> dues, double total})?> dues() async {
    final j = await ApiService.getJson('/clinic/dues',
        timeout: const Duration(seconds: 12));
    if (j == null) return null;
    return (
      dues: Due.list(j['dues']),
      total: (j['total'] as num?)?.toDouble() ?? 0
    );
  }

  /// Returns null on failure; otherwise whether the patient has no number
  /// (so the "I'll call them" promise couldn't be kept — the UI says so).
  Future<({bool noPhone})?> scheduleFollowUp({
    required int clientId,
    required DateTime dueAt,
    String note = '',
    bool notifyPatient = true,
  }) async {
    final r = await ApiService.sendJson('/clinic/followups', body: {
      'clientId': clientId,
      'dueAt': dueAt.millisecondsSinceEpoch,
      'note': note,
      'notifyPatient': notifyPatient,
    });
    if (r == null) return null;
    refresh(force: true);
    return (noPhone: r['noPhone'] == true);
  }

  Future<bool> closeFollowUp(int id, {bool cancel = false}) async {
    final r = await ApiService.sendJson('/clinic/followups/$id/done',
        body: {'cancel': cancel});
    if (r == null) return false;
    refresh(force: true);
    return true;
  }

  /* ---------------- phase 2: profile & appointments ---------------- */

  ClinicProfile? profile;


  Future<ClinicProfile?> loadProfile() async {
    final j = await ApiService.getJson('/clinic/profile',
        timeout: const Duration(seconds: 12));
    if (j == null) return profile;
    profile = ClinicProfile.fromJson(
        (j['profile'] as Map?)?.cast<String, dynamic>() ?? const {});
    notifyListeners();
    return profile;
  }

  Future<bool> saveProfile(ClinicProfile p) async {
    final r = await ApiService.sendJson('/clinic/profile',
        method: 'PUT', body: p.toJson());
    if (r == null) return false;
    profile = ClinicProfile.fromJson(
        (r['profile'] as Map?)?.cast<String, dynamic>() ?? const {});
    notifyListeners();
    return true;
  }

  static String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<List<Appointment>?> appointmentsOn(DateTime day) async {
    final j = await ApiService.getJson('/clinic/appointments?date=${_ymd(day)}',
        timeout: const Duration(seconds: 12));
    return j == null ? null : Appointment.list(j['appointments']);
  }

  Future<List<DateTime>?> slotsOn(DateTime day) async {
    final j = await ApiService.getJson('/clinic/slots?date=${_ymd(day)}',
        timeout: const Duration(seconds: 12));
    if (j == null) return null;
    return ((j['slots'] as List?) ?? const [])
        .whereType<num>()
        .map((n) => DateTime.fromMillisecondsSinceEpoch(n.toInt()))
        .toList();
  }

  Future<Appointment?> book({
    int? clientId,
    String patientName = '',
    String patientPhone = '',
    required DateTime startsAt,
    String reason = '',
    bool remindPatient = true,
  }) async {
    final r = await ApiService.sendJson('/clinic/appointments', body: {
      if (clientId != null) 'clientId': clientId,
      'patientName': patientName,
      'patientPhone': patientPhone,
      'startsAt': startsAt.millisecondsSinceEpoch,
      'reason': reason,
      'remindPatient': remindPatient,
    });
    if (r == null) return null;
    refresh(force: true);
    return Appointment.fromJson(
        (r['appointment'] as Map).cast<String, dynamic>());
  }

  Future<bool> setAppointmentStatus(int id, String status) async {
    final r = await ApiService.sendJson('/clinic/appointments/$id',
        method: 'PATCH', body: {'status': status});
    if (r == null) return false;
    refresh(force: true);
    return true;
  }

  /// Number of patients being called, or null when the server couldn't
  /// (offline, or calling not configured on the server).
  Future<int?> runningLate(int minutes) async {
    final r = await ApiService.sendJson('/clinic/appointments/delay',
        body: {'minutes': minutes}, timeout: const Duration(seconds: 60));
    if (r == null) return null;
    return (r['called'] as num?)?.toInt() ?? 0;
  }

  /* ---------------- phase 2: consult notes & prescriptions ---------------- */

  /// Uploads one recorded audio file; returns its transcript or null.
  Future<String?> transcribeConsult(String filePath) async {
    try {
      final req = http.MultipartRequest(
          'POST', Uri.parse('${ApiService.baseUrl}/clinic/consult/transcribe'));
      final h = Map<String, String>.from(ApiService.authHeaders)
        ..remove('Content-Type');
      req.headers.addAll(h);
      req.fields['consent'] = 'true';
      req.files.add(await http.MultipartFile.fromPath('audio', filePath));
      final streamed = await req.send().timeout(const Duration(seconds: 120));
      final r = await http.Response.fromStream(streamed);
      if (r.statusCode != 200) return null;
      return ((jsonDecode(r.body) as Map)['text'] as String?)?.trim();
    } catch (_) {
      return null;
    } finally {
      try {
        File(filePath).deleteSync();
      } catch (_) {}
    }
  }

  /// Draft SOAP note from a transcript. Returns (note, provider) or null.
  Future<({SoapNote note, String provider})?> draftConsult(
      {required int clientId, required String transcript}) async {
    final r = await ApiService.sendJson('/clinic/consult/draft',
        body: {'clientId': clientId, 'transcript': transcript},
        timeout: const Duration(seconds: 150));
    if (r == null || r['note'] is! Map) return null;
    return (
      note: SoapNote.fromJson((r['note'] as Map).cast<String, dynamic>()),
      provider: (r['provider'] ?? '').toString(),
    );
  }

  Future<bool> saveConsult({required int clientId, required String text}) async {
    final r = await ApiService.sendJson('/clinic/consult/save',
        body: {'clientId': clientId, 'text': text});
    return r != null;
  }

  Future<({String diagnosis, List<RxItem> meds, String advice, int? followUpDays})?>
      parseRx(String text) async {
    final r = await ApiService.sendJson('/clinic/rx/parse',
        body: {'text': text}, timeout: const Duration(seconds: 120));
    if (r == null) return null;
    return (
      diagnosis: (r['diagnosis'] ?? '').toString(),
      meds: RxItem.list(r['medications']),
      advice: (r['advice'] ?? '').toString(),
      followUpDays: (r['followUpDays'] as num?)?.toInt(),
    );
  }

  /// Creates the prescription PDF, filed in the patient's record.
  Future<UserDocument?> createRx({
    required int clientId,
    required List<RxItem> meds,
    String diagnosis = '',
    String advice = '',
    int? followUpDays,
    String age = '',
    String sex = '',
  }) async {
    final r = await ApiService.sendJson('/clinic/rx',
        body: {
          'clientId': clientId,
          'medications': meds.map((m) => m.toJson()).toList(),
          'diagnosis': diagnosis,
          'advice': advice,
          if (followUpDays != null) 'followUpDays': followUpDays,
          'age': age,
          'sex': sex,
        },
        timeout: const Duration(seconds: 40));
    if (r == null || r['document'] is! Map) return null;
    return UserDocument.fromJson((r['document'] as Map).cast<String, dynamic>());
  }

  /// kind: 'due' (patient owes more) or 'paid'. Returns the new balance.
  Future<double?> addLedger({
    required int clientId,
    required double amount,
    required String kind,
    String note = '',
  }) async {
    final r = await ApiService.sendJson('/clinic/ledger', body: {
      'clientId': clientId,
      'amount': amount,
      'kind': kind,
      'note': note,
    });
    if (r == null) return null;
    refresh(force: true);
    return (r['balance'] as num?)?.toDouble();
  }
}
