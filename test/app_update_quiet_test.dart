// Quiet updates (owner, 2026-11-23: "update silently without the user
// knowing"): an automatic check downloads on Wi-Fi with nothing on screen;
// once the app is left, a system job installs it three minutes later.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/services/app_update_service.dart';

void main() {
  group('which way an update is taken', () {
    UpdatePath path({
      bool userAsked = false,
      bool forced = false,
      bool silentPossible = true,
      bool metered = false,
    }) =>
        AppUpdateService.choosePath(
            userAsked: userAsked,
            forced: forced,
            silentPossible: silentPossible,
            metered: metered);

    test('an automatic check on Wi-Fi is quiet', () {
      expect(path(), UpdatePath.quiet);
    });

    test('on mobile data a quiet update waits for Wi-Fi', () {
      expect(path(metered: true), UpdatePath.waitForWifi);
    });

    test('asking by voice always shows the sheet', () {
      expect(path(userAsked: true), UpdatePath.sheet);
      expect(path(userAsked: true, metered: true), UpdatePath.sheet);
    });

    test('a forced update shows the sheet', () {
      expect(path(forced: true), UpdatePath.sheet);
    });

    test('a phone that cannot install without a prompt gets the sheet', () {
      expect(path(silentPossible: false), UpdatePath.sheet);
      expect(path(silentPossible: false, metered: true), UpdatePath.sheet);
    });
  });

  group('the quiet install waits until the app has been left', () {
    final calls = <MethodCall>[];
    final apk = File('${Directory.systemTemp.path}/update-999.apk');

    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('hari/updater'), (c) async {
        calls.add(c);
        return true;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('hari/updater'), null);
    });

    Iterable<MethodCall> named(String m) => calls.where((c) => c.method == m);

    testWidgets('leaving the app hands the install to a system job, three minutes on',
        (t) async {
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      AppUpdateService.instance.debugQuietReady(apk, 999);
      await t.pump(const Duration(minutes: 10));
      expect(calls, isEmpty, reason: 'nothing while the app is in use');

      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await t.pump();
      expect(named('scheduleQuietInstall'), isNotEmpty);
      final args = named('scheduleQuietInstall').last.arguments as Map<Object?, Object?>;
      expect(args['path'], apk.path);
      expect(args['delayMs'], const Duration(minutes: 3).inMilliseconds);
      // The app never installs itself from a timer of its own: Android
      // freezes it in the background, and the timer would fire on return.
      expect(named('install'), isEmpty);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pump();
    });

    testWidgets('coming back cancels it; leaving again schedules it again', (t) async {
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      AppUpdateService.instance.debugQuietReady(apk, 1000);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await t.pump();
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pump();
      expect(calls.last.method, 'cancelQuietInstall',
          reason: 'back in use: the app is never replaced under the user');

      calls.clear();
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await t.pump();
      expect(named('scheduleQuietInstall'), isNotEmpty);
      expect(named('install'), isEmpty);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pump();
    });
  });
}
