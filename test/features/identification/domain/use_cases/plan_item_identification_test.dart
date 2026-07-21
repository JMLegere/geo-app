import 'package:earth_nova/core/domain/content/base_item_content.dart';
import 'package:earth_nova/core/domain/content/content_identity.dart';
import 'package:earth_nova/core/domain/rules/condition.dart';
import 'package:earth_nova/core/domain/rules/selector.dart';
import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/identification/domain/entities/identification_entities.dart';
import 'package:earth_nova/features/identification/domain/use_cases/plan_item_identification.dart';
import 'package:earth_nova/features/item_knowledge/domain/entities/item_knowledge_entities.dart';
import 'package:flutter_test/flutter_test.dart';

final _foxId = StableContentId<BaseItemContent>('base-item-fox');
final _foxVersion = ExactVersionRef<BaseItemContent>(
  stableId: _foxId,
  versionId: ContentVersionId<BaseItemContent>('base-item-fox-v2'),
  revision: 2,
);
final _foxEarlierVersion = ExactVersionRef<BaseItemContent>(
  stableId: _foxId,
  versionId: ContentVersionId<BaseItemContent>('base-item-fox-v1'),
  revision: 1,
);

ItemKnowledgeItemRef _item({String id = 'item-fox-1'}) => ItemKnowledgeItemRef(
      id: ItemKnowledgeItemId(id),
      playerId: 'player-1',
      baseItemId: _foxId,
      baseItemVersion: _foxVersion,
    );

VariablePropertyDefinition _property(
  String id, {
  ExactVersionRef<BaseItemContent>? version,
}) =>
    VariablePropertyDefinition(
      id: VariablePropertyDefinitionId(id),
      baseItemId: _foxId,
      baseItemVersion: version ?? _foxVersion,
      selectorId: PropertySelectorId('$id-selector'),
    );

IdentificationProperty _assignment({
  required int ordinal,
  required VariablePropertyDefinition definition,
  required Iterable<SelectorCandidate<String, Object?>> candidates,
  String? expectedSelectorCandidateId,
  String itemId = 'item-fox-1',
}) {
  final candidateList = List<SelectorCandidate<String, Object?>>.of(candidates);
  final selector = Selector<String, Object?>(candidates: candidateList);
  final resolvedExpectedCandidateId = expectedSelectorCandidateId ??
      selector
          .resolveCandidate(
            null,
            () => PlanItemIdentification.normalizedRollFor(
              itemId: ItemKnowledgeItemId(itemId),
              variablePropertyId: definition.id,
            ),
          )
          .id;
  return IdentificationProperty(
    ordinal: ordinal,
    definition: definition,
    selector: selector,
    expectedSelectorCandidateId: PropertySelectorCandidateId(
      resolvedExpectedCandidateId,
    ),
  );
}

IdentificationPreparation _preparation({
  ItemKnowledgeItemRef? item,
  bool playerDiscovered = false,
  Iterable<IdentificationProperty> properties = const [],
}) =>
    IdentificationPreparation(
      item: item ?? _item(),
      playerDiscovered: playerDiscovered,
      properties: properties,
    );

SelectorCandidate<String, Object?> _value(
        String id, String value, double weight) =>
    SelectorCandidate<String, Object?>.value(
      id: id,
      value: value,
      weight: weight,
    );

Item _committedItem(ItemKnowledgeItemRef item) => Item(
      id: item.id.value,
      definitionId: 'definition-fox',
      baseItemId: item.baseItemId.value,
      baseItemVersionId: item.baseItemVersion.versionId.value,
      displayName: 'Identified fox',
      category: ItemCategory.fauna,
      acquiredAt: DateTime.utc(2026),
      status: ItemStatus.active,
      identificationState: ItemIdentificationState.identified,
    );

SelectorCandidate<String, Object?> _none(String id, double weight) =>
    SelectorCandidate<String, Object?>.none(id: id, weight: weight);

final class _AlwaysCondition extends Condition<Object?> {
  const _AlwaysCondition();

  @override
  bool evaluate(Object? context) => true;
}

