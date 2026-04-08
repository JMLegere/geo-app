import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import 'package:earth_nova/core/domain/entities/user_profile.dart';
import 'package:earth_nova/features/auth/data/dtos/user_profile_dto.dart';
import 'package:earth_nova/features/auth/domain/repositories/auth_repository.dart';

typedef RepositoryLogEvent = void Function(
  String event,
  String category, {
  Map<String, dynamic>? data,
});
typedef AuthSignInAction = Future<UserProfile> Function(
    String email, String password);
typedef AuthSignUpAction = Future<UserProfile> Function(
  String email,
  String password,
  Map<String, dynamic>? metadata,
);
typedef AuthSignOutAction = Future<void> Function();
typedef AuthCurrentUserAction = Future<UserProfile?> Function();
typedef AuthCurrentSessionAction = supa.Session? Function();
typedef AuthRefreshSessionAction = Future<void> Function();

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository({
    required supa.SupabaseClient? client,
    AuthSignInAction? signInAction,
    AuthSignUpAction? signUpAction,
    AuthSignOutAction? signOutAction,
    AuthCurrentUserAction? currentUserAction,
    AuthCurrentSessionAction? currentSessionAction,
    AuthRefreshSessionAction? refreshSessionAction,
    RepositoryLogEvent? logEvent,
  })  : _client = client,
        _signInAction = signInAction,
        _signUpAction = signUpAction,
        _signOutAction = signOutAction,
        _currentUserAction = currentUserAction,
        _currentSessionAction = currentSessionAction,
        _refreshSessionAction = refreshSessionAction,
        _logEvent = logEvent;

  final supa.SupabaseClient? _client;
  final AuthSignInAction? _signInAction;
  final AuthSignUpAction? _signUpAction;
  final AuthSignOutAction? _signOutAction;
  final AuthCurrentUserAction? _currentUserAction;
  final AuthCurrentSessionAction? _currentSessionAction;
  final AuthRefreshSessionAction? _refreshSessionAction;
  final RepositoryLogEvent? _logEvent;
  final _controller = StreamController<AuthEvent>.broadcast();
  static const _category = 'auth.auth_repository';

  @override
  Stream<AuthEvent> get authStateChanges => _controller.stream;

  @override
  Future<UserProfile> signInWithEmail(
    String email,
    String password, {
    String? traceId,
  }) async {
    final stopwatch = Stopwatch()..start();
    _logEvent?.call('db.query_started', _category, data: {'trace_id': traceId});
    try {
      final profile = await _runSignIn(email, password);
      _controller.add(AuthStateChanged(profile));
      _logEvent?.call('db.query_completed', _category, data: {
        'trace_id': traceId,
        'row_count': 1,
        'duration_ms': stopwatch.elapsedMilliseconds,
      });
      return profile;
    } catch (error) {
      _logEvent?.call('db.query_failed', _category, data: {
        'trace_id': traceId,
        'duration_ms': stopwatch.elapsedMilliseconds,
      });
      rethrow;
    }
  }

  @override
  Future<UserProfile> signUpWithEmail(
    String email,
    String password, {
    Map<String, dynamic>? metadata,
    String? traceId,
  }) async {
    final stopwatch = Stopwatch()..start();
    _logEvent?.call('db.query_started', _category, data: {'trace_id': traceId});
    try {
      final profile = await _runSignUp(email, password, metadata);
      _controller.add(AuthStateChanged(profile));
      _logEvent?.call('db.query_completed', _category, data: {
        'trace_id': traceId,
        'row_count': 1,
        'duration_ms': stopwatch.elapsedMilliseconds,
      });
      return profile;
    } catch (error) {
      _logEvent?.call('db.query_failed', _category, data: {
        'trace_id': traceId,
        'duration_ms': stopwatch.elapsedMilliseconds,
      });
      rethrow;
    }
  }

  @override
  Future<void> signOut({String? traceId}) async {
    final stopwatch = Stopwatch()..start();
    _logEvent?.call('db.query_started', _category, data: {'trace_id': traceId});
    try {
      await _runSignOut();
      _controller.add(const AuthStateChanged(null));
      _logEvent?.call('db.query_completed', _category, data: {
        'trace_id': traceId,
        'row_count': 0,
        'duration_ms': stopwatch.elapsedMilliseconds,
      });
    } catch (error) {
      _logEvent?.call('db.query_failed', _category, data: {
        'trace_id': traceId,
        'duration_ms': stopwatch.elapsedMilliseconds,
      });
      rethrow;
    }
  }

  @override
  Future<UserProfile?> getCurrentUser({String? traceId}) async {
    final stopwatch = Stopwatch()..start();
    _logEvent?.call('db.query_started', _category, data: {'trace_id': traceId});
    try {
      final profile = await _runCurrentUser();
      _logEvent?.call('db.query_completed', _category, data: {
        'trace_id': traceId,
        'row_count': profile == null ? 0 : 1,
        'duration_ms': stopwatch.elapsedMilliseconds,
      });
      return profile;
    } catch (error) {
      _logEvent?.call('db.query_failed', _category, data: {
        'trace_id': traceId,
        'duration_ms': stopwatch.elapsedMilliseconds,
      });
      rethrow;
    }
  }

  @override
  Future<bool> restoreSession({String? traceId}) async {
    final stopwatch = Stopwatch()..start();
    _logEvent?.call('db.query_started', _category, data: {'trace_id': traceId});
    final session = _runCurrentSession();
    if (session == null) {
      _logEvent?.call('db.query_completed', _category, data: {
        'trace_id': traceId,
        'row_count': 0,
        'duration_ms': stopwatch.elapsedMilliseconds,
      });
      return false;
    }
    final rawUser = _client?.auth.currentUser;
    if (rawUser != null) {
      final isAnonymous = rawUser.userMetadata?['is_anonymous'] == true ||
          (rawUser.appMetadata['provider'] == 'anonymous');
      if (isAnonymous) {
        await _runSignOut();
        _controller.add(const AuthStateChanged(null));
        _logEvent?.call('db.query_completed', _category, data: {
          'trace_id': traceId,
          'row_count': 0,
          'duration_ms': stopwatch.elapsedMilliseconds,
        });
        return false;
      }
    }
    if (session.isExpired) {
      try {
        await _runRefreshSession();
        final refreshed = _runCurrentSession();
        if (refreshed != null && !refreshed.isExpired) {
          final profile = await getCurrentUser(traceId: traceId);
          if (profile != null) {
            _controller.add(AuthStateChanged(profile));
            _logEvent?.call('db.query_completed', _category, data: {
              'trace_id': traceId,
              'row_count': 1,
              'duration_ms': stopwatch.elapsedMilliseconds,
            });
            return true;
          }
        }
      } catch (_) {
        _controller.add(const AuthSessionExpired());
        _logEvent?.call('db.query_failed', _category, data: {
          'trace_id': traceId,
          'duration_ms': stopwatch.elapsedMilliseconds,
        });
        return false;
      }
    }
    final profile = await getCurrentUser(traceId: traceId);
    if (profile != null) {
      _controller.add(AuthStateChanged(profile));
      _logEvent?.call('db.query_completed', _category, data: {
        'trace_id': traceId,
        'row_count': 1,
        'duration_ms': stopwatch.elapsedMilliseconds,
      });
      return true;
    }
    _logEvent?.call('db.query_completed', _category, data: {
      'trace_id': traceId,
      'row_count': 0,
      'duration_ms': stopwatch.elapsedMilliseconds,
    });
    return false;
  }

  @override
  void dispose() => _controller.close();

  Future<UserProfile> _runSignIn(String email, String password) async {
    if (_signInAction != null) {
      return _signInAction!(email, password);
    }
    final client = _client;
    if (client == null) {
      throw const AuthException('Supabase client unavailable for sign-in.');
    }
    try {
      final response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return _profileFromUser(response.user);
    } on supa.AuthException catch (e) {
      throw AuthException(e.message);
    }
  }

  Future<UserProfile> _runSignUp(
    String email,
    String password,
    Map<String, dynamic>? metadata,
  ) async {
    if (_signUpAction != null) {
      return _signUpAction!(email, password, metadata);
    }
    final client = _client;
    if (client == null) {
      throw const AuthException('Supabase client unavailable for sign-up.');
    }
    try {
      final response = await client.auth.signUp(
        email: email,
        password: password,
        data: metadata,
      );
      return _profileFromUser(response.user);
    } on supa.AuthException catch (e) {
      throw AuthException(e.message);
    }
  }

  Future<void> _runSignOut() async {
    if (_signOutAction != null) {
      await _signOutAction!();
      return;
    }
    final client = _client;
    if (client == null) {
      throw const AuthException('Supabase client unavailable for sign-out.');
    }
    await client.auth.signOut();
  }

  Future<UserProfile?> _runCurrentUser() async {
    if (_currentUserAction != null) {
      return _currentUserAction!();
    }
    final client = _client;
    if (client == null) {
      return null;
    }
    final user = client.auth.currentUser;
    if (user == null) return null;
    return UserProfileDto(
      id: user.id,
      phone: user.userMetadata?['phone_number'] as String? ?? '',
      displayName: user.userMetadata?['display_name'] as String?,
      createdAt: DateTime.parse(user.createdAt),
    ).toDomain();
  }

  supa.Session? _runCurrentSession() {
    if (_currentSessionAction != null) {
      return _currentSessionAction!();
    }
    return _client?.auth.currentSession;
  }

  Future<void> _runRefreshSession() async {
    if (_refreshSessionAction != null) {
      await _refreshSessionAction!();
      return;
    }
    final client = _client;
    if (client == null) {
      throw const AuthException('Supabase client unavailable for refresh.');
    }
    await client.auth.refreshSession();
  }

  UserProfile _profileFromUser(supa.User? user) {
    if (user == null) {
      throw const AuthException('Auth request failed: no user returned.');
    }
    return UserProfileDto(
      id: user.id,
      phone: user.userMetadata?['phone_number'] as String? ?? '',
      displayName: user.userMetadata?['display_name'] as String?,
      createdAt: DateTime.parse(user.createdAt),
    ).toDomain();
  }
}
