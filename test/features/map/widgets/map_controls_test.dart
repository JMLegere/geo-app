import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/features/location/services/location_service.dart';
import 'package:earth_nova/features/map/widgets/map_controls.dart';

void main() {
  group('MapControls', () {
    testWidgets('renders recenter button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MapControls(
              onRecenter: () {},
              onToggleDebug: () {},
              onToggleZoom: () {},
              locationMode: LocationMode.keyboard,
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
              onToggleZoom: () {},
              locationMode: LocationMode.keyboard,
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
              onToggleZoom: () {},
              locationMode: LocationMode.keyboard,
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
              onToggleZoom: () {},
              locationMode: LocationMode.keyboard,
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
              onToggleZoom: () {},
              locationMode: LocationMode.keyboard,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.my_location));
      await tester.pump();

      expect(debugToggled, isFalse);
    });

    testWidgets('shows world icon by default (player zoom)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MapControls(
              onRecenter: () {},
              onToggleDebug: () {},
              onToggleZoom: () {},
              locationMode: LocationMode.keyboard,
            ),
          ),
        ),
      );
      // Default isWorldZoom=false → shows globe icon to switch TO world.
      expect(find.byIcon(Icons.public), findsOneWidget);
    });

    testWidgets('shows player icon when in world zoom', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MapControls(
              onRecenter: () {},
              onToggleDebug: () {},
              onToggleZoom: () {},
              isWorldZoom: true,
              locationMode: LocationMode.keyboard,
            ),
          ),
        ),
      );
      // isWorldZoom=true → shows person icon to switch TO player.
      expect(find.byIcon(Icons.person_pin_circle), findsOneWidget);
    });

    testWidgets('calls onToggleZoom when zoom button is tapped',
        (tester) async {
      var zoomToggled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MapControls(
              onRecenter: () {},
              onToggleDebug: () {},
              onToggleZoom: () => zoomToggled = true,
              locationMode: LocationMode.keyboard,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.public));
      await tester.pump();

      expect(zoomToggled, isTrue);
    });
  });
}
