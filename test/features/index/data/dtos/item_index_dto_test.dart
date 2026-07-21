import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/features/index/data/dtos/item_index_dto.dart';
import 'package:earth_nova/features/index/domain/entities/index_entry.dart';
import 'package:earth_nova/features/index/domain/repositories/item_index_repository.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> entry({
  String baseItemId = 'base-a',
  String versionId = 'version-a',
  int revision = 4,
  String category = 'fauna',
  String? scientificName = 'Panthera onca',
  String provenance = 'explicit_identification',
  String discoveredAt = '2026-07-20T10:00:00Z',
}) =>
    {
      'base_item_id': baseItemId,
      'category': category,
      'first_identified_item_id': 'item-$baseItemId',
      'base_item_version_id': versionId,
      'base_item_revision': revision,
      'display_name': 'Jaguar',
      'scientific_name': scientificName,
      'discovery_provenance': provenance,
      'discovered_at': discoveredAt,
    };

Map<String, Object?> payload(List<Object?> entries) => {'entries': entries};

void main() {
  group('ItemIndexDto', () {
    test('retains the first exact Base Item Version and provenance', () {
      final entries = ItemIndexDto.fromJson(payload([entry()])).toDomain();

      expect(entries, hasLength(1));
      final parsed = entries.single;
      expect(parsed.baseItemId.value, 'base-a');
      expect(parsed.category, ItemCategory.fauna);
      expect(parsed.firstIdentifiedItemId, 'item-base-a');
      expect(parsed.firstVersionId.value, 'version-a');
      expect(parsed.firstRevision, 4);
      expect(parsed.discoveryProvenance,
          DiscoveryProvenance.explicitIdentification);
      expect(parsed.discoveredAt, DateTime.utc(2026, 7, 20, 10));
    });

    test('accepts one stable entry with a nullable scientific name', () {
      final entries = ItemIndexDto.fromJson(
        payload([entry(scientificName: null)]),
      ).toDomain();

      expect(entries.single.scientificName, isNull);
      expect(entries.single.firstVersion.stableId, entries.single.baseItemId);
    });

    test('rejects missing and extra response or entry keys', () {
      final missing = <String, Object?>{'entries': <Object?>[]};
      final extraResponse = <String, Object?>{...missing, 'unexpected': true};
      final extraEntry = <String, Object?>{...entry(), 'rarity': 'rare'};

      expect(() => ItemIndexDto.fromJson(extraResponse),
          throwsA(isA<ItemIndexFailure>()));
      expect(() => ItemIndexDto.fromJson(payload([extraEntry])),
          throwsA(isA<ItemIndexFailure>()));
      expect(() => ItemIndexDto.fromJson({'not_entries': []}),
          throwsA(isA<ItemIndexFailure>()));
    });

    test('rejects bad categories, invalid revisions, blank ids, and timestamps',
        () {
      for (final invalid in [
        entry(category: 'legendary'),
        entry(revision: 0),
        entry(baseItemId: '   '),
        entry(discoveredAt: 'not-a-timestamp'),
        entry(discoveredAt: '2026-07-20T10:00:00'),
      ]) {
        expect(
          () => ItemIndexDto.fromJson(payload([invalid])),
          throwsA(isA<ItemIndexFailure>()),
        );
      }
    });

    test('rejects duplicate stable Base Item ids and non-deterministic order',
        () {
      expect(
        () =>
            ItemIndexDto.fromJson(payload([entry(), entry(versionId: 'v-2')])),
        throwsA(isA<ItemIndexFailure>()),
      );
      expect(
        () => ItemIndexDto.fromJson(
          payload([
            entry(baseItemId: 'base-b', discoveredAt: '2026-07-20T10:00:00Z'),
            entry(baseItemId: 'base-a', discoveredAt: '2026-07-20T10:00:00Z'),
          ]),
        ),
        throwsA(isA<ItemIndexFailure>()),
      );
      expect(
        () => ItemIndexDto.fromJson(
          payload([
            entry(discoveredAt: '2026-07-19T10:00:00Z'),
            entry(baseItemId: 'base-b', discoveredAt: '2026-07-20T10:00:00Z'),
          ]),
        ),
        throwsA(isA<ItemIndexFailure>()),
      );
    });
  });
}
