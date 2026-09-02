import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/core/domain/entities/auth_state.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/features/auth/presentation/providers/auth_provider.dart';
import 'package:earth_nova/features/home/domain/entities/home.dart';
import 'package:earth_nova/features/home/presentation/providers/home_provider.dart';
import 'package:earth_nova/shared/design.dart';
import 'package:earth_nova/shared/observability/widgets/observable_interaction.dart';
import 'package:earth_nova/shared/observability/widgets/observable_screen.dart';

/// Read-only Home identity surface for the authenticated Player.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final obs = ref.watch(appObservabilityProvider);
    final authState = ref.watch(authProvider);
    final homeState = ref.watch(homeProvider);
    _syncHome(authState, homeState);

    return ObservableScreen(
      screenName: 'home_screen',
      observability: obs,
      builder: (_) => Scaffold(
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () => _refreshHome(authState),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: SizedBox(
                      width: double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Home',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your permanent place in EarthNova.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 24),
                          _HomeBody(
                            authState: authState,
                            state: homeState,
                            onRetry: () => _refreshHome(authState),
                            logger:
                                ({required event, required category, data}) {
                                  ref
                                      .read(appObservabilityProvider)
                                      .log(event, category, data: data);
                                },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _syncHome(AuthState authState, HomeState homeState) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (authState.status == AuthStatus.authenticated) {
        final playerId = authState.user!.id;
        if (ref.read(homeProvider).shouldLoadFor(playerId)) {
          unawaited(ref.read(homeProvider.notifier).load(playerId));
        }
        return;
      }

      if (homeState.playerId != null ||
          homeState.home != null ||
          homeState.error != null) {
        ref.read(homeProvider.notifier).invalidate();
      }
    });
  }

  Future<void> _refreshHome(AuthState authState) async {
    if (authState.status != AuthStatus.authenticated) return;
    await ref.read(homeProvider.notifier).refresh(authState.user!.id);
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody({
    required this.authState,
    required this.state,
    required this.onRetry,
    required this.logger,
  });

  final AuthState authState;
  final HomeState state;
  final Future<void> Function() onRetry;
  final InteractionLogger logger;

  @override
  Widget build(BuildContext context) {
    if (authState.status == AuthStatus.loading) {
      return const _HomeLoadingState();
    }
    if (authState.status != AuthStatus.authenticated) {
      return const AppNotice(
        title: 'Home unavailable',
        message: 'Sign in to view your established Home identity.',
      );
    }

    final home = state.home;
    if (state.isLoading && home == null) {
      return const _HomeLoadingState();
    }
    if (state.error != null && home == null) {
      return _HomeErrorState(
        message: state.error!,
        onRetry: onRetry,
        logger: logger,
      );
    }
    if (home == null) {
      return const _HomeLoadingState();
    }

    return _ExistingHomeState(home: home, refreshError: state.error);
  }
}

class _HomeLoadingState extends StatelessWidget {
  const _HomeLoadingState();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      title: 'Loading Home',
      description: 'Home identity',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Confirming your personal Home identity.'),
          SizedBox(height: 16),
          LoadingDots(),
        ],
      ),
    );
  }
}

class _HomeErrorState extends StatelessWidget {
  const _HomeErrorState({
    required this.message,
    required this.onRetry,
    required this.logger,
  });

  final String message;
  final Future<void> Function() onRetry;
  final InteractionLogger logger;

  @override
  Widget build(BuildContext context) {
    return AppErrorState(
      title: 'Home could not load',
      message: message,
      retryLabel: 'Retry Home load',
      onRetry: ObservableInteraction.wrapAsyncCallback(
        logger: logger,
        screenName: 'home_screen',
        widgetName: 'home_error_retry',
        actionType: 'retry_home_load',
        telemetryOnlyReason:
            'Home retry is transport recovery inside the open Home view.',
        callback: onRetry,
      ),
    );
  }
}

class _ExistingHomeState extends StatelessWidget {
  const _ExistingHomeState({required this.home, required this.refreshError});

  final Home home;
  final String? refreshError;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (refreshError != null) ...[
          AppNotice(
            title: 'Home refresh delayed',
            message: refreshError!,
            tone: AppNoticeTone.warning,
          ),
          const SizedBox(height: 16),
        ],
        AppCard(
          title: 'Your Home',
          description: 'Permanent',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppFieldRow(
                label: 'Status',
                value: 'Established',
                helper: 'This Home is yours and stays with you.',
              ),
              const AppFieldRow(
                label: 'Identity',
                value: 'Yours across EarthNova',
                helper: 'Your Home follows your progress across EarthNova.',
              ),
              AppFieldRow(
                label: 'Established',
                value: _formatEstablishedDate(home.createdAt),
                helper: 'The day this Home became yours.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

const _monthNames = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String _formatEstablishedDate(DateTime value) {
  final utc = value.toUtc();
  return '${_monthNames[utc.month - 1]} ${utc.day}, ${utc.year}';
}
