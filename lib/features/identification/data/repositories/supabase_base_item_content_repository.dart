import 'package:earth_nova/core/domain/content/authored_content_snapshot.dart';
import 'package:earth_nova/core/domain/content/base_item_content.dart';
import 'package:earth_nova/core/domain/content/base_item_content_repository.dart';
import 'package:earth_nova/core/domain/content/content_identity.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// An injectable current-content query used to keep adapter tests independent
/// of Supabase.
typedef BaseItemCurrentContentQuery = Future<Map<String, Object?>?> Function(
  StableContentId<BaseItemContent> stableId,
);

/// An injectable exact-content query used to keep adapter tests independent of
/// Supabase.
typedef BaseItemExactContentQuery = Future<Map<String, Object?>?> Function(
  ContentVersionId<BaseItemContent> versionId,
);
typedef RepositoryLogEvent = void Function(
  String event,
  String category, {
  Map<String, dynamic>? data,
});

/// Supabase-backed read adapter for immutable authored Base Item Versions.
///
/// This adapter intentionally has no write operations and remains unwired until
/// a later Item slice needs authored content.
final class SupabaseBaseItemContentRepository
    implements BaseItemContentRepository {
  static const _category = 'identification.base_item_content_repository';

  SupabaseBaseItemContentRepository({
    required SupabaseClient? client,
    BaseItemCurrentContentQuery? currentQuery,
    BaseItemExactContentQuery? exactQuery,
    RepositoryLogEvent? logEvent,
  })  : _client = client,
        _currentQuery = currentQuery,
        _exactQuery = exactQuery,
        _logEvent = logEvent;

  final SupabaseClient? _client;
  final BaseItemCurrentContentQuery? _currentQuery;
  final BaseItemExactContentQuery? _exactQuery;
  final RepositoryLogEvent? _logEvent;

  /// Creates the production adapter with Supabase-backed queries.
  factory SupabaseBaseItemContentRepository.fromSupabase(
    SupabaseClient client, {
    RepositoryLogEvent? logEvent,
  }) =>
      SupabaseBaseItemContentRepository(client: client, logEvent: logEvent);

  @override
  Future<AuthoredContentSnapshot<BaseItemContent>?> currentPublishedForNewState(
    StableContentId<BaseItemContent> stableId,
  ) async {
    return _trace<AuthoredContentSnapshot<BaseItemContent>?>(
      operation: 'fetch_current_base_item_content',
      rowCount: (snapshot) => snapshot == null ? 0 : 1,
      action: () async {
        final row = await _runCurrentQuery(stableId);
        if (row == null) return null;

        final rowOwnerId = _requiredString(row['id'], 'id');
        if (rowOwnerId != stableId.value) {
          throw StateError(
            'Current Base Item row does not match its requested owner.',
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
            'Current Base Item Version does not belong to its stable row.',
          );
        }
        if (snapshot.reference.versionId.value != pointerId) {
          throw StateError(
            'Current Base Item row does not point to the returned Version.',
          );
        }
        if (snapshot.publicationState != PublicationState.published) {
          throw StateError('Current Base Item Version must be published.');
        }
        return snapshot;
      },
    );
  }

  @override
  Future<AuthoredContentSnapshot<BaseItemContent>?>
      exactVersionForExistingState(
    ContentVersionId<BaseItemContent> versionId,
  ) async {
    return _trace<AuthoredContentSnapshot<BaseItemContent>?>(
      operation: 'fetch_exact_base_item_content',
      rowCount: (snapshot) => snapshot == null ? 0 : 1,
      action: () async {
        final row = await _runExactQuery(versionId);
        if (row == null) return null;

        final snapshot = _snapshotFromVersion(row);
        if (snapshot.reference.versionId != versionId) {
          throw StateError(
              'Exact Base Item query returned a different Version.');
        }
        if (snapshot.publicationState == PublicationState.draft) {
          throw StateError(
              'Existing state cannot read a draft Base Item Version.');
        }
        return snapshot;
      },
    );
  }

  Future<Map<String, Object?>?> _runCurrentQuery(
    StableContentId<BaseItemContent> stableId,
  ) async {
    final query = _currentQuery;
    if (query != null) return query(stableId);

    final client = _requiredClient();
    final response = await client
        .from('v3_base_items')
        .select(
          'id,current_published_version_id,'
          'current_version:v3_base_item_versions!'
          'v3_base_items_current_published_version_owner_fk('
          'id,base_item_id,revision,publication_status,authored_content)',
        )
        .eq('id', stableId.value)
        .maybeSingle();
    return _externalRowOrNull(response, 'current Base Item query');
  }

  Future<Map<String, Object?>?> _runExactQuery(
    ContentVersionId<BaseItemContent> versionId,
  ) async {
    final query = _exactQuery;
    if (query != null) return query(versionId);

    final client = _requiredClient();
    final response = await client
        .from('v3_base_item_versions')
        .select('id,base_item_id,revision,publication_status,authored_content')
        .eq('id', versionId.value)
        .maybeSingle();
    return _externalRowOrNull(response, 'exact Base Item query');
  }

  SupabaseClient _requiredClient() {
    final client = _client;
    if (client == null) {
      throw StateError(
        'Supabase client is required when no Base Item content query is provided.',
      );
    }
    return client;
  }

  AuthoredContentSnapshot<BaseItemContent> _snapshotFromVersion(
    Map<String, Object?> row,
  ) =>
      AuthoredContentSnapshot<BaseItemContent>(
        stableId: StableContentId<BaseItemContent>(
          _requiredString(row['base_item_id'], 'base_item_id'),
        ),
        versionId: ContentVersionId<BaseItemContent>(
          _requiredString(row['id'], 'id'),
        ),
        revision: _requiredRevision(row['revision']),
        publicationState: _publicationState(row['publication_status']),
        authoredContent: _requiredJsonObject(
          row['authored_content'],
          'authored_content',
        ),
      );

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
