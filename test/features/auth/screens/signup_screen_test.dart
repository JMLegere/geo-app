import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/features/auth/models/auth_state.dart';
import 'package:earth_nova/features/auth/providers/auth_provider.dart';
import 'package:earth_nova/features/auth/screens/signup_screen.dart';
import 'package:earth_nova/features/auth/widgets/auth_button.dart';

// ---------------------------------------------------------------------------
// Stub notifiers (top-level — Dart does not allow class defs inside functions)
// ---------------------------------------------------------------------------

class _UnauthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState.unauthenticated();
}

class _ErrorNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState.error('Email already registered');
}

// ---------------------------------------------------------------------------
// Tests
// Note: We inline ProviderScope in each test to avoid relying on the
// `Override` type annotation (export stability varies across Riverpod 3.x
// minor versions). Each test builds its own ProviderScope directly.
// ---------------------------------------------------------------------------

void main() {
  group('SignupScreen', () {
    testWidgets('renders email, password, and display name fields',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [authProvider.overrideWith(_UnauthNotifier.new)],
        child: const MaterialApp(home: SignupScreen()),
      ));

      // Display name + email + password = 3 TextFormFields.
      expect(find.byType(TextFormField), findsNWidgets(3));
    });

    testWidgets('renders Create Account button', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [authProvider.overrideWith(_UnauthNotifier.new)],
        child: const MaterialApp(home: SignupScreen()),
      ));

      expect(find.byType(AuthButton), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);
    });

    testWidgets('renders back-to-sign-in link', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [authProvider.overrideWith(_UnauthNotifier.new)],
        child: const MaterialApp(home: SignupScreen()),
      ));

      expect(find.text('Already have an account? Sign In'), findsOneWidget);
    });

    testWidgets('create account button is disabled when required fields empty',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [authProvider.overrideWith(_UnauthNotifier.new)],
        child: const MaterialApp(home: SignupScreen()),
      ));

      final button = tester.widget<AuthButton>(find.byType(AuthButton));
      expect(button.onPressed, isNull);
    });

    testWidgets(
        'create account button enabled when email and password filled',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [authProvider.overrideWith(_UnauthNotifier.new)],
        child: const MaterialApp(home: SignupScreen()),
      ));

      // Field 0 = display name (optional), field 1 = email, field 2 = password.
      await tester.enterText(find.byType(TextFormField).at(1), 'a@b.com');
      await tester.pump();
      await tester.enterText(find.byType(TextFormField).at(2), 'secret123');
      await tester.pump();

      final button = tester.widget<AuthButton>(find.byType(AuthButton));
      expect(button.onPressed, isNotNull);
    });

    testWidgets('shows error message when auth state has an error',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [authProvider.overrideWith(_ErrorNotifier.new)],
        child: const MaterialApp(home: SignupScreen()),
      ));

      expect(find.text('Email already registered'), findsOneWidget);
    });
  });
}
