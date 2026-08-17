import 'dart:convert';

import 'package:earth_nova/core/domain/entities/item.dart';

class ItemDto {
  const ItemDto({
    required this.id,
    this.definitionId,
    this.baseItemId,
    this.baseItemVersionId,
    required this.displayName,
    this.scientificName,
    required this.category,
    this.rarity,
    this.iconUrl,
    this.iconUrlFrame2,
    this.artUrl,
    required this.acquiredAt,
    this.acquiredInCellId,
    required this.status,
    this.taxonomicClass,
    this.habitats = const [],
    this.continents = const [],
    this.identificationState = 'identified',
    String? examinationState,
    this.examinedAt,
    this.identifiedAt,
    this.identifiedDisplayName,
    this.identifiedScientificName,
    this.identifiedTaxonomicClass,
    this.identifiedHabitats = const [],
    this.identifiedContinents = const [],
  }) : examinationState = identificationState == 'identified'
            ? 'examined'
            : examinationState ?? 'unexamined';

  final String id;
  final String? definitionId;
  final String? baseItemId;
  final String? baseItemVersionId;
  final String displayName;
  final String? scientificName;
  final String category;
  final String? rarity;
  final String? iconUrl;
  final String? iconUrlFrame2;
  final String? artUrl;
  final DateTime acquiredAt;
  final String? acquiredInCellId;
  final String status;
  final String? taxonomicClass;
  final List<String> habitats;
  final List<String> continents;
  final String identificationState;
  final String examinationState;
  final DateTime? examinedAt;
  final DateTime? identifiedAt;
  final String? identifiedDisplayName;
  final String? identifiedScientificName;
  final String? identifiedTaxonomicClass;
  final List<String> identifiedHabitats;
  final List<String> identifiedContinents;

