import 'package:earth_nova/core/domain/entities/user_profile.dart';
import 'package:earth_nova/core/observability/observable_use_case.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/auth/domain/repositories/auth_repository.dart';

class GetCurrentUser extends ObservableUseCase<void, UserProfile?> {
  const GetCurrentUser(this._repository, this._obs);
  final AuthRepository _repository;
  final ObservabilityService _obs;

  @override
  ObservabilityService get obs => _obs;

  @override
  String get operationName => 'auth.get_current_user';

  @override
  Future<UserProfile?> execute(void input, String traceId) async {
    return await _repository.getCurrentUser(traceId: traceId);
  }
}
