import 'package:earth_nova/core/domain/content/base_item_content.dart';
import 'package:earth_nova/core/domain/content/content_version_id.dart';
import 'package:earth_nova/core/domain/content/exact_version_ref.dart';
import 'package:earth_nova/core/domain/content/stable_content_id.dart';
import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/features/index/domain/entities/index_entry.dart';
import 'package:earth_nova/features/index/domain/repositories/item_index_repository.dart';

/// Strict parser for the frozen `fetch_v3_item_index()` response.
///
/// The projection is untrusted at this boundary. Parsing either returns the
/// complete ordered stable-index aggregate or throws a safe failure; it never
/// manufactures partial entries from Pack Items or current Base Item Versions.
final class ItemIndexDto {
  const ItemIndexDto._(this._entries);

  final List<IndexEntry> _entries;

  factory ItemIndexDto.fromJson(Object? json) {
    try {
      final response = _requiredObject(json, 'response');
      _requireExactKeys(response, const ['entries'], 'response');
      final values = _requiredList(response['entries'], 'entries');
      final entries = <IndexEntry>[];
      final ids = <String>{};
      IndexEntry? previous;

      for (var index = 0; index < values.length; index += 1) {
        final entry = _parseEntry(values[index], index);
        if (!ids.add(entry.baseItemId.value)) {
          throw const ItemIndexFailure.malformedPayload();
        }
        if (previous != null && !_isStrictlyAfter(previous, entry)) {
          throw const ItemIndexFailure.malformedPayload();
        }
        entries.add(entry);
        previous = entry;
      }
      return ItemIndexDto._(List<IndexEntry>.unmodifiable(entries));
    } on ItemIndexFailure {
      rethrow;
    } on ArgumentError {
      throw const ItemIndexFailure.malformedPayload();
    } on FormatException {
      throw const ItemIndexFailure.malformedPayload();
    } on TypeError {
      throw const ItemIndexFailure.malformedPayload();
    } on StateError {
      throw const ItemIndexFailure.malformedPayload();
    }
  }

  List<IndexEntry> toDomain() => _entries;
}

IndexEntry _parseEntry(Object? value, int index) {
  final json = _requiredObject(value, 'entries[$index]');
  _requireExactKeys(
    json,
    const [
      'base_item_id',
      'category',
      'first_identified_item_id',
      'base_item_version_id',
      'base_item_revision',
      'display_name',
      'scientific_name',
      'discovery_provenance',
      'discovered_at',
    ],
    'entries[$index]',
  );

  final baseItemId = StableContentId<BaseItemContent>(
    _requiredText(json['base_item_id']),
  );
  final firstVersion = ExactVersionRef<BaseItemContent>(
    stableId: baseItemId,
    versionId: ContentVersionId<BaseItemContent>(
      _requiredText(json['base_item_version_id']),
    ),
    revision: _requiredPositiveInt(json['base_item_revision']),
  );

  return IndexEntry(
    baseItemId: baseItemId,
    category: _category(json['category']),
    firstIdentifiedItemId: _requiredText(json['first_identified_item_id']),
    firstVersion: firstVersion,
    displayName: _requiredText(json['display_name']),
    scientificName: _nullableText(json['scientific_name']),
    discoveryProvenance: _provenance(json['discovery_provenance']),
    discoveredAt: _timestamp(json['discovered_at']),
  );
}

bool _isStrictlyAfter(IndexEntry previous, IndexEntry current) {
  final timeOrder = current.discoveredAt.compareTo(previous.discoveredAt);
  if (timeOrder != 0) return timeOrder < 0;
  return current.baseItemId.value.compareTo(previous.baseItemId.value) > 0;
}

Map<String, Object?> _requiredObject(Object? value, String field) {
  if (value is! Map) throw const ItemIndexFailure.malformedPayload();
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) throw const ItemIndexFailure.malformedPayload();
    result[entry.key as String] = entry.value;
  }
  return result;
}

List<Object?> _requiredList(Object? value, String field) {
  if (value is! List) throw const ItemIndexFailure.malformedPayload();
  return List<Object?>.unmodifiable(value);
}

void _requireExactKeys(
  Map<String, Object?> value,
  List<String> expected,
  String field,
) {
  if (value.length != expected.length ||
      value.keys.any((key) => !expected.contains(key))) {
    throw const ItemIndexFailure.malformedPayload();
  }
}

String _requiredText(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    throw const ItemIndexFailure.malformedPayload();
  }
  return value;
}

String? _nullableText(Object? value) {
  if (value == null) return null;
  return _requiredText(value);
}

int _requiredPositiveInt(Object? value) {
  if (value is! int || value <= 0) {
    throw const ItemIndexFailure.malformedPayload();
  }
  return value;
}

final _rfc3339Timestamp = RegExp(
  r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$',
);
DateTime _timestamp(Object? value) {
  if (value is! String ||
      value.trim().isEmpty ||
      !_rfc3339Timestamp.hasMatch(value)) {
    throw const ItemIndexFailure.malformedPayload();
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw const ItemIndexFailure.malformedPayload();
  return parsed.toUtc();
}

ItemCategory _category(Object? value) => switch (value) {
      'fauna' => ItemCategory.fauna,
      'flora' => ItemCategory.flora,
      'mineral' => ItemCategory.mineral,
      'fossil' => ItemCategory.fossil,
      'artifact' => ItemCategory.artifact,
      'food' => ItemCategory.food,
      'orb' => ItemCategory.orb,
      _ => throw const ItemIndexFailure.malformedPayload(),
    };

DiscoveryProvenance _provenance(Object? value) => switch (value) {
      'legacy_backfill' => DiscoveryProvenance.legacyBackfill,
      'explicit_identification' => DiscoveryProvenance.explicitIdentification,
      'automatic_identification' => DiscoveryProvenance.automaticIdentification,
      _ => throw const ItemIndexFailure.malformedPayload(),
    };
