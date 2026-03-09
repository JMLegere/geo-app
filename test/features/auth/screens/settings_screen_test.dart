import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/core/species/species_service.dart';
import 'package:earth_nova/features/auth/models/auth_state.dart';
import 'package:earth_nova/features/auth/models/user_profile.dart';
import 'package:earth_nova/features/auth/providers/auth_provider.dart';
import 'package:earth_nova/features/auth/providers/upgrade_prompt_provider.dart';
import 'package:earth_nova/features/auth/screens/settings_screen.dart';
import 'package:earth_nova/features/discovery/providers/discovery_provider.dart';
import 'package:earth_nova/features/sanctuary/screens/sanctuary_screen.dart';

// ---------------------------------------------------------------------------
// Stub notifiers
// Must be top-level — Riverpod requires concrete class declarations.
// ---------------------------------------------------------------------------

final _minimalUser = UserProfile(
  id: 'user-123',
  email: '',
  createdAt: DateTime(2024),
);

final _emailUser = UserProfile(
  id: 'user-456',
  email: 'explorer@example.com',
  displayName: 'Alex Explorer',
  createdAt: DateTime(2024),
);

final _phoneUser = UserProfile(
  id: 'phone-789',
  email: '',
  phoneNumber: '+15551234567',
  displayName: 'Phone User',
  createdAt: DateTime(2024),
);

class _MinimalAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState.authenticated(_minimalUser);
}

/// Inert upgrade-prompt notifier — returns fixed state, never starts a Timer.
class _StubUpgradePromptNotifier extends UpgradePromptNotifier {
  @override
  UpgradePromptState build() => const UpgradePromptState(
        totalCollected: 0,
        supabaseInitialized: false,
      );
}

class _EmailAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState.authenticated(_emailUser);
}

class _PhoneAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState.authenticated(_phoneUser);
}

// ---------------------------------------------------------------------------
// Tests
// Note: We avoid annotating helpers with `List<Override>` because `Override`
// may not be re-exported from flutter_riverpod in all 3.x minor versions.
// Each test builds its own ProviderScope inline.
// ---------------------------------------------------------------------------

void main() {
  group('SettingsScreen', () {
    // ── Profile display ──────────────────────────────────────────────────────

    testWidgets('shows "Explorer" and "No contact info" for minimal user',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [authProvider.overrideWith(_MinimalAuthNotifier.new)],
        child: const MaterialApp(home: SettingsScreen()),
      ));
      await tester.pump();

      expect(find.text('Explorer'), findsOneWidget);
      expect(find.text('No contact info'), findsOneWidget);
    });

    testWidgets('shows display name and email for email user', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [authProvider.overrideWith(_EmailAuthNotifier.new)],
        child: const MaterialApp(home: SettingsScreen()),
      ));
      await tester.pump();

      expect(find.text('Alex Explorer'), findsOneWidget);
      expect(find.text('explorer@example.com'), findsOneWidget);
    });

    testWidgets('shows phone number for phone-auth user', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [authProvider.overrideWith(_PhoneAuthNotifier.new)],
        child: const MaterialApp(home: SettingsScreen()),
      ));
      await tester.pump();

      expect(find.text('Phone User'), findsOneWidget);
      expect(find.text('+15551234567'), findsOneWidget);
    });

    testWidgets('shows person icon avatar for user with no displayName',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [authProvider.overrideWith(_MinimalAuthNotifier.new)],
        child: const MaterialApp(home: SettingsScreen()),
      ));
      await tester.pump();

      expect(find.byIcon(Icons.person), findsOneWidget);
    });

    testWidgets('shows first letter of display name in avatar for named user',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [authProvider.overrideWith(_EmailAuthNotifier.new)],
        child: const MaterialApp(home: SettingsScreen()),
      ));
      await tester.pump();

      // First letter of 'Alex Explorer' is 'A'.
      expect(find.text('A'), findsOneWidget);
    });

    // ── Sign-out dialog ──────────────────────────────────────────────────────

    testWidgets('sign-out shows simple confirmation dialog for all users',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [authProvider.overrideWith(_MinimalAuthNotifier.new)],
        child: const MaterialApp(home: SettingsScreen()),
      ));
      await tester.pump();

      // Tap the Sign Out row.
      await tester.tap(find.text('Sign Out'));
      await tester.pumpAndSettle();

      // Simple dialog — no destructive "lose all progress" text.
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Are you sure you want to sign out?'), findsOneWidget);
      expect(find.textContaining('lose all progress'), findsNothing);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('cancel dismisses sign-out dialog without leaving screen',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [authProvider.overrideWith(_MinimalAuthNotifier.new)],
        child: const MaterialApp(home: SettingsScreen()),
      ));
      await tester.pump();

      await tester.tap(find.text('Sign Out'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    // ── App info ─────────────────────────────────────────────────────────────

    testWidgets('shows version string', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [authProvider.overrideWith(_MinimalAuthNotifier.new)],
        child: const MaterialApp(home: SettingsScreen()),
      ));
      await tester.pump();

      expect(find.textContaining('v0.1.0'), findsOneWidget);
    });

    // ── Settings title ───────────────────────────────────────────────────────

    testWidgets('shows "Settings" in AppBar title', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [authProvider.overrideWith(_MinimalAuthNotifier.new)],
        child: const MaterialApp(home: SettingsScreen()),
      ));
      await tester.pump();

      expect(find.text('Settings'), findsOneWidget);
    });
  });

  // ── SanctuaryScreen gear icon ─────────────────────────────────────────────

  group('SanctuaryScreen gear icon', () {
    testWidgets('AppBar has settings gear icon', (tester) async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(_MinimalAuthNotifier.new),
          speciesServiceProvider.overrideWith((_) => SpeciesService(const [])),
          upgradePromptProvider.overrideWith(_StubUpgradePromptNotifier.new),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SanctuaryScreen()),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.settings), findsOneWidget);
    });

    testWidgets('tapping gear icon navigates to SettingsScreen',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(_MinimalAuthNotifier.new),
          speciesServiceProvider.overrideWith((_) => SpeciesService(const [])),
          upgradePromptProvider.overrideWith(_StubUpgradePromptNotifier.new),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SanctuaryScreen()),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsOneWidget);
    });
  });
}
