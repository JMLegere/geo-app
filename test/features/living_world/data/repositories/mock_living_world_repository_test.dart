import 'package:earth_nova/features/living_world/data/dtos/living_world_dto.dart';
import 'package:earth_nova/features/living_world/data/repositories/mock_living_world_repository.dart';
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
}
