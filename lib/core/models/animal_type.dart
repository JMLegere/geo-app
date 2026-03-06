
/// 5 animal types derived deterministically from IUCN taxonomicClass.
enum AnimalType {
  mammal,
  bird,
  fish,
  reptile,
  bug;

  String get displayName => switch (this) {
        AnimalType.mammal => 'Mammal',
        AnimalType.bird => 'Bird',
        AnimalType.fish => 'Fish',
        AnimalType.reptile => 'Reptile',
        AnimalType.bug => 'Bug',
      };

  /// Deterministic mapping from IUCN taxonomicClass string.
  /// Returns null for unrecognized classes.
  static AnimalType? fromTaxonomicClass(String taxonomicClass) {
    return switch (taxonomicClass) {
      'MAMMALIA' || 'Mammalia' => AnimalType.mammal,
      'AVES' || 'Aves' => AnimalType.bird,
      'ACTINOPTERYGII' ||
      'Actinopterygii' ||
      'CHONDRICHTHYES' ||
      'Chondrichthyes' ||
      'CEPHALASPIDOMORPHI' ||
      'Cephalaspidomorphi' ||
      'MYXINI' ||
      'Myxini' ||
      'SARCOPTERYGII' ||
      'Sarcopterygii' =>
        AnimalType.fish,
      'REPTILIA' ||
      'Reptilia' ||
      'AMPHIBIA' ||
      'Amphibia' =>
        AnimalType.reptile,
      'INSECTA' ||
      'Insecta' ||
      'ARACHNIDA' ||
      'Arachnida' ||
      'GASTROPODA' ||
      'Gastropoda' ||
      'MALACOSTRACA' ||
      'Malacostraca' ||
      'CHILOPODA' ||
      'Chilopoda' ||
      'DIPLOPODA' ||
      'Diplopoda' ||
      // Invertebrates without a closer match — mapped to bug
      'BIVALVIA' ||
      'Bivalvia' ||
      'ANTHOZOA' ||
      'Anthozoa' ||
      'CLITELLATA' ||
      'Clitellata' ||
      'HOLOTHUROIDEA' ||
      'Holothuroidea' ||
      'BRANCHIOPODA' ||
      'Branchiopoda' ||
      'UDEONYCHOPHORA' ||
      'Udeonychophora' ||
      'ENOPLA' ||
      'Enopla' ||
      'HYDROZOA' ||
      'Hydrozoa' ||
      'MEROSTOMATA' ||
      'Merostomata' =>
        AnimalType.bug,
      // Cephalopoda → fish (matches AnimalClass.cephalopod)
      'CEPHALOPODA' ||
      'Cephalopoda' =>
        AnimalType.fish,
      _ => null,
    };
  }

  static AnimalType fromString(String value) {
    return AnimalType.values.firstWhere(
      (t) => t.name == value,
      orElse: () => throw ArgumentError('Unknown AnimalType: $value'),
    );
  }

  @override
  String toString() => name;
}
