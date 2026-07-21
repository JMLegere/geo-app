import 'package:earth_nova/core/domain/content/base_item_content.dart';
import 'package:earth_nova/core/domain/content/content_version_id.dart';
import 'package:earth_nova/core/domain/content/exact_version_ref.dart';
import 'package:earth_nova/core/domain/content/stable_content_id.dart';
import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/features/index/domain/entities/index_entry.dart';
import 'package:flutter_test/flutter_test.dart';

IndexEntry _entry({
  String baseItemId = 'item.fox',
  String firstIdentifiedItemId = ' identified-1 ',
  String displayName = ' Red Fox ',
  String? scientificName = ' Vulpes vulpes ',
  ItemCategory category = ItemCategory.fauna,
  DiscoveryProvenance discoveryProvenance =
      DiscoveryProvenance.explicitIdentification,
  DateTime? discoveredAt,
  String? versionId,
  int revision = 3,
  String? versionStableId,
}) {
  final stableId = StableContentId<BaseItemContent>(baseItemId);
  final versionStable = StableContentId<BaseItemContent>(
    versionStableId ?? baseItemId,
  );
  final exactVersion = ExactVersionRef<BaseItemContent>(
    stableId: versionStable,
    versionId: ContentVersionId<BaseItemContent>(
      versionId ?? '$baseItemId.v$revision',
    ),
    revision: revision,
  );

  return IndexEntry(
    baseItemId: stableId,
    category: category,
    firstIdentifiedItemId: firstIdentifiedItemId,
    firstVersion: exactVersion,
    displayName: displayName,
    scientificName: scientificName,
    discoveryProvenance: discoveryProvenance,
    discoveredAt: discoveredAt ?? DateTime.utc(2026, 7, 21, 12),
  );
}

void main() {
  group('DiscoveryProvenance', () {
    test('round-trips every public wire value', () {
      for (final provenance in DiscoveryProvenance.values) {
        expect(
          DiscoveryProvenance.fromWireValue(provenance.wireValue),
          equals(provenance),
        );
      }
    });

    test('rejects unknown wire values', () {
      expect(
        () => DiscoveryProvenance.fromWireValue('manual_override'),
        throwsArgumentError,
      );
    });
  });

  group('IndexEntry', () {
    test('canonicalizes fields and preserves the exact discovery version', () {
      final versionId = ContentVersionId<BaseItemContent>('item.fox.v3');
      final localTime = DateTime.utc(2026, 7, 21, 12).toLocal();
      final entry = _entry(
        discoveredAt: localTime,
        versionId: versionId.value,
      );

      expect(entry.firstIdentifiedItemId, equals('identified-1'));
      expect(entry.displayName, equals('Red Fox'));
      expect(entry.scientificName, equals('Vulpes vulpes'));
      expect(entry.firstVersionId, equals(versionId));
      expect(entry.firstRevision, equals(3));
      expect(entry.discoveredAt.isUtc, isTrue);
      expect(entry.discoveredAt, equals(localTime.toUtc()));
    });

    test('allows an absent scientific name', () {
      final entry = _entry(scientificName: null);

      expect(entry.scientificName, isNull);
    });

    test('rejects a version bound to a different stable identity', () {
      expect(
        () => _entry(versionStableId: 'item.wolf'),
        throwsArgumentError,
      );
    });

    test('rejects blank required and optional display fields', () {
      expect(
        () => _entry(firstIdentifiedItemId: ' \t '),
        throwsArgumentError,
      );
      expect(
        () => _entry(displayName: '\n'),
        throwsArgumentError,
      );
      expect(
        () => _entry(scientificName: '  '),
        throwsArgumentError,
      );
    });

    test('uses all value fields for equality and hash identity', () {
      final first = _entry();
      final same = _entry();

      expect(first, equals(same));
      expect(first.hashCode, equals(same.hashCode));
      expect(first, equals(first));
      expect(first, isNot(equals(_entry(category: ItemCategory.flora))));
      expect(
        first,
        isNot(equals(
            _entry(discoveryProvenance: DiscoveryProvenance.legacyBackfill))),
      );
      expect(
        first,
        isNot(equals(_entry(discoveredAt: DateTime.utc(2026, 7, 22, 12)))),
      );
      expect(
        first,
        isNot(equals(_entry(firstIdentifiedItemId: 'identified-2'))),
      );
      expect(first, isNot(equals(_entry(displayName: 'Gray Fox'))));
      expect(first, isNot(equals(_entry(scientificName: null))));
      expect(
          first, isNot(equals(_entry(versionId: 'item.fox.v4', revision: 4))));
      expect(first, isNot(equals(_entry(baseItemId: 'item.wolf'))));
    });
  });
}
