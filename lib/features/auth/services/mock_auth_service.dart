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
  final Map<String, UserProfile> _phoneProfiles = {}; // phone → profile

  UserProfile? _currentUser;

  final _authStateController = StreamController<UserProfile?>.broadcast();

  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// E.164 phone format: '+' followed by 7-15 digits.
  static final _phoneRegex = RegExp(r'^\+[1-9]\d{6,14}$');

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
  Future<UserProfile> signInWithPhone({required String phoneNumber}) async {
    await Future<void>.delayed(_delay);

    if (!_phoneRegex.hasMatch(phoneNumber)) {
      throw const AuthException('Invalid phone number format (E.164 required)');
    }

    // Unified flow: return existing user or create new one.
    final existing = _phoneProfiles[phoneNumber];
    if (existing != null) {
      _currentUser = existing;
      _authStateController.add(existing);
      return existing;
    }

    // New user — create account keyed by phone.
    // TODO(auth): When OTP verification is enabled, this will require
    // SMS code verification before creating the account.
    final profile = UserProfile(
      id: 'phone-${DateTime.now().millisecondsSinceEpoch}',
      email: '',
      phoneNumber: phoneNumber,
      displayName: null,
      createdAt: DateTime.now(),
    );

    _phoneProfiles[phoneNumber] = profile;
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
      isAnonymous: true,
    );
    _currentUser = profile;
    _authStateController.add(profile);
    return profile;
  }

  @override
  Future<UserProfile> upgradeWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    await Future<void>.delayed(_delay);

    if (_currentUser == null) {
      throw const AuthException('No user signed in');
    }
    if (!_currentUser!.isAnonymous) {
      throw const AuthException('User is already upgraded');
    }
    if (!_emailRegex.hasMatch(email)) {
      throw const AuthException('Invalid email format');
    }
    if (_passwords.containsKey(email)) {
      throw const AuthException('Email already registered');
    }

    final upgraded = _currentUser!.copyWith(
      email: email,
      displayName: displayName ?? _currentUser!.displayName,
      isAnonymous: false,
    );

    _passwords[email] = password;
    _profiles[email] = upgraded;
    _currentUser = upgraded;
    _authStateController.add(upgraded);
    return upgraded;
  }

  @override
  Future<UserProfile> linkOAuthIdentity({required String provider}) async {
    await Future<void>.delayed(_delay);

    if (_currentUser == null) {
      throw const AuthException('No user signed in');
    }
    if (!_currentUser!.isAnonymous) {
      throw const AuthException('User is already upgraded');
    }

    final upgraded = _currentUser!.copyWith(
      email: '$provider@oauth.mock',
      isAnonymous: false,
    );

    _currentUser = upgraded;
    _authStateController.add(upgraded);
    return upgraded;
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
