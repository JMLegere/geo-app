import 'package:earth_nova/core/models/animal_class.dart';
import 'package:earth_nova/core/models/animal_type.dart';
import 'package:earth_nova/core/models/item_definition.dart';
import 'package:earth_nova/core/models/climate.dart';
import 'package:earth_nova/core/models/continent.dart';
import 'package:earth_nova/core/models/food_type.dart';
import 'package:earth_nova/core/models/habitat.dart';
import 'package:earth_nova/core/models/item_category.dart';
import 'package:earth_nova/core/models/iucn_status.dart';
import 'package:earth_nova/core/models/season.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// EarthNova Game Iconography
//
// Emoji placeholders for every game concept. These will eventually be replaced
// with custom sprite assets. Every UI that shows a game concept should pull
// its icon from here — never hardcode emoji inline.
//
// Organized by domain. Lookup via static methods that accept domain enums.
// ═══════════════════════════════════════════════════════════════════════════════

/// Centralized emoji icons for all game concepts.
///
/// Usage:
/// ```dart
/// GameIcons.habitat(Habitat.forest)   // '🌲'
/// GameIcons.animalType(AnimalType.bird) // '🐦'
/// GameIcons.rarity(IucnStatus.endangered) // '🔴'
/// ```
abstract final class GameIcons {
  // ── Item Categories ───────────────────────────────────────────────────────

  static String category(ItemCategory cat) => switch (cat) {
        ItemCategory.fauna => '🐾',
        ItemCategory.flora => '🌿',
        ItemCategory.mineral => '💎',
        ItemCategory.fossil => '🦴',
        ItemCategory.artifact => '🏺',
        ItemCategory.food => '🍎',
        ItemCategory.orb => '🔮',
      };

  // ── Animal Types (5) ─────────────────────────────────────────────────────

  static String animalType(AnimalType type) => switch (type) {
        AnimalType.mammal => '🦊',
        AnimalType.bird => '🐦',
        AnimalType.fish => '🐟',
        AnimalType.reptile => '🦎',
        AnimalType.bug => '🐛',
      };

  // ── Animal Classes (35) ──────────────────────────────────────────────────

  static String animalClass(AnimalClass cls) => switch (cls) {
        // Bird (7)
        AnimalClass.birdOfPrey => '🦅',
        AnimalClass.gameBird => '🐔',
        AnimalClass.nightbird => '🦉',
        AnimalClass.parrot => '🦜',
        AnimalClass.songbird => '🐤',
        AnimalClass.waterfowl => '🦆',
        AnimalClass.woodpecker => '🪶',
        // Bug (9)
        AnimalClass.bee => '🐝',
        AnimalClass.beetle => '🪲',
        AnimalClass.butterfly => '🦋',
        AnimalClass.cicada => '🦗',
        AnimalClass.dragonfly => '🪰',
        AnimalClass.landMollusk => '🐌',
        AnimalClass.locust => '🦗',
        AnimalClass.scorpion => '🦂',
        AnimalClass.spider => '🕷️',
        // Fish (6)
        AnimalClass.cartilaginousFish => '🦈',
        AnimalClass.cephalopod => '🐙',
        AnimalClass.clamsUrchinsAndCrustaceans => '🦀',
        AnimalClass.jawlessFish => '🐡',
        AnimalClass.lobeFinnedFish => '🐠',
        AnimalClass.rayFinnedFish => '🐟',
        // Mammal (8)
        AnimalClass.bat => '🦇',
        AnimalClass.carnivore => '🐺',
        AnimalClass.hare => '🐇',
        AnimalClass.herbivore => '🦌',
        AnimalClass.primate => '🐒',
        AnimalClass.rodent => '🐀',
        AnimalClass.seaMammal => '🐋',
        AnimalClass.shrew => '🐭',
        // Reptile (5)
        AnimalClass.amphibian => '🐸',
        AnimalClass.crocodile => '🐊',
        AnimalClass.lizard => '🦎',
        AnimalClass.snake => '🐍',
        AnimalClass.turtle => '🐢',
      };

  /// Best emoji for a fauna item: class → type → habitat → unknown.
  static String fauna(FaunaDefinition def) {
    if (def.animalClass != null) return animalClass(def.animalClass!);
    if (def.animalType != null) return animalType(def.animalType!);
    if (def.habitats.isNotEmpty) return habitat(def.habitats.first);
    return unknown;
  }

  // ── Habitats (7) ─────────────────────────────────────────────────────────

  static String habitat(Habitat h) => switch (h) {
        Habitat.forest => '🌲',
        Habitat.plains => '🌾',
        Habitat.freshwater => '💧',
        Habitat.saltwater => '🌊',
        Habitat.swamp => '🌿',
        Habitat.mountain => '⛰️',
        Habitat.desert => '🏜️',
      };

  // ── Climate Zones (4) ────────────────────────────────────────────────────

  static String climate(Climate c) => switch (c) {
        Climate.tropic => '🌴',
        Climate.temperate => '🍂',
        Climate.boreal => '🌨️',
        Climate.frigid => '❄️',
      };

  // ── Food Types (7) ───────────────────────────────────────────────────────

  static String foodType(FoodType f) => switch (f) {
        FoodType.critter => '🦗',
        FoodType.fish => '🐟',
        FoodType.fruit => '🍇',
        FoodType.grub => '🪱',
        FoodType.nectar => '🍯',
        FoodType.seed => '🌰',
        FoodType.veg => '🥬',
      };

  // ── Continents (6) ───────────────────────────────────────────────────────

  static String continent(Continent c) => switch (c) {
        Continent.asia => '🏯',
        Continent.northAmerica => '🗽',
        Continent.southAmerica => '🌎',
        Continent.africa => '🌍',
        Continent.oceania => '🏝️',
        Continent.europe => '🏰',
      };

  // ── Rarity / IUCN Status (6) ─────────────────────────────────────────────

  static String rarity(IucnStatus status) => switch (status) {
        IucnStatus.leastConcern => '🟢',
        IucnStatus.nearThreatened => '🟡',
        IucnStatus.vulnerable => '🟠',
        IucnStatus.endangered => '🔴',
        IucnStatus.criticallyEndangered => '💀',
        IucnStatus.extinct => '⚫',
      };

  // ── Seasons (2) ──────────────────────────────────────────────────────────

  static String season(Season s) => switch (s) {
        Season.summer => '☀️',
        Season.winter => '❄️',
      };

  // ── Stats (for detail sheets) ────────────────────────────────────────────

  static const String brawn = '💪';
  static const String wit = '🧠';
  static const String speed = '⚡';

  // ── Misc game concepts ───────────────────────────────────────────────────

  static const String character = '🧑';
  static const String streak = '🔥';
  static const String distance = '👣';
  static const String cellsExplored = '🗺️';
  static const String totalItems = '🎒';
  static const String wildCaught = '🎣';
  static const String bred = '🥚';
  static const String donated = '🏛️';
  static const String placed = '🏡';
  static const String released = '🕊️';
  static const String traded = '🤝';
  static const String steps = '🚶';
  static const String unknown = '❓';
  static const String empty = '◻️';
}
