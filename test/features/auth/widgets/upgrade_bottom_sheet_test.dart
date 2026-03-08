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
    testWidgets('renders "Add Phone Number" header', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [authProvider.overrideWith(_AnonNotifier.new)],
        child: const MaterialApp(
          home: Scaffold(body: UpgradeBottomSheet()),
        ),
      ));

      expect(find.text('Add Phone Number'), findsOneWidget);
    });

    testWidgets('renders phone number field with +1 prefix', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [authProvider.overrideWith(_AnonNotifier.new)],
        child: const MaterialApp(
          home: Scaffold(body: UpgradeBottomSheet()),
        ),
      ));

      // Single phone number TextField.
      expect(find.byType(TextField), findsOneWidget);
      // +1 prefix visible.
      expect(find.text('+1'), findsOneWidget);
    });

    testWidgets('renders Continue button', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [authProvider.overrideWith(_AnonNotifier.new)],
        child: const MaterialApp(
          home: Scaffold(body: UpgradeBottomSheet()),
        ),
      ));

      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('Continue button is disabled when phone field is empty',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [authProvider.overrideWith(_AnonNotifier.new)],
        child: const MaterialApp(
          home: Scaffold(body: UpgradeBottomSheet()),
        ),
      ));

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('Continue button enables when 10 digits entered',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [authProvider.overrideWith(_AnonNotifier.new)],
        child: const MaterialApp(
          home: Scaffold(body: UpgradeBottomSheet()),
        ),
      ));

      await tester.enterText(find.byType(TextField), '5551234567');
      await tester.pump();

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNotNull);
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

    testWidgets('does not render email, password, or OAuth buttons',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [authProvider.overrideWith(_AnonNotifier.new)],
        child: const MaterialApp(
          home: Scaffold(body: UpgradeBottomSheet()),
        ),
      ));

      expect(find.text('Create Account'), findsNothing);
      expect(find.text('Continue with Google'), findsNothing);
      expect(find.text('Continue with Apple'), findsNothing);
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
