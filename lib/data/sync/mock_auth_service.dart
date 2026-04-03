import 'dart:async';

import 'package:earth_nova/data/sync/auth_service.dart';
import 'package:earth_nova/models/user_profile.dart';

/// In-memory [AuthService] for development and testing.
///
/// Simulates phone+OTP authentication without network calls.
/// The OTP code is always '123456' for any phone number.
class MockAuthService implements AuthService {
  MockAuthService();

  final Map<String, UserProfile> _phoneProfiles = {};
  final Set<String> _pendingOtp = {};
  UserProfile? _currentUser;
  final _authStateController = StreamController<UserProfile?>.broadcast();

  static final _phoneRegex = RegExp(r'^\+[1-9]\d{6,14}$');
  static const _mockOtpCode = '123456';
  static const _delay = Duration(milliseconds: 100);

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
          'No OTP was sent to this number. Call sendOtp first.');
    }
    if (code != _mockOtpCode) {
      throw const AuthException(
          'Invalid or expired OTP code. Please try again.');
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
    late StreamController<UserProfile?> controller;
    StreamSubscription<UserProfile?>? sub;
    controller = StreamController<UserProfile?>(
      onListen: () {
        scheduleMicrotask(() {
          if (!controller.isClosed) controller.add(_currentUser);
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
  void dispose() {
    _authStateController.close();
  }
}
