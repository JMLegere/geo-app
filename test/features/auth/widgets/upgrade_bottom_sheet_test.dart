import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fog_of_world/features/auth/models/auth_state.dart';
import 'package:fog_of_world/features/auth/models/user_profile.dart';
import 'package:fog_of_world/features/auth/providers/auth_provider.dart';
import 'package:fog_of_world/features/auth/widgets/upgrade_bottom_sheet.dart';

// ---------------------------------------------------------------------------
// Stub notifiers (top-level — must not be inside functions)
// ---------------------------------------------------------------------------

/// Anonymous authenticated user — the normal state when this sheet is shown.
class _AnonNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState.authenticated(
        UserProfile(
          id: 'anon-1',
          email: '',
          createdAt: DateTime(2024),
          isAnonymous: true,
        ),
      );
}

/// Auth state with an error message.
class _ErrorNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState.error('Something went wrong');
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('UpgradeBottomSheet', () {
    testWidgets('renders email, password, and display name fields',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [authProvider.overrideWith(_AnonNotifier.new)],
        child: const MaterialApp(
          home: Scaffold(body: UpgradeBottomSheet()),
        ),
      ));

      // Three TextFields: email, password, display name.
      expect(find.byType(TextField), findsNWidgets(3));
    });

    testWidgets('renders Create Account button', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [authProvider.overrideWith(_AnonNotifier.new)],
        child: const MaterialApp(
          home: Scaffold(body: UpgradeBottomSheet()),
        ),
      ));

      expect(find.text('Create Account'), findsOneWidget);
    });

    testWidgets('renders Google and Apple OAuth buttons', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [authProvider.overrideWith(_AnonNotifier.new)],
        child: const MaterialApp(
          home: Scaffold(body: UpgradeBottomSheet()),
        ),
      ));

      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Continue with Apple'), findsOneWidget);
    });

    testWidgets('Not now button is present', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [authProvider.overrideWith(_AnonNotifier.new)],
        child: const MaterialApp(
          home: Scaffold(body: UpgradeBottomSheet()),
        ),
      ));

      expect(find.text('Not now'), findsOneWidget);
    });

    testWidgets('shows error message when auth state has error',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [authProvider.overrideWith(_ErrorNotifier.new)],
        child: const MaterialApp(
          home: Scaffold(body: UpgradeBottomSheet()),
        ),
      ));

      expect(find.text('Something went wrong'), findsOneWidget);
    });
  });
}
