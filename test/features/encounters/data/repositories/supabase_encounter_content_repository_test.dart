import 'package:earth_nova/core/domain/content/content_identity.dart';
import 'package:earth_nova/core/domain/content/encounter_content.dart';
import 'package:earth_nova/features/encounters/data/repositories/supabase_encounter_content_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final stableId = StableContentId<EncounterContent>('encounter-1');
  final currentVersionId = ContentVersionId<EncounterContent>('version-2');
  final retiredVersionId = ContentVersionId<EncounterContent>('version-1');

  Map<String, Object?> currentRow({
    String ownerId = 'encounter-1',
    String currentId = 'version-2',
    Object? publicationStatus = 'published',
    Object? revision = 2,
    Object? authoredContent = const <String, Object?>{
      'display_name': 'Current'
    },
  }) =>
      <String, Object?>{
        'id': ownerId,
        'current_published_version_id': currentId,
        'current_version': <String, Object?>{
          'id': currentId,
          'encounter_definition_id': ownerId,
          'revision': revision,
          'publication_status': publicationStatus,
          'authored_content': authoredContent,
        },
      };

  Map<String, Object?> exactRow({
    String versionId = 'version-2',
    String ownerId = 'encounter-1',
    Object? publicationStatus = 'published',
    Object? revision = 2,
    Object? authoredContent = const <String, Object?>{
      'display_name': 'Current'
    },
  }) =>
      <String, Object?>{
        'id': versionId,
        'encounter_definition_id': ownerId,
        'revision': revision,
        'publication_status': publicationStatus,
        'authored_content': authoredContent,
      };

  group('SupabaseEncounterContentRepository current lookup', () {
    test('returns the stable row current published exact Version', () async {
      final repository = SupabaseEncounterContentRepository(
        client: null,
        currentQuery: (_) async => currentRow(),
      );

      final content = await repository.currentPublishedForNewState(stableId);

      expect(content, isNotNull);
      expect(content!.reference.stableId, stableId);
      expect(content.reference.versionId, currentVersionId);
      expect(content.reference.revision, 2);
      expect(content.publicationState, PublicationState.published);
      expect(content.authoredContent,
          <String, Object?>{'display_name': 'Current'});
      expect(
        () => content.authoredContent['display_name'] = 'Changed',
        throwsUnsupportedError,
      );
    });

    test('returns null when no current content exists', () async {
      final repository = SupabaseEncounterContentRepository(
        client: null,
        currentQuery: (_) async => null,
      );

      expect(
        await repository.currentPublishedForNewState(stableId),
        isNull,
      );
    });

    test('rejects malformed current rows', () async {
      final repository = SupabaseEncounterContentRepository(
        client: null,
        currentQuery: (_) async =>
            currentRow(authoredContent: const <Object?>[]),
      );

      expect(
        () => repository.currentPublishedForNewState(stableId),
        throwsStateError,
      );
    });

    test('rejects a current Version with a different stable owner', () async {
      final repository = SupabaseEncounterContentRepository(
        client: null,
        currentQuery: (_) async => currentRow(ownerId: 'other-encounter'),
      );

      expect(
        () => repository.currentPublishedForNewState(stableId),
        throwsStateError,
      );
    });

    test('does not expose a draft current Version', () async {
      final repository = SupabaseEncounterContentRepository(
        client: null,
        currentQuery: (_) async => currentRow(publicationStatus: 'draft'),
      );

      expect(
        () => repository.currentPublishedForNewState(stableId),
        throwsStateError,
      );
    });
  });

  group('SupabaseEncounterContentRepository exact lookup', () {
    test('returns a retired exact Version for existing state', () async {
      final repository = SupabaseEncounterContentRepository(
        client: null,
        exactQuery: (_) async => exactRow(
          versionId: retiredVersionId.value,
          publicationStatus: 'retired',
          revision: 1,
          authoredContent: const <String, Object?>{'display_name': 'Retired'},
        ),
      );

      final content = await repository.exactVersionForExistingState(
        retiredVersionId,
      );

      expect(content, isNotNull);
      expect(content!.reference.versionId, retiredVersionId);
      expect(content.reference.revision, 1);
      expect(content.publicationState, PublicationState.retired);
    });

    test('returns null when an exact Version is missing', () async {
      final repository = SupabaseEncounterContentRepository(
        client: null,
        exactQuery: (_) async => null,
      );

      expect(
        await repository.exactVersionForExistingState(currentVersionId),
        isNull,
      );
    });

    test('never calls the current query for exact retrieval', () async {
      var currentCalls = 0;
      var exactCalls = 0;
      final repository = SupabaseEncounterContentRepository(
        client: null,
        currentQuery: (_) async {
          currentCalls += 1;
          return currentRow();
        },
        exactQuery: (_) async {
          exactCalls += 1;
          return exactRow();
        },
      );

      await repository.exactVersionForExistingState(currentVersionId);

      expect(currentCalls, 0);
      expect(exactCalls, 1);
    });

    test('rejects malformed exact rows and owner mismatches', () async {
      final malformedRepository = SupabaseEncounterContentRepository(
        client: null,
        exactQuery: (_) async => exactRow(publicationStatus: 'unknown'),
      );
      final mismatchRepository = SupabaseEncounterContentRepository(
        client: null,
        exactQuery: (_) async => exactRow(ownerId: '  '),
      );

      expect(
        () =>
            malformedRepository.exactVersionForExistingState(currentVersionId),
        throwsStateError,
      );
      expect(
        () => mismatchRepository.exactVersionForExistingState(currentVersionId),
        throwsStateError,
      );
    });
  });
}
