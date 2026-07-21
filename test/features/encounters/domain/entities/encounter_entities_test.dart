import 'package:earth_nova/core/domain/content/content_identity.dart';
import 'package:earth_nova/core/domain/content/base_item_content.dart';
import 'package:earth_nova/core/domain/content/encounter_content.dart';
import 'package:earth_nova/core/domain/content/venue_content.dart';
import 'package:earth_nova/core/domain/entities/venue_id.dart';
import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/features/encounters/domain/entities/encounter_entities.dart';
import 'package:earth_nova/features/encounters/domain/repositories/encounter_repository.dart';
import 'package:flutter_test/flutter_test.dart';

final _encounterDefinitionId = StableContentId<EncounterContent>('enc-fox');
final _encounterVersion = ExactVersionRef<EncounterContent>(
  stableId: _encounterDefinitionId,
  versionId: ContentVersionId<EncounterContent>('enc-fox-v1'),
  revision: 1,
);
final _baseItemId = StableContentId<BaseItemContent>('item-fox');
final _baseItemVersion = ExactVersionRef<BaseItemContent>(
  stableId: _baseItemId,
  versionId: ContentVersionId<BaseItemContent>('item-fox-v2'),
  revision: 2,
);
final _venueVersion = ExactVersionRef<VenueContent>(
  stableId: StableContentId<VenueContent>('venue:fox-den'),
  versionId: ContentVersionId<VenueContent>('venue-fox-den-v2'),
  revision: 2,
);

EncounterOption _option({
  String id = 'option-observe',
  int ordinal = 0,
  bool isImplicit = false,
  Iterable<EncounterOutcome>? outcomes,
}) =>
    EncounterOption(
      id: EncounterOptionId(id),
      ordinal: ordinal,
      displayName: 'Observe',
      isImplicit: isImplicit,
      outcomes: outcomes ?? <EncounterOutcome>[_generateItemOutcome()],
    );

GenerateItemOutcome _generateItemOutcome({
  String id = 'outcome-item',
  int ordinal = 0,
}) =>
    GenerateItemOutcome(
      id: EncounterOutcomeId(id),
      ordinal: ordinal,
      baseItemId: _baseItemId,
    );

