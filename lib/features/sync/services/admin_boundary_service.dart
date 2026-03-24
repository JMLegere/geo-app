import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:earth_nova/core/models/location_node.dart';
import 'package:earth_nova/core/persistence/location_node_repository.dart';

/// Fetches admin boundary polygons from the `resolve-admin-boundaries`
/// Edge Function and caches them locally via [LocationNodeRepository].
///
/// Pure Dart service — no Riverpod dependency. Injected with
/// [SupabaseClient] and [LocationNodeRepository] via constructor.
class AdminBoundaryService {
  AdminBoundaryService({
    required SupabaseClient client,
    required LocationNodeRepository repository,
  })  : _client = client,
        _repository = repository;

  final SupabaseClient _client;
  final LocationNodeRepository _repository;

  final StreamController<List<String>> _boundariesResolvedController =
      StreamController<List<String>>.broadcast(sync: true);

  /// Fires after each successful boundary fetch with the upserted node IDs.
  Stream<List<String>> get onBoundariesResolved =>
      _boundariesResolvedController.stream;

  /// Lat/lon key from the last [requestBoundaries] call, rounded to 4 decimal
  /// places (~11 m). Repeated calls at the same location are no-ops.
  String? _lastRequestedLocation;

  /// Fetches admin boundary polygons for [lat]/[lon] from the Edge Function
  /// and upserts them into the local [LocationNodeRepository].
  ///
  /// - Debounced: same lat/lon rounded to 4 decimal places → no-op.
  /// - Cached: if all 4 admin levels already have geometry in the repository,
  ///   the Edge Function call is skipped.
  /// - Error-safe: all exceptions are caught and logged; never throws.
  Future<void> requestBoundaries(double lat, double lon) async {
    // Primary deduplication: same location (rounded to 4 decimal places).
    final locationKey = '${lat.toStringAsFixed(4)}_${lon.toStringAsFixed(4)}';
    if (locationKey == _lastRequestedLocation) return;

    try {
      // Secondary deduplication removed — the old check looked at ALL nodes
      // globally, so once any single district had geometry, it skipped
      // fetching geometry for every other district. The primary deduplication
      // (same lat/lon rounded to 4 decimal places) and the Edge Function's
      // own per-node cache are sufficient.

      final response = await _client.functions.invoke(
        'resolve-admin-boundaries',
        body: {'lat': lat, 'lon': lon},
      );

      if (response.data == null) return;

      final data = response.data as Map<String, dynamic>;
      final boundaries = data['boundaries'] as List<dynamic>?;
      if (boundaries == null || boundaries.isEmpty) return;

      final nodeIds = <String>[];

      for (final boundary in boundaries) {
        if (boundary is! Map<String, dynamic>) continue;

        final adminLevelStr = boundary['admin_level'] as String?;
        final name = boundary['name'] as String?;
        final osmId = boundary['osm_id'] as int?;
        final geometryJsonRaw = boundary['geometry_json'];

        if (adminLevelStr == null || name == null || geometryJsonRaw == null) {
          continue;
        }

        AdminLevel adminLevel;
        try {
          adminLevel = AdminLevel.fromString(adminLevelStr);
        } catch (_) {
          debugPrint('[AdminBoundary] unknown admin level: $adminLevelStr');
          continue;
        }

        // geometryJsonRaw arrives as a Map when the Edge Function fetches
        // from Nominatim (fresh), but as a String when it serves a cache hit
        // from the text-typed geometry_json column. Only encode Maps.
        final geometryStr = geometryJsonRaw is String
            ? geometryJsonRaw
            : jsonEncode(geometryJsonRaw);

        // Try to find an existing node by osm_id to preserve its canonical ID.
        LocationNode? existing;
        if (osmId != null) {
          try {
            existing = await _repository.getByOsmId(osmId);
          } catch (_) {
            // Ignore lookup failure — create a new node below.
          }
        }

        final String nodeId;
        final LocationNode node;

        if (existing != null) {
          nodeId = existing.id;
          node = existing.copyWith(geometryJson: () => geometryStr);
        } else {
          nodeId = _makeNodeId(adminLevelStr, name);
          node = LocationNode(
            id: nodeId,
            osmId: osmId,
            name: name,
            adminLevel: adminLevel,
            parentId: null,
            colorHex: null,
            geometryJson: geometryStr,
          );
        }

        await _repository.upsert(node);
        nodeIds.add(nodeId);
      }

      // Only mark location as done after successful response with results.
      if (nodeIds.isNotEmpty) {
        _lastRequestedLocation = locationKey;
        _boundariesResolvedController.add(nodeIds);
      }
    } catch (e) {
      debugPrint('[AdminBoundary] requestBoundaries failed: $e');
    }
  }

  /// Builds a provisional node ID from [level] and [name].
  ///
  /// Matches the server-side `makeId()` function for country-level nodes:
  /// `"${level}_${slug}"` where slug replaces non-alphanumeric chars with `_`.
  String _makeNodeId(String level, String name) {
    final slug = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return '${level}_$slug';
  }
}
