import 'package:earth_nova/features/map/domain/repositories/wake_lock_repository.dart';

/// Mobile wake lock implementation.
///
/// Native wake lock on iOS/Android requires a platform plugin (e.g.
/// wakelock_plus). Until that dependency is approved, this delegates to
/// no-op behaviour so the contract is satisfied without hard-failing.
class MobileWakeLockRepository implements WakeLockRepository {
  const MobileWakeLockRepository();

  @override
  Future<void> acquire() async {}

  @override
  Future<void> release() async {}
}
