// JYOTISH (features/jyotish): the server's chart parses (fixture made by the
// backend's own engine), reading events parse, both kundli styles draw, the
// Home card opens the screen, and the chat fills the form.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/ai/listen.dart';
import 'package:myassistant/ai/local_tools.dart';
import 'package:myassistant/features/jyotish/jyotish_card.dart';
import 'package:myassistant/features/jyotish/jyotish_guru.dart';
import 'package:myassistant/features/jyotish/jyotish_models.dart';
import 'package:myassistant/features/jyotish/jyotish_onboarding.dart';
import 'package:myassistant/features/jyotish/jyotish_screen.dart';
import 'package:myassistant/features/jyotish/jyotish_service.dart';
import 'package:myassistant/features/jyotish/jyotish_theme.dart';
import 'package:myassistant/features/jyotish/jyotish_voice.dart';
import 'package:myassistant/features/jyotish/kundli_chart.dart';
import 'package:myassistant/features/jyotish/today_horoscope.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _fixture() =>
    jsonDecode(File('test/fixtures/jyotish_chart.json').readAsStringSync()) as Map<String, dynamic>;

class _FakeService extends JyotishService {
  _FakeService({this.profileList = const []});
  List<SavedProfile> profileList;
  final extractCalls = <List<({String role, String text})>>[];
  Extracted? nextExtract;

  @override
  Future<List<SavedProfile>?> profiles() async => profileList;

  @override
  Future<Extracted?> extract(List<({String role, String text})> messages) async {
    extractCalls.add(messages);
    return nextExtract;
  }

  @override
  Future<List<PlaceOption>?> places(String q) async =>
      const [PlaceOption(name: 'Udupi, Karnataka, India', lat: 13.3409, lng: 74.7421, tz: 'Asia/Kolkata')];

  @override
  Future<ChartResult?> chart(Birth birth, {DateTime? transitDate}) async => ChartResult.fromJson(_fixture());

  @override
  Future<bool> saveProfile(String name, Birth birth) async => true;
}

class _QuietRecognizer implements RecognizerPort {
  @override
  Future<bool> initialize({required void Function(String) onStatus, required void Function(String, bool) onError}) async =>
      false;
  @override
  Future<List<String>> localeIds() async => const [];
  @override
  Future<void> listen({
    required void Function(String, bool) onResult,
    void Function(double)? onLevel,
    String? localeId,
    required bool onDevice,
    required Duration listenFor,
    required Duration pauseFor,
  }) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> cancel() async {}
}

class _QuietSpeaker extends JyotishSpeaker {
  @override
  Future<bool> hasLanguage(String locale) async => true;
  @override
  Future<List<TtsVoice>> voicesFor(String locale) async => const [];
  @override
  Future<void> stop() async => state.value = SpeakState.idle;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('models', () {
    test('a chart from the server parses in full', () {
      final r = ChartResult.fromJson(_fixture())!;
      expect(r.birth.utc, '2004-03-14T01:00:00.000Z');
      expect(r.birth.offsetMinutes, 330);
      final c = r.chart;
      expect(c.timeKnown, isTrue);
      expect(c.planets, hasLength(9));
      expect(c.lagna!.signName, 'Aquarius');
      expect(c.firstSign, 10);
      expect(c.rashi, 'Sagittarius');
      expect(c.nakshatra, 'Mula');
      expect(c.planet('Jupiter')!.showRetro, isTrue);
      expect(c.planet('Rahu')!.showRetro, isFalse, reason: 'the nodes are always backwards; not flagged');
      expect(c.dashas, hasLength(9));
      expect(c.dashas.first.lord, 'Ketu');
      expect(c.dashas.first.sub, hasLength(9));
      final (md, ad) = c.dashaAt(DateTime.utc(2026, 11, 22));
      expect(md!.lord, 'Venus');
      expect(ad, isNotNull);
      expect(c.yogas.map((y) => y.name), contains('Gajakesari Yoga'));
      expect(r.transits.planets, hasLength(9));
      expect(r.transits.planets.every((p) => p.houseFromMoon != null), isTrue);
      expect(r.disclaimer, 'For entertainment and self-reflection only.');
    });

    test('missing and odd fields never throw', () {
      expect(ChartResult.fromJson(null), isNull);
      expect(ChartResult.fromJson({'birth': {}, 'chart': {}}), isNull);
      final c = Chart.fromJson({'planets': [{'name': 'Sun', 'sign': 'x'}], 'yogas': 'nope', 'dasha': 3});
      expect(c.planets.single.sign, 0);
      expect(c.yogas, isEmpty);
      expect(c.dashas, isEmpty);
      expect(c.lagna, isNull);
      final e = Extracted.fromJson({'fields': {'timeStatus': 'unknown'}, 'complete': true, 'places': [{'name': 'x'}]});
      expect(e.timeUnknown, isTrue);
      expect(e.places, isEmpty, reason: 'a place without coordinates is dropped');
    });

    test('reading events', () {
      expect(readingEventFrom({'t': 'Hello'}), isA<ReadingText>());
      expect((readingEventFrom({'meta': {'cached': true, 'period': {'start': '2026-11-01'}}}) as ReadingMeta).cached, isTrue);
      expect(readingEventFrom({'fallback': true}), isA<ReadingFallback>());
      expect((readingEventFrom({'error': {'message': 'down'}}) as ReadingError).message, 'down');
      expect(readingEventFrom({'t': ''}), isNull);
      expect(readingEventFrom('junk'), isNull);
    });

    test('birth to JSON keeps an unknown time as null', () {
      const b = Birth(date: '1990-08-15', lat: 28.6, lng: 77.2);
      expect(b.toJson().containsKey('time'), isTrue);
      expect(b.toJson()['time'], isNull);
      expect(b.timeKnown, isFalse);
    });

    test('pretty dates and times', () {
      expect(prettyDate('2004-03-14'), '14 Mar 2004');
      expect(prettyTime('06:30'), '6:30 AM');
      expect(prettyTime('18:05'), '6:05 PM');
      expect(prettyTime('00:10'), '12:10 AM');
      expect(prettyTime(null), 'Time unknown');
    });
  });

