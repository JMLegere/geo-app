import 'dart:async';

import 'package:earth_nova/core/domain/entities/auth_state.dart';
import 'package:earth_nova/core/domain/entities/user_profile.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/auth/presentation/providers/auth_provider.dart';
import 'package:earth_nova/features/home/domain/entities/home.dart';
import 'package:earth_nova/features/home/domain/repositories/home_repository.dart';
import 'package:earth_nova/features/home/presentation/providers/home_provider.dart';
import 'package:riverpod/misc.dart';
import 'package:earth_nova_widgetbook/fixtures/auth_fixtures.dart';

final storyHomePlayer = UserProfile(
  id: storyPlayerId,
  phone: '5555555555',
  displayName: 'Explorer',
  createdAt: DateTime.utc(2026),
);

final storyHome = Home(
  id: 'home:explorer',
  playerId: storyPlayerId,
  createdAt: DateTime.utc(2026, 7, 21),
);

List<Override> homeStoryOverrides(Future<Home> Function() read) {
  final observability = ObservabilityService(sessionId: 'widgetbook-home');
  return [
    appObservabilityProvider.overrideWithValue(observability),
    homeObservabilityProvider.overrideWithValue(observability),
    authProvider.overrideWith(
      () => StoryAuthNotifier(AuthState.authenticated(storyHomePlayer)),
    ),
    homeRepositoryProvider.overrideWithValue(StoryHomeRepository(read)),
  ];
}

final class StoryHomeRepository implements HomeRepository {
  StoryHomeRepository(this._read);

  final Future<Home> Function() _read;

  @override
  Future<Home> readHome(String playerId, {required String traceId}) => _read();
}

Future<Home> storyHomeLoading() => Completer<Home>().future;

Future<Home> storyHomeUnavailable() =>
    Future<Home>.error(const HomeFailure.unavailable());
