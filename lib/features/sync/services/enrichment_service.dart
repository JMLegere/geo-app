import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:earth_nova/core/models/animal_class.dart';
import 'package:earth_nova/core/models/animal_type.dart';
import 'package:earth_nova/core/models/species_enrichment.dart';
import 'package:earth_nova/core/persistence/enrichment_repository.dart';

enum EnrichmentPriority { high, low }

class _EnrichmentRequest {
  final String definitionId;
  final String scientificName;
  final String commonName;
  final String taxonomicClass;
  final bool force;
  final int attempt;
  final EnrichmentPriority priority;

  _EnrichmentRequest({
    required this.definitionId,
    required this.scientificName,
    required this.commonName,
    required this.taxonomicClass,
    this.force = false,
    this.attempt = 0,
    this.priority = EnrichmentPriority.high,
  });

  _EnrichmentRequest retry() => _EnrichmentRequest(
        definitionId: definitionId,
        scientificName: scientificName,
        commonName: commonName,
        taxonomicClass: taxonomicClass,
        force: force,
        attempt: attempt + 1,
        priority: priority,
      );
}

class EnrichmentService {
  EnrichmentService({
    required this.repository,
    this.supabaseClient,
    this.onEnriched,
    @visibleForTesting this.maxRetries = 3,
    @visibleForTesting this.baseDelayMs = 4000,
    @visibleForTesting this.minIntervalMs = _defaultMinIntervalMs,
  }) {
    debugPrint('[EnrichmentService] created — '
        'client ${supabaseClient != null ? "available" : "NULL"}');
  }

  final EnrichmentRepository repository;
  final SupabaseClient? supabaseClient;
  final int maxRetries;
  final int baseDelayMs;
  final int minIntervalMs;

  /// Called after each successful enrichment is cached locally.
  /// Provider layer uses this to invalidate [enrichmentMapProvider].
  final void Function(SpeciesEnrichment enrichment)? onEnriched;

  /// Secondary hook called after [onEnriched]. Set by [gameCoordinatorProvider]
  /// to update the in-memory enrichment cache and backfill intrinsic affixes
  /// for items whose enrichment arrived via the startup requeue path.
  /// Mutable so it can be wired after provider construction.
  void Function(SpeciesEnrichment enrichment)? onEnrichedHook;

  static const _maxConcurrent = 2;
  static const _defaultMinIntervalMs = 4200;
  static const _batchSize = 10;

  final Queue<_EnrichmentRequest> _queue = Queue();
  final Set<String> _inFlight = {};
  int _activeRequests = 0;
  bool _batchSupported = true;
  DateTime _lastRequestTime = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _drainTimer;
  bool _rateLimited = false;
  bool _disposed = false;

  /// Circuit breaker: set when a 401 retry fails, stops all further
  /// Edge Function calls to prevent a stampede of refreshSession() calls
  /// that would hit Supabase auth rate limits and cause logout.
  bool _authFailed = false;

  /// Deduplicates concurrent refreshSession() calls. If a refresh is already
  /// in flight, subsequent 401 handlers await the same future instead of
  /// firing parallel refresh requests.
  Future<void>? _pendingRefresh;

  @visibleForTesting
  bool get batchSupported => _batchSupported;

  Future<void> requestEnrichment({
    required String definitionId,
    required String scientificName,
    required String commonName,
    required String taxonomicClass,
    bool force = false,
    EnrichmentPriority priority = EnrichmentPriority.high,
  }) async {
    if (supabaseClient == null) {
      debugPrint('[EnrichmentService] skipping $definitionId — '
          'Supabase client not available');
      return;
    }
    if (_inFlight.contains(definitionId)) return;

    _queue.add(_EnrichmentRequest(
      definitionId: definitionId,
      scientificName: scientificName,
      commonName: commonName,
      taxonomicClass: taxonomicClass,
      force: force,
      priority: priority,
    ));
    _inFlight.add(definitionId);
    _scheduleDrain();
  }

  void _scheduleDrain() {
    if (_drainTimer?.isActive ?? false) return;
    if (_queue.isEmpty) return;

    final sinceLastRequest =
        DateTime.now().difference(_lastRequestTime).inMilliseconds;
    final delay = max(0, minIntervalMs - sinceLastRequest);

    _drainTimer = Timer(Duration(milliseconds: delay), _drain);
  }

  Future<void> _drain() async {
    if (_batchSupported) {
      await _drainBatch();
    } else {
      await _drainSingle();
    }
  }

  Future<void> _drainBatch() async {
    while (_queue.isNotEmpty &&
        _activeRequests < _maxConcurrent &&
        !_rateLimited &&
        !_authFailed &&
        !_disposed &&
        _batchSupported) {
      // Collect up to _batchSize requests, sorted by priority (high first).
      final batch = <_EnrichmentRequest>[];
      while (_queue.isNotEmpty && batch.length < _batchSize) {
        batch.add(_queue.removeFirst());
      }
      // Sort: high priority first.
      batch.sort((a, b) => a.priority.index.compareTo(b.priority.index));

      _activeRequests++;
      _lastRequestTime = DateTime.now();

      await _executeBatch(batch);
      _activeRequests--;
      _scheduleDrain();
    }
  }

