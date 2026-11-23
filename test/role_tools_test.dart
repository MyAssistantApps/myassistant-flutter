// A page's role names the server tools its work needs (2026-11-23): the
// Jyotish guru and the professional pages. A fast-voice session takes its
// tools once, when it opens, so every context request carries them.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myassistant/ai/assistant_role.dart';
import 'package:myassistant/ai/tool_server.dart';
import 'package:myassistant/features/jyotish/jyotish_guru.dart';
import 'package:myassistant/screens/pro_assistant_screen.dart';

/// Tools registered on the server (myassistant-backend src/tools/builtins.js
/// and src/jyotish/tools.js) that the roles may name.
const _serverTools = {
  'jyotish_chart', 'jyotish_reading', 'book_patient_appointment',
  'schedule_patient_recall', 'complete_patient_recall', 'check_patient_dues',
  'record_patient_payment', 'send_patient_document', 'find_document',
  'list_person_documents', 'file_document_under_client', 'remember_case',
  'remember_event', 'draft_text', 'indian_case_law', 'check_payments',
  'record_entry',
};

void main() {
  tearDown(() => AssistantRole.current.value = null);

  Future<Map<String, dynamic>> sent() async {
    late Map<String, dynamic> body;
    final server = ToolServer(
      client: MockClient((req) async {
        body = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response('{}', 500);
      }),
      baseUrl: () => 'https://example.test',
      headers: () => const {},
      onStatus: (_) {},
    );
    await server.context(text: '', mode: 'live');
    return body;
  }

  test('a context request carries the role\'s tools, and none without a role', () async {
    expect((await sent()).containsKey('roleTools'), isFalse);
    AssistantRole.current.value = guruRole;
    expect((await sent())['roleTools'], ['jyotish_chart', 'jyotish_reading']);
  });

  test('every role names real server tools, at most sixteen', () {
    final roles = <AssistantRole>[
      guruRole,
      for (final k in ProKind.values) ...[
        ProProfile.of(k).role,
        for (final a in ProProfile.of(k).actions.where((a) => !a.featured)) ProProfile.of(k).roleFor(a),
      ],
    ];
    for (final r in roles) {
      expect(r.tools, isNotEmpty, reason: r.name);
      expect(r.tools.length, lessThanOrEqualTo(16), reason: r.name);
      expect(r.tools.toSet().length, r.tools.length, reason: '${r.name}: no repeats');
      for (final t in r.tools) {
        expect(_serverTools, contains(t), reason: '${r.name}: $t');
      }
    }
  });

  test('each tile\'s mic can do what its tile says', () {
    final doctor = ProProfile.of(ProKind.doctor);
    for (final a in doctor.actions.where((a) => !a.featured)) {
      final r = doctor.roleFor(a);
      // Every tool the tile's own hint names is one the session is given.
      for (final m in RegExp(r'\b([a-z]+(?:_[a-z]+)+)\b').allMatches(a.voice!)) {
        final name = m.group(1)!;
        if (!_serverTools.contains(name)) continue;
        expect(r.tools, contains(name), reason: '${a.title}: $name');
      }
    }
    final roles = [ProKind.advocate, ProKind.business].map(ProProfile.of);
    for (final p in roles) {
      for (final a in p.actions.where((a) => !a.featured)) {
        for (final m in RegExp(r'\b([a-z]+(?:_[a-z]+)+)\b').allMatches(a.voice!)) {
          final name = m.group(1)!;
          if (!_serverTools.contains(name)) continue;
          expect(p.roleFor(a).tools, contains(name), reason: '${p.name} ${a.title}: $name');
        }
      }
    }
  });
}
