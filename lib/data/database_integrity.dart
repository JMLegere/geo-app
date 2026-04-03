import 'app_database.dart';

Set<String> missingRequiredTables(
  Set<String> existing, {
  Set<String> expected = kExpectedTableNames,
}) {
  return expected.difference(existing);
}

bool hasRequiredTables(
  Set<String> existing, {
  Set<String> expected = kExpectedTableNames,
}) {
  return missingRequiredTables(existing, expected: expected).isEmpty;
}
