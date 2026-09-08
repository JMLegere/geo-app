import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/app/sync/application/identification_sync_provider.dart';
import 'package:earth_nova/app/save/application/checkpoint_sync_provider.dart';
import 'package:earth_nova/app/save/domain/checkpoint_gateway.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/core/observability/observable_notifier.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/identification/presentation/providers/items_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/map_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/map_readiness_provider.dart';
import 'client_working_set.dart';

enum AppReadinessPhase {
  hydrating,
  usable,
  syncing,
  degraded,
  conflict,
  recovery,
  failed,
}

class AppReadinessState {
  const AppReadinessState({
    required this.phase,
    required this.completedCheckpoints,
    this.errorMessage,
  });

  const AppReadinessState.initial()
    : phase = AppReadinessPhase.hydrating,
      completedCheckpoints = const {},
      errorMessage = null;

  static const requiredCheckpoints = <String>{
    'working_set',
    'pack',
    'map_surface',
  };

  final AppReadinessPhase phase;
  final Set<String> completedCheckpoints;
  final String? errorMessage;

  int get completedRequiredCheckpoints =>
      completedCheckpoints.intersection(requiredCheckpoints).length;
  int get totalRequiredCheckpoints => requiredCheckpoints.length;
  bool get permitsInput =>
      phase == AppReadinessPhase.usable ||
      phase == AppReadinessPhase.syncing ||
      phase == AppReadinessPhase.degraded ||
      phase == AppReadinessPhase.conflict ||
      phase == AppReadinessPhase.recovery;
  bool get isDegraded => phase == AppReadinessPhase.degraded;

  AppReadinessState copyWith({
    AppReadinessPhase? phase,
    Set<String>? completedCheckpoints,
    String? errorMessage,
  }) => AppReadinessState(
    phase: phase ?? this.phase,
    completedCheckpoints: Set<String>.unmodifiable(
      completedCheckpoints ?? this.completedCheckpoints,
    ),
    errorMessage: errorMessage,
  );
}

final appReadinessProvider =
    NotifierProvider<AppReadinessNotifier, AppReadinessState>(
      AppReadinessNotifier.new,
    );

class AppReadinessNotifier extends ObservableNotifier<AppReadinessState> {
  int _generation = 0;
  String? _userId;
  @override
  ObservabilityService get obs => ref.watch(appObservabilityProvider);

  @override
  String get category => 'app';
  String get _environment => ref.read(appReadinessEnvironmentProvider);

  bool get _persistenceEnabled =>
      _environment == 'local' || _environment == 'prod';

  @override
  AppReadinessState build() => const AppReadinessState.initial();

  Future<void> start(String userId) => _start(userId);

  Future<void> retry() {
    final userId = _userId;
    return userId == null ? Future.value() : _start(userId);
  }

  Future<bool> purge(String userId) async {
    final generation = ++_generation;
    if (_userId == userId) _userId = null;
    _flow(
      TelemetryFlowPhase.cancelled,
      eventName: 'app.readiness.cancelled',
      reason: 'sign_out',
    );
    try {
      await ref
          .read(identificationSyncServiceProvider)
          ?.purge(playerId: userId);
      await ref
          .read(clientWorkingSetStoreProvider)
          .purge(environment: _environment, userId: userId);
      if (generation == _generation) {
        transition(
          const AppReadinessState.initial(),
          'app.readiness.state_reset',
        );
      }
      _flow(
        TelemetryFlowPhase.completed,
        eventName: 'app.readiness.snapshot_purged',
        reason: 'sign_out',
      );
      return true;
    } catch (error, stack) {
      ref
          .read(appObservabilityProvider)
          .logError(error, stack, event: 'app.readiness.snapshot_purge_failed');
      if (generation == _generation) {
        transition(
          state.copyWith(
            phase: AppReadinessPhase.failed,
            errorMessage: "Couldn't safely clear this device. Try again.",
          ),
          'app.readiness.state_failed',
        );
      }
      return false;
    }
  }

  Future<void> persistCurrent() {
    final userId = _userId;
    if (userId == null) return Future.value();
    return _commit(_generation, userId);
  }

  Future<void> selectLocalSave() async {
    final sync = ref.read(checkpointSyncCoordinatorProvider);
    await sync?.selectLocalBranch();
    transition(
      state.copyWith(
        phase: AppReadinessPhase.syncing,
        errorMessage: 'Checking this device save before publishing.',
      ),
      'app.readiness.conflict_local_selected',
    );
    if (_userId case final userId?) unawaited(_synchronizeCheckpoint(userId));
  }

