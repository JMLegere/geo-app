import 'package:earth_nova/shared/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'phase_seven_capture_support.dart';

const _accessibilityAssets = <({Size size, String name})>[
  (
    size: phaseSevenMobileSize,
    name: 'accessibility/design-library-200pct-390x844.png',
  ),
  (
    size: phaseSevenDesktopSize,
    name: 'accessibility/design-library-200pct-1440x900.png',
  ),
];

void main() {
  group('Phase seven accessibility fixtures', () {
    test('declares the 200% design-library asset contract', () {
      expect(_accessibilityAssets, const [
        (
          size: phaseSevenMobileSize,
          name: 'accessibility/design-library-200pct-390x844.png',
        ),
        (
          size: phaseSevenDesktopSize,
          name: 'accessibility/design-library-200pct-1440x900.png',
        ),
      ]);
    });

    for (final (:size, :name) in _accessibilityAssets) {
      testWidgets('captures $name', (tester) async {
        await capturePhaseSevenFixture(
          tester,
          size: size,
          name: name,
          textScaler: const TextScaler.linear(2),
          child: const Scaffold(body: DesignLibraryExample()),
        );

        expect(tester.takeException(), isNull);
      }, skip: !phaseSevenCaptureEnabled);
    }
  });
}
