import 'package:flutter/material.dart';

import 'api_service.dart';
import 'auth_service.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  PERSONA — what the user does, chosen once at registration.
///
///  The single switch for profession-specific workspaces. Doctors get the
///  Clinic workspace; nobody else ever sees it. The server enforces the
///  same rule (/clinic answers 403 to anyone else), so hiding a screen
///  here is about a clean UI, never about security.
///
///  Source of truth is the account (AuthService.user.persona, cached with
///  the session), so the first frame after a cold start is already right.
/// ─────────────────────────────────────────────────────────────────────────
class PersonaOption {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  const PersonaOption(this.id, this.title, this.subtitle, this.icon);
}

/// What a workspace is called and the three things it gives.
class WorkspaceInfo {
  final String title;
  final List<String> perks;
  const WorkspaceInfo(this.title, this.perks);
}

/// One profession in the onboarding catalog.
class ProfessionEntry {
  final String label;
  final String persona;
  final IconData icon;
  final bool popular;
  const ProfessionEntry(this.label, this.persona, this.icon,
      {this.popular = false});
}

/// A profession the user picked or typed, with its workspace key.
class ProfessionMatch {
  final String label;
  final String persona;
  const ProfessionMatch(this.label, this.persona);
}

class Persona {
  Persona._();

  static const options = <PersonaOption>[
    PersonaOption('doctor', 'Doctor',
        'Patients, follow-ups, clinic calls and payments',
        Icons.medical_services_rounded),
    PersonaOption('advocate', 'Advocate',
        'Clients, hearings, case files and follow-ups',
        Icons.gavel_rounded),
    PersonaOption('business', 'Business Leader',
        'Clients, deals, meetings and receivables',
        Icons.business_center_rounded),
    PersonaOption('professional', 'Working Professional',
        'Meetings, clients, commitments and follow-ups',
        Icons.work_rounded),
    PersonaOption('student', 'Student',
        'Classes, deadlines and reminders',
        Icons.school_rounded),
    PersonaOption('personal', 'Personal Use',
        'Your day, your contacts and your errands',
        Icons.person_rounded),
  ];

  /// What each workspace gives, shown once a profession is picked.
  static const workspaces = <String, WorkspaceInfo>{
    'doctor': WorkspaceInfo('Clinic Workspace', [
      'Appointments, timings and open slots',
      'Patient follow-ups, notes and dues',
      'Your assistant answers patient calls',
    ]),
    'advocate': WorkspaceInfo('Legal Practice Workspace', [
      'Client case files and documents',
      'Hearing dates with timely reminders',
      'Client follow-ups and invoices',
    ]),
    'business': WorkspaceInfo('Business Workspace', [
      'Customers, leads and deals',
      'Invoices and receivables',
      'Meetings and follow-ups tracked for you',
    ]),
    'professional': WorkspaceInfo('Professional Workspace', [
      'Meetings, commitments and follow-ups',
      'Client files kept in one place',
      'A daily briefing shaped around your work',
    ]),
    'student': WorkspaceInfo('Student Workspace', [
      'Classes, deadlines and exams',
      'Reminders before every due date',
      'Focus time and study habits',
    ]),
    'personal': WorkspaceInfo('Personal Assistant', [
      'Your day, reminders and errands',
      'Calls, messages and contacts',
      'Bookings and everyday tasks',
    ]),
  };

