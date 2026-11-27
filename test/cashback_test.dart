// CASHBACK (2026-11-27): what the phone reads, shows and asks for.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/features/cashback/cashback_screen.dart';
import 'package:myassistant/features/cashback/cashback_service.dart';
import 'package:myassistant/features/home/partner_app.dart';
import 'package:myassistant/services/sign_out_cleanup.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _summary({
  int pending = 4500,
  int available = 17500,
  int paid = 20000,
  int held = 0,
  bool canWithdraw = true,
}) =>
    {
      'enabled': true,
      'balance': {
        'pendingPaise': pending,
        'confirmedPaise': available + paid + held,
        'paidPaise': paid,
        'heldPaise': held,
        'availablePaise': available,
      },
      'minPayoutPaise': 10000,
      'sharePct': 100,
      'canWithdraw': canWithdraw,
      'txns': [
        {'id': 3, 'store': 'Myntra', 'merchant': 'myntra', 'cashbackPaise': 17500, 'salePaise': 249900,
          'status': 'confirmed', 'occurredAt': DateTime(2026, 11, 20).millisecondsSinceEpoch, 'confirmedAt': 1},
        {'id': 4, 'store': 'AJIO', 'merchant': 'ajio', 'cashbackPaise': 4500, 'salePaise': 0,
          'status': 'pending', 'occurredAt': DateTime(2026, 11, 25).millisecondsSinceEpoch, 'confirmedAt': 0},
        {'id': 5, 'store': 'Nykaa', 'merchant': 'nykaa', 'cashbackPaise': 3000, 'salePaise': 60000,
          'status': 'rejected', 'occurredAt': DateTime(2026, 11, 10).millisecondsSinceEpoch, 'confirmedAt': 0},
      ],
      'payouts': [
        {'id': 1, 'amountPaise': 20000, 'upiId': 'as••••@okaxis', 'status': 'paid', 'note': '',
          'requestedAt': DateTime(2026, 11, 1).millisecondsSinceEpoch, 'decidedAt': 2},
      ],
      'stores': [
        {'id': 'myntra', 'name': 'Myntra', 'category': 'Fashion', 'color': '#FF3F6C', 'rateText': 'Up to 6%'},
        {'id': 'flipkart', 'name': 'Flipkart', 'category': 'Shopping', 'color': '#2874F0', 'rateText': ''},
      ],
    };

