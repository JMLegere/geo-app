import 'package:earth_nova/core/domain/content/content_identity.dart';
import 'package:earth_nova/core/domain/content/encounter_content.dart';

import 'package:earth_nova/core/domain/content/current_encounter_version_binding_repository.dart';
import 'package:flutter_test/flutter_test.dart';

final _definitionId = StableContentId<EncounterContent>('encounter:red-fox');
final _version = ExactVersionRef<EncounterContent>(
  stableId: _definitionId,
  versionId: ContentVersionId<EncounterContent>('red-fox-v2'),
  revision: 2,
);

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

  group('CurrentEncounterVersionBinding', () {
    test('keeps automatic policy beside the exact immutable Version', () {
      final automatic = CurrentEncounterVersionBinding(
        version: _version,
        isAutomatic: true,
      );
      final manual = CurrentEncounterVersionBinding(
        version: _version,
        isAutomatic: false,
      );

      expect(automatic.version, _version);
      expect(automatic.isAutomatic, isTrue);
      expect(manual.isAutomatic, isFalse);
    });
  });
}
