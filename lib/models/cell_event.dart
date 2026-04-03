import 'package:flutter/foundation.dart';

/// Rotating daily event type that can occur on a cell.
enum CellEventType {
  migration,
  nestingSite;

  String get displayName => switch (this) {
        CellEventType.migration => 'Migration',
        CellEventType.nestingSite => 'Nesting Site',
      };

  static CellEventType fromString(String value) {
    return CellEventType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => throw ArgumentError('Unknown CellEventType: $value'),
    );
  }

  @override
  String toString() => name;
}

/// Rotating daily event on a cell. Deterministic from dailySeed + cellId.
/// NOT persisted — recomputed on demand from the daily seed.
///
/// Same cell + same daily seed = same event type.
/// Different day = different daily seed = different event for same cell.
@immutable
class CellEvent {
  final CellEventType type;
  final String cellId;
  final String dailySeed;

  const CellEvent({
    required this.type,
    required this.cellId,
    required this.dailySeed,
  });

  CellEvent copyWith({
    CellEventType? type,
    String? cellId,
    String? dailySeed,
  }) {
    return CellEvent(
      type: type ?? this.type,
      cellId: cellId ?? this.cellId,
      dailySeed: dailySeed ?? this.dailySeed,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'cellId': cellId,
      'dailySeed': dailySeed,
    };
  }

  static CellEvent fromJson(Map<String, dynamic> json) {
    return CellEvent(
      type: CellEventType.fromString(json['type'] as String),
      cellId: json['cellId'] as String,
      dailySeed: json['dailySeed'] as String,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is CellEvent &&
        other.type == type &&
        other.cellId == cellId &&
        other.dailySeed == dailySeed;
  }

  @override
  int get hashCode {
    return Object.hash(type, cellId, dailySeed);
  }

  @override
  String toString() {
    return 'CellEvent(type: $type, cellId: $cellId, dailySeed: $dailySeed)';
  }
}
