import 'package:earth_nova/features/identification/data/dtos/identification_preparation_dto.dart';
import 'package:flutter_test/flutter_test.dart';

const _itemId = '11111111-1111-4111-8111-111111111111';
const _playerId = '22222222-2222-4222-8222-222222222222';
const _baseItemVersionId = '33333333-3333-4333-8333-333333333333';
const _serviceVersionId = '44444444-4444-4444-8444-444444444444';

Map<String, dynamic> _preparation() => <String, dynamic>{
      'item': <String, dynamic>{
        'id': _itemId,
        'user_id': _playerId,
        'base_item_id': 'fauna:amberwing',
        'base_item_version_id': _baseItemVersionId,
        'base_item_revision': 7,
        'identification_state': 'unidentified',
      },
      'discovery': null,
      'service_access': <String, dynamic>{
        'villager_id': 'villager:rowan',
        'villager_display_name': 'Rowan',
        'service_id': 'service:identify_item_properties',
        'service_version_id': _serviceVersionId,
        'service_version_revision': 2,
        'service_display_name': 'Identification',
      },
      'properties': const <Object?>[],
    };

void main() {
  group('IdentificationPreparationDto service access', () {
    test('parses the exact current Villager Identification Service access', () {
      final preparation =
          IdentificationPreparationDto.fromJson(_preparation()).toDomain();

      final access = preparation.serviceAccess;
      expect(access.villagerId.value, 'villager:rowan');
      expect(access.villagerDisplayName, 'Rowan');
      expect(access.serviceId.value, 'service:identify_item_properties');
      expect(access.serviceVersion.versionId.value, _serviceVersionId);
      expect(access.serviceVersion.revision, 2);
      expect(access.serviceDisplayName, 'Identification');
    });

    test('fails closed when known current service evidence is absent or drifts',
        () {
      final missingAccess = _preparation()..remove('service_access');
      final extraAccessField = _preparation();
      (extraAccessField['service_access'] as Map<String, dynamic>)['venue_id'] =
          'venue:harbor';
      final invalidVersion = _preparation();
      (invalidVersion['service_access']
          as Map<String, dynamic>)['service_version_id'] = 'not-a-uuid';
      final invalidRevision = _preparation();
      (invalidRevision['service_access']
          as Map<String, dynamic>)['service_version_revision'] = 0;

      for (final payload in [
        missingAccess,
        extraAccessField,
        invalidVersion,
        invalidRevision,
      ]) {
        expect(
          () => IdentificationPreparationDto.fromJson(payload),
          throwsStateError,
        );
      }
    });

    test('does not accept a Venue Visit input or an unexamined Item', () {
      final withVenueVisit = _preparation()
        ..['venue_visit'] = <String, dynamic>{'id': _itemId};
      final unexamined = _preparation();
      (unexamined['item'] as Map<String, dynamic>)['identification_state'] =
          'unexamined';

      expect(
        () => IdentificationPreparationDto.fromJson(withVenueVisit),
        throwsStateError,
      );
      expect(
        () => IdentificationPreparationDto.fromJson(unexamined),
        throwsStateError,
      );
    });
  });
}
