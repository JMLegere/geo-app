import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'ui596_workbench.dart';

// Explicit artifact export, not an automatically accepted golden baseline.
void main() {
  testWidgets('export real production controls for review', (tester) async {
    const output = String.fromEnvironment('UI596_RENDER_OUTPUT');
    expect(
      output,
      isNotEmpty,
      reason: 'Pass an explicit review output directory.',
    );
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final font = FontLoader('packages/shadcn_ui/Geist')
      ..addFont(rootBundle.load('packages/shadcn_ui/fonts/Geist[wght].ttf'));
    await font.load();
    final material = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await material.load();
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(key: boundaryKey, child: ui596Workbench()),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
    final boundary =
        boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = Directory(output)..createSync(recursive: true);
      File(
        '${directory.path}/foundation.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });
}
