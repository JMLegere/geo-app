import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/domain/content/content_identity.dart';

class EncounterDefinition {
  const EncounterDefinition._();
}

class BaseItem {
  const BaseItem._();
}

void main() {
  group('StableContentId', () {
    test('is equal by typed canonical value and has matching hash code', () {
      final first = StableContentId<EncounterDefinition>('encounter.fox');
      final second = StableContentId<EncounterDefinition>('encounter.fox');
      final otherType = StableContentId<BaseItem>('encounter.fox');
      final otherValue = StableContentId<EncounterDefinition>('encounter.wolf');

      expect(first, equals(second));
      expect(first.hashCode, equals(second.hashCode));
      expect(first, isNot(equals(otherType)));
      expect(first, isNot(equals(otherValue)));
      expect(first.value, equals('encounter.fox'));
    });

    test('rejects empty and whitespace-only canonical values', () {
      expect(
        () => StableContentId<EncounterDefinition>(''),
        throwsArgumentError,
      );
      expect(
        () => StableContentId<EncounterDefinition>('   '),
        throwsArgumentError,
      );
    });

    test('trims surrounding whitespace from canonical values', () {
      final id = StableContentId<EncounterDefinition>(' encounter.fox ');

      expect(id.value, equals('encounter.fox'));
    });
  });

  group('ContentVersionId', () {
    test('is equal by typed opaque value and has matching hash code', () {
      final first = ContentVersionId<EncounterDefinition>('encounter.fox.v1');
      final second = ContentVersionId<EncounterDefinition>('encounter.fox.v1');
      final next = ContentVersionId<EncounterDefinition>('encounter.fox.v2');
      final stable = StableContentId<EncounterDefinition>('encounter.fox.v1');

      expect(first, equals(second));
      expect(first.hashCode, equals(second.hashCode));
      expect(first, isNot(equals(next)));
      expect(first, isNot(equals(stable)));
      expect(first.value, equals('encounter.fox.v1'));
    });

    test('rejects empty and whitespace-only opaque values', () {
      expect(
        () => ContentVersionId<EncounterDefinition>(''),
        throwsArgumentError,
      );
      expect(
        () => ContentVersionId<EncounterDefinition>('   '),
        throwsArgumentError,
      );
    });

    test('trims surrounding whitespace from opaque values', () {
      final id = ContentVersionId<EncounterDefinition>(' encounter.fox.v1 ');

      expect(id.value, equals('encounter.fox.v1'));
    });
  });

  group('ExactVersionRef', () {
    test('binds one stable identity to one exact version', () {
      final stableId = StableContentId<EncounterDefinition>('encounter.fox');
      final versionId = ContentVersionId<EncounterDefinition>(
        'encounter.fox.version.3',
      );
      final reference = ExactVersionRef<EncounterDefinition>(
        stableId: stableId,
        versionId: versionId,
        revision: 3,
      );

      expect(reference.stableId, equals(stableId));
      expect(reference.versionId, equals(versionId));
      expect(reference.revision, equals(3));
      expect(
          reference,
          equals(ExactVersionRef<EncounterDefinition>(
            stableId: stableId,
            versionId: versionId,
            revision: 3,
          )));
      expect(
          reference.hashCode,
          equals(ExactVersionRef<EncounterDefinition>(
            stableId: stableId,
            versionId: versionId,
            revision: 3,
          ).hashCode));
    });

    test('distinguishes exact revisions and version identities', () {
      final stableId = StableContentId<EncounterDefinition>('encounter.fox');
      final firstVersion = ContentVersionId<EncounterDefinition>(
        'encounter.fox.version.1',
      );
      final secondVersion = ContentVersionId<EncounterDefinition>(
        'encounter.fox.version.2',
      );
      final first = ExactVersionRef<EncounterDefinition>(
        stableId: stableId,
        versionId: firstVersion,
        revision: 1,
      );
      final sameVersionDifferentRevision = ExactVersionRef<EncounterDefinition>(
        stableId: stableId,
        versionId: firstVersion,
        revision: 2,
      );
      final second = ExactVersionRef<EncounterDefinition>(
        stableId: stableId,
        versionId: secondVersion,
        revision: 1,
      );

      expect(first, isNot(equals(sameVersionDifferentRevision)));
      expect(first, isNot(equals(second)));
      expect(
          first.hashCode, isNot(equals(sameVersionDifferentRevision.hashCode)));
      expect(first.hashCode, isNot(equals(second.hashCode)));
    });

    test('rejects non-positive exact revisions', () {
      final stableId = StableContentId<EncounterDefinition>('encounter.fox');
      final versionId = ContentVersionId<EncounterDefinition>(
        'encounter.fox.version.1',
      );

      expect(
        () => ExactVersionRef<EncounterDefinition>(
          stableId: stableId,
          versionId: versionId,
          revision: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => ExactVersionRef<EncounterDefinition>(
          stableId: stableId,
          versionId: versionId,
          revision: -1,
        ),
        throwsArgumentError,
      );
    });
  });

  group('PublicationState', () {
    test('exposes immutable publication states with value equality', () {
      expect(PublicationState.draft, equals(PublicationState.draft));
      expect(
          PublicationState.published, isNot(equals(PublicationState.retired)));
      expect(PublicationState.published.hashCode,
          equals(PublicationState.published.hashCode));
    });

    test('has only draft, published, and retired states', () {
      expect(PublicationState.values, hasLength(3));
      expect(PublicationState.values, contains(PublicationState.draft));
      expect(PublicationState.values, contains(PublicationState.published));
      expect(PublicationState.values, contains(PublicationState.retired));
    });
  });
}
