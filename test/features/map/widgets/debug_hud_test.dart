import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fog_of_world/features/map/controllers/camera_controller.dart';
import 'package:fog_of_world/features/map/providers/map_state_provider.dart';
import 'package:fog_of_world/features/map/widgets/debug_hud.dart';

void main() {
  group('DebugHud', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DebugHud(
              mapState: MapState(isReady: true, zoom: 15.0),
              visibleCells: 0,
              visitedCells: 0,
              cameraMode: CameraMode.following,
            ),
          ),
        ),
      );
      expect(find.byType(DebugHud), findsOneWidget);
    });

    testWidgets('shows camera coordinates when available', (tester) async {
      const mapState = MapState(
        isReady: true,
        zoom: 14.5,
        cameraLat: 37.7749,
        cameraLon: -122.4194,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DebugHud(
              mapState: mapState,
              visibleCells: 42,
              visitedCells: 10,
              cameraMode: CameraMode.following,
            ),
          ),
        ),
      );

      // Camera position: lat shown to 4 decimal places.
      expect(find.textContaining('37.7749'), findsOneWidget);
      expect(find.textContaining('-122.4194'), findsOneWidget);
    });

    testWidgets('shows zoom level formatted to 1 decimal', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DebugHud(
              mapState: MapState(isReady: true, zoom: 14.5),
              visibleCells: 0,
              visitedCells: 0,
              cameraMode: CameraMode.following,
            ),
          ),
        ),
      );
      expect(find.textContaining('14.5'), findsOneWidget);
    });

    testWidgets('shows following camera mode', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DebugHud(
              mapState: MapState(isReady: true, zoom: 15.0),
              visibleCells: 0,
              visitedCells: 0,
              cameraMode: CameraMode.following,
            ),
          ),
        ),
      );
      expect(find.textContaining('following'), findsOneWidget);
    });

    testWidgets('shows free camera mode', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DebugHud(
              mapState: MapState(isReady: false, zoom: 15.0),
              visibleCells: 0,
              visitedCells: 0,
              cameraMode: CameraMode.free,
            ),
          ),
        ),
      );
      expect(find.textContaining('free'), findsOneWidget);
    });

    testWidgets('shows visible and visited cell counts', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DebugHud(
              mapState: MapState(isReady: true, zoom: 15.0),
              visibleCells: 37,
              visitedCells: 13,
              cameraMode: CameraMode.following,
            ),
          ),
        ),
      );
      expect(find.textContaining('37'), findsOneWidget);
      expect(find.textContaining('13'), findsOneWidget);
    });

    testWidgets('shows dash when camera lat/lon is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DebugHud(
              mapState: MapState(isReady: false, zoom: 15.0),
              visibleCells: 0,
              visitedCells: 0,
              cameraMode: CameraMode.following,
            ),
          ),
        ),
      );
      // When lat/lon are null, we show '—' in the cam line.
      expect(find.textContaining('—'), findsOneWidget);
    });

    testWidgets('shows ready vs waiting map state', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DebugHud(
              mapState: MapState(isReady: true, zoom: 15.0),
              visibleCells: 0,
              visitedCells: 0,
              cameraMode: CameraMode.following,
            ),
          ),
        ),
      );
      expect(find.textContaining('ready'), findsOneWidget);
    });
  });
}
