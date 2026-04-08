import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/core/observability/observable_notifier.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/map/domain/repositories/wake_lock_repository.dart';

enum WakeLockState { released, acquired }

final wakeLockObservabilityProvider = Provider<ObservabilityService>((ref) {
  throw UnimplementedError('Must be overridden with overrideWithValue');
});

final wakeLockRepositoryProvider = Provider<WakeLockRepository>((ref) {
  throw UnimplementedError('Must be overridden with overrideWithValue');
});

final wakeLockProvider =
    NotifierProvider<WakeLockNotifier, WakeLockState>(WakeLockNotifier.new);

class WakeLockNotifier extends ObservableNotifier<WakeLockState> {
  late WakeLockRepository _repository;

  @override
  ObservabilityService get obs => ref.watch(wakeLockObservabilityProvider);

  @override
  String get category => 'map';

  @override
  WakeLockState build() {
    _repository = ref.watch(wakeLockRepositoryProvider);
    ref.onDispose(() {
      _repository.release().ignore();
    });
    return WakeLockState.released;
  }

  Future<void> acquire() async {
    try {
      await _repository.acquire();
      transition(WakeLockState.acquired, 'map.wake_lock_acquired');
    } catch (_) {
      transition(WakeLockState.released, 'map.wake_lock_acquire_failed');
    }
  }

  Future<void> release() async {
    try {
      await _repository.release();
    } catch (_) {
      // Best-effort release — ignore errors
    }
    transition(WakeLockState.released, 'map.wake_lock_released');
  }
}
