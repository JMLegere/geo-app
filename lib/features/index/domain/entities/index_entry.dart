import 'package:earth_nova/core/domain/content/base_item_content.dart';
import 'package:earth_nova/core/domain/content/content_version_id.dart';
import 'package:earth_nova/core/domain/content/exact_version_ref.dart';
import 'package:earth_nova/core/domain/content/stable_content_id.dart';
import 'package:earth_nova/core/domain/entities/item.dart';

/// Why a stable Base Item first became known to the player.
enum DiscoveryProvenance {
  legacyBackfill('legacy_backfill'),
  explicitIdentification('explicit_identification'),
  automaticIdentification('automatic_identification');

  const DiscoveryProvenance(this.wireValue);

  final String wireValue;

  static DiscoveryProvenance fromWireValue(String value) {
    for (final provenance in values) {
      if (provenance.wireValue == value) return provenance;
    }
    throw ArgumentError.value(value, 'value', 'is not a known provenance');
  }
}

/// One immutable, stable Base Item entry in the player's Item Index.
///
/// [firstVersion] is the exact authored Version bound when the discovery was
/// first recorded. It intentionally never resolves a current Version and has
/// no Pack Item or Property Value linkage.
final class IndexEntry {
  factory IndexEntry({
    required StableContentId<BaseItemContent> baseItemId,
    required ItemCategory category,
    required String firstIdentifiedItemId,
    required ExactVersionRef<BaseItemContent> firstVersion,
    required String displayName,
    required String? scientificName,
    required DiscoveryProvenance discoveryProvenance,
    required DateTime discoveredAt,
  }) {
    if (firstVersion.stableId != baseItemId) {
      throw ArgumentError.value(
        firstVersion,
        'firstVersion',
        'must belong to baseItemId',
      );
    }
    return IndexEntry._(
      baseItemId: baseItemId,
      category: category,
      firstIdentifiedItemId: _nonBlank(
        firstIdentifiedItemId,
        'firstIdentifiedItemId',
      ),
      firstVersion: firstVersion,
      displayName: _nonBlank(displayName, 'displayName'),
      scientificName: _nullableNonBlank(scientificName, 'scientificName'),
      discoveryProvenance: discoveryProvenance,
      discoveredAt: discoveredAt.toUtc(),
    );
  }

  const IndexEntry._({
    required this.baseItemId,
    required this.category,
    required this.firstIdentifiedItemId,
    required this.firstVersion,
    required this.displayName,
    required this.scientificName,
    required this.discoveryProvenance,
    required this.discoveredAt,
  });

  final StableContentId<BaseItemContent> baseItemId;
  final ItemCategory category;
  final String firstIdentifiedItemId;
  final ExactVersionRef<BaseItemContent> firstVersion;
  final String displayName;
  final String? scientificName;
  final DiscoveryProvenance discoveryProvenance;
  final DateTime discoveredAt;

  /// The exact Version id retained with this first discovery.
  ContentVersionId<BaseItemContent> get firstVersionId =>
      firstVersion.versionId;

  /// The exact positive revision retained with this first discovery.
  int get firstRevision => firstVersion.revision;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IndexEntry &&
          baseItemId == other.baseItemId &&
          category == other.category &&
          firstIdentifiedItemId == other.firstIdentifiedItemId &&
          firstVersion == other.firstVersion &&
          displayName == other.displayName &&
          scientificName == other.scientificName &&
          discoveryProvenance == other.discoveryProvenance &&
          discoveredAt == other.discoveredAt;

  @override
  int get hashCode => Object.hash(
        baseItemId,
        category,
        firstIdentifiedItemId,
        firstVersion,
        displayName,
        scientificName,
        discoveryProvenance,
        discoveredAt,
      );
}

String _nonBlank(String value, String name) {
  final canonical = value.trim();
  if (canonical.isEmpty) {
    throw ArgumentError.value(value, name, 'must not be blank');
  }
  return canonical;
}

String? _nullableNonBlank(String? value, String name) =>
    value == null ? null : _nonBlank(value, name);
