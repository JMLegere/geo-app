import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import 'package:earth_nova/core/domain/entities/user_profile.dart';
import 'package:earth_nova/features/auth/data/dtos/user_profile_dto.dart';
import 'package:earth_nova/features/auth/domain/repositories/auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository({required supa.SupabaseClient client})
      : _client = client;

  final supa.SupabaseClient _client;
  final _controller = StreamController<AuthEvent>.broadcast();

  @override
  Stream<AuthEvent> get authStateChanges => _controller.stream;

  @override
  Future<UserProfile> signInWithEmail(String email, String password) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = response.user;
      if (user != null) {
        final dto = UserProfileDto(
          id: user.id,
          phone: user.userMetadata?['phone_number'] as String? ?? '',
          displayName: user.userMetadata?['display_name'] as String?,
          createdAt: DateTime.parse(user.createdAt),
        );
        final profile = dto.toDomain();
        _controller.add(AuthStateChanged(profile));
        return profile;
      }
    } on supa.AuthException catch (e) {
      throw AuthException(e.message);
    }
    throw const AuthException('Sign-in failed: no user returned.');
  }

  @override
  Future<UserProfile> signUpWithEmail(
    String email,
    String password, {
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: metadata,
      );
      final user = response.user;
      if (user != null) {
        final dto = UserProfileDto(
          id: user.id,
          phone: user.userMetadata?['phone_number'] as String? ?? '',
          displayName: user.userMetadata?['display_name'] as String?,
          createdAt: DateTime.parse(user.createdAt),
        );
        final profile = dto.toDomain();
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
    final user = _client.auth.currentUser;
    if (user == null) return null;
    return UserProfileDto(
      id: user.id,
      phone: user.userMetadata?['phone_number'] as String? ?? '',
      displayName: user.userMetadata?['display_name'] as String?,
      createdAt: DateTime.parse(user.createdAt),
    ).toDomain();
  }

  @override
  Future<bool> restoreSession() async {
    final session = _client.auth.currentSession;
    if (session == null) return false;
    final user = _client.auth.currentUser;
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
}
