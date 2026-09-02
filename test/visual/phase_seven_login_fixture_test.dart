import 'dart:async';

import 'package:earth_nova/core/domain/entities/user_profile.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/core/observability/observable_use_case_provider.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/auth/data/repositories/mock_auth_repository.dart';
import 'package:earth_nova/features/auth/domain/repositories/auth_repository.dart';
import 'package:earth_nova/features/auth/presentation/providers/auth_provider.dart';
import 'package:earth_nova/features/auth/presentation/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'phase_seven_capture_support.dart';

const phaseSevenLoginAssets = <String>[
  'login/idle-390x844.png',
  'login/idle-1440x900.png',
  'login/focused-valid-390x844.png',
  'login/focused-valid-1440x900.png',
  'login/invalid-390x844.png',
  'login/invalid-1440x900.png',
  'login/submitting-390x844.png',
  'login/submitting-1440x900.png',
  'login/auth-error-390x844.png',
  'login/auth-error-1440x900.png',
];

final _phoneInput = find.byKey(const Key('phone_input'));
final _continueButton = find.byKey(const Key('continue_button'));

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
  group('Phase seven login fixtures', () {
    test('declares the final 10-asset matrix', () {
      expect(phaseSevenLoginAssets, hasLength(10));
      expect(phaseSevenLoginAssets.toSet(), hasLength(10));
      expect(
        phaseSevenLoginAssets.every((asset) => asset.startsWith('login/')),
        isTrue,
      );
    });

    testWidgets('captures login/idle-390x844.png', (tester) async {
      final auth = MockAuthRepository();
      addTearDown(auth.dispose);
      await _captureLogin(
        tester,
        size: phaseSevenMobileSize,
        name: 'login/idle-390x844.png',
        repository: auth,
      );
    }, skip: !phaseSevenCaptureEnabled);

    testWidgets('captures login/idle-1440x900.png', (tester) async {
      final auth = MockAuthRepository();
      addTearDown(auth.dispose);
      await _captureLogin(
        tester,
        size: phaseSevenDesktopSize,
        name: 'login/idle-1440x900.png',
        repository: auth,
      );
    }, skip: !phaseSevenCaptureEnabled);

    testWidgets('captures login/focused-valid-390x844.png', (tester) async {
      final auth = MockAuthRepository();
      addTearDown(auth.dispose);
      await _captureLogin(
        tester,
        size: phaseSevenMobileSize,
        name: 'login/focused-valid-390x844.png',
        repository: auth,
        prepare: _prepareFocusedValid,
      );
    }, skip: !phaseSevenCaptureEnabled);

    testWidgets('captures login/focused-valid-1440x900.png', (tester) async {
      final auth = MockAuthRepository();
      addTearDown(auth.dispose);
      await _captureLogin(
        tester,
        size: phaseSevenDesktopSize,
        name: 'login/focused-valid-1440x900.png',
        repository: auth,
        prepare: _prepareFocusedValid,
      );
    }, skip: !phaseSevenCaptureEnabled);

    testWidgets('captures login/invalid-390x844.png', (tester) async {
      final auth = MockAuthRepository();
      addTearDown(auth.dispose);
      await _captureLogin(
        tester,
        size: phaseSevenMobileSize,
        name: 'login/invalid-390x844.png',
        repository: auth,
        prepare: _prepareInvalid,
      );
    }, skip: !phaseSevenCaptureEnabled);

    testWidgets('captures login/invalid-1440x900.png', (tester) async {
      final auth = MockAuthRepository();
      addTearDown(auth.dispose);
      await _captureLogin(
        tester,
        size: phaseSevenDesktopSize,
        name: 'login/invalid-1440x900.png',
        repository: auth,
        prepare: _prepareInvalid,
      );
    }, skip: !phaseSevenCaptureEnabled);

    testWidgets('captures login/submitting-390x844.png', (tester) async {
      final auth = _PendingAuthRepository();
      addTearDown(auth.dispose);
      await _captureLogin(
        tester,
        size: phaseSevenMobileSize,
        name: 'login/submitting-390x844.png',
        repository: auth,
        prepare: _prepareSubmitting,
      );
    }, skip: !phaseSevenCaptureEnabled);

    testWidgets('captures login/submitting-1440x900.png', (tester) async {
      final auth = _PendingAuthRepository();
      addTearDown(auth.dispose);
      await _captureLogin(
        tester,
        size: phaseSevenDesktopSize,
        name: 'login/submitting-1440x900.png',
        repository: auth,
        prepare: _prepareSubmitting,
      );
    }, skip: !phaseSevenCaptureEnabled);

    testWidgets('captures login/auth-error-390x844.png', (tester) async {
      final auth = _FailingAuthRepository();
      addTearDown(auth.dispose);
      await _captureLogin(
        tester,
        size: phaseSevenMobileSize,
        name: 'login/auth-error-390x844.png',
        repository: auth,
        prepare: _prepareAuthError,
      );
    }, skip: !phaseSevenCaptureEnabled);

    testWidgets('captures login/auth-error-1440x900.png', (tester) async {
      final auth = _FailingAuthRepository();
      addTearDown(auth.dispose);
      await _captureLogin(
        tester,
        size: phaseSevenDesktopSize,
        name: 'login/auth-error-1440x900.png',
        repository: auth,
        prepare: _prepareAuthError,
      );
    }, skip: !phaseSevenCaptureEnabled);
  });
}

Future<void> _captureLogin(
  WidgetTester tester, {
  required Size size,
  required String name,
  required AuthRepository repository,
  Future<void> Function(WidgetTester tester)? prepare,
}) {
  return capturePhaseSevenFixture(
    tester,
    size: size,
    name: name,
    child: _login(repository),
    prepare: (tester) async {
      await _restoreSession(tester);
      await prepare?.call(tester);
    },
  );
}

Widget _login(AuthRepository repository) {
  final observability = ObservabilityService(sessionId: 'phase-seven-login');
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(repository),
      observabilityProvider.overrideWithValue(observability),
      observableUseCaseProvider.overrideWithValue(observability),
      appObservabilityProvider.overrideWithValue(observability),
    ],
    child: const LoginScreen(),
  );
}

Future<void> _restoreSession(WidgetTester tester) async {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(LoginScreen)),
  );
  await container.read(authProvider.notifier).restoreSession();
  await tester.pump();
}

Future<void> _prepareFocusedValid(WidgetTester tester) async {
  await tester.showKeyboard(_phoneInput);
  await tester.enterText(_phoneInput, '5551234567');
  await tester.pump();
}

Future<void> _prepareInvalid(WidgetTester tester) async {
  await tester.enterText(_phoneInput, '55512');
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
}

Future<void> _prepareSubmitting(WidgetTester tester) async {
  await tester.enterText(_phoneInput, '5551234567');
  await tester.pump();
  await tester.tap(_continueButton);
  await tester.pump();
}

Future<void> _prepareAuthError(WidgetTester tester) async {
  await tester.enterText(_phoneInput, '5551234567');
  await tester.pump();
  await tester.tap(_continueButton);
  await tester.pump();
  await tester.pump();
}
