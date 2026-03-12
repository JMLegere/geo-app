import 'dart:async';

import 'package:earth_nova/features/auth/models/user_profile.dart';
import 'package:earth_nova/features/auth/services/auth_service.dart';

/// In-memory [AuthService] for development and testing.
///
/// Simulates phone+OTP authentication without network calls.
/// The OTP code is always '123456' for any phone number.
/// Simulates network latency with a 100 ms delay on mutating operations.
/// Broadcasts auth state changes via a [StreamController].
class MockAuthService implements AuthService {
  MockAuthService();

  /// Maps phone number → profile for signed-in users.
  final Map<String, UserProfile> _phoneProfiles = {};

  /// Tracks which phone numbers have had an OTP sent (pending verification).
  final Set<String> _pendingOtp = {};

  UserProfile? _currentUser;

  final _authStateController = StreamController<UserProfile?>.broadcast();

  /// E.164 phone format: '+' followed by 7-15 digits.
  static final _phoneRegex = RegExp(r'^\+[1-9]\d{6,14}$');

  /// Fixed OTP code accepted by [verifyOtp] in mock mode.
  static const _mockOtpCode = '123456';

  static const _delay = Duration(milliseconds: 100);

  // ---------------------------------------------------------------------------
  // AuthService implementation
  // ---------------------------------------------------------------------------

  @override
  Future<void> sendOtp(String phone) async {
    await Future<void>.delayed(_delay);

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
  Future<UserProfile> signInWithPhone(String phone) async {
    await Future<void>.delayed(_delay);

    if (!_phoneRegex.hasMatch(phone)) {
      throw const AuthException(
        'Invalid phone number format. Use E.164 (e.g., +13334445555)',
      );
    }

    // Return existing profile for this phone, or create a new one.
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
  Future<UserProfile?> getCurrentUser() async {
    return _currentUser;
  }

  @override
  Future<bool> restoreSession() async {
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
