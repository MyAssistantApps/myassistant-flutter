import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/listing.dart';
import 'api_service.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  LISTING SERVICE — the professional's public page (/listing, doctors,
///  advocates and businesses only) and "professionals near me" for every
///  user (/listings). Null on any failure; screens say so in words.
/// ─────────────────────────────────────────────────────────────────────────
class ListingService {
  ListingService._();
  static final instance = ListingService._();

  static const _t = Duration(seconds: 15);

  /// New booking requests waiting — the badge on the assistant page.
  final ValueNotifier<int> newRequests = ValueNotifier(0);

  /// Last known state, so the assistant page's card draws at once.
  final ValueNotifier<ListingState?> state = ValueNotifier(null);

  ListingState? _apply(Map<String, dynamic>? j) {
    if (j == null || j['listing'] is! Map) return null;
    final s = ListingState.fromJson(j);
    state.value = s;
    newRequests.value = s.newRequests;
    return s;
  }

  Future<ListingState?> load() async => _apply(await ApiService.getJson('/listing', timeout: _t));

  Future<ListingState?> save(Map<String, dynamic> patch) async =>
      _apply(await ApiService.sendJson('/listing', method: 'PUT', body: patch));

  /// Publishing can be refused (409) with what is still missing.
  Future<({ListingState? state, List<String> missing, String? message})> publish(bool on) async {
    final r = await ApiService.sendJson('/listing/publish', body: {'on': on});
    if (r != null && r['rejected'] == true) {
      return (
        state: null,
        missing: [for (final m in (r['missing'] as List? ?? const [])) '$m'],
        message: r['message'] as String?,
      );
    }
    return (state: _apply(r), missing: const <String>[], message: null);
  }

  Future<ListingState?> setPhoto(Uint8List bytes) async => _apply(await ApiService.sendJson(
      '/listing/photo',
      method: 'PUT',
      body: {'image': base64Encode(bytes)},
      timeout: const Duration(seconds: 40)));

  Future<ListingState?> removePhoto() async =>
      _apply(await ApiService.sendJson('/listing/photo', method: 'DELETE'));

  Future<List<ListingPost>?> posts() async {
    final j = await ApiService.getJson('/listing/posts', timeout: _t);
    return j == null ? null : ListingPost.list(j['posts']);
  }

  Future<ListingPost?> addPost({required String kind, required String title, String body = '', int days = 14}) async {
    final r = await ApiService.sendJson('/listing/posts',
        body: {'kind': kind, 'title': title, 'body': body, 'days': days});
    if (r == null || r['post'] is! Map) return null;
    return ListingPost.fromJson((r['post'] as Map).cast<String, dynamic>());
  }

  Future<bool> deletePost(int id) async => (await ApiService.deleteJson('/listing/posts/$id')) != null;

  Future<List<BookingRequest>?> requests() async {
    final j = await ApiService.getJson('/listing/requests', timeout: _t);
    if (j == null) return null;
    final list = BookingRequest.list(j['requests']);
    newRequests.value = list.where((r) => r.isNew).length;
    return list;
  }

  Future<bool> accept(int id, DateTime at, {bool remind = true}) async {
    final r = await ApiService.sendJson('/listing/requests/$id/accept',
        body: {'startsAt': at.millisecondsSinceEpoch, 'remindPatient': remind});
    final ok = r != null && r['request'] is Map;
    if (ok && newRequests.value > 0) newRequests.value--;
    return ok;
  }

  Future<bool> decline(int id) async {
    final r = await ApiService.sendJson('/listing/requests/$id/decline');
    final ok = r != null && r['request'] is Map;
    if (ok && newRequests.value > 0) newRequests.value--;
    return ok;
  }

  /* ---------------- anyone: near me ---------------- */

  Future<List<ProCard>?> near({required double lat, required double lng, String q = '', String persona = '', int radiusKm = 15}) async {
    final qs = Uri(queryParameters: {
      'lat': lat.toStringAsFixed(5),
      'lng': lng.toStringAsFixed(5),
      if (q.trim().isNotEmpty) 'q': q.trim(),
      if (persona.isNotEmpty) 'persona': persona,
      'radius': '$radiusKm',
    }).query;
    final j = await ApiService.getJson('/listings/near?$qs', timeout: _t);
    return j == null ? null : ProCard.list(j['results']);
  }

  Future<ProCard?> open(String slug) async {
    final j = await ApiService.getJson('/listings/${Uri.encodeComponent(slug)}', timeout: _t);
    if (j == null || j['listing'] is! Map) return null;
    return ProCard.fromJson((j['listing'] as Map).cast<String, dynamic>());
  }

  Future<bool> requestBooking(String slug, {required String name, required String phone, String preferred = '', String message = ''}) async {
    final r = await ApiService.sendJson('/listings/${Uri.encodeComponent(slug)}/request',
        body: {'name': name, 'phone': phone, 'preferred': preferred, 'message': message});
    return r != null && r['ok'] == true;
  }
}
