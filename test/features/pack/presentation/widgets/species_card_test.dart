import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/features/pack/presentation/widgets/species_card.dart';

void main() {
  group('SpeciesCard', () {
    testWidgets('identified card discloses neutral field details', (
      tester,
    ) async {
      final item = _item(
        name: 'Red Fox',
        scientificName: 'Vulpes vulpes',
        rarity: 'endangered',
        taxonomicClass: 'MAMMALIA',
        habitats: ['Forest', 'Mountain'],
        continents: ['Africa', 'Asia'],
        cellId: 'v_45_67',
      );

      await _pumpCard(tester, item, onOpenIdentificationService: (_) {});

      expect(find.text('Red Fox'), findsOneWidget);
      expect(find.text('Vulpes vulpes'), findsOneWidget);
      expect(find.text('Identified'), findsOneWidget);
      expect(find.text('EN · Endangered'), findsOneWidget);
      expect(find.text('Mammals'), findsOneWidget);
      expect(find.text('Forest, Mountain'), findsOneWidget);
      expect(find.text('Africa, Asia'), findsOneWidget);
      expect(find.text('Jan 15, 2026'), findsOneWidget);
      expect(find.text('Map exploration'), findsOneWidget);
      expect(find.text('Cell v_45_67'), findsNothing);
      expect(find.text('Open identification service'), findsNothing);
      expect(find.text('◆'), findsNothing);
      expect(find.text('🌲'), findsNothing);
      expect(find.text('🌍'), findsNothing);
    });

    testWidgets('unexamined card is a safe semantic silhouette', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final item = _item(
        name: 'Amberwing Warbler',
        scientificName: 'Setophaga aestiva',
        rarity: 'endangered',
        examinationState: ItemExaminationState.unexamined,
        identificationState: ItemIdentificationState.unidentified,
      );

      await _pumpCard(tester, item);

      expect(find.bySemanticsLabel('Unexamined fauna Item'), findsOneWidget);
      expect(find.text('Amberwing Warbler'), findsNothing);
      expect(find.text('Setophaga aestiva'), findsNothing);
      expect(find.text('EN · Endangered'), findsNothing);
      expect(
        find.text(
          'Identity and field details are unavailable until this Item has been examined.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Examine this Item before viewing its identity and field details.',
        ),
        findsNothing,
      );
      expect(find.text('Open identification service'), findsNothing);
      expect(find.text('Start identification'), findsNothing);
      expect(find.text('Hold to reveal'), findsNothing);
      semantics.dispose();
    });

    testWidgets(
      'examined unidentified card hands the exact Item to Identification',
      (tester) async {
        Item? openedItem;
        final item = _item(
          name: 'Amberwing Warbler',
          scientificName: 'Setophaga aestiva',
          examinationState: ItemExaminationState.examined,
          identificationState: ItemIdentificationState.unidentified,
        );

        await _pumpCard(
          tester,
          item,
          onOpenIdentificationService: (value) => openedItem = value,
        );

        expect(find.text('Amberwing Warbler'), findsOneWidget);
        expect(find.text('Setophaga aestiva'), findsOneWidget);
        expect(find.text('Examined'), findsOneWidget);
        expect(
          find.text(
            'Examination revealed these field details. Identification remains pending.',
          ),
          findsOneWidget,
        );
        expect(find.text('Open identification service'), findsOneWidget);
        expect(find.text('Start identification'), findsNothing);
        expect(find.text('Hold to reveal'), findsNothing);

        await tester.tap(find.byKey(const Key('open-identification-service')));
        await tester.pump();

        expect(identical(openedItem, item), isTrue);
      },
    );

    testWidgets('media fallback uses a labeled native icon', (tester) async {
      final semantics = tester.ensureSemantics();
      final item = _item(category: ItemCategory.flora);

      await _pumpCard(tester, item);

      expect(
        find.byKey(const ValueKey('species-media-fallback-test-1')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Flora media unavailable'), findsOneWidget);
      expect(find.text('Flora media unavailable'), findsOneWidget);
      expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('art and icon images define loading and fallback paths', (
      tester,
    ) async {
      final item = _item(
        artUrl: 'https://example.invalid/species-art.png',
        iconUrl: 'https://example.invalid/species-icon.png',
      );

      await _pumpCard(tester, item);

      final art = tester.widget<Image>(
        find.byKey(const ValueKey('species-art-test-1')),
      );
      expect(art.loadingBuilder, isNotNull);
      expect(art.errorBuilder, isNotNull);
    });

    testWidgets('uses a stacked layout on narrow screens', (tester) async {
      await _pumpCard(tester, _item(), size: const Size(500, 900));

      expect(
        find.byKey(const Key('species-card-mobile-layout')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('species-card-desktop-layout')),
        findsNothing,
      );
    });

    testWidgets('uses a split layout on wide screens', (tester) async {
      await _pumpCard(tester, _item(), size: const Size(1000, 900));

      expect(
        find.byKey(const Key('species-card-desktop-layout')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('species-card-mobile-layout')), findsNothing);
    });

    testWidgets('dialog opens with an autofocus close control', (tester) async {
      await _openDialog(tester, _item(name: 'Test Species'));

      expect(find.byKey(const ValueKey('species-card-test-1')), findsOneWidget);
      final close = tester.widget<IconButton>(
        find.byKey(const Key('species-card-close')),
      );
      expect(close.autofocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('species-card-test-1')), findsNothing);
    });

    testWidgets('Escape dismisses the dialog', (tester) async {
      await _openDialog(tester, _item());

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('species-card-test-1')), findsNothing);
    });

    testWidgets('the modal barrier dismisses the dialog', (tester) async {
      await _openDialog(tester, _item());

      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('species-card-test-1')), findsNothing);
    });

    testWidgets('a downward drag dismisses the dialog', (tester) async {
      await _openDialog(tester, _item());

      await tester.drag(
        find.byKey(const ValueKey('species-card-test-1')),
        const Offset(0, 400),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('species-card-test-1')), findsNothing);
    });

    test('source uses neutral design vocabulary without legacy decoration', () {
      final source = File(
        'lib/features/pack/presentation/widgets/species_card.dart',
      ).readAsStringSync();

      expect(source, contains("package:earth_nova/shared/design.dart"));
      for (final token in const [
        'AppTheme',
        'design_tokens',
        'Earth',
        'TCG',
        'LinearGradient',
        'BoxShadow',
        'glow',
        'iconography.dart',
        'iucn_status_theme',
        'Color(0x',
        '_RarityPill',
        '◆',
      ]) {
        expect(source, isNot(contains(token)), reason: 'legacy token: $token');
      }
      expect(source, isNot(contains('.emoji')));
      expect(source, isNot(contains('_categoryMediaFallback')));
      expect(source, isNot(contains("Cell \${item.acquiredInCellId}")));
    });
  });
}

Future<void> _pumpCard(
  WidgetTester tester,
  Item item, {
  Size size = const Size(800, 900),
  void Function(Item item)? onOpenIdentificationService,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ShadApp(
      home: Scaffold(
        body: SpeciesCard(
          item: item,
          onOpenIdentificationService: onOpenIdentificationService,
        ),
      ),
    ),
  );
}

Future<void> _openDialog(WidgetTester tester, Item item) async {
  tester.view.physicalSize = const Size(800, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ShadApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showSpeciesCard(context, item),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
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
  String? artUrl,
  String? iconUrl,
  ItemIdentificationState identificationState =
      ItemIdentificationState.identified,
  String? identifiedDisplayName,
  String? identifiedScientificName,
  ItemExaminationState examinationState = ItemExaminationState.examined,
}) => Item(
  id: 'test-1',
  definitionId: 'def-1',
  displayName: name,
  scientificName: scientificName,
  category: category,
  rarity: rarity,
  artUrl: artUrl,
  iconUrl: iconUrl,
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
