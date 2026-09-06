import 'dart:io';
import 'dart:ui' as ui;

import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/features/pack/presentation/widgets/species_card.dart';
import 'package:earth_nova/shared/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('exports the real identified Item inspection', (tester) async {
    const output = String.fromEnvironment('UI596_RENDER_OUTPUT');
    expect(output, isNotEmpty);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await (FontLoader(
          'packages/shadcn_ui/Geist',
        )..addFont(rootBundle.load('packages/shadcn_ui/fonts/Geist[wght].ttf')))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();

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
              item: Item(
                id: 'inspection-review',
                definitionId: 'fauna:red_fox',
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
              ),
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
        boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('$output/inspection-identified-390x844.png');
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });
}
