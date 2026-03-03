import 'dart:async';

import 'package:fog_of_world/features/auth/models/user_profile.dart';
import 'package:fog_of_world/features/auth/services/auth_service.dart';

/// In-memory [AuthService] for development and testing.
///
/// Stores users in a [Map] keyed by email. Simulates network latency with a
/// 100 ms delay on mutating operations. Broadcasts auth state changes via a
/// [StreamController].
class MockAuthService implements AuthService {
  MockAuthService();

  final Map<String, String> _passwords = {}; // email → password
  final Map<String, UserProfile> _profiles = {}; // email → profile

  UserProfile? _currentUser;

  final _authStateController = StreamController<UserProfile?>.broadcast();

  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static const _delay = Duration(milliseconds: 100);

  // ---------------------------------------------------------------------------
  // AuthService implementation
  // ---------------------------------------------------------------------------

  @override
  Future<UserProfile> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    await Future<void>.delayed(_delay);

    if (!_emailRegex.hasMatch(email)) {
      throw const AuthException('Invalid email format');
    }
    if (_passwords.containsKey(email)) {
      throw const AuthException('Email already registered');
    }

    final profile = UserProfile(
      id: 'mock-${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      displayName: displayName,
      createdAt: DateTime.now(),
    );

    _passwords[email] = password;
    _profiles[email] = profile;
    _currentUser = profile;
    _authStateController.add(profile);
    return profile;
  }

  @override
  Future<UserProfile> signIn({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(_delay);

    final storedPassword = _passwords[email];
    if (storedPassword == null) {
      throw const AuthException('User not found');
    }
    if (storedPassword != password) {
      throw const AuthException('Wrong password');
    }

    final profile = _profiles[email]!;
    _currentUser = profile;
    _authStateController.add(profile);
    return profile;
  }

  @override
  Future<UserProfile> signInAnonymously() async {
    await Future<void>.delayed(_delay);
    final profile = UserProfile(
      id: 'anon-${DateTime.now().millisecondsSinceEpoch}',
      email: '',
      displayName: 'Explorer',
      createdAt: DateTime.now(),
    );
    _currentUser = profile;
    _authStateController.add(profile);
    return profile;
  }

  @override
  Future<void> signOut() async {
    await Future<void>.delayed(_delay);
    _currentUser = null;
    _authStateController.add(null);
  }

  @override
  Future<UserProfile?> getCurrentUser() async {
    return _currentUser;
  }

  @override
  Future<bool> isSessionValid() async {
    return _currentUser != null;
  }

  @override
  Stream<UserProfile?> get authStateChanges => _authStateController.stream;

  @override
  void dispose() {
    _authStateController.close();
  }
}
