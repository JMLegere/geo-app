import 'package:earth_nova/core/domain/entities/taxonomic_group.dart';
import 'package:earth_nova/core/domain/entities/habitat.dart';
import 'package:earth_nova/core/domain/entities/game_region.dart';
import 'package:earth_nova/core/domain/entities/item.dart';

abstract final class AppIcons {
  static const String fauna = '🦊';
  static const String flora = '🌿';
  static const String mineral = '💎';
  static const String fossil = '🦴';
  static const String artifact = '🏺';
  static const String food = '🍄';
  static const String orb = '🔮';

  static const String mammals = '🦁';
  static const String birds = '🦅';
  static const String reptiles = '🦎';
  static const String amphibians = '🐸';
  static const String fish = '🐟';
  static const String invertebrates = '🦋';

  static const String forest = '🌲';
  static const String plains = '🌾';
  static const String freshwater = '💧';
  static const String saltwater = '🌊';
  static const String swamp = '🌱';
  static const String mountain = '🏔️';
  static const String desert = '🌵';

  static const String africa = '🌍';
  static const String asia = '🌏';
  static const String europe = '🏛️';
  static const String northAmerica = '🌎';
  static const String southAmerica = '🌺';
  static const String oceania = '🪃';

  static const String sortRecent = '🕐';
  static const String sortRarity = '⭐';
  static const String sortName = '🔤';

  static const String unknown = '❓';
  static const String search = '🔍';

  static const String map = '🗺️';
  static const String sanctuary = '🌿';
}

extension TaxonomicGroupIcon on TaxonomicGroup {
  String get icon => switch (this) {
        TaxonomicGroup.mammals => AppIcons.mammals,
        TaxonomicGroup.birds => AppIcons.birds,
        TaxonomicGroup.reptiles => AppIcons.reptiles,
        TaxonomicGroup.amphibians => AppIcons.amphibians,
        TaxonomicGroup.fish => AppIcons.fish,
        TaxonomicGroup.invertebrates => AppIcons.invertebrates,
        TaxonomicGroup.other => AppIcons.unknown,
      };
}

extension HabitatIcon on Habitat {
  String get icon => switch (this) {
        Habitat.forest => AppIcons.forest,
        Habitat.plains => AppIcons.plains,
        Habitat.freshwater => AppIcons.freshwater,
        Habitat.saltwater => AppIcons.saltwater,
        Habitat.swamp => AppIcons.swamp,
        Habitat.mountain => AppIcons.mountain,
        Habitat.desert => AppIcons.desert,
        Habitat.unknown => AppIcons.unknown,
      };
}

extension GameRegionIcon on GameRegion {
  String get icon => switch (this) {
        GameRegion.africa => AppIcons.africa,
        GameRegion.asia => AppIcons.asia,
        GameRegion.europe => AppIcons.europe,
        GameRegion.northAmerica => AppIcons.northAmerica,
        GameRegion.southAmerica => AppIcons.southAmerica,
        GameRegion.oceania => AppIcons.oceania,
        GameRegion.unknown => AppIcons.unknown,
      };
}

extension ItemCategoryEmoji on ItemCategory {
  String get emoji => switch (this) {
        ItemCategory.fauna => AppIcons.fauna,
        ItemCategory.flora => AppIcons.flora,
        ItemCategory.mineral => AppIcons.mineral,
        ItemCategory.fossil => AppIcons.fossil,
        ItemCategory.artifact => AppIcons.artifact,
        ItemCategory.food => AppIcons.food,
        ItemCategory.orb => AppIcons.orb,
      };
}

enum PackSortMode {
  recent(AppIcons.sortRecent, 'Recent'),
  rarity(AppIcons.sortRarity, 'Rarity'),
  name(AppIcons.sortName, 'A→Z');

  const PackSortMode(this.icon, this.label);

  final String icon;
  final String label;
}
