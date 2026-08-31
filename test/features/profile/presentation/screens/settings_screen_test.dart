import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:earth_nova/core/domain/entities/auth_state.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/core/observability/observable_use_case_provider.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/core/persistence/shared_preferences_provider.dart';
import 'package:earth_nova/features/auth/data/repositories/mock_auth_repository.dart';
import 'package:earth_nova/features/auth/presentation/providers/auth_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/desktop_controls_provider.dart';
import 'package:earth_nova/features/profile/presentation/screens/settings_screen.dart';
import 'package:earth_nova/shared/debug/debug_mode_provider.dart';

void main() {
  group('SettingsScreen', () {
    late MockAuthRepository auth;
    late ObservabilityService obs;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      auth = MockAuthRepository();
      obs = ObservabilityService(sessionId: 'test-session');
    });

    tearDown(() => auth.dispose());

    Future<ProviderContainer> buildScreen(
      WidgetTester tester, {
      bool desktopControlsAvailable = false,
      Size? surfaceSize,
    }) async {
      if (surfaceSize != null) {
        await tester.binding.setSurfaceSize(surfaceSize);
        addTearDown(() => tester.binding.setSurfaceSize(null));
      }
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          observabilityProvider.overrideWithValue(obs),
          observableUseCaseProvider.overrideWithValue(obs),
          appObservabilityProvider.overrideWithValue(obs),
          debugModeObservabilityProvider.overrideWithValue(obs),
          sharedPreferencesProvider.overrideWithValue(prefs),
          desktopControlsAvailableProvider.overrideWithValue(
            desktopControlsAvailable,
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        ShadTheme(
          data: ShadThemeData(
            brightness: Brightness.dark,
            colorScheme: const ShadZincColorScheme.dark(),
          ),
          child: UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: SettingsScreen()),
          ),
        ),
      );
      await tester.pump();
      return container;
    }

    testWidgets('labels Developer Mode with a 44px touch target', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final container = await buildScreen(tester);

      final toggleFinder = find.byKey(const Key('debug_mode_toggle'));
      final toggle = tester.widget<ShadSwitch>(toggleFinder);
      expect(toggle.value, container.read(debugModeProvider));
      expect(toggle.label, isA<Text>());
      expect(toggle.sublabel, isA<Text>());
      expect(tester.getSize(toggleFinder).height, greaterThanOrEqualTo(44));
      final semanticsNode = tester.getSemantics(
        find.byKey(const Key('debug_mode_semantics')),
      );
      expect(semanticsNode.label, contains('Developer Mode'));
      expect(semanticsNode.label, contains('Debug controls'));
      semantics.dispose();
    });

    testWidgets('toggles Developer Mode by keyboard activation', (
      tester,
    ) async {
      final container = await buildScreen(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, isNotNull);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();

      expect(container.read(debugModeProvider), isTrue);
    });

    testWidgets('keeps the settings card within mobile bounds', (tester) async {
      await buildScreen(tester, surfaceSize: const Size(320, 480));

      final content = tester.getRect(find.byKey(const Key('settings_content')));
      expect(content.left, greaterThanOrEqualTo(16));
      expect(content.right, lessThanOrEqualTo(304));
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows the execution environment copy', (tester) async {
      await buildScreen(tester);

      expect(find.byKey(const Key('execution_environment')), findsOneWidget);
      expect(find.text('Execution Environment'), findsOneWidget);
      expect(find.text('unknown client · prod data'), findsOneWidget);
    });

    group('desktop controls', () {
      testWidgets('hides Desktop Controls when unavailable', (tester) async {
        await buildScreen(tester);

        expect(find.byKey(const Key('desktop_controls_toggle')), findsNothing);
      });

      testWidgets('shows and updates Desktop Controls when available', (
        tester,
      ) async {
        final container = await buildScreen(
          tester,
          desktopControlsAvailable: true,
        );
        await container
            .read(authProvider.notifier)
            .signInWithPhone('1234567890');
        await tester.pump();

        expect(
          find.byKey(const Key('desktop_controls_toggle')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('desktop_controls_toggle')));
        await tester.pump();

        expect(container.read(desktopControlsProvider), isTrue);
        expect(
          tester
              .getSize(find.byKey(const Key('desktop_controls_toggle')))
              .height,
          greaterThanOrEqualTo(44),
        );
      });
    });

    testWidgets('uses a Shad alert dialog and signs out after confirmation', (
      tester,
    ) async {
      final container = await buildScreen(tester);

      await tester.tap(find.byKey(const Key('sign_out_button')));
      await tester.pumpAndSettle();

      expect(find.byType(ShadDialog), findsOneWidget);
      expect(find.byKey(const Key('sign_out_dialog_cancel')), findsOneWidget);
      expect(find.byKey(const Key('sign_out_dialog_confirm')), findsOneWidget);

      await tester.tap(find.byKey(const Key('sign_out_dialog_confirm')));
      await tester.pumpAndSettle();

      expect(find.byType(ShadDialog), findsNothing);
      expect(container.read(authProvider).status, AuthStatus.unauthenticated);
    });
  });
}
