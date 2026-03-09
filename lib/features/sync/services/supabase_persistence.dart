import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SyncException implements Exception {
  const SyncException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'SyncException: $message (cause: $cause)';
}

class SyncValidationRejectedException implements Exception {
  const SyncValidationRejectedException(this.reason);

  final String reason;

  @override
  String toString() => 'SyncValidationRejectedException: $reason';
}

class SyncRejectedException implements Exception {
  const SyncRejectedException(this.reason);

  final String reason;

  @override
  String toString() => 'SyncRejectedException: $reason';
}

class EncounterValidationResult {
  final bool isFirstGlobal;
  const EncounterValidationResult({required this.isFirstGlobal});
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
    bool? hasCompletedOnboarding,
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
    if (hasCompletedOnboarding != null) {
      data['has_completed_onboarding'] = hasCompletedOnboarding;
    }

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
      final response =
          await _client.from('cell_progress').select().eq('user_id', userId);
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
      final response =
          await _client.from('item_instances').select().eq('user_id', userId);
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
    String? displayName,
    String? scientificName,
    String? categoryName,
    String? rarityName,
    String? habitatsJson,
    String? continentsJson,
    String? taxonomicClass,
    String? badgesJson,
    String? parentAId,
    String? parentBId,
    required DateTime acquiredAt,
    String? acquiredInCellId,
    String? dailySeed,
    required String status,
  }) async {
    try {
      final data = <String, dynamic>{
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
      };
      if (displayName != null) data['display_name'] = displayName;
      if (scientificName != null) data['scientific_name'] = scientificName;
      if (categoryName != null) data['category_name'] = categoryName;
      if (rarityName != null) data['rarity_name'] = rarityName;
      if (habitatsJson != null) data['habitats_json'] = habitatsJson;
      if (continentsJson != null) data['continents_json'] = continentsJson;
      if (taxonomicClass != null) data['taxonomic_class'] = taxonomicClass;
      if (badgesJson != null) {
        data['badges_json'] = badgesJson;
      }
      await _client.from('item_instances').upsert(
            data,
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
      await _client.from('item_instances').delete().eq('id', id);
    } catch (e) {
      debugPrint('[SupabasePersistence] deleteItemInstance failed: $e');
      throw SyncException('Failed to delete item instance.', cause: e);
    }
  }

  // -- Encounter Validation ----------------------------------------------------

  /// Validates an encounter with the server and returns the result.
  ///
  /// The server checks seed validity, structural integrity, and whether
  /// this is the first global discovery of the species.
  Future<EncounterValidationResult> validateEncounter({
    required String itemId,
    required String userId,
    required String definitionId,
    required String cellId,
    String? dailySeed,
    required String acquiredAt,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'validate-encounter',
        body: {
          'item_id': itemId,
          'user_id': userId,
          'definition_id': definitionId,
          'cell_id': cellId,
          'daily_seed': dailySeed,
          'acquired_at': acquiredAt,
        },
      );

      if (response.status == 409) {
        final data = response.data as Map<String, dynamic>?;
        final reason = data?['reason'] as String? ?? 'server_rejected';
        throw SyncValidationRejectedException(reason);
      }

      if (response.status != 200) {
        throw SyncException(
          'Validation failed with status ${response.status}',
        );
      }

      final data = response.data as Map<String, dynamic>?;
      return EncounterValidationResult(
        isFirstGlobal: data?['is_first_global'] as bool? ?? false,
      );
    } on SyncValidationRejectedException {
      rethrow;
    } catch (e) {
      if (e is SyncException) rethrow;
      debugPrint('[SupabasePersistence] validateEncounter failed: $e');
      throw SyncException('Failed to validate encounter.', cause: e);
    }
  }

  // -- Species Enrichment -----------------------------------------------------

  Future<List<Map<String, dynamic>>> fetchEnrichments({DateTime? since}) async {
    try {
      var query = _client.from('species_enrichment').select();
      if (since != null) {
        query = query.gte('enriched_at', since.toIso8601String());
      }
      final response = await query;
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('[SupabasePersistence] fetchEnrichments failed: $e');
      throw SyncException('Failed to load enrichments.', cause: e);
    }
  }
}