  Future<void> selectCloudSave() async {
    final sync = ref.read(checkpointSyncCoordinatorProvider);
    await sync?.selectCloudBranch();
    transition(
      state.copyWith(
        phase: AppReadinessPhase.recovery,
        errorMessage: 'Cloud progress restored. Checking shared updates.',
      ),
      'app.readiness.conflict_cloud_selected',
    );
    if (_userId case final userId?) unawaited(_synchronizeCheckpoint(userId));
  }

  Future<void> _start(String userId) async {
    final generation = ++_generation;
    _userId = userId;
    transition(
      const AppReadinessState.initial(),
      'app.readiness.state_hydrating',
    );
    _flow(TelemetryFlowPhase.started, eventName: 'app.readiness.started');

    ClientWorkingSet? snapshot;
    if (_persistenceEnabled) {
      try {
        snapshot = await ref
            .read(clientWorkingSetStoreProvider)
            .load(environment: _environment, userId: userId);
      } catch (error, stack) {
        ref
            .read(appObservabilityProvider)
            .logError(
              error,
              stack,
              event: 'app.readiness.snapshot_load_failed',
            );
      }
    }
    if (!_isCurrent(generation)) return;

    if (snapshot != null) {
      ref.read(mapProvider.notifier).hydrate(snapshot.map);
      ref.read(itemsProvider.notifier).hydrate(snapshot.items);
      _complete('working_set');
      _complete('pack');
      _flow(
        TelemetryFlowPhase.dependencyReady,
        eventName: 'app.readiness.snapshot_hydrated',
        dependency: 'working_set',
      );

      if (!await _waitForMapSurface(generation)) return;
      _complete('map_surface');
      if (!_isCurrent(generation)) return;
      transition(
        state.copyWith(phase: AppReadinessPhase.usable),
        'app.readiness.state_usable',
      );
      _flow(TelemetryFlowPhase.completed, eventName: 'app.readiness.usable');
      unawaited(_refreshFromSnapshot(generation, snapshot));
      return;
    }

    await _loadCold(generation, userId);
  }

  Future<void> _loadCold(int generation, String userId) async {
    _flow(
      TelemetryFlowPhase.dependencyRequested,
      eventName: 'app.readiness.cold_load_started',
      dependency: 'working_set',
    );
    await Future.wait([
      ref.read(mapProvider.notifier).refresh(),
      ref.read(itemsProvider.notifier).fetchItems(),
    ]);
    if (!_isCurrent(generation)) return;

    final error = _currentLoadError();
    if (error != null) {
      _fail(generation, error);
      return;
    }
    _complete('pack');
    if (!await _waitForMapSurface(generation)) return;
    _complete('map_surface');
    _complete('working_set');
    if (!_isCurrent(generation)) return;

    await _commit(generation, userId);
    if (!_isCurrent(generation)) return;
    transition(
      state.copyWith(phase: AppReadinessPhase.usable),
      'app.readiness.state_usable',
    );
    _flow(TelemetryFlowPhase.completed, eventName: 'app.readiness.usable');
    unawaited(_recoverPendingIdentification(generation, userId));
  }

  Future<void> _refreshFromSnapshot(
    int generation,
    ClientWorkingSet snapshot,
  ) async {
    if (!_isCurrent(generation)) return;
    transition(
      state.copyWith(phase: AppReadinessPhase.syncing),
      'app.readiness.state_syncing',
    );
    _flow(
      TelemetryFlowPhase.dependencyRequested,
      eventName: 'app.readiness.refresh_started',
      dependency: 'working_set',
    );
    final results = await Future.wait<Object?>([
      ref.read(mapProvider.notifier).refresh(),
      ref.read(itemsProvider.notifier).fetchItems(),
    ]);
    if (!_isCurrent(generation)) return;

    final error = results.first != true
        ? "Couldn't refresh your map. Using your saved expedition."
        : _currentLoadError();
    if (error != null) {
      ref.read(mapProvider.notifier).hydrate(snapshot.map);
      ref.read(itemsProvider.notifier).hydrate(snapshot.items);
      transition(
        state.copyWith(phase: AppReadinessPhase.degraded, errorMessage: error),
        'app.readiness.state_degraded',
      );
      _flow(
        TelemetryFlowPhase.dependencyFailed,
        eventName: 'app.readiness.degraded',
        dependency: 'working_set',
        reason: error,
      );
      unawaited(_recoverPendingIdentification(generation, snapshot.userId));
      return;
    }

    await _commit(generation, snapshot.userId);
    if (!_isCurrent(generation)) return;
    transition(
      state.copyWith(phase: AppReadinessPhase.usable),
      'app.readiness.state_usable',
    );
    _flow(
      TelemetryFlowPhase.completed,
      eventName: 'app.readiness.refresh_completed',
    );
    unawaited(_recoverPendingIdentification(generation, snapshot.userId));
  }