void main() {
  final planner = PlanItemIdentification(
    ObservabilityService(sessionId: 'plan-item-identification-test'),
  );

  group('PlanItemIdentification', () {
    test('uses the specified SHA-256 deterministic roll vectors', () {
      expect(
        PlanItemIdentification.normalizedRollFor(
          itemId: ItemKnowledgeItemId('item-fox-1'),
          variablePropertyId: VariablePropertyDefinitionId('coat-color'),
        ),
        closeTo(0.45370053057558835, 0.0000000000000001),
      );
      expect(
        PlanItemIdentification.normalizedRollFor(
          itemId: ItemKnowledgeItemId('item-fox-1'),
          variablePropertyId: VariablePropertyDefinitionId('fur-length'),
        ),
        closeTo(0.8763877602759749, 0.0000000000000001),
      );
      expect(
        PlanItemIdentification.normalizedRollFor(
          itemId: ItemKnowledgeItemId('vector-item'),
          variablePropertyId: VariablePropertyDefinitionId('property-a'),
        ),
        closeTo(0.10916358209215105, 0.0000000000000001),
      );
    });

    test('accepts exactly the three derived requirement cases', () async {
      expect(
        await planner(_preparation(playerDiscovered: false)),
        ItemIdentificationPlan(item: _item(), propertyResolutions: const []),
      );

      final property = _property('coat-color');
      final assignment = _assignment(
        ordinal: 0,
        definition: property,
        candidates: [_value('red-candidate', 'red', 1)],
      );
      expect(
        (await planner(_preparation(properties: [assignment])))
            .propertyResolutions,
        hasLength(1),
      );
      expect(
        (await planner(
          _preparation(playerDiscovered: true, properties: [assignment]),
        ))
            .propertyResolutions,
        hasLength(1),
      );
    });

    test('rejects the one derived requirement case with no command', () {
      expect(
        () => planner(_preparation(playerDiscovered: true)),
        throwsStateError,
      );
    });

    test('resolves multiple properties in dense authored order', () async {
      final coat = _property('coat-color');
      final fur = _property('fur-length');
      final plan = await planner(
        _preparation(
          properties: [
            _assignment(
              ordinal: 0,
              definition: coat,
              candidates: [
                _value('coat-dark', 'dark', .45),
                _value('coat-red', 'red', .55),
              ],
            ),
            _assignment(
              ordinal: 1,
              definition: fur,
              candidates: [
                _value('fur-short', 'short', .5),
                _value('fur-long', 'long', .5),
              ],
            ),
          ],
        ),
      );

      expect(plan.propertyResolutions.map((value) => value.ordinal), [0, 1]);
      expect(
        plan.propertyResolutions.map((value) => value.definition.id.value),
        ['coat-color', 'fur-length'],
      );
      expect(
        plan.propertyResolutions
            .map((value) => value.selectorCandidateId.value),
        ['coat-red', 'fur-long'],
      );
      expect(
        plan.propertyResolutions.map((value) => value.resolution),
        [SelectedPropertyValue('red'), SelectedPropertyValue('long')],
      );
    });

    test('uses generic weighted candidate boundaries without rerolling',
        () async {
      final property = _property('property-a');
      final outsideFirstWeight = await planner(
        _preparation(
          item: _item(id: 'vector-item'),
          properties: [
            _assignment(
              ordinal: 0,
              definition: property,
              itemId: 'vector-item',
              candidates: [
                _value('first', 'first', .109),
                _value('second', 'second', .891),
              ],
            ),
          ],
        ),
      );
      final insideFirstWeight = await planner(
        _preparation(
          item: _item(id: 'vector-item'),
          properties: [
            _assignment(
              ordinal: 0,
              definition: property,
              itemId: 'vector-item',
              candidates: [
                _value('first', 'first', .110),
                _value('second', 'second', .890),
              ],
            ),
          ],
        ),
      );

      expect(
        outsideFirstWeight.propertyResolutions.single.selectorCandidateId,
        PropertySelectorCandidateId('second'),
      );
      expect(
        insideFirstWeight.propertyResolutions.single.selectorCandidateId,
        PropertySelectorCandidateId('first'),
      );
    });

    test('preserves explicit None and its exact authored candidate identity',
        () async {
      final plan = await planner(
        _preparation(
          properties: [
            _assignment(
              ordinal: 0,
              definition: _property('coat-color'),
              candidates: [_none('no-coat-color', 1)],
            ),
          ],
        ),
      );

      expect(
        plan.propertyResolutions.single.selectorCandidateId,
        PropertySelectorCandidateId('no-coat-color'),
      );
      expect(
          plan.propertyResolutions.single.resolution, const NoPropertyValue());
    });

    test(
        'rejects foreign exact Version, duplicate definitions, and gapped order',
        () {
      final foreignVersion =
          _property('coat-color', version: _foxEarlierVersion);
      expect(
        () => planner(
          _preparation(
            properties: [
              _assignment(
                ordinal: 0,
                definition: foreignVersion,
                candidates: [_value('candidate', 'red', 1)],
              ),
            ],
          ),
        ),
        throwsArgumentError,
      );

      final coat = _property('coat-color');
      expect(
        () => planner(
          _preparation(
            properties: [
              _assignment(
                ordinal: 0,
                definition: coat,
                candidates: [_value('first', 'red', 1)],
              ),
              _assignment(
                ordinal: 1,
                definition: coat,
                candidates: [_value('second', 'brown', 1)],
              ),
            ],
          ),
        ),
        throwsArgumentError,
      );

      expect(
        () => planner(
          _preparation(
            properties: [
              _assignment(
                ordinal: 1,
                definition: _property('fur-length'),
                candidates: [_value('candidate', 'long', 1)],
              ),
            ],
          ),
        ),
        throwsArgumentError,
      );
    });

    test('rejects every conditioned candidate before any selector evaluation',
        () {
      final candidate = SelectorCandidate<String, Object?>.value(
        id: 'conditioned-red',
        value: 'red',
        weight: 1,
        condition: const _AlwaysCondition(),
      );
      expect(
        () => planner(
          _preparation(
            properties: [
              _assignment(
                ordinal: 0,
                definition: _property('coat-color'),
                candidates: [candidate],
              ),
            ],
          ),
        ),
        throwsArgumentError,
      );
    });

    test('rejects invalid authored candidate outcomes even when unselected',
        () {
      expect(
        () => planner(
          _preparation(
            properties: [
              _assignment(
                ordinal: 0,
                definition: _property('coat-color'),
                candidates: [
                  _value('valid', 'red', .99),
                  _value('invalid', ' ', .01),
                ],
              ),
            ],
          ),
        ),
        throwsArgumentError,
      );
    });

    test('has immutable value equality and supports exact retry-plan reuse',
        () async {
      final inputProperties = <IdentificationProperty>[
        _assignment(
          ordinal: 0,
          definition: _property('coat-color'),
          candidates: [_value('red-candidate', 'red', 1)],
        ),
      ];
      final preparation = _preparation(properties: inputProperties);
      inputProperties.clear();

      final retainedPlan = await planner(preparation);
      final recomputedPlan = await planner(preparation);
      expect(retainedPlan, recomputedPlan);
      expect(retainedPlan.hashCode, recomputedPlan.hashCode);
      expect(preparation.properties, hasLength(1));
      expect(
        () => retainedPlan.propertyResolutions.add(
          PlannedPropertyResolution(
            ordinal: 1,
            definition: _property('fur-length'),
            selectorCandidateId: PropertySelectorCandidateId('other'),
            resolution: SelectedPropertyValue('long'),
          ),
        ),
        throwsUnsupportedError,
      );
      expect(
        retainedPlan.propertyResolutions.single.selectorCandidateId,
        PropertySelectorCandidateId('red-candidate'),
      );
    });

    test('returns immutable value-equal committed result evidence', () async {
      final definition = _property('coat-color');
      final plan = await planner(
        _preparation(
          properties: [
            _assignment(
              ordinal: 0,
              definition: definition,
              candidates: [_value('red-candidate', 'red', 1)],
            ),
          ],
        ),
      );
      final propertyValues = <PropertyValue>[
        PropertyValue(
          item: plan.item,
          definition: definition,
          resolution: SelectedPropertyValue('red'),
        ),
      ];
      final discovery = ItemDiscovery(
        playerId: plan.item.playerId,
        baseItemId: plan.item.baseItemId,
      );
      final result = ItemIdentificationResult(
        item: plan.item,
        committedItem: _committedItem(plan.item),
        discovery: discovery,
        propertyValues: propertyValues,
        identification: plan,
      );
      propertyValues.clear();

      expect(
        result,
        ItemIdentificationResult(
          item: plan.item,
          committedItem: _committedItem(plan.item),
          discovery: discovery,
          propertyValues: [
            PropertyValue(
              item: plan.item,
              definition: definition,
              resolution: SelectedPropertyValue('red'),
            ),
          ],
          identification: plan,
        ),
      );
      expect(result.propertyValues, hasLength(1));
      expect(
        () => result.propertyValues.clear(),
        throwsUnsupportedError,
      );
    });
  });
}
