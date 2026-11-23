// Quiet updates (owner, 2026-11-23: "update silently without the user
// knowing"): an automatic check downloads on Wi-Fi with nothing on screen
// and installs only after the app has been left for three minutes.
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
    final calls = <Map<Object?, Object?>>[];
    final apk = File('${Directory.systemTemp.path}/update-999.apk');

    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('hari/updater'), (c) async {
        if (c.method == 'install') calls.add(c.arguments as Map<Object?, Object?>);
        return true;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('hari/updater'), null);
    });

    testWidgets('three minutes in the background, then a silent install', (t) async {
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      AppUpdateService.instance.debugQuietReady(apk, 999);
      await t.pump(const Duration(minutes: 10));
      expect(calls, isEmpty, reason: 'never while the app is in use');

      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await t.pump(const Duration(minutes: 2));
      expect(calls, isEmpty, reason: 'a quick switch away is not "left"');
      await t.pump(const Duration(minutes: 1, seconds: 1));
      expect(calls, hasLength(1));
      expect(calls.single['silent'], isTrue);
      expect(calls.single['path'], apk.path);

      // Once per build per run: no second attempt in the background.
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await t.pump(const Duration(minutes: 5));
      expect(calls, hasLength(1));
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });

    testWidgets('coming back before three minutes starts the wait again', (t) async {
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      AppUpdateService.instance.debugQuietReady(apk, 1000);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await t.pump(const Duration(minutes: 2));
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pump(const Duration(minutes: 5));
      expect(calls, isEmpty, reason: 'back in use: the app is never replaced');

      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await t.pump(const Duration(minutes: 3, seconds: 1));
      expect(calls, hasLength(1));
      expect(calls.single['silent'], isTrue);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });
  });
}
