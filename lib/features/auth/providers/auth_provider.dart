import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/features/auth/models/auth_state.dart';
import 'package:earth_nova/features/auth/models/user_profile.dart';
import 'package:earth_nova/features/auth/services/auth_service.dart';

/// Thin auth state holder with action wrappers.
///
/// Auth orchestration (session restore, fallback) lives in the game
/// coordinator. This notifier handles:
///   - State storage (reactive, watched by UI and routing)
///   - Action wrappers that delegate to [authServiceProvider]
///   - Loading/error state transitions for each action
///
/// The game coordinator calls [setState] for auth lifecycle events.
/// UI calls action methods (sendOtp, verifyOtp, signOut) which read
/// [authServiceProvider] for the actual service instance.
class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState.loading();

  /// Direct state setter — called by gameCoordinatorProvider for auth
  /// lifecycle events (session restore, stream events).
  void setState(AuthState newState) {
    state = newState;
  }

  // ---------------------------------------------------------------------------
  // UI-facing action methods — delegate to authServiceProvider
  // ---------------------------------------------------------------------------

  /// Sends an OTP to the given phone number.
  Future<void> sendOtp(String phone) async {
    final service = ref.read(authServiceProvider);
    if (service == null) return;
    state = AuthState.otpSent(phone: phone);
    try {
      await service.sendOtp(phone);
      if (!ref.mounted) return;
      state = AuthState.otpSent(phone: phone);
    } on AuthException catch (e) {
      if (!ref.mounted) return;
      state = AuthState.error(e.message);
    }
  }

  /// Verifies the OTP code for the given phone number.
  ///
  /// On failure, returns to [AuthStatus.otpSent] (not unauthenticated) so the
  /// user stays on the OTP screen and can retry without re-entering their phone.
  Future<void> verifyOtp({
    required String phone,
    required String code,
  }) async {
    final service = ref.read(authServiceProvider);
    if (service == null) return;
    state = AuthState.otpVerifying(phone: phone);
    try {
      final user = await service.verifyOtp(phone: phone, code: code);
      if (!ref.mounted) return;
      state = AuthState.authenticated(user);
    } on AuthException catch (e) {
      if (!ref.mounted) return;
      state = AuthState.otpSent(phone: phone).copyWith(errorMessage: e.message);
    }
  }

  /// Bypasses OTP verification with a deterministic mock user.
  ///
  /// Only available in debug builds (guarded by [kDebugMode] at the call
  /// site). Creates a stable user profile seeded from the phone number so
  /// the same phone always produces the same user ID.
  void bypassVerification(String phone) {
    assert(kDebugMode, 'bypassVerification must only be called in debug mode');
    final user = UserProfile(
      id: 'bypass-${phone.hashCode.toRadixString(16)}',
      email: 'bypass@earthnova.dev',
      phoneNumber: phone,
      displayName: 'Beta Tester',
      createdAt: DateTime.now(),
    );
    state = AuthState.authenticated(user);
  }

  /// Signs out the current user.
  Future<void> signOut() async {
    final service = ref.read(authServiceProvider);
    if (service == null) return;
    try {
      await service.signOut();
      if (!ref.mounted) return;
      state = const AuthState.unauthenticated();
    } on AuthException catch (e) {
      if (!ref.mounted) return;
      state = AuthState.error(e.message);
    }
  }
}

final authProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

/// Holds the [AuthService] instance created by gameCoordinatorProvider
/// during auth initialization.
///
/// Null until auth init completes. [AuthNotifier] reads this for all
/// auth operations. UI can also read it directly if needed.
class AuthServiceHolder extends Notifier<AuthService?> {
  @override
  AuthService? build() => null;

  void set(AuthService service) {
    state = service;
  }
}

final authServiceProvider =
    NotifierProvider<AuthServiceHolder, AuthService?>(AuthServiceHolder.new);