  factory ItemDto.fromJson(Map<String, dynamic> json) {
    final identificationState = ItemIdentificationState.fromString(
      json['identification_state'] as String?,
    ).name;
    final isUnidentified = identificationState == 'unidentified';
    final requestedExaminationState = json['examination_state'] as String?;
    final examinationState = identificationState == 'identified'
        ? 'examined'
        : requestedExaminationState == null
            ? 'unexamined'
            : ItemExaminationState.fromString(requestedExaminationState).name;
    final isUnexamined = examinationState == 'unexamined';
    final category = json['category'] as String? ?? 'fauna';

    if (isUnexamined) {
      _requireMaskedIdentity(json);
    } else if (isUnidentified) {
      _requireMaskedIdentificationProperties(json);
    }

    return ItemDto(
      id: _requiredNonBlankText(json['id'], 'id'),
      baseItemId: isUnexamined
          ? null
          : _requiredNonBlankText(json['base_item_id'], 'base_item_id'),
      baseItemVersionId: isUnexamined
          ? null
          : _requiredUuid(json['base_item_version_id'], 'base_item_version_id'),
      definitionId: isUnexamined
          ? null
          : _requiredNonBlankText(json['definition_id'], 'definition_id'),
      displayName: isUnexamined
          ? _requiredNonBlankText(json['display_name'], 'display_name')
          : (json['display_name'] as String? ??
              _requiredNonBlankText(json['definition_id'], 'definition_id')),
      scientificName:
          isUnexamined ? null : _nullableText(json['scientific_name']),
      category: category,
      rarity: isUnexamined ? null : _nullableText(json['rarity']),
      iconUrl: isUnexamined ? null : _nullableText(json['icon_url']),
      iconUrlFrame2:
          isUnexamined ? null : _nullableText(json['icon_url_frame2']),
      artUrl: isUnexamined ? null : _nullableText(json['art_url']),
      acquiredAt: DateTime.parse(_requiredNonBlankText(
        json['acquired_at'],
        'acquired_at',
      )),
      acquiredInCellId: _nullableText(json['acquired_in_cell_id']),
      status: json['status'] as String? ?? 'active',
      taxonomicClass:
          isUnexamined ? null : _nullableText(json['taxonomic_class']),
      habitats: isUnexamined
          ? const []
          : _parseJsonArray(json['habitats_json'] as String?),
      continents: isUnexamined
          ? const []
          : _parseJsonArray(json['continents_json'] as String?),
      identificationState: identificationState,
      examinationState: examinationState,
      examinedAt: isUnexamined || json['examined_at'] == null
          ? null
          : DateTime.parse(json['examined_at'] as String),
      identifiedAt: isUnidentified || json['identified_at'] == null
          ? null
          : DateTime.parse(json['identified_at'] as String),
      identifiedDisplayName: isUnidentified
          ? null
          : _nullableText(json['identified_display_name']),
      identifiedScientificName: isUnidentified
          ? null
          : _nullableText(json['identified_scientific_name']),
      identifiedTaxonomicClass: isUnidentified
          ? null
          : _nullableText(json['identified_taxonomic_class']),
      identifiedHabitats: isUnidentified
          ? const []
          : _parseJsonArray(json['identified_habitats_json'] as String?),
      identifiedContinents: isUnidentified
          ? const []
          : _parseJsonArray(json['identified_continents_json'] as String?),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'definition_id': definitionId,
        'base_item_id': baseItemId,
        'base_item_version_id': baseItemVersionId,
        'display_name': displayName,
        'scientific_name': scientificName,
        'category': category,
        'rarity': rarity,
        'icon_url': iconUrl,
        'icon_url_frame2': iconUrlFrame2,
        'art_url': artUrl,
        'acquired_at': acquiredAt.toIso8601String(),
        'acquired_in_cell_id': acquiredInCellId,
        'status': status,
        'taxonomic_class': taxonomicClass,
        'habitats_json': jsonEncode(habitats),
        'continents_json': jsonEncode(continents),
        'identification_state': identificationState,
        'examination_state': examinationState,
        'examined_at': examinedAt?.toIso8601String(),
        'identified_at': identifiedAt?.toIso8601String(),
        'identified_display_name': identifiedDisplayName,
        'identified_scientific_name': identifiedScientificName,
        'identified_taxonomic_class': identifiedTaxonomicClass,
        'identified_habitats_json': jsonEncode(identifiedHabitats),
        'identified_continents_json': jsonEncode(identifiedContinents),
      };

  Item toDomain() => Item(
        id: id,
        definitionId: definitionId,
        baseItemId: baseItemId,
        baseItemVersionId: baseItemVersionId,
        displayName: displayName,
        scientificName: scientificName,
        category: ItemCategory.fromString(category),
        rarity: rarity,
        iconUrl: iconUrl,
        iconUrlFrame2: iconUrlFrame2,
        artUrl: artUrl,
        acquiredAt: acquiredAt,
        acquiredInCellId: acquiredInCellId,
        status: ItemStatus.fromString(status),
        taxonomicClass: taxonomicClass,
        habitats: habitats,
        continents: continents,
        identificationState:
            ItemIdentificationState.fromString(identificationState),
        identifiedAt: identifiedAt,
        examinationState: ItemExaminationState.fromString(examinationState),
        examinedAt: examinedAt,
        identifiedDisplayName: identifiedDisplayName,
        identifiedScientificName: identifiedScientificName,
        identifiedTaxonomicClass: identifiedTaxonomicClass,
        identifiedHabitats: identifiedHabitats,
        identifiedContinents: identifiedContinents,
      );

  factory ItemDto.fromDomain(Item item) => ItemDto(
        id: item.id,
        definitionId: item.definitionId,
        baseItemId: item.baseItemId,
        baseItemVersionId: item.baseItemVersionId,
        displayName: item.displayName,
        scientificName: item.scientificName,
        category: item.category.name,
        rarity: item.rarity,
        iconUrl: item.iconUrl,
        iconUrlFrame2: item.iconUrlFrame2,
        artUrl: item.artUrl,
        acquiredAt: item.acquiredAt,
        acquiredInCellId: item.acquiredInCellId,
        status: item.status.name,
        taxonomicClass: item.taxonomicClass,
        habitats: item.habitats,
        continents: item.continents,
        identificationState: item.identificationState.name,
        examinationState: item.examinationState.name,
        examinedAt: item.examinedAt,
        identifiedAt: item.identifiedAt,
        identifiedDisplayName: item.identifiedDisplayName,
        identifiedScientificName: item.identifiedScientificName,
        identifiedTaxonomicClass: item.identifiedTaxonomicClass,
        identifiedHabitats: item.identifiedHabitats,
        identifiedContinents: item.identifiedContinents,
      );
}

List<String> _parseJsonArray(String? json) {
  if (json == null || json.isEmpty || json == '[]') return const [];
  try {
    return List<String>.from(jsonDecode(json) as List);
  } catch (_) {
    return const [];
  }
}

String? _nullableText(Object? value) {
  if (value == null) return null;
  if (value is! String) {
    throw FormatException('Optional Item text must be a string when present.');
  }
  return value;
}

void _requireMaskedIdentity(Map<String, dynamic> json) {
  const hiddenFields = <String>[
    'definition_id',
    'base_item_id',
    'base_item_version_id',
    'scientific_name',
    'rarity',
    'icon_url',
    'icon_url_frame2',
    'art_url',
    'taxonomic_class',
    'habitats_json',
    'continents_json',
    'identified_at',
    'identified_display_name',
    'identified_scientific_name',
    'identified_taxonomic_class',
    'identified_habitats_json',
    'identified_continents_json',
  ];

  for (final field in hiddenFields) {
    if (json[field] != null) {
      throw FormatException(
        'Unidentified Item response must not expose $field.',
      );
    }
  }
}

void _requireMaskedIdentificationProperties(Map<String, dynamic> json) {
  const hiddenFields = <String>[
    'identified_at',
    'identified_display_name',
    'identified_scientific_name',
    'identified_taxonomic_class',
    'identified_habitats_json',
    'identified_continents_json',
  ];

  for (final field in hiddenFields) {
    if (json[field] != null) {
      throw FormatException(
        'Unidentified Item response must not expose $field.',
      );
    }
  }
}

String _requiredNonBlankText(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$field must be a nonblank string.');
  }
  return value;
}

String _requiredUuid(Object? value, String field) {
  final text = _requiredNonBlankText(value, field);
  if (!_uuidPattern.hasMatch(text)) {
    throw FormatException('$field must be a UUID.');
  }
  return text;
}

final _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
