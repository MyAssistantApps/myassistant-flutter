import 'persona.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  PRO WORDS — one place for how each profession names the same things.
///  The workspace screens are shared (Today, follow-ups, dues, bookings,
///  settings); only the words change: a doctor's "Clinic · Appointments ·
///  Payments" is an advocate's "Chambers · Consultations · Fees" and a
///  business leader's "Office · Meetings · Receivables".
/// ─────────────────────────────────────────────────────────────────────────
class ProWords {
  const ProWords._(
    this.workspace,
    this.today,
    this.appointments,
    this.appointment,
    this.book,
    this.payments,
    this.person,
    this.people,
    this.settings,
    this.placeName,
    this.regNo,
    this.qualification,
    this.feeLabel,
    this.receptionist,
  );

  /// "Clinic" / "Chambers" / "Office"
  final String workspace;

  /// "Today at clinic" / "Today in chambers" / "Today at a glance"
  final String today;

  /// "Appointments" / "Consultations" / "Meetings"
  final String appointments;
  final String appointment;

  /// "Book appointment" / "Book consultation" / "Schedule meeting"
  final String book;

  /// "Payments" / "Fees" / "Receivables"
  final String payments;

  /// "Patient" / "Client" / "Client"
  final String person;
  final String people;

  /// "Clinic settings" / "Chamber settings" / "Office settings"
  final String settings;

  /// Label of the place's name field.
  final String placeName;

  /// "Medical registration number" / "Bar Council enrolment number" / "GSTIN"
  final String regNo;

  /// "Qualifications (e.g. MBBS, MD)" / "Designation (e.g. Senior Advocate)" / ...
  final String qualification;

  /// null = no fee field (business).
  final String? feeLabel;

  /// What the phone receptionist does, for the settings switch.
  final String receptionist;

  static const doctor = ProWords._(
    'Clinic', 'Today at clinic', 'Appointments', 'appointment', 'Book appointment',
    'Payments', 'Patient', 'Patients', 'Clinic settings', 'Clinic name',
    'Medical registration number', 'Qualifications (e.g. MBBS, MD)', 'Consultation fee (₹)',
    'When you can\'t answer, your assistant offers callers your free slots and books them. '
        'It never gives medical advice, and sends emergencies to 108.',
  );

  static const advocate = ProWords._(
    'Chambers', 'Today in chambers', 'Consultations', 'consultation', 'Book consultation',
    'Fees', 'Client', 'Clients', 'Chamber settings', 'Chamber / firm name',
    'Bar Council enrolment number', 'Designation (e.g. Advocate, High Court)', 'Consultation fee (₹)',
    'When you can\'t answer, your assistant offers callers consultation slots and books them. '
        'It never gives legal advice or discusses a case, and flags urgent matters to you.',
  );

  static const business = ProWords._(
    'Office', 'Today at a glance', 'Meetings', 'meeting', 'Schedule meeting',
    'Receivables', 'Client', 'Clients', 'Office settings', 'Company name',
    'GSTIN', 'Your title (e.g. Managing Director)', null,
    'When you can\'t answer, your assistant screens callers, offers meeting slots and books '
        'them. It never quotes prices or commits to a deal.',
  );

  /// The words for the signed-in user's profession (doctor by default).
  static ProWords get current => of(Persona.value);

  static ProWords of(String persona) => switch (persona) {
        'advocate' => advocate,
        'business' => business,
        _ => doctor,
      };
}
