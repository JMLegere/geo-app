import 'animal_type.dart';

/// ~35 game-designed animal sub-classifications.
/// AI-determined on first global discovery, then canonical forever.
enum AnimalClass {
  // Bird (7)
  birdOfPrey,
  gameBird,
  nightbird,
  parrot,
  songbird,
  waterfowl,
  woodpecker,
  // Bug (9)
  bee,
  beetle,
  butterfly,
  cicada,
  dragonfly,
  landMollusk,
  locust,
  scorpion,
  spider,
  // Fish (6)
  cartilaginousFish,
  cephalopod,
  clamsUrchinsAndCrustaceans,
  jawlessFish,
  lobeFinnedFish,
  rayFinnedFish,
  // Mammal (8)
  bat,
  carnivore,
  hare,
  herbivore,
  primate,
  rodent,
  seaMammal,
  shrew,
  // Reptile (5)
  amphibian,
  crocodile,
  lizard,
  snake,
  turtle;

  String get displayName => switch (this) {
        AnimalClass.birdOfPrey => 'Bird of Prey',
        AnimalClass.gameBird => 'Game Bird',
        AnimalClass.nightbird => 'Nightbird',
        AnimalClass.parrot => 'Parrot',
        AnimalClass.songbird => 'Songbird',
        AnimalClass.waterfowl => 'Waterfowl',
        AnimalClass.woodpecker => 'Woodpecker',
        AnimalClass.bee => 'Bee',
        AnimalClass.beetle => 'Beetle',
        AnimalClass.butterfly => 'Butterfly',
        AnimalClass.cicada => 'Cicada',
        AnimalClass.dragonfly => 'Dragonfly',
        AnimalClass.landMollusk => 'Land Mollusk',
        AnimalClass.locust => 'Locust',
        AnimalClass.scorpion => 'Scorpion',
        AnimalClass.spider => 'Spider',
        AnimalClass.cartilaginousFish => 'Cartilaginous Fish',
        AnimalClass.cephalopod => 'Cephalopod',
        AnimalClass.clamsUrchinsAndCrustaceans =>
          'Clams, Urchins & Crustaceans',
        AnimalClass.jawlessFish => 'Jawless Fish',
        AnimalClass.lobeFinnedFish => 'Lobe-finned Fish',
        AnimalClass.rayFinnedFish => 'Ray-finned Fish',
        AnimalClass.bat => 'Bat',
        AnimalClass.carnivore => 'Carnivore',
        AnimalClass.hare => 'Hare',
        AnimalClass.herbivore => 'Herbivore',
        AnimalClass.primate => 'Primate',
        AnimalClass.rodent => 'Rodent',
        AnimalClass.seaMammal => 'Sea Mammal',
        AnimalClass.shrew => 'Shrew',
        AnimalClass.amphibian => 'Amphibian',
        AnimalClass.crocodile => 'Crocodile',
        AnimalClass.lizard => 'Lizard',
        AnimalClass.snake => 'Snake',
        AnimalClass.turtle => 'Turtle',
      };

  /// The [AnimalType] this class belongs to.
  AnimalType get parentType => switch (this) {
        AnimalClass.birdOfPrey ||
        AnimalClass.gameBird ||
        AnimalClass.nightbird ||
        AnimalClass.parrot ||
        AnimalClass.songbird ||
        AnimalClass.waterfowl ||
        AnimalClass.woodpecker =>
          AnimalType.bird,
        AnimalClass.bee ||
        AnimalClass.beetle ||
        AnimalClass.butterfly ||
        AnimalClass.cicada ||
        AnimalClass.dragonfly ||
        AnimalClass.landMollusk ||
        AnimalClass.locust ||
        AnimalClass.scorpion ||
        AnimalClass.spider =>
          AnimalType.bug,
        AnimalClass.cartilaginousFish ||
        AnimalClass.cephalopod ||
        AnimalClass.clamsUrchinsAndCrustaceans ||
        AnimalClass.jawlessFish ||
        AnimalClass.lobeFinnedFish ||
        AnimalClass.rayFinnedFish =>
          AnimalType.fish,
        AnimalClass.bat ||
        AnimalClass.carnivore ||
        AnimalClass.hare ||
        AnimalClass.herbivore ||
        AnimalClass.primate ||
        AnimalClass.rodent ||
        AnimalClass.seaMammal ||
        AnimalClass.shrew =>
          AnimalType.mammal,
        AnimalClass.amphibian ||
        AnimalClass.crocodile ||
        AnimalClass.lizard ||
        AnimalClass.snake ||
        AnimalClass.turtle =>
          AnimalType.reptile,
      };

  static AnimalClass fromString(String value) {
    return AnimalClass.values.firstWhere(
      (c) => c.name == value,
      orElse: () => throw ArgumentError('Unknown AnimalClass: $value'),
    );
  }

  @override
  String toString() => name;
}