CashbackService _service(Map<String, dynamic>? Function() summary,
    {Map<String, dynamic>? Function(Object body)? onSend, List<Object>? sent}) {
  final s = CashbackService();
  s.getJson = (path) async {
    expect(path, '/cashback');
    return summary();
  };
  s.send = (path, body) async {
    expect(path, '/cashback/payouts');
    sent?.add(body);
    return onSend == null ? {'payout': {'id': 9}} : onSend(body);
  };
  return s;
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1080, 5200);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: child));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  group('money and UPI', () {
    test('rupees the Indian way, paise only when there are any', () {
      expect(CashbackService.inr(0), '₹0');
      expect(CashbackService.inr(4500), '₹45');
      expect(CashbackService.inr(129950), '₹1,299.50');
      expect(CashbackService.inr(10000000), '₹1,00,000');
      expect(CashbackService.inr(1234567805), '₹1,23,45,678.05');
      expect(CashbackService.inr(-250), '-₹2.50');
    });

    test('a UPI ID has a name, an @ and a bank', () {
      for (final ok in ['asha.k@okaxis', 'ravi-9@ybl', '9845012345@upi', '  name@bank  ']) {
        expect(CashbackService.validUpi(ok), isTrue, reason: ok);
      }
      for (final bad in ['', 'asha', 'asha@', '@okaxis', 'a@b', 'asha k@okaxis', 'asha@ok axis', 'asha@9bank', 'asha@@okaxis']) {
        expect(CashbackService.validUpi(bad), isFalse, reason: bad);
      }
    });
  });

  group('what the server sends', () {
    test('switched off, or an older server: nothing to show', () {
      expect(CashbackSummary.fromJson({'enabled': false}).enabled, isFalse);
      expect(CashbackSummary.fromJson({}).enabled, isFalse);
      expect(CashbackSummary.fromJson({'error': 'not found'}).enabled, isFalse);
    });

    test('a full summary', () {
      final s = CashbackSummary.fromJson(_summary());
      expect(s.enabled, isTrue);
      expect([s.pendingPaise, s.availablePaise, s.paidPaise, s.heldPaise, s.minPayoutPaise],
          [4500, 17500, 20000, 0, 10000]);
      expect(s.canWithdraw, isTrue);
      expect(s.txns.map((t) => t.status),
          [CashbackStatus.confirmed, CashbackStatus.pending, CashbackStatus.rejected]);
      expect(s.txns.first.occurredAt, DateTime(2026, 11, 20));
      expect(s.payouts.single.upiId, 'as••••@okaxis');
      expect(s.stores.first.rateText, 'Up to 6%');
    });

    test('missing and malformed fields do not break the screen', () {
      final s = CashbackSummary.fromJson({
        'enabled': true,
        'balance': 'nonsense',
        'txns': [
          null,
          'x',
          {'id': 1},
          {'id': '7', 'cashbackPaise': 1250.0, 'status': 'something new'},
        ],
        'payouts': {'not': 'a list'},
        'stores': [{'name': 'no id'}, {'id': 'croma'}],
      });
      expect(s.enabled, isTrue);
      expect(s.availablePaise, 0);
      expect(s.canWithdraw, isFalse);
      expect(s.txns.single.id, 7);
      expect(s.txns.single.cashbackPaise, 1250);
      expect(s.txns.single.status, CashbackStatus.pending, reason: 'an unknown state is shown as pending');
      expect(s.txns.single.store, 'Store');
      expect(s.txns.single.occurredAt, isNull);
      expect(s.payouts, isEmpty);
      expect(s.stores.single.name, 'croma');
    });
  });

  group('asking for a withdrawal', () {
    test('a bad UPI ID is refused on the phone, before anything is sent', () async {
      final sent = <Object>[];
      final s = _service(_summary, sent: sent);
      expect(await s.withdraw('not a upi id'), contains('valid UPI ID'));
      expect(sent, isEmpty);
    });

    test('taken, refused with the server\'s words, or no connection', () async {
      final sent = <Object>[];
      expect(await _service(_summary, sent: sent).withdraw(' asha.k@okaxis '), isNull);
      expect(sent.single, {'upiId': 'asha.k@okaxis'});
      final refused = _service(_summary,
          onSend: (_) => {'error': 'A withdrawal is already being processed.', 'code': 'open', 'rejected': true});
      expect(await refused.withdraw('asha.k@okaxis'), 'A withdrawal is already being processed.');
      final offline = _service(_summary, onSend: (_) => null);
      expect(await offline.withdraw('asha.k@okaxis'), contains('check your connection'));
    });
  });

  test('a partner that earns cashback is opened through its link, never straight into its app', () {
    expect(opensInstalledAppFirst(pkg: 'com.myntra.android', cashback: true), isFalse);
    expect(opensInstalledAppFirst(pkg: 'com.myntra.android', cashback: false), isTrue);
    expect(opensInstalledAppFirst(pkg: null, cashback: false), isFalse);
    expect(opensInstalledAppFirst(pkg: '', cashback: false), isFalse);
  });

  group('the Cashback screen', () {
    testWidgets('shows the balance, the stores and every purchase and withdrawal', (tester) async {
      final opened = <String>[];
      await _pump(tester, CashbackScreen(
        service: _service(_summary),
        openStore: (id) async {
          opened.add(id);
          return true;
        },
      ));
      expect(tester.takeException(), isNull);
      expect(find.text('₹175'), findsWidgets, reason: 'available');
      expect(find.text('₹45'), findsWidgets, reason: 'pending');
      expect(find.text('₹200'), findsWidgets, reason: 'paid');
      expect(find.text('Up to 6% cashback'), findsOneWidget);
      expect(find.text('Confirmed'), findsOneWidget);
      expect(find.text('Pending'), findsWidgets);
      expect(find.text('Cancelled'), findsOneWidget);
      expect(find.text('Withdrawal to as••••@okaxis'), findsOneWidget);
      expect(find.text('Paid'), findsWidgets);
      // Our commission and the network are never on the user's screen.
      expect(find.textContaining('commission a store pays'), findsOneWidget);
      expect(find.textContaining('cuelinks'), findsNothing);

      await tester.tap(find.text('Flipkart'));
      await tester.pump();
      expect(opened, ['flipkart']);
    });

    testWidgets('a withdrawal: the UPI ID is checked, sent once, and the screen reloads', (tester) async {
      final sent = <Object>[];
      var loads = 0;
      final service = _service(() {
        loads++;
        return loads == 1 ? _summary() : _summary(available: 0, held: 17500, canWithdraw: false);
      }, sent: sent);
      await _pump(tester, CashbackScreen(service: service));
      await tester.tap(find.widgetWithText(FilledButton, 'Withdraw to UPI'));
      await tester.pumpAndSettle();
      expect(find.text('Withdraw ₹175'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'wrong');
      await tester.tap(find.text('Request Withdrawal'));
      await tester.pump();
      expect(find.textContaining('valid UPI ID'), findsOneWidget);
      expect(sent, isEmpty);

      await tester.enterText(find.byType(TextField), 'asha.k@okaxis');
      await tester.tap(find.text('Request Withdrawal'));
      await tester.pumpAndSettle();
      expect(sent, [{'upiId': 'asha.k@okaxis'}]);
      expect(find.text('Withdraw ₹175'), findsNothing, reason: 'the sheet closed');
      expect(loads, 2);
      expect(find.textContaining('A withdrawal of ₹175 is being processed'), findsOneWidget);
      final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Withdraw to UPI'));
      expect(button.onPressed, isNull, reason: 'the same money cannot be asked for twice');
      await tester.pump(const Duration(seconds: 6)); // let the toast leave
    });

    testWidgets('a refusal from the server is shown in the sheet, in its own words', (tester) async {
      final service = _service(_summary,
          onSend: (_) => {'error': 'Please verify your phone number before withdrawing cashback.', 'rejected': true});
      await _pump(tester, CashbackScreen(service: service));
      await tester.tap(find.widgetWithText(FilledButton, 'Withdraw to UPI'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'asha.k@okaxis');
      await tester.tap(find.text('Request Withdrawal'));
      await tester.pumpAndSettle();
      expect(find.text('Please verify your phone number before withdrawing cashback.'), findsOneWidget);
      expect(find.text('Withdraw ₹175'), findsOneWidget, reason: 'the sheet stays open');
    });

    testWidgets('below the minimum the button waits, and says what it waits for', (tester) async {
      await _pump(tester, CashbackScreen(service: _service(() => _summary(available: 8000, canWithdraw: false))));
      final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Withdraw to UPI'));
      expect(button.onPressed, isNull);
      expect(find.textContaining('reaches ₹100'), findsOneWidget);
    });

    testWidgets('switched off on the server: a plain note; unreachable: a way to retry', (tester) async {
      await _pump(tester, CashbackScreen(service: _service(() => {'enabled': false})));
      expect(find.text('Cashback Is Not Available Yet'), findsOneWidget);
      expect(find.text('Withdraw to UPI'), findsNothing);

      var fail = true;
      await _pump(tester, CashbackScreen(key: UniqueKey(), service: _service(() => fail ? null : _summary())));
      expect(find.text('Unable to Load Your Cashback'), findsOneWidget);
      fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('₹175'), findsWidgets);
    });
  });

  testWidgets('the banner on Everyday Services shows what has been earned', (tester) async {
    var opened = 0;
    final service = _service(_summary);
    await _pump(tester, Scaffold(body: CashbackBanner(service: service, onOpen: () => opened++)));
    expect(find.text('₹175 available · ₹45 pending'), findsOneWidget);
    await tester.tap(find.text('Cashback'));
    expect(opened, 1);
  });

  test('signing out forgets the cashback read for this account', () async {
    SharedPreferences.setMockInitialValues({});
    CashbackService.instance.summary.value = CashbackSummary.fromJson(_summary());
    await SignOutCleanup.run();
    expect(CashbackService.instance.summary.value, isNull);
  });
}
