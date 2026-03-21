import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/shared/game_icons.dart';
import 'package:earth_nova/shared/widgets/town_placeholder_screen.dart';

void main() {
  group('TownPlaceholderScreen', () {
    testWidgets('renders EmptyStateWidget with expected content', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: TownPlaceholderScreen()),
      );

      expect(find.text(GameIcons.town), findsOneWidget);
      expect(find.text('Town — Coming Soon'), findsOneWidget);
      expect(find.textContaining('Discover NPCs'), findsOneWidget);
    });

    testWidgets('has no interactive elements', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: TownPlaceholderScreen()),
      );

      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.byType(TextButton), findsNothing);
      expect(find.byType(IconButton), findsNothing);
    });
  });
}
