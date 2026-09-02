import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/core/observability/observable_use_case_provider.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/core/persistence/shared_preferences_provider.dart';
import 'package:earth_nova/features/auth/data/repositories/mock_auth_repository.dart';
import 'package:earth_nova/features/auth/presentation/providers/auth_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/desktop_controls_provider.dart';
import 'package:earth_nova/features/profile/presentation/screens/settings_screen.dart';
import 'package:earth_nova/shared/debug/debug_mode_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'phase_seven_capture_support.dart';

const phaseSevenSettingsAssets = <String>[
  'settings/normal-390x844.png',
  'settings/normal-1440x900.png',
  'settings/sign-out-confirmation-390x844.png',
  'settings/sign-out-confirmation-1440x900.png',
];

void main() {
  group('Phase seven settings fixtures', () {
    test(
      'declares the four reachable assets; SettingsScreen has no warning surface',
      () {
        expect(phaseSevenSettingsAssets, hasLength(4));
        expect(phaseSevenSettingsAssets.toSet(), hasLength(4));
        expect(
          phaseSevenSettingsAssets,
          equals(const [
            'settings/normal-390x844.png',
            'settings/normal-1440x900.png',
            'settings/sign-out-confirmation-390x844.png',
            'settings/sign-out-confirmation-1440x900.png',
          ]),
        );
        expect(
          phaseSevenSettingsAssets.where((asset) => asset.contains('warning')),
          isEmpty,
          reason: 'SettingsScreen has no warning surface to capture.',
        );
      },
    );

    testWidgets(
      'captures settings/normal-390x844.png',
      (tester) => _captureSettings(
        tester,
        size: phaseSevenMobileSize,
        name: 'settings/normal-390x844.png',
        desktopControlsAvailable: false,
      ),
      skip: !phaseSevenCaptureEnabled,
    );

    testWidgets(
      'captures settings/normal-1440x900.png',
      (tester) => _captureSettings(
        tester,
        size: phaseSevenDesktopSize,
        name: 'settings/normal-1440x900.png',
        desktopControlsAvailable: true,
      ),
      skip: !phaseSevenCaptureEnabled,
    );

    testWidgets(
      'captures settings/sign-out-confirmation-390x844.png',
      (tester) => _captureSettings(
        tester,
        size: phaseSevenMobileSize,
        name: 'settings/sign-out-confirmation-390x844.png',
        desktopControlsAvailable: false,
        prepare: _openSignOutDialog,
      ),
      skip: !phaseSevenCaptureEnabled,
    );

    testWidgets(
      'captures settings/sign-out-confirmation-1440x900.png',
      (tester) => _captureSettings(
        tester,
        size: phaseSevenDesktopSize,
        name: 'settings/sign-out-confirmation-1440x900.png',
        desktopControlsAvailable: true,
        prepare: _openSignOutDialog,
      ),
      skip: !phaseSevenCaptureEnabled,
    );
  });
}

Future<void> _captureSettings(
  WidgetTester tester, {
  required Size size,
  required String name,
  required bool desktopControlsAvailable,
  Future<void> Function(WidgetTester tester)? prepare,
}) async {
  SharedPreferences.setMockInitialValues({});
  final auth = MockAuthRepository();
  final observability = ObservabilityService(sessionId: 'phase-seven-settings');
  final preferences = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      observabilityProvider.overrideWithValue(observability),
      observableUseCaseProvider.overrideWithValue(observability),
      appObservabilityProvider.overrideWithValue(observability),
      debugModeObservabilityProvider.overrideWithValue(observability),
      sharedPreferencesProvider.overrideWithValue(preferences),
      desktopControlsAvailableProvider.overrideWithValue(
        desktopControlsAvailable,
      ),
    ],
  );
  addTearDown(auth.dispose);
  addTearDown(container.dispose);

  await capturePhaseSevenFixture(
    tester,
    size: size,
    name: name,
    child: UncontrolledProviderScope(
      container: container,
      child: const SettingsScreen(),
    ),
    prepare: prepare,
  );
}

Future<void> _openSignOutDialog(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('sign_out_button')));
  await tester.pumpAndSettle();
  expect(find.byType(ShadDialog), findsOneWidget);
}