  /// Professions people can search or tap. Each maps to the workspace that
  /// fits it; anything not listed is typed freely and resolved by the
  /// server (POST /profile/profession/resolve).
  static const professions = <ProfessionEntry>[
    // Quick picks, shown before any search.
    ProfessionEntry('Doctor', 'doctor', Icons.medical_services_rounded, popular: true),
    ProfessionEntry('Lawyer / Advocate', 'advocate', Icons.gavel_rounded, popular: true),
    ProfessionEntry('Business Owner', 'business', Icons.storefront_rounded, popular: true),
    ProfessionEntry('Software Engineer', 'professional', Icons.code_rounded, popular: true),
    ProfessionEntry('Teacher', 'professional', Icons.co_present_rounded, popular: true),
    ProfessionEntry('Chartered Accountant', 'professional', Icons.calculate_rounded, popular: true),
    ProfessionEntry('Sales & Marketing', 'professional', Icons.trending_up_rounded, popular: true),
    ProfessionEntry('Manager', 'professional', Icons.groups_rounded, popular: true),
    ProfessionEntry('Freelancer', 'professional', Icons.laptop_mac_rounded, popular: true),
    ProfessionEntry('Student', 'student', Icons.school_rounded, popular: true),
    ProfessionEntry('Homemaker', 'personal', Icons.home_rounded, popular: true),
    ProfessionEntry('Retired', 'personal', Icons.park_rounded, popular: true),
    // Healthcare
    ProfessionEntry('Dentist', 'doctor', Icons.medical_services_rounded),
    ProfessionEntry('Physiotherapist', 'doctor', Icons.accessibility_new_rounded),
    ProfessionEntry('Veterinarian', 'doctor', Icons.pets_rounded),
    ProfessionEntry('Ayurvedic Doctor', 'doctor', Icons.spa_rounded),
    ProfessionEntry('Homeopathic Doctor', 'doctor', Icons.spa_rounded),
    ProfessionEntry('Psychiatrist', 'doctor', Icons.psychology_rounded),
    ProfessionEntry('Surgeon', 'doctor', Icons.medical_services_rounded),
    ProfessionEntry('Nurse', 'professional', Icons.local_hospital_rounded),
    ProfessionEntry('Pharmacist', 'professional', Icons.medication_rounded),
    ProfessionEntry('Psychologist / Counsellor', 'professional', Icons.psychology_alt_rounded),
    ProfessionEntry('Dietitian / Nutritionist', 'professional', Icons.restaurant_menu_rounded),
    ProfessionEntry('Lab Technician', 'professional', Icons.biotech_rounded),
    // Legal and finance
    ProfessionEntry('Company Secretary', 'professional', Icons.badge_rounded),
    ProfessionEntry('Legal Consultant', 'professional', Icons.balance_rounded),
    ProfessionEntry('Accountant', 'professional', Icons.calculate_rounded),
    ProfessionEntry('Banker', 'professional', Icons.account_balance_rounded),
    ProfessionEntry('Financial Advisor', 'professional', Icons.savings_rounded),
    ProfessionEntry('Insurance Agent', 'business', Icons.shield_rounded),
    ProfessionEntry('Stock Trader / Investor', 'business', Icons.candlestick_chart_rounded),
    // Business and trade
    ProfessionEntry('Entrepreneur / Founder', 'business', Icons.rocket_launch_rounded),
    ProfessionEntry('Shop Owner', 'business', Icons.storefront_rounded),
    ProfessionEntry('Restaurant / Café Owner', 'business', Icons.restaurant_rounded),
    ProfessionEntry('Real Estate Agent', 'business', Icons.real_estate_agent_rounded),
    ProfessionEntry('Contractor / Builder', 'business', Icons.construction_rounded),
    ProfessionEntry('Trader / Wholesaler', 'business', Icons.inventory_2_rounded),
    ProfessionEntry('Manufacturer', 'business', Icons.factory_rounded),
    ProfessionEntry('Agency Owner', 'business', Icons.hub_rounded),
    ProfessionEntry('Salon / Spa Owner', 'business', Icons.content_cut_rounded),
    ProfessionEntry('Gym / Studio Owner', 'business', Icons.fitness_center_rounded),
    ProfessionEntry('Event Planner', 'business', Icons.celebration_rounded),
    ProfessionEntry('Travel Agent', 'business', Icons.flight_takeoff_rounded),
    ProfessionEntry('Farmer', 'business', Icons.agriculture_rounded),
    ProfessionEntry('Exporter / Importer', 'business', Icons.local_shipping_rounded),
    // Technology and office
    ProfessionEntry('Product Manager', 'professional', Icons.dashboard_customize_rounded),
    ProfessionEntry('Designer', 'professional', Icons.palette_rounded),
    ProfessionEntry('Data Scientist / Analyst', 'professional', Icons.analytics_rounded),
    ProfessionEntry('Consultant', 'professional', Icons.support_agent_rounded),
    ProfessionEntry('HR / Recruiter', 'professional', Icons.person_search_rounded),
    ProfessionEntry('Operations Executive', 'professional', Icons.settings_suggest_rounded),
    ProfessionEntry('Customer Support', 'professional', Icons.headset_mic_rounded),
    ProfessionEntry('Civil Engineer', 'professional', Icons.engineering_rounded),
    ProfessionEntry('Mechanical Engineer', 'professional', Icons.precision_manufacturing_rounded),
    ProfessionEntry('Architect', 'professional', Icons.architecture_rounded),
    // Education and research
    ProfessionEntry('Professor / Lecturer', 'professional', Icons.history_edu_rounded),
    ProfessionEntry('Tutor / Coach', 'professional', Icons.menu_book_rounded),
    ProfessionEntry('Researcher / Scientist', 'professional', Icons.science_rounded),
    // Media and creative
    ProfessionEntry('Content Creator', 'professional', Icons.videocam_rounded),
    ProfessionEntry('Journalist / Writer', 'professional', Icons.edit_note_rounded),
    ProfessionEntry('Photographer', 'professional', Icons.photo_camera_rounded),
    ProfessionEntry('Artist / Musician', 'professional', Icons.music_note_rounded),
    // Public service and field work
    ProfessionEntry('Government Employee', 'professional', Icons.account_balance_rounded),
    ProfessionEntry('Police / Defence', 'professional', Icons.local_police_rounded),
    ProfessionEntry('Driver', 'professional', Icons.local_taxi_rounded),
    ProfessionEntry('Delivery Partner', 'professional', Icons.delivery_dining_rounded),
    ProfessionEntry('Electrician / Plumber', 'professional', Icons.electrical_services_rounded),
    ProfessionEntry('Mechanic / Technician', 'professional', Icons.build_rounded),
    ProfessionEntry('Chef / Cook', 'professional', Icons.soup_kitchen_rounded),
    ProfessionEntry('Pilot / Cabin Crew', 'professional', Icons.flight_rounded),
    ProfessionEntry('Social Worker / NGO', 'professional', Icons.volunteer_activism_rounded),
    ProfessionEntry('Priest / Religious Service', 'professional', Icons.self_improvement_rounded),
    // Studying and personal
    ProfessionEntry('College Student', 'student', Icons.school_rounded),
    ProfessionEntry('School Student', 'student', Icons.backpack_rounded),
    ProfessionEntry('Exam Aspirant (UPSC, NEET, JEE)', 'student', Icons.auto_stories_rounded),
    ProfessionEntry('Looking for Work', 'personal', Icons.work_outline_rounded),
  ];

