import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import 'package:earth_nova/models/auth_state.dart';
import 'package:earth_nova/services/auth_service.dart';
import 'package:earth_nova/services/observability_service.dart';

/// Supabase-backed auth service using phone → derived email+password.
///
/// The `_deriveEmail` and `_derivePassword` functions MUST be byte-for-byte
/// identical to v2 (`lib/data/sync/supabase_auth.dart:145-153`).
/// A regression test enforces this.
class SupabaseAuthService implements AuthService {
  SupabaseAuthService({
    required supa.SupabaseClient client,
    required ObservabilityService observability,
  }) : _client = client;

  final supa.SupabaseClient _client;
  final _controller = StreamController<AuthEvent>.broadcast();

  @override
  Stream<AuthEvent> get authStateChanges => _controller.stream;

  @override
  Future<UserProfile> signInWithPhone(String phone) async {
    final email = _deriveEmail(phone);
    final password = _derivePassword(phone);

    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      // ignore: unnecessary_null_comparison
      if (response.user != null) {
        final user = response.user!;
        final profile = UserProfile(
          id: user.id,
          phone: phone,
          displayName: user.userMetadata?['display_name'] as String?,
          createdAt: DateTime.parse(user.createdAt),
        );
        _controller.add(AuthStateChanged(profile));
        return profile;
      }
    } on supa.AuthException catch (e) {
      // If credentials don't exist, try sign-up (upsert behavior).
      if (e.message.contains('Invalid login credentials')) {
        return _signUp(phone, email, password);
      }
      throw AuthException(e.message);
    }
    throw const AuthException('Sign-in failed: no user returned.');
  }

  Future<UserProfile> _signUp(
      String phone, String email, String password) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'phone_number': phone},
      );
      // ignore: unnecessary_null_comparison
      if (response.user != null) {
        final user = response.user!;
        final profile = UserProfile(
          id: user.id,
          phone: phone,
          displayName: user.userMetadata?['display_name'] as String?,
          // ignore: unnecessary_non_null_assertion
          createdAt: DateTime.parse(user.createdAt),
        );
        _controller.add(AuthStateChanged(profile));
        return profile;
      }
    } on supa.AuthException catch (e) {
      throw AuthException(e.message);
    }
    throw const AuthException('Sign-up failed: no user returned.');
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
    _controller.add(const AuthStateChanged(null));
  }

  @override
  Future<UserProfile?> getCurrentUser() async {
    // ignore: unnecessary_null_comparison
    final user = _client.auth.currentUser;
    // ignore: unnecessary_null_comparison
    if (user == null) return null;
    return UserProfile(
      id: user.id,
      phone: user.userMetadata?['phone_number'] as String? ?? '',
      displayName: user.userMetadata?['display_name'] as String?,
      createdAt: DateTime.parse(user.createdAt),
    );
  }

  @override
  Future<bool> restoreSession() async {
    final session = _client.auth.currentSession;
    if (session == null) return false;
    // ignore: unnecessary_null_comparison
    final user = _client.auth.currentUser;
    // ignore: unnecessary_null_comparison
    if (user != null) {
      final isAnonymous = user.userMetadata?['is_anonymous'] == true ||
          (user.appMetadata['provider'] == 'anonymous');
      if (isAnonymous) {
        await _client.auth.signOut();
        _controller.add(const AuthStateChanged(null));
        return false;
      }
    }
    if (session.isExpired) {
      try {
        await _client.auth.refreshSession();
        final refreshed = _client.auth.currentSession;
        if (refreshed != null && !refreshed.isExpired) {
          final profile = await getCurrentUser();
          if (profile != null) {
            _controller.add(AuthStateChanged(profile));
            return true;
          }
        }
      } catch (_) {
        _controller.add(const AuthSessionExpired());
        return false;
      }
    }
    final profile = await getCurrentUser();
    if (profile != null) {
      _controller.add(AuthStateChanged(profile));
      return true;
    }
    return false;
  }

  @override
  void dispose() => _controller.close();

  // ── Identity bridge (MUST match v2 exactly) ──────────────────────────────

  static String _deriveEmail(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    return '$digits@earthnova.app';
  }

  static String _derivePassword(String phone) {
    // This is the critical identity bridge for beta users.
    // Do NOT change this string without a data migration plan.
    final bytes = utf8.encode('$phone:earthnova-beta-2026');
    return sha256.convert(bytes).toString();
  }
}