  group('kundli', () {
    for (final style in KundliStyle.values) {
      testWidgets('${style.name} style draws, with a spoken summary', (t) async {
        final c = ChartResult.fromJson(_fixture())!.chart;
        await t.pumpWidget(MaterialApp(
          home: Center(
            child: SizedBox(width: 320, child: KundliChart(chart: c, style: style, colors: Cosmic.kundli)),
          ),
        ));
        expect(t.takeException(), isNull);
        expect(find.bySemanticsLabel(RegExp('lagna Aquarius.*house 1, Aquarius: Sun')), findsOneWidget);
      });
    }

    testWidgets('without a birth time it is the Moon chart', (t) async {
      final j = _fixture();
      final chart = Map<String, dynamic>.from(j['chart'] as Map)
        ..['timeKnown'] = false
        ..['lagna'] = null;
      final c = Chart.fromJson(chart);
      expect(c.firstSign, 8, reason: 'Sagittarius, the Moon sign');
      await t.pumpWidget(MaterialApp(
        home: SizedBox(width: 300, child: KundliChart(chart: c, style: KundliStyle.south, colors: Cosmic.kundli)),
      ));
      expect(find.bySemanticsLabel(RegExp('Moon chart, starting from Sagittarius')), findsOneWidget);
    });
  });

  group('the Jyotish voice', () {
    test('the card\'s mic: today\'s bhavishya from a saved chart, or the birth questions', () {
      expect(jyotishMicNote, contains('jyotish_chart'));
      expect(jyotishMicNote, contains("today's Jyotisha Bhavishya"));
      expect(jyotishMicNote, contains('jyotish_reading'));
      expect(jyotishMicNote, contains('one question at a time'));
      expect(jyotishMicNote, contains('other questions'));
    });

    test('it speaks only from the Jyotish tools, kindly, in a male voice', () {
      expect(guruRole.brief, contains('jyotish_chart'));
      expect(guruRole.brief, contains('jyotish_reading'));
      expect(guruRole.brief, contains('never invent planetary positions'));
      expect(guruRole.brief, contains('never sell remedies'));
      expect(guruRole.voice, 'cedar');
      expect(guruRole.tools, ['jyotish_chart', 'jyotish_reading']);
    });
  });

