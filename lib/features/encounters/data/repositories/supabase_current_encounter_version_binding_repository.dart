import 'package:earth_nova/core/domain/content/content_identity.dart';
import 'package:earth_nova/core/domain/content/current_encounter_version_binding_repository.dart';
import 'package:earth_nova/core/domain/content/encounter_content.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Injectable current-version query that keeps adapter tests independent from
/// Supabase while matching the least-privilege production row shape.
typedef CurrentEncounterVersionBindingQuery = Future<Map<String, Object?>?>
    Function(
  StableContentId<EncounterContent> definitionId,
);
typedef RepositoryLogEvent = void Function(
  String event,
  String category, {
  Map<String, dynamic>? data,
});

/// The only production projection used to bind a Cell Visit selection.
///
/// It deliberately excludes authored content, Options, Outcomes, and Outcome
/// payloads: the planner needs only the stable Definition/current Version
/// identity, revision, and publication state.
const currentEncounterVersionBindingSelect = 'id,current_published_version_id,'
    'current_version:v3_encounter_definition_versions!'
    'v3_encounter_definitions_current_published_version_owner_fk('
    'id,encounter_definition_id,revision,publication_status)';

/// Supabase adapter for the immutable Version binding required by Cell Visit
/// planning. This is intentionally separate from the full authored-content
/// repository used for exact content reads elsewhere.
final class SupabaseCurrentEncounterVersionBindingRepository
    implements CurrentEncounterVersionBindingRepository {
  static const _category = 'encounters.current_version_binding_repository';

  SupabaseCurrentEncounterVersionBindingRepository({
    required SupabaseClient? client,
    CurrentEncounterVersionBindingQuery? currentQuery,
    RepositoryLogEvent? logEvent,
  })  : _client = client,
        _currentQuery = currentQuery,
        _logEvent = logEvent;

  final SupabaseClient? _client;
  final CurrentEncounterVersionBindingQuery? _currentQuery;
  final RepositoryLogEvent? _logEvent;

  factory SupabaseCurrentEncounterVersionBindingRepository.fromSupabase(
    SupabaseClient client, {
    RepositoryLogEvent? logEvent,
  }) =>
      SupabaseCurrentEncounterVersionBindingRepository(
        client: client,
        logEvent: logEvent,
      );

  @override
  Future<ExactVersionRef<EncounterContent>?>
      currentPublishedVersionForNewCellVisit(
    StableContentId<EncounterContent> definitionId, {
    String? traceId,
  }) async {
    try {
      return await _trace<ExactVersionRef<EncounterContent>?>(
        traceId: traceId,
        operation: 'fetch_current_encounter_version_binding',
        rowCount: (binding) => binding == null ? 0 : 1,
        action: () async {
          final row = await _runCurrentQuery(definitionId);
          if (row == null) return null;

          final ownerId = _requiredString(row['id'], 'id');
          if (ownerId != definitionId.value) {
            throw StateError(
              'Current Encounter Definition row does not match its requested owner.',
            );
          }
          final pointerId = _requiredString(
            row['current_published_version_id'],
            'current_published_version_id',
          );
          final version =
              _requiredObject(row['current_version'], 'current_version');
          final binding = ExactVersionRef<EncounterContent>(
            stableId: StableContentId<EncounterContent>(
              _requiredString(
                version['encounter_definition_id'],
                'encounter_definition_id',
              ),
            ),
            versionId: ContentVersionId<EncounterContent>(
              _requiredString(version['id'], 'id'),
            ),
            revision: _requiredRevision(version['revision']),
          );

          if (binding.stableId.value != ownerId) {
            throw StateError(
              'Current Encounter Definition Version does not belong to its stable row.',
            );
          }
          if (binding.versionId.value != pointerId) {
            throw StateError(
              'Current Encounter Definition row does not point to the returned Version.',
            );
          }
          if (version['publication_status'] != 'published') {
            throw StateError(
              'Current Encounter Definition Version must be published.',
            );
          }
          return binding;
        },
      );
    } catch (error) {
      if (error is CurrentEncounterVersionBindingFailure) rethrow;
      throw CurrentEncounterVersionBindingFailure(_safeErrorMessage(error));
    }
  }

  Future<Map<String, Object?>?> _runCurrentQuery(
    StableContentId<EncounterContent> definitionId,
  ) async {
    final query = _currentQuery;
    if (query != null) return query(definitionId);

    final client = _client;
    if (client == null) {
      throw StateError(
        'Supabase client is required when no current Version query is provided.',
      );
    }
    final response = await client
        .from('v3_encounter_definitions')
        .select(currentEncounterVersionBindingSelect)
        .eq('id', definitionId.value)
        .maybeSingle();
    return _externalRowOrNull(response, 'current Encounter Version query');
  }

  Future<T> _trace<T>({
    required String? traceId,
    required String operation,
    required int Function(T result) rowCount,
    required Future<T> Function() action,
  }) async {
    final stopwatch = Stopwatch()..start();
    _logEvent?.call('db.query_started', _category, data: {
      'trace_id': traceId,
      'operation': operation,
    });
    try {
      final result = await action();
      _logEvent?.call('db.query_completed', _category, data: {
        'trace_id': traceId,
        'operation': operation,
        'row_count': rowCount(result),
        'duration_ms': stopwatch.elapsedMilliseconds,
      });
      return result;
    } catch (error) {
      _logEvent?.call('db.query_failed', _category, data: {
        'trace_id': traceId,
        'operation': operation,
        'duration_ms': stopwatch.elapsedMilliseconds,
        'error_type': error.runtimeType.toString(),
        'error_message': _safeErrorMessage(error),
      });
      rethrow;
    }
  }
}

Map<String, Object?>? _externalRowOrNull(Object? value, String field) {
  if (value == null) return null;
  return _requiredObject(value, field);
}

Map<String, Object?> _requiredObject(Object? value, String field) {
  if (value is! Map) {
    throw StateError('$field must be an object.');
  }

  final result = <String, Object?>{};
  for (final entry in value.entries) {
    final key = entry.key;
    if (key is! String) {
      throw StateError('$field keys must be strings.');
    }
    result[key] = entry.value;
  }
  return result;
}

String _requiredString(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw StateError('$field must be a non-empty string.');
  }
  return value;
}

int _requiredRevision(Object? value) {
  if (value is! int || value <= 0) {
    throw StateError('revision must be a positive integer.');
  }
  return value;
}

String _safeErrorMessage(Object error) => switch (error) {
      StateError() => 'invalid_repository_response',
      _ => 'repository_operation_failed',
    };
