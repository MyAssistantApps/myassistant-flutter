import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_service.dart';

const _intent = MethodChannel('hari/intent');

/// OPEN A PARTNER'S OWN APP (2026-11-13: "open the app if it is installed,
/// else the Play Store"). [pkg] is its Android package, from GET /go.
///
/// Installed → the app opens. Not installed → its Play Store page. Either
/// way GET /go/:id is still called, so the click is counted on the server.
/// Returns false when there is no [pkg] (the caller opens the website).
Future<bool> openPartnerApp(String id, String? pkg) async {
  if (pkg == null || pkg.isEmpty) return false;
  // Count the click; the link itself is not needed here.
  ApiService.getJson('/go/$id').ignore();
  try {
    // Exact package only (name ''), so a lookalike label can never win.
    final opened =
        await _intent.invokeMethod<String>('launchApp', {'name': '', 'pkg': pkg});
    if (opened != null && opened.isNotEmpty) return true;
  } catch (_) {}
  final market = Uri.parse('market://details?id=$pkg');
  if (await launchUrl(market, mode: LaunchMode.externalApplication)) return true;
  return launchUrl(
      Uri.parse('https://play.google.com/store/apps/details?id=$pkg'),
      mode: LaunchMode.externalApplication);
}
