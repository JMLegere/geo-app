import 'dart:async';

import 'package:earth_nova/core/domain/entities/user_profile.dart';
import 'package:earth_nova/features/auth/domain/repositories/auth_repository.dart';

class MockAuthRepository implements AuthRepository {
  final _controller = StreamController<AuthEvent>.broadcast();
  UserProfile? _user;

  @override
  Stream<AuthEvent> get authStateChanges => _controller.stream;

  @override
  Future<UserProfile> signInWithEmail(String email, String password) async {
    final digits = email.split('@').first;
    if (digits.length < 10) {
      throw const AuthException('Invalid phone number. Enter 10 digits.');
    }
    _user = UserProfile(
      id: 'mock_$digits',
      phone: digits,
      displayName: 'MockExplorer',
      createdAt: DateTime.now(),
    );
    _controller.add(AuthStateChanged(_user));
    return _user!;
  }

  @override
  Future<UserProfile> signUpWithEmail(
    String email,
    String password, {
    Map<String, dynamic>? metadata,
  }) async {
    final digits = email.split('@').first;
    _user = UserProfile(
      id: 'mock_$digits',
      phone: metadata?['phone_number'] as String? ?? digits,
      displayName: 'MockExplorer',
      createdAt: DateTime.now(),
    );
    _controller.add(AuthStateChanged(_user));
    return _user!;
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _controller.add(const AuthStateChanged(null));
  }

  @override
  Future<UserProfile?> getCurrentUser() async => _user;

  @override
  Future<bool> restoreSession() async {
    if (_user != null) {
      _controller.add(AuthStateChanged(_user));
      return true;
    }
    return false;
  }

  @override
  void dispose() => _controller.close();
}
