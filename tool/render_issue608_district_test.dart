import 'dart:io';
import 'dart:ui' as ui;

import 'package:earth_nova/features/map/domain/repositories/hierarchy_repository.dart';
import 'package:earth_nova/ui/product_surfaces/map/widgets/district_footprint_map.dart';
import 'package:earth_nova/ui/product_surfaces/map/widgets/hierarchy_header.dart';
import 'package:earth_nova/ui/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('renders District boundaries and unavailable metadata', (
    tester,
  ) async {
    const output = String.fromEnvironment('ISSUE608_RENDER_OUTPUT');
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
    final polygon = DistrictBoundary.tryParseGeoJson(
      '{"type":"Polygon","coordinates":[[[-66.65,45.96],[-66.64,45.96],[-66.64,45.97],[-66.65,45.97],[-66.65,45.96]],[[-66.647,45.963],[-66.647,45.967],[-66.643,45.967],[-66.643,45.963],[-66.647,45.963]]]}',
    );
    expect(polygon, isNotNull);
    for (final size in const [Size(390, 844), Size(1440, 900)]) {
      for (final available in [true, false]) {
        tester.view.physicalSize = size;
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
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
                home: Scaffold(
                  backgroundColor: DesignPalette.base,
                  body: Column(
                    children: [
                      const HierarchyHeader(
                        scopeLevel: 'District',
                        scopeName: 'Boundary fixture',
                        scopeCode: 'fixture',
                        cellsVisited: 55,
                        cellsTotal: 0,
                        cellsTotalKnown: false,
                        progressPercent: 0,
                        rank: 0,
                        explorerCount: 1,
                      ),
                      Expanded(
                        child: DistrictFootprintMap(
                          cells: const [],
                          currentDistrictId: 'fixture',
                          visitedCellIds: const {},
                          districtBoundary: available ? polygon : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.text('55 cells explored; total unavailable'),
          findsOneWidget,
        );
        expect(find.text('0%'), findsNothing);
        expect(
          find.text('District boundary unavailable.'),
          available ? findsNothing : findsOneWidget,
        );
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            '$output/district-${available ? 'hole' : 'unavailable'}-${size.width.toInt()}x${size.height.toInt()}.png',
          );
          file.parent.createSync(recursive: true);
          file.writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    }
  });
}