  Future<void> _drainSingle() async {
    while (_queue.isNotEmpty &&
        _activeRequests < _maxConcurrent &&
        !_rateLimited &&
        !_authFailed &&
        !_disposed) {
      final request = _queue.removeFirst();
      _activeRequests++;
      _lastRequestTime = DateTime.now();

      _executeRequest(request).whenComplete(() {
        _activeRequests--;
        _scheduleDrain();
      });

      if (_queue.isNotEmpty && _activeRequests < _maxConcurrent) {
        await Future<void>.delayed(Duration(milliseconds: minIntervalMs));
      }
    }
  }

  Future<void> _executeBatch(List<_EnrichmentRequest> batch) async {
    final client = supabaseClient;
    if (client == null || _disposed) return;

    final batchIds = batch.map((r) => r.definitionId).toList();
    debugPrint('[EnrichmentService] invoking enrich-species-batch for '
        '${batch.length} species: $batchIds');

    try {
      final speciesList = batch.map((r) {
        final expectedType = AnimalType.fromTaxonomicClass(r.taxonomicClass);
        final validClasses = expectedType != null
            ? AnimalClass.values
                .where((c) => c.parentType == expectedType)
                .map((c) => c.name)
                .toList()
            : null;
        return {
          'definition_id': r.definitionId,
          'scientific_name': r.scientificName,
          'common_name': r.commonName,
          'taxonomic_class': r.taxonomicClass,
          if (validClasses != null) 'valid_animal_classes': validClasses,
          if (r.force) 'force': true,
        };
      }).toList();

      final response = await client.functions.invoke(
        'enrich-species-batch',
        headers: _authHeaders(client),
        body: {'species': speciesList},
      );

      if (_disposed) return;

      if (response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final results =
            (data['results'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final errors =
            (data['errors'] as List?)?.cast<Map<String, dynamic>>() ?? [];

        for (final result in results) {
          try {
            final enrichment = SpeciesEnrichment.fromJson(result);
            final defId = enrichment.definitionId;
            final request = batch.firstWhere((r) => r.definitionId == defId,
                orElse: () => batch.first);
            final expectedType =
                AnimalType.fromTaxonomicClass(request.taxonomicClass);

            if (expectedType != null &&
                enrichment.animalClass.parentType != expectedType) {
              debugPrint('[EnrichmentService] rejected $defId: '
                  'animalClass ${enrichment.animalClass.name} '
                  'does not match expected type ${expectedType.name}');
              continue;
            }

            await repository.upsertEnrichment(enrichment);
            debugPrint('[EnrichmentService] enriched $defId: '
                '${enrichment.animalClass.name}, '
                '${enrichment.foodPreference.name}, '
                '${enrichment.climate.name}');
            if (!_disposed) {
              onEnriched?.call(enrichment);
              onEnrichedHook?.call(enrichment);
            }
          } catch (e) {
            debugPrint(
                '[EnrichmentService] failed to process batch result: $e');
          }
        }

        for (final error in errors) {
          debugPrint('[EnrichmentService] batch error for '
              '${error['definition_id']}: ${error['error']}');
        }
      }
    } on FunctionException catch (e) {
      if (e.status == 404) {
        debugPrint('[EnrichmentService] batch endpoint not found (404) — '
            'falling back to single-request mode');
        _batchSupported = false;
        // Re-queue all batch items for single-request processing.
        for (final request in batch.reversed) {
          _queue.addFirst(request);
        }
        _scheduleDrain();
        return;
      }
      if (e.status == 429) {
        // Rate limited — re-queue all with retry.
        for (final request in batch) {
          _handleRateLimit(request);
        }
        return;
      }
      if (e.status == 401) {
        debugPrint('[EnrichmentService] 401 for batch '
            '— refreshing session and retrying');
        try {
          await _deduplicatedRefresh(client);
          if (_disposed) return;
          await _executeBatch(batch);
          return;
        } catch (refreshErr) {
          debugPrint('[EnrichmentService] refresh + retry failed for '
              'batch: $refreshErr');
          _tripAuthCircuitBreaker();
          return;
        }
      }
      debugPrint('[EnrichmentService] function error for batch: $e');
    } catch (e) {
      debugPrint('[EnrichmentService] failed for batch: $e');
    } finally {
      for (final request in batch) {
        _inFlight.remove(request.definitionId);
      }
    }
  }

  Future<void> _executeRequest(
    _EnrichmentRequest request, {
    bool isRetry = false,
  }) async {
    final client = supabaseClient;
    if (client == null || _disposed) return;

    debugPrint('[EnrichmentService] invoking enrich-species for '
        '${request.definitionId} (${request.commonName})'
        '${isRetry ? ' [retry]' : ''}');
    try {
      final expectedType =
          AnimalType.fromTaxonomicClass(request.taxonomicClass);
      final validClasses = expectedType != null
          ? AnimalClass.values
              .where((c) => c.parentType == expectedType)
              .map((c) => c.name)
              .toList()
          : null;

      final response = await client.functions.invoke(
        'enrich-species',
        headers: _authHeaders(client),
        body: {
          'definition_id': request.definitionId,
          'scientific_name': request.scientificName,
          'common_name': request.commonName,
          'taxonomic_class': request.taxonomicClass,
          if (validClasses != null) 'valid_animal_classes': validClasses,
          if (request.force) 'force': true,
        },
      );

      if (_disposed) return;

      if (response.data != null) {
        final data = response.data as Map<String, dynamic>;
        if (data.containsKey('error')) {
          final statusCode = data['statusCode'] as int? ?? 500;
          if (statusCode == 429) {
            _handleRateLimit(request);
            return;
          }
          debugPrint('[EnrichmentService] error for ${request.definitionId}: '
              '${data['error']}');
        } else {
          final enrichment = SpeciesEnrichment.fromJson(data);
          if (expectedType != null &&
              enrichment.animalClass.parentType != expectedType) {
            debugPrint('[EnrichmentService] rejected ${request.definitionId}: '
                'animalClass ${enrichment.animalClass.name} '
                'does not match expected type ${expectedType.name}');
            _inFlight.remove(request.definitionId);
            return;
          }
          await repository.upsertEnrichment(enrichment);
          debugPrint('[EnrichmentService] enriched ${request.definitionId}: '
              '${enrichment.animalClass.name}, '
              '${enrichment.foodPreference.name}, '
              '${enrichment.climate.name}');
          if (!_disposed) {
            onEnriched?.call(enrichment);
            onEnrichedHook?.call(enrichment);
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
        debugPrint('[EnrichmentService] 401 for ${request.definitionId} '
            '— refreshing session and retrying');
        try {
          await _deduplicatedRefresh(client);
          if (_disposed) return;
          await _executeRequest(request, isRetry: true);
          return;
        } catch (refreshErr) {
          debugPrint('[EnrichmentService] refresh + retry failed for '
              '${request.definitionId}: $refreshErr');
          _tripAuthCircuitBreaker();
          return;
        }
      }
      if (e.status == 401 && isRetry) {
        debugPrint('[EnrichmentService] retry 401 for '
            '${request.definitionId} — tripping circuit breaker');
        _tripAuthCircuitBreaker();
        return;
      }
      debugPrint('[EnrichmentService] function error for '
          '${request.definitionId}: $e');
    } catch (e) {
      debugPrint('[EnrichmentService] failed for '
          '${request.definitionId}: $e');
    } finally {
      _inFlight.remove(request.definitionId);
    }
  }

  /// Deduplicate concurrent refreshSession() calls. Only one refresh runs
  /// at a time; others await the same future.
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
    debugPrint('[EnrichmentService] auth circuit breaker tripped — '
        'dropped $dropped queued requests');
  }

  void _handleRateLimit(_EnrichmentRequest request) {
    if (request.attempt >= maxRetries) {
      debugPrint('[EnrichmentService] max retries for ${request.definitionId}');
      _inFlight.remove(request.definitionId);
      return;
    }

    _rateLimited = true;
    final retried = request.retry();
    _queue.addFirst(retried);

    final backoffMs = baseDelayMs * pow(2, request.attempt).toInt();
    debugPrint('[EnrichmentService] rate limited, backing off ${backoffMs}ms '
        '(attempt ${retried.attempt})');

    Timer(Duration(milliseconds: backoffMs), () {
      if (_disposed) return;
      _rateLimited = false;
      _scheduleDrain();
    });
  }

  Future<int> syncEnrichments({DateTime? since}) async {
    final client = supabaseClient;
    if (client == null) return 0;

    try {
      var query = client.from('species_enrichment').select();
      if (since != null) {
        query = query.gte('enriched_at', since.toIso8601String());
      }

      final response = await query;
      final rows = List<Map<String, dynamic>>.from(response as List);
      final enrichments = rows
          .map((row) {
            try {
              return SpeciesEnrichment.fromJson(row);
            } catch (e) {
              debugPrint('[EnrichmentService] failed to parse row: $e');
              return null;
            }
          })
          .whereType<SpeciesEnrichment>()
          .toList();

      await repository.upsertAll(enrichments);
      return enrichments.length;
    } catch (e) {
      debugPrint('[EnrichmentService] syncEnrichments failed: $e');
      return 0;
    }
  }

  Future<Map<String, SpeciesEnrichment>> getEnrichmentMap() async {
    final all = await repository.getAllEnrichments();
    return {for (final e in all) e.definitionId: e};
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
