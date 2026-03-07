import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'affix.dart';

/// A unique discovered item. Every discovery creates a new instance.
///
/// PoE / CryptoKitty model: no stacking. Two Red Foxes found in different
/// cells have different randomly-rolled affixes. Each instance has its own
/// UUID.
///
/// Lifecycle: active → donated | placed | released | traded.
@immutable
class ItemInstance {
  /// Globally unique ID (UUID v4).
  final String id;

  /// References [ItemDefinition.id] — the static blueprint for this item.
  final String definitionId;

  /// Item modifiers: one intrinsic (base stats) + rolled prefix/suffix.
  ///
  /// Every wild-caught instance has exactly one [AffixType.intrinsic] affix
  /// containing speed, brawn, and wit stats.
  /// Rarity gates prefix/suffix pool depth: LC=0-1, NT=1-2, VU=2-3, EN=3-4, CR=4-5, EX=5+.
  final List<Affix> affixes;

  /// Instance-level badges / flags assigned at creation time.
  ///
  /// Badges are simple string identifiers (e.g. 'first_discovery', 'beta',
  /// 'pioneer', 'art_winner'). They grant visual treatment (borders, icons)
  /// but carry no stat values — that's what [affixes] are for.
  ///
  /// Stored as a JSON array in the database.
  final Set<String> badges;

  /// Null for wild-caught. Set for bred offspring.
  final String? parentAId;

  /// Null for wild-caught. Set for bred offspring.
  final String? parentBId;

  /// When the player acquired this item.
  final DateTime acquiredAt;

  /// Cell where this item was found. Null for bred items.
  final String? acquiredInCellId;

  /// Daily seed used for this roll (for server-side re-derivation).
  final String? dailySeed;

  /// Current lifecycle status.
  final ItemInstanceStatus status;

  const ItemInstance({
    required this.id,
    required this.definitionId,
    this.affixes = const [],
    this.badges = const {},
    this.parentAId,
    this.parentBId,
    required this.acquiredAt,
    this.acquiredInCellId,
    this.dailySeed,
    this.status = ItemInstanceStatus.active,
  });

  /// Whether this item was caught in the wild (not bred).
  bool get isWildCaught => parentAId == null && parentBId == null;

  /// Whether this item was bred from two parents.
  bool get isBred => parentAId != null && parentBId != null;

  /// Whether this instance has the first-discovery badge (shiny foil).
  bool get isFirstDiscovery => badges.contains('first_discovery');

  // TODO(phase5): copyWith cannot null out optional fields (parentAId,
  // parentBId, acquiredInCellId, dailySeed). When breeding needs to clear
  // parentage, adopt a sentinel pattern (e.g. Value<T> wrappers or
  // nullable Function() closures).
  ItemInstance copyWith({
    String? id,
    String? definitionId,
    List<Affix>? affixes,
    Set<String>? badges,
    String? parentAId,
    String? parentBId,
    DateTime? acquiredAt,
    String? acquiredInCellId,
    String? dailySeed,
    ItemInstanceStatus? status,
  }) {
    return ItemInstance(
      id: id ?? this.id,
      definitionId: definitionId ?? this.definitionId,
      affixes: affixes ?? this.affixes,
      badges: badges ?? this.badges,
      parentAId: parentAId ?? this.parentAId,
      parentBId: parentBId ?? this.parentBId,
      acquiredAt: acquiredAt ?? this.acquiredAt,
      acquiredInCellId: acquiredInCellId ?? this.acquiredInCellId,
      dailySeed: dailySeed ?? this.dailySeed,
      status: status ?? this.status,
    );
  }

  /// Serialize affixes list to JSON string for database storage.
  String affixesToJson() => jsonEncode(affixes.map((a) => a.toJson()).toList());

  /// Deserialize affixes list from JSON string (database storage).
  static List<Affix> affixesFromJson(String json) {
    final list = jsonDecode(json) as List;
    return list.map((a) => Affix.fromJson(a as Map<String, dynamic>)).toList();
  }

  /// Serialize badges set to JSON string for database storage.
  String badgesToJson() => jsonEncode(badges.toList());

  /// Deserialize badges set from JSON string (database storage).
  static Set<String> badgesFromJson(String json) {
    final list = jsonDecode(json) as List;
    return list.cast<String>().toSet();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ItemInstance && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ItemInstance(id: $id, definitionId: $definitionId, '
      'affixes: ${affixes.length}, status: $status)';
}

/// Lifecycle status of an item instance.
enum ItemInstanceStatus {
  /// In player's active inventory.
  active,

  /// Permanently donated to museum.
  donated,

  /// Placed in sanctuary.
  placed,

  /// Released back to the wild.
  released,

  /// Traded to another player.
  traded;

  static ItemInstanceStatus fromString(String value) {
    return ItemInstanceStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => throw ArgumentError('Unknown ItemInstanceStatus: $value'),
    );
  }

  @override
  String toString() => name;
}
