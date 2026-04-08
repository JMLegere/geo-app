import 'dart:async';

import 'package:earth_nova/core/domain/entities/user_profile.dart';
import 'package:earth_nova/features/auth/domain/repositories/auth_repository.dart';

class MockAuthRepository implements AuthRepository {
  final _controller = StreamController<AuthEvent>.broadcast();
  UserProfile? _user;

  @override
  Stream<AuthEvent> get authStateChanges => _controller.stream;

  @override
  Future<UserProfile> signInWithEmail(
    String email,
    String password, {
    String? traceId,
  }) async {
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
    String? traceId,
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
  Future<void> signOut({String? traceId}) async {
    _user = null;
    _controller.add(const AuthStateChanged(null));
  }

  @override
  Future<UserProfile?> getCurrentUser({String? traceId}) async => _user;

  @override
  Future<bool> restoreSession({String? traceId}) async {
    if (_user != null) {
      _controller.add(AuthStateChanged(_user));
      return true;
    }
    return false;
  }

  /// Emit an auth event directly on the stream (for testing stream listeners).
  void emitEvent(AuthEvent event) => _controller.add(event);

  @override
  void dispose() => _controller.close();
}
