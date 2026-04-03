/// Expected table names for native database integrity check.
///
/// Used by [connection_native.dart] to verify the database schema after open.
/// If any table is missing, the file is deleted and recreated from scratch.
const Set<String> kExpectedTableNames = {
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
};
