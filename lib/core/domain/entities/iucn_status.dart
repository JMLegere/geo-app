enum IucnStatus {
  leastConcern('LC', 'Least Concern'),
  nearThreatened('NT', 'Near Threatened'),
  vulnerable('VU', 'Vulnerable'),
  endangered('EN', 'Endangered'),
  criticallyEndangered('CR', 'Critically Endangered'),
  extinct('EX', 'Extinct');

  const IucnStatus(this.code, this.displayName);

  final String code;
  final String displayName;

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
