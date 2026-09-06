import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:earth_nova/shared/design.dart';
import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/identification/presentation/providers/items_provider.dart';
import 'package:earth_nova/features/pack/presentation/screens/pack_screen.dart';

/// Actual screen, isolated fixtures; fallback symbols are not approved Item art.
void main() {
  testWidgets('export Pack layouts without backend access', (tester) async {
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
    for (final fixture in [
      (390.0, 1.0),
      (390.0, 2.0),
      (320.0, 1.0),
      (900.0, 1.0),
    ]) {
      tester.view.physicalSize = Size(fixture.$1, 844);
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: ProviderScope(
            overrides: [
              itemsProvider.overrideWith(_FixtureItems.new),
              appObservabilityProvider.overrideWithValue(
                ObservabilityService(sessionId: 'render-only'),
              ),
            ],
            child: ShadApp(
              theme: AppDesignTheme.dark(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(fixture.$2)),
                child: child!,
              ),
              home: const PackScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory(output).createSync(recursive: true);
        File(
          '$output/pack-${fixture.$1.toInt()}-${fixture.$2.toInt()}x.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}

class _FixtureItems extends ItemsNotifier {
  @override
  ItemsState build() => ItemsState(
    hasLoaded: true,
    items: [
      for (var i = 0; i < 48; i++)
        Item(
          id: 'fixture-$i',
          definitionId: i % 3 == 0 ? null : 'example-base',
          displayName: i % 3 == 0
              ? 'Unidentified fauna specimen'
              : 'Example animal',
          category: ItemCategory.fauna,
          acquiredAt: DateTime.utc(2026, 1, 1).add(Duration(minutes: i)),
          status: ItemStatus.active,
          identificationState: i % 3 == 0
              ? ItemIdentificationState.unidentified
              : ItemIdentificationState.identified,
          examinationState: i % 3 == 0
              ? ItemExaminationState.unexamined
              : ItemExaminationState.examined,
          taxonomicClass: i % 3 == 0 ? null : (i.isEven ? 'AVES' : 'MAMMALIA'),
        ),
    ],
  );
  @override
  Future<void> fetchItems() async {}
}
