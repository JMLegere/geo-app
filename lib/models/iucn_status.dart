/// IUCN conservation status — used for rarity display in the pack.
enum IucnStatus {
  leastConcern('LC', 'Least Concern'),
  nearThreatened('NT', 'Near Threatened'),
  vulnerable('VU', 'Vulnerable'),
  endangered('EN', 'Endangered'),
  criticallyEndangered('CR', 'Critically Endangered'),
  extinct('EX', 'Extinct');

  const IucnStatus(this.code, this.displayName);

  /// Short code for badge labels (e.g. "LC", "EN").
  final String code;

  /// Full display name (e.g. "Least Concern").
  final String displayName;

  /// Parse from a string (case-insensitive). Returns null if unknown.
  static IucnStatus? fromString(String? value) {
    if (value == null) return null;
    for (final status in IucnStatus.values) {
      if (status.name.toLowerCase() == value.toLowerCase() ||
          status.code.toLowerCase() == value.toLowerCase()) {
        return status;
      }
    }
    return null;
  }
}
