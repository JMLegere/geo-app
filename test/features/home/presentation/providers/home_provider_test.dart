import 'dart:async';
import 'dart:io';

import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/home/domain/entities/home.dart';
import 'package:earth_nova/features/home/domain/repositories/home_repository.dart';
import 'package:earth_nova/features/home/presentation/providers/home_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../home_test_data.dart';

final class RecordingObservabilityService extends ObservabilityService {
  RecordingObservabilityService() : super(sessionId: 'home-test');

  final List<Map<String, dynamic>> events = [];

  @override
  void log(String event, String category, {Map<String, dynamic>? data}) {
    events.add({'event': event, 'category': category, ...?data});
  }
}

final class FakeHomeRepository implements HomeRepository {
  Future<Home> Function(String playerId)? onRead;
  int reads = 0;

  @override
  Future<Home> readHome(String playerId, {required String traceId}) async {
    reads += 1;
    return onRead!(playerId);
  }
}

ProviderContainer containerFor(
  FakeHomeRepository repository,
  RecordingObservabilityService observability,
) =>
    ProviderContainer(overrides: [
      homeRepositoryProvider.overrideWithValue(repository),
      homeObservabilityProvider.overrideWithValue(observability),
    ]);

Home testHome() => Home(
      id: homeId,
      playerId: playerId,
      createdAt: DateTime.parse(createdAt),
    );

void main() {
  group('HomeNotifier', () {
    test('loads, refreshes, invalidates, and recreates Home state', () async {
      final repository = FakeHomeRepository()..onRead = (_) async => testHome();
      final observability = RecordingObservabilityService();
      final container = containerFor(repository, observability);
      addTearDown(container.dispose);

      await container.read(homeProvider.notifier).load(playerId);
      await container.read(homeProvider.notifier).refresh(playerId);
      expect(repository.reads, 2);
      expect(container.read(homeProvider).home!.id, homeId);
      container.read(homeProvider.notifier).invalidate();
      expect(container.read(homeProvider).home, isNull);

      final recreated = containerFor(repository, observability);
      addTearDown(recreated.dispose);
      expect(recreated.read(homeProvider).home, isNull);
      await recreated.read(homeProvider.notifier).load(playerId);
      expect(repository.reads, 3);
      expect(observability.events.map((event) => event['event']),
          contains('home.refresh.completed'));
    });

    test('drops stale completions and keeps current Home', () async {
      final stale = Completer<Home>();
      final refreshed = testHome();
      var readCount = 0;
      final repository = FakeHomeRepository()
        ..onRead = (_) {
          readCount += 1;
          return readCount == 1 ? stale.future : Future<Home>.value(refreshed);
        };
      final observability = RecordingObservabilityService();
      final container = containerFor(repository, observability);
      addTearDown(container.dispose);

      final pending = container.read(homeProvider.notifier).load(playerId);
      await container.read(homeProvider.notifier).refresh(playerId);
      stale.complete(testHome());
      await pending;

      expect(container.read(homeProvider).home, same(refreshed));
      expect(observability.events.join(), isNot(contains('database password')));
    });

    test('exposes a safe error state and telemetry category', () async {
      final repository = FakeHomeRepository()
        ..onRead = (_) => Future<Home>.error(StateError('database password'));
      final observability = RecordingObservabilityService();
      final container = containerFor(repository, observability);
      addTearDown(container.dispose);

      await container.read(homeProvider.notifier).load(playerId);

      expect(container.read(homeProvider).error,
          'Unable to load your Home. Pull to retry.');
      expect(observability.events.join(), isNot(contains('database password')));
      expect(observability.events.last['failure_kind'], 'unavailable');
    });

    test('introduces no Home Module or Orb behavior APIs', () {
      final root = Directory('lib/features/home');
      final source = root
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .map((file) => file.readAsStringSync())
          .join('\n');

      expect(source, isNot(contains('HomeModule')));
      expect(source, isNot(contains('Orb')));
      expect(source, isNot(contains('placeItem')));
      expect(source, isNot(contains('createHome')));
      expect(source, isNot(contains('updateHome')));
    });
  });
}
