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
// Note: We avoid annotating helpers with `List<Override>` because `Override`
// may not be re-exported from flutter_riverpod in all 3.x minor versions.
// Instead, each test builds its own ProviderScope inline.
// ---------------------------------------------------------------------------

void main() {
  group('LoginScreen', () {
    testWidgets('renders email and password fields', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [authProvider.overrideWith(_UnauthNotifier.new)],
        child: const MaterialApp(home: LoginScreen()),
      ));

      // Two TextFormFields: email + password.
      expect(find.byType(TextFormField), findsNWidgets(2));
    });

    testWidgets('renders sign in button', (tester) async {
      // Use stub notifier so auth state is unauthenticated (not loading),
      // which ensures the button shows its label instead of a spinner.
      await tester.pumpWidget(ProviderScope(
        overrides: [authProvider.overrideWith(_UnauthNotifier.new)],
        child: const MaterialApp(home: LoginScreen()),
      ));

      expect(find.byType(AuthButton), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
    });

    testWidgets('renders Create Account link', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [authProvider.overrideWith(_UnauthNotifier.new)],
        child: const MaterialApp(home: LoginScreen()),
      ));

      expect(find.text('Create Account'), findsOneWidget);
    });

    testWidgets('renders Continue as Guest link', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [authProvider.overrideWith(_UnauthNotifier.new)],
        child: const MaterialApp(home: LoginScreen()),
      ));

      expect(find.text('Continue as Guest'), findsOneWidget);
    });

    testWidgets('sign in button is disabled when fields are empty',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [authProvider.overrideWith(_UnauthNotifier.new)],
        child: const MaterialApp(home: LoginScreen()),
      ));

      final button = tester.widget<AuthButton>(find.byType(AuthButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('sign in button is enabled when both fields have text',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [authProvider.overrideWith(_UnauthNotifier.new)],
        child: const MaterialApp(home: LoginScreen()),
      ));

      await tester.enterText(find.byType(TextFormField).at(0), 'a@b.com');
      await tester.pump();
      await tester.enterText(find.byType(TextFormField).at(1), 'pass');
      await tester.pump();

      final button = tester.widget<AuthButton>(find.byType(AuthButton));
      expect(button.onPressed, isNotNull);
    });

    testWidgets('shows error message when auth state has an error',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [authProvider.overrideWith(_ErrorNotifier.new)],
        child: const MaterialApp(home: LoginScreen()),
      ));

      expect(find.text('User not found'), findsOneWidget);
    });

    testWidgets('shows error message when auth state has error via override',
        (tester) async {
      // Use _ErrorNotifier to verify LoginScreen renders the error message.
      // Previous version used live MockAuthService but that auto-signs-in
      // when Supabase is not configured, leaving pending timers.
      await tester.pumpWidget(ProviderScope(
        overrides: [authProvider.overrideWith(_ErrorNotifier.new)],
        child: const MaterialApp(home: LoginScreen()),
      ));
      await tester.pump();

      expect(find.text('User not found'), findsOneWidget);
    });
  });
}
