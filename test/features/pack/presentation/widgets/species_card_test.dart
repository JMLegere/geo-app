import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/features/pack/presentation/widgets/species_card.dart';

void main() {
  group('SpeciesCard', () {
    testWidgets('displays species name and scientific name', (tester) async {
      final item = _item(
        name: 'Red Fox',
        scientificName: 'Vulpes vulpes',
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SpeciesCard(item: item)),
      ));

      expect(find.text('Red Fox'), findsOneWidget);
      expect(find.text('Vulpes vulpes'), findsOneWidget);
    });

    testWidgets('displays rarity badge pill with full name', (tester) async {
      final item = _item(rarity: 'endangered');

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SpeciesCard(item: item)),
      ));

      expect(find.text('EN · Endangered'), findsOneWidget);
    });

    testWidgets('displays category emoji in art overlay', (tester) async {
      final item = _item(category: ItemCategory.flora);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SpeciesCard(item: item)),
      ));

      expect(find.text('🌿'), findsAtLeast(1));
    });

    testWidgets('displays habitat emojis when present', (tester) async {
      final item = _item(habitats: ['Forest', 'Mountain']);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SpeciesCard(item: item)),
      ));

      expect(find.text('🌲'), findsOneWidget);
      expect(find.text('🏔️'), findsOneWidget);
    });

    testWidgets('displays region emojis when present', (tester) async {
      final item = _item(continents: ['Africa', 'Asia']);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SpeciesCard(item: item)),
      ));

      expect(find.text('🌍'), findsOneWidget);
      expect(find.text('🌏'), findsOneWidget);
    });

    testWidgets('displays acquired date', (tester) async {
      final item = _item();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SpeciesCard(item: item)),
      ));

      expect(find.text('Jan 15, 2026'), findsOneWidget);
    });

    testWidgets('displays taxonomic group badge for fauna', (tester) async {
      final item = _item(taxonomicClass: 'MAMMALIA');

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SpeciesCard(item: item)),
      ));

      expect(find.text('Mammals'), findsOneWidget);
    });

    testWidgets('hides habitat/region rows when empty', (tester) async {
      final item = _item();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SpeciesCard(item: item)),
      ));

      expect(find.text('🌲'), findsNothing);
      expect(find.text('🌍'), findsNothing);
    });

    testWidgets('showSpeciesCard opens dialog overlay', (tester) async {
      final item = _item(name: 'Test Species');

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showSpeciesCard(context, item),
              child: const Text('Open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Test Species'), findsOneWidget);
    });

    testWidgets('unexamined card is a semantic silhouette', (tester) async {
      final semantics = tester.ensureSemantics();
      final item = _item(
        name: 'Amberwing Warbler',
        scientificName: 'Setophaga aestiva',
        rarity: 'rare',
        examinationState: ItemExaminationState.unexamined,
        identificationState: ItemIdentificationState.unidentified,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SpeciesCard(item: item)),
      ));

      expect(
        find.bySemanticsLabel('Unexamined fauna Item'),
        findsOneWidget,
      );
      expect(find.text('Amberwing Warbler'), findsNothing);
      expect(find.text('Setophaga aestiva'), findsNothing);
      expect(find.text('Rare'), findsNothing);
      expect(find.text('Start identification'), findsNothing);
      expect(find.text('Hold to reveal'), findsNothing);
      semantics.dispose();
    });

    testWidgets(
        'examined unidentified card opens service without direct identify or reveal',
        (tester) async {
      var openServiceCount = 0;
      String? openedItemId;
      final item = _item(
        name: 'Amberwing Warbler',
        scientificName: 'Setophaga aestiva',
        rarity: 'rare',
        examinationState: ItemExaminationState.examined,
        identificationState: ItemIdentificationState.unidentified,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SpeciesCard(
            item: item,
            onOpenIdentificationService: (item) {
              openServiceCount++;
              openedItemId = item.id;
            },
          ),
        ),
      ));

      expect(find.text('Amberwing Warbler'), findsOneWidget);
      expect(find.text('Setophaga aestiva'), findsOneWidget);
      expect(find.text('Open identification service'), findsOneWidget);
      expect(find.text('Start identification'), findsNothing);
      expect(find.text('Hold to reveal'), findsNothing);

      await tester.tap(find.text('Open identification service'));
      await tester.pump();

      expect(openServiceCount, 1);
      expect(openedItemId, item.id);
    });

    testWidgets('displays cell ID when available', (tester) async {
      final item = _item(cellId: 'v_45_67');

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SpeciesCard(item: item)),
      ));

      expect(find.text('Cell v_45_67'), findsOneWidget);
    });

    testWidgets('CR shows diamond accent in rarity pill', (tester) async {
      final item = _item(rarity: 'criticallyEndangered');

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SpeciesCard(item: item)),
      ));

      expect(find.text('◆'), findsOneWidget);
      expect(find.text('CR'), findsAtLeast(1));
    });
  });
}

Item _item({
  String name = 'Test Animal',
  String? scientificName,
  String? rarity,
  ItemCategory category = ItemCategory.fauna,
  String? taxonomicClass,
  List<String> habitats = const [],
  List<String> continents = const [],
  String? cellId,
  ItemIdentificationState identificationState =
      ItemIdentificationState.identified,
  String? identifiedDisplayName,
  String? identifiedScientificName,
  ItemExaminationState examinationState = ItemExaminationState.examined,
}) =>
    Item(
      id: 'test-1',
      definitionId: 'def-1',
      displayName: name,
      scientificName: scientificName,
      category: category,
      rarity: rarity,
      acquiredAt: DateTime(2026, 1, 15),
      acquiredInCellId: cellId,
      status: ItemStatus.active,
      taxonomicClass: taxonomicClass,
      habitats: habitats,
      continents: continents,
      identificationState: identificationState,
      examinationState: examinationState,
      identifiedDisplayName: identifiedDisplayName,
      identifiedScientificName: identifiedScientificName,
    );
