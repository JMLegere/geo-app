import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:earth_nova/core/models/admin_level.dart';
import 'package:earth_nova/core/models/hierarchy.dart';
import 'package:earth_nova/core/persistence/cell_property_repository.dart';
import 'package:earth_nova/core/persistence/hierarchy_repository.dart';

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
    required this.hierarchyRepo,
    this.supabaseClient,
    @visibleForTesting this.maxRetries = 3,
    @visibleForTesting this.baseDelayMs = 1200,
  });

  final CellPropertyRepository cellPropertyRepo;
  final HierarchyRepository hierarchyRepo;
  final SupabaseClient? supabaseClient;
  final int maxRetries;
  final int baseDelayMs;

  /// Stream of (cellId, locationId) pairs emitted when enrichment completes.
  /// Replaces the old `onLocationEnriched` callback field — multiple listeners
  /// can subscribe without collision.
  final StreamController<({String cellId, String locationId})>
      _enrichedController =
      StreamController<({String cellId, String locationId})>.broadcast();

  /// Stream that fires when a cell's locationId is resolved via enrichment.
  Stream<({String cellId, String locationId})> get onLocationEnriched =>
      _enrichedController.stream;

  /// Cells that permanently failed enrichment (e.g., ocean, no Nominatim data).
  /// Skipped on future requests to avoid hammering Nominatim.
  final Set<String> _permanentlyFailed = {};

  // Nominatim: 1 req/sec. Edge Function batches internally.
  // Client interval should exceed expected server batch time (~25 cells × 1.1s).
  static const _minIntervalMs = 1200;
  static const _batchSize = 25;
  static const _batchIntervalMs = 12000;

  final Queue<_EnrichRequest> _queue = Queue();
  final Set<String> _inFlight = {};
  DateTime _lastRequestTime = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _drainTimer;
  bool _rateLimited = false;
  bool _disposed = false;

  /// Circuit breaker: set when a 401 retry fails, stops all further
  /// Edge Function calls to prevent a stampede of refreshSession() calls
  /// that would hit Supabase auth rate limits and cause logout.
  bool _authFailed = false;
  bool _batchSupported = true;

  /// Deduplicates concurrent refreshSession() calls.
  Future<void>? _pendingRefresh;

  @visibleForTesting
  bool get batchSupported => _batchSupported;

  void requestEnrichment({
    required String cellId,
    required double lat,
    required double lon,
  }) {
    if (_disposed) return;
    if (supabaseClient == null) return;
    if (_inFlight.contains(cellId)) return;
    if (_authFailed) return;
    if (_permanentlyFailed.contains(cellId)) return;

    _queue.add(_EnrichRequest(cellId: cellId, lat: lat, lon: lon));
    _inFlight.add(cellId);
    _scheduleDrain();
  }

  /// Resets the auth circuit breaker so enrichment can resume.
  /// Call when the user re-authenticates or a new session starts.
  void resetAuthCircuitBreaker() {
    if (!_authFailed) return;
    _authFailed = false;
    debugPrint('[LocationEnrichment] auth circuit breaker reset');
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
    while (_queue.isNotEmpty && !_rateLimited && !_disposed && !_authFailed) {
      if (_batchSupported) {
        final batch = <_EnrichRequest>[];
        while (batch.length < _batchSize && _queue.isNotEmpty) {
          batch.add(_queue.removeFirst());
        }
        _lastRequestTime = DateTime.now();
        await _executeBatch(batch);

        // If 404 fallback was triggered, continue with single-request mode.
        if (!_batchSupported) continue;

        if (_queue.isNotEmpty) {
          await Future<void>.delayed(
              const Duration(milliseconds: _batchIntervalMs));
        }
      } else {
        final request = _queue.removeFirst();
        _lastRequestTime = DateTime.now();

        await _executeRequest(request);

        if (_queue.isNotEmpty) {
          await Future<void>.delayed(
              const Duration(milliseconds: _minIntervalMs));
        }
      }
    }
  }

  Future<void> _executeBatch(
    List<_EnrichRequest> batch, {
    bool isRetry = false,
  }) async {
    final client = supabaseClient;
    if (client == null || _disposed) return;

    final cellIds = batch.map((r) => r.cellId).toSet();

    try {
      final cellPayloads = <Map<String, Object>>[];
      for (final r in batch) {
        cellPayloads.add({
          'cell_id': r.cellId,
          'lat': r.lat,
          'lon': r.lon,
        });
      }

      final response = await client.functions.invoke(
        'enrich-locations-batch',
        headers: _authHeaders(client),
        body: {'cells': cellPayloads},
      );

      if (_disposed) return;

      if (response.data != null) {
        final data = response.data as Map<String, dynamic>;

        // Process successful results.
        final results = data['results'] as List<dynamic>?;
        if (results != null) {
          for (final result in results) {
            final resultMap = result as Map<String, dynamic>;
            final cellId = resultMap['cell_id'] as String;
            final status = resultMap['status'] as String?;
            final locationId = resultMap['location_id'] as String?;

            if ((status == 'enriched' || status == 'already_enriched') &&
                locationId != null) {
              final hierarchy = resultMap['hierarchy'] as List<dynamic>?;
              if (hierarchy != null) {
                for (final nodeData in hierarchy) {
                  try {
                    await _upsertHierarchyNode(
                        nodeData as Map<String, dynamic>);
                  } catch (e) {
                    debugPrint(
                        '[LocationEnrichment] failed to upsert hierarchy node: $e');
                  }
                }
              }

              await cellPropertyRepo.updateLocationId(cellId, locationId);
              if (!_disposed && !_enrichedController.isClosed) {
                _enrichedController
                    .add((cellId: cellId, locationId: locationId));
              }

              debugPrint('[LocationEnrichment] batch enriched $cellId '
                  '→ $locationId');
            }
          }
        }

        // Track per-cell errors. Mark cells as permanently failed if
        // the error indicates no data available (e.g., ocean cells).
        final errors = data['errors'] as List<dynamic>?;
        if (errors != null) {
          for (final error in errors) {
            final errorMap = error as Map<String, dynamic>;
            final failedCellId = errorMap['cell_id'] as String?;
            final errorMsg = errorMap['error'] as String? ?? '';
            debugPrint('[LocationEnrichment] batch error for '
                '$failedCellId: $errorMsg');
            // Permanent failures: Nominatim returned no usable data.
            if (failedCellId != null &&
                (errorMsg.contains('no_location') ||
                    errorMsg.contains('unable to resolve') ||
                    errorMsg.contains('ocean'))) {
              _permanentlyFailed.add(failedCellId);
            }
          }
        }
      }
    } on FunctionException catch (e) {
      if (e.status == 404) {
        debugPrint('[LocationEnrichment] batch endpoint not found (404) '
            '— falling back to single-request mode');
        _batchSupported = false;
        for (final request in batch.reversed) {
          _queue.addFirst(request);
        }
        return;
      }
      if (e.status == 429) {
        _rateLimited = true;
        for (final request in batch.reversed) {
          if (request.attempt >= maxRetries) {
            debugPrint(
                '[LocationEnrichment] max retries for ${request.cellId}');
            continue;
          }
          _queue.addFirst(request.retry());
        }
        final backoffMs = baseDelayMs * pow(2, batch.first.attempt).toInt();
        debugPrint('[LocationEnrichment] batch rate limited, '
            'backing off ${backoffMs}ms');
        Timer(Duration(milliseconds: backoffMs), () {
          if (_disposed) return;
          _rateLimited = false;
          _scheduleDrain();
        });
        return;
      }
      if (e.status == 401 && !isRetry) {
        debugPrint('[LocationEnrichment] batch 401 '
            '— refreshing session and retrying');
        try {
          await _deduplicatedRefresh(client);
          if (_disposed) return;
          await _executeBatch(batch, isRetry: true);
          return;
        } catch (refreshErr) {
          debugPrint('[LocationEnrichment] batch refresh + retry '
              'failed: $refreshErr');
          _tripAuthCircuitBreaker();
          return;
        }
      }
      if (e.status == 401 && isRetry) {
        debugPrint('[LocationEnrichment] batch retry 401 '
            '— tripping circuit breaker');
        _tripAuthCircuitBreaker();
        return;
      }
      debugPrint('[LocationEnrichment] batch function error: $e');
    } catch (e) {
      debugPrint('[LocationEnrichment] batch failed: $e');
    } finally {
      for (final id in cellIds) {
        _inFlight.remove(id);
      }
    }
  }

  Future<void> _executeRequest(
    _EnrichRequest request, {
    bool isRetry = false,
  }) async {
    final client = supabaseClient;
    if (client == null || _disposed) return;

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

      if (_disposed) return;

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
                try {
                  await _upsertHierarchyNode(nodeData as Map<String, dynamic>);
                } catch (e) {
                  debugPrint(
                      '[LocationEnrichment] failed to upsert hierarchy node: $e');
                }
              }
            }

            await cellPropertyRepo.updateLocationId(request.cellId, locationId);
            if (!_disposed && !_enrichedController.isClosed) {
              _enrichedController
                  .add((cellId: request.cellId, locationId: locationId));
            }

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
      // 401 = JWT rejected. Refresh ONCE (deduplicated), retry ONCE.
      // If retry also fails, trip the circuit breaker to stop the stampede.
      if (e.status == 401 && !isRetry) {
        debugPrint('[LocationEnrichment] 401 for ${request.cellId} '
            '— refreshing session and retrying');
        try {
          await _deduplicatedRefresh(client);
          if (_disposed) return;
          await _executeRequest(request, isRetry: true);
          return;
        } catch (refreshErr) {
          debugPrint('[LocationEnrichment] refresh + retry failed for '
              '${request.cellId}: $refreshErr');
          _tripAuthCircuitBreaker();
          return;
        }
      }
      if (e.status == 401 && isRetry) {
        debugPrint('[LocationEnrichment] retry 401 for '
            '${request.cellId} — tripping circuit breaker');
        _tripAuthCircuitBreaker();
        return;
      }
      debugPrint('[LocationEnrichment] function error for '
          '${request.cellId}: $e');
    } catch (e) {
      debugPrint('[LocationEnrichment] failed for ${request.cellId}: $e');
    } finally {
      _inFlight.remove(request.cellId);
    }
  }

  /// Deduplicate concurrent refreshSession() calls.
  Future<void> _deduplicatedRefresh(SupabaseClient client) {
    if (_pendingRefresh != null) return _pendingRefresh!;
    _pendingRefresh = client.auth.refreshSession().whenComplete(() {
      _pendingRefresh = null;
    });
    return _pendingRefresh!;
  }

  /// Stop all Edge Function calls. The service is dead until reconstructed
  /// (which happens on next login when the provider rebuilds).
  void _tripAuthCircuitBreaker() {
    if (_authFailed) return;
    _authFailed = true;
    final dropped = _queue.length;
    _queue.clear();
    _inFlight.clear();
    debugPrint('[LocationEnrichment] auth circuit breaker tripped — '
        'dropped $dropped queued requests');
  }

  Future<void> _upsertHierarchyNode(Map<String, dynamic> nodeData) async {
    final id = nodeData['id'] as String;
    final name = nodeData['name'] as String;
    final levelStr = nodeData['level'] as String;
    final parentId = nodeData['parent_id'] as String?;
    final level = AdminLevel.fromString(levelStr);

    // The Edge Function doesn't provide centroid coords for hierarchy nodes,
    // so use 0.0 as placeholder — real values come from Supabase sync.
    switch (level) {
      case AdminLevel.country:
        await hierarchyRepo.upsertCountry(HCountry(
          id: id,
          name: name,
          centroidLat: 0.0,
          centroidLon: 0.0,
          continent: '',
        ));
      case AdminLevel.state:
        await hierarchyRepo.upsertState(HState(
          id: id,
          name: name,
          centroidLat: 0.0,
          centroidLon: 0.0,
          countryId: parentId ?? '',
        ));
      case AdminLevel.city:
        await hierarchyRepo.upsertCity(HCity(
          id: id,
          name: name,
          centroidLat: 0.0,
          centroidLon: 0.0,
          stateId: parentId ?? '',
        ));
      case AdminLevel.district:
        await hierarchyRepo.upsertDistrict(HDistrict(
          id: id,
          name: name,
          centroidLat: 0.0,
          centroidLon: 0.0,
          cityId: parentId ?? '',
        ));
      default:
        break; // Skip world/continent levels
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
    _enrichedController.close();
  }
}
