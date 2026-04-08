import 'package:earth_nova/core/domain/entities/user_profile.dart';
import 'package:earth_nova/core/observability/observable_use_case.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/auth/domain/repositories/auth_repository.dart';

class RestoreSession extends ObservableUseCase<void, UserProfile?> {
  RestoreSession(this._repository, this._obs);
  final AuthRepository _repository;
  final ObservabilityService _obs;

  @override
  ObservabilityService get obs => _obs;

  @override
  String get operationName => 'auth.restore_session';

  @override
  Future<UserProfile?> execute(void input, String traceId) async {
    final restored = await _repository.restoreSession(traceId: traceId);
    if (!restored) return null;
    return await _repository.getCurrentUser(traceId: traceId);
  }
}
