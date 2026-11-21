import '../models/clinic.dart';
import '../models/user_document.dart';
import 'api_service.dart';
import 'clinic_service.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  PRO SERVICE — the advocate's cases, hearings and drafts, and the
///  business owner's invoices, quotes and leads (backend /clinic/*, gated
///  per profession on the server). Shared pieces — clients, follow-ups,
///  dues, appointments, the Today numbers — stay in ClinicService.
///
///  Every call returns null on failure (no network, refused): screens say
///  so in plain words instead of crashing. Writes refresh Today so the
///  numbers on the assistant page and Home move at once.
/// ─────────────────────────────────────────────────────────────────────────
class ProService {
  ProService._();
  static final instance = ProService._();

  void _refreshToday() => ClinicService.instance.refresh(force: true);

  static const _t = Duration(seconds: 15);

  /* ---------------- cases & hearings (advocates) ---------------- */

  Future<List<LegalCase>?> cases({bool closed = false}) async {
    final j = await ApiService.getJson('/clinic/cases${closed ? '?status=closed' : ''}', timeout: _t);
    return j == null ? null : LegalCase.list(j['cases']);
  }

  Future<({LegalCase kase, List<Hearing> hearings})?> caseDetail(int id) async {
    final j = await ApiService.getJson('/clinic/cases/$id', timeout: _t);
    if (j == null || j['case'] is! Map) return null;
    return (
      kase: LegalCase.fromJson((j['case'] as Map).cast<String, dynamic>()),
      hearings: Hearing.list(j['hearings']),
    );
  }

  Future<LegalCase?> createCase({
    int? clientId,
    required String title,
    String caseNumber = '',
    String court = '',
    String oppositeParty = '',
    String stage = '',
  }) async {
    final r = await ApiService.sendJson('/clinic/cases', body: {
      if (clientId != null) 'clientId': clientId,
      'title': title,
      'caseNumber': caseNumber,
      'court': court,
      'oppositeParty': oppositeParty,
      'stage': stage,
    });
    if (r == null || r['case'] is! Map) return null;
    return LegalCase.fromJson((r['case'] as Map).cast<String, dynamic>());
  }

  Future<LegalCase?> updateCase(int id, Map<String, dynamic> patch) async {
    final r = await ApiService.sendJson('/clinic/cases/$id', method: 'PATCH', body: patch);
    if (r == null || r['case'] is! Map) return null;
    return LegalCase.fromJson((r['case'] as Map).cast<String, dynamic>());
  }

  /// Returns (hearing, noPhone) — noPhone: the client can't be called.
  Future<({Hearing hearing, bool noPhone})?> addHearing(int caseId,
      {required DateTime at, String purpose = '', bool remindClient = true}) async {
    final r = await ApiService.sendJson('/clinic/cases/$caseId/hearings', body: {
      'at': at.millisecondsSinceEpoch,
      'purpose': purpose,
      'remindClient': remindClient,
    });
    if (r == null || r['hearing'] is! Map) return null;
    _refreshToday();
    return (
      hearing: Hearing.fromJson((r['hearing'] as Map).cast<String, dynamic>()),
      noPhone: r['noPhone'] == true,
    );
  }

  Future<bool> updateHearing(int id, {String? status, String? outcome}) async {
    final r = await ApiService.sendJson('/clinic/hearings/$id', method: 'PATCH', body: {
      if (status != null) 'status': status,
      if (outcome != null) 'outcome': outcome,
    });
    if (r == null) return false;
    _refreshToday();
    return true;
  }

  /* ---------------- legal drafting (advocates) ---------------- */

  Future<LegalDraft?> draftLegal({
    required String kind,
    required String facts,
    int? clientId,
    int? caseId,
  }) async {
    final r = await ApiService.sendJson('/clinic/drafts/legal',
        body: {
          'kind': kind,
          'facts': facts,
          if (clientId != null) 'clientId': clientId,
          if (caseId != null) 'caseId': caseId,
        },
        timeout: const Duration(seconds: 150));
    if (r == null || r['body'] == null) return null;
    return LegalDraft.fromJson(r);
  }

  Future<UserDocument?> legalPdf({required String title, required String body, int? clientId}) async {
    final r = await ApiService.sendJson('/clinic/drafts/legal/pdf',
        body: {'title': title, 'body': body, if (clientId != null) 'clientId': clientId},
        timeout: const Duration(seconds: 40));
    if (r == null || r['document'] is! Map) return null;
    return UserDocument.fromJson((r['document'] as Map).cast<String, dynamic>());
  }

  /* ---------------- invoices & quotes ---------------- */

  Future<List<Invoice>?> invoices({String? kind}) async {
    final j = await ApiService.getJson('/clinic/invoices${kind != null ? '?kind=$kind' : ''}', timeout: _t);
    return j == null ? null : Invoice.list(j['invoices']);
  }

  /// Creates an invoice or quote (PDF filed under the client). paymentError
  /// explains why no online payment link could be attached, if so.
  Future<({Invoice invoice, UserDocument? document, String? paymentError})?> createInvoice({
    required int clientId,
    required String kind,
    required List<InvoiceLine> items,
    double gstRate = 0,
    String notes = '',
    DateTime? dueAt,
    bool paymentLink = true,
  }) async {
    final r = await ApiService.sendJson('/clinic/invoices',
        body: {
          'clientId': clientId,
          'kind': kind,
          'items': items.where((i) => i.description.trim().isNotEmpty && i.qty > 0).map((i) => i.toJson()).toList(),
          'gstRate': gstRate,
          'notes': notes,
          if (dueAt != null) 'dueAt': dueAt.millisecondsSinceEpoch,
          'paymentLink': paymentLink,
        },
        timeout: const Duration(seconds: 40));
    if (r == null || r['invoice'] is! Map) return null;
    _refreshToday();
    return (
      invoice: Invoice.fromJson((r['invoice'] as Map).cast<String, dynamic>()),
      document: r['document'] is Map
          ? UserDocument.fromJson((r['document'] as Map).cast<String, dynamic>())
          : null,
      paymentError: r['paymentError'] as String?,
    );
  }

  Future<bool> markInvoicePaid(int id) async {
    final r = await ApiService.sendJson('/clinic/invoices/$id/paid', body: const {});
    if (r == null) return false;
    _refreshToday();
    return true;
  }

  /* ---------------- leads & deals (business) ---------------- */

  Future<List<Lead>?> leads({bool all = false}) async {
    final j = await ApiService.getJson('/clinic/leads${all ? '?all=1' : ''}', timeout: _t);
    return j == null ? null : Lead.list(j['leads']);
  }

  Future<Lead?> createLead({
    required String name,
    String company = '',
    String phone = '',
    double value = 0,
    DateTime? nextFollowUp,
    String note = '',
  }) async {
    final r = await ApiService.sendJson('/clinic/leads', body: {
      'name': name,
      'company': company,
      'phone': phone,
      'value': value,
      if (nextFollowUp != null) 'nextFollowUp': nextFollowUp.millisecondsSinceEpoch,
      'note': note,
    });
    if (r == null || r['lead'] is! Map) return null;
    _refreshToday();
    return Lead.fromJson((r['lead'] as Map).cast<String, dynamic>());
  }

  Future<Lead?> updateLead(int id, Map<String, dynamic> patch) async {
    final r = await ApiService.sendJson('/clinic/leads/$id', method: 'PATCH', body: patch);
    if (r == null || r['lead'] is! Map) return null;
    _refreshToday();
    return Lead.fromJson((r['lead'] as Map).cast<String, dynamic>());
  }
}
