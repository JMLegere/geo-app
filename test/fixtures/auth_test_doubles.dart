import 'dart:async';

import 'package:earth_nova/features/auth/models/user_profile.dart';
import 'package:earth_nova/features/auth/services/auth_service.dart';

/// Predictable test user for auth tests.
final kTestUser = UserProfile(
  id: 'test-user-001',
  email: 'test@example.com',
  phoneNumber: '+15555550100',
  displayName: 'Test Explorer',
  createdAt: DateTime(2025, 1, 1),
);

/// Fake [AuthService] for testing. Provides full in-memory OTP auth behavior
/// with predictable results. Suitable for both unit tests (via [shouldThrow]
/// flag) and integration-style tests (via realistic phone validation).
///
/// Implements the CURRENT [AuthService] interface exactly.
/// Fixed OTP code: '123456' for any phone number.
class FakeAuthService implements AuthService {
  FakeAuthService();

  /// Maps phone number → profile for signed-in users.
  final Map<String, UserProfile> _phoneProfiles = {};

  /// Tracks which phone numbers have had an OTP sent (pending verification).
  final Set<String> _pendingOtp = {};

  UserProfile? _currentUser;

  final _authStateController = StreamController<UserProfile?>.broadcast();

  /// E.164 phone format: '+' followed by 7-15 digits.
  static final _phoneRegex = RegExp(r'^\+[1-9]\d{6,14}$');

  /// Fixed OTP code accepted by [verifyOtp] in fake mode.
  static const _mockOtpCode = '123456';

  static const _delay = Duration(milliseconds: 100);

  // Config flags for test scenarios
  bool shouldThrow = false;
  String throwMessage = 'Test auth error';

  // ---------------------------------------------------------------------------
  // AuthService implementation
  // ---------------------------------------------------------------------------

  @override
  Future<void> sendOtp(String phone) async {
    await Future<void>.delayed(_delay);

    if (shouldThrow) throw AuthException(throwMessage);

    if (!_phoneRegex.hasMatch(phone)) {
      throw const AuthException(
        'Invalid phone number format. Use E.164 (e.g., +13334445555)',
      );
    }

    _pendingOtp.add(phone);
  }

  @override
  Future<UserProfile> verifyOtp({
    required String phone,
    required String code,
  }) async {
    await Future<void>.delayed(_delay);

    if (shouldThrow) throw AuthException(throwMessage);

    if (!_pendingOtp.contains(phone)) {
      throw const AuthException(
        'No OTP was sent to this number. Call sendOtp first.',
      );
    }

    if (code != _mockOtpCode) {
      throw const AuthException(
        'Invalid or expired OTP code. Please try again.',
      );
    }

    _pendingOtp.remove(phone);

    final existing = _phoneProfiles[phone];
    if (existing != null) {
      _currentUser = existing;
      _authStateController.add(existing);
      return existing;
    }

    final profile = UserProfile(
      id: 'phone-${DateTime.now().millisecondsSinceEpoch}',
      email: '',
      phoneNumber: phone,
      displayName: null,
      createdAt: DateTime.now(),
    );

    _phoneProfiles[phone] = profile;
    _currentUser = profile;
    _authStateController.add(profile);
    return profile;
  }

  @override
  Future<UserProfile> signInAnonymously() async {
    await Future<void>.delayed(_delay);
    if (shouldThrow) throw AuthException(throwMessage);
    final profile = UserProfile(
      id: 'anon-${DateTime.now().millisecondsSinceEpoch}',
      email: '',
      phoneNumber: null,
      displayName: 'Beta Tester',
      createdAt: DateTime.now(),
    );
    _currentUser = profile;
    _authStateController.add(profile);
    return profile;
  }

  @override
  Future<UserProfile> signInWithPhone(String phone) async {
    await Future<void>.delayed(_delay);
    if (shouldThrow) throw AuthException(throwMessage);

    if (!_phoneRegex.hasMatch(phone)) {
      throw const AuthException(
        'Invalid phone number format. Use E.164 (e.g., +13334445555)',
      );
    }

    final existing = _phoneProfiles[phone];
    if (existing != null) {
      _currentUser = existing;
      _authStateController.add(existing);
      return existing;
    }

    final profile = UserProfile(
      id: 'phone-${DateTime.now().millisecondsSinceEpoch}',
      email: '',
      phoneNumber: phone,
      displayName: null,
      createdAt: DateTime.now(),
    );

    _phoneProfiles[phone] = profile;
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
  Future<UserProfile?> getCurrentUser() async => _currentUser;

  @override
  Future<bool> restoreSession() async => _currentUser != null;

  @override
  Stream<UserProfile?> get authStateChanges {
    // Mimic Supabase SDK behavior: emit the current session immediately on
    // subscription (Supabase fires INITIAL_SESSION), then relay future changes.
    late StreamController<UserProfile?> controller;
    StreamSubscription<UserProfile?>? sub;

    controller = StreamController<UserProfile?>(
      onListen: () {
        scheduleMicrotask(() {
          if (!controller.isClosed) {
            controller.add(_currentUser);
          }
        });
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
  void dispose() => _authStateController.close();

  // ---------------------------------------------------------------------------
  // Test helpers
  // ---------------------------------------------------------------------------

  /// Pre-authenticate for tests that need a logged-in user.
  void setAuthenticated([UserProfile? user]) {
    _currentUser = user ?? kTestUser;
    _authStateController.add(_currentUser);
  }
}
