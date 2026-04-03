import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/data/app_database.dart';
import 'package:earth_nova/data/database_integrity.dart';

void main() {
  group('database integrity helpers', () {
    test('expected table names include all app tables', () {
      expect(
        kExpectedTableNames,
        containsAll(<String>{
          'players_table',
          'species_table',
          'items_table',
          'cell_visits_table',
          'cell_properties_table',
          'countries_table',
          'states_table',
          'cities_table',
          'districts_table',
          'write_queue_table',
        }),
      );
      expect(kExpectedTableNames, hasLength(10));
    });

    test('missingRequiredTables returns missing tables', () {
      final existing = <String>{
        'players_table',
        'items_table',
        'cell_visits_table',
        'cell_properties_table',
        'countries_table',
        'states_table',
        'cities_table',
        'districts_table',
        'write_queue_table',
      };

      expect(missingRequiredTables(existing), {'species_table'});
      expect(hasRequiredTables(existing), isFalse);
    });

    test('hasRequiredTables returns true when all expected tables exist', () {
      expect(hasRequiredTables(kExpectedTableNames), isTrue);
      expect(missingRequiredTables(kExpectedTableNames), isEmpty);
    });
  });
}
