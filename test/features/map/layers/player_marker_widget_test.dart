import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fog_of_world/features/map/layers/player_marker_widget.dart';

void main() {
  group('PlayerMarkerWidget', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: PlayerMarkerWidget(),
        ),
      );
      expect(find.byType(PlayerMarkerWidget), findsOneWidget);
    });

    testWidgets('contains AnimatedBuilder for the pulse animation',
        (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: PlayerMarkerWidget(),
        ),
      );
      // The pulse ring is driven by AnimatedBuilder.
      expect(find.byType(AnimatedBuilder), findsOneWidget);
    });

    testWidgets('outer SizedBox uses size × 2.2', (tester) async {
      const markerSize = 20.0;
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: PlayerMarkerWidget(size: markerSize),
        ),
      );
      // The outermost SizedBox governs the widget footprint.
      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
      expect(sizedBox.width, closeTo(markerSize * 2.2, 0.01));
      expect(sizedBox.height, closeTo(markerSize * 2.2, 0.01));
    });

    testWidgets('respects custom size parameter', (tester) async {
      const customSize = 30.0;
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: PlayerMarkerWidget(size: customSize),
        ),
      );
      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
      expect(sizedBox.width, closeTo(customSize * 2.2, 0.01));
    });

    testWidgets('animation advances when time is pumped', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: PlayerMarkerWidget(),
        ),
      );
      // Advance the animation and verify no errors.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(PlayerMarkerWidget), findsOneWidget);
    });
  });
}
