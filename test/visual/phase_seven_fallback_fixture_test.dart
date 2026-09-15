import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/ui/design_system.dart';
import 'package:earth_nova/ui/product_surfaces/system/stub_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'phase_seven_capture_support.dart';

void main() {
  group('Phase seven fallback fixtures', () {
    test('declares the final 12-asset matrix', () {
      expect(phaseSevenCaptureAssets, hasLength(12));
      expect(
        phaseSevenCaptureAssets,
        containsAll(const [
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
        ]),
      );
    });

    testWidgets(
      'captures fallback/retryable-error-390x844.png',
      (tester) => _capture(
        tester,
        size: phaseSevenMobileSize,
        name: 'fallback/retryable-error-390x844.png',
        child: AppErrorState(
          title: 'Unable to load',
          message: 'Check your connection and try again.',
          retryLabel: 'Try again',
          onRetry: _retry,
        ),
      ),
      skip: !phaseSevenCaptureEnabled,
    );

    testWidgets(
      'captures fallback/retryable-error-1440x900.png',
      (tester) => _capture(
        tester,
        size: phaseSevenDesktopSize,
        name: 'fallback/retryable-error-1440x900.png',
        child: AppErrorState(
          title: 'Unable to load',
          message: 'Check your connection and try again.',
          retryLabel: 'Try again',
          onRetry: _retry,
        ),
      ),
      skip: !phaseSevenCaptureEnabled,
    );

    testWidgets(
      'captures fallback/nonretryable-error-390x844.png',
      (tester) => _capture(
        tester,
        size: phaseSevenMobileSize,
        name: 'fallback/nonretryable-error-390x844.png',
        child: const AppErrorState(
          title: 'Unable to continue',
          message: 'This request cannot be retried right now.',
        ),
      ),
      skip: !phaseSevenCaptureEnabled,
    );

    testWidgets(
      'captures fallback/nonretryable-error-1440x900.png',
      (tester) => _capture(
        tester,
        size: phaseSevenDesktopSize,
        name: 'fallback/nonretryable-error-1440x900.png',
        child: const AppErrorState(
          title: 'Unable to continue',
          message: 'This request cannot be retried right now.',
        ),
      ),
      skip: !phaseSevenCaptureEnabled,
    );

    testWidgets(
      'captures fallback/coming-soon-390x844.png',
      (tester) => _capture(
        tester,
        size: phaseSevenMobileSize,
        name: 'fallback/coming-soon-390x844.png',
        child: _comingSoon(),
      ),
      skip: !phaseSevenCaptureEnabled,
    );

    testWidgets(
      'captures fallback/coming-soon-1440x900.png',
      (tester) => _capture(
        tester,
        size: phaseSevenDesktopSize,
        name: 'fallback/coming-soon-1440x900.png',
        child: _comingSoon(),
      ),
      skip: !phaseSevenCaptureEnabled,
    );

    testWidgets(
      'captures fallback/loading-active-390x844.png',
      (tester) => _capture(
        tester,
        size: phaseSevenMobileSize,
        name: 'fallback/loading-active-390x844.png',
        child: const Center(child: LoadingDots()),
        disableAnimations: false,
      ),
      skip: !phaseSevenCaptureEnabled,
    );

    testWidgets(
      'captures fallback/loading-active-1440x900.png',
      (tester) => _capture(
        tester,
        size: phaseSevenDesktopSize,
        name: 'fallback/loading-active-1440x900.png',
        child: const Center(child: LoadingDots()),
        disableAnimations: false,
      ),
      skip: !phaseSevenCaptureEnabled,
    );

    testWidgets(
      'captures fallback/loading-reduced-motion-390x844.png',
      (tester) => _capture(
        tester,
        size: phaseSevenMobileSize,
        name: 'fallback/loading-reduced-motion-390x844.png',
        child: const Center(child: LoadingDots()),
      ),
      skip: !phaseSevenCaptureEnabled,
    );

    testWidgets(
      'captures fallback/loading-reduced-motion-1440x900.png',
      (tester) => _capture(
        tester,
        size: phaseSevenDesktopSize,
        name: 'fallback/loading-reduced-motion-1440x900.png',
        child: const Center(child: LoadingDots()),
      ),
      skip: !phaseSevenCaptureEnabled,
    );

    testWidgets(
      'captures catalog/design-library-390x844.png',
      (tester) => _capture(
        tester,
        size: phaseSevenMobileSize,
        name: 'catalog/design-library-390x844.png',
        child: const Scaffold(body: DesignLibraryExample()),
      ),
      skip: !phaseSevenCaptureEnabled,
    );

    testWidgets(
      'captures catalog/design-library-1440x900.png',
      (tester) => _capture(
        tester,
        size: phaseSevenDesktopSize,
        name: 'catalog/design-library-1440x900.png',
        child: const Scaffold(body: DesignLibraryExample()),
      ),
      skip: !phaseSevenCaptureEnabled,
    );
  });
}

Future<void> _capture(
  WidgetTester tester, {
  required Size size,
  required String name,
  required Widget child,
  bool disableAnimations = true,
}) {
  return capturePhaseSevenFixture(
    tester,
    size: size,
    name: name,
    child: child,
    disableAnimations: disableAnimations,
  );
}

Widget _comingSoon() {
  return ProviderScope(
    overrides: [
      appObservabilityProvider.overrideWithValue(
        ObservabilityService(sessionId: 'phase-seven-coming-soon'),
      ),
    ],
    child: const StubScreen(label: 'Field guide'),
  );
}

void _retry() {}
