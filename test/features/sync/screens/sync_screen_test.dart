import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fog_of_world/features/auth/models/auth_state.dart';
import 'package:fog_of_world/features/auth/models/user_profile.dart';
import 'package:fog_of_world/features/auth/providers/auth_provider.dart';
import 'package:fog_of_world/features/sync/models/sync_status.dart';
import 'package:fog_of_world/features/sync/providers/sync_provider.dart';
import 'package:fog_of_world/features/sync/screens/sync_screen.dart';

// ---------------------------------------------------------------------------
// Fake SyncNotifier — returns a fixed SyncStatus without touching service deps.
// ---------------------------------------------------------------------------

class _FakeSyncNotifier extends SyncNotifier {
  _FakeSyncNotifier(this._fixed);
  final SyncStatus _fixed;

  @override
  SyncStatus build() => _fixed;

  @override
  Future<void> syncNow() async {
    state = SyncStatus(
      type: SyncStatusType.syncing,
      lastSyncedAt: state.lastSyncedAt,
      pendingChanges: state.pendingChanges,
    );
  }

  @override
  Future<void> refreshPendingCount() async {}
}

// ---------------------------------------------------------------------------
// Fake AuthNotifier — provides a pre-set auth state with no async session check.
// ---------------------------------------------------------------------------

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this._fixed);
  final AuthState _fixed;

  @override
  AuthState build() => _fixed;
}

// ---------------------------------------------------------------------------
// Test fixtures
// ---------------------------------------------------------------------------

final _mockUser = UserProfile(
  id: 'test-user-id',
  email: 'test@example.com',
  createdAt: DateTime(2026, 1, 1),
);

// ---------------------------------------------------------------------------
// Pump helper — uses ProviderScope to avoid fake-async hanging.
// ---------------------------------------------------------------------------

/// Pumps [SyncScreen] with controlled sync and auth state via [ProviderScope].
///
/// [asGuest] → auth state is guest (button disabled, "Sign in" prompt shown).
/// Otherwise → authenticated with [_mockUser].
Future<void> _pumpScreen(
  WidgetTester tester, {
  SyncStatus? syncStatus,
  bool asGuest = false,
}) async {
  final status = syncStatus ?? const SyncStatus(type: SyncStatusType.idle);
  final auth =
      asGuest ? const AuthState.guest() : AuthState.authenticated(_mockUser);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        syncProvider.overrideWith(() => _FakeSyncNotifier(status)),
        authProvider.overrideWith(() => _FakeAuthNotifier(auth)),
      ],
      child: const MaterialApp(home: SyncScreen()),
    ),
  );
  await tester.pump();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('SyncScreen', () {
    // ── basic rendering ───────────────────────────────────────────────────────

    testWidgets('renders SyncScreen widget', (tester) async {
      await _pumpScreen(tester);
      expect(find.byType(SyncScreen), findsOneWidget);
    });

    testWidgets('shows "Cloud Sync" title in AppBar', (tester) async {
      await _pumpScreen(tester);
      expect(find.text('Cloud Sync'), findsOneWidget);
    });

    testWidgets('renders "Sync Now" button', (tester) async {
      await _pumpScreen(tester);
      expect(find.text('Sync Now'), findsOneWidget);
    });

    testWidgets('shows info text about local save', (tester) async {
      await _pumpScreen(tester);
      expect(
        find.textContaining('Your progress is saved locally'),
        findsOneWidget,
      );
    });

    // ── last synced time ──────────────────────────────────────────────────────

    testWidgets('shows "Never synced" when lastSyncedAt is null', (tester) async {
      await _pumpScreen(
        tester,
        syncStatus: const SyncStatus(type: SyncStatusType.idle),
      );
      expect(find.text('Never synced'), findsOneWidget);
    });

    testWidgets('shows last synced time when lastSyncedAt is set', (tester) async {
      final dt = DateTime.now().subtract(const Duration(minutes: 5));
      await _pumpScreen(
        tester,
        syncStatus: SyncStatus(
          type: SyncStatusType.success,
          lastSyncedAt: dt,
        ),
      );
      // Key-based finder for the last synced text.
      expect(find.byKey(const Key('last_synced_text')), findsOneWidget);
    });

    // ── pending changes count ─────────────────────────────────────────────────

    testWidgets('shows 0 pending changes by default', (tester) async {
      await _pumpScreen(tester);
      expect(
        find.byKey(const Key('pending_changes_text')),
        findsOneWidget,
      );
      expect(find.textContaining('0 pending change'), findsOneWidget);
    });

    testWidgets('shows correct pending changes count', (tester) async {
      await _pumpScreen(
        tester,
        syncStatus: const SyncStatus(
          type: SyncStatusType.idle,
          pendingChanges: 3,
        ),
      );
      expect(find.textContaining('3 pending change'), findsOneWidget);
    });

    // ── syncing state ─────────────────────────────────────────────────────────

    testWidgets('button is disabled and shows spinner while syncing',
        (tester) async {
      await _pumpScreen(
        tester,
        syncStatus: const SyncStatus(type: SyncStatusType.syncing),
      );

      // CircularProgressIndicator with Key 'sync_spinner' is present.
      expect(find.byKey(const Key('sync_spinner')), findsOneWidget);

      // The ElevatedButton should be disabled (onPressed = null).
      final button = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton).first,
      );
      expect(button.onPressed, isNull);
    });

    // ── error state ───────────────────────────────────────────────────────────

    testWidgets('shows error message when sync fails', (tester) async {
      await _pumpScreen(
        tester,
        syncStatus: const SyncStatus(
          type: SyncStatusType.error,
          errorMessage: 'Network timeout',
        ),
      );

      expect(find.byKey(const Key('error_message_text')), findsOneWidget);
      expect(find.textContaining('Network timeout'), findsOneWidget);
    });

    testWidgets('error banner shows Try Again button', (tester) async {
      await _pumpScreen(
        tester,
        syncStatus: const SyncStatus(
          type: SyncStatusType.error,
          errorMessage: 'Upload failed',
        ),
      );

      expect(find.text('Try Again'), findsOneWidget);
    });

    // ── guest user ────────────────────────────────────────────────────────────

    testWidgets('guest user sees "Sign in" prompt', (tester) async {
      await _pumpScreen(tester, asGuest: true);

      expect(find.byKey(const Key('sign_in_prompt')), findsOneWidget);
      expect(
        find.textContaining('Sign in to enable cloud sync'),
        findsOneWidget,
      );
    });

    testWidgets('Sync Now button is disabled for guest user', (tester) async {
      await _pumpScreen(tester, asGuest: true);

      final button = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton).first,
      );
      expect(button.onPressed, isNull);
    });
  });
}
