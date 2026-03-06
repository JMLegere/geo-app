import 'package:flutter/foundation.dart';

/// PoE-style prefix/suffix modifier rolled on item discovery.
///
/// Affixes are CryptoKitty-style breeding traits — each item instance has
/// a unique set of affixes, and breeding combines traits from two parents.
///
/// The affix pool and stat values are TBD (Phase 5+). The schema supports
/// arbitrary key-value pairs via [values] so the stat system can evolve
/// without schema migrations.
@immutable
class Affix {
  /// Unique identifier for this affix type (e.g. "swift", "ancient").
  final String id;

  /// Whether this is a prefix or suffix.
  final AffixType type;

  /// Flexible stat payload. Keys and value types are affix-specific.
  ///
  /// Examples: `{"speed": 1.2}`, `{"element": "fire", "power": 3}`.
  final Map<String, dynamic> values;

  const Affix({
    required this.id,
    required this.type,
    this.values = const {},
  });

  factory Affix.fromJson(Map<String, dynamic> json) {
    return Affix(
      id: json['id'] as String,
      type: AffixType.fromString(json['type'] as String),
      values: (json['values'] as Map<String, dynamic>?) ?? const {},
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'values': values,
      };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Affix &&
        other.id == id &&
        other.type == type &&
        mapEquals(other.values, values);
  }

  @override
  int get hashCode => Object.hash(id, type);

  @override
  String toString() => 'Affix($type:$id)';
}

/// Whether an affix is a prefix or suffix.
enum AffixType {
  prefix,
  suffix;

  static AffixType fromString(String value) {
    return AffixType.values.firstWhere(
      (t) => t.name == value,
      orElse: () => throw ArgumentError('Unknown AffixType: $value'),
    );
  }

  @override
  String toString() => name;
}
