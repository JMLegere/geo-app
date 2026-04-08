import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:earth_nova/core/domain/entities/user_profile.dart';
import 'package:earth_nova/core/observability/observable_use_case.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/auth/domain/repositories/auth_repository.dart';

class SignInWithPhone extends ObservableUseCase<String, UserProfile> {
  SignInWithPhone(this._repository, this._obs);
  final AuthRepository _repository;
  final ObservabilityService _obs;

  @override
  ObservabilityService get obs => _obs;

  @override
  String get operationName => 'auth.sign_in_with_phone';

  @override
  Future<UserProfile> execute(String phone, String traceId) async {
    final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    final email = '$digits@earthnova.app';
    final password = _derivePassword(phone);
    try {
      return await _repository.signInWithEmail(
        email,
        password,
        traceId: traceId,
      );
    } on AuthException catch (e) {
      if (e.message.contains('Invalid login credentials')) {
        return await _repository.signUpWithEmail(
          email,
          password,
          metadata: {'phone_number': phone},
          traceId: traceId,
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
