import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:earth_nova/core/domain/entities/user_profile.dart';
import 'package:earth_nova/features/auth/domain/repositories/auth_repository.dart';

class SignInWithPhone {
  const SignInWithPhone(this._repository);
  final AuthRepository _repository;

  Future<UserProfile> call(String phone) async {
    final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    final email = '$digits@earthnova.app';
    final password = _derivePassword(phone);
    try {
      return await _repository.signInWithEmail(email, password);
    } on AuthException catch (e) {
      if (e.message.contains('Invalid login credentials')) {
        return await _repository.signUpWithEmail(
          email,
          password,
          metadata: {'phone_number': phone},
        );
      }
      rethrow;
    }
  }

  static String _derivePassword(String phone) {
    final bytes = utf8.encode('$phone:earthnova-beta-2026');
    return sha256.convert(bytes).toString();
  }
}
