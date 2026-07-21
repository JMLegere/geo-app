import 'package:earth_nova/core/observability/observable_notifier.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/home/domain/entities/home.dart';
import 'package:earth_nova/features/home/domain/repositories/home_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bootstrap supplies the authoritative durable Home adapter.
final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  throw UnimplementedError('Home repository must be provided by bootstrap.');
});

/// Bootstrap supplies the safe observability sink for Home reads.
final homeObservabilityProvider = Provider<ObservabilityService>((ref) {
  throw UnimplementedError('Home observability must be provided by bootstrap.');
});

/// Durable presentation state for the Player's immutable Home identity.
final class HomeState {
  const HomeState({
    this.playerId,
    this.home,
    this.isLoading = false,
    this.error,
  });

  final String? playerId;
  final Home? home;
  final bool isLoading;
  final String? error;

  bool shouldLoadFor(String nextPlayerId) =>
      playerId != nextPlayerId && !isLoading;
}

/// Read-only controller for the server-owned Home identity.
final homeProvider =
    NotifierProvider<HomeNotifier, HomeState>(HomeNotifier.new);

final class HomeNotifier extends ObservableNotifier<HomeState> {
  late HomeRepository _repository;
  int _requestGeneration = 0;

  @override
  ObservabilityService get obs => ref.watch(homeObservabilityProvider);

  @override
  String get category => 'home';

  @override
  HomeState build() {
    _repository = ref.watch(homeRepositoryProvider);
    return const HomeState();
  }

  /// Loads the authenticated Player's server-owned Home identity.
  Future<void> load(String playerId) => _read(playerId, 'home.load');

  /// Re-reads the authoritative Home identity without mutating it.
  Future<void> refresh(String playerId) => _read(playerId, 'home.refresh');

  /// Drops local Home state and prevents displaced requests from restoring it.
  void invalidate() {
    _requestGeneration += 1;
    transition(const HomeState(), 'home.invalidate');
  }

  Future<void> _read(String playerId, String operation) async {
    final request = ++_requestGeneration;
    final previousHome = state.home?.playerId == playerId ? state.home : null;
    transition(
      HomeState(playerId: playerId, home: previousHome, isLoading: true),
      '$operation.started',
    );
    try {
      final home = await _repository.readHome(
        playerId,
        traceId: _traceId(operation, request),
      );
      if (request != _requestGeneration) return;
      transition(
        HomeState(playerId: playerId, home: home),
        '$operation.completed',
        data: {'home_id': home.id},
      );
    } catch (error) {
      if (request != _requestGeneration) return;
      transition(
        HomeState(
          playerId: playerId,
          home: previousHome,
          error: 'Unable to load your Home. Pull to retry.',
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
      HomeFailure(:final kind) => kind.name,
      _ => HomeFailureKind.unavailable.name,
    };
