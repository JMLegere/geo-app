import 'package:earth_nova/features/map/domain/repositories/wake_lock_repository.dart';

class NoopWakeLockRepository implements WakeLockRepository {
  const NoopWakeLockRepository();

  @override
  Future<void> acquire() async {}

  @override
  Future<void> release() async {}
}
