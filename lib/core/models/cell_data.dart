import 'package:flutter/foundation.dart';
import 'package:geobase/geobase.dart';
import 'fog_state.dart';

class CellData {
  final String id;
  final Geographic center;
  final FogState fogState;
  final List<String> speciesIds;
  final double restorationLevel;
  final double distanceWalked;
  final int visitCount;
  final DateTime? lastVisited;

  CellData({
    required this.id,
    required this.center,
    required this.fogState,
    required this.speciesIds,
    required double restorationLevel,
    required this.distanceWalked,
    required this.visitCount,
    required this.lastVisited,
  }) : restorationLevel = restorationLevel.clamp(0.0, 1.0);

  CellData copyWith({
    String? id,
    Geographic? center,
    FogState? fogState,
    List<String>? speciesIds,
    double? restorationLevel,
    double? distanceWalked,
    int? visitCount,
    DateTime? lastVisited,
  }) {
    return CellData(
      id: id ?? this.id,
      center: center ?? this.center,
      fogState: fogState ?? this.fogState,
      speciesIds: speciesIds ?? this.speciesIds,
      restorationLevel: restorationLevel ?? this.restorationLevel,
      distanceWalked: distanceWalked ?? this.distanceWalked,
      visitCount: visitCount ?? this.visitCount,
      lastVisited: lastVisited ?? this.lastVisited,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'center': {
        'lat': center.lat,
        'lon': center.lon,
      },
      'fogState': fogState.name,
      'speciesIds': speciesIds,
      'restorationLevel': restorationLevel,
      'distanceWalked': distanceWalked,
      'visitCount': visitCount,
      'lastVisited': lastVisited?.toIso8601String(),
    };
  }

  static CellData fromJson(Map<String, dynamic> json) {
    return CellData(
      id: json['id'] as String,
      center: Geographic(
        lat: (json['center']['lat'] as num).toDouble(),
        lon: (json['center']['lon'] as num).toDouble(),
      ),
      fogState: FogState.fromString(json['fogState'] as String),
      speciesIds: List<String>.from(json['speciesIds'] as List),
      restorationLevel: (json['restorationLevel'] as num).toDouble(),
      distanceWalked: (json['distanceWalked'] as num).toDouble(),
      visitCount: json['visitCount'] as int,
      lastVisited: json['lastVisited'] != null
          ? DateTime.parse(json['lastVisited'] as String)
          : null,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is CellData &&
        other.id == id &&
        other.center.lat == center.lat &&
        other.center.lon == center.lon &&
        other.fogState == fogState &&
        listEquals(other.speciesIds, speciesIds) &&
        other.restorationLevel == restorationLevel &&
        other.distanceWalked == distanceWalked &&
        other.visitCount == visitCount &&
        other.lastVisited == lastVisited;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      center.lat,
      center.lon,
      fogState,
      speciesIds,
      restorationLevel,
      distanceWalked,
      visitCount,
      lastVisited,
    );
  }

  @override
  String toString() {
    return 'CellData(id: $id, center: $center, fogState: $fogState, '
        'speciesIds: $speciesIds, restorationLevel: $restorationLevel, '
        'distanceWalked: $distanceWalked, visitCount: $visitCount, '
        'lastVisited: $lastVisited)';
  }
}
