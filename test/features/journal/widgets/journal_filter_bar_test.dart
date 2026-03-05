import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fog_of_world/features/journal/providers/journal_provider.dart';
import 'package:fog_of_world/features/journal/widgets/journal_filter_bar.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Future<void> _pumpBar(
  WidgetTester tester, {
  CollectionFilter collectionFilter = CollectionFilter.all,
  HabitatFilter habitatFilter = HabitatFilter.all,
  RarityFilter rarityFilter = RarityFilter.all,
  ValueChanged<CollectionFilter>? onCollectionFilterChanged,
  ValueChanged<HabitatFilter>? onHabitatFilterChanged,
  ValueChanged<RarityFilter>? onRarityFilterChanged,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: JournalFilterBar(
          collectionFilter: collectionFilter,
          habitatFilter: habitatFilter,
          rarityFilter: rarityFilter,
          onCollectionFilterChanged: onCollectionFilterChanged ?? (_) {},
          onHabitatFilterChanged: onHabitatFilterChanged ?? (_) {},
          onRarityFilterChanged: onRarityFilterChanged ?? (_) {},
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('JournalFilterBar', () {
    testWidgets('renders without error', (tester) async {
      await _pumpBar(tester);
      expect(find.byType(JournalFilterBar), findsOneWidget);
    });

    testWidgets('renders collection filter chips', (tester) async {
      await _pumpBar(tester);

      expect(find.text('All'), findsWidgets);
      expect(find.text('Collected'), findsOneWidget);
      expect(find.text('Undiscovered'), findsOneWidget);
    });

    testWidgets('renders all habitat filter chips', (tester) async {
      await _pumpBar(tester);

      expect(find.text('Forest'), findsOneWidget);
      expect(find.text('Plains'), findsOneWidget);
      expect(find.text('Freshwater'), findsOneWidget);
      expect(find.text('Saltwater'), findsOneWidget);
      expect(find.text('Swamp'), findsOneWidget);
      expect(find.text('Mountain'), findsOneWidget);
      expect(find.text('Desert'), findsOneWidget);
    });

    testWidgets('renders all rarity filter chips', (tester) async {
      await _pumpBar(tester);

      expect(find.text('LC'), findsOneWidget);
      expect(find.text('NT'), findsOneWidget);
      expect(find.text('VU'), findsOneWidget);
      expect(find.text('EN'), findsOneWidget);
      expect(find.text('CR'), findsOneWidget);
      expect(find.text('EX'), findsOneWidget);
    });

    testWidgets('tapping Collected chip calls onCollectionFilterChanged',
        (tester) async {
      CollectionFilter? captured;
      await _pumpBar(
        tester,
        onCollectionFilterChanged: (f) => captured = f,
      );

      await tester.tap(find.text('Collected'));
      await tester.pump();

      expect(captured, equals(CollectionFilter.collected));
    });

    testWidgets('tapping Undiscovered chip calls onCollectionFilterChanged',
        (tester) async {
      CollectionFilter? captured;
      await _pumpBar(
        tester,
        onCollectionFilterChanged: (f) => captured = f,
      );

      await tester.tap(find.text('Undiscovered'));
      await tester.pump();

      expect(captured, equals(CollectionFilter.undiscovered));
    });

    testWidgets('tapping Forest chip calls onHabitatFilterChanged',
        (tester) async {
      HabitatFilter? captured;
      await _pumpBar(
        tester,
        onHabitatFilterChanged: (f) => captured = f,
      );

      await tester.tap(find.text('Forest'));
      await tester.pump();

      expect(captured, equals(HabitatFilter.forest));
    });

    testWidgets('tapping Mountain chip calls onHabitatFilterChanged',
        (tester) async {
      HabitatFilter? captured;
      await _pumpBar(
        tester,
        onHabitatFilterChanged: (f) => captured = f,
      );

      await tester.ensureVisible(find.text('Mountain'));
      await tester.tap(find.text('Mountain'));
      await tester.pump();

      expect(captured, equals(HabitatFilter.mountain));
    });

    testWidgets('tapping EN chip calls onRarityFilterChanged', (tester) async {
      RarityFilter? captured;
      await _pumpBar(
        tester,
        onRarityFilterChanged: (f) => captured = f,
      );

      await tester.ensureVisible(find.text('EN'));
      await tester.tap(find.text('EN'));
      await tester.pump();

      expect(captured, equals(RarityFilter.endangered));
    });

    testWidgets('tapping CR chip calls onRarityFilterChanged', (tester) async {
      RarityFilter? captured;
      await _pumpBar(
        tester,
        onRarityFilterChanged: (f) => captured = f,
      );

      await tester.ensureVisible(find.text('CR'));
      await tester.tap(find.text('CR'));
      await tester.pump();

      expect(captured, equals(RarityFilter.criticallyEndangered));
    });

    testWidgets('selected collection chip is visually marked', (tester) async {
      await _pumpBar(
        tester,
        collectionFilter: CollectionFilter.collected,
      );

      // The selected FilterChip has its selected prop = true.
      final chips = tester.widgetList<FilterChip>(find.byType(FilterChip));
      final collectedChip = chips.firstWhere(
        (c) {
          final label = c.label;
          if (label is Text) {
            return label.data == 'Collected';
          }
          return false;
        },
      );
      expect(collectedChip.selected, isTrue);
    });
  });
}
