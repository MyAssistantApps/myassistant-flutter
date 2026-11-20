import 'package:flutter/foundation.dart';

import 'privacy_prefs_service.dart' show JsonTransport, apiTransport;

/// ─────────────────────────────────────────────────────────────────────────
///  CONNECTED APPS (build 120): whether mail and Google are linked, for the
///  Connected Apps screen. Each keeps its own way of linking.
/// ─────────────────────────────────────────────────────────────────────────
class ConnectionsService {
  ConnectionsService._();
  static final ConnectionsService instance = ConnectionsService._();

  @visibleForTesting
  static JsonTransport transport = apiTransport;

  /// Mail keeps its own screen; this is only whether it is linked.
  Future<bool> mailLinked() async {
    final r = await Future.wait(
        [transport('GET', '/email/account'), transport('GET', '/google/status')]);
    return r[0]?['connected'] == true || r[1]?['connected'] == true;
  }

  /// Google (Gmail + Calendar) links through the phone's own Google sign-in.
  Future<bool> googleLinked() async =>
      (await transport('GET', '/google/status'))?['connected'] == true;
}
