import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/core/observability/observable_use_case_provider.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/auth/data/repositories/mock_auth_repository.dart';
import 'package:earth_nova/features/auth/presentation/providers/auth_provider.dart';
import 'package:earth_nova/features/profile/presentation/screens/settings_screen.dart';
import 'package:earth_nova/shared/debug/debug_mode_provider.dart';

void main() {
  group('SettingsScreen debug toggle', () {
    late MockAuthRepository auth;
    late ObservabilityService obs;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      auth = MockAuthRepository();
      obs = ObservabilityService(sessionId: 'test-session');
    });

    tearDown(() => auth.dispose());

    Future<ProviderContainer> buildScreen(WidgetTester tester) async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          observabilityProvider.overrideWithValue(obs),
          observableUseCaseProvider.overrideWithValue(obs),
          appObservabilityProvider.overrideWithValue(obs),
          debugModeObservabilityProvider.overrideWithValue(obs),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pump();
      return container;
    }

    testWidgets('debug_mode_toggle is present', (tester) async {
      await buildScreen(tester);

      expect(find.byKey(const Key('debug_mode_toggle')), findsOneWidget);
    });

    testWidgets('debug_mode_toggle reflects debugModeProvider state',
        (tester) async {
      final container = await buildScreen(tester);

      final switchTile = tester.widget<SwitchListTile>(
        find.byKey(const Key('debug_mode_toggle')),
      );
      expect(switchTile.value, container.read(debugModeProvider));
    });

    testWidgets('tapping debug_mode_toggle calls toggle() on provider',
        (tester) async {
      final container = await buildScreen(tester);

      expect(container.read(debugModeProvider), false);

      await tester.tap(find.byKey(const Key('debug_mode_toggle')));
      await tester.pump();

      expect(container.read(debugModeProvider), true);
    });
  });
}
