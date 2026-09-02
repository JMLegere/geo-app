import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const phaseSevenCaptureEnabled = bool.fromEnvironment('PHASE7_CAPTURE');
const phaseSevenMobileSize = Size(390, 844);
const phaseSevenDesktopSize = Size(1440, 900);

const phaseSevenCaptureAssets = <String>[
  'fallback/retryable-error-390x844.png',
  'fallback/retryable-error-1440x900.png',
  'fallback/nonretryable-error-390x844.png',
  'fallback/nonretryable-error-1440x900.png',
  'fallback/coming-soon-390x844.png',
  'fallback/coming-soon-1440x900.png',
  'fallback/loading-active-390x844.png',
  'fallback/loading-active-1440x900.png',
  'fallback/loading-reduced-motion-390x844.png',
  'fallback/loading-reduced-motion-1440x900.png',
  'catalog/design-library-390x844.png',
  'catalog/design-library-1440x900.png',
];

const _assetRoot = '.agents/qa/assets/shadcn-final';
const _captureKey = ValueKey('phase-seven-capture');

Future<void> capturePhaseSevenFixture(
  WidgetTester tester, {
  required Size size,
  required String name,
  required Widget child,
  bool disableAnimations = true,
  TextScaler textScaler = TextScaler.noScaling,
  Future<void> Function(WidgetTester tester)? prepare,
}) async {
  if (!phaseSevenCaptureEnabled) {
    return;
  }

  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  try {
    await (FontLoader(
          'packages/shadcn_ui/Geist',
        )..addFont(rootBundle.load('packages/shadcn_ui/fonts/Geist[wght].ttf')))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await tester.pumpWidget(
      ShadApp.custom(
        theme: ShadThemeData(
          brightness: Brightness.dark,
          colorScheme: const ShadZincColorScheme.dark(),
        ),
        themeMode: ThemeMode.dark,
        appBuilder: (context) => MaterialApp(
          theme: Theme.of(context),
          builder: (context, appChild) => RepaintBoundary(
            key: _captureKey,
            child: ShadAppBuilder(
              child: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: textScaler,
                  disableAnimations: disableAnimations,
                ),
                child: appChild!,
              ),
            ),
          ),
          home: child,
        ),
      ),
    );
    await tester.pump();
    await prepare?.call(tester);

    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_captureKey),
    );
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      expect(image.width, size.width.toInt());
      expect(image.height, size.height.toInt());
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('$_assetRoot/$name');
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }
}
