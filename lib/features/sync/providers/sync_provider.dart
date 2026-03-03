import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:fog_of_world/features/sync/services/supabase_bootstrap.dart';
import 'package:fog_of_world/features/sync/services/supabase_persistence.dart';
import 'package:fog_of_world/features/sync/models/sync_status.dart';

// ── Infrastructure providers ──────────────────────────────────────────────────

/// Returns a [SupabasePersistence] instance when Supabase actually initialised,
/// or null when credentials are missing or init failed (e.g. web locale crash).
final supabasePersistenceProvider = Provider<SupabasePersistence?>((ref) {
  if (!supabaseInitialized) return null;
  return SupabasePersistence(Supabase.instance.client);
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
