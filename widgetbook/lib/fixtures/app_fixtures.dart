import 'package:earth_nova/app/readiness/app_readiness.dart';
import 'package:earth_nova/core/domain/entities/auth_state.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/auth/presentation/providers/auth_provider.dart';
import 'package:riverpod/misc.dart';
import 'package:earth_nova_widgetbook/fixtures/auth_fixtures.dart';

List<Override> readinessStoryOverrides(AppReadinessState state) {
  final observability = ObservabilityService(sessionId: 'widgetbook-readiness');
  return [
    appObservabilityProvider.overrideWithValue(observability),
    authProvider.overrideWith(
      () => StoryAuthNotifier(const AuthState.unauthenticated()),
    ),
    appReadinessProvider.overrideWith(() => StoryReadinessNotifier(state)),
  ];
}

final class StoryReadinessNotifier extends AppReadinessNotifier {
  StoryReadinessNotifier(this.initialState);

  final AppReadinessState initialState;

  @override
  AppReadinessState build() => initialState;

  @override
  Future<void> start(String userId) async {}

  @override
  Future<void> retry() async {}

  @override
  Future<bool> purge(String userId) async => true;
}
