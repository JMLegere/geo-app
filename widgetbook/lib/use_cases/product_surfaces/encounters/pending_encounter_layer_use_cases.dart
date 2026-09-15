import 'package:earth_nova/features/encounters/presentation/providers/pending_encounter_provider.dart';
import 'package:earth_nova/ui/product_surfaces/encounters/widgets/pending_encounter_layer.dart';
import 'package:earth_nova_widgetbook/fixtures/encounters_fixtures.dart';
import 'package:earth_nova_widgetbook/fixtures/story_host.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

Widget _pendingEncounterStory(PendingEncounterState state) => earthNovaStory(
  child: const Scaffold(body: PendingEncounterLayer()),
  overrides: pendingEncounterStoryOverrides(state),
);

@widgetbook.UseCase(
  name: '00 Happy Path',
  type: PendingEncounterLayer,
  path: '[Product Surfaces]/Encounters',
)
Widget pendingEncounterReady(BuildContext context) =>
    _pendingEncounterStory(PendingEncounterReady(storyPendingEncounter));

@widgetbook.UseCase(
  name: '01 Resolving',
  type: PendingEncounterLayer,
  path: '[Product Surfaces]/Encounters',
)
Widget pendingEncounterResolving(BuildContext context) =>
    _pendingEncounterStory(
      PendingEncounterResolving(
        storyPendingEncounter,
        storyPendingEncounter.options.first.id,
      ),
    );

@widgetbook.UseCase(
  name: '02 Resolution Failure',
  type: PendingEncounterLayer,
  path: '[Product Surfaces]/Encounters',
)
Widget pendingEncounterFailure(BuildContext context) => _pendingEncounterStory(
  PendingEncounterFailure(
    pendingEncounter: storyPendingEncounter,
    optionId: storyPendingEncounter.options.first.id,
  ),
);

@widgetbook.UseCase(
  name: '03 No Pending — Expected Absence',
  type: PendingEncounterLayer,
  path: '[Product Surfaces]/Encounters',
)
Widget pendingEncounterNone(BuildContext context) =>
    _pendingEncounterStory(const PendingEncounterNone());

@widgetbook.UseCase(
  name: '04 Loading — Expected Absence',
  type: PendingEncounterLayer,
  path: '[Product Surfaces]/Encounters',
)
Widget pendingEncounterLoading(BuildContext context) =>
    _pendingEncounterStory(const PendingEncounterLoading());

@widgetbook.UseCase(
  name: '05 Load Error — Expected Absence',
  type: PendingEncounterLayer,
  path: '[Product Surfaces]/Encounters',
)
Widget pendingEncounterLoadError(BuildContext context) =>
    _pendingEncounterStory(const PendingEncounterFailure());

@widgetbook.UseCase(
  name: '06 Resolved — Expected Absence',
  type: PendingEncounterLayer,
  path: '[Product Surfaces]/Encounters',
)
Widget pendingEncounterResolved(BuildContext context) =>
    _pendingEncounterStory(storyResolvedEncounter);
