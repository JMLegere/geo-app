import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:earth_nova/core/models/location_node.dart';
import 'package:earth_nova/core/persistence/cell_property_repository.dart';
import 'package:earth_nova/core/persistence/location_node_repository.dart';

class _EnrichRequest {
  final String cellId;
  final double lat;
  final double lon;
  final int attempt;

  _EnrichRequest({
    required this.cellId,
    required this.lat,
    required this.lon,
    this.attempt = 0,
  });

  _EnrichRequest retry() => _EnrichRequest(
        cellId: cellId,
        lat: lat,
        lon: lon,
        attempt: attempt + 1,
      );
}

class LocationEnrichmentService {
  LocationEnrichmentService({
    required this.cellPropertyRepo,
    required this.locationNodeRepo,
    this.supabaseClient,
    this.onLocationEnriched,
    @visibleForTesting this.maxRetries = 3,
    @visibleForTesting this.baseDelayMs = 1200,
  });

  final CellPropertyRepository cellPropertyRepo;
  final LocationNodeRepository locationNodeRepo;
  final SupabaseClient? supabaseClient;
  final int maxRetries;
  final int baseDelayMs;

  void Function(String cellId, String locationId)? onLocationEnriched;

  // Nominatim: 1 req/sec. Keep interval above that.
  static const _minIntervalMs = 1200;

  final Queue<_EnrichRequest> _queue = Queue();
  final Set<String> _inFlight = {};
  DateTime _lastRequestTime = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _drainTimer;
  bool _rateLimited = false;
  bool _disposed = false;

  void requestEnrichment({
    required String cellId,
    required double lat,
    required double lon,
  }) {
    if (_disposed) return;
    if (supabaseClient == null) return;
    if (_inFlight.contains(cellId)) return;

    _queue.add(_EnrichRequest(cellId: cellId, lat: lat, lon: lon));
    _inFlight.add(cellId);
    _scheduleDrain();
  }

  void _scheduleDrain() {
    if (_drainTimer?.isActive ?? false) return;
    if (_queue.isEmpty) return;

    final sinceLastRequest =
        DateTime.now().difference(_lastRequestTime).inMilliseconds;
    final delay = max(0, _minIntervalMs - sinceLastRequest);

    _drainTimer = Timer(Duration(milliseconds: delay), _drain);
  }

  Future<void> _drain() async {
    while (_queue.isNotEmpty && !_rateLimited && !_disposed) {
      final request = _queue.removeFirst();
      _lastRequestTime = DateTime.now();

      await _executeRequest(request);

      if (_queue.isNotEmpty) {
        await Future<void>.delayed(
            const Duration(milliseconds: _minIntervalMs));
      }
    }
  }

  Future<void> _executeRequest(
    _EnrichRequest request, {
    bool isRetry = false,
  }) async {
    final client = supabaseClient;
    if (client == null) return;

    try {
      final response = await client.functions.invoke(
        'enrich-location',
        headers: _authHeaders(client),
        body: {
          'cell_id': request.cellId,
          'lat': request.lat,
          'lon': request.lon,
        },
      );

      if (response.data != null) {
        final data = response.data as Map<String, dynamic>;

        if (data.containsKey('error')) {
          debugPrint('[LocationEnrichment] error for ${request.cellId}: '
              '${data['error']}');
          return;
        }

        final status = data['status'] as String?;
        final locationId = data['location_id'] as String?;

        if (status == 'already_enriched' || status == 'enriched') {
          if (locationId != null) {
            // Save hierarchy nodes to local SQLite cache.
            final hierarchy = data['hierarchy'] as List<dynamic>?;
            if (hierarchy != null) {
              for (final nodeData in hierarchy) {
                final node = _parseHierarchyNode(nodeData);
                if (node != null) {
                  await locationNodeRepo.upsert(node);
                }
              }
            }

            await cellPropertyRepo.updateLocationId(request.cellId, locationId);
            onLocationEnriched?.call(request.cellId, locationId);

            debugPrint('[LocationEnrichment] enriched ${request.cellId} '
                '→ $locationId');
          }
        }
      }
    } on FunctionException catch (e) {
      if (e.status == 429) {
        _handleRateLimit(request);
        return;
      }
      // 401 = JWT rejected by Edge Function gateway. Refresh the session
      // and retry once. The explicit _authHeaders() call on the retry
      // reads the fresh token directly from auth state, bypassing the
      // async FunctionsClient header cache race condition.
      if (e.status == 401 && !isRetry) {
        debugPrint('[LocationEnrichment] 401 for ${request.cellId} '
            '— refreshing session and retrying');
        try {
          await client.auth.refreshSession();
          await _executeRequest(request, isRetry: true);
          return;
        } catch (refreshErr) {
          debugPrint('[LocationEnrichment] refresh + retry failed for '
              '${request.cellId}: $refreshErr');
          return;
        }
      }
      debugPrint('[LocationEnrichment] function error for '
          '${request.cellId}: $e');
    } catch (e) {
      debugPrint('[LocationEnrichment] failed for ${request.cellId}: $e');
    } finally {
      _inFlight.remove(request.cellId);
    }
  }

  LocationNode? _parseHierarchyNode(dynamic nodeData) {
    if (nodeData is! Map<String, dynamic>) return null;
    try {
      final id = nodeData['id'] as String;
      final name = nodeData['name'] as String;
      final level = nodeData['level'] as String;
      final parentId = nodeData['parent_id'] as String?;
      return LocationNode(
        id: id,
        osmId: null,
        name: name,
        adminLevel: AdminLevel.fromString(level),
        parentId: parentId,
        colorHex: null,
      );
    } catch (e) {
      debugPrint('[LocationEnrichment] failed to parse node: $e');
      return null;
    }
  }

  void _handleRateLimit(_EnrichRequest request) {
    if (request.attempt >= maxRetries) {
      debugPrint('[LocationEnrichment] max retries for ${request.cellId}');
      _inFlight.remove(request.cellId);
      return;
    }

    _rateLimited = true;
    final retried = request.retry();
    _queue.addFirst(retried);

    final backoffMs = baseDelayMs * pow(2, request.attempt).toInt();
    debugPrint('[LocationEnrichment] rate limited, backing off ${backoffMs}ms '
        '(attempt ${retried.attempt})');

    Timer(Duration(milliseconds: backoffMs), () {
      if (_disposed) return;
      _rateLimited = false;
      _scheduleDrain();
    });
  }

  /// Read the current access token directly from auth state and pass it
  /// explicitly. This avoids a race condition in supabase-dart where
  /// [SupabaseClient._handleTokenChanged] updates [FunctionsClient] headers
  /// asynchronously — meaning [functions.invoke] can read a stale token
  /// after [auth.refreshSession] completes.
  Map<String, String> _authHeaders(SupabaseClient client) {
    final token = client.auth.currentSession?.accessToken;
    if (token != null) {
      return {'Authorization': 'Bearer $token'};
    }
    return {};
  }

  void dispose() {
    _disposed = true;
    _drainTimer?.cancel();
  }
}
