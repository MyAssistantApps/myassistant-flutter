// ARCHITECTURE GUARD (owner, 2026-11-22). The rules in CLAUDE.md
// ("Architecture rules"), checked on every `flutter test` and in CI, so a
// change that breaks them fails before review — whoever (or whatever)
// wrote it. When a rule really must change, change CLAUDE.md and this
// file together, in the same pull request, and say why.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/features/pricecompare/price_models.dart';

/// Every Dart file under lib/, with its path in forward slashes.
Map<String, String> _sources() => {
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>())
        if (f.path.endsWith('.dart')) f.path.replaceAll('\\', '/'): f.readAsStringSync(),
    };

/// Lines of [src] (comments stripped) matching [re], as "path:line".
List<String> _hits(Map<String, String> files, RegExp re, {bool Function(String path)? allow}) {
  final out = <String>[];
  files.forEach((path, src) {
    if (allow != null && allow(path)) return;
    final lines = src.replaceAll('\r', '').split('\n');
    for (var i = 0; i < lines.length; i++) {
      final code = lines[i].replaceFirst(RegExp(r'//.*$'), '');
      if (re.hasMatch(code)) out.add('$path:${i + 1}  ${lines[i].trim()}');
    }
  });
  return out;
}

void main() {
  final files = _sources();

  test('every AI call goes through our server: no Firebase AI / Gemini client in the app', () {
    // The phone talks to /ai/* on our server (ServerModelPort); the
    // firebase_ai package is only its wire format. A client created on the
    // phone bypasses the server's keys, budget breaker and logging.
    final hits = _hits(files,
        RegExp(r'FirebaseAI\s*\.|FirebaseModelPort|\bgenerativeModel\s*\(|\bliveGenerativeModel\s*\(|GoogleGenerativeAI|generativelanguage\.googleapis'));
    expect(hits, isEmpty, reason: 'Use the server model port (lib/ai/server_model_port.dart) instead:\n${hits.join('\n')}');
  });

  test('firebase_ai types stay inside lib/ai', () {
    final hits = _hits(files, RegExp(r'''import\s+['"]package:firebase_ai/'''),
        allow: (p) => p.startsWith('lib/ai/') || p == 'lib/screens/connect/assistant_call_screen.dart');
    expect(hits, isEmpty, reason: 'Go through lib/ai (brain / cloud), not firebase_ai directly:\n${hits.join('\n')}');
  });

  test('no new raw HTTP outside the services that already do it', () {
    // New network calls go through ApiService (lib/services/api_service.dart):
    // it adds auth, location, timezone, retries and readable errors.
    const known = {
      'lib/ai/brain.dart', 'lib/ai/server_model_port.dart', 'lib/ai/tool_server.dart',
      'lib/features/draft/draft_pad.dart', 'lib/features/shopping/shopping_service.dart',
      'lib/screens/business_card_flow.dart', 'lib/screens/diagnostics_screen.dart',
      'lib/screens/email_setup_screen.dart', 'lib/services/api_service.dart',
      'lib/services/app_update_service.dart', 'lib/services/auth_service.dart',
      'lib/services/avatar_message_service.dart', 'lib/services/call_recording_watcher.dart',
      'lib/services/clinic_service.dart', 'lib/services/connect_service.dart',
      'lib/services/focus_service.dart', 'lib/services/meetings_service.dart',
      'lib/services/net_status.dart', 'lib/services/phone_verify_service.dart',
      'lib/services/self_check.dart', 'lib/services/shortcuts_service.dart',
      'lib/services/studio_service.dart', 'lib/services/turn_audio_uploader.dart',
    };
    final hits = _hits(files, RegExp(r'''package:http/http\.dart|HttpClient\s*\(|package:dio/'''),
        allow: known.contains);
    expect(hits, isEmpty, reason: 'Use ApiService.getJson / sendJson / postJson instead:\n${hits.join('\n')}');
  });

  test('removed features stay removed: Price Compare offers products only', () {
    // Flights, hotels, rides and grocery left Price Compare on 2026-11-14
    // (owner decision). Bringing one back needs the owner's OK first.
    expect(PriceCategory.shown, [PriceCategory.shopping]);
  });

  test('users name their own assistant: no "Hari" in what the user sees', () {
    // A comparison (n == 'Hari') recognises the old default name: fine.
    final hits = _hits(files, RegExp(r'''(?<![=!]=\s*)['"][^'"]*\bHari\b[^'"]*['"]'''));
    expect(hits, isEmpty, reason: 'The assistant has the name the user gave it:\n${hits.join('\n')}');
  });
}
