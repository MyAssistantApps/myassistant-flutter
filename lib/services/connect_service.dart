import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_service.dart';
import 'contacts_sync_service.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  CONNECT — talk live to a contact's own assistant (owner, 2026-11-21:
///  "connect me to Alan's assistant ... I should see Alan's photo plus the
///  name Alan gave his agent ... the voice should match").
///
///  Mirrors backend src/connect/ (GET /connect/people, /connect/:id,
///  /connect/:id/photo, POST /connect/:id/secret|tool|end, /connect/settings).
///  The session's voice, instructions and tools are decided by the server
///  from the HOST's settings; the phone only carries audio and tool calls.
/// ─────────────────────────────────────────────────────────────────────────
class AssistantContact {
  final int id;
  final String ownerName; // as the caller saved them
  final String assistantName; // what the owner named their assistant
  final String voice;
  final String profession;
  final String persona;
  final bool hasPhoto;
  const AssistantContact({
    required this.id,
    required this.ownerName,
    required this.assistantName,
    required this.voice,
    this.profession = '',
    this.persona = '',
    this.hasPhoto = false,
  });

  factory AssistantContact.fromJson(Map<String, dynamic> j) => AssistantContact(
        id: (j['id'] as num?)?.toInt() ?? 0,
        ownerName: (j['ownerName'] as String?)?.trim().isNotEmpty == true
            ? (j['ownerName'] as String).trim()
            : 'Your Contact',
        assistantName:
            (j['assistantName'] as String?)?.trim().isNotEmpty == true
                ? (j['assistantName'] as String).trim()
                : 'Assistant',
        voice: j['voice'] as String? ?? '',
        profession: j['profession'] as String? ?? '',
        persona: j['persona'] as String? ?? '',
        hasPhoto: j['hasPhoto'] == true,
      );

  /// "Alan Lobo" → "Alan".
  String get firstName => ownerName.split(RegExp(r'\s+')).first;

  /// The photo's URL; load it with [ApiService.authHeaders].
  String get photoUrl => '${ApiService.baseUrl}/connect/$id/photo';
}

/// One guest tool result, as the server answered it.
class GuestToolResult {
  final Map<String, dynamic> json;
  const GuestToolResult(this.json);
  bool get ok => json['ok'] == true;
  bool get ends => json['end'] == true;
}

class ConnectService {
  ConnectService._();

  /// Contacts who use MyAssistant and take assistant calls. Syncs the
  /// address book first when [sync] (at most every 12 h unless forced),
  /// because discovery is the address book matched to app numbers.
  static Future<List<AssistantContact>?> people(
      {bool sync = true, bool force = false}) async {
    if (sync) {
      try {
        await ContactsSyncService.instance.maybeSync(force: force);
      } catch (_) {
        // No permission or offline: the server still has the last copy.
      }
    }
    final j = await ApiService.getJson('/connect/people',
        timeout: const Duration(seconds: 12));
    final list = j?['people'];
    if (list is! List) return null;
    return list
        .whereType<Map>()
        .map((m) => AssistantContact.fromJson(m.cast<String, dynamic>()))
        .where((c) => c.id > 0)
        .toList(growable: false);
  }

  static Future<AssistantContact?> card(int id) async {
    final j = await ApiService.getJson('/connect/$id');
    if (j == null || j['id'] == null) return null;
    return AssistantContact.fromJson(j);
  }

  /// The realtime key for a session as [id]'s assistant, plus its card and
  /// the opening cue. Null when refused (the error is in [lastError]).
  static Future<Map<String, dynamic>?> mint(int id) async {
    lastError = null;
    try {
      final r = await http
          .post(Uri.parse('${ApiService.baseUrl}/connect/$id/secret'),
              headers: {
                ...ApiService.authHeaders,
                'Content-Type': 'application/json'
              },
              body: '{}')
          .timeout(const Duration(seconds: 15));
      final j = r.body.isEmpty ? const <String, dynamic>{} : jsonDecode(r.body);
      final m =
          j is Map ? j.cast<String, dynamic>() : const <String, dynamic>{};
      if (r.statusCode != 200 || (m['value'] ?? '').toString().isEmpty) {
        // The server's own words ("This person is not taking assistant
        // calls.") are written to be shown as they are.
        lastError = (m['error'] as String?) ?? 'Unable to reach the assistant.';
        return null;
      }
      return m;
    } catch (_) {
      lastError = 'Unable to reach the assistant. Check your connection.';
      return null;
    }
  }

  static String? lastError;

  static Future<GuestToolResult> tool(
      int id, String name, Map<String, dynamic> args) async {
    final j = await ApiService.postJson(
        '/connect/$id/tool', {'name': name, 'args': args});
    return GuestToolResult(j ??
        const {'ok': false, 'error': 'the request did not reach the server'});
  }

  /// I have seen an urgent alert: its repeat pings stop and the sender is
  /// told. Without [id], every open urgent alert.
  static Future<void> ackUrgent([int? id]) async {
    await ApiService.postJson('/connect/urgent/ack', {if (id != null) 'id': id});
  }

  /// After the call: the host gets a short summary from the transcript.
  static Future<void> end(int id, List<Map<String, String>> transcript) async {
    await ApiService.postJson('/connect/$id/end', {'transcript': transcript});
  }

  static Future<String?> openMode() async {
    final j = await ApiService.getJson('/connect/settings');
    return j?['open'] as String?;
  }

  static Future<bool> setOpenMode(String mode) async {
    final j = await ApiService.sendJson('/connect/settings',
        method: 'PUT', body: {'open': mode});
    return j?['open'] == mode;
  }
}
