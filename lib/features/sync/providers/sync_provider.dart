import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:fog_of_world/core/state/supabase_bootstrap_provider.dart';
import 'package:fog_of_world/features/sync/services/supabase_persistence.dart';
import 'package:fog_of_world/features/sync/models/sync_status.dart';

// ── Infrastructure providers ──────────────────────────────────────────────────

/// Returns the [SupabaseClient] when Supabase is initialised, or null when
/// credentials are missing or init failed.
///
/// This is the single allowed entry point for Supabase client access outside
/// of [supabase_auth_service.dart]. Features that need the client (e.g.
/// enrichment) must import this provider rather than importing
/// `supabase_flutter` directly.
final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  if (!ref.read(supabaseBootstrapProvider).initialized) return null;
  return Supabase.instance.client;
});

/// Returns a [SupabasePersistence] instance when Supabase actually initialised,
/// or null when credentials are missing or init failed (e.g. web locale crash).
final supabasePersistenceProvider = Provider<SupabasePersistence?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return null;
  return SupabasePersistence(client);
});

// ── SyncNotifier ─────────────────────────────────────────────────────────────

class SyncNotifier extends Notifier<SyncStatus> {
  @override
  SyncStatus build() {
    final isConnected = ref.watch(supabasePersistenceProvider) != null;
    return SyncStatus(
      type: isConnected ? SyncStatusType.idle : SyncStatusType.error,
      errorMessage: isConnected ? null : 'Supabase not configured',
    );
  }

  /// Triggers a manual sync. Updates state to reflect progress and surfaces
  /// user-friendly error messages on failure without exposing raw exceptions.
  Future<void> syncNow() async {
    final persistence = ref.read(supabasePersistenceProvider);
    if (persistence == null) {
      // No credentials — surface a non-blocking message.
      state = state.copyWith(
        type: SyncStatusType.error,
        errorMessage: 'Sync unavailable: Supabase not configured.',
      );
      return;
    }

    state = state.copyWith(type: SyncStatusType.syncing, errorMessage: null);

    try {
      // Sync operations go here as features are wired up.
      // Placeholder: any SyncException from SupabasePersistence propagates here.
      state = state.copyWith(
        type: SyncStatusType.success,
        lastSyncedAt: DateTime.now(),
        errorMessage: null,
      );
    } on SyncException catch (e) {
      // SyncException always has a user-friendly message.
      debugPrint('[SyncNotifier] sync failed: $e');
      state = state.copyWith(
        type: SyncStatusType.error,
        errorMessage: e.message,
      );
    } catch (e) {
      // Unexpected error — log but never expose raw message to user.
      debugPrint('[SyncNotifier] unexpected sync error: $e');
      state = state.copyWith(
        type: SyncStatusType.error,
        errorMessage: 'Sync failed. Please check your connection and try again.',
      );
    }
  }
}

/// The primary sync provider consumed by the sync screen.
final syncProvider = NotifierProvider<SyncNotifier, SyncStatus>(
  SyncNotifier.new,
);
