import 'dart:math' as math;

import 'package:earth_nova/ui/product_surfaces/map/widgets/desktop_traversal_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _mapKey = ValueKey('map-child');

void main() {
  group('DesktopTraversalInput', () {
    testWidgets('moves at the cardinal rate and stops on key up', (
      tester,
    ) async {
      final moves = <(double, double)>[];
      var ended = 0;
      await tester.pumpWidget(
        _input(
          onMove: (north, east) => moves.add((north, east)),
          onMovementEnded: () => ended++,
        ),
      );
      await tester.tap(find.byKey(_mapKey));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();

      await tester.pump(const Duration(seconds: 1));
      expect(_north(moves), closeTo(100, 0.001));
      expect(_east(moves), closeTo(0, 0.001));

      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowUp);
      final moveCount = moves.length;
      await tester.pump(const Duration(seconds: 1));
      expect(moves, hasLength(moveCount));
      expect(ended, 1);
    });

    testWidgets('normalizes diagonal movement to the cardinal rate', (
      tester,
    ) async {
      final moves = <(double, double)>[];
      await tester.pumpWidget(
        _input(onMove: (north, east) => moves.add((north, east))),
      );
      await tester.tap(find.byKey(_mapKey));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      await tester.pump(const Duration(seconds: 1));

      expect(_north(moves), closeTo(100 / math.sqrt(2), 0.001));
      expect(_east(moves), closeTo(100 / math.sqrt(2), 0.001));
      expect(_distance(moves), closeTo(100, 0.001));
    });

    testWidgets('does not move while disabled or blocked', (tester) async {
      final disabledMoves = <(double, double)>[];
      await tester.pumpWidget(
        _input(
          enabled: false,
          onMove: (north, east) => disabledMoves.add((north, east)),
        ),
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump(const Duration(seconds: 1));
      expect(disabledMoves, isEmpty);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowUp);

      final blockedMoves = <(double, double)>[];
      await tester.pumpWidget(
        _input(
          blocked: true,
          onMove: (north, east) => blockedMoves.add((north, east)),
        ),
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump(const Duration(seconds: 1));
      expect(blockedMoves, isEmpty);
    });

    testWidgets('clears and flushes movement when focus leaves the map', (
      tester,
    ) async {
      final moves = <(double, double)>[];
      final textFocus = FocusNode();
      addTearDown(textFocus.dispose);
      var ended = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Expanded(
                  child: DesktopTraversalInput(
                    enabled: true,
                    blocked: false,
                    onMove: (north, east) => moves.add((north, east)),
                    onMovementEnded: () => ended++,
                    child: const SizedBox.expand(),
                  ),
                ),
                TextField(focusNode: textFocus),
              ],
            ),
          ),
        ),
      );

      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyS);
      await tester.pump(const Duration(milliseconds: 100));
      textFocus.requestFocus();
      await tester.pump();
      final moveCount = moves.length;
      await tester.pump(const Duration(seconds: 1));

      expect(moves, hasLength(moveCount));
      expect(ended, 1);
    });

    testWidgets('does not start movement while a modal blocks traversal', (
      tester,
    ) async {
      final moves = <(double, double)>[];
      await tester.pumpWidget(
        _input(
          blocked: true,
          onMove: (north, east) => moves.add((north, east)),
        ),
      );

      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyA);
      await tester.pump(const Duration(seconds: 1));

      expect(moves, isEmpty);
    });

    testWidgets('leaves native pointer interaction with the map child intact', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DesktopTraversalInput(
              enabled: true,
              blocked: false,
              onMove: (_, __) {},
              onMovementEnded: () {},
              child: GestureDetector(
                key: _mapKey,
                behavior: HitTestBehavior.opaque,
                onTap: () => taps++,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(GestureDetector));
      expect(taps, 1);
    });
  });
}

Widget _input({
  bool enabled = true,
  bool blocked = false,
  required void Function(double north, double east) onMove,
  VoidCallback? onMovementEnded,
}) {
  return MaterialApp(
    home: Scaffold(
      body: DesktopTraversalInput(
        enabled: enabled,
        blocked: blocked,
        onMove: onMove,
        onMovementEnded: onMovementEnded ?? () {},
        child: const SizedBox.expand(key: _mapKey),
      ),
    ),
  );
}

double _north(List<(double, double)> moves) =>
    moves.fold(0, (total, move) => total + move.$1);

double _east(List<(double, double)> moves) =>
    moves.fold(0, (total, move) => total + move.$2);

double _distance(List<(double, double)> moves) =>
    math.sqrt(_north(moves) * _north(moves) + _east(moves) * _east(moves));
