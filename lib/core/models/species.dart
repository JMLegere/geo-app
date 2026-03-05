import 'continent.dart';
import 'habitat.dart';
import 'iucn_status.dart';

/// A species from the IUCN dataset (static seed data).
/// This is loaded from assets/species_data.json at startup.
class SpeciesRecord {
  final String commonName;
  final String scientificName;
  final String taxonomicClass;
  final List<Continent> continents;
  final List<Habitat> habitats;
  final IucnStatus iucnStatus;

  const SpeciesRecord({
    required this.commonName,
    required this.scientificName,
    required this.taxonomicClass,
    required this.continents,
    required this.habitats,
    required this.iucnStatus,
  });

  /// Unique ID derived from scientific name (stable, deterministic).
  String get id => scientificName.toLowerCase().replaceAll(' ', '_');

  factory SpeciesRecord.fromJson(Map<String, dynamic> json) {
    return SpeciesRecord(
      commonName: json['commonName'] as String,
      scientificName: json['scientificName'] as String,
      taxonomicClass: json['taxonomicClass'] as String,
      continents: (json['continents'] as List)
          .map((c) => Continent.fromDataString(c as String))
          .toList(),
      habitats: (json['habitats'] as List)
          .map((h) => Habitat.fromString((h as String).toLowerCase()))
          .toList(),
      iucnStatus: IucnStatus.fromIucnString(json['iucnStatus'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'commonName': commonName,
    'scientificName': scientificName,
    'taxonomicClass': taxonomicClass,
    'continents': continents.map((c) => c.displayName).toList(),
    'habitats': habitats.map((h) => h.displayName).toList(),
    'iucnStatus': iucnStatus.displayName,
  };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SpeciesRecord &&
        other.scientificName == scientificName;
  }

  @override
  int get hashCode => scientificName.hashCode;

  @override
  String toString() =>
      'SpeciesRecord(id: $id, commonName: $commonName, '
      'scientificName: $scientificName, iucnStatus: $iucnStatus)';
}

/// A species the player has collected (mutable state, persisted).
class CollectedSpecies {
  final String speciesId; // matches SpeciesRecord.id
  final DateTime collectedAt;
  final String cellId; // where it was collected

  const CollectedSpecies({
    required this.speciesId,
    required this.collectedAt,
    required this.cellId,
  });
}