  static List<ProfessionEntry> get popular =>
      professions.where((p) => p.popular).toList(growable: false);

  /// Catalog entries matching [query], best first: the label starts with
  /// it, then a word in it does, then it appears anywhere.
  static List<ProfessionEntry> search(String query, {int limit = 8}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    int rank(ProfessionEntry p) {
      final l = p.label.toLowerCase();
      if (l.startsWith(q)) return 0;
      if (l.contains(' $q') || l.contains('/$q') || l.contains('($q')) return 1;
      return l.contains(q) ? 2 : 9;
    }

    final hits = professions.where((p) => rank(p) < 9).toList()
      ..sort((a, b) => rank(a).compareTo(rank(b)));
    return hits.take(limit).toList(growable: false);
  }

  /// Free text the catalog doesn't know → its workspace, decided by the
  /// server. Null when offline; the caller falls back to Professional.
  static Future<ProfessionMatch?> resolve(String text) async {
    final r = await ApiService.sendJson('/profile/profession/resolve',
        body: {'text': text.trim()}, timeout: const Duration(seconds: 8));
    final persona = r?['persona'] as String?;
    if (r == null || persona == null || persona.isEmpty) return null;
    final label = (r['label'] as String?)?.trim();
    return ProfessionMatch(
        (label == null || label.isEmpty) ? text.trim() : label, persona);
  }

  static const specialties = [
    'General Physician', 'Dentist', 'Paediatrician', 'Gynaecologist',
    'Dermatologist', 'Orthopaedic', 'Cardiologist', 'ENT',
    'Ophthalmologist', 'Psychiatrist', 'Physiotherapist',
  ];

  /// Rebuilds whatever listens when the persona changes (sign-in, the
  /// registration step, or a change in Settings).
  static final ValueNotifier<String> notifier = ValueNotifier('');

  static String get value => notifier.value;
  static bool get isDoctor => notifier.value == 'doctor';
  static bool get isChosen => notifier.value.isNotEmpty;

  /// Doctors, advocates, professionals and business owners use case files.
  static bool get usesCaseFiles => const {'doctor', 'advocate', 'professional', 'business'}
      .contains(notifier.value);

  /// The one Pro assistant (doctor / advocate / business) this user may
  /// see, or null. Owner's rule (2026-11-13): each profession sees ONLY its
  /// own assistant; everyone else sees none. The server enforces the same.
  static String? get proKind => const {'doctor', 'advocate', 'business'}
          .contains(notifier.value)
      ? notifier.value
      : null;

  static String titleFor(String id) =>
      options.where((o) => o.id == id).map((o) => o.title).firstOrNull ??
      'Not set';

  static bool _bound = false;

  /// Follows the signed-in account. Idempotent; call once at startup.
  static void bind() {
    if (_bound) return;
    _bound = true;
    AuthService.instance.addListener(_sync);
    _sync();
  }

  static void _sync() {
    notifier.value = AuthService.instance.user?.persona ?? '';
  }

  /// Saves the choice. Returns false when the server didn't accept it —
  /// the caller keeps the user on the screen and says so.
  static Future<bool> save(String persona,
      {String specialty = '', String clinic = '', String profession = ''}) async {
    final r = await ApiService.sendJson('/profile/details',
        method: 'PUT',
        body: {
          'persona': persona,
          if (profession.trim().isNotEmpty) 'profession': profession.trim(),
          if (specialty.trim().isNotEmpty) 'specialty': specialty.trim(),
          if (clinic.trim().isNotEmpty) 'organisation': clinic.trim(),
        });
    if (r == null) return false;
    final user = r['user'] as Map?;
    // An older backend ignores the field and echoes no `persona` at all:
    // nothing can be saved there, so don't hold the user on this screen.
    if (user == null || !user.containsKey('persona')) return true;
    final saved = (user['persona'] as String?) ?? '';
    if (saved != persona) return false; // server refused the value
    AuthService.instance.applyPersona(persona,
        specialty: specialty.trim(), profession: profession.trim());
    return true;
  }
}
