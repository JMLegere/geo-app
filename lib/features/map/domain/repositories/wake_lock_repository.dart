abstract class WakeLockRepository {
  Future<void> acquire();
  Future<void> release();
}
