import 'package:earth_nova/core/domain/content/current_encounter_version_binding_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CurrentEncounterVersionBindingFailure', () {
    test('retains its safe diagnostic code as its public failure identity', () {
      const failure = CurrentEncounterVersionBindingFailure('version_missing');

      expect(failure.diagnosticCode, 'version_missing');
      expect(
        failure.toString(),
        'CurrentEncounterVersionBindingFailure(version_missing)',
      );
    });
  });
}
