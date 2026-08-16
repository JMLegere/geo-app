import 'dart:async';

import 'package:earth_nova/core/observability/observable_notifier.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/encounters/domain/entities/encounter_entities.dart';
import 'package:earth_nova/features/encounters/domain/repositories/encounter_repository.dart';
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

final class PendingEncounterFailure extends PendingEncounterState {
  const PendingEncounterFailure();
}

final pendingEncounterProvider =
    NotifierProvider<PendingEncounterNotifier, PendingEncounterState>(
  PendingEncounterNotifier.new,
);

class PendingEncounterNotifier
    extends ObservableNotifier<PendingEncounterState> {
  late EncounterRepository _repository;
  String? _trustedCellId;
  String? _loadedCellId;
  int _requestGeneration = 0;

  @override
  ObservabilityService get obs => ref.watch(explorationObservabilityProvider);

  @override
  String get category => 'encounter';

  @override
  PendingEncounterState build() {
    _repository = ref.watch(encounterCommandRepositoryProvider);
    final currentCellId = ref.watch(
      explorationProvider.select((state) => state.currentCellId),
    );
    final canRecordVisits = ref.watch(
      explorationEligibilityProvider.select(
        (eligibility) => eligibility.canRecordVisits,
      ),
    );
    final trustedCellId = canRecordVisits ? currentCellId : null;

    if (trustedCellId != _trustedCellId) {
      _trustedCellId = trustedCellId;
      _loadedCellId = null;
      _requestGeneration += 1;
      if (trustedCellId != null) {
        Future<void>.microtask(load);
      }
    }

    return const PendingEncounterNone();
  }

  Future<void> load() async {
    final cellId = _trustedCellId;
    if (cellId == null || _loadedCellId == cellId) return;
    await _read(cellId, operation: 'load');
  }

  Future<void> refresh() async {
    final cellId = _trustedCellId;
    if (cellId == null) return;
    await _read(cellId, operation: 'refresh');
  }

  void show(PendingEncounter pendingEncounter) {
    if (pendingEncounter.cellId != _trustedCellId) return;
    _requestGeneration += 1;
    _loadedCellId = pendingEncounter.cellId;
    transition(
      PendingEncounterReady(pendingEncounter),
      'encounter.pending.shown',
      data: {'cell_id': pendingEncounter.cellId},
    );
  }

  Future<void> _read(String cellId, {required String operation}) async {
    final request = ++_requestGeneration;
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
