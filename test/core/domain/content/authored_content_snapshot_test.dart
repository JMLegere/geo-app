import 'package:earth_nova/core/domain/content/authored_content_snapshot.dart';
import 'package:earth_nova/core/domain/content/base_item_content.dart';
import 'package:earth_nova/core/domain/content/content_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('deeply freezes authored JSON snapshots', () {
    final source = <String, Object?>{
      'nested': <String, Object?>{'name': 'Original'},
      'values': <Object?>['first'],
    };
    final snapshot = AuthoredContentSnapshot<BaseItemContent>(
      stableId: StableContentId<BaseItemContent>('base-item-1'),
      versionId: ContentVersionId<BaseItemContent>('version-1'),
      revision: 1,
      publicationState: PublicationState.published,
      authoredContent: source,
    );

    final nested = snapshot.authoredContent['nested'];
    final values = snapshot.authoredContent['values'];
    if (nested is! Map<String, Object?> || values is! List<Object?>) {
      fail('Authored JSON was not retained with typed nested structures.');
    }

    source['later'] = true;
    final sourceNested = source['nested'];
    final sourceValues = source['values'];
    if (sourceNested is! Map<String, Object?> ||
        sourceValues is! List<Object?>) {
      fail('Test source JSON did not retain nested values.');
    }
    sourceNested['name'] = 'Changed';
    sourceValues.add('second');

    expect(snapshot.authoredContent, isNot(contains('later')));
    expect(nested, <String, Object?>{'name': 'Original'});
    expect(values, <Object?>['first']);
    expect(() => nested['name'] = 'Mutated', throwsUnsupportedError);
    expect(() => values.add('Mutated'), throwsUnsupportedError);
  });

  test('rejects non-finite JSON numbers at their authored content path', () {
    expect(
      () => AuthoredContentSnapshot<BaseItemContent>(
        stableId: StableContentId<BaseItemContent>('base-item-1'),
        versionId: ContentVersionId<BaseItemContent>('version-1'),
        revision: 1,
        publicationState: PublicationState.published,
        authoredContent: {
          'metadata': {'rarity': double.infinity}
        },
      ),
      throwsA(
        isA<ArgumentError>().having(
          (error) => error.name,
          'path',
          'metadata.rarity',
        ),
      ),
    );
  });

  test('rejects authored JSON objects with non-string keys', () {
    expect(
      () => AuthoredContentSnapshot<BaseItemContent>(
        stableId: StableContentId<BaseItemContent>('base-item-1'),
        versionId: ContentVersionId<BaseItemContent>('version-1'),
        revision: 1,
        publicationState: PublicationState.published,
        authoredContent: {
          'metadata': <Object?, Object?>{1: 'not JSON'},
        },
      ),
      throwsA(
        isA<ArgumentError>().having(
          (error) => error.name,
          'path',
          'metadata',
        ),
      ),
    );
  });

  test('rejects non-JSON values nested in authored arrays', () {
    expect(
      () => AuthoredContentSnapshot<BaseItemContent>(
        stableId: StableContentId<BaseItemContent>('base-item-1'),
        versionId: ContentVersionId<BaseItemContent>('version-1'),
        revision: 1,
        publicationState: PublicationState.published,
        authoredContent: {
          'effects': <Object?>['valid', DateTime.utc(2026, 7, 21)],
        },
      ),
      throwsA(
        isA<ArgumentError>().having(
          (error) => error.name,
          'path',
          'effects[1]',
        ),
      ),
    );
  });
}
