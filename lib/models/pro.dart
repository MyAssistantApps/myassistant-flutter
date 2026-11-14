// Advocate & business workspace models — shapes of /clinic/cases, /hearings,
// /invoices, /leads, /drafts (backend src/clinic/routes.js + src/pro).

int? _ms(dynamic v) => (v as num?)?.toInt();

DateTime? _dt(dynamic v) {
  final ms = _ms(v);
  return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
}

class LegalCase {
  final int id;
  final int? clientId;
  final String clientName;
  final String clientPhone;
  final String title;
  final String caseNumber;
  final String court;
  final String oppositeParty;
  final String stage;
  final String status;
  final String notes;
  final DateTime? nextHearingAt;
  final String nextHearingPurpose;

  const LegalCase({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.clientPhone,
    required this.title,
    required this.caseNumber,
    required this.court,
    required this.oppositeParty,
    required this.stage,
    required this.status,
    required this.notes,
    required this.nextHearingAt,
    required this.nextHearingPurpose,
  });

  factory LegalCase.fromJson(Map<String, dynamic> j) => LegalCase(
        id: _ms(j['id']) ?? 0,
        clientId: _ms(j['clientId']),
        clientName: (j['clientName'] ?? '').toString(),
        clientPhone: (j['clientPhone'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        caseNumber: (j['caseNumber'] ?? '').toString(),
        court: (j['court'] ?? '').toString(),
        oppositeParty: (j['oppositeParty'] ?? '').toString(),
        stage: (j['stage'] ?? '').toString(),
        status: (j['status'] ?? 'open').toString(),
        notes: (j['notes'] ?? '').toString(),
        nextHearingAt: _dt(j['nextHearingAt']),
        nextHearingPurpose: (j['nextHearingPurpose'] ?? '').toString(),
      );

  static List<LegalCase> list(dynamic v) => (v is List ? v : const [])
      .whereType<Map>()
      .map((m) => LegalCase.fromJson(m.cast<String, dynamic>()))
      .toList();
}

class Hearing {
  final int id;
  final int caseId;
  final String caseTitle;
  final String caseNumber;
  final String court;
  final String clientName;
  final DateTime at;
  final String purpose;
  final String outcome;

  /// upcoming | done | adjourned | cancelled
  final String status;
  final bool remindClient;

  const Hearing({
    required this.id,
    required this.caseId,
    required this.caseTitle,
    required this.caseNumber,
    required this.court,
    required this.clientName,
    required this.at,
    required this.purpose,
    required this.outcome,
    required this.status,
    required this.remindClient,
  });

  factory Hearing.fromJson(Map<String, dynamic> j) => Hearing(
        id: _ms(j['id']) ?? 0,
        caseId: _ms(j['caseId']) ?? 0,
        caseTitle: (j['caseTitle'] ?? '').toString(),
        caseNumber: (j['caseNumber'] ?? '').toString(),
        court: (j['court'] ?? '').toString(),
        clientName: (j['clientName'] ?? '').toString(),
        at: _dt(j['at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        purpose: (j['purpose'] ?? '').toString(),
        outcome: (j['outcome'] ?? '').toString(),
        status: (j['status'] ?? 'upcoming').toString(),
        remindClient: j['remindClient'] == true,
      );

  static List<Hearing> list(dynamic v) => (v is List ? v : const [])
      .whereType<Map>()
      .map((m) => Hearing.fromJson(m.cast<String, dynamic>()))
      .toList();
}

class InvoiceLine {
  String description;
  double qty;
  double rate;
  InvoiceLine({this.description = '', this.qty = 1, this.rate = 0});

  double get amount => qty * rate;

  Map<String, dynamic> toJson() =>
      {'description': description.trim(), 'qty': qty, 'rate': rate};
}

class Invoice {
  final int id;

  /// invoice | quote
  final String kind;
  final String number;
  final String clientName;
  final double subtotal;
  final double gstRate;
  final double gst;
  final double total;

  /// issued | sent | paid | cancelled | accepted
  final String status;
  final String paymentUrl;
  final int? documentId;
  final DateTime createdAt;

  const Invoice({
    required this.id,
    required this.kind,
    required this.number,
    required this.clientName,
    required this.subtotal,
    required this.gstRate,
    required this.gst,
    required this.total,
    required this.status,
    required this.paymentUrl,
    required this.documentId,
    required this.createdAt,
  });

  bool get isQuote => kind == 'quote';
  bool get isPaid => status == 'paid';

  factory Invoice.fromJson(Map<String, dynamic> j) => Invoice(
        id: _ms(j['id']) ?? 0,
        kind: (j['kind'] ?? 'invoice').toString(),
        number: (j['number'] ?? '').toString(),
        clientName: (j['clientName'] ?? '').toString(),
        subtotal: (j['subtotal'] as num?)?.toDouble() ?? 0,
        gstRate: (j['gstRate'] as num?)?.toDouble() ?? 0,
        gst: (j['gst'] as num?)?.toDouble() ?? 0,
        total: (j['total'] as num?)?.toDouble() ?? 0,
        status: (j['status'] ?? 'issued').toString(),
        paymentUrl: (j['paymentUrl'] ?? '').toString(),
        documentId: _ms(j['documentId']),
        createdAt: _dt(j['createdAt']) ?? DateTime.now(),
      );

  static List<Invoice> list(dynamic v) => (v is List ? v : const [])
      .whereType<Map>()
      .map((m) => Invoice.fromJson(m.cast<String, dynamic>()))
      .toList();
}

const leadStages = ['new', 'contacted', 'proposal', 'won', 'lost'];

const leadStageLabel = {
  'new': 'New',
  'contacted': 'Contacted',
  'proposal': 'Proposal',
  'won': 'Won',
  'lost': 'Lost',
};

class Lead {
  final int id;
  final String name;
  final String company;
  final String phone;
  final double value;
  final String stage;
  final DateTime? nextFollowUp;
  final String note;
  final int? clientId;

  const Lead({
    required this.id,
    required this.name,
    required this.company,
    required this.phone,
    required this.value,
    required this.stage,
    required this.nextFollowUp,
    required this.note,
    required this.clientId,
  });

  factory Lead.fromJson(Map<String, dynamic> j) => Lead(
        id: _ms(j['id']) ?? 0,
        name: (j['name'] ?? '').toString(),
        company: (j['company'] ?? '').toString(),
        phone: (j['phone'] ?? '').toString(),
        value: (j['value'] as num?)?.toDouble() ?? 0,
        stage: (j['stage'] ?? 'new').toString(),
        nextFollowUp: _dt(j['nextFollowUp']),
        note: (j['note'] ?? '').toString(),
        clientId: _ms(j['clientId']),
      );

  static List<Lead> list(dynamic v) => (v is List ? v : const [])
      .whereType<Map>()
      .map((m) => Lead.fromJson(m.cast<String, dynamic>()))
      .toList();
}

/// A legal draft to review: title + body, the provisions it cites and the
/// facts the advocate must still fill in.
class LegalDraft {
  String title;
  String body;
  final List<String> provisionsCited;
  final List<String> advocateChecks;
  LegalDraft(this.title, this.body, this.provisionsCited, this.advocateChecks);

  factory LegalDraft.fromJson(Map<String, dynamic> j) => LegalDraft(
        (j['title'] ?? '').toString(),
        (j['body'] ?? '').toString(),
        ((j['provisionsCited'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        ((j['advocateChecks'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
      );
}
