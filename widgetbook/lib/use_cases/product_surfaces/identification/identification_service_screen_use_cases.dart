import 'package:earth_nova/ui/product_surfaces/identification/screens/identification_service_screen.dart';
import 'package:earth_nova_widgetbook/fixtures/identification_fixtures.dart';
import 'package:earth_nova_widgetbook/fixtures/story_host.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

@widgetbook.UseCase(
  name: '00 Happy Path',
  type: IdentificationServiceScreen,
  path: '[Product Surfaces]/Identification',
)
Widget identificationServiceHappyPath(BuildContext context) => earthNovaStory(
  child: IdentificationServiceScreen(
    item: storyIdentificationItem,
    prepare: storyPrepareIdentification,
    commit: storyCommitIdentification,
  ),
  overrides: identificationStoryOverrides(),
);

@widgetbook.UseCase(
  name: '01 Preparing',
  type: IdentificationServiceScreen,
  path: '[Product Surfaces]/Identification',
)
Widget identificationServicePreparing(BuildContext context) => earthNovaStory(
  child: IdentificationServiceScreen(
    item: storyIdentificationItem,
    prepare: storyPendingPreparation,
    commit: storyCommitIdentification,
  ),
  overrides: identificationStoryOverrides(),
);

@widgetbook.UseCase(
  name: '02 Preparation Error',
  type: IdentificationServiceScreen,
  path: '[Product Surfaces]/Identification',
)
Widget identificationServicePreparationError(BuildContext context) =>
    earthNovaStory(
      child: IdentificationServiceScreen(
        item: storyIdentificationItem,
        prepare: storyFailPreparation,
        commit: storyCommitIdentification,
      ),
      overrides: identificationStoryOverrides(),
    );

@widgetbook.UseCase(
  name: '03 Hold To Reveal',
  type: IdentificationServiceScreen,
  path: '[Product Surfaces]/Identification',
)
Widget identificationServiceHoldToReveal(BuildContext context) =>
    earthNovaStory(
      child: IdentificationServiceScreen(
        item: storyIdentificationItem,
        prepare: storyPrepareIdentification,
        commit: storyCommitIdentification,
      ),
      overrides: identificationStoryOverrides(),
    );

@widgetbook.UseCase(
  name: '04 Committing (Start, Then Hold)',
  type: IdentificationServiceScreen,
  path: '[Product Surfaces]/Identification',
)
Widget identificationServiceCommitting(BuildContext context) => earthNovaStory(
  child: IdentificationServiceScreen(
    item: storyIdentificationItem,
    prepare: storyPrepareIdentification,
    commit: storyPendingCommit,
  ),
  overrides: identificationStoryOverrides(),
);

@widgetbook.UseCase(
  name: '05 Commit Error',
  type: IdentificationServiceScreen,
  path: '[Product Surfaces]/Identification',
)
Widget identificationServiceCommitError(BuildContext context) => earthNovaStory(
  child: IdentificationServiceScreen(
    item: storyIdentificationItem,
    prepare: storyPrepareIdentification,
    commit: storyFailCommit,
  ),
  overrides: identificationStoryOverrides(),
);

@widgetbook.UseCase(
  name: '06 Identified Result',
  type: IdentificationServiceScreen,
  path: '[Product Surfaces]/Identification',
)
Widget identificationServiceResult(BuildContext context) => earthNovaStory(
  child: IdentificationServiceScreen(
    item: storyIdentificationItem,
    prepare: storyPrepareIdentification,
    commit: storyCommitIdentification,
  ),
  overrides: identificationStoryOverrides(),
);
