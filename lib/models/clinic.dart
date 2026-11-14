// Clinic workspace models — shapes of /clinic/* (backend src/clinic/routes.js).
import 'pro.dart';
export 'pro.dart';

class FollowUp {
  final int id;
  final int clientId;
  final String clientName;
  final String clientPhone;
  final String note;
  final DateTime dueAt;
  final bool notifyPatient;
  final bool patientCalled;

  const FollowUp({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.clientPhone,
    required this.note,
    required this.dueAt,
    required this.notifyPatient,
    required this.patientCalled,
  });

  factory FollowUp.fromJson(Map<String, dynamic> j) => FollowUp(
        id: (j['id'] as num?)?.toInt() ?? 0,
        clientId: (j['clientId'] as num?)?.toInt() ?? 0,
        clientName: (j['clientName'] ?? '').toString(),
        clientPhone: (j['clientPhone'] ?? '').toString(),
        note: (j['note'] ?? '').toString(),
        dueAt: DateTime.fromMillisecondsSinceEpoch(
            (j['dueAt'] as num?)?.toInt() ?? 0),
        notifyPatient: j['notifyPatient'] == true,
        patientCalled: j['patientCalled'] == true,
      );

  static List<FollowUp> list(dynamic v) => (v is List ? v : const [])
      .whereType<Map>()
      .map((m) => FollowUp.fromJson(m.cast<String, dynamic>()))
      .toList();
}

class FollowUpBuckets {
  final List<FollowUp> overdue;
  final List<FollowUp> today;
  final List<FollowUp> upcoming;
  const FollowUpBuckets(this.overdue, this.today, this.upcoming);

  static const empty = FollowUpBuckets([], [], []);

  factory FollowUpBuckets.fromJson(Map<String, dynamic>? j) => j == null
      ? empty
      : FollowUpBuckets(FollowUp.list(j['overdue']),
          FollowUp.list(j['today']), FollowUp.list(j['upcoming']));

  bool get isEmpty => overdue.isEmpty && today.isEmpty && upcoming.isEmpty;
}

class Due {
  final int clientId;
  final String name;
  final double balance;
  const Due(this.clientId, this.name, this.balance);

  factory Due.fromJson(Map<String, dynamic> j) => Due(
        (j['clientId'] as num?)?.toInt() ?? 0,
        (j['name'] ?? '').toString(),
        (j['balance'] as num?)?.toDouble() ?? 0,
      );

  static List<Due> list(dynamic v) => (v is List ? v : const [])
      .whereType<Map>()
      .map((m) => Due.fromJson(m.cast<String, dynamic>()))
      .toList();
}

class ClinicToday {
  final int patients;
  final FollowUpBuckets followUps;
  final List<Due> dues;
  final int duesCount;
  final double duesTotal;
  final List<Appointment> appointments;

  // Advocates: hearings today / later this week.
  final List<Hearing> hearingsToday;
  final List<Hearing> hearingsWeek;

  // Business: leads to follow up today, the open pipeline, unpaid invoices.
  final List<Lead> leadsDue;
  final int openLeads;
  final double pipelineValue;
  final int unpaidInvoices;
  final double unpaidTotal;

  const ClinicToday({
    required this.patients,
    required this.followUps,
    required this.dues,
    required this.duesCount,
    required this.duesTotal,
    this.appointments = const [],
    this.hearingsToday = const [],
    this.hearingsWeek = const [],
    this.leadsDue = const [],
    this.openLeads = 0,
    this.pipelineValue = 0,
    this.unpaidInvoices = 0,
    this.unpaidTotal = 0,
  });

  /// Appointments still to be seen today (booked or in the waiting room).
  List<Appointment> get openAppointments =>
      appointments.where((a) => a.isOpen).toList();

