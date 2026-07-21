import 'package:earth_nova/core/observability/observable_notifier.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/living_world/domain/entities/living_world_knowledge.dart';
import 'package:earth_nova/features/living_world/domain/entities/town_projection.dart';
import 'package:earth_nova/features/living_world/domain/repositories/living_world_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bootstrap supplies the authoritative durable Town adapter.
final livingWorldRepositoryProvider = Provider<LivingWorldRepository>((ref) {
  throw UnimplementedError(
      'Living World repository must be provided by bootstrap.');
});

/// Bootstrap supplies the safe observability sink for this read/command flow.
final livingWorldObservabilityProvider = Provider<ObservabilityService>((ref) {
  throw UnimplementedError(
      'Living World observability must be provided by bootstrap.');
});

/// Durable Town presentation state. The projection is never derived from map
/// entry, local player knowledge, Items, or any physical trigger.
final class TownState {
  const TownState({
    this.playerId,
    this.town,
    this.isLoading = false,
    this.isRecordingVenueVisit = false,
    this.error,
  });

  /// The authenticated Player whose projection is being loaded, loaded, or
  /// errored. It prevents screen rebuilds from repeatedly issuing reads.
  final String? playerId;
  final TownProjection? town;
  final bool isLoading;
  final bool isRecordingVenueVisit;
  final String? error;

  bool shouldLoadFor(String nextPlayerId) =>
      playerId != nextPlayerId && !isLoading;
}

/// Read/command controller for the durable Town projection.
final townProvider =
    NotifierProvider<TownNotifier, TownState>(TownNotifier.new);

final class TownNotifier extends ObservableNotifier<TownState> {
  late LivingWorldRepository _repository;
  int _requestGeneration = 0;

  @override
  ObservabilityService get obs => ref.watch(livingWorldObservabilityProvider);

  @override
  String get category => 'living_world';

  @override
  TownState build() {
    _repository = ref.watch(livingWorldRepositoryProvider);
    return const TownState();
  }

  /// Loads the authenticated player's server-owned Town projection.
  Future<void> load(String playerId) => _read(playerId, 'town.load');

  /// Re-reads authoritative Town state without revealing or mutating content.
  Future<void> refresh(String playerId) => _read(playerId, 'town.refresh');

  /// Discards the local projection. A displaced in-flight request cannot
  /// repopulate state after invalidation.
  void invalidate() {
    _requestGeneration += 1;
    transition(const TownState(), 'town.invalidate');
  }

  /// Explicitly records an already-persisted Cell Visit. This controller is
  /// intentionally not wired to screen open, map taps, location, or GPS.
  Future<void> recordVenueVisit(RecordVenueVisitCommand command) async {
    final request = ++_requestGeneration;
    transition(
      TownState(
        playerId: command.playerId,
        town: state.town?.playerId == command.playerId ? state.town : null,
        isRecordingVenueVisit: true,
      ),
      'town.record_venue_visit.started',
    );
    try {
      final result = await _repository.recordVenueVisit(
        command,
        traceId: _traceId('record_venue_visit', request),
      );
      if (request != _requestGeneration) return;
      transition(
        TownState(playerId: result.town.playerId, town: result.town),
        'town.record_venue_visit.completed',
        data: {
          'idempotent_retry': result.isIdempotentRetry,
          'introduced_villager_count': result.introducedVillagers.length,
        },
      );
    } catch (error) {
      if (request != _requestGeneration) return;
      transition(
        TownState(
          playerId: command.playerId,
          town: state.town?.playerId == command.playerId ? state.town : null,
          error: 'Unable to update your Town. Please try again.',
        ),
        'town.record_venue_visit.failed',
        data: {'failure_kind': _safeFailureKind(error)},
      );
    }
  }

  Future<void> _read(String playerId, String operation) async {
    final request = ++_requestGeneration;
    final previousTown = state.town?.playerId == playerId ? state.town : null;
    transition(
      TownState(playerId: playerId, town: previousTown, isLoading: true),
      '$operation.started',
    );
    try {
      final town = await _repository.readTown(
        playerId,
        traceId: _traceId(operation, request),
      );
      if (request != _requestGeneration) return;
      transition(
        TownState(playerId: playerId, town: town),
        '$operation.completed',
        data: {'venue_count': town.venues.length},
      );
    } catch (error) {
      if (request != _requestGeneration) return;
      transition(
        TownState(
          playerId: playerId,
          town: previousTown,
          error: 'Unable to load your Town. Pull to retry.',
        ),
        '$operation.failed',
        data: {'failure_kind': _safeFailureKind(error)},
      );
    }
  }

  String _traceId(String operation, int request) =>
      '${obs.sessionId}:$operation:$request';
}

String _safeFailureKind(Object error) => switch (error) {
      LivingWorldFailure(:final kind) => kind.name,
      _ => LivingWorldFailureKind.unavailable.name,
    };
