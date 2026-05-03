import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:earth_nova/features/map/data/dtos/cell_dto.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/ports/cell_query_port.dart';

typedef CellFetchQuery = Future<List<Map<String, dynamic>>> Function(
  double lat,
  double lng,
  double radiusMeters,
);

class SupabaseCellQueryAdapter implements CellQueryPort {
  SupabaseCellQueryAdapter({
    required SupabaseClient? client,
    CellFetchQuery? fetchCellsQuery,
  })  : _client = client,
        _fetchCellsQuery = fetchCellsQuery;

  final SupabaseClient? _client;
  final CellFetchQuery? _fetchCellsQuery;

  @override
  Future<List<Cell>> fetchNearbyCells({
    required double lat,
    required double lng,
    required double radiusMeters,
    String? traceId,
  }) async {
    final response = await _runFetchCellsQuery(lat, lng, radiusMeters);

    return response
        .map((json) => CellDto.fromJson(json).toDomain())
        .where((cell) => cell.hasRenderableGeometry)
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _runFetchCellsQuery(
    double lat,
    double lng,
    double radiusMeters,
  ) async {
    if (_fetchCellsQuery != null) {
      return _fetchCellsQuery!(lat, lng, radiusMeters);
    }

    final client = _client;
    if (client == null) {
      throw StateError(
        'Supabase client is required when no fetchCellsQuery is provided.',
      );
    }

    final response = await client.rpc(
      'fetch_nearby_cells',
      params: {
        'p_lat': lat,
        'p_lng': lng,
        'p_radius_meters': radiusMeters,
      },
    );

    if (response is! List) return [];

    return response
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }
}
