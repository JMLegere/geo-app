import 'package:earth_nova/ui/product_surfaces/pack/widgets/species_card.dart';
import 'package:earth_nova_widgetbook/fixtures/pack_fixtures.dart';
import 'package:earth_nova_widgetbook/fixtures/story_host.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

@widgetbook.UseCase(
  name: '00 Happy Path',
  type: SpeciesCard,
  path: '[Product Surfaces]/Pack',
)
Widget speciesCardHappyPath(BuildContext context) =>
    earthNovaStory(child: SpeciesCard(item: storyExaminedFauna));

@widgetbook.UseCase(
  name: '01 Examined Unidentified',
  type: SpeciesCard,
  path: '[Product Surfaces]/Pack',
)
Widget speciesCardExaminedUnidentified(BuildContext context) => earthNovaStory(
  child: SpeciesCard(
    item: storyExaminedUnidentifiedFauna,
    onOpenIdentificationService: (_) {},
  ),
);

@widgetbook.UseCase(
  name: '02 Unexamined Item',
  type: SpeciesCard,
  path: '[Product Surfaces]/Pack',
)
Widget speciesCardUnexamined(BuildContext context) =>
    earthNovaStory(child: SpeciesCard(item: storyUnexaminedFauna));
