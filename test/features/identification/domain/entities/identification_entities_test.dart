import 'package:earth_nova/core/domain/content/base_item_content.dart';
import 'package:earth_nova/core/domain/content/content_identity.dart';
import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/core/domain/rules/selector.dart';
import 'package:earth_nova/features/identification/domain/entities/identification_entities.dart';
import 'package:earth_nova/features/item_knowledge/domain/entities/item_knowledge_entities.dart';
import 'package:earth_nova/features/living_world/domain/entities/authored_living_world_entities.dart';
import 'package:flutter_test/flutter_test.dart';

final _baseItemId = StableContentId<BaseItemContent>('fauna:amberwing');
final _exactVersion = ExactVersionRef<BaseItemContent>(
  stableId: _baseItemId,
  versionId: ContentVersionId<BaseItemContent>('base-item-version-7'),
  revision: 7,
);
final _otherVersion = ExactVersionRef<BaseItemContent>(
  stableId: _baseItemId,
  versionId: ContentVersionId<BaseItemContent>('base-item-version-6'),
  revision: 6,
);
final _item = ItemKnowledgeItemRef(
  id: ItemKnowledgeItemId('item-amberwing'),
  playerId: 'player-1',
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
      'service-version-2',
    ),
    revision: 2,
  ),
  serviceDisplayName: 'Identification',
);

VariablePropertyDefinition _definition(
  String id, {
  ExactVersionRef<BaseItemContent>? version,
}) =>
    VariablePropertyDefinition(
      id: VariablePropertyDefinitionId(id),
      baseItemId: _baseItemId,
      baseItemVersion: version ?? _exactVersion,
      selectorId: PropertySelectorId('$id-selector'),
    );

IdentificationProperty _property({
  required int ordinal,
  required VariablePropertyDefinition definition,
  String candidateId = 'candidate-1',
  String value = 'russet',
}) =>
    IdentificationProperty(
      ordinal: ordinal,
      definition: definition,
      selector: Selector<String, Object?>(
        candidates: [
          SelectorCandidate<String, Object?>.value(
            id: candidateId,
            value: value,
            weight: 1,
          ),
        ],
      ),
      expectedSelectorCandidateId: PropertySelectorCandidateId(candidateId),
    );

PlannedPropertyResolution _resolution({
  required int ordinal,
  required VariablePropertyDefinition definition,
  String candidateId = 'candidate-1',
  PropertyValueResolution? resolution,
}) =>
    PlannedPropertyResolution(
      ordinal: ordinal,
      definition: definition,
      selectorCandidateId: PropertySelectorCandidateId(candidateId),
      resolution: resolution ?? SelectedPropertyValue('russet'),
    );

Item _committedItem({
  ItemIdentificationState state = ItemIdentificationState.identified,
}) =>
    Item(
      id: _item.id.value,
      definitionId: 'amberwing-warbler',
      baseItemId: _item.baseItemId.value,
      baseItemVersionId: _item.baseItemVersion.versionId.value,
      displayName: 'Amberwing Warbler',
      category: ItemCategory.fauna,
      acquiredAt: DateTime.utc(2026, 1, 2),
      status: ItemStatus.active,
      identificationState: state,
    );

