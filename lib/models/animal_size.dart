/// Physical size category for fauna species.
///
/// AI-enriched on first global discovery. Each category defines a weight
/// range in grams; per-instance weight is rolled randomly within that range.
///
/// Ranges are contiguous and non-overlapping (each maxGrams = next minGrams - 1).
enum AnimalSize {
  /// Insects, tiny invertebrates. < 50 g.
  fine(minGrams: 1, maxGrams: 49),

  /// Small insects, frogs, mice. 50 g - 500 g.
  diminutive(minGrams: 50, maxGrams: 499),

  /// Squirrels, rats, small birds. 500 g - 4 kg.
  tiny(minGrams: 500, maxGrams: 3999),

  /// Foxes, rabbits, medium dogs. 4 - 25 kg.
  small(minGrams: 4000, maxGrams: 24999),

  /// Wolves, large cats, deer. 25 - 150 kg.
  medium(minGrams: 25000, maxGrams: 149999),

  /// Bears, big cats, large ungulates. 150 - 500 kg.
  large(minGrams: 150000, maxGrams: 499999),

  /// Rhinos, hippos, small cetaceans. 500 - 2,000 kg.
  huge(minGrams: 500000, maxGrams: 1999999),

  /// Elephants, large cetaceans. 2 - 15 t.
  gargantuan(minGrams: 2000000, maxGrams: 14999999),

  /// Blue whales, colossal marine life. 15+ t (capped at 247 t).
  /// Upper bound = 130% of heaviest blue whale on record (~190 t).
  colossal(minGrams: 15000000, maxGrams: 247000000);

  const AnimalSize({required this.minGrams, required this.maxGrams});

  /// Inclusive lower bound of the weight range in grams.
  final int minGrams;

  /// Inclusive upper bound of the weight range in grams.
  final int maxGrams;

  /// Number of possible weight values in this size band.
  int get rangeSpan => maxGrams - minGrams + 1;

  /// Parse from string (enum name). Throws on unknown value.
  static AnimalSize fromString(String value) {
    return AnimalSize.values.firstWhere(
      (s) => s.name == value,
      orElse: () => throw ArgumentError('Unknown AnimalSize: $value'),
    );
  }

  @override
  String toString() => name;
}
