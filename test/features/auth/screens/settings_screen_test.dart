import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fog_of_world/core/species/species_service.dart';
import 'package:fog_of_world/features/auth/models/auth_state.dart';
import 'package:fog_of_world/features/auth/models/user_profile.dart';
import 'package:fog_of_world/features/auth/providers/auth_provider.dart';
import 'package:fog_of_world/features/auth/screens/settings_screen.dart';
import 'package:fog_of_world/features/discovery/providers/discovery_provider.dart';
import 'package:fog_of_world/features/sanctuary/screens/sanctuary_screen.dart';

// ---------------------------------------------------------------------------
// Stub notifiers
// Must be top-level — Riverpod requires concrete class declarations.
// ---------------------------------------------------------------------------

final _anonymousUser = UserProfile(
  id: 'anon-123',
  email: 'anon@example.com',
  createdAt: DateTime(2024),
  isAnonymous: true,
);

final _upgradedUser = UserProfile(
  id: 'user-456',
  email: 'explorer@example.com',
  displayName: 'Alex Explorer',
  createdAt: DateTime(2024),
  isAnonymous: false,
);

class _AnonAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState.authenticated(_anonymousUser);
}

class _UpgradedAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState.authenticated(_upgradedUser);
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

    testWidgets('shows "Explorer" and "Anonymous account" for anonymous user',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [authProvider.overrideWith(_AnonAuthNotifier.new)],
        child: const MaterialApp(home: SettingsScreen()),
      ));
      await tester.pump();

      expect(find.text('Explorer'), findsOneWidget);
      expect(find.text('Anonymous account'), findsOneWidget);
    });

    testWidgets('shows display name and email for upgraded user',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [authProvider.overrideWith(_UpgradedAuthNotifier.new)],
        child: const MaterialApp(home: SettingsScreen()),
      ));
      await tester.pump();

      expect(find.text('Alex Explorer'), findsOneWidget);
      expect(find.text('explorer@example.com'), findsOneWidget);
    });

    testWidgets('shows person icon avatar for anonymous user (no displayName)',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [authProvider.overrideWith(_AnonAuthNotifier.new)],
        child: const MaterialApp(home: SettingsScreen()),
      ));
      await tester.pump();

      expect(find.byIcon(Icons.person), findsOneWidget);
    });

    testWidgets('shows first letter of display name in avatar for upgraded user',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [authProvider.overrideWith(_UpgradedAuthNotifier.new)],
        child: const MaterialApp(home: SettingsScreen()),
      ));
      await tester.pump();

      // First letter of 'Alex Explorer' is 'A'.
      expect(find.text('A'), findsOneWidget);
    });

    // ── Upgrade button ───────────────────────────────────────────────────────

    testWidgets('"Upgrade your account" button visible for anonymous user',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [authProvider.overrideWith(_AnonAuthNotifier.new)],
        child: const MaterialApp(home: SettingsScreen()),
      ));
      await tester.pump();

      expect(find.text('Upgrade your account'), findsOneWidget);
    });

    testWidgets('"Upgrade your account" button hidden for upgraded user',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [authProvider.overrideWith(_UpgradedAuthNotifier.new)],
        child: const MaterialApp(home: SettingsScreen()),
      ));
      await tester.pump();

      expect(find.text('Upgrade your account'), findsNothing);
    });

    // ── Sign-out dialogs ─────────────────────────────────────────────────────

    testWidgets(
        'sign-out shows destructive warning dialog for anonymous user',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [authProvider.overrideWith(_AnonAuthNotifier.new)],
        child: const MaterialApp(home: SettingsScreen()),
      ));
      await tester.pump();

      // Tap the Sign Out row.
      await tester.tap(find.text('Sign Out'));
      await tester.pumpAndSettle();

      // Dialog shown with "lose all progress" text.
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('lose all progress'), findsOneWidget);
      expect(find.text('Sign Out Anyway'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets(
        'sign-out shows simple confirmation dialog for upgraded user',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [authProvider.overrideWith(_UpgradedAuthNotifier.new)],
        child: const MaterialApp(home: SettingsScreen()),
      ));
      await tester.pump();

      await tester.tap(find.text('Sign Out'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Are you sure you want to sign out?'), findsOneWidget);
      // No destructive "lose all progress" text for upgraded users.
      expect(find.textContaining('lose all progress'), findsNothing);
    });

    testWidgets('cancel dismisses sign-out dialog without leaving screen',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [authProvider.overrideWith(_AnonAuthNotifier.new)],
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
        overrides: [authProvider.overrideWith(_AnonAuthNotifier.new)],
        child: const MaterialApp(home: SettingsScreen()),
      ));
      await tester.pump();

      expect(find.textContaining('v0.1.0'), findsOneWidget);
    });

    // ── Settings title ───────────────────────────────────────────────────────

    testWidgets('shows "Settings" in AppBar title', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [authProvider.overrideWith(_AnonAuthNotifier.new)],
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
          authProvider.overrideWith(_AnonAuthNotifier.new),
          speciesServiceProvider.overrideWith((_) => SpeciesService(const [])),
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
          authProvider.overrideWith(_AnonAuthNotifier.new),
          speciesServiceProvider.overrideWith((_) => SpeciesService(const [])),
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
