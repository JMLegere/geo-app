import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/core/observability/trace_context.dart';
import 'package:earth_nova/features/identification/presentation/providers/items_provider.dart';
import 'package:riverpod/misc.dart';

final storyPackItems = <Item>[
  storyExaminedFauna,
  storyExaminedFlora,
  storyUnexaminedFauna,
];

final storyExaminedFauna = Item(
  id: 'story-red-fox',
  definitionId: 'fauna:red_fox',
  displayName: 'Red Fox',
  scientificName: 'Vulpes vulpes',
  category: ItemCategory.fauna,
  rarity: 'leastConcern',
  acquiredAt: DateTime.utc(2026, 1, 3),
  status: ItemStatus.active,
  taxonomicClass: 'MAMMALIA',
  habitats: const ['forest'],
  continents: const ['northAmerica'],
  examinedAt: DateTime.utc(2026, 1, 3, 1),
);

final storyExaminedFlora = Item(
  id: 'story-oak',
  definitionId: 'flora:oak',
  displayName: 'Oak Tree',
  scientificName: 'Quercus robur',
  category: ItemCategory.flora,
  rarity: 'leastConcern',
  acquiredAt: DateTime.utc(2026, 1, 2),
  status: ItemStatus.active,
  taxonomicClass: 'MAGNOLIOPSIDA',
  habitats: const ['forest'],
  continents: const ['europe'],
  examinedAt: DateTime.utc(2026, 1, 2, 1),
);

final storyUnexaminedFauna = Item(
  id: 'story-amberwing',
  definitionId: 'fauna:amberwing',
  displayName: 'Amberwing Warbler',
  scientificName: 'Setophaga aestiva',
  category: ItemCategory.fauna,
  rarity: 'vulnerable',
  acquiredAt: DateTime.utc(2026, 1, 4),
  status: ItemStatus.active,
  identificationState: ItemIdentificationState.unidentified,
  examinationState: ItemExaminationState.unexamined,
  identifiedDisplayName: 'Amberwing Warbler',
  identifiedScientificName: 'Setophaga aestiva',
);

final storyExaminedUnidentifiedFauna = storyUnexaminedFauna.copyWith(
  examinationState: ItemExaminationState.examined,
  examinedAt: DateTime.utc(2026, 1, 4, 1),
);

List<Override> packStoryOverrides(ItemsState state) => [
  appObservabilityProvider.overrideWithValue(
    ObservabilityService(sessionId: 'widgetbook-pack'),
  ),
  itemsProvider.overrideWith(() => PackStoryItemsNotifier(state)),
];

final class PackStoryItemsNotifier extends ItemsNotifier {
  PackStoryItemsNotifier(this.value);

  final ItemsState value;

  @override
  ItemsState build() => value;

  @override
  Future<void> fetchItems() async {}

  @override
  Future<Item?> examinePackItem(String itemId, {TraceContext? parent}) async =>
      state.items.where((item) => item.id == itemId).firstOrNull;
}
