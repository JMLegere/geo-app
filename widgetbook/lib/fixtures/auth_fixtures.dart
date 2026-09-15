import 'package:earth_nova/core/domain/entities/auth_state.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/auth/presentation/providers/auth_provider.dart';
import 'package:riverpod/misc.dart';

const storyPlayerId = '00000000-0000-4000-8000-000000000001';

List<Override> authStoryOverrides({
  AuthState state = const AuthState.unauthenticated(),
  AuthState? submittedState,
}) {
  final observability = ObservabilityService(sessionId: 'widgetbook-auth');
  return [
    appObservabilityProvider.overrideWithValue(observability),
    observabilityProvider.overrideWithValue(observability),
    authProvider.overrideWith(
      () => StoryAuthNotifier(state, submittedState: submittedState),
    ),
  ];
}

final class StoryAuthNotifier extends AuthNotifier {
  StoryAuthNotifier(this.initialState, {this.submittedState});

  final AuthState initialState;
  final AuthState? submittedState;

  @override
  AuthState build() => initialState;

  @override
  Future<void> signInWithPhone(String phone) async {
    state = submittedState ?? initialState;
  }

  @override
  Future<void> restoreSession() async {}

  @override
  Future<void> signOut() async {
    state = const AuthState.unauthenticated();
  }
}
