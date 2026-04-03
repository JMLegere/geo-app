import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import 'package:earth_nova/data/sync/auth_service.dart';
import 'package:earth_nova/models/user_profile.dart';

/// E.164 phone number validation.
bool _isValidE164(String phone) => RegExp(r'^\+[1-9]\d{0,14}$').hasMatch(phone);

/// Production [AuthService] backed by Supabase phone+OTP authentication.
///
/// Active when `SupabaseBootstrap.initialized` is true (i.e. `SUPABASE_URL` /
/// `SUPABASE_ANON_KEY` supplied as `--dart-define` values).
class SupabaseAuthService implements AuthService {
  supa.GoTrueClient get _auth {
    try {
      return supa.Supabase.instance.client.auth;
    } catch (e) {
      throw AuthException('Supabase not initialised: $e');
    }
  }

  static String? _displayNameFrom(supa.User user) {
    final raw = user.userMetadata?['display_name'];
    return raw is String ? raw : null;
  }

  static String? _phoneNumberFrom(supa.User user) {
    final raw = user.userMetadata?['phone_number'];
    return (raw is String && raw.isNotEmpty) ? raw : null;
  }

  static UserProfile _profileFrom(supa.User user) {
    return UserProfile(
      id: user.id,
      email: user.email ?? '',
      phoneNumber: _phoneNumberFrom(user) ?? user.phone,
      displayName: _displayNameFrom(user),
      createdAt: DateTime.parse(user.createdAt),
    );
  }

  @override
  Future<void> sendOtp(String phone) async {
    if (!_isValidE164(phone)) {
      throw const AuthException(
        'Invalid phone number format. Use E.164 (e.g., +13334445555)',
      );
    }
    try {
      await _auth.signInWithOtp(phone: phone);
    } on supa.AuthApiException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('rate') || e.statusCode == '429') {
        throw const AuthException(
            'Too many attempts. Please wait before trying again.');
      }
      throw AuthException('Authentication failed: ${e.message}');
    } on supa.AuthException catch (e) {
      throw AuthException('Authentication failed: ${e.message}');
    } catch (e) {
      throw AuthException(
          'Network error. Check your connection and try again.');
    }
  }

  @override
  Future<UserProfile> verifyOtp(
      {required String phone, required String code}) async {
    try {
      final response = await _auth.verifyOTP(
        phone: phone,
        token: code,
        type: supa.OtpType.sms,
      );
      final user = response.user;
      if (user == null)
        throw const AuthException('OTP verification failed: no user returned');
      return _profileFrom(user);
    } on supa.AuthApiException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('invalid') || msg.contains('expired')) {
        throw const AuthException(
            'Invalid or expired OTP code. Please try again.');
      }
      throw AuthException('Authentication failed: ${e.message}');
    } on AuthException {
      rethrow;
    } on supa.AuthException catch (e) {
      throw AuthException('Authentication failed: ${e.message}');
    } catch (e) {
      throw AuthException(
          'Network error. Check your connection and try again.');
    }
  }

  @override
  Future<UserProfile> signInWithPhone(String phone) async {
    if (!_isValidE164(phone)) {
      throw const AuthException(
        'Invalid phone number format. Use E.164 (e.g., +13334445555)',
      );
    }
    final email = _deriveEmail(phone);
    final password = _derivePassword(phone);

    try {
      final signInResponse =
          await _auth.signInWithPassword(email: email, password: password);
      final user = signInResponse.user;
      if (user == null)
        throw const AuthException('Phone sign-in failed: no user returned.');
      return _profileFrom(user);
    } on supa.AuthApiException catch (e) {
      final msg = e.message.toLowerCase();
      if (!msg.contains('invalid')) {
        throw AuthException('Phone sign-in failed: ${e.message}');
      }
    }

    try {
      final signUpResponse = await _auth.signUp(
        email: email,
        password: password,
        data: {'phone_number': phone},
      );
      final user = signUpResponse.user;
      if (user != null && (user.identities?.isNotEmpty ?? false)) {
        return _profileFrom(user);
      }
    } on supa.AuthApiException catch (e) {
      throw AuthException('Phone sign-up failed: ${e.message}');
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException(
          'Network error. Check your connection and try again.');
    }
    throw const AuthException('Phone sign-up failed: no user returned.');
  }

  static String _deriveEmail(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    return '$digits@earthnova.app';
  }

  static String _derivePassword(String phone) {
    final bytes = utf8.encode('$phone:earthnova-beta-2026');
    return sha256.convert(bytes).toString();
  }

  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } on supa.AuthException catch (e) {
      throw AuthException(e.message);
    } catch (e) {
      throw AuthException('Sign-out failed: $e');
    }
  }

  @override
  Future<UserProfile?> getCurrentUser() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;
      return _profileFrom(user);
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException('Failed to get current user: $e');
    }
  }

  @override
  Future<bool> restoreSession() async {
    try {
      final session = _auth.currentSession;
      if (session == null) return false;
      final user = _auth.currentUser;
      if (user != null) {
        final isAnonymous = user.userMetadata?['is_anonymous'] == true ||
            (user.appMetadata['provider'] == 'anonymous');
        if (isAnonymous) {
          debugPrint('[Auth] anonymous session detected — signing out');
          await _auth.signOut();
          return false;
        }
      }
      if (session.isExpired) {
        debugPrint('[Auth] stored session expired — attempting refresh');
        try {
          await _auth.refreshSession();
          final refreshed = _auth.currentSession;
          return refreshed != null && !refreshed.isExpired;
        } catch (e) {
          debugPrint('[Auth] session refresh failed: $e');
          return false;
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Stream<UserProfile?> get authStateChanges {
    try {
      return _auth.onAuthStateChange.map((authState) {
        final session = authState.session;
        if (session == null) return null;
        return _profileFrom(session.user);
      });
    } catch (e) {
      return Stream.error(AuthException('Supabase not initialised: $e'));
    }
  }

  @override
  void dispose() {
    // Supabase manages its own resources.
  }
}
