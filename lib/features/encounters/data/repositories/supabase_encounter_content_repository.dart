import 'package:earth_nova/core/domain/content/authored_content_snapshot.dart';
import 'package:earth_nova/core/domain/content/content_identity.dart';
import 'package:earth_nova/core/domain/content/encounter_content.dart';
import 'package:earth_nova/core/domain/content/encounter_content_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// An injectable current-content query used to keep adapter tests independent
/// of Supabase.
typedef EncounterCurrentContentQuery = Future<Map<String, Object?>?> Function(
  StableContentId<EncounterContent> stableId,
);

/// An injectable exact-content query used to keep adapter tests independent of
/// Supabase.
typedef EncounterExactContentQuery = Future<Map<String, Object?>?> Function(
  ContentVersionId<EncounterContent> versionId,
);
typedef RepositoryLogEvent = void Function(
  String event,
  String category, {
  Map<String, dynamic>? data,
});

/// Supabase-backed read adapter for immutable authored Encounter Definition
/// Versions.
///
/// This adapter intentionally has no write operations and remains unwired until
/// a later Encounter slice needs authored content.
final class SupabaseEncounterContentRepository
    implements EncounterContentRepository {
  static const _category = 'encounters.content_repository';

  SupabaseEncounterContentRepository({
    required SupabaseClient? client,
    EncounterCurrentContentQuery? currentQuery,
    EncounterExactContentQuery? exactQuery,
    RepositoryLogEvent? logEvent,
  })  : _client = client,
        _currentQuery = currentQuery,
        _exactQuery = exactQuery,
        _logEvent = logEvent;

  final SupabaseClient? _client;
  final EncounterCurrentContentQuery? _currentQuery;
  final EncounterExactContentQuery? _exactQuery;
  final RepositoryLogEvent? _logEvent;

  /// Creates the production adapter with Supabase-backed queries.
  factory SupabaseEncounterContentRepository.fromSupabase(
    SupabaseClient client, {
    RepositoryLogEvent? logEvent,
  }) =>
      SupabaseEncounterContentRepository(client: client, logEvent: logEvent);

  @override
  Future<AuthoredContentSnapshot<EncounterContent>?>
      currentPublishedForNewState(
    StableContentId<EncounterContent> stableId,
  ) async {
    return _trace<AuthoredContentSnapshot<EncounterContent>?>(
      operation: 'fetch_current_encounter_content',
      rowCount: (snapshot) => snapshot == null ? 0 : 1,
      action: () async {
        final row = await _runCurrentQuery(stableId);
        if (row == null) return null;

        final rowOwnerId = _requiredString(row['id'], 'id');
        if (rowOwnerId != stableId.value) {
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
        final snapshot = _snapshotFromVersion(version);

        if (snapshot.reference.stableId.value != rowOwnerId) {
          throw StateError(
            'Current Encounter Definition Version does not belong to its stable row.',
          );
        }
        if (snapshot.reference.versionId.value != pointerId) {
          throw StateError(
            'Current Encounter Definition row does not point to the returned Version.',
          );
        }
        if (snapshot.publicationState != PublicationState.published) {
          throw StateError(
            'Current Encounter Definition Version must be published.',
          );
        }
        return snapshot;
      },
    );
  }

  @override
  Future<AuthoredContentSnapshot<EncounterContent>?>
      exactVersionForExistingState(
    ContentVersionId<EncounterContent> versionId,
  ) async {
    return _trace<AuthoredContentSnapshot<EncounterContent>?>(
      operation: 'fetch_exact_encounter_content',
      rowCount: (snapshot) => snapshot == null ? 0 : 1,
      action: () async {
        final row = await _runExactQuery(versionId);
        if (row == null) return null;

        final snapshot = _snapshotFromVersion(row);
        if (snapshot.reference.versionId != versionId) {
          throw StateError(
              'Exact Encounter query returned a different Version.');
        }
        if (snapshot.publicationState == PublicationState.draft) {
          throw StateError(
            'Existing state cannot read a draft Encounter Version.',
          );
        }
        return snapshot;
      },
    );
  }

  Future<Map<String, Object?>?> _runCurrentQuery(
    StableContentId<EncounterContent> stableId,
  ) async {
    final query = _currentQuery;
    if (query != null) return query(stableId);

    final client = _requiredClient();
    final response = await client
        .from('v3_encounter_definitions')
        .select(
          'id,current_published_version_id,'
          'current_version:v3_encounter_definition_versions!'
          'v3_encounter_definitions_current_published_version_owner_fk('
          'id,encounter_definition_id,revision,publication_status,display_name,'
          'eligibility_condition_id,is_automatic,'
          'options:v3_encounter_options('
          'id,ordinal,display_name,condition_id,is_implicit,'
          'outcomes:v3_encounter_outcomes(id,ordinal,kind,payload)))',
        )
        .eq('id', stableId.value)
        .maybeSingle();
    return _externalRowOrNull(response, 'current Encounter query');
  }

  Future<Map<String, Object?>?> _runExactQuery(
    ContentVersionId<EncounterContent> versionId,
  ) async {
    final query = _exactQuery;
    if (query != null) return query(versionId);

    final client = _requiredClient();
    final response = await client
        .from('v3_encounter_definition_versions')
        .select(
          'id,encounter_definition_id,revision,publication_status,display_name,'
          'eligibility_condition_id,is_automatic,'
          'options:v3_encounter_options('
          'id,ordinal,display_name,condition_id,is_implicit,'
          'outcomes:v3_encounter_outcomes(id,ordinal,kind,payload))',
        )
        .eq('id', versionId.value)
        .maybeSingle();
    final row = _externalRowOrNull(response, 'exact Encounter query');
    return row == null ? null : _withAuthoredContent(row);
  }

  SupabaseClient _requiredClient() {
    final client = _client;
    if (client == null) {
      throw StateError(
        'Supabase client is required when no Encounter content query is provided.',
      );
    }
    return client;
  }

  AuthoredContentSnapshot<EncounterContent> _snapshotFromVersion(
    Map<String, Object?> row,
  ) {
    final version = _withAuthoredContent(row);
    return AuthoredContentSnapshot<EncounterContent>(
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
      publicationState: _publicationState(version['publication_status']),
      authoredContent: _requiredJsonObject(
        version['authored_content'],
        'authored_content',
      ),
    );
  }

  Future<T> _trace<T>({
    required String operation,
    required int Function(T result) rowCount,
    required Future<T> Function() action,
  }) async {
    final stopwatch = Stopwatch()..start();
    _logEvent?.call('db.query_started', _category, data: {
      'trace_id': null,
      'operation': operation,
    });
    try {
      final result = await action();
      _logEvent?.call('db.query_completed', _category, data: {
        'trace_id': null,
        'operation': operation,
        'row_count': rowCount(result),
        'duration_ms': stopwatch.elapsedMilliseconds,
      });
      return result;
    } catch (error) {
      _logEvent?.call('db.query_failed', _category, data: {
        'trace_id': null,
        'operation': operation,
        'duration_ms': stopwatch.elapsedMilliseconds,
        'error_type': error.runtimeType.toString(),
        'error_message': _safeErrorMessage(error),
      });
      rethrow;
    }
  }
}

Map<String, Object?>? _externalRowOrNull(Object? value, String source) {
  if (value == null) return null;
  return _requiredObject(value, source);
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

Map<String, Object?> _withAuthoredContent(Map<String, Object?> row) {
  if (row.containsKey('authored_content')) return row;

  final eligibilityConditionId = row['eligibility_condition_id'];
  if (eligibilityConditionId != null) {
    _requiredString(eligibilityConditionId, 'eligibility_condition_id');
  }
  final automatic = row['is_automatic'];
  if (automatic is! bool) {
    throw StateError('is_automatic must be a boolean.');
  }
  final options = row['options'];
  if (options is! List) {
    throw StateError('options must be a list.');
  }

  return <String, Object?>{
    ...row,
    'authored_content': <String, Object?>{
      'display_name': _requiredString(row['display_name'], 'display_name'),
      'eligibility_condition_id': eligibilityConditionId,
      'is_automatic': automatic,
      'options': options,
    },
  };
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

PublicationState _publicationState(Object? value) => switch (value) {
      'draft' => PublicationState.draft,
      'published' => PublicationState.published,
      'retired' => PublicationState.retired,
      _ => throw StateError(
          'publication_status must be a known publication state.'),
    };

Map<String, Object?> _requiredJsonObject(Object? value, String field) {
  if (value is! Map) {
    throw StateError('$field must be an object.');
  }

  final result = <String, Object?>{};
  for (final entry in value.entries) {
    final key = entry.key;
    if (key is! String) {
      throw StateError('$field keys must be strings.');
    }
    result[key] = _copyJson(entry.value, '$field.$key');
  }
  return Map<String, Object?>.unmodifiable(result);
}

Object? _copyJson(Object? value, String field) {
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  if (value is List) {
    return List<Object?>.unmodifiable(
      value.map((entry) => _copyJson(entry, field)),
    );
  }
  if (value is Map) {
    return _requiredJsonObject(value, field);
  }
  throw StateError('$field contains a non-JSON value.');
}

String _safeErrorMessage(Object error) => switch (error) {
      StateError() ||
      ArgumentError() ||
      FormatException() =>
        'invalid_repository_response',
      _ => 'repository_operation_failed',
    };
