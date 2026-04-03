import 'dart:async';

import 'package:earth_nova/models/auth_state.dart';
import 'package:earth_nova/services/auth_service.dart';

/// In-memory auth service for testing and offline dev.
///
/// Accepts any 10-digit phone number. Rejects anything shorter.
/// Returns a synthetic [UserProfile] immediately.
class MockAuthService implements AuthService {
  final _controller = StreamController<AuthEvent>.broadcast();
  UserProfile? _user;

  @override
  Stream<AuthEvent> get authStateChanges => _controller.stream;

  @override
  Future<UserProfile> signInWithPhone(String phone) async {
    final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length < 10) {
      throw const AuthException('Invalid phone number. Enter 10 digits.');
    }
    _user = UserProfile(
      id: 'mock_$digits',
      phone: phone,
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
