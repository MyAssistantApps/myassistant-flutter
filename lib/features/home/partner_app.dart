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
///
/// A PARTNER THAT EARNS CASHBACK IS NEVER OPENED THIS WAY (2026-11-27).
/// A purchase is tracked only when the user arrives through the partner's
/// link from GET /go/:id, which carries the click's own id; launching the
/// installed app directly skips that link, and the purchase would earn the
/// user nothing. [opensInstalledAppFirst] is the one place that decides.
bool opensInstalledAppFirst({required String? pkg, required bool cashback}) =>
    !cashback && pkg != null && pkg.isNotEmpty;

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

/// Opens a partner through its tracked link (GET /go/:id). False when the
/// link could not be fetched or opened.
Future<bool> openPartnerLink(String id) async {
  final j = await ApiService.getJson('/go/$id');
  final url = j?['url'] as String?;
  if (url == null || url.isEmpty) return false;
  return launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}
