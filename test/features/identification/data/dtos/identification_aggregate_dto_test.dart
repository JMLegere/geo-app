import 'package:earth_nova/core/domain/content/base_item_content.dart';
import 'package:earth_nova/core/domain/content/content_identity.dart';
import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/features/identification/data/dtos/identification_aggregate_dto.dart';
import 'package:earth_nova/features/identification/domain/entities/identification_entities.dart';
import 'package:earth_nova/features/living_world/domain/entities/authored_living_world_entities.dart';
import 'package:earth_nova/features/item_knowledge/domain/entities/item_knowledge_entities.dart';
import 'package:flutter_test/flutter_test.dart';

const _itemId = '11111111-1111-4111-8111-111111111111';
const _playerId = '22222222-2222-4222-8222-222222222222';
const _versionId = '33333333-3333-4333-8333-333333333333';
const _firstCandidateId = '44444444-4444-4444-8444-444444444444';
const _secondCandidateId = '55555555-5555-4555-8555-555555555555';

final _baseItemId = StableContentId<BaseItemContent>('fauna:amberwing');
final _exactVersion = ExactVersionRef<BaseItemContent>(
  stableId: _baseItemId,
  versionId: ContentVersionId<BaseItemContent>(_versionId),
  revision: 7,
);
final _itemRef = ItemKnowledgeItemRef(
  id: ItemKnowledgeItemId(_itemId),
  playerId: _playerId,
  baseItemId: _baseItemId,
  baseItemVersion: _exactVersion,
);

final _serviceAccess = IdentificationServiceAccess(
  villagerId: VillagerId('villager:rowan'),
  villagerDisplayName: 'Rowan',
  serviceId: ServiceId('service:identify_item_properties'),
  serviceVersion: ExactVersionRef<ServiceContent>(
    stableId: StableContentId<ServiceContent>(
      'service:identify_item_properties',
    ),
    versionId: ContentVersionId<ServiceContent>(
      '66666666-6666-4666-8666-666666666666',
    ),
    revision: 2,
  ),
  serviceDisplayName: 'Identification',
);
final _coat = VariablePropertyDefinition(
  id: VariablePropertyDefinitionId('coat-color'),
  baseItemId: _baseItemId,
  baseItemVersion: _exactVersion,
  selectorId: PropertySelectorId('coat-selector'),
);
final _song = VariablePropertyDefinition(
  id: VariablePropertyDefinitionId('song-type'),
  baseItemId: _baseItemId,
  baseItemVersion: _exactVersion,
  selectorId: PropertySelectorId('song-selector'),
);

ItemIdentificationPlan _plan() => ItemIdentificationPlan(
      item: _itemRef,
      serviceAccess: _serviceAccess,
      propertyResolutions: [
        PlannedPropertyResolution(
          ordinal: 0,
          definition: _coat,
          selectorCandidateId: PropertySelectorCandidateId(_firstCandidateId),
          resolution: SelectedPropertyValue('russet'),
        ),
        PlannedPropertyResolution(
          ordinal: 1,
          definition: _song,
          selectorCandidateId: PropertySelectorCandidateId(_secondCandidateId),
          resolution: const NoPropertyValue(),
        ),
      ],
    );

Map<String, dynamic> _item() => {
      'id': _itemId,
      'user_id': _playerId,
      'definition_id': 'amberwing-warbler',
      'display_name': 'Amberwing Warbler',
      'scientific_name': 'Setophaga amberia',
      'category': 'fauna',
      'rarity': 'rare',
      'icon_url': 'https://example.test/icon.png',
      'icon_url_frame2': null,
      'art_url': null,
      'acquired_at': '2026-01-02T03:04:05Z',
      'acquired_in_cell_id': null,
      'status': 'active',
      'taxonomic_class': 'Aves',
      'habitats_json': '["forest"]',
      'continents_json': '["North America"]',
      'identification_state': 'identified',
      'identified_at': '2026-01-02T04:05:06Z',
      'base_item_id': _baseItemId.value,
      'base_item_version_id': _versionId,
      'base_item_revision': 7,
    };

