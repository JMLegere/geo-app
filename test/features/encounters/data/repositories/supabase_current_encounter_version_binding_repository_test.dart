import 'package:earth_nova/core/domain/content/content_identity.dart';
import 'package:earth_nova/core/domain/content/encounter_content.dart';
import 'package:earth_nova/core/domain/content/current_encounter_version_binding_repository.dart';
import 'package:earth_nova/features/encounters/data/repositories/supabase_current_encounter_version_binding_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final definitionId = StableContentId<EncounterContent>('encounter-1');

  Map<String, Object?> currentRow({
    String ownerId = 'encounter-1',
    String pointerId = 'version-2',
    String versionId = 'version-2',
    Object? revision = 2,
    Object? publicationStatus = 'published',
    Object? isAutomatic = false,
  }) =>
      <String, Object?>{
        'id': ownerId,
        'current_published_version_id': pointerId,
        'current_version': <String, Object?>{
          'id': versionId,
          'encounter_definition_id': ownerId,
          'revision': revision,
          'publication_status': publicationStatus,
          'is_automatic': isAutomatic,
        },
      };

  test('binds the selected Definition to its exact published revision',
      () async {
    final repository = SupabaseCurrentEncounterVersionBindingRepository(
      client: null,
      currentQuery: (_) async => currentRow(revision: 7),
    );

    final binding =
        await repository.currentPublishedVersionForNewCellVisit(definitionId);

    expect(binding, isNotNull);
    expect(binding!.version.stableId, definitionId);
    expect(binding.version.versionId.value, 'version-2');
    expect(binding.version.revision, 7);
    expect(binding.isAutomatic, isFalse);
  });

  test('parses automatic policy with the exact published revision', () async {
    final repository = SupabaseCurrentEncounterVersionBindingRepository(
      client: null,
      currentQuery: (_) async => currentRow(isAutomatic: true),
    );

    final binding =
        await repository.currentPublishedVersionForNewCellVisit(definitionId);

    expect(binding!.isAutomatic, isTrue);
    expect(binding.version.revision, 2);
  });

  test('returns null when the selected Definition has no current Version',
      () async {
    final repository = SupabaseCurrentEncounterVersionBindingRepository(
      client: null,
      currentQuery: (_) async => null,
    );

    expect(
      await repository.currentPublishedVersionForNewCellVisit(definitionId),
      isNull,
    );
  });

  test('rejects a mismatched pointer, owner, revision, or publication state',
      () {
    Future<Object?> read(Map<String, Object?> row) {
      return SupabaseCurrentEncounterVersionBindingRepository(
        client: null,
        currentQuery: (_) async => row,
      ).currentPublishedVersionForNewCellVisit(definitionId);
    }

    expect(
      () => read(currentRow(pointerId: 'other-version')),
      throwsA(isA<CurrentEncounterVersionBindingFailure>()),
    );
    expect(
      () => read(currentRow(ownerId: 'other-definition')),
      throwsA(isA<CurrentEncounterVersionBindingFailure>()),
    );
    expect(
      () => read(currentRow(revision: 0)),
      throwsA(isA<CurrentEncounterVersionBindingFailure>()),
    );
    expect(
      () => read(currentRow(publicationStatus: 'retired')),
      throwsA(isA<CurrentEncounterVersionBindingFailure>()),
    );
    expect(
      () => read(currentRow(isAutomatic: 'true')),
      throwsA(isA<CurrentEncounterVersionBindingFailure>()),
    );
  });

  test('emits query terminal telemetry with safe failure diagnostics',
      () async {
    final events = <Map<String, Object?>>[];
    final success = SupabaseCurrentEncounterVersionBindingRepository(
      client: null,
      currentQuery: (_) async => currentRow(),
      logEvent: (event, category, {data}) =>
          events.add({'event': event, 'category': category, 'data': data}),
    );

    await success.currentPublishedVersionForNewCellVisit(
      definitionId,
      traceId: 'binding-trace',
    );
    expect(events.map((event) => event['event']), [
      'db.query_started',
      'db.query_completed',
    ]);
    expect((events.last['data'] as Map)['operation'],
        'fetch_current_encounter_version_binding');
    expect((events.last['data'] as Map)['duration_ms'], isA<int>());

    final failure = SupabaseCurrentEncounterVersionBindingRepository(
      client: null,
      currentQuery: (_) async =>
          throw StateError('postgres://credentials@host/internal-secret'),
      logEvent: (event, category, {data}) =>
          events.add({'event': event, 'category': category, 'data': data}),
    );
    await expectLater(
      failure.currentPublishedVersionForNewCellVisit(definitionId),
      throwsA(
        isA<CurrentEncounterVersionBindingFailure>().having(
            (error) => error.diagnosticCode,
            'diagnosticCode',
            'invalid_repository_response'),
      ),
    );
    expect(events.last['event'], 'db.query_failed');
    final failureData = events.last['data'] as Map;
    expect(failureData['error_message'], 'invalid_repository_response');
    expect(failureData.values.join(), isNot(contains('internal-secret')));
  });
  test(
      'production select has only current identity and publication binding fields',
      () {
    expect(
      currentEncounterVersionBindingSelect,
      contains('id,current_published_version_id'),
    );
    expect(currentEncounterVersionBindingSelect,
        contains('encounter_definition_id'));
    expect(currentEncounterVersionBindingSelect, contains('revision'));
    expect(
        currentEncounterVersionBindingSelect, contains('publication_status'));
    expect(currentEncounterVersionBindingSelect, contains('is_automatic'));
    expect(currentEncounterVersionBindingSelect, isNot(contains('options')));
    expect(currentEncounterVersionBindingSelect, isNot(contains('outcomes')));
    expect(currentEncounterVersionBindingSelect, isNot(contains('payload')));
  });
}
