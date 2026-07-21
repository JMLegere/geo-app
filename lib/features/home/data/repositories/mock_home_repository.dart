import 'package:earth_nova/features/home/domain/entities/home.dart';
import 'package:earth_nova/features/home/domain/repositories/home_repository.dart';

/// Deterministic Home read adapter for focused tests and offline previews.
///
/// It returns only a Home explicitly supplied at construction; it never creates
/// an identity implicitly or exposes a mutation surface.
final class MockHomeRepository implements HomeRepository {
  MockHomeRepository({Home? home}) : _home = home;

  final Home? _home;
  int readCount = 0;

  @override
  Future<Home> readHome(
    String playerId, {
    required String traceId,
  }) async {
    readCount += 1;
    final home = _home;
    if (home == null || home.playerId != playerId) {
      throw const HomeFailure.unavailable();
    }
    return home;
  }
}