Map<String, dynamic> _discovery() => {
      'user_id': _playerId,
      'base_item_id': _baseItemId.value,
      'first_identified_item_id': _itemId,
      'first_base_item_version_id': _versionId,
      'provenance': 'explicit_identification',
      'discovered_at': '2026-01-02T04:05:06Z',
    };

Map<String, dynamic> _value({
  required int ordinal,
  required VariablePropertyDefinition definition,
  required String candidateId,
  required String kind,
  required String? valueId,
}) =>
    {
      'ordinal': ordinal,
      'variable_property_key': definition.id.value,
      'selector_id': definition.selectorId.value,
      'selector_candidate_id': candidateId,
      'resolution_kind': kind,
      'resolved_value_id': valueId,
      'resolved_at': '2026-01-02T04:05:06.123Z',
    };

Map<String, dynamic> _aggregate() => {
      'item': _item(),
      'discovery': _discovery(),
      'property_values': [
        _value(
          ordinal: 0,
          definition: _coat,
          candidateId: _firstCandidateId,
          kind: 'value',
          valueId: 'russet',
        ),
        _value(
          ordinal: 1,
          definition: _song,
          candidateId: _secondCandidateId,
          kind: 'none',
          valueId: null,
        ),
      ],
      'identification': {
        'kind': 'explicit',
        'committed_at': '2026-01-02T04:05:06+00:00',
      },
    };

void main() {
  group('IdentificationAggregateDto.fromJson', () {
    test('binds the committed aggregate to the supplied exact plan', () {
      final result =
          IdentificationAggregateDto.fromJson(_aggregate(), plan: _plan())
              .toDomain();

      expect(result.item, _itemRef);
      expect(result.committedItem.identificationState,
          ItemIdentificationState.identified);
      expect(result.committedItem.baseItemVersionId, _versionId);
      expect(result.discovery.playerId, _playerId);
      expect(result.discovery.baseItemId, _baseItemId);
      expect(result.propertyValues.map((value) => value.resolution), [
        SelectedPropertyValue('russet'),
        const NoPropertyValue(),
      ]);
      expect(result.identification, _plan());
    });

    test('rejects a response whose exact item binding is from another version',
        () {
      final json = _aggregate();
      (json['item'] as Map<String, dynamic>)['base_item_version_id'] =
          '66666666-6666-4666-8666-666666666666';

      expect(
        () => IdentificationAggregateDto.fromJson(json, plan: _plan()),
        throwsStateError,
      );
    });

    test('rejects replayed property evidence with another candidate or outcome',
        () {
      final wrongCandidate = _aggregate();
      ((wrongCandidate['property_values'] as List)[0]
              as Map<String, dynamic>)['selector_candidate_id'] =
          '66666666-6666-4666-8666-666666666666';
      final wrongNone = _aggregate();
      ((wrongNone['property_values'] as List)[1]
          as Map<String, dynamic>)['resolved_value_id'] = 'leaked-value';

      expect(
        () =>
            IdentificationAggregateDto.fromJson(wrongCandidate, plan: _plan()),
        throwsStateError,
      );
      expect(
        () => IdentificationAggregateDto.fromJson(wrongNone, plan: _plan()),
        throwsStateError,
      );
    });

    test('rejects malformed aggregate boundaries instead of accepting extras',
        () {
      final extraRoot = _aggregate()..['unexpected'] = true;
      final incompleteValues = _aggregate()
        ..['property_values'] = <Object>[
          _value(
            ordinal: 0,
            definition: _coat,
            candidateId: _firstCandidateId,
            kind: 'value',
            valueId: 'russet',
          ),
        ];
      final invalidReceipt = _aggregate();
      (invalidReceipt['identification'] as Map<String, dynamic>)['kind'] =
          'implicit';

      expect(
        () => IdentificationAggregateDto.fromJson(extraRoot, plan: _plan()),
        throwsStateError,
      );
      expect(
        () => IdentificationAggregateDto.fromJson(incompleteValues,
            plan: _plan()),
        throwsStateError,
      );
      expect(
        () =>
            IdentificationAggregateDto.fromJson(invalidReceipt, plan: _plan()),
        throwsStateError,
      );
    });
  });
}
