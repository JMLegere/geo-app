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

  /// Exposes the underlying Supabase client for direct queries (e.g. enrichment pull).
  SupabaseClient get client => _client;

  Map<String, String> _authHeaders() {
    final token = _client.auth.currentSession?.accessToken;
    if (token != null) return {'Authorization': 'Bearer $token'};
    return {};
  }

  // -- Profile ----------------------------------------------------------------

  Future<Map<String, dynamic>?> fetchProfile(String userId) async {
    try {
      return await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
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

  /// Simplified upsert — no enrichver parameters.
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
    // Species enrichment denorm (no enrichver)
    String? animalClassName,
    String? foodPreferenceName,
    String? climateName,
    int? brawn,
    int? wit,
    int? speed,
    String? sizeName,
    // Cell context
    String? cellHabitatName,
    String? cellClimateName,
    String? cellContinentName,
    // Location hierarchy
    String? locationDistrict,
    String? locationCity,
    String? locationState,
    String? locationCountry,
    String? locationCountryCode,
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
      if (badgesJson != null) data['badges_json'] = badgesJson;
      data['animal_class_name'] = animalClassName;
      data['food_preference_name'] = foodPreferenceName;
      data['climate_name'] = climateName;
      data['brawn'] = brawn;
      data['wit'] = wit;
      data['speed'] = speed;
      data['size_name'] = sizeName;
      data['cell_habitat_name'] = cellHabitatName;
      data['cell_climate_name'] = cellClimateName;
      data['cell_continent_name'] = cellContinentName;
      data['location_district'] = locationDistrict;
      data['location_city'] = locationCity;
      data['location_state'] = locationState;
      data['location_country'] = locationCountry;
      data['location_country_code'] = locationCountryCode;
      await _client.from('item_instances').upsert(data, onConflict: 'id');
    } catch (e) {
      debugPrint('[SupabasePersistence] upsertItemInstance failed: $e');
      throw SyncException('Failed to save item instance.', cause: e);
    }
  }

  Future<void> deleteItemInstance({required String id}) async {
    try {
      await _client.from('item_instances').delete().eq('id', id);
    } catch (e) {
      debugPrint('[SupabasePersistence] deleteItemInstance failed: $e');
      throw SyncException('Failed to delete item instance.', cause: e);
    }
  }

  // -- Encounter Validation ---------------------------------------------------

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
        headers: _authHeaders(),
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
        throw SyncException('Validation failed with status ${response.status}');
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

  // -- Cell Properties --------------------------------------------------------

  Future<void> upsertCellProperties({
    required String cellId,
    required String userId,
    required List<String> habitats,
    required String climate,
    required String continent,
    String? locationId,
  }) async {
    try {
      await _client.from('cell_properties').upsert(
        {
          'cell_id': cellId,
          'habitats': habitats,
          'climate': climate,
          'continent': continent,
          'location_id': locationId,
          'created_by': userId,
        },
        onConflict: 'cell_id',
        ignoreDuplicates: true,
      );
    } catch (e) {
      debugPrint('[SupabasePersistence] upsertCellProperties failed: $e');
      throw SyncException('Failed to save cell properties.', cause: e);
    }
  }

  Future<List<Map<String, dynamic>>> fetchCellProperties(
      List<String> cellIds) async {
    if (cellIds.isEmpty) return [];
    try {
      final results = <Map<String, dynamic>>[];
      for (var i = 0; i < cellIds.length; i += 500) {
        final chunk = cellIds.sublist(i, (i + 500).clamp(0, cellIds.length));
        final response = await _client
            .from('cell_properties')
            .select()
            .inFilter('cell_id', chunk);
        results.addAll(List<Map<String, dynamic>>.from(response as List));
      }
      return results;
    } catch (e) {
      debugPrint('[SupabasePersistence] fetchCellProperties failed: $e');
      throw SyncException('Failed to load cell properties.', cause: e);
    }
  }

  // -- Location Hierarchy -----------------------------------------------------

  /// Fetches all countries from Supabase.
  Future<List<Map<String, dynamic>>> fetchCountries() async {
    final response = await _client.from('countries').select();
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> fetchStates() async {
    final response = await _client.from('states').select();
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> fetchCities() async {
    final response = await _client.from('cities').select();
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> fetchDistricts() async {
    final response = await _client.from('districts').select();
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> fetchSpeciesUpdates({
    required DateTime since,
  }) async {
    try {
      final response = await _client
          .from('species')
          .select()
          .not('enriched_at', 'is', null)
          .gt('enriched_at', since.toIso8601String());
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('[SupabasePersistence] fetchSpeciesUpdates failed: $e');
      throw SyncException('Failed to load species updates.', cause: e);
    }
  }
}
