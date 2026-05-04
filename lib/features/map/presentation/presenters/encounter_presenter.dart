import 'package:earth_nova/features/map/domain/entities/encounter.dart';

class EncounterPresenter {
  const EncounterPresenter._();

  static String message(Encounter encounter) {
    return switch (encounter.type) {
      EncounterType.species =>
        'You found a ${friendlySpeciesName(encounter.speciesId)}',
      EncounterType.critter => 'A critter appeared',
      EncounterType.loot => 'You found supplies',
    };
  }

  static String friendlySpeciesName(String speciesId) {
    final cleaned = speciesId
        .replaceFirst(RegExp(r'^species[_-]?', caseSensitive: false), '')
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .trim();

    if (cleaned.isEmpty) return 'New Species';
    if (!_looksLikeHash(cleaned)) return _titleCase(cleaned);

    final hash = _stableHash(speciesId);
    final adjective = _adjectives[hash % _adjectives.length];
    final noun = _nouns[(hash ~/ _adjectives.length) % _nouns.length];
    return '$adjective $noun';
  }

  static bool _looksLikeHash(String value) {
    final compact = value.replaceAll(' ', '');
    if (compact.length < 8) return false;
    return RegExp(r'^[0-9a-fA-F]+$').hasMatch(compact);
  }

  static String _titleCase(String value) {
    return value
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part.length == 1
            ? part.toUpperCase()
            : '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
        .join(' ');
  }

  static int _stableHash(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }

  static const _adjectives = [
    'Amberwing',
    'Ferncrest',
    'Frostcap',
    'Mossback',
    'Riverglade',
    'Stonebloom',
    'Sunspotted',
    'Willowshade',
  ];

  static const _nouns = [
    'Finch',
    'Hare',
    'Moth',
    'Newt',
    'Vole',
    'Warbler',
    'Beetle',
    'Fox',
  ];
}
