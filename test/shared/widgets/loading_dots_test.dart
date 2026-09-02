import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/shared/widgets/loading_dots.dart';

void main() {
  group('LoadingDots', () {
    testWidgets('uses an indeterminate 20px indicator when motion is enabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: LoadingDots())),
        ),
      );

      expect(find.bySemanticsLabel('Loading'), findsOneWidget);
      expect(find.byKey(const ValueKey('loading-dots-static')), findsNothing);
      final track = find.byKey(const ValueKey('loading-dots-track'));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(track, findsOneWidget);
      expect(
        tester.widget<DecoratedBox>(track).decoration,
        isA<BoxDecoration>()
            .having((decoration) => decoration.shape, 'shape', BoxShape.circle)
            .having((decoration) => decoration.border, 'border', isNotNull),
      );
      expect(tester.getSize(track), const Size(20, 20));
      expect(
        tester
            .widget<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator),
            )
            .value,
        isNull,
      );
      expect(
        tester.getSize(find.byType(CircularProgressIndicator)),
        const Size(20, 20),
      );
    });

    testWidgets('uses a static native cue when motion is disabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(body: Center(child: LoadingDots())),
          ),
        ),
      );

      expect(find.bySemanticsLabel('Loading'), findsOneWidget);
      expect(find.byKey(const ValueKey('loading-dots-static')), findsOneWidget);
      expect(find.byKey(const ValueKey('loading-dots-track')), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        find.descendant(
          of: find.byType(LoadingDots),
          matching: find.byType(RotationTransition),
        ),
        findsNothing,
      );
      expect(
        tester
            .widget<Icon>(find.byKey(const ValueKey('loading-dots-static')))
            .icon,
        Icons.more_horiz,
      );
    });
  });
}
