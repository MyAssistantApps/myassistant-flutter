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

class Persona {
  Persona._();

  static const options = <PersonaOption>[
    PersonaOption('doctor', 'Doctor',
        'Patients, follow-ups, clinic calls and payments',
        Icons.medical_services_rounded),
    PersonaOption('advocate', 'Advocate',
        'Clients, hearings, case files and follow-ups',
        Icons.gavel_rounded),
    PersonaOption('business', 'Business leader',
        'Clients, deals, meetings and receivables',
        Icons.business_center_rounded),
    PersonaOption('professional', 'Working professional',
        'Meetings, clients, promises and follow-ups',
        Icons.work_rounded),
    PersonaOption('student', 'Student',
        'Classes, deadlines and reminders',
        Icons.school_rounded),
    PersonaOption('personal', 'Personal use',
        'Your day, your people, your errands',
        Icons.person_rounded),
  ];

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
      {String specialty = '', String clinic = ''}) async {
    final r = await ApiService.sendJson('/profile/details',
        method: 'PUT',
        body: {
          'persona': persona,
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
    AuthService.instance.applyPersona(persona, specialty: specialty.trim());
    return true;
  }
}
