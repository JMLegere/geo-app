import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Exception thrown when a Supabase sync operation fails.
///
/// Contains a user-friendly [message] (safe to display) and the underlying
/// [cause] for diagnostic logging. Raw Supabase errors are never exposed
/// directly to the caller.
class SyncException implements Exception {
  const SyncException(this.message, {this.cause});

  /// User-friendly error message. Safe to display in the UI.
  final String message;

  /// Underlying exception for diagnostic logging. Never shown to users.
  final Object? cause;

  @override
  String toString() => 'SyncException: $message (cause: $cause)';
}

class SupabasePersistence {
  SupabasePersistence(this._client);

  final SupabaseClient _client;

  // -- Profile ----------------------------------------------------------------

  Future<Map<String, dynamic>?> fetchProfile(String userId) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      return response;
    } catch (e) {
      debugPrint('[SupabasePersistence] fetchProfile failed: $e');
      throw SyncException('Failed to load profile.', cause: e);
    }
  }

  Future<void> upsertProfile({
    required String userId,
    String? displayName,
    int? currentStreak,
    int? longestStreak,
    double? totalDistanceKm,
    String? currentSeason,
  }) async {
    final data = <String, dynamic>{
      'id': userId,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (displayName != null) data['display_name'] = displayName;
    if (currentStreak != null) data['current_streak'] = currentStreak;
    if (longestStreak != null) data['longest_streak'] = longestStreak;
    if (totalDistanceKm != null) data['total_distance_km'] = totalDistanceKm;
    if (currentSeason != null) data['current_season'] = currentSeason;

    try {
      await _client.from('profiles').upsert(data);
    } catch (e) {
      debugPrint('[SupabasePersistence] upsertProfile failed: $e');
      throw SyncException('Failed to save profile.', cause: e);
    }
  }

  // -- Cell Progress ----------------------------------------------------------

  Future<List<Map<String, dynamic>>> fetchCellProgress(String userId) async {
    try {
      final response = await _client
          .from('cell_progress')
          .select()
          .eq('user_id', userId);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('[SupabasePersistence] fetchCellProgress failed: $e');
      throw SyncException('Failed to load cell progress.', cause: e);
    }
  }

  Future<void> upsertCellProgress({
    required String userId,
    required String cellId,
    required String fogState,
    double distanceWalked = 0,
    int visitCount = 0,
    double restorationLevel = 0,
    DateTime? lastVisited,
  }) async {
    try {
      await _client.from('cell_progress').upsert(
        {
          'user_id': userId,
          'cell_id': cellId,
          'fog_state': fogState,
          'distance_walked': distanceWalked,
          'visit_count': visitCount,
          'restoration_level': restorationLevel,
          'last_visited': lastVisited?.toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id,cell_id',
      );
    } catch (e) {
      debugPrint('[SupabasePersistence] upsertCellProgress failed: $e');
      throw SyncException('Failed to save cell progress.', cause: e);
    }
  }

  // -- Item Instances ---------------------------------------------------------

  Future<List<Map<String, dynamic>>> fetchItemInstances(String userId) async {
    try {
      final response = await _client
          .from('item_instances')
          .select()
          .eq('user_id', userId);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('[SupabasePersistence] fetchItemInstances failed: $e');
      throw SyncException('Failed to load item instances.', cause: e);
    }
  }

  Future<void> upsertItemInstance({
    required String id,
    required String userId,
    required String definitionId,
    required String affixes,
    String? parentAId,
    String? parentBId,
    required DateTime acquiredAt,
    String? acquiredInCellId,
    String? dailySeed,
    required String status,
  }) async {
    try {
      await _client.from('item_instances').upsert(
        {
          'id': id,
          'user_id': userId,
          'definition_id': definitionId,
          'affixes': affixes,
          'parent_a_id': parentAId,
          'parent_b_id': parentBId,
          'acquired_at': acquiredAt.toIso8601String(),
          'acquired_in_cell_id': acquiredInCellId,
          'daily_seed': dailySeed,
          'status': status,
        },
        onConflict: 'id',
      );
    } catch (e) {
      debugPrint('[SupabasePersistence] upsertItemInstance failed: $e');
      throw SyncException('Failed to save item instance.', cause: e);
    }
  }

  Future<void> deleteItemInstance({
    required String id,
  }) async {
    try {
      await _client
          .from('item_instances')
          .delete()
          .eq('id', id);
    } catch (e) {
      debugPrint('[SupabasePersistence] deleteItemInstance failed: $e');
      throw SyncException('Failed to delete item instance.', cause: e);
    }
  }
}