  factory ClinicToday.fromJson(Map<String, dynamic> j) => ClinicToday(
        patients: (j['patients'] as num?)?.toInt() ?? 0,
        followUps: FollowUpBuckets.fromJson(
            (j['followUps'] as Map?)?.cast<String, dynamic>()),
        dues: Due.list(j['dues']),
        duesCount: (j['duesCount'] as num?)?.toInt() ?? 0,
        duesTotal: (j['duesTotal'] as num?)?.toDouble() ?? 0,
        appointments: Appointment.list(j['appointments']),
        hearingsToday: Hearing.list(j['hearingsToday']),
        hearingsWeek: Hearing.list(j['hearingsWeek']),
        leadsDue: Lead.list(j['leadsDue']),
        openLeads: (j['openLeads'] as num?)?.toInt() ?? 0,
        pipelineValue: (j['pipelineValue'] as num?)?.toDouble() ?? 0,
        unpaidInvoices: (j['unpaidInvoices'] as num?)?.toInt() ?? 0,
        unpaidTotal: (j['unpaidTotal'] as num?)?.toDouble() ?? 0,
      );
}

/// ₹1,25,000 — Indian digit grouping, no paise unless there are some.
String rupees(double v) {
  final neg = v < 0;
  final abs = v.abs();
  final whole = abs.truncate();
  final paise = ((abs - whole) * 100).round();
  var s = whole.toString();
  if (s.length > 3) {
    final last3 = s.substring(s.length - 3);
    var rest = s.substring(0, s.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    s = '${parts.join(',')},$last3';
  }
  return '${neg ? '−' : ''}₹$s${paise > 0 ? '.${paise.toString().padLeft(2, '0')}' : ''}';
}

/* ---------------------------------------------------------------------- */
/* Phase 2 — appointments, clinic profile, consult notes, prescriptions   */
/* ---------------------------------------------------------------------- */

class Appointment {
  final int id;
  final int? clientId;
  final String patientName;
  final String patientPhone;
  final DateTime startsAt;
  final int durationMin;
  final String reason;

  /// booked | arrived | done | cancelled | no_show
  final String status;

  /// app | voice | receptionist
  final String source;
  final bool remindPatient;
  final bool reminded;

  const Appointment({
    required this.id,
    required this.clientId,
    required this.patientName,
    required this.patientPhone,
    required this.startsAt,
    required this.durationMin,
    required this.reason,
    required this.status,
    required this.source,
    required this.remindPatient,
    required this.reminded,
  });

  bool get isOpen => status == 'booked' || status == 'arrived';

  factory Appointment.fromJson(Map<String, dynamic> j) => Appointment(
        id: (j['id'] as num?)?.toInt() ?? 0,
        clientId: (j['clientId'] as num?)?.toInt(),
        patientName: (j['patientName'] ?? '').toString(),
        patientPhone: (j['patientPhone'] ?? '').toString(),
        startsAt: DateTime.fromMillisecondsSinceEpoch(
            (j['startsAt'] as num?)?.toInt() ?? 0),
        durationMin: (j['durationMin'] as num?)?.toInt() ?? 15,
        reason: (j['reason'] ?? '').toString(),
        status: (j['status'] ?? 'booked').toString(),
        source: (j['source'] ?? 'app').toString(),
        remindPatient: j['remindPatient'] == true,
        reminded: j['reminded'] == true,
      );

  static List<Appointment> list(dynamic v) => (v is List ? v : const [])
      .whereType<Map>()
      .map((m) => Appointment.fromJson(m.cast<String, dynamic>()))
      .toList();
}

/// Weekly timetable: day key (mon…sun) → sessions like ["10:00", "13:00"].
typedef ClinicHours = Map<String, List<List<String>>>;

const clinicDays = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

class ClinicProfile {
  String clinicName;
  String address;
  String phone;
  double fee;
  String regNo;
  String qualification;
  ClinicHours hours;
  int slotMin;
  bool receptionistBooks;
  final bool configured;

  ClinicProfile({
    required this.clinicName,
    required this.address,
    required this.phone,
    required this.fee,
    required this.regNo,
    required this.qualification,
    required this.hours,
    required this.slotMin,
    required this.receptionistBooks,
    required this.configured,
  });

  factory ClinicProfile.fromJson(Map<String, dynamic> j) {
    final raw = (j['hours'] as Map?) ?? const {};
    final hours = <String, List<List<String>>>{
      for (final d in clinicDays)
        d: ((raw[d] as List?) ?? const [])
            .whereType<List>()
            .where((r) => r.length == 2)
            .map((r) => [r[0].toString(), r[1].toString()])
            .toList(),
    };
    return ClinicProfile(
      clinicName: (j['clinicName'] ?? '').toString(),
      address: (j['address'] ?? '').toString(),
      phone: (j['phone'] ?? '').toString(),
      fee: (j['fee'] as num?)?.toDouble() ?? 0,
      regNo: (j['regNo'] ?? '').toString(),
      qualification: (j['qualification'] ?? '').toString(),
      hours: hours,
      slotMin: (j['slotMin'] as num?)?.toInt() ?? 15,
      receptionistBooks: j['receptionistBooks'] == true,
      configured: j['configured'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'clinicName': clinicName,
        'address': address,
        'phone': phone,
        'fee': fee,
        'regNo': regNo,
        'qualification': qualification,
        'hours': hours,
        'slotMin': slotMin,
        'receptionistBooks': receptionistBooks,
      };
}

class RxItem {
  String name;
  String dose;
  String frequency;
  String duration;
  String instructions;

  RxItem({
    this.name = '',
    this.dose = '',
    this.frequency = '',
    this.duration = '',
    this.instructions = '',
  });

  factory RxItem.fromJson(Map<String, dynamic> j) => RxItem(
        name: (j['name'] ?? '').toString(),
        dose: (j['dose'] ?? '').toString(),
        frequency: (j['frequency'] ?? '').toString(),
        duration: (j['duration'] ?? '').toString(),
        instructions: (j['instructions'] ?? '').toString(),
      );

  static List<RxItem> list(dynamic v) => (v is List ? v : const [])
      .whereType<Map>()
      .map((m) => RxItem.fromJson(m.cast<String, dynamic>()))
      .toList();

  Map<String, dynamic> toJson() => {
        'name': name.trim(),
        'dose': dose.trim(),
        'frequency': frequency.trim(),
        'duration': duration.trim(),
        'instructions': instructions.trim(),
      };

  String get line => [
        name,
        dose,
        frequency,
        if (duration.isNotEmpty) '× $duration',
        if (instructions.isNotEmpty) '($instructions)',
      ].where((s) => s.trim().isNotEmpty).join(' ');
}

class SoapNote {
  String chiefComplaint;
  String subjective;
  String objective;
  String assessment;
  String plan;
  List<RxItem> medications;
  int? followUpDays;
  List<String> redFlags;

  SoapNote({
    required this.chiefComplaint,
    required this.subjective,
    required this.objective,
    required this.assessment,
    required this.plan,
    required this.medications,
    required this.followUpDays,
    required this.redFlags,
  });

  factory SoapNote.fromJson(Map<String, dynamic> j) => SoapNote(
        chiefComplaint: (j['chiefComplaint'] ?? '').toString(),
        subjective: (j['subjective'] ?? '').toString(),
        objective: (j['objective'] ?? '').toString(),
        assessment: (j['assessment'] ?? '').toString(),
        plan: (j['plan'] ?? '').toString(),
        medications: RxItem.list(j['medications']),
        followUpDays: (j['followUpDays'] as num?)?.toInt(),
        redFlags: ((j['redFlags'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
      );

  /// The text filed in the case file — same shape the server produces.
  String toText() {
    String or(String s) => s.trim().isEmpty ? 'Not discussed.' : s.trim();
    final b = StringBuffer();
    if (chiefComplaint.trim().isNotEmpty) {
      b.writeln('CC: ${chiefComplaint.trim()}');
    }
    b.writeln('S: ${or(subjective)}');
    b.writeln('O: ${or(objective)}');
    b.writeln('A: ${or(assessment)}');
    b.writeln('P: ${or(plan)}');
    final meds = medications.where((m) => m.name.trim().isNotEmpty).toList();
    if (meds.isNotEmpty) {
      b.writeln('Rx:');
      for (final m in meds) {
        b.writeln('  • ${m.line}');
      }
    }
    if (redFlags.isNotEmpty) b.writeln('Watch for: ${redFlags.join('; ')}');
    final fu = followUpDays;
    if (fu != null && fu > 0) {
      b.writeln('Review in $fu day${fu == 1 ? '' : 's'}.');
    }
    return b.toString().trim();
  }
}
