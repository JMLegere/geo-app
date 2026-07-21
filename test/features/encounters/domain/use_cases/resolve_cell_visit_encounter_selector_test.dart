import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:earth_nova/core/domain/content/content_identity.dart';
import 'package:earth_nova/core/domain/content/current_encounter_version_binding_repository.dart';
import 'package:earth_nova/core/domain/content/encounter_content.dart';
import 'package:earth_nova/core/domain/rules/condition.dart';
import 'package:earth_nova/core/domain/rules/selector.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/encounters/domain/entities/encounter_entities.dart';
import 'package:earth_nova/features/encounters/domain/use_cases/resolve_cell_visit_encounter_selector.dart';
import 'package:earth_nova/features/map/domain/entities/cell_visit.dart';
import 'package:earth_nova/features/map/domain/rules/legacy_encounter_eligibility.dart';
import 'package:flutter_test/flutter_test.dart';

final class _AllowsSelection extends Condition<bool> {
  const _AllowsSelection();

  @override
  bool evaluate(bool context) => context;
}

final class _FakeCurrentEncounterVersionBindingRepository
    implements CurrentEncounterVersionBindingRepository {
  _FakeCurrentEncounterVersionBindingRepository(this.current);

  final Map<StableContentId<EncounterContent>,
      ExactVersionRef<EncounterContent>> current;
  final List<StableContentId<EncounterContent>> requestedStableIds = [];
  final List<String?> traceIds = [];

  @override
  Future<ExactVersionRef<EncounterContent>?>
      currentPublishedVersionForNewCellVisit(
    StableContentId<EncounterContent> definitionId, {
    String? traceId,
  }) async {
    requestedStableIds.add(definitionId);
    traceIds.add(traceId);
    return current[definitionId];
  }
}

ExactVersionRef<EncounterContent> _binding(
  StableContentId<EncounterContent> stableId, {
  int revision = 4,
}) =>
    ExactVersionRef<EncounterContent>(
      stableId: stableId,
      versionId:
          ContentVersionId<EncounterContent>('version:${stableId.value}'),
      revision: revision,
    );

String _postgresMd5Uuid(String input) {
  final digest = md5.convert(utf8.encode(input)).toString();
  return '${digest.substring(0, 8)}-'
      '${digest.substring(8, 12)}-'
      '${digest.substring(12, 16)}-'
      '${digest.substring(16, 20)}-'
      '${digest.substring(20)}';
}

CellVisit _cellVisit() => CellVisit(
      id: 'visit-1',
      cellId: 'cell-1',
      userId: 'player-1',
      visitedAt: DateTime.utc(2026, 7, 20),
    );

ResolveCellVisitEncounterSelectorInput<Context> _input<Context>({
  required CellVisit cellVisit,
  required Selector<StableContentId<EncounterContent>, Context> selector,
  required Context context,
  required double roll,
}) =>
    ResolveCellVisitEncounterSelectorInput<Context>(
      cellVisit: cellVisit,
      selectorId: SelectorId('selector:test'),
      selector: selector,
      selectorContext: context,
      rollSource: () => roll,
    );

ResolveCellVisitEncounterSelector<Context> _useCase<Context>(
  CurrentEncounterVersionBindingRepository repository,
) =>
    ResolveCellVisitEncounterSelector<Context>(
      repository,
      ObservabilityService(sessionId: 'resolve-cell-visit-selector-test'),
    );

