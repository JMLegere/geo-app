import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fog_of_world/features/auth/models/auth_state.dart';
import 'package:fog_of_world/features/auth/providers/auth_provider.dart';
import 'package:fog_of_world/features/auth/screens/login_screen.dart';
import 'package:fog_of_world/features/auth/widgets/auth_button.dart';

// ---------------------------------------------------------------------------
// Stub notifiers (must be top-level — no class defs inside functions)
// ---------------------------------------------------------------------------

class _UnauthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState.unauthenticated();
}

class _ErrorNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState.error('User not found');
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('LoginScreen', () {
    testWidgets('renders phone number field', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [authProvider.overrideWith(_UnauthNotifier.new)],
        child: const MaterialApp(home: LoginScreen()),
      ));

      // One TextFormField: phone number.
      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.text('+1'), findsOneWidget);
    });

    testWidgets('renders continue button', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [authProvider.overrideWith(_UnauthNotifier.new)],
        child: const MaterialApp(home: LoginScreen()),
      ));

      expect(find.byType(AuthButton), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('does not render Create Account link', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [authProvider.overrideWith(_UnauthNotifier.new)],
        child: const MaterialApp(home: LoginScreen()),
      ));

      // Unified phone flow — no separate signup.
      expect(find.text('Create Account'), findsNothing);
    });

    testWidgets('renders Continue as Guest link', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [authProvider.overrideWith(_UnauthNotifier.new)],
        child: const MaterialApp(home: LoginScreen()),
      ));

      expect(find.text('Continue as Guest'), findsOneWidget);
    });

    testWidgets('continue button is disabled when phone field is empty',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [authProvider.overrideWith(_UnauthNotifier.new)],
        child: const MaterialApp(home: LoginScreen()),
      ));

      final button = tester.widget<AuthButton>(find.byType(AuthButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('continue button is enabled when phone has 10 digits',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [authProvider.overrideWith(_UnauthNotifier.new)],
        child: const MaterialApp(home: LoginScreen()),
      ));

      await tester.enterText(find.byType(TextFormField).first, '5551234567');
      await tester.pump();

      final button = tester.widget<AuthButton>(find.byType(AuthButton));
      expect(button.onPressed, isNotNull);
    });

    testWidgets('continue button stays disabled with fewer than 10 digits',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [authProvider.overrideWith(_UnauthNotifier.new)],
        child: const MaterialApp(home: LoginScreen()),
      ));

      await tester.enterText(find.byType(TextFormField).first, '55512');
      await tester.pump();

      final button = tester.widget<AuthButton>(find.byType(AuthButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('shows error message when auth state has an error',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [authProvider.overrideWith(_ErrorNotifier.new)],
        child: const MaterialApp(home: LoginScreen()),
      ));

      expect(find.text('User not found'), findsOneWidget);
    });
  });
}
