import 'package:earth_nova/core/models/animal_class.dart';
import 'package:earth_nova/core/models/animal_type.dart';
import 'package:earth_nova/core/models/cell_event.dart';
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
// Every emoji is UNIQUE across all categories that can appear on the same
// screen. The species card identity row (habitat, continent, food, climate)
// must have zero collisions. Animal class (type bar) must not repeat habitat
// or food emojis.
//
// When picking emojis: check this file first. If the emoji exists, pick
// a different one.
// ═══════════════════════════════════════════════════════════════════════════════

/// Centralized icons for all game concepts.
///
/// Usage:
/// ```dart
/// GameIcons.habitat(Habitat.forest)   // '🌲'
/// GameIcons.animalClass(AnimalClass.carnivore) // '🦁'
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

  // ── Animal Types (5) — fallback when class is unknown ─────────────────────

  static String animalType(AnimalType type) => switch (type) {
        AnimalType.mammal => '🐻',
        AnimalType.bird => '🕊️',
        AnimalType.fish => '🐟',
        AnimalType.reptile => '🐲',
        AnimalType.bug => '🪳',
      };

  // ── Animal Classes (35) — all unique, no repeats ─────────────────────────

  static String animalClass(AnimalClass cls) => switch (cls) {
        // Bird (7)
        AnimalClass.birdOfPrey => '🦅',
        AnimalClass.gameBird => '🦃',
        AnimalClass.nightbird => '🦉',
        AnimalClass.parrot => '🦜',
        AnimalClass.songbird => '🐦',
        AnimalClass.waterfowl => '🦆',
        AnimalClass.woodpecker => '🪶',
        // Bug (9)
        AnimalClass.bee => '🐝',
        AnimalClass.beetle => '🪲',
        AnimalClass.butterfly => '🦋',
        AnimalClass.cicada => '🦗',
        AnimalClass.dragonfly => '🪰',
        AnimalClass.landMollusk => '🐌',
        AnimalClass.locust => '🦟',
        AnimalClass.scorpion => '🦂',
        AnimalClass.spider => '🕷️',
        // Fish (6) — 🐟🐠🐡🦈🐙🦞 all distinct
        AnimalClass.cartilaginousFish => '🦈',
        AnimalClass.cephalopod => '🐙',
        AnimalClass.clamsUrchinsAndCrustaceans => '🦞',
        AnimalClass.jawlessFish => '🐡',
        AnimalClass.lobeFinnedFish => '🐟',
        AnimalClass.rayFinnedFish => '🐠',
        // Mammal (8)
        AnimalClass.bat => '🦇',
        AnimalClass.carnivore => '🦁',
        AnimalClass.hare => '🐇',
        AnimalClass.herbivore => '🦌',
        AnimalClass.primate => '🐒',
        AnimalClass.rodent => '🐭',
        AnimalClass.seaMammal => '🐋',
        AnimalClass.shrew => '🐀',
        // Reptile (5)
        AnimalClass.amphibian => '🐸',
        AnimalClass.crocodile => '🐊',
        AnimalClass.lizard => '🦎',
        AnimalClass.snake => '🐍',
        AnimalClass.turtle => '🐢',
      };

  /// Best icon for a fauna item: class → type → habitat → unknown.
  static String fauna(FaunaDefinition def) {
    if (def.animalClass != null) return animalClass(def.animalClass!);
    if (def.animalType != null) return animalType(def.animalType!);
    if (def.habitats.isNotEmpty) return habitat(def.habitats.first);
    return unknown;
  }

  // ── Habitats (7) — identity row emojis ────────────────────────────────────

  static String habitat(Habitat h) => switch (h) {
        Habitat.forest => '🌲',
        Habitat.plains => '🌾',
        Habitat.freshwater => '💧',
        Habitat.saltwater => '🌊',
        Habitat.swamp => '🪷',
        Habitat.mountain => '⛰️',
        Habitat.desert => '🏜️',
      };

  // ── Climate Zones (4) — identity row emojis ───────────────────────────────

  static String climate(Climate c) => switch (c) {
        Climate.tropic => '🌴',
        Climate.temperate => '🌤️',
        Climate.boreal => '🌨️',
        Climate.frigid => '🧊',
      };

  // ── Food Types (7) — identity row emojis ──────────────────────────────────

  static String foodType(FoodType f) => switch (f) {
        FoodType.critter => '🍖',
        FoodType.fish => '🎣',
        FoodType.fruit => '🍇',
        FoodType.grub => '🪱',
        FoodType.nectar => '🍯',
        FoodType.seed => '🌰',
        FoodType.veg => '🥬',
      };

  // ── Continents (6) — identity row emojis ──────────────────────────────────

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

  // ── Abbreviations (kept for non-card contexts) ───────────────────────────

  static String habitatAbbrev(Habitat h) => switch (h) {
        Habitat.forest => 'FOR',
        Habitat.plains => 'PLN',
        Habitat.freshwater => 'FRW',
        Habitat.saltwater => 'SAL',
        Habitat.swamp => 'SWP',
        Habitat.mountain => 'MTN',
        Habitat.desert => 'DES',
      };

  static String continentAbbrev(Continent c) => switch (c) {
        Continent.asia => 'AS',
        Continent.northAmerica => 'NA',
        Continent.southAmerica => 'SA',
        Continent.africa => 'AF',
        Continent.oceania => 'OC',
        Continent.europe => 'EU',
      };

  static String animalClassAbbrev(AnimalClass cls) => switch (cls) {
        AnimalClass.birdOfPrey => 'BOP',
        AnimalClass.gameBird => 'GMB',
        AnimalClass.nightbird => 'NTB',
        AnimalClass.parrot => 'PRT',
        AnimalClass.songbird => 'SNG',
        AnimalClass.waterfowl => 'WTF',
        AnimalClass.woodpecker => 'WDP',
        AnimalClass.bee => 'BEE',
        AnimalClass.beetle => 'BTL',
        AnimalClass.butterfly => 'BTF',
        AnimalClass.cicada => 'CCD',
        AnimalClass.dragonfly => 'DGF',
        AnimalClass.landMollusk => 'MLK',
        AnimalClass.locust => 'LCT',
        AnimalClass.scorpion => 'SCR',
        AnimalClass.spider => 'SPD',
        AnimalClass.cartilaginousFish => 'CRT',
        AnimalClass.cephalopod => 'CPH',
        AnimalClass.clamsUrchinsAndCrustaceans => 'CRC',
        AnimalClass.jawlessFish => 'JWL',
        AnimalClass.lobeFinnedFish => 'LBF',
        AnimalClass.rayFinnedFish => 'RYF',
        AnimalClass.bat => 'BAT',
        AnimalClass.carnivore => 'CRN',
        AnimalClass.hare => 'HAR',
        AnimalClass.herbivore => 'HRB',
        AnimalClass.primate => 'PRM',
        AnimalClass.rodent => 'RDT',
        AnimalClass.seaMammal => 'SEA',
        AnimalClass.shrew => 'SHR',
        AnimalClass.amphibian => 'AMP',
        AnimalClass.crocodile => 'CRO',
        AnimalClass.lizard => 'LZD',
        AnimalClass.snake => 'SNK',
        AnimalClass.turtle => 'TRT',
      };

  /// Convert 2-letter ISO 3166-1 country code to flag emoji.
  static String countryFlag(String isoCode) {
    if (isoCode.length != 2) return '🏳️';
    return String.fromCharCodes(
      isoCode.toUpperCase().codeUnits.map((c) => c + 0x1F1A5),
    );
  }

  // ── Size & Weight ─────────────────────────────────────────────────────────

  static const String size = '📏';
  static const String weight = '⚖️';

  // ── Stats (for detail sheets) ────────────────────────────────────────────

  static const String brawn = '💪';
  static const String wit = '🧠';
  static const String speed = '⚡';

  // ── Cell Events (2) ────────────────────────────────────────────────────

  static String cellEvent(CellEventType type) => switch (type) {
        CellEventType.migration => '🦢',
        CellEventType.nestingSite => '🪺',
      };

  /// Icon for cells with an event that hasn't been visited yet.
  static const String eventUnknown = '❓';

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
  static const String town = '🏘️';
  static const String globe = '🌏';
  static const String error = '😕';
}
