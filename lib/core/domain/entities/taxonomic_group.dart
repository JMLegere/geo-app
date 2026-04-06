enum TaxonomicGroup {
  mammals('Mammals'),
  birds('Birds'),
  reptiles('Reptiles'),
  amphibians('Amphibians'),
  fish('Fish'),
  invertebrates('Invertebrates'),
  other('Other');

  const TaxonomicGroup(this.label);

  final String label;

  static TaxonomicGroup fromTaxonomicClass(String? cls) {
    if (cls == null || cls.isEmpty) return other;
    return switch (cls.toUpperCase()) {
      'MAMMALIA' => mammals,
      'AVES' => birds,
      'REPTILIA' => reptiles,
      'AMPHIBIA' => amphibians,
      'ACTINOPTERYGII' ||
      'CHONDRICHTHYES' ||
      'SARCOPTERYGII' ||
      'MYXINI' ||
      'CEPHALASPIDOMORPHI' =>
        fish,
      'INSECTA' ||
      'GASTROPODA' ||
      'MALACOSTRACA' ||
      'BIVALVIA' ||
      'DIPLOPODA' ||
      'CEPHALOPODA' ||
      'ARACHNIDA' ||
      'ANTHOZOA' ||
      'CLITELLATA' ||
      'HOLOTHUROIDEA' ||
      'BRANCHIOPODA' ||
      'UDEONYCHOPHORA' ||
      'CHILOPODA' ||
      'ENOPLA' ||
      'MEROSTOMATA' ||
      'HYDROZOA' =>
        invertebrates,
      _ => other,
    };
  }
}
