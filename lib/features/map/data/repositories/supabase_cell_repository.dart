import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:earth_nova/features/map/data/dtos/cell_dto.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/repositories/cell_repository.dart';

class SupabaseCellRepository implements CellRepository {
  SupabaseCellRepository({required SupabaseClient client}) : _client = client;

  final SupabaseClient _client;

  @override
  Future<List<Cell>> fetchCellsInRadius(
    double lat,
    double lng,
    double radiusMeters,
  ) async {
    final response = await _client
        .from('cell_properties')
        .select('cell_id, habitats, location_id');

    if (response.isEmpty) return [];
    return (response as List)
        .map((json) => CellDto.fromJson({
              'cell_id': json['cell_id'],
              'habitats': json['habitats'] ?? [],
              'polygon': <Map<String, dynamic>>[],
              'district_id': null,
              'city_id': null,
              'state_id': null,
              'country_id': null,
            }).toDomain())
        .toList();
  }

  @override
  Future<void> recordVisit(String userId, String cellId) async {
    await _client.from('v3_cell_visits').insert({
      'user_id': userId,
      'cell_id': cellId,
    });
  }

  @override
  Future<Set<String>> getVisitedCellIds(String userId) async {
    final response = await _client
        .from('v3_cell_visits')
        .select('cell_id')
        .eq('user_id', userId);

    if (response.isEmpty) return {};
    return (response as List).map((row) => row['cell_id'] as String).toSet();
  }

  @override
  Future<bool> isFirstVisit(String userId, String cellId) async {
    final response = await _client
        .from('v3_cell_visits')
        .select('id')
        .eq('user_id', userId)
        .eq('cell_id', cellId)
        .limit(1);

    return (response as List).isEmpty;
  }
}