  group('screens', () {
    Widget host(Widget child) => MaterialApp(home: child);

    testWidgets('the Home card opens the horoscope; its camera uploads one; it has a mic', (t) async {
      Widget? opened;
      TodayHoroscope.sign.value = null;
      await t.pumpWidget(host(Scaffold(body: JyotishCard(load: false, onOpen: (p) => opened = p))));
      expect(find.text("TODAY'S HOROSCOPE"), findsOneWidget);
      expect(find.text('Jyotish'), findsOneWidget);
      await t.tap(find.text('Jyotish'));
      expect(opened, isA<JyotishScreen>());
      expect((opened! as JyotishScreen).startWithUpload, isFalse);
      await t.tap(find.bySemanticsLabel('Upload your horoscope'));
      expect((opened! as JyotishScreen).startWithUpload, isTrue);
      // A mic, no "Talk to Guruji" button.
      expect(find.bySemanticsLabel(RegExp(r'^Speak to .* about your horoscope$')), findsOneWidget);
      expect(find.text('Talk to Guruji'), findsNothing);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('an uploaded horoscope fills the details to check', (t) async {
      t.view.physicalSize = const Size(1080, 2400);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      await t.pumpWidget(host(Scaffold(
        body: JyotishOnboarding(
          service: _FakeService(),
          listener: JyotishListener(_QuietRecognizer()),
          onCast: (_, {required save}) async => true,
          extracted: const Extracted(
            name: 'Asha',
            date: '2004-03-14',
            time: '06:30',
            timeStatus: 'exact',
            place: 'Udupi',
            complete: true,
            places: [PlaceOption(name: 'Udupi, Karnataka, India', lat: 13.3409, lng: 74.7421, tz: 'Asia/Kolkata')],
          ),
        ),
      )));
      await t.pumpAndSettle();
      expect(find.textContaining('I have read your horoscope, Asha'), findsOneWidget);
      expect(find.text('Asha'), findsWidgets);
      expect(find.text('14 Mar 2004'), findsOneWidget);
      expect(find.text('6:30 AM'), findsOneWidget);
      expect(find.text('Udupi, Karnataka, India'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('the date of birth is chosen on wheels, not a calendar', (t) async {
      t.view.physicalSize = const Size(1080, 2400);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      await t.pumpWidget(host(Scaffold(
        body: JyotishOnboarding(
          service: _FakeService(),
          listener: JyotishListener(_QuietRecognizer()),
          onCast: (_, {required save}) async => true,
        ),
      )));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(find.text('Choose a date'), 120, scrollable: find.byType(Scrollable).first);
      await t.tap(find.text('Choose a date'));
      await t.pumpAndSettle();
      expect(find.byType(CupertinoDatePicker), findsOneWidget);
      expect(find.byType(CalendarDatePicker), findsNothing);
      expect(find.text('Date of Birth'), findsOneWidget);
      await t.tap(find.text('Done'));
      await t.pumpAndSettle();
      final y = DateTime.now().year - 25;
      expect(find.text('1 Jan $y'), findsOneWidget);
      // and the time, the same way
      await t.tap(find.text('Choose a time'));
      await t.pumpAndSettle();
      expect(find.byType(CupertinoDatePicker), findsOneWidget);
      await t.tap(find.text('Done'));
      await t.pumpAndSettle();
      expect(find.text('6:00 AM'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('with no saved people: the chat fills the form', (t) async {
      t.view.physicalSize = const Size(1080, 2400);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      final svc = _FakeService()
        ..nextExtract = const Extracted(
          name: 'Asha',
          date: '2004-03-14',
          time: '06:30',
          timeStatus: 'approximate',
          place: 'Udupi',
          complete: true,
          places: [PlaceOption(name: 'Udupi, Karnataka, India', lat: 13.3409, lng: 74.7421, tz: 'Asia/Kolkata')],
        );
      await t.pumpWidget(host(JyotishScreen(
          service: svc, speaker: _QuietSpeaker(), listener: JyotishListener(_QuietRecognizer()))));
      await t.pumpAndSettle();
      expect(find.textContaining('Tell me when and where you were born'), findsOneWidget);
      expect(find.byTooltip('Upload Horoscope'), findsOneWidget);
      await t.enterText(find.byType(TextField).first, 'I was born 14 March 2004 around 6:30 am in Udupi');
      await t.tap(find.byTooltip('Send'));
      await t.pumpAndSettle();
      expect(svc.extractCalls.single.single.text, contains('14 March 2004'));
      expect(find.text('Asha'), findsWidgets); // the name field
      expect(find.text('14 Mar 2004'), findsOneWidget);
      expect(find.text('6:30 AM'), findsOneWidget);
      expect(find.text('Udupi, Karnataka, India'), findsOneWidget);
      expect(find.textContaining('Got it, Asha'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('a saved person opens on the chart tabs', (t) async {
      t.view.physicalSize = const Size(1080, 2400);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      final birth = Birth.fromJson(_fixture()['birth'])!;
      final svc = _FakeService(profileList: [SavedProfile(id: 1, name: 'Asha', birth: birth)]);
      await t.pumpWidget(host(JyotishScreen(
          service: svc, speaker: _QuietSpeaker(), listener: JyotishListener(_QuietRecognizer()))));
      await t.pumpAndSettle();
      for (final tab in ['Kundli', 'Planets', 'Dasha', 'Predictions']) {
        expect(find.text(tab), findsOneWidget);
      }
      expect(find.text('Aquarius'), findsWidgets); // the lagna chip
      await t.tap(find.text('Dasha'));
      await t.pumpAndSettle();
      expect(find.text('Running now'), findsOneWidget);
      await t.tap(find.text('Predictions'));
      await t.pumpAndSettle();
      expect(find.text('Get my reading'), findsOneWidget);
      expect(find.text('For entertainment and self-reflection only.'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
    testWidgets("Today's Horoscope: the saved profile's rashi, its reading, colour and number", (t) async {
      final sign = TodayHoroscope.byName('Gemini')!;
      TodayHoroscope.sign.value = sign;
      addTearDown(() => TodayHoroscope.sign.value = null);
      await t.pumpWidget(host(const Scaffold(body: SingleChildScrollView(child: JyotishCard(load: false)))));
      final r = TodayHoroscope.today(sign);
      expect(find.text('Gemini'), findsOneWidget);
      expect(find.text(r.outlook), findsOneWidget);
      expect(find.text(r.luckyColour), findsOneWidget);
      expect(find.text('No. ${r.luckyNumber}'), findsOneWidget);
      expect(find.bySemanticsLabel('Upload your horoscope'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('the form mic: Guruji fills the birth details as they are spoken, then casts', (t) async {
      t.view.physicalSize = const Size(1080, 2400);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      final tools = LocalToolRegistry();
      Birth? cast;
      await t.pumpWidget(host(Scaffold(
        body: JyotishOnboarding(
          service: _FakeService(),
          listener: JyotishListener(_QuietRecognizer()),
          tools: tools,
          orb: const SizedBox(key: Key('orb')),
          onCast: (b, {required save}) async {
            cast = b;
            return true;
          },
        ),
      )));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('orb')), findsOneWidget);
      expect(tools.available().map((x) => x.name), containsAll([fillBirthTool, castBirthTool]));

      Future<LocalToolResult> run(String name, Map<String, Object?> args) async {
        late LocalToolResult r;
        await t.runAsync(() async => r = await tools.run(LocalToolCall(name: name, args: args, userText: '')));
        await t.pumpAndSettle();
        return r;
      }

      // Too early to cast: says what is missing.
      var r = await run(castBirthTool, const {});
      expect(r.ok, isFalse);
      expect(cast, isNull);

      r = await run(fillBirthTool, const {'name': 'Asha', 'date': '2004-03-14'});
      expect(r.result['changed'], ['name', 'date']);
      expect(r.result['missing'], contains('place of birth'));
      expect(find.text('14 Mar 2004'), findsOneWidget);

      r = await run(fillBirthTool, const {'time': '06:30', 'place': 'Udupi'});
      expect(r.result['missing'], isEmpty);
      expect(find.text('6:30 AM'), findsOneWidget);
      expect(find.text('Udupi, Karnataka, India'), findsWidgets);

      // A bad date is refused, not guessed.
      r = await run(fillBirthTool, const {'date': '2999-01-01'});
      expect(r.result['problems'], isNotEmpty);
      expect(find.text('14 Mar 2004'), findsOneWidget);

      r = await run(castBirthTool, const {});
      expect(r.ok, isTrue);
      expect(cast?.name, 'Asha');
      expect(cast?.date, '2004-03-14');
      expect(cast?.time, '06:30');
      expect(cast?.place, 'Udupi, Karnataka, India');

      // The tools leave with the form.
      await t.pumpWidget(const SizedBox());
      expect(tools.isEmpty, isTrue);
    });
  });
}
