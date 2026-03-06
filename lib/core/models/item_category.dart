/// The 5 item categories in EarthNova.
///
/// Every discoverable thing is an item. Categories group item definitions
/// by their real-world origin.
enum ItemCategory {
  fauna,
  flora,
  mineral,
  fossil,
  artifact;

  String get displayName => switch (this) {
        ItemCategory.fauna => 'Fauna',
        ItemCategory.flora => 'Flora',
        ItemCategory.mineral => 'Mineral',
        ItemCategory.fossil => 'Fossil',
        ItemCategory.artifact => 'Artifact',
      };

  static ItemCategory fromString(String value) {
    return ItemCategory.values.firstWhere(
      (c) => c.name == value,
      orElse: () => throw ArgumentError('Unknown ItemCategory: $value'),
    );
  }

  @override
  String toString() => name;
}
