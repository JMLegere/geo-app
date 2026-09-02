import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const phaseFiveCaptureEnabled = bool.fromEnvironment('PHASE5_CAPTURE');
const phaseFiveMobileSize = Size(390, 844);
const phaseFiveDesktopSize = Size(1440, 900);

const _assetRoot = '.agents/qa/assets/shadcn-phase-5';
const _captureKey = ValueKey('phase-five-capture');

Future<void> pumpPhaseFiveFixture(
  WidgetTester tester, {
  required Size size,
  required Widget child,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  await (FontLoader('packages/shadcn_ui/Geist')
        ..addFont(rootBundle.load('packages/shadcn_ui/fonts/Geist[wght].ttf')))
      .load();
  await (FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
      .load();
  await tester.pumpWidget(
    ShadApp.custom(
      theme: ShadThemeData(
        brightness: Brightness.dark,
        colorScheme: const ShadZincColorScheme.dark(),
      ),
      themeMode: ThemeMode.dark,
      appBuilder: (context) => MaterialApp(
        theme: Theme.of(context),
        builder: (context, child) => ShadAppBuilder(
          child: MediaQuery(
            data: MediaQueryData(size: size, disableAnimations: true),
            child: child!,
          ),
        ),
        home: RepaintBoundary(key: _captureKey, child: child),
      ),
    ),
  );
  await tester.pump();
}

Future<void> capturePhaseFiveFixture(
  WidgetTester tester, {
  required Size size,
  required String name,
  required Widget child,
}) async {
  if (!phaseFiveCaptureEnabled) {
    return;
  }

  await pumpPhaseFiveFixture(tester, size: size, child: child);
  await tester.pump();

  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_captureKey),
  );
  final image = await boundary.toImage(pixelRatio: 1);
  expect(image.width, size.width.toInt());
  expect(image.height, size.height.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();

  final file = File('$_assetRoot/$name');
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes!.buffer.asUint8List());
}
