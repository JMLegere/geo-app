import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:fog_of_world/core/config/supabase_config.dart';
import 'package:fog_of_world/features/sync/services/supabase_persistence.dart';
import 'package:fog_of_world/features/sync/models/sync_status.dart';

// ── Infrastructure providers ──────────────────────────────────────────────────

/// Returns a [SupabasePersistence] instance when Supabase is configured,
/// or null in development (no --dart-define credentials).
final supabasePersistenceProvider = Provider<SupabasePersistence?>((ref) {
  if (SupabaseConfig.projectUrl.isEmpty) return null;
  return SupabasePersistence(Supabase.instance.client);
});

// ── SyncNotifier ─────────────────────────────────────────────────────────────

class SyncNotifier extends Notifier<SyncStatus> {
  @override
  SyncStatus build() {
    final isConnected =
        ref.watch(supabasePersistenceProvider) != null;
    return SyncStatus(
      type: isConnected ? SyncStatusType.idle : SyncStatusType.error,
      errorMessage: isConnected ? null : 'Supabase not configured',
    );
  }

  Future<void> syncNow() async {}
}

/// The primary sync provider consumed by the sync screen.
final syncProvider = NotifierProvider<SyncNotifier, SyncStatus>(
  SyncNotifier.new,
);