void main() {
  group('Encounter Definition and Version', () {
    test('keeps a stable Definition identity distinct from exact Versions', () {
      final definition = EncounterDefinition(id: _encounterDefinitionId);
      final laterVersion = ExactVersionRef<EncounterContent>(
        stableId: _encounterDefinitionId,
        versionId: ContentVersionId<EncounterContent>('enc-fox-v2'),
        revision: 2,
      );

      final first = EncounterDefinitionVersion(
        definition: definition,
        version: _encounterVersion,
        displayName: 'Fox in the hedgerow',
        isAutomatic: false,
        options: [_option()],
      );
      final second = EncounterDefinitionVersion(
        definition: definition,
        version: laterVersion,
        displayName: 'Fox in the hedgerow, revised',
        isAutomatic: false,
        options: [_option()],
      );

      expect(first.definition.id, same(second.definition.id));
      expect(first.version, isNot(second.version));
      expect(first.version.stableId, second.version.stableId);
    });

    test(
        'rejects a Version whose exact reference belongs to another Definition',
        () {
      expect(
        () => EncounterDefinitionVersion(
          definition: EncounterDefinition(
            id: StableContentId<EncounterContent>('enc-otter'),
          ),
          version: _encounterVersion,
          displayName: 'Otter',
          isAutomatic: false,
          options: [_option()],
        ),
        throwsArgumentError,
      );
    });

    test('preserves ordered immutable Options and Outcomes', () {
      final firstOutcome = _generateItemOutcome(ordinal: 0);
      final secondOutcome = RevealVenueOutcome(
        id: EncounterOutcomeId('outcome-venue'),
        ordinal: 1,
        venueId: VenueId('venue-garden'),
      );
      final sourceOutcomes = <EncounterOutcome>[firstOutcome, secondOutcome];
      final sourceOptions = <EncounterOption>[
        _option(id: 'option-first', ordinal: 0, outcomes: sourceOutcomes),
        _option(id: 'option-second', ordinal: 1),
      ];

      final version = EncounterDefinitionVersion(
        definition: EncounterDefinition(id: _encounterDefinitionId),
        version: _encounterVersion,
        displayName: 'Fox in the hedgerow',
        isAutomatic: false,
        options: sourceOptions,
      );
      sourceOptions.clear();
      sourceOutcomes.clear();

      expect(version.options.map((option) => option.ordinal), [0, 1]);
      expect(version.options.first.outcomes.map((outcome) => outcome.ordinal),
          [0, 1]);
      expect(
        () => version.options.add(_option(id: 'option-third', ordinal: 2)),
        throwsUnsupportedError,
      );
      expect(
        () => version.options.first.outcomes
            .add(_generateItemOutcome(id: 'other', ordinal: 2)),
        throwsUnsupportedError,
      );
    });

    test('normalizes Options and Outcomes into ordinal order', () {
      final lateOutcome = _generateItemOutcome(id: 'late', ordinal: 3);
      final earlyOutcome = RevealVenueOutcome(
        id: EncounterOutcomeId('early'),
        ordinal: 1,
        venueId: VenueId('venue-garden'),
      );
      final version = EncounterDefinitionVersion(
        definition: EncounterDefinition(id: _encounterDefinitionId),
        version: _encounterVersion,
        displayName: 'Ordered encounter',
        isAutomatic: false,
        options: [
          _option(id: 'late-option', ordinal: 7),
          _option(
            id: 'early-option',
            ordinal: 2,
            outcomes: [lateOutcome, earlyOutcome],
          ),
        ],
      );

      expect(version.options.map((option) => option.ordinal), [2, 7]);
      expect(
        version.options.first.outcomes.map((outcome) => outcome.ordinal),
        [1, 3],
      );
    });

    test('requires nonempty unique nonnegative Options and Outcomes', () {
      expect(
        () => EncounterDefinitionVersion(
          definition: EncounterDefinition(id: _encounterDefinitionId),
          version: _encounterVersion,
          displayName: 'Fox',
          isAutomatic: false,
          options: const [],
        ),
        throwsArgumentError,
      );
      expect(
        () => EncounterDefinitionVersion(
          definition: EncounterDefinition(id: _encounterDefinitionId),
          version: _encounterVersion,
          displayName: 'Fox',
          isAutomatic: false,
          options: [_option(), _option(id: 'option-second')],
        ),
        throwsArgumentError,
      );
      expect(
        () => _option(
          outcomes: [_generateItemOutcome(ordinal: -1)],
        ),
        throwsArgumentError,
      );
      expect(
        () => _option(
          outcomes: [
            _generateItemOutcome(),
            _generateItemOutcome(id: 'second')
          ],
        ),
        throwsArgumentError,
      );
    });

    test('requires exactly one implicit Option for automatic Versions', () {
      expect(
        () => EncounterDefinitionVersion(
          definition: EncounterDefinition(id: _encounterDefinitionId),
          version: _encounterVersion,
          displayName: 'Automatic Fox',
          isAutomatic: true,
          options: [_option(isImplicit: false)],
        ),
        throwsArgumentError,
      );
      expect(
        () => EncounterDefinitionVersion(
          definition: EncounterDefinition(id: _encounterDefinitionId),
          version: _encounterVersion,
          displayName: 'Automatic Fox',
          isAutomatic: true,
          options: [
            _option(id: 'one', ordinal: 0, isImplicit: true),
            _option(id: 'two', ordinal: 1, isImplicit: true),
          ],
        ),
        throwsArgumentError,
      );

      final automatic = EncounterDefinitionVersion(
        definition: EncounterDefinition(id: _encounterDefinitionId),
        version: _encounterVersion,
        displayName: 'Automatic Fox',
        isAutomatic: true,
        options: [_option(isImplicit: true)],
      );
      expect(automatic.options.single.isImplicit, isTrue);
    });

    test('forbids implicit Options for manual Versions', () {
      expect(
        () => EncounterDefinitionVersion(
          definition: EncounterDefinition(id: _encounterDefinitionId),
          version: _encounterVersion,
          displayName: 'Manual Fox',
          isAutomatic: false,
          options: [_option(isImplicit: true)],
        ),
        throwsArgumentError,
      );
    });
  });

  group('Encounter Outcomes', () {
    test('has only typed Generate Item and Reveal Venue variants', () {
      final outcomes = <EncounterOutcome>[
        _generateItemOutcome(),
        RevealVenueOutcome(
          id: EncounterOutcomeId('outcome-venue'),
          ordinal: 1,
          venueId: VenueId('venue-garden'),
        ),
      ];

      expect(outcomes[0], isA<GenerateItemOutcome>());
      expect(outcomes[1], isA<RevealVenueOutcome>());
      expect(
        outcomes.map(
          (outcome) => switch (outcome) {
            GenerateItemOutcome() => 'generate_item',
            RevealVenueOutcome() => 'reveal_venue',
          },
        ),
        ['generate_item', 'reveal_venue'],
      );
    });

    test('Generate Item Outcome names only a stable Base Item', () {
      final outcome = _generateItemOutcome();

      expect(outcome.baseItemId, _baseItemId);
      expect(outcome.baseItemId, isNot(_baseItemVersion));
    });
  });

  group('Cell Visit Resolution', () {
    test('makes None distinct from a selected stable Definition', () {
      final none = CellVisitResolution.none(
        id: CellVisitResolutionId('resolution-none'),
        cellVisitId: CellVisitId('visit-1'),
        selectorId: SelectorId('selector-encounter'),
        selectorCandidateId: SelectorCandidateId('candidate-none'),
        resolvedAt: DateTime.utc(2026, 7, 20),
      );
      final selected = CellVisitResolution.selectedDefinition(
        id: CellVisitResolutionId('resolution-encounter'),
        cellVisitId: CellVisitId('visit-2'),
        selectorId: SelectorId('selector-encounter'),
        selectorCandidateId: SelectorCandidateId('candidate-fox'),
        definitionId: _encounterDefinitionId,
        resolvedAt: DateTime.utc(2026, 7, 20),
      );

      expect(none.result, isA<NoEncounterDefinitionSelection>());
      expect(selected.result, isA<EncounterDefinitionSelection>());
      expect((selected.result as EncounterDefinitionSelection).definitionId,
          _encounterDefinitionId);
    });
  });

  group('Encounter occurrence', () {
    final createdAt = DateTime.utc(2026, 7, 20, 10);

    EncounterOccurrence occurrence({
      required EncounterResolutionStatus status,
      EncounterOptionId? selectedOptionId,
      DateTime? resolvedAt,
      EncounterFailure? failure,
    }) =>
        EncounterOccurrence(
          id: EncounterId('encounter-1'),
          cellVisitId: CellVisitId('visit-1'),
          cellVisitResolutionId: CellVisitResolutionId('resolution-encounter'),
          definitionVersion: _encounterVersion,
          status: status,
          createdAt: createdAt,
          selectedOptionId: selectedOptionId,
          resolvedAt: resolvedAt,
          failure: failure,
        );

    test('enforces pending, resolved, and failed state fields', () {
      expect(
        occurrence(status: EncounterResolutionStatus.pending),
        isA<EncounterOccurrence>(),
      );
      expect(
        occurrence(
          status: EncounterResolutionStatus.resolved,
          selectedOptionId: EncounterOptionId('option-observe'),
          resolvedAt: DateTime.utc(2026, 7, 20, 11),
        ),
        isA<EncounterOccurrence>(),
      );
      expect(
        occurrence(
          status: EncounterResolutionStatus.failed,
          failure: EncounterFailure(code: 'selector_exhausted'),
        ),
        isA<EncounterOccurrence>(),
      );

      expect(
        () => occurrence(
          status: EncounterResolutionStatus.pending,
          selectedOptionId: EncounterOptionId('option-observe'),
        ),
        throwsArgumentError,
      );
      expect(
        () => occurrence(
          status: EncounterResolutionStatus.resolved,
          selectedOptionId: EncounterOptionId('option-observe'),
        ),
        throwsArgumentError,
      );
      expect(
        () => occurrence(
          status: EncounterResolutionStatus.failed,
          resolvedAt: DateTime.utc(2026, 7, 20, 11),
          failure: EncounterFailure(code: 'selector_exhausted'),
        ),
        throwsArgumentError,
      );
      expect(
        () => occurrence(status: EncounterResolutionStatus.failed),
        throwsArgumentError,
      );
    });
  });

  group('Encounter Outcome Results', () {
    test('immutably binds Generate Item result to the exact Base Item Version',
        () {
      final result = GenerateItemOutcomeResult(
        id: EncounterOutcomeResultId('result-item'),
        encounterId: EncounterId('encounter-1'),
        outcomeId: EncounterOutcomeId('outcome-item'),
        ordinal: 0,
        resolvedBaseItemVersion: _baseItemVersion,
        createdAt: DateTime.utc(2026, 7, 20, 11),
      );

      final resolvedVersion = result.resolvedBaseItemVersion;
      expect(resolvedVersion, _baseItemVersion);
      expect(resolvedVersion, isNotNull);
      final exactVersion = resolvedVersion!;
      expect(exactVersion.stableId, _baseItemId);
      expect(exactVersion.versionId.value, 'item-fox-v2');
    });

    test('binds Reveal Venue result to its stable Venue and exact Version', () {
      final result = RevealVenueOutcomeResult(
        id: EncounterOutcomeResultId('result-venue'),
        encounterId: EncounterId('encounter-1'),
        outcomeId: EncounterOutcomeId('outcome-venue'),
        ordinal: 1,
        createdAt: DateTime.utc(2026, 7, 20, 11),
        venueId: VenueId('venue:fox-den'),
        resolvedVenueVersion: _venueVersion,
      );

      expect(result.venueId.value, 'venue:fox-den');
      expect(result.resolvedVenueVersion, _venueVersion);
      expect(
        () => RevealVenueOutcomeResult(
          id: EncounterOutcomeResultId('result-other-venue'),
          encounterId: EncounterId('encounter-1'),
          outcomeId: EncounterOutcomeId('outcome-other-venue'),
          ordinal: 2,
          createdAt: DateTime.utc(2026, 7, 20, 11),
          venueId: VenueId('venue:other'),
          resolvedVenueVersion: _venueVersion,
        ),
        throwsArgumentError,
      );
    });

    test('validates nonblank runtime IDs and failure codes', () {
      expect(() => EncounterId('  '), throwsArgumentError);
      expect(() => VenueId(''), throwsArgumentError);
      expect(() => EncounterFailure(code: ' '), throwsArgumentError);
    });
  });

  group('Committed generated Item boundary', () {
    GenerateItemOutcomeResult result({
      ExactVersionRef<BaseItemContent>? exactVersion,
    }) =>
        GenerateItemOutcomeResult(
          id: EncounterOutcomeResultId('result-item'),
          encounterId: EncounterId('encounter-1'),
          outcomeId: EncounterOutcomeId('outcome-item'),
          ordinal: 0,
          createdAt: DateTime.utc(2026, 7, 20, 11),
          resolvedBaseItemVersion: exactVersion,
        );

    Item item({
      String? definitionId,
      ItemIdentificationState identificationState =
          ItemIdentificationState.identified,
    }) =>
        Item(
          id: 'item-1',
          definitionId: definitionId,
          displayName: 'Captured fox',
          category: ItemCategory.fauna,
          acquiredAt: DateTime.utc(2026, 7, 20, 11),
          status: ItemStatus.active,
          identificationState: identificationState,
        );

    test(
        'rejects canonical identity that differs from committed exact evidence',
        () {
      expect(
        () => GeneratedItemCommit(
          outcomeResult: result(exactVersion: _baseItemVersion),
          item: item(definitionId: 'item-otter'),
        ),
        throwsArgumentError,
      );
    });

    test('permits only redacted unidentified Items without an exact result',
        () {
      expect(
        () => GeneratedItemCommit(
          outcomeResult: result(),
          item: item(),
        ),
        throwsArgumentError,
      );

      final commit = GeneratedItemCommit(
        outcomeResult: result(),
        item: item(
          identificationState: ItemIdentificationState.unidentified,
        ),
      );

      expect(commit.item.isUnidentified, isTrue);
      expect(commit.resolvedBaseItemVersion, isNull);
    });
  });
}
