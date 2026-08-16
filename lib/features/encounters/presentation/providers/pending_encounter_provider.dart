import 'dart:async';

import 'package:earth_nova/core/observability/observable_notifier.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/core/observability/trace_context.dart';
import 'package:earth_nova/features/encounters/domain/entities/encounter_entities.dart';
import 'package:earth_nova/features/encounters/domain/repositories/encounter_repository.dart';
import 'package:earth_nova/features/encounters/domain/use_cases/resolve_pending_encounter.dart';
import 'package:earth_nova/features/encounters/presentation/providers/encounter_entry_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/exploration_eligibility_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/exploration_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

sealed class PendingEncounterState {
  const PendingEncounterState();
}

final class PendingEncounterNone extends PendingEncounterState {
  const PendingEncounterNone();
}

final class PendingEncounterLoading extends PendingEncounterState {
  const PendingEncounterLoading();
}

final class PendingEncounterReady extends PendingEncounterState {
  const PendingEncounterReady(this.pendingEncounter);

  final PendingEncounter pendingEncounter;
}

final class PendingEncounterResolving extends PendingEncounterState {
  const PendingEncounterResolving(this.pendingEncounter, this.optionId);

  final PendingEncounter pendingEncounter;
  final EncounterOptionId optionId;
}

final class PendingEncounterResolved extends PendingEncounterState {
  const PendingEncounterResolved(this.pendingEncounter, this.aggregate);

  final PendingEncounter pendingEncounter;
  final EncounterRuntimeAggregate aggregate;
}

final class PendingEncounterFailure extends PendingEncounterState {
  const PendingEncounterFailure({this.pendingEncounter, this.optionId});

  final PendingEncounter? pendingEncounter;
  final EncounterOptionId? optionId;
}

final pendingEncounterProvider =
    NotifierProvider<PendingEncounterNotifier, PendingEncounterState>(
  PendingEncounterNotifier.new,
);

final class _PendingResolution {
  const _PendingResolution({required this.input, required this.traceContext});

  final ResolvePendingEncounterInput input;
  final TraceContext traceContext;
}

