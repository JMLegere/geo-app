import 'package:supabase_flutter/supabase_flutter.dart';

class SupabasePersistence {
  SupabasePersistence(this._client);

  final SupabaseClient _client;

  // -- Profile ----------------------------------------------------------------

  Future<Map<String, dynamic>?> fetchProfile(String userId) async {
    final response = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    return response;
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

    await _client.from('profiles').upsert(data);
  }

  // -- Cell Progress ----------------------------------------------------------

  Future<List<Map<String, dynamic>>> fetchCellProgress(String userId) async {
    final response = await _client
        .from('cell_progress')
        .select()
        .eq('user_id', userId);
    return List<Map<String, dynamic>>.from(response);
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
  }

  // -- Collection -------------------------------------------------------------

  Future<List<Map<String, dynamic>>> fetchCollection(String userId) async {
    final response = await _client
        .from('collected_species')
        .select()
        .eq('user_id', userId);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> addToCollection({
    required String userId,
    required String speciesId,
    required String cellId,
  }) async {
    await _client.from('collected_species').upsert(
      {
        'user_id': userId,
        'species_id': speciesId,
        'cell_id': cellId,
        'collected_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'user_id,species_id,cell_id',
    );
  }

  Future<void> removeFromCollection({
    required String userId,
    required String speciesId,
    required String cellId,
  }) async {
    await _client
        .from('collected_species')
        .delete()
        .eq('user_id', userId)
        .eq('species_id', speciesId)
        .eq('cell_id', cellId);
  }
}
