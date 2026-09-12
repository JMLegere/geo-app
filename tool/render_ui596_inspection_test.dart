import 'dart:io';
import 'dart:ui' as ui;

import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/features/identification/domain/entities/item_recorded_property.dart';
import 'package:earth_nova/features/item_knowledge/domain/entities/item_knowledge_entities.dart';
import 'package:earth_nova/features/pack/presentation/widgets/species_card.dart';
import 'package:earth_nova/shared/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('exports identified recorded-property inspection states', (
    tester,
  ) async {
    const output = String.fromEnvironment('UI596_RENDER_OUTPUT');
    expect(output, isNotEmpty);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await (FontLoader(
          'packages/shadcn_ui/Geist',
        )..addFont(rootBundle.load('packages/shadcn_ui/fonts/Geist[wght].ttf')))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();

    final identified = Item(
      id: 'inspection-review',
      definitionId: 'fauna:red_fox',
      baseItemId: 'fauna:red_fox',
      baseItemVersionId: '11111111-1111-4111-8111-111111111111',
      displayName: 'Red Fox',
      scientificName: 'Vulpes vulpes',
      category: ItemCategory.fauna,
      rarity: 'least_concern',
      acquiredAt: DateTime.utc(2026, 1, 15),
      acquiredInCellId: 'review-cell',
      status: ItemStatus.active,
      taxonomicClass: 'MAMMALIA',
      habitats: const ['Forest', 'Mountain'],
      continents: const ['Europe', 'Asia'],
    );

    await _export(
      tester,
      output: output,
      name: 'inspection-identified-values-390x844.png',
      size: const Size(390, 844),
      item: identified,
      loadRecordedProperties: (_) async => [
        ItemRecordedProperty(
          ordinal: 0,
          propertyKey: 'temperament',
          propertyLabel: 'Temperament',
          resolution: SelectedPropertyValue('calm'),
          valueLabel: 'Calm',
        ),
        ItemRecordedProperty(
          ordinal: 1,
          propertyKey: 'size',
          propertyLabel: 'Size',
          resolution: const NoPropertyValue(),
        ),
      ],
    );
    await _export(
      tester,
      output: output,
      name: 'inspection-identified-empty-1000x900.png',
      size: const Size(1000, 900),
      item: identified,
      loadRecordedProperties: (_) async => [],
    );
    await _export(
      tester,
      output: output,
      name: 'inspection-identified-unavailable-1000x900.png',
      size: const Size(1000, 900),
      item: identified,
      loadRecordedProperties: (_) async => throw StateError('offline'),
    );

    var reads = 0;
    await _export(
      tester,
      output: output,
      name: 'inspection-unknown-390x844.png',
      size: const Size(390, 844),
      item: Item(
        id: 'inspection-unknown',
        displayName: 'Hidden Species Name',
        scientificName: 'Hidden scientific name',
        category: ItemCategory.fauna,
        acquiredAt: DateTime.utc(2026, 1, 15),
        status: ItemStatus.active,
        identificationState: ItemIdentificationState.unidentified,
      ),
      loadRecordedProperties: (_) async {
        reads++;
        return const [];
      },
    );
    expect(reads, 0);
    expect(find.text('Hidden Species Name'), findsNothing);
    expect(find.text('Hidden scientific name'), findsNothing);
  });
}

Future<void> _export(
  WidgetTester tester, {
  required String output,
  required String name,
  required Size size,
  required Item item,
  Future<List<ItemRecordedProperty>> Function(Item item)?
  loadRecordedProperties,
}) async {
  tester.view.physicalSize = size;
  final boundaryKey = GlobalKey();
  await tester.pumpWidget(
    RepaintBoundary(
      key: boundaryKey,
      child: ShadApp.custom(
        theme: AppDesignTheme.dark(),
        themeMode: ThemeMode.dark,
        appBuilder: (context) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: Theme.of(context).copyWith(
            textTheme: Theme.of(
              context,
            ).textTheme.apply(fontFamily: DesignTypography.family),
          ),
          builder: (context, child) => ShadAppBuilder(child: child),
          home: SpeciesCard(
            item: item,
            loadRecordedProperties: loadRecordedProperties,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final layoutException = tester.takeException();
  if (layoutException != null) {
    debugDumpRenderTree();
    fail('$layoutException');
  }
  final boundary =
      boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$output/$name');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
