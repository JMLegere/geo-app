import 'package:earth_nova/features/home/domain/entities/home.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('preserves immutable Home identity', () {
    final home = Home(
      id: '10000000-0000-4000-8000-000000000001',
      playerId: '20000000-0000-4000-8000-000000000002',
      createdAt: DateTime.parse('2026-07-21T00:00:00.000Z'),
    );

    expect(home.id, '10000000-0000-4000-8000-000000000001');
    expect(home.playerId, '20000000-0000-4000-8000-000000000002');
    expect(home.createdAt, DateTime.utc(2026, 7, 21));
  });

  test('rejects blank immutable identity values', () {
    expect(
      () => Home(id: ' ', playerId: 'player', createdAt: DateTime.utc(2026)),
      throwsArgumentError,
    );
    expect(
      () => Home(id: 'home', playerId: ' ', createdAt: DateTime.utc(2026)),
      throwsArgumentError,
    );
  });
}
