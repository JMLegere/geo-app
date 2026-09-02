import 'dart:async';

import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/living_world/data/dtos/living_world_dto.dart';
import 'package:earth_nova/features/living_world/domain/entities/living_world_knowledge.dart';
import 'package:earth_nova/features/living_world/domain/entities/town_projection.dart';
import 'package:earth_nova/features/living_world/domain/repositories/living_world_repository.dart';
import 'package:earth_nova/features/living_world/presentation/providers/town_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/living_world_test_data.dart';

final class RecordingObservabilityService extends ObservabilityService {
  RecordingObservabilityService() : super(sessionId: 'living-world-test');

  final List<Map<String, dynamic>> events = [];

  @override
  void log(String event, String category, {Map<String, dynamic>? data}) {
    events.add({'event': event, 'category': category, ...?data});
  }
}

final class FakeLivingWorldRepository implements LivingWorldRepository {
  Future<TownProjection> Function(String playerId)? onRead;
  Future<VenueVisitResult> Function(RecordVenueVisitCommand command)? onRecord;
  int reads = 0;
  int records = 0;

  @override
  Future<TownProjection> readTown(
    String playerId, {
    required String traceId,
  }) async {
    reads += 1;
    return onRead!(playerId);
  }

  @override
  Future<VenueVisitResult> recordVenueVisit(
    RecordVenueVisitCommand command, {
    required String traceId,
  }) async {
    records += 1;
    return onRecord!(command);
  }
}

ProviderContainer containerFor(
  FakeLivingWorldRepository repository,
  RecordingObservabilityService observability,
) => ProviderContainer(
  overrides: [
    livingWorldRepositoryProvider.overrideWithValue(repository),
    livingWorldObservabilityProvider.overrideWithValue(observability),
  ],
);

void main() {
  group('TownNotifier', () {
    test(
      'loads, refreshes, invalidates, and recreates durable Town state',
      () async {
        final repository = FakeLivingWorldRepository()
          ..onRead = (_) async => LivingWorldTownDto.fromJson(
            town(withVillager: false),
            playerId: playerId,
          ).toDomain();
        final observability = RecordingObservabilityService();
        final container = containerFor(repository, observability);
        addTearDown(container.dispose);

        await container.read(townProvider.notifier).load(playerId);
        await container.read(townProvider.notifier).refresh(playerId);
        expect(repository.reads, 2);
        expect(
          container.read(townProvider).town!.venues.single.villagers,
          isEmpty,
        );
        container.read(townProvider.notifier).invalidate();
        expect(container.read(townProvider).town, isNull);

        final recreated = containerFor(repository, observability);
        addTearDown(recreated.dispose);
        expect(recreated.read(townProvider).town, isNull);
        await recreated.read(townProvider.notifier).load(playerId);
        expect(repository.reads, 3);
        expect(
          observability.events.map((event) => event['event']),
          contains('town.refresh.completed'),
        );
      },
    );

    test(
      'explicit command atomically replaces Town without screen-open mutation',
      () async {
        final repository = FakeLivingWorldRepository();
        repository.onRead = (_) async => LivingWorldTownDto.fromJson(
          town(withVillager: false),
          playerId: playerId,
        ).toDomain();
        repository.onRecord = (_) async =>
            LivingWorldVenueVisitResultDto.fromJson(
              recordResponse(),
              command: command(),
            ).toDomain();
        final observability = RecordingObservabilityService();
        final container = containerFor(repository, observability);
        addTearDown(container.dispose);

        container.read(townProvider);
        expect(repository.records, 0);
        await container.read(townProvider.notifier).load(playerId);
        await container.read(townProvider.notifier).recordVenueVisit(command());

        expect(repository.records, 1);
        expect(
          container.read(townProvider).town!.venues.single.villagers,
          hasLength(1),
        );
        expect(container.read(townProvider).isRecordingVenueVisit, isFalse);
      },
    );

    test(
      'drops stale command completions and keeps terminal telemetry safe',
      () async {
        final record = Completer<VenueVisitResult>();
        final refreshed = LivingWorldTownDto.fromJson(
          town(withVillager: false),
          playerId: playerId,
        ).toDomain();
        final repository = FakeLivingWorldRepository();
        repository.onRead = (_) async => refreshed;
        repository.onRecord = (_) => record.future;
        final observability = RecordingObservabilityService();
        final container = containerFor(repository, observability);
        addTearDown(container.dispose);

        final pending = container
            .read(townProvider.notifier)
            .recordVenueVisit(command());
        await container.read(townProvider.notifier).refresh(playerId);
        record.complete(
          LivingWorldVenueVisitResultDto.fromJson(
            recordResponse(),
            command: command(),
          ).toDomain(),
        );
        await pending;

        expect(container.read(townProvider).town, same(refreshed));
        expect(
          observability.events.join(),
          isNot(contains('database password')),
        );
      },
    );

    test(
      'turns unsafe failures into a safe state and telemetry category',
      () async {
        final repository = FakeLivingWorldRepository()
          ..onRead = (_) =>
              Future<TownProjection>.error(StateError('database password'));
        final observability = RecordingObservabilityService();
        final container = containerFor(repository, observability);
        addTearDown(container.dispose);

        await container.read(townProvider.notifier).load(playerId);

        expect(
          container.read(townProvider).error,
          'Unable to load your Town. Try again.',
        );
        expect(
          observability.events.join(),
          isNot(contains('database password')),
        );
        expect(observability.events.last['failure_kind'], 'unavailable');
      },
    );

    test(
      'keeps the matching Town on a safe terminal visit-command failure',
      () async {
        final initial = LivingWorldTownDto.fromJson(
          town(withVillager: false),
          playerId: playerId,
        ).toDomain();
        final repository = FakeLivingWorldRepository();
        repository.onRead = (_) async => initial;
        repository.onRecord = (_) => Future<VenueVisitResult>.error(
          const LivingWorldFailure.cellVisitNotOwned(),
        );
        final observability = RecordingObservabilityService();
        final container = containerFor(repository, observability);
        addTearDown(container.dispose);

        await container.read(townProvider.notifier).load(playerId);
        await container.read(townProvider.notifier).recordVenueVisit(command());

        final state = container.read(townProvider);
        expect(state.town, same(initial));
        expect(state.isRecordingVenueVisit, isFalse);
        expect(state.error, 'Unable to update your Town. Please try again.');
        expect(
          observability.events.last['event'],
          'town.record_venue_visit.failed',
        );
        expect(observability.events.last['failure_kind'], 'cellVisitNotOwned');
      },
    );
  });
}
