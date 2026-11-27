// LAUNCH READINESS (2026-11-25): the fixes from the pre-launch audit that
// can be checked without a phone. Each test names the fault it guards.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/core/build_error_note.dart';
import 'package:myassistant/core/store_build.dart';
import 'package:myassistant/features/calendar/calendar_service.dart';
import 'package:myassistant/features/pricecompare/price_service.dart';
import 'package:myassistant/services/api_service.dart';
import 'package:myassistant/services/app_update_service.dart';
import 'package:myassistant/services/assistant_identity.dart';
import 'package:myassistant/services/avatar_message_service.dart';
import 'package:myassistant/services/net_status.dart';
import 'package:myassistant/services/phone_verify_service.dart';
import 'package:myassistant/services/sign_out_cleanup.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('server address override', () {
    test('a release build follows an override only to our own servers', () {
      bool ok(String u) => ApiService.overrideAllowed(u, release: true);
      expect(ok('https://backend.envisionsit.in'), isTrue);
      expect(ok('https://dev.backend.envisionsit.in'), isTrue);
      expect(ok('https://dev.189-72-146-77.sslip.io'), isTrue);
      // A stranger's server never receives the session token.
      expect(ok('https://evil.example.com'), isFalse);
      expect(ok('https://backend.envisionsit.in.evil.example.com'), isFalse);
      expect(ok('https://evilenvisionsit.in'), isFalse);
      expect(ok('https://user:pass@backend.envisionsit.in'), isFalse);
      expect(ok('http://backend.envisionsit.in'), isFalse, reason: 'https only');
      expect(ok('not a url'), isFalse);
      expect(ok(''), isFalse);
    });

    test('a debug build may still use a local server', () {
      expect(ApiService.overrideAllowed('http://10.0.2.2:3000', release: false), isTrue);
    });
  });

  test('a busy answer still means the server is up', () {
    expect(NetStatus.answered(200), isTrue);
    // "Too many requests" is the server answering, not the server down.
    expect(NetStatus.answered(429), isTrue);
    expect(NetStatus.answered(401), isTrue);
    expect(NetStatus.answered(500), isFalse);
    expect(NetStatus.answered(502), isFalse);
  });

  test('the chat list does not ask the server from a tab nobody is looking at', () {
    // A hidden tab stays built with its tickers off (TabDeck); its route is
    // still "current". The poll must stop there: 12 requests a minute from
    // every open phone is what filled a shared network address's limit.
    final src = File('lib/screens/meetings/meetings_screen.dart').readAsStringSync();
    final start = src.indexOf('_poll = Timer.periodic');
    expect(start, greaterThan(0));
    final poll = src.substring(start, src.indexOf('void dispose()', start));
    final hidden = poll.indexOf('if (!TickerMode.valuesOf(context).enabled) return;');
    final load = poll.indexOf('_load(quiet: true)');
    expect(hidden, greaterThan(0));
    expect(hidden, lessThan(load), reason: 'the tab check comes before the request');
    // And the deck really does switch a hidden tab's tickers off.
    final deck = File('lib/design/tab_deck.dart').readAsStringSync();
    expect(deck, contains('TickerMode('));
    expect(deck, contains('enabled: visible.contains(i)'));
  });

  test('phone verification gives up waiting after half a minute', () {
    expect(PhoneVerifyService.postTimeout, const Duration(seconds: 30));
  });

  group('the self-updater and Google Play', () {
    test('the updater is on for the sideloaded build and off for a Play build', () {
      // This test runs as the sideloaded build (no STORE define).
      expect(kPlayStoreBuild, isFalse);
      expect(AppUpdateService.enabled, !kPlayStoreBuild);
      final src = File('lib/services/app_update_service.dart').readAsStringSync();
      expect(src, contains('static const bool enabled = !kPlayStoreBuild;'));
    });

    test('the Play manifest ships nothing that installs packages', () {
      final play = File('android/app/src/playRelease/AndroidManifest.xml').readAsStringSync();
      for (final gone in const [
        'android.permission.REQUEST_INSTALL_PACKAGES',
        'android.permission.UPDATE_PACKAGES_WITHOUT_USER_ACTION',
        '.InstallResultReceiver',
        '.QuietInstallJob',
      ]) {
        expect(
          RegExp('android:name="${RegExp.escape(gone)}"\\s+tools:node="remove"').hasMatch(play),
          isTrue,
          reason: '$gone is removed from the Play build',
        );
      }
      // Both components exist in the main manifest, so the removal is real.
      final main = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(main, contains('android:name=".QuietInstallJob"'));
      expect(main, contains('android:name=".InstallResultReceiver"'));
    });
  });

  group('a Google Play build contains no installer code', () {
    const pkg = 'com/myassistant/myassistant';
    const src = 'android/app/src';
    // What only the updater uses (tool/check_play_build.sh has the same list
    // and, on CI, also inspects the compiled Play variant).
    final installer = RegExp('PackageInstaller|InstallResultReceiver|ApkInstaller|QuietInstallJob|'
        'package-archive|ACTION_INSTALL_PACKAGE|canRequestPackageInstalls|REQUEST_INSTALL_PACKAGES');

    test('the installer lives only in the sideloaded build\'s source folder', () {
      for (final f in const ['ApkInstaller.kt', 'QuietInstallJob.kt', 'UpdaterChannel.kt']) {
        expect(File('$src/sideload/kotlin/$pkg/$f').existsSync(), isTrue, reason: f);
        expect(File('$src/main/kotlin/$pkg/$f').existsSync(), isFalse,
            reason: '$f in src/main would be compiled into the Play build');
      }
      for (final f in Directory('$src/main/kotlin').listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.kt')) continue;
        expect(installer.hasMatch(f.readAsStringSync()), isFalse,
            reason: '${f.path} holds installer code; it belongs in src/sideload/kotlin');
      }
    });

    test('the build picks the folder by store, and the activity only knows the channel\'s name', () {
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();
      expect(gradle,
          contains('kotlin.srcDir(if (playStoreBuild) "src/play/kotlin" else "src/sideload/kotlin")'));
      final activity = File('$src/main/kotlin/$pkg/MainActivity.kt').readAsStringSync();
      expect(activity, contains('UpdaterChannel.register('));
      expect(activity.contains('"hari/updater"'), isFalse,
          reason: 'the channel is registered by UpdaterChannel, not by the activity');
    });

    test('the Play stand-in has the same shape and does nothing', () {
      final real = File('$src/sideload/kotlin/$pkg/UpdaterChannel.kt').readAsStringSync();
      final play = File('$src/play/kotlin/$pkg/UpdaterChannel.kt').readAsStringSync();
      const shape = 'fun register(messenger: BinaryMessenger, app: Context)';
      expect(real, contains(shape));
      expect(play, contains(shape));
      expect(real, contains('const val AVAILABLE = true'));
      expect(play, contains('const val AVAILABLE = false'));
      // Code lines only: its comment may name what it replaces.
      final code = play
          .split('\n')
          .where((l) => !RegExp(r'^\s*(\*|/\*\*|//)').hasMatch(l))
          .join('\n');
      expect(installer.hasMatch(code), isFalse);
      expect(code.contains('MethodChannel'), isFalse, reason: 'no channel is registered on Play');
      // The real one answers every method the Dart side calls.
      final dart = File('lib/services/app_update_service.dart').readAsStringSync();
      final called = RegExp(r"invokeMethod<bool>\(\s*'(\w+)'").allMatches(dart).map((m) => m.group(1)!).toSet();
      expect(called, isNotEmpty);
      for (final m in called) {
        expect(real, contains('"$m" ->'), reason: 'the sideloaded channel handles $m');
      }
    });

    test('on Play, asking for an update points to the Play Store', () {
      final engine = File('lib/features/assistant/state/assistant_engine.dart').readAsStringSync();
      expect(engine, contains('This app is updated by the Google Play Store'));
    });
  });

  test('the native copy of the session token is kept out of backups', () {
    for (final f in const [
      'android/app/src/main/res/xml/backup_rules.xml',
      'android/app/src/main/res/xml/data_extraction_rules.xml',
    ]) {
      final xml = File(f).readAsStringSync();
      expect(xml, contains('path="hari_overlay_prefs.xml"'), reason: f);
      expect(xml, contains('path="hari_overlay_prefs_plain.xml"'), reason: f);
    }
    // The names match the file the native side writes.
    final kt = File('android/app/src/main/kotlin/com/myassistant/myassistant/NotifyPrefs.kt')
        .readAsStringSync();
    expect(kt, contains('private const val FILE = "hari_overlay_prefs"'));
    expect(kt, contains(r'"${FILE}_plain"'));
  });

  test('the microphone service is not started without the microphone permission', () {
    final kt = File('android/app/src/main/kotlin/com/myassistant/myassistant/OverlayServices.kt')
        .readAsStringSync();
    final acquire = kt.substring(kt.indexOf('fun acquire('), kt.indexOf('fun releaseAll('));
    final check = acquire.indexOf('RECORD_AUDIO');
    final start = acquire.indexOf('startForegroundService');
    expect(check, greaterThan(0));
    expect(check, lessThan(start), reason: 'the permission is checked before the service starts');
  });

  group('signing out', () {
    testWidgets('the next account starts clean and the app returns to its first screen', (tester) async {
      SharedPreferences.setMockInitialValues({
        'assistant_named_v1': true,
        'assistant_display_name': 'Nova',
        'price_compare.recent.v1': '[]',
        'price_compare.watches.v1': '[]',
        'cal_extras_v1': '{}',
        // The phone's own choices stay.
        'perm_mic_skipped_v1': true,
        'welcomed_v1': true,
      });
      AssistantIdentity.notifier.value = 'Nova';

      await tester.pumpWidget(MaterialApp(
        navigatorKey: AvatarMessageService.navigatorKey,
        home: const Scaffold(body: Text('root')),
      ));
      AvatarMessageService.navigatorKey.currentState!.push(
          MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('documents'))));
      await tester.pumpAndSettle();
      expect(find.text('documents'), findsOneWidget);

      await tester.runAsync(SignOutCleanup.run);
      await tester.pumpAndSettle();

      // The screen that was open is gone; the root (the sign-in screen in
      // the app) is what is left.
      expect(find.text('documents'), findsNothing);
      expect(find.text('root'), findsOneWidget);

      final prefs = await SharedPreferences.getInstance();
      for (final k in SignOutCleanup.accountKeys) {
        expect(prefs.containsKey(k), isFalse, reason: '$k belonged to the account that left');
      }
      expect(prefs.getBool('perm_mic_skipped_v1'), isTrue);
      expect(prefs.getBool('welcomed_v1'), isTrue);
      expect(AssistantIdentity.name, AssistantIdentity.fallback);
      expect(PriceService.instance.recent, isEmpty);
      expect(PriceService.instance.watches, isEmpty);
      final now = DateTime.now();
      expect(CalendarService.cachedMonth(now.year, now.month), isNull);
    });

    test('with no screen up yet, cleaning up does not throw', () async {
      SharedPreferences.setMockInitialValues({'assistant_named_v1': true});
      await SignOutCleanup.run();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('assistant_named_v1'), isFalse);
    });
  });

  group('a widget that fails to build', () {
    testWidgets('shows one calm sentence in a release build', (tester) async {
      // The test framework insists the builder is back before the body ends.
      final before = ErrorWidget.builder;
      late final Widget shown;
      try {
        installBuildErrorNote(release: true);
        shown = ErrorWidget.builder(FlutterErrorDetails(exception: Exception('boom')));
      } finally {
        ErrorWidget.builder = before;
      }
      expect(shown, isA<BuildErrorNote>());
      // It needs nothing above it: no theme, no text direction.
      await tester.pumpWidget(shown);
      expect(find.text(BuildErrorNote.message), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('a debug build keeps Flutter\'s own error text', () {
      final before = ErrorWidget.builder;
      installBuildErrorNote(release: false);
      expect(identical(ErrorWidget.builder, before), isTrue);
    });
  });
}
