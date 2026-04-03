/// 7 food subtypes. Found during exploration, fed to sanctuary animals.
enum FoodType {
  critter,
  fish,
  fruit,
  grub,
  nectar,
  seed,
  veg;

  String get displayName => switch (this) {
        FoodType.critter => 'Critter',
        FoodType.fish => 'Fish',
        FoodType.fruit => 'Fruit',
        FoodType.grub => 'Grub',
        FoodType.nectar => 'Nectar',
        FoodType.seed => 'Seed',
        FoodType.veg => 'Veg',
      };

  /// Canonical item ID prefix: 'food-critter', 'food-fish', etc.
  String get id => 'food-$name';

  static FoodType fromString(String value) {
    return FoodType.values.firstWhere(
      (t) => t.name == value,
      orElse: () => throw ArgumentError('Unknown FoodType: $value'),
    );
  }

  @override
  String toString() => name;
}
