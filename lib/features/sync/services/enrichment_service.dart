import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:earth_nova/core/models/animal_class.dart';
import 'package:earth_nova/core/models/animal_type.dart';
import 'package:earth_nova/core/models/species_enrichment.dart';
import 'package:earth_nova/core/persistence/enrichment_repository.dart';

class _EnrichmentRequest {
  final String definitionId;
  final String scientificName;
  final String commonName;
  final String taxonomicClass;
  final bool force;
  final int attempt;

  _EnrichmentRequest({
    required this.definitionId,
    required this.scientificName,
    required this.commonName,
    required this.taxonomicClass,
    this.force = false,
    this.attempt = 0,
  });

  _EnrichmentRequest retry() => _EnrichmentRequest(
        definitionId: definitionId,
        scientificName: scientificName,
        commonName: commonName,
        taxonomicClass: taxonomicClass,
        force: force,
        attempt: attempt + 1,
      );
}

class EnrichmentService {
  EnrichmentService({
    required this.repository,
    this.supabaseClient,
    this.onEnriched,
    @visibleForTesting this.maxRetries = 3,
    @visibleForTesting this.baseDelayMs = 4000,
  }) {
    debugPrint('[EnrichmentService] created — '
        'client ${supabaseClient != null ? "available" : "NULL"}');
  }

  final EnrichmentRepository repository;
  final SupabaseClient? supabaseClient;
  final int maxRetries;
  final int baseDelayMs;

  /// Called after each successful enrichment is cached locally.
  /// Provider layer uses this to invalidate [enrichmentMapProvider].
  final void Function(SpeciesEnrichment enrichment)? onEnriched;

  /// Secondary hook called after [onEnriched]. Set by [gameCoordinatorProvider]
  /// to update the in-memory enrichment cache and backfill intrinsic affixes
  /// for items whose enrichment arrived via the startup requeue path.
  /// Mutable so it can be wired after provider construction.
  void Function(SpeciesEnrichment enrichment)? onEnrichedHook;

  static const _maxConcurrent = 2;
  static const _minIntervalMs = 4200;

  final Queue<_EnrichmentRequest> _queue = Queue();
  final Set<String> _inFlight = {};
  int _activeRequests = 0;
  DateTime _lastRequestTime = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _drainTimer;
  bool _rateLimited = false;

  Future<void> requestEnrichment({
    required String definitionId,
    required String scientificName,
    required String commonName,
    required String taxonomicClass,
    bool force = false,
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
    ));
    _inFlight.add(definitionId);
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
    while (_queue.isNotEmpty &&
        _activeRequests < _maxConcurrent &&
        !_rateLimited) {
      final request = _queue.removeFirst();
      _activeRequests++;
      _lastRequestTime = DateTime.now();

      _executeRequest(request).whenComplete(() {
        _activeRequests--;
        _scheduleDrain();
      });

      if (_queue.isNotEmpty && _activeRequests < _maxConcurrent) {
        await Future<void>.delayed(
            const Duration(milliseconds: _minIntervalMs));
      }
    }
  }

  Future<void> _executeRequest(
    _EnrichmentRequest request, {
    bool isRetry = false,
  }) async {
    final client = supabaseClient;
    if (client == null) {
      debugPrint('[EnrichmentService] _executeRequest: client null, '
          'skipping ${request.definitionId}');
      return;
    }

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
        body: {
          'definition_id': request.definitionId,
          'scientific_name': request.scientificName,
          'common_name': request.commonName,
          'taxonomic_class': request.taxonomicClass,
          if (validClasses != null) 'valid_animal_classes': validClasses,
          if (request.force) 'force': true,
        },
      );

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
          onEnriched?.call(enrichment);
          onEnrichedHook?.call(enrichment);
        }
      }
    } on FunctionException catch (e) {
      if (e.status == 429) {
        _handleRateLimit(request);
        return;
      }
      // 401 = JWT rejected by Edge Function gateway. Refresh the session
      // and retry once — covers stale tokens after web session restore.
      if (e.status == 401 && !isRetry) {
        debugPrint('[EnrichmentService] 401 for ${request.definitionId} '
            '— refreshing session and retrying');
        try {
          await client.auth.refreshSession();
          await _executeRequest(request, isRetry: true);
          return;
        } catch (refreshErr) {
          debugPrint('[EnrichmentService] refresh + retry failed for '
              '${request.definitionId}: $refreshErr');
          return;
        }
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

  void dispose() {
    _drainTimer?.cancel();
  }
}
