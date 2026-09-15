import 'package:earth_nova/app/readiness/app_readiness.dart';
import 'package:earth_nova/ui/product_surfaces/app/app_readiness_gate.dart';
import 'package:earth_nova_widgetbook/fixtures/app_fixtures.dart';
import 'package:earth_nova_widgetbook/fixtures/story_host.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

Widget _readinessStory(AppReadinessState state) => earthNovaStory(
  overrides: readinessStoryOverrides(state),
  child: const AppReadinessGate(
    userId: '00000000-0000-4000-8000-000000000001',
    child: Scaffold(body: Center(child: Text('Safe catalog child'))),
  ),
);

@widgetbook.UseCase(
  name: '00 Happy Path',
  type: AppReadinessGate,
  path: '[Product Surfaces]/App',
)
Widget appReadinessGateHappyPath(BuildContext context) => _readinessStory(
  const AppReadinessState(
    phase: AppReadinessPhase.usable,
    completedCheckpoints: AppReadinessState.requiredCheckpoints,
  ),
);

@widgetbook.UseCase(
  name: '10 Hydrating',
  type: AppReadinessGate,
  path: '[Product Surfaces]/App',
)
Widget appReadinessGateHydrating(BuildContext context) => _readinessStory(
  const AppReadinessState(
    phase: AppReadinessPhase.hydrating,
    completedCheckpoints: {'working_set'},
  ),
);

@widgetbook.UseCase(
  name: '20 Syncing',
  type: AppReadinessGate,
  path: '[Product Surfaces]/App',
)
Widget appReadinessGateSyncing(BuildContext context) => _readinessStory(
  const AppReadinessState(
    phase: AppReadinessPhase.syncing,
    completedCheckpoints: AppReadinessState.requiredCheckpoints,
  ),
);

@widgetbook.UseCase(
  name: '30 Degraded',
  type: AppReadinessGate,
  path: '[Product Surfaces]/App',
)
Widget appReadinessGateDegraded(BuildContext context) => _readinessStory(
  const AppReadinessState(
    phase: AppReadinessPhase.degraded,
    completedCheckpoints: AppReadinessState.requiredCheckpoints,
  ),
);

@widgetbook.UseCase(
  name: '40 Failed',
  type: AppReadinessGate,
  path: '[Product Surfaces]/App',
)
Widget appReadinessGateFailed(BuildContext context) => _readinessStory(
  const AppReadinessState(
    phase: AppReadinessPhase.failed,
    completedCheckpoints: {'pack'},
    errorMessage: 'Your saved expedition is unavailable right now.',
  ),
);