void main() {
  group('Identification value objects', () {
    test('use structural selector equality and retain defensive list snapshots',
        () {
      final definition = _definition('coat-color');
      final input = [_property(ordinal: 0, definition: definition)];
      final first = IdentificationPreparation(
        item: _item,
        playerDiscovered: false,
        properties: input,
        serviceAccess: _serviceAccess,
      );
      final equivalent = IdentificationPreparation(
        item: _item,
        playerDiscovered: false,
        properties: [_property(ordinal: 0, definition: definition)],
        serviceAccess: _serviceAccess,
      );

      final differentSelector = IdentificationPreparation(
        item: _item,
        playerDiscovered: false,
        properties: [
          _property(
            ordinal: 0,
            definition: definition,
            candidateId: 'other-candidate',
          ),
        ],
        serviceAccess: _serviceAccess,
      );

      input.clear();

      expect(first, equivalent);
      expect(first.hashCode, equivalent.hashCode);
      expect(first, isNot(differentSelector));
      expect(first.properties, hasLength(1));
      expect(() => first.properties.clear(), throwsUnsupportedError);
    });

    test('retains exact service access as immutable plan evidence', () {
      final equivalent = IdentificationServiceAccess(
        villagerId: VillagerId('villager:rowan'),
        villagerDisplayName: 'Rowan',
        serviceId: ServiceId('service:identify_item_properties'),
        serviceVersion: ExactVersionRef<ServiceContent>(
          stableId: StableContentId<ServiceContent>(
            'service:identify_item_properties',
          ),
          versionId: ContentVersionId<ServiceContent>('service-version-2'),
          revision: 2,
        ),
        serviceDisplayName: 'Identification',
      );

      expect(_serviceAccess, equivalent);
      expect(_serviceAccess.hashCode, equivalent.hashCode);
      expect(
        () => IdentificationServiceAccess(
          villagerId: VillagerId('villager:rowan'),
          villagerDisplayName: 'Rowan',
          serviceId: ServiceId('service:identify_item_properties'),
          serviceVersion: ExactVersionRef<ServiceContent>(
            stableId: StableContentId<ServiceContent>(
              'service:other',
            ),
            versionId: ContentVersionId<ServiceContent>('service-version-2'),
            revision: 2,
          ),
          serviceDisplayName: 'Identification',
        ),
        throwsArgumentError,
      );
    });

    test('rejects negative property ordinals before an invalid command exists',
        () {
      final definition = _definition('coat-color');

      expect(
        () => _property(ordinal: -1, definition: definition),
        throwsArgumentError,
      );
      expect(
        () => _resolution(ordinal: -1, definition: definition),
        throwsArgumentError,
      );
    });

    test('requires a plan to be dense, exact-version-bound, and non-duplicated',
        () {
      final coat = _definition('coat-color');

      expect(
        () => ItemIdentificationPlan(
          item: _item,
          serviceAccess: _serviceAccess,
          propertyResolutions: [_resolution(ordinal: 1, definition: coat)],
        ),
        throwsArgumentError,
      );
      expect(
        () => ItemIdentificationPlan(
          item: _item,
          serviceAccess: _serviceAccess,
          propertyResolutions: [
            _resolution(ordinal: 0, definition: coat),
            _resolution(ordinal: 1, definition: coat, candidateId: 'second'),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => ItemIdentificationPlan(
          item: _item,
          serviceAccess: _serviceAccess,
          propertyResolutions: [
            _resolution(
              ordinal: 0,
              definition: _definition('foreign', version: _otherVersion),
            ),
          ],
        ),
        throwsArgumentError,
      );
    });
  });

  group('ItemIdentificationResult', () {
    final definition = _definition('coat-color');
    final plan = ItemIdentificationPlan(
      item: _item,
      serviceAccess: _serviceAccess,
      propertyResolutions: [_resolution(ordinal: 0, definition: definition)],
    );
    final discovery = ItemDiscovery(
      playerId: _item.playerId,
      baseItemId: _item.baseItemId,
    );
    final value = PropertyValue(
      item: _item,
      definition: definition,
      resolution: SelectedPropertyValue('russet'),
    );

    test('retains immutable exact replay evidence with value equality', () {
      final input = [value];
      final first = ItemIdentificationResult(
        item: _item,
        committedItem: _committedItem(),
        discovery: discovery,
        propertyValues: input,
        identification: plan,
      );
      input.clear();
      final equivalent = ItemIdentificationResult(
        item: _item,
        committedItem: _committedItem(),
        discovery: discovery,
        propertyValues: [value],
        identification: plan,
      );

      expect(first, equivalent);
      expect(first.hashCode, equivalent.hashCode);
      expect(first.propertyValues, [value]);
      expect(() => first.propertyValues.clear(), throwsUnsupportedError);
    });

    test(
        'rejects result evidence that breaks ownership or exact committed binding',
        () {
      final otherItem = ItemKnowledgeItemRef(
        id: ItemKnowledgeItemId('other-item'),
        playerId: _item.playerId,
        baseItemId: _item.baseItemId,
        baseItemVersion: _item.baseItemVersion,
      );
      final otherPlan = ItemIdentificationPlan(
        item: otherItem,
        serviceAccess: _serviceAccess,
        propertyResolutions: const [],
      );

      expect(
        () => ItemIdentificationResult(
          item: _item,
          committedItem: _committedItem(),
          discovery: discovery,
          propertyValues: const [],
          identification: otherPlan,
        ),
        throwsArgumentError,
      );
      expect(
        () => ItemIdentificationResult(
          item: _item,
          committedItem: _committedItem(),
          discovery: ItemDiscovery(
            playerId: 'another-player',
            baseItemId: _item.baseItemId,
          ),
          propertyValues: [value],
          identification: plan,
        ),
        throwsArgumentError,
      );
      expect(
        () => ItemIdentificationResult(
          item: _item,
          committedItem:
              _committedItem(state: ItemIdentificationState.unidentified),
          discovery: discovery,
          propertyValues: [value],
          identification: plan,
        ),
        throwsArgumentError,
      );
    });

    test('rejects incomplete or reordered property replay evidence', () {
      expect(
        () => ItemIdentificationResult(
          item: _item,
          committedItem: _committedItem(),
          discovery: discovery,
          propertyValues: const [],
          identification: plan,
        ),
        throwsArgumentError,
      );
      expect(
        () => ItemIdentificationResult(
          item: _item,
          committedItem: _committedItem(),
          discovery: discovery,
          propertyValues: [
            PropertyValue(
              item: _item,
              definition: _definition('different-definition'),
              resolution: SelectedPropertyValue('russet'),
            ),
          ],
          identification: plan,
        ),
        throwsArgumentError,
      );
    });
  });
}
