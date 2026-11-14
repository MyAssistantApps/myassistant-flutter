import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:myassistant/screens/auth/phone_verify_screen.dart';
import 'package:myassistant/services/phone_verify_service.dart';

class _NoSim implements SimNumberPort {
  @override
  Future<bool> supported() async => false;
  @override
  Future<SimNumberResult> verify() async => const SimNumberResult.failed('unsupported');
}

void main() {
  final posts = <(String, Map<String, dynamic>)>[];
  var refreshed = 0;

  PhoneVerifyService svc({bool call = true, bool typed = false, int codeStatus = 200}) =>
      PhoneVerifyService(
        sim: _NoSim(),
        getJson: (_) async => {'sim': true, 'call': call, 'typed': typed},
        post: (path, body) async {
          posts.add((path, body));
          if (path == '/phone/call-verify' && body['code'] != '482913') {
            return http.Response(jsonEncode({'error': "That code isn't right. 4 tries left."}), 400);
          }
          return http.Response(jsonEncode({'ok': true}), codeStatus);
        },
        refreshUser: () async => refreshed++,
      );

  setUp(() {
    posts.clear();
    refreshed = 0;
  });

  test('methods: the call is offered when the server says so', () async {
    final m = await svc().methods();
    expect(m.call, isTrue);
    expect(m.sim, isFalse, reason: 'no SIM support on this phone');
  });

  test('requestCall posts the number; the right code registers it', () async {
    final s = svc();
    expect(await s.requestCall('+919845012345'), isNull);
    expect(posts.single.$1, '/phone/call-code');
    expect(await s.verifyCallCode('+919845012345', '000000'), contains("isn't right"));
    expect(refreshed, 0);
    expect(await s.verifyCallCode('+919845012345', '482913'), isNull);
    expect(refreshed, 1);
  });

  test('a number taken by another account says so', () async {
    expect(await svc(codeStatus: 409).requestCall('+919845012345'), contains('already registered'));
  });

  testWidgets('the screen: number → call → code → verified', (t) async {
    final s = svc();
    await t.pumpWidget(MaterialApp(home: PhoneVerifyScreen(service: s)));
    await t.pumpAndSettle();
    expect(find.text('Call me with a code'), findsOneWidget);
    expect(find.textContaining('Testing:'), findsNothing, reason: 'typed path hidden when the server has it off');

    await t.enterText(find.byType(TextField).at(1), '9845012345');
    await t.tap(find.text('Call me with a code'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(find.textContaining("We're calling +919845012345"), findsOneWidget);
    expect(find.text('6-digit code'), findsOneWidget);
    expect(find.textContaining('Call again in'), findsOneWidget);

    await t.enterText(find.byType(TextField).first, '482913');
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(posts.last.$1, '/phone/call-verify');
    expect(posts.last.$2['code'], '482913');
    expect(refreshed, 1);
    // Let the cooldown timer finish so the test ends clean.
    await t.pump(const Duration(seconds: 46));
  });
}