class PendingEncounterNotifier
    extends ObservableNotifier<PendingEncounterState> {
  late EncounterRepository _repository;
  late ResolvePendingEncounter _resolvePendingEncounter;
  late Future<void> Function(PendingEncounter, GeneratedItemCommit)
      _presentCommittedReward;
  String? _trustedCellId;
  String? _loadedCellId;
  _PendingResolution? _retryResolution;
  int _requestGeneration = 0;

  @override
  ObservabilityService get obs => ref.watch(explorationObservabilityProvider);

  @override
  String get category => 'encounter';

  @override
  PendingEncounterState build() {
    _repository = ref.read(encounterCommandRepositoryProvider);
    _resolvePendingEncounter = ResolvePendingEncounter(_repository, obs);
    _presentCommittedReward = ref.read(
      committedPendingEncounterRewardPresenterProvider,
    );
    ref.listen<ExplorationStateData>(
      explorationProvider,
      (_, __) => _syncTrustedCell(),
    );
    ref.listen<ExplorationEligibility>(
      explorationEligibilityProvider,
      (_, __) => _syncTrustedCell(),
    );
    _syncTrustedCell();

    return const PendingEncounterNone();
  }

  void _syncTrustedCell() {
    final currentCellId = ref.read(explorationProvider).currentCellId;
    final canRecordVisits =
        ref.read(explorationEligibilityProvider).canRecordVisits;
    final trustedCellId = canRecordVisits ? currentCellId : null;
    if (trustedCellId == _trustedCellId) return;

    _trustedCellId = trustedCellId;
    _loadedCellId = null;
    _retryResolution = null;
    _requestGeneration += 1;
    transition(
      const PendingEncounterNone(),
      'encounter.pending.trust_changed',
      data: {'cell_id': trustedCellId},
    );
    if (trustedCellId != null) {
      Future<void>.microtask(load);
    }
  }

  Future<void> load() async {
    final cellId = _trustedCellId;
    if (cellId == null || _loadedCellId == cellId) return;
    await _read(cellId, operation: 'load');
  }

  Future<void> refresh() async {
    final current = state;
    if (current is PendingEncounterResolving ||
        current is PendingEncounterResolved ||
        (current is PendingEncounterFailure &&
            current.pendingEncounter != null)) {
      return;
    }
    final cellId = _trustedCellId;
    if (cellId == null) return;
    await _read(cellId, operation: 'refresh');
  }

  Future<void> resolve(EncounterOptionId optionId) async {
    final current = state;
    if (current is! PendingEncounterReady ||
        current.pendingEncounter.cellId != _trustedCellId ||
        !current.pendingEncounter.options
            .any((option) => option.id == optionId)) {
      return;
    }
    final command = _PendingResolution(
      input: ResolvePendingEncounterInput(
        pendingEncounter: current.pendingEncounter,
        optionId: optionId,
      ),
      traceContext: TraceContext.start(),
    );
    _retryResolution = command;
    await _resolve(command);
  }

  Future<void> retryResolution() async {
    final command = _retryResolution;
    final current = state;
    if (command == null ||
        current is! PendingEncounterFailure ||
        !identical(current.pendingEncounter, command.input.pendingEncounter) ||
        current.optionId != command.input.optionId ||
        command.input.pendingEncounter.cellId != _trustedCellId) {
      return;
    }
    await _resolve(command);
  }

  void show(PendingEncounter pendingEncounter) {
    if (pendingEncounter.cellId != _trustedCellId) return;
    _requestGeneration += 1;
    _retryResolution = null;
    _loadedCellId = pendingEncounter.cellId;
    transition(
      PendingEncounterReady(pendingEncounter),
      'encounter.pending.shown',
      data: {'cell_id': pendingEncounter.cellId},
    );
  }

  Future<void> _resolve(_PendingResolution command) async {
    final pendingEncounter = command.input.pendingEncounter;
    if (pendingEncounter.cellId != _trustedCellId ||
        state is PendingEncounterResolving ||
        state is PendingEncounterResolved) {
      return;
    }
    final request = ++_requestGeneration;
    transition(
      PendingEncounterResolving(pendingEncounter, command.input.optionId),
      'encounter.pending.resolve.started',
      data: {
        'cell_id': pendingEncounter.cellId,
        'encounter_id': pendingEncounter.encounter.id.value,
        'option_id': command.input.optionId.value,
      },
    );
    try {
      final aggregate = await _resolvePendingEncounter(
        command.input,
        parent: command.traceContext,
      );
      if (!_isCurrentResolution(request, pendingEncounter)) return;
      await _presentCommittedReward(
        pendingEncounter,
        aggregate.generatedItemCommits.single,
      );
      if (!_isCurrentResolution(request, pendingEncounter)) return;
      _retryResolution = null;
      transition(
        PendingEncounterResolved(pendingEncounter, aggregate),
        'encounter.pending.resolve.completed',
        data: {
          'cell_id': pendingEncounter.cellId,
          'encounter_id': pendingEncounter.encounter.id.value,
          'option_id': command.input.optionId.value,
        },
      );
    } catch (error) {
      if (!_isCurrentResolution(request, pendingEncounter)) return;
      transition(
        PendingEncounterFailure(
          pendingEncounter: pendingEncounter,
          optionId: command.input.optionId,
        ),
        'encounter.pending.resolve.failed',
        data: {
          'cell_id': pendingEncounter.cellId,
          'encounter_id': pendingEncounter.encounter.id.value,
          'option_id': command.input.optionId.value,
          'error_type': error.runtimeType.toString(),
        },
      );
    }
  }

  bool _isCurrentResolution(int request, PendingEncounter pendingEncounter) {
    return request == _requestGeneration &&
        pendingEncounter.cellId == _trustedCellId &&
        state is PendingEncounterResolving;
  }

  Future<void> _read(String cellId, {required String operation}) async {
    final request = ++_requestGeneration;
    _retryResolution = null;
    _loadedCellId = cellId;
    transition(
      const PendingEncounterLoading(),
      'encounter.pending.$operation.started',
      data: {'cell_id': cellId},
    );
    try {
      final pendingEncounter = await _repository.readPendingEncounterForCell(
        cellId,
        traceId: '${obs.sessionId}:encounter.pending.$operation:$request',
      );
      if (request != _requestGeneration || cellId != _trustedCellId) return;
      transition(
        pendingEncounter == null
            ? const PendingEncounterNone()
            : PendingEncounterReady(pendingEncounter),
        'encounter.pending.$operation.completed',
        data: {
          'cell_id': cellId,
          'has_pending_encounter': pendingEncounter != null,
        },
      );
    } catch (error) {
      if (request != _requestGeneration || cellId != _trustedCellId) return;
      transition(
        const PendingEncounterFailure(),
        'encounter.pending.$operation.failed',
        data: {
          'cell_id': cellId,
          'error_type': error.runtimeType.toString(),
        },
      );
    }
  }
}
