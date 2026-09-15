import 'dart:async';

import 'package:earth_nova/core/domain/entities/user_profile.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/core/observability/observable_use_case_provider.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/auth/data/repositories/mock_auth_repository.dart';
import 'package:earth_nova/features/auth/domain/repositories/auth_repository.dart';
import 'package:earth_nova/features/auth/presentation/providers/auth_provider.dart';
import 'package:earth_nova/ui/product_surfaces/auth/screens/login_screen.dart';
import 'package:earth_nova/ui/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class _FailingAuthRepository extends MockAuthRepository {
  @override
  Future<UserProfile> signInWithEmail(
    String email,
    String password, {
    String? traceId,
  }) => Future<UserProfile>.error(const AuthException('Server unavailable.'));
}

class _PendingAuthRepository extends MockAuthRepository {
  @override
  Future<UserProfile> signInWithEmail(
    String email,
    String password, {
    String? traceId,
  }) => Completer<UserProfile>().future;
}

void main() {
  group('LoginScreen', () {
    late MockAuthRepository auth;
    late ObservabilityService obs;

    setUp(() {
      auth = MockAuthRepository();
      obs = ObservabilityService(sessionId: 'test-session');
    });

    tearDown(() => auth.dispose());

    Widget buildScreen({
      AuthRepository? repository,
      TextScaler textScaler = TextScaler.noScaling,
    }) {
      return ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(repository ?? auth),
          observabilityProvider.overrideWithValue(obs),
          observableUseCaseProvider.overrideWithValue(obs),
          appObservabilityProvider.overrideWithValue(obs),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: child!,
          ),
          home: ShadTheme(
            data: ShadThemeData(
              brightness: Brightness.dark,
              colorScheme: const ShadZincColorScheme.dark(),
            ),
            child: const LoginScreen(),
          ),
        ),
      );
    }

    Future<void> pumpLogin(
      WidgetTester tester, {
      AuthRepository? repository,
      TextScaler textScaler = TextScaler.noScaling,
    }) async {
      await tester.pumpWidget(
        buildScreen(repository: repository, textScaler: textScaler),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(LoginScreen)),
      );
      await container.read(authProvider.notifier).restoreSession();
      await tester.pump();
    }

    final phoneInput = find.byKey(const Key('phone_input'));
    final continueButton = find.byKey(const Key('continue_button'));

    AppButton button(WidgetTester tester) =>
        tester.widget<AppButton>(continueButton);

    ShadInput input(WidgetTester tester) =>
        tester.widget<ShadInput>(phoneInput);

    testWidgets('phone input and Continue button are disabled initially', (
      tester,
    ) async {
      await pumpLogin(tester);

      expect(phoneInput, findsOneWidget);
      expect(continueButton, findsOneWidget);
      expect(button(tester).onPressed, isNull);
      expect(input(tester).enabled, isTrue);
    });

    testWidgets('formats a phone number and enables Continue after 10 digits', (
      tester,
    ) async {
      await pumpLogin(tester);

      await tester.enterText(phoneInput, '5551234567');
      await tester.pump();

      expect(input(tester).controller!.text, '(555) 123-4567');
      expect(button(tester).onPressed, isNotNull);
    });

    testWidgets('caps input at 10 raw digits', (tester) async {
      await pumpLogin(tester);

      await tester.enterText(phoneInput, '55512345678901');
      await tester.pump();

      final rawDigits = input(
        tester,
      ).controller!.text.replaceAll(RegExp(r'[^\d]'), '');
      expect(rawDigits, hasLength(10));
    });

    testWidgets('keyboard submit announces a short phone number', (
      tester,
    ) async {
      await pumpLogin(tester);

      await tester.enterText(phoneInput, '55512');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(button(tester).onPressed, isNull);
      expect(
        find.bySemanticsLabel('error: Enter at least 10 digits.'),
        findsOneWidget,
      );
    });

    testWidgets('keyboard submit authenticates a valid phone number', (
      tester,
    ) async {
      await pumpLogin(tester);

      await tester.enterText(phoneInput, '5551234567');
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      expect(container.read(authProvider).status.name, 'authenticated');
    });

    testWidgets('input and Continue disable while submitting', (tester) async {
      final pendingAuth = _PendingAuthRepository();
      addTearDown(pendingAuth.dispose);
      await pumpLogin(tester, repository: pendingAuth);

      await tester.enterText(phoneInput, '5551234567');
      await tester.pump();
      await tester.tap(continueButton);
      await tester.pump();

      expect(button(tester).isLoading, isTrue);
      expect(button(tester).onPressed, isNull);
      expect(input(tester).enabled, isFalse);
    });

    testWidgets('server errors are announced and clear on edit', (
      tester,
    ) async {
      final failingAuth = _FailingAuthRepository();
      addTearDown(failingAuth.dispose);
      await pumpLogin(tester, repository: failingAuth);

      await tester.enterText(phoneInput, '5551234567');
      await tester.pump();
      await tester.tap(continueButton);
      await tester.pump();
      await tester.pump();

      expect(
        find.bySemanticsLabel('error: Sign-in failed. Server unavailable.'),
        findsOneWidget,
      );

      await tester.enterText(phoneInput, '555123456');
      await tester.pump();

      expect(
        find.bySemanticsLabel('error: Sign-in failed. Server unavailable.'),
        findsNothing,
      );
    });

    testWidgets('server errors wrap without clipping at 200% text', (
      tester,
    ) async {
      final failingAuth = _FailingAuthRepository();
      addTearDown(failingAuth.dispose);
      await tester.binding.setSurfaceSize(const Size(320, 480));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpLogin(
        tester,
        repository: failingAuth,
        textScaler: const TextScaler.linear(2),
      );

      await tester.enterText(phoneInput, '5551234567');
      await tester.pump();
      await tester.ensureVisible(continueButton);
      await tester.pump();
      await tester.tap(continueButton);
      await tester.pump();
      await tester.pump();

      final message = tester.widget<Text>(
        find.text('Sign-in failed. Server unavailable.'),
      );
      expect(message.maxLines, isNull);
      expect(message.overflow, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('scrolls safely in a keyboard-sized viewport', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 480));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpLogin(tester);

      await tester.showKeyboard(phoneInput);
      await tester.pump();

      expect(find.byKey(const Key('login_scroll')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
