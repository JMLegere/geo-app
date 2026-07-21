import 'package:earth_nova/features/living_world/data/dtos/living_world_dto.dart';
import 'package:earth_nova/features/living_world/data/repositories/mock_living_world_repository.dart';
import 'package:earth_nova/features/living_world/domain/entities/living_world_knowledge.dart';
import 'package:earth_nova/features/living_world/domain/repositories/living_world_repository.dart';
import 'package:earth_nova/features/map/domain/entities/cell_visit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../living_world_test_data.dart';

void main() {
  test(
      'MockLivingWorldRepository replaces its durable Town only from command result',
      () async {
    final initial = LivingWorldTownDto.fromJson(town(withVillager: false),
            playerId: playerId)
        .toDomain();
    final committed = LivingWorldVenueVisitResultDto.fromJson(recordResponse(),
            command: command())
        .toDomain();
    final visitCommand = command();
    final repository = MockLivingWorldRepository(
      town: initial,
      recordVenueVisit: (_) async => committed,
    );

    expect(
        (await repository.readTown(playerId, traceId: 'read'))
            .venues
            .single
            .villagers,
        isEmpty);
    await repository.recordVenueVisit(visitCommand, traceId: 'visit');

    expect(repository.recordedVenueVisits, [same(visitCommand)]);
    expect(
        (await repository.readTown(playerId, traceId: 'read'))
            .venues
            .single
            .villagers,
        hasLength(1));
  });

  test('rejects reads and commands that lack a durable response', () async {
    final repository = MockLivingWorldRepository();

    await expectLater(
      repository.readTown(playerId, traceId: 'read-trace'),
      throwsA(
        isA<LivingWorldFailure>().having(
          (failure) => failure.kind,
          'kind',
          LivingWorldFailureKind.unavailable,
        ),
      ),
    );
    await expectLater(
      repository.recordVenueVisit(command(), traceId: 'command-trace'),
      throwsA(
        isA<LivingWorldFailure>().having(
          (failure) => failure.kind,
          'kind',
          LivingWorldFailureKind.unavailable,
        ),
      ),
    );
  });

  test('rejects a command result that does not match its visit evidence',
      () async {
    final committed = LivingWorldVenueVisitResultDto.fromJson(recordResponse(),
            command: command())
        .toDomain();
    final expected = command();
    final conflicting = RecordVenueVisitCommand(
      cellVisit: CellVisit(
        id: 'different-cell-visit',
        cellId: expected.cellVisit.cellId,
        userId: playerId,
        visitedAt: expected.cellVisit.visitedAt,
      ),
      venueId: expected.venueId,
      venueVersion: expected.venueVersion,
    );
    final repository = MockLivingWorldRepository(
      recordVenueVisit: (_) async => committed,
    );

    await expectLater(
      repository.recordVenueVisit(conflicting, traceId: 'command-trace'),
      throwsA(
        isA<LivingWorldFailure>().having(
          (failure) => failure.kind,
          'kind',
          LivingWorldFailureKind.malformedPayload,
        ),
      ),
    );
    expect(repository.recordedVenueVisits, [same(conflicting)]);
  });
}
