import 'package:earth_nova/core/domain/content/base_item_content.dart';
import 'package:earth_nova/core/domain/content/content_identity.dart';
import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/features/item_knowledge/domain/entities/item_knowledge_entities.dart';
import 'package:earth_nova/features/item_knowledge/domain/rules/identification_requirement.dart';
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
final _fernId = StableContentId<BaseItemContent>('base-item-fern');
final _fernVersion = ExactVersionRef<BaseItemContent>(
  stableId: _fernId,
  versionId: ContentVersionId<BaseItemContent>('base-item-fern-v1'),
  revision: 1,
);

ItemKnowledgeItemRef _foxItem({
  String id = 'item-fox-1',
  ExactVersionRef<BaseItemContent>? baseItemVersion,
}) =>
    ItemKnowledgeItemRef(
      id: ItemKnowledgeItemId(id),
      playerId: 'player-1',
      baseItemId: _foxId,
      baseItemVersion: baseItemVersion ?? _foxVersion,
    );

VariablePropertyDefinition _coatColor({
  ExactVersionRef<BaseItemContent>? baseItemVersion,
}) =>
    VariablePropertyDefinition(
      id: VariablePropertyDefinitionId('coat-color'),
      baseItemId: _foxId,
      baseItemVersion: baseItemVersion ?? _foxVersion,
      selectorId: PropertySelectorId('coat-color-selector'),
    );

void main() {
  group('IdentificationRequirement', () {
    test('requires Identification for every derived-rule truth table case', () {
      expect(
        IdentificationRequirement.requires(
          playerDiscovered: false,
          variablePropertyCount: 0,
        ),
        isTrue,
      );
      expect(
        IdentificationRequirement.requires(
          playerDiscovered: false,
          variablePropertyCount: 1,
        ),
        isTrue,
      );
      expect(
        IdentificationRequirement.requires(
          playerDiscovered: true,
          variablePropertyCount: 0,
        ),
        isFalse,
      );
      expect(
        IdentificationRequirement.requires(
          playerDiscovered: true,
          variablePropertyCount: 1,
        ),
        isTrue,
      );
    });

    test('rejects a negative Variable Property count', () {
      expect(
        () => IdentificationRequirement.requires(
          playerDiscovered: true,
          variablePropertyCount: -1,
        ),
        throwsArgumentError,
      );
    });
  });

  group('Item Discovery', () {
    test('is an immutable value keyed by player and stable Base Item', () {
      final first = ItemDiscovery(playerId: ' player-1 ', baseItemId: _foxId);
      final same = ItemDiscovery(playerId: 'player-1', baseItemId: _foxId);

      expect(first, same);
      expect(first.playerId, 'player-1');
      expect(first.baseItemId, _foxId);
    });

    test('rejects a blank player identity', () {
      expect(
        () => ItemDiscovery(playerId: '  ', baseItemId: _foxId),
        throwsArgumentError,
      );
    });
  });

  group('Variable Properties and Property Values', () {
    test('binds a Variable Property definition to its exact Base Item Version',
        () {
      final definition = _coatColor();

      expect(definition.baseItemId, _foxId);
      expect(definition.baseItemVersion, _foxVersion);
      expect(definition.selectorId, PropertySelectorId('coat-color-selector'));
    });

    test('preserves an exact immutable Item Version binding in Property Values',
        () {
      final value = PropertyValue(
        item: _foxItem(),
        definition: _coatColor(),
        resolution: SelectedPropertyValue('red'),
      );

      expect(value.item.baseItemVersion, _foxVersion);
      expect(value.definition.baseItemVersion, _foxVersion);
      expect(value.resolution, SelectedPropertyValue('red'));
    });

    test('represents None as an explicit resolved Property Value outcome', () {
      final value = PropertyValue(
        item: _foxItem(),
        definition: _coatColor(),
        resolution: const NoPropertyValue(),
      );

      expect(value.resolution, const NoPropertyValue());
      expect(value.resolution, isA<NoPropertyValue>());
    });

    test('rejects foreign and mismatched exact Version ownership', () {
      expect(
        () => VariablePropertyDefinition(
          id: VariablePropertyDefinitionId('coat-color'),
          baseItemId: _foxId,
          baseItemVersion: _fernVersion,
          selectorId: PropertySelectorId('coat-color-selector'),
        ),
        throwsArgumentError,
      );
      expect(
        () => ItemKnowledgeItemRef(
          id: ItemKnowledgeItemId('item-fox-1'),
          playerId: 'player-1',
          baseItemId: _foxId,
          baseItemVersion: _fernVersion,
        ),
        throwsArgumentError,
      );
      expect(
        () => PropertyValue(
          item: _foxItem(baseItemVersion: _foxEarlierVersion),
          definition: _coatColor(),
          resolution: SelectedPropertyValue('red'),
        ),
        throwsArgumentError,
      );
    });

    test('rejects blank identities and implicit missing outcomes', () {
      expect(() => ItemKnowledgeItemId(' '), throwsArgumentError);
      expect(() => VariablePropertyDefinitionId(' '), throwsArgumentError);
      expect(() => PropertySelectorId(' '), throwsArgumentError);
      expect(() => SelectedPropertyValue(' '), throwsArgumentError);
      expect(
        () => PropertyValue(
          item: _foxItem(),
          definition: _coatColor(),
          resolution: null as PropertyValueResolution?,
        ),
        throwsArgumentError,
      );
    });

    test('uses value equality for immutable Property Value contracts', () {
      final first = PropertyValue(
        item: _foxItem(),
        definition: _coatColor(),
        resolution: SelectedPropertyValue('red'),
      );
      final same = PropertyValue(
        item: _foxItem(),
        definition: _coatColor(),
        resolution: SelectedPropertyValue('red'),
      );

      expect(first, same);
      expect(first.hashCode, same.hashCode);
    });
  });

  group('Discipline', () {
    test('maps every knowledge category and leaves Food and Orb absent', () {
      expect(Discipline.forCategory(ItemCategory.fauna), Discipline.zoology);
      expect(Discipline.forCategory(ItemCategory.flora), Discipline.botany);
      expect(Discipline.forCategory(ItemCategory.mineral), Discipline.geology);
      expect(
        Discipline.forCategory(ItemCategory.fossil),
        Discipline.paleontology,
      );
      expect(
        Discipline.forCategory(ItemCategory.artifact),
        Discipline.archaeology,
      );
      expect(Discipline.forCategory(ItemCategory.food), isNull);
      expect(Discipline.forCategory(ItemCategory.orb), isNull);
    });

    test(
        'stores immutable, value-equal Player progression without tuning rules',
        () {
      final first = DisciplineProgress(
        playerId: ' player-1 ',
        discipline: Discipline.zoology,
        experience: 120,
        level: 3,
      );
      final same = DisciplineProgress(
        playerId: 'player-1',
        discipline: Discipline.zoology,
        experience: 120,
        level: 3,
      );

      expect(first, same);
      expect(first.playerId, 'player-1');
      expect(first.hashCode, same.hashCode);
    });

    test('rejects invalid experience and levels', () {
      expect(
        () => DisciplineProgress(
          playerId: 'player-1',
          discipline: Discipline.zoology,
          experience: -1,
          level: 1,
        ),
        throwsArgumentError,
      );
      expect(
        () => DisciplineProgress(
          playerId: 'player-1',
          discipline: Discipline.zoology,
          experience: 0,
          level: 0,
        ),
        throwsArgumentError,
      );
    });
  });
}
