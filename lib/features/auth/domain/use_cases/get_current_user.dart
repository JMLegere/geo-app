import 'package:earth_nova/core/domain/entities/user_profile.dart';
import 'package:earth_nova/features/auth/domain/repositories/auth_repository.dart';

class GetCurrentUser {
  const GetCurrentUser(this._repository);
  final AuthRepository _repository;

  Future<UserProfile?> call() async {
    return await _repository.getCurrentUser();
  }
}
