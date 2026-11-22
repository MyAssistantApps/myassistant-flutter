// JYOTISH SERVICE (2026-11-22) — the app's side of /jyotish
// (myassistant-backend src/jyotish/routes.js). The chart is computed on the
// server; the AI key never reaches the phone.

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/log.dart';
import '../../services/api_service.dart';
import 'jyotish_models.dart';

class JyotishService {
  const JyotishService();

  /// The chat so far → what the AI read from it. Null when it failed.
  Future<Extracted?> extract(List<({String role, String text})> messages) async {
    final j = await ApiService.sendJson('/jyotish/extract',
        body: {
          'messages': [
            for (final m in messages) {'role': m.role, 'text': m.text}
          ]
        },
        timeout: const Duration(seconds: 30));
    return j == null ? null : Extracted.fromJson(j);
  }

  /// Up to five places for what the user typed. Null when the lookup failed.
  Future<List<PlaceOption>?> places(String q) async {
    final j = await ApiService.getJson(
        '/jyotish/places?q=${Uri.encodeQueryComponent(q.trim())}');
    return j == null ? null : PlaceOption.listFrom(j['places']);
  }

  Future<ChartResult?> chart(Birth birth, {DateTime? transitDate}) async {
    final j = await ApiService.sendJson('/jyotish/chart', body: {
      'birth': birth.toJson(),
      if (transitDate != null) 'transitDate': ymd(transitDate),
    });
    return ChartResult.fromJson(j);
  }

  Future<List<SavedProfile>?> profiles() async {
    final j = await ApiService.getJson('/jyotish/profiles');
    return j == null ? null : SavedProfile.listFrom(j['profiles']);
  }

  Future<bool> saveProfile(String name, Birth birth) async {
    final j = await ApiService.sendJson('/jyotish/profiles',
        body: {'name': name, 'birth': birth.toJson()});
    return j != null && j['profile'] != null;
  }

  Future<bool> deleteProfile(int id) async =>
      await ApiService.deleteJson('/jyotish/profiles/$id') != null;

  /// A reading, as it is written. The stream ends after the last event;
  /// a failure arrives as a [ReadingError], never as a thrown error.
  Stream<ReadingEvent> predict({
    required Birth birth,
    required String range,
    required String category,
    required String language,
    DateTime? date,
  }) async* {
    final client = http.Client();
    try {
      final req = http.Request(
          'POST', Uri.parse('${ApiService.baseUrl}/jyotish/predict'))
        ..headers.addAll({
          ...ApiService.authHeaders,
          'Content-Type': 'application/json',
          'Accept': 'text/event-stream',
        })
        ..body = jsonEncode({
          'birth': birth.toJson(),
          'range': range,
          'category': category,
          'language': language,
          if (date != null) 'date': ymd(date),
        });
      final resp = await client.send(req).timeout(const Duration(seconds: 30));
      if (resp.statusCode == 429) {
        yield const ReadingError(
            'Too many readings in a minute. Please wait a moment.');
        return;
      }
      if (resp.statusCode != 200) {
        ApiService.noteAuthStatus(resp.statusCode);
        AppLog.add('jyotish', 'predict -> ${resp.statusCode}');
        yield const ReadingError('Unable to get the reading. Please try again.');
        return;
      }
      var buffer = '';
      await for (final piece in resp.stream
          .transform(utf8.decoder)
          .timeout(const Duration(seconds: 60))) {
        buffer += piece;
        int nl;
        while ((nl = buffer.indexOf('\n')) >= 0) {
          final line = buffer.substring(0, nl).trim();
          buffer = buffer.substring(nl + 1);
          if (!line.startsWith('data:')) continue;
          final payload = line.substring(5).trim();
          if (payload.isEmpty || payload == '[DONE]') continue;
          Object? decoded;
          try {
            decoded = jsonDecode(payload);
          } catch (_) {
            continue;
          }
          final ev = readingEventFrom(decoded);
          if (ev != null) yield ev;
        }
      }
    } catch (e) {
      AppLog.add('jyotish', 'predict failed: $e');
      yield const ReadingError(
          'Unable to get the reading. Check your connection and try again.');
    } finally {
      client.close();
    }
  }
}

String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