  Future<void> _recoverPendingIdentification(
    int generation,
    String userId,
  ) async {
    final sync = ref.read(identificationSyncServiceProvider);
    if (sync == null || !_isCurrent(generation)) return;
    try {
      await sync.resumeAfterAuthentication(
        playerId: userId,
        applyCanonicalResult: (result) async {
          if (!_isCurrent(generation)) return;
          ref
              .read(itemsProvider.notifier)
              .registerOwnedDiscovery(result.committedItem);
          await _commit(generation, userId);
        },
      );
    } catch (error, stack) {
      ref
          .read(appObservabilityProvider)
          .logError(error, stack, event: 'sync.recovery.failed');
    }
  }

  Future<void> _commit(int generation, String userId) async {
    if (!_persistenceEnabled) {
      _flow(
        TelemetryFlowPhase.completed,
        eventName: 'app.readiness.snapshot_skipped',
        reason: 'environment_unconfigured',
      );
      return;
    }
    final map = ref.read(mapProvider);
    final items = ref.read(itemsProvider).items;
    if (map is! MapStateReady || !_isCurrent(generation)) return;

    final saved = await ref
        .read(clientWorkingSetStoreProvider)
        .save(
          ClientWorkingSet(
            environment: _environment,
            userId: userId,
            capturedAt: DateTime.now().toUtc(),
            map: map,
            items: items,
          ),
        );
    if (!_isCurrent(generation)) return;
    _flow(
      saved
          ? TelemetryFlowPhase.completed
          : TelemetryFlowPhase.dependencyFailed,
      eventName: saved
          ? 'app.readiness.snapshot_committed'
          : 'app.readiness.snapshot_commit_skipped',
      dependency: 'working_set',
    );
    if (saved) unawaited(_synchronizeCheckpoint(userId));
  }

  Future<void> _synchronizeCheckpoint(String userId) async {
    final sync = ref.read(checkpointSyncCoordinatorProvider);
    if (sync == null) return;
    try {
      await sync.restore(environment: _environment, playerId: userId);
      await sync.reconcile();
      final result = await sync.synchronize();
      if (result is CheckpointConflict) {
        transition(
          state.copyWith(
            phase: AppReadinessPhase.conflict,
            errorMessage:
                'This device and the cloud both have progress. Choose one complete save; the other is kept for recovery.',
          ),
          'app.readiness.state_conflict',
        );
      } else if (result is CheckpointRejected) {
        transition(
          state.copyWith(
            phase: AppReadinessPhase.recovery,
            errorMessage:
                'Your progress is saved on this device, but it needs attention before publishing.',
          ),
          'app.readiness.state_recovery',
        );
      }
    } catch (error, stack) {
      ref
          .read(appObservabilityProvider)
          .logError(error, stack, event: 'checkpoint.background_sync_failed');
    }
  }

  Future<bool> _waitForMapSurface(int generation) async {
    final deadline = DateTime.now().add(const Duration(seconds: 12));
    while (_isCurrent(generation) &&
        !ref.read(mapReadinessProvider).isSteadyStateReady &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    if (!_isCurrent(generation)) return false;
    if (!ref.read(mapReadinessProvider).isSteadyStateReady) {
      _fail(generation, 'Map is taking too long to prepare.');
      return false;
    }
    return true;
  }

  String? _currentLoadError() {
    final map = ref.read(mapProvider);
    if (map is MapStateError) return map.message;
    final items = ref.read(itemsProvider);
    return items.error;
  }

  void _fail(int generation, String message) {
    if (!_isCurrent(generation)) return;
    transition(
      state.copyWith(phase: AppReadinessPhase.failed, errorMessage: message),
      'app.readiness.state_failed',
    );
    _flow(
      TelemetryFlowPhase.failed,
      eventName: 'app.readiness.failed',
      reason: message,
    );
  }

  void _complete(String checkpoint) {
    transition(
      state.copyWith(
        completedCheckpoints: {...state.completedCheckpoints, checkpoint},
      ),
      'app.readiness.checkpoint_completed',
      data: {'checkpoint': checkpoint},
    );
  }

  bool _isCurrent(int generation) =>
      generation == _generation && _userId != null;

  void _flow(
    TelemetryFlowPhase phase, {
    required String eventName,
    String? dependency,
    String? reason,
  }) {
    ref
        .read(appObservabilityProvider)
        .logFlowEvent(
          'app.readiness',
          phase,
          'app',
          eventName: eventName,
          dependency: dependency,
          reason: reason,
        );
  }
}

final appReadinessEnvironmentProvider = Provider<String>(
  (_) => const String.fromEnvironment(
    'DEPLOYMENT_ENVIRONMENT',
    defaultValue: 'unknown',
  ),
);
