// Speak to fill (features/home/voice_booking.dart): spoken booking
// requests read into the form's fields, only what was said.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/ai/config.dart';
import 'package:myassistant/ai/listen.dart';
import 'package:myassistant/features/home/bus_search.dart' show busCities;
import 'package:myassistant/features/home/flight_search.dart' show indianAirports, worldAirports;
import 'package:myassistant/features/home/voice_booking.dart';

import 'ai/fakes.dart';

void main() {
  final now = DateTime(2026, 11, 21, 18, 45); // a Saturday
  final cities = {for (final a in [...indianAirports, ...worldAirports]) a.city};

  group('trips', () {
    VoiceTrip t(String s) => VoiceBooking.trip(s, now: now, places: cities);

    test('from, to, date, people and cabin in one go', () {
      final v = t('From Bangalore to Delhi on 5th December, 2 passengers, business class');
      expect(v.from, 'Bengaluru');
      expect(v.to, 'New Delhi');
      expect(v.date, DateTime(2026, 12, 5));
      expect(v.people, 2);
      expect(v.cabin, 'business');
    });

    test('"X to Y" without from, in number words', () {
      final v = t('mumbai to goa tomorrow for three people');
      expect(v.from, 'Mumbai');
      expect(v.to, 'Goa');
      expect(v.date, DateTime(2026, 11, 22));
      expect(v.people, 3);
    });

    test('to before from', () {
      final v = t('I want to go to Dubai from Kochi next friday');
      expect(v.from, 'Kochi');
      expect(v.to, 'Dubai');
      expect(v.date, DateTime(2026, 11, 27));
    });

    test('just one thing changes just that', () {
      final v = t('make it 4 people');
      expect(v.people, 4);
      expect(v.from, isNull);
      expect(v.to, isNull);
      expect(v.date, isNull);
      expect(v.cabin, isNull);
      expect(t('change destination to Chennai').to, 'Chennai');
      expect(t('change destination to Chennai').from, isNull);
    });

    test('dates: month first, past ones roll to next year, day after tomorrow', () {
      expect(t('december 25th').date, DateTime(2026, 12, 25));
      expect(t('on 2 jan').date, DateTime(2027, 1, 2));
      expect(t('day after tomorrow').date, DateTime(2026, 11, 23));
      expect(t('on the 28th').date, DateTime(2026, 11, 28));
      expect(t('on the 3rd').date, DateTime(2026, 12, 3));
    });

    test('just me / me and my wife', () {
      expect(t('just me').people, 1);
      expect(t('me and my wife').people, 2);
    });

    test('nothing understood', () {
      expect(t('hello there').isEmpty, isTrue);
    });

    test('bus cities', () {
      final v = VoiceBooking.trip('mysore to mangalore tomorrow', now: now, places: busCities);
      expect(v.from, 'Mysuru');
      expect(v.to, 'Mangaluru');
    });
  });

  group('stays', () {
    VoiceStay s(String x) => VoiceBooking.stay(x, now: now, places: cities);

    test('city, a date range in one month, adults and rooms', () {
      final v = s('Goa from 22 to 25 November, 2 adults, 1 room');
      expect(v.city, 'Goa');
      expect(v.checkIn, DateTime(2026, 11, 22));
      expect(v.checkOut, DateTime(2026, 11, 25));
      expect(v.adults, 2);
      expect(v.rooms, 1);
    });

    test('check in tomorrow for three nights, two rooms', () {
      final v = s('hotel in Jaipur tomorrow for three nights, four guests, two rooms');
      expect(v.city, 'Jaipur');
      expect(v.checkIn, DateTime(2026, 11, 22));
      expect(v.nights, 3);
      expect(v.adults, 4);
      expect(v.rooms, 2);
    });

    test('a place the lists do not know', () {
      expect(s('stay in Coorg this weekend').city, 'Coorg');
      expect(s('stay in Coorg this weekend').checkIn, DateTime(2026, 11, 21));
    });

    test('a bare number at the end, or "for two", is the people (as heard on the phone)', () {
      final v = s('22 to 25 November two');
      expect(v.checkIn, DateTime(2026, 11, 22));
      expect(v.checkOut, DateTime(2026, 11, 25));
      expect(v.adults, 2);
      expect(s('Goa for two').adults, 2);
      expect(s('Goa from 22 to 25').adults, isNull);
      expect(VoiceBooking.trip('Bangalore to Delhi on 5', now: now, places: cities).people, isNull);
      expect(s('Goa for 2 nights').adults, isNull);
      expect(s('check in November 2').adults, isNull);
      expect(s('check in November 2').checkIn, DateTime(2027, 11, 2));
    });

    test('only the count', () {
      final v = s('3 adults');
      expect(v.adults, 3);
      expect(v.city, isNull);
      expect(v.checkIn, isNull);
    });
  });

  group('the booking agent', () {
    test('reads the JSON inside fences or chatter', () {
      final r = AgentReply.parse('Sure!\n```json\n{"set": {"city": "Goa", "adults": 2}, "reply": "Done.", "action": null, "listen": true}\n```');
      expect(r!.set, {'city': 'Goa', 'adults': 2});
      expect(r.reply, 'Done.');
      expect(r.action, isNull);
      expect(r.listen, isTrue);
      expect(AgentReply.parse('no json here'), isNull);
    });

    test('model values are checked: dates never in the past, numbers as numbers', () {
      expect(voiceDate('2026-11-25', now: now), DateTime(2026, 11, 25));
      expect(voiceDate('2026-11-01', now: now), isNull);
      expect(voiceDate('soon', now: now), isNull);
      expect(voiceInt('3'), 3);
      expect(voiceInt(2.0), 2);
      expect(voiceText('  '), isNull);
    });

    test('the model is told the screen, today, the form and the actions', () async {
      final model = FakeModel([textChunk('{"set": {}, "reply": "Hi.", "action": null, "listen": false}')]);
      final agent = BookingAgent(_form(), port: model, now: () => now, config: () => AiConfig.defaults);
      await agent.respond('hello');
      final sys = model.requests.single.system!;
      expect(sys, contains('Hotels screen'));
      expect(sys, contains('Saturday, 2026-11-21'));
      expect(sys, contains('"city":"Goa"'));
      expect(sys, contains('"booking": open Booking.com'));
    });
  });

  group('the floating mic', () {
    testWidgets('talk: the AI fills the form and answers', (t) async {
      final applied = <Map<String, Object?>>[];
      final model = FakeModel([
        textChunk('{"set": {"city": "Goa", "checkIn": "2026-11-22", "adults": 2}, '
            '"reply": "Done, Goa from tomorrow for two.", "action": null, "listen": false}'),
      ]);
      final form = _form(applied: applied);
      await t.pumpWidget(_host(form, _ears('Goa tomorrow for two'), BookingAgent(form, port: model, now: () => now, config: () => AiConfig.defaults)));
      await t.tap(find.text('Speak to book'));
      for (var i = 0; i < 6; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(applied.single, {'city': 'Goa', 'checkIn': '2026-11-22', 'adults': 2});
      expect(find.text('Done, Goa from tomorrow for two.'), findsOneWidget);
      expect(find.text('applied'), findsOneWidget);
      await t.pump(const Duration(seconds: 9));
      await t.pump(const Duration(milliseconds: 500));
    });

    testWidgets('a conversation: it asks, listens again, then books', (t) async {
      final applied = <Map<String, Object?>>[];
      var opened = '';
      final model = FakeModel([
        textChunk('{"set": {"city": "Goa"}, "reply": "Goa it is. For how many people?", "action": null, "listen": true}'),
        textChunk('{"set": {"adults": 3}, "reply": "Opening Booking.com for three.", "action": "booking", "listen": false}'),
      ]);
      final form = _form(applied: applied, onAction: (id) => opened = id);
      await t.pumpWidget(_host(form, _ears('Goa'), BookingAgent(form, port: model, now: () => now, config: () => AiConfig.defaults)));
      await t.tap(find.text('Speak to book'));
      for (var i = 0; i < 12; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(model.requests, hasLength(2));
      expect(model.requests.last.contents, hasLength(3)); // the first turn is remembered
      expect(applied, [
        {'city': 'Goa'},
        {'adults': 3}
      ]);
      expect(opened, 'booking');
      await t.pump(const Duration(seconds: 9));
      await t.pump(const Duration(milliseconds: 500));
    });

    testWidgets('no AI: the words are read on the phone', (t) async {
      final model = FakeModel([Exception('offline')]);
      final form = _form(local: (s) => 'local: $s');
      await t.pumpWidget(_host(form, _ears('Goa'), BookingAgent(form, port: model, now: () => now, config: () => AiConfig.defaults)));
      await t.tap(find.text('Speak to book'));
      for (var i = 0; i < 6; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('local: Goa'), findsOneWidget);
      expect(find.text('FILLED IN'), findsOneWidget);
      await t.pump(const Duration(seconds: 9));
      await t.pump(const Duration(milliseconds: 500));
    });

    testWidgets('a refused microphone says so', (t) async {
      final form = _form();
      await t.pumpWidget(_host(form, VoiceListener(recognizer: _FakeEars(error: 'error_permission'), config: () => AiConfig.defaults),
          BookingAgent(form, port: FakeModel(), now: () => now, config: () => AiConfig.defaults)));
      await t.tap(find.text('Speak to book'));
      for (var i = 0; i < 4; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('TRY AGAIN'), findsOneWidget);
      expect(find.textContaining('Allow the microphone'), findsOneWidget);
      await t.pump(const Duration(seconds: 9));
      await t.pump(const Duration(milliseconds: 500));
    });
  });
}

/// A recogniser that "hears" [words] (or fails with [error]).
class _FakeEars implements RecognizerPort {
  _FakeEars({this.words = '', this.error});
  final String words;
  final String? error;
  void Function(String, bool)? _err;

  @override
  Future<bool> initialize({required void Function(String) onStatus, required void Function(String, bool) onError}) async {
    _err = onError;
    return true;
  }

  @override
  Future<List<String>> localeIds() async => ['en_IN', 'en_US'];

  @override
  Future<void> listen({
    required void Function(String words, bool isFinal) onResult,
    void Function(double level)? onLevel,
    String? localeId,
    required bool onDevice,
    required Duration listenFor,
    required Duration pauseFor,
  }) async {
    if (error != null) {
      scheduleMicrotask(() => _err?.call(error!, true));
      return;
    }
    scheduleMicrotask(() {
      onResult(words.split(' ').first, false);
      onResult(words, true);
    });
  }

  @override
  Future<void> stop() async {}
  @override
  Future<void> cancel() async {}
}

VoiceListener _ears(String words) => VoiceListener(recognizer: _FakeEars(words: words), config: () => AiConfig.defaults);

BookingForm _form({
  List<Map<String, Object?>>? applied,
  void Function(String id)? onAction,
  String Function(String said)? local,
}) =>
    BookingForm(
      screen: 'Hotels',
      example: '"Goa"',
      fields: const {'city': 'the city', 'adults': 'adults'},
      state: () => {'city': 'Goa', 'adults': 2},
      apply: (v) {
        applied?.add(v);
        return 'applied';
      },
      parseLocal: local ?? (_) => '',
      actions: {
        'booking': ('open Booking.com', () async => onAction?.call('booking')),
      },
    );

Widget _host(BookingForm form, VoiceListener ears, BookingAgent agent) => MaterialApp(
      home: Scaffold(
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: VoiceFillButton(form: form, listener: ears, agent: agent, talk: false),
      ),
    );
