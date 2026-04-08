import 'package:earth_nova/core/observability/observable_use_case.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/auth/domain/repositories/auth_repository.dart';

class SignOut extends ObservableUseCase<void, void> {
  SignOut(this._repository, this._obs);
  final AuthRepository _repository;
  final ObservabilityService _obs;

  @override
  ObservabilityService get obs => _obs;

  @override
  String get operationName => 'auth.sign_out';

  @override
  Future<void> execute(void input, String traceId) async {
    await _repository.signOut(traceId: traceId);
  }
}
