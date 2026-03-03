import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fog_of_world/features/map/widgets/map_controls.dart';

void main() {
  group('MapControls', () {
    testWidgets('renders recenter button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MapControls(
              onRecenter: () {},
              onToggleDebug: () {},
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.my_location), findsOneWidget);
    });

    testWidgets('calls onRecenter when recenter button is tapped',
        (tester) async {
      var recenterCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MapControls(
              onRecenter: () => recenterCalled = true,
              onToggleDebug: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.my_location));
      await tester.pump();

      expect(recenterCalled, isTrue);
    });

    testWidgets('calls onToggleDebug when debug button is tapped in debug mode',
        (tester) async {
      // kDebugMode is true during tests.
      if (!kDebugMode) return;

      var debugToggled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MapControls(
              onRecenter: () {},
              onToggleDebug: () => debugToggled = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.bug_report_outlined));
      await tester.pump();

      expect(debugToggled, isTrue);
    });

    testWidgets('shows debug button in debug mode', (tester) async {
      if (!kDebugMode) return;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MapControls(
              onRecenter: () {},
              onToggleDebug: () {},
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.bug_report_outlined), findsOneWidget);
    });

    testWidgets('does not call onToggleDebug on recenter tap', (tester) async {
      var debugToggled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MapControls(
              onRecenter: () {},
              onToggleDebug: () => debugToggled = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.my_location));
      await tester.pump();

      expect(debugToggled, isFalse);
    });
  });
}
