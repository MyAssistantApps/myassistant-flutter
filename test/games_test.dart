// The Games Hub (client, 2026-11-01): the games play to the end without an
// error, and Maya plays tic-tac-toe properly (wins, blocks) yet can lose.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/features/games/games.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('tic-tac-toe knows a win, a draw and an open board', () {
    expect(ticWinner(['X', 'X', 'X', null, 'O', 'O', null, null, null]), 'X');
    expect(ticWinner(['X', 'O', 'X', 'X', 'O', 'O', 'O', 'X', 'X']), 'draw');
    expect(ticWinner(List.filled(9, null)), isNull);
  });

  test('Maya takes a win, blocks a loss, and takes the centre', () {
    final r = math.Random(1);
    expect(mayaMove(['O', 'O', null, 'X', 'X', null, null, null, null], r, slip: 0), 2, reason: 'win');
    expect(mayaMove(['X', 'X', null, null, 'O', null, null, null, null], r, slip: 0), 2, reason: 'block');
    expect(mayaMove(['X', null, null, null, null, null, null, null, null], r, slip: 0), 4, reason: 'centre');
  });

  testWidgets('memory pairs: every pair found ends the game', (t) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.625;
    addTearDown(t.view.reset);
    await t.pumpWidget(const MaterialApp(home: MemoryPairsScreen(seed: 7)));
    // The same deal the screen makes from seed 7.
    final deal = [for (var i = 0; i < 8; i++) ...[i, i]]..shuffle(math.Random(7));
    final tiles = find.descendant(of: find.byType(GridView), matching: find.byType(GestureDetector));
    expect(tiles, findsNWidgets(16));
    for (var v = 0; v < 8; v++) {
      final at = [for (var i = 0; i < 16; i++) if (deal[i] == v) i];
      await t.tap(tiles.at(at[0]));
      await t.pump();
      await t.tap(tiles.at(at[1]));
      await t.pump(const Duration(milliseconds: 100));
    }
    await t.pump(const Duration(seconds: 1));
    expect(find.text('All pairs found'), findsOneWidget);
    expect(find.textContaining('8 moves'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('quick maths: a round starts, scores and ends', (t) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.625;
    addTearDown(t.view.reset);
    await t.pumpWidget(const MaterialApp(home: QuickMathsScreen(seconds: 3, seed: 3)));
    await t.tap(find.text('Play again'));
    await t.pump();
    expect(find.text('correct'), findsOneWidget);
    await t.pump(const Duration(seconds: 4));
    await t.pump();
    expect(find.text('Time!'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('tic-tac-toe: a game plays to its end', (t) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.625;
    addTearDown(t.view.reset);
    await t.pumpWidget(const MaterialApp(home: TicTacToeScreen(seed: 2)));
    for (var i = 0; i < 9; i++) {
      if (find.text('New game').evaluate().isNotEmpty) break;
      final squares = find.bySemanticsLabel(RegExp(r'empty$'));
      if (squares.evaluate().isEmpty) break;
      await t.tap(squares.first);
      await t.pump(const Duration(milliseconds: 600));
    }
    expect(find.text('New game'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