void main() {
  group('ResolveCellVisitEncounterSelector', () {
    test('retains selector and candidate identity while binding exact Version',
        () async {
      final selectedId =
          StableContentId<EncounterContent>('encounter:selected');
      final repository = _FakeCurrentEncounterVersionBindingRepository({
        selectedId: _binding(selectedId, revision: 7),
      });
      final useCase = _useCase<bool>(repository);
      final selector = Selector<StableContentId<EncounterContent>, bool>(
        candidates: [
          SelectorCandidate.value(
            id: 'candidate:selected',
            value: selectedId,
            weight: 1,
          ),
        ],
      );

      final result = await useCase(
        _input(
          cellVisit: _cellVisit(),
          selector: selector,
          context: true,
          roll: 0,
        ),
      );

      final selected = result as EncounterSelectedCellVisitPlan;
      expect(selected.cellVisit, _cellVisit());
      expect(selected.selectorId, SelectorId('selector:test'));
      expect(selected.selectorCandidateId,
          SelectorCandidateId('candidate:selected'));
      expect(selected.definitionId, selectedId);
      expect(selected.definitionVersion.stableId, selectedId);
      expect(selected.definitionVersion.versionId.value,
          'version:encounter:selected');
      expect(selected.definitionVersion.revision, 7);
      expect(repository.requestedStableIds, [selectedId]);
      expect(repository.traceIds.single, matches(RegExp(r'^[0-9a-f]{32}$')));
    });

    test('returns explicit None without loading or binding Encounter content',
        () async {
      final repository = _FakeCurrentEncounterVersionBindingRepository({});
      final selector = Selector<StableContentId<EncounterContent>, bool>(
        candidates: [SelectorCandidate.none(id: 'candidate:none', weight: 1)],
      );

      final result = await _useCase<bool>(repository)(
        _input(
          cellVisit: _cellVisit(),
          selector: selector,
          context: false,
          roll: 0,
        ),
      );

      final none = result as NoEncounterCellVisitPlan;
      expect(none.cellVisit, _cellVisit());
      expect(none.selectorId, SelectorId('selector:test'));
      expect(none.selectorCandidateId, SelectorCandidateId('candidate:none'));
      expect(repository.requestedStableIds, isEmpty);
    });

    test(
        'fails clearly when selected Definition has no current published Version',
        () async {
      final definitionId =
          StableContentId<EncounterContent>('encounter:missing');
      final repository = _FakeCurrentEncounterVersionBindingRepository({});
      final selector = Selector<StableContentId<EncounterContent>, bool>(
        candidates: [
          SelectorCandidate.value(
            id: 'candidate:missing',
            value: definitionId,
            weight: 1,
          ),
        ],
      );

      expect(
        () => _useCase<bool>(repository)(
          _input(
            cellVisit: _cellVisit(),
            selector: selector,
            context: true,
            roll: 0,
          ),
        ),
        throwsA(
          isA<MissingCurrentPublishedEncounterVersion>().having(
              (error) => error.definitionId, 'definition ID', definitionId),
        ),
      );
    });

    test('filters ineligible candidates before selecting', () async {
      final blockedId = StableContentId<EncounterContent>('encounter:blocked');
      final allowedId = StableContentId<EncounterContent>('encounter:allowed');
      final repository = _FakeCurrentEncounterVersionBindingRepository({
        allowedId: _binding(allowedId),
      });
      final selector = Selector<StableContentId<EncounterContent>, bool>(
        candidates: [
          SelectorCandidate.value(
            id: 'candidate:blocked',
            value: blockedId,
            weight: 100,
            condition: const _AllowsSelection(),
          ),
          SelectorCandidate.value(
            id: 'candidate:allowed',
            value: allowedId,
            weight: 1,
          ),
        ],
      );

      final result = await _useCase<bool>(repository)(
        _input(
          cellVisit: _cellVisit(),
          selector: selector,
          context: false,
          roll: 0,
        ),
      );

      final selected = result as EncounterSelectedCellVisitPlan;
      expect(selected.selectorCandidateId,
          SelectorCandidateId('candidate:allowed'));
      expect(selected.definitionId, allowedId);
      expect(repository.requestedStableIds, [allowedId]);
    });

    test('legacy compatibility selector exactly follows SHA-256 catalog shards',
        () async {
      final selector = buildLegacyCellEncounterCompatibilitySelector();
      final definitions = legacyCellEncounterDefinitionIds;

      for (var index = 0; index < legacyCellEncounterSlugs.length; index++) {
        expect(
          selector.candidates[index].id,
          _postgresMd5Uuid(
            'earthnova:legacy-encounter-selector-candidate:'
            '${legacyCellEncounterSlugs[index]}',
          ),
        );
      }
      expect(
        selector.candidates.last.id,
        _postgresMd5Uuid('earthnova:legacy-encounter-selector-candidate:none'),
      );
      final bindings = <StableContentId<EncounterContent>,
          ExactVersionRef<EncounterContent>>{
        for (final definition in definitions) definition: _binding(definition),
      };
      final repository =
          _FakeCurrentEncounterVersionBindingRepository(bindings);
      final useCase = _useCase<LegacyEncounterEligibilityContext>(repository);
      final observedIndices = <int>{};

      for (var index = 0; index < 128; index++) {
        final seed = 'seed-$index';
        final cellId = 'cell-$index';
        final hash = sha256
            .convert(utf8.encode('${seed}_$cellId'))
            .toString()
            .substring(0, 8);
        final expectedIndex = int.parse(hash, radix: 16) % definitions.length;
        observedIndices.add(expectedIndex);

        final result = await useCase(
          ResolveCellVisitEncounterSelectorInput(
            cellVisit: CellVisit(
              id: 'visit-$index',
              cellId: cellId,
              userId: 'player-1',
              visitedAt: DateTime.utc(2026, 7, 20),
            ),
            selectorId: legacyCellEncounterSelectorId,
            selector: selector,
            selectorContext: const LegacyEncounterEligibilityContext(
              isFirstVisit: true,
              hasLegacyLoot: false,
            ),
            rollSource: () =>
                legacyCellEncounterRoll(seed: seed, cellId: cellId),
          ),
        );

        final selected = result as EncounterSelectedCellVisitPlan;
        expect(selected.definitionId, definitions[expectedIndex]);
        expect(
          selected.selectorCandidateId.value,
          selector.candidates[expectedIndex].id,
        );
        expect(
          selected.selectorCandidateId.value,
          matches(RegExp(
              r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')),
        );
      }

      expect(observedIndices, hasLength(definitions.length));
    });

    test('legacy compatibility selector yields explicit None when ineligible',
        () async {
      final repository = _FakeCurrentEncounterVersionBindingRepository({});
      final result =
          await _useCase<LegacyEncounterEligibilityContext>(repository)(
        ResolveCellVisitEncounterSelectorInput(
          cellVisit: _cellVisit(),
          selectorId: legacyCellEncounterSelectorId,
          selector: buildLegacyCellEncounterCompatibilitySelector(),
          selectorContext: const LegacyEncounterEligibilityContext(
            isFirstVisit: false,
            hasLegacyLoot: false,
          ),
          rollSource: () =>
              legacyCellEncounterRoll(seed: 'seed', cellId: 'cell-1'),
        ),
      );

      expect(result, isA<NoEncounterCellVisitPlan>());
      expect(repository.requestedStableIds, isEmpty);
    });
  });
}
