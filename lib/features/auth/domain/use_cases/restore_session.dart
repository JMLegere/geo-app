import 'package:earth_nova/core/domain/entities/user_profile.dart';
import 'package:earth_nova/features/auth/domain/repositories/auth_repository.dart';

class RestoreSession {
  const RestoreSession(this._repository);
  final AuthRepository _repository;

  Future<UserProfile?> call() async {
    final restored = await _repository.restoreSession();
    if (!restored) return null;
    return await _repository.getCurrentUser();
  }
}
