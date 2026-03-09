import 'dart:async';

import 'package:earth_nova/features/auth/models/user_profile.dart';
import 'package:earth_nova/features/auth/services/auth_service.dart';

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

    // If the user is currently signed in anonymously, upgrade their existing
    // account by attaching the phone number — preserving their UUID and data.
    // TODO(auth): When OTP verification is enabled, this will require
    // SMS code verification before creating the account.
    if (_currentUser != null && _currentUser!.isAnonymous) {
      final upgraded = _currentUser!.copyWith(
        phoneNumber: phoneNumber,
        isAnonymous: false,
      );
      _phoneProfiles[phoneNumber] = upgraded;
      _currentUser = upgraded;
      _authStateController.add(upgraded);
      return upgraded;
    }

    // No current session — create a fresh account keyed by phone.
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

    // Idempotent: if already signed in as anonymous, return existing user.
    // This prevents generating a new ID on provider rebuild, which would
    // cause an auth identity change cascade (old anon-X → new anon-Y) and
    // trigger unnecessary re-hydration on a disposed Ref.
    if (_currentUser != null && _currentUser!.isAnonymous) {
      _authStateController.add(_currentUser);
      return _currentUser!;
    }

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
  Stream<UserProfile?> get authStateChanges {
    // Mimic Supabase SDK behavior: emit the current session immediately on
    // subscription (Supabase fires INITIAL_SESSION), then relay future changes.
    // Each call to this getter creates a fresh stream so every subscriber
    // independently receives the initial value followed by broadcast events.
    late StreamController<UserProfile?> controller;
    StreamSubscription<UserProfile?>? sub;

    controller = StreamController<UserProfile?>(
      onListen: () {
        // Emit current state synchronously-ish via microtask so the listener
        // is wired before the event fires.
        scheduleMicrotask(() {
          if (!controller.isClosed) {
            controller.add(_currentUser);
          }
        });
        // Forward all future broadcast events.
        sub = _authStateController.stream.listen(
          controller.add,
          onError: controller.addError,
          onDone: controller.close,
        );
      },
      onCancel: () {
        sub?.cancel();
        controller.close();
      },
    );

    return controller.stream;
  }

  @override
  void dispose() {
    _authStateController.close();
  }
}
