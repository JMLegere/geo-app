import 'package:flutter_test/flutter_test.dart';
import 'package:fog_of_world/core/models/continent.dart';
import 'package:fog_of_world/core/models/habitat.dart';
import 'package:fog_of_world/core/models/iucn_status.dart';
import 'package:fog_of_world/core/models/item_definition.dart';
import 'package:fog_of_world/features/discovery/models/discovery_event.dart';

void main() {
  final redFox = FaunaDefinition(
    id: 'fauna_vulpes_vulpes',
    displayName: 'Red Fox',
    scientificName: 'Vulpes vulpes',
    taxonomicClass: 'Mammalia',
    continents: [Continent.northAmerica],
    habitats: [Habitat.forest],
    rarity: IucnStatus.leastConcern,
  );

  final timestamp = DateTime(2026, 3, 2, 10, 0, 0);

  group('DiscoveryEvent', () {
    test('stores all constructor fields', () {
      final event = DiscoveryEvent(
        item: redFox,
        cellId: 'cell_42',
        isNew: true,
        timestamp: timestamp,
      );

      expect(event.item, same(redFox));
      expect(event.cellId, equals('cell_42'));
      expect(event.isNew, isTrue);
      expect(event.timestamp, equals(timestamp));
    });

    test('isNew can be false (already collected)', () {
      final event = DiscoveryEvent(
        item: redFox,
        cellId: 'cell_99',
        isNew: false,
        timestamp: timestamp,
      );

      expect(event.isNew, isFalse);
    });

    test('equality: two events with same fields are equal', () {
      final a = DiscoveryEvent(
        item: redFox,
        cellId: 'cell_42',
        isNew: true,
        timestamp: timestamp,
      );
      final b = DiscoveryEvent(
        item: redFox,
        cellId: 'cell_42',
        isNew: true,
        timestamp: timestamp,
      );

      expect(a, equals(b));
    });

    test('equality: events with different cellId are not equal', () {
      final a = DiscoveryEvent(
        item: redFox,
        cellId: 'cell_42',
        isNew: true,
        timestamp: timestamp,
      );
      final b = DiscoveryEvent(
        item: redFox,
        cellId: 'cell_99',
        isNew: true,
        timestamp: timestamp,
      );

      expect(a, isNot(equals(b)));
    });

    test('equality: events with different isNew are not equal', () {
      final a = DiscoveryEvent(
        item: redFox,
        cellId: 'cell_42',
        isNew: true,
        timestamp: timestamp,
      );
      final b = DiscoveryEvent(
        item: redFox,
        cellId: 'cell_42',
        isNew: false,
        timestamp: timestamp,
      );

      expect(a, isNot(equals(b)));
    });

    test('hashCode matches for equal events', () {
      final a = DiscoveryEvent(
        item: redFox,
        cellId: 'cell_42',
        isNew: true,
        timestamp: timestamp,
      );
      final b = DiscoveryEvent(
        item: redFox,
        cellId: 'cell_42',
        isNew: true,
        timestamp: timestamp,
      );

      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString includes item name and cellId', () {
      final event = DiscoveryEvent(
        item: redFox,
        cellId: 'cell_42',
        isNew: true,
        timestamp: timestamp,
      );

      expect(event.toString(), contains('Red Fox'));
      expect(event.toString(), contains('cell_42'));
    });
  });
}
