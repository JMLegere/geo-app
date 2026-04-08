import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/map/domain/repositories/wake_lock_repository.dart';
import 'package:earth_nova/features/map/presentation/providers/wake_lock_provider.dart';

class TestObservabilityService extends ObservabilityService {
  TestObservabilityService() : super(sessionId: 'test-session');

  final List<({String event, String category, Map<String, dynamic>? data})>
      events = [];

  @override
  void log(String event, String category, {Map<String, dynamic>? data}) {
    events.add((event: event, category: category, data: data));
    super.log(event, category, data: data);
  }

  List<String> get eventNames => events.map((e) => e.event).toList();
}

class FakeWakeLockRepository implements WakeLockRepository {
  int acquireCount = 0;
  int releaseCount = 0;
  bool _acquireThrows = false;
  bool _releaseThrows = false;

  void setAcquireThrows(bool value) => _acquireThrows = value;
  void setReleaseThrows(bool value) => _releaseThrows = value;

  @override
  Future<void> acquire() async {
    if (_acquireThrows) throw Exception('Wake lock unsupported');
    acquireCount++;
  }

  @override
  Future<void> release() async {
    if (_releaseThrows) throw Exception('Release failed');
    releaseCount++;
  }
}

void main() {
  group('WakeLockNotifier', () {
    late ProviderContainer container;
    late TestObservabilityService obs;
    late FakeWakeLockRepository repo;

    setUp(() {
      obs = TestObservabilityService();
      repo = FakeWakeLockRepository();
      container = ProviderContainer(
        overrides: [
          wakeLockObservabilityProvider.overrideWithValue(obs),
          wakeLockRepositoryProvider.overrideWithValue(repo),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is released', () {
      final state = container.read(wakeLockProvider);
      expect(state, WakeLockState.released);
    });

    test('acquire transitions state to acquired', () async {
      container.read(wakeLockProvider.notifier).acquire();
      await Future<void>.delayed(Duration.zero);

      expect(container.read(wakeLockProvider), WakeLockState.acquired);
    });

    test('acquire calls repository.acquire once', () async {
      container.read(wakeLockProvider.notifier).acquire();
      await Future<void>.delayed(Duration.zero);

      expect(repo.acquireCount, 1);
    });

    test('release transitions state to released', () async {
      container.read(wakeLockProvider.notifier).acquire();
      await Future<void>.delayed(Duration.zero);

      container.read(wakeLockProvider.notifier).release();
      await Future<void>.delayed(Duration.zero);

      expect(container.read(wakeLockProvider), WakeLockState.released);
    });

    test('release calls repository.release once', () async {
      container.read(wakeLockProvider.notifier).acquire();
      await Future<void>.delayed(Duration.zero);

      container.read(wakeLockProvider.notifier).release();
      await Future<void>.delayed(Duration.zero);

      expect(repo.releaseCount, 1);
    });

    test('acquire logs map.wake_lock_acquired event', () async {
      container.read(wakeLockProvider.notifier).acquire();
      await Future<void>.delayed(Duration.zero);

      expect(obs.eventNames, contains('map.wake_lock_acquired'));
    });

    test('release logs map.wake_lock_released event', () async {
      container.read(wakeLockProvider.notifier).acquire();
      await Future<void>.delayed(Duration.zero);

      container.read(wakeLockProvider.notifier).release();
      await Future<void>.delayed(Duration.zero);

      expect(obs.eventNames, contains('map.wake_lock_released'));
    });

    test('acquire failure does not hard-fail — state stays released', () async {
      repo.setAcquireThrows(true);

      container.read(wakeLockProvider.notifier).acquire();
      await Future<void>.delayed(Duration.zero);

      expect(container.read(wakeLockProvider), WakeLockState.released);
    });

    test('acquire failure logs map.wake_lock_acquire_failed event', () async {
      repo.setAcquireThrows(true);

      container.read(wakeLockProvider.notifier).acquire();
      await Future<void>.delayed(Duration.zero);

      expect(obs.eventNames, contains('map.wake_lock_acquire_failed'));
    });

    test('release failure does not hard-fail — state transitions to released',
        () async {
      container.read(wakeLockProvider.notifier).acquire();
      await Future<void>.delayed(Duration.zero);

      repo.setReleaseThrows(true);
      container.read(wakeLockProvider.notifier).release();
      await Future<void>.delayed(Duration.zero);

      // Even on release error, we consider it released (best-effort)
      expect(container.read(wakeLockProvider), WakeLockState.released);
    });

    test('uses category map for all events', () async {
      container.read(wakeLockProvider.notifier).acquire();
      await Future<void>.delayed(Duration.zero);

      container.read(wakeLockProvider.notifier).release();
      await Future<void>.delayed(Duration.zero);

      for (final event in obs.events) {
        expect(event.category, 'map');
      }
    });
  });
}
