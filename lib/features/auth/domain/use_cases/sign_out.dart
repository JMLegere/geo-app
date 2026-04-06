import 'package:earth_nova/features/auth/domain/repositories/auth_repository.dart';

class SignOut {
  const SignOut(this._repository);
  final AuthRepository _repository;

  Future<void> call() async {
    await _repository.signOut();
  }
}
