import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';

import 'package:earth_nova/core/database/app_database.dart';
import 'package:earth_nova/core/models/animal_class.dart';
import 'package:earth_nova/core/models/climate.dart';
import 'package:earth_nova/core/models/food_type.dart';

@immutable
class SpeciesEnrichment {
  SpeciesEnrichment({
    required this.definitionId,
    required this.animalClass,
    required this.foodPreference,
    required this.climate,
    required this.brawn,
    required this.wit,
    required this.speed,
    this.artUrl,
    required this.enrichedAt,
  }) {
    if (brawn + wit + speed != 90) {
      throw ArgumentError(
        'brawn + wit + speed must equal 90, got ${brawn + wit + speed}',
      );
    }
  }

  final String definitionId;
  final AnimalClass animalClass;
  final FoodType foodPreference;
  final Climate climate;
  final int brawn;
  final int wit;
  final int speed;
  final String? artUrl;
  final DateTime enrichedAt;

  factory SpeciesEnrichment.fromJson(Map<String, dynamic> json) {
    return SpeciesEnrichment(
      definitionId: json['definition_id'] as String,
      animalClass: AnimalClass.fromString(json['animal_class'] as String),
      foodPreference: FoodType.fromString(json['food_preference'] as String),
      climate: Climate.fromString(json['climate'] as String),
      brawn: json['brawn'] as int,
      wit: json['wit'] as int,
      speed: json['speed'] as int,
      artUrl: json['art_url'] as String?,
      enrichedAt: DateTime.parse(json['enriched_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'definition_id': definitionId,
        'animal_class': animalClass.name,
        'food_preference': foodPreference.name,
        'climate': climate.name,
        'brawn': brawn,
        'wit': wit,
        'speed': speed,
        'art_url': artUrl,
        'enriched_at': enrichedAt.toIso8601String(),
      };

  factory SpeciesEnrichment.fromDrift(LocalSpeciesEnrichment row) {
    return SpeciesEnrichment(
      definitionId: row.definitionId,
      animalClass: AnimalClass.fromString(row.animalClass),
      foodPreference: FoodType.fromString(row.foodPreference),
      climate: Climate.fromString(row.climate),
      brawn: row.brawn,
      wit: row.wit,
      speed: row.speed,
      artUrl: row.artUrl,
      enrichedAt: row.enrichedAt,
    );
  }

  LocalSpeciesEnrichment toDriftRow() {
    return LocalSpeciesEnrichment(
      definitionId: definitionId,
      animalClass: animalClass.name,
      foodPreference: foodPreference.name,
      climate: climate.name,
      brawn: brawn,
      wit: wit,
      speed: speed,
      artUrl: artUrl,
      enrichedAt: enrichedAt,
    );
  }

  LocalSpeciesEnrichmentTableCompanion toDriftCompanion() {
    return LocalSpeciesEnrichmentTableCompanion(
      definitionId: Value(definitionId),
      animalClass: Value(animalClass.name),
      foodPreference: Value(foodPreference.name),
      climate: Value(climate.name),
      brawn: Value(brawn),
      wit: Value(wit),
      speed: Value(speed),
      artUrl: Value(artUrl),
      enrichedAt: Value(enrichedAt),
    );
  }

  SpeciesEnrichment copyWith({
    String? definitionId,
    AnimalClass? animalClass,
    FoodType? foodPreference,
    Climate? climate,
    int? brawn,
    int? wit,
    int? speed,
    String? artUrl,
    DateTime? enrichedAt,
  }) {
    return SpeciesEnrichment(
      definitionId: definitionId ?? this.definitionId,
      animalClass: animalClass ?? this.animalClass,
      foodPreference: foodPreference ?? this.foodPreference,
      climate: climate ?? this.climate,
      brawn: brawn ?? this.brawn,
      wit: wit ?? this.wit,
      speed: speed ?? this.speed,
      artUrl: artUrl ?? this.artUrl,
      enrichedAt: enrichedAt ?? this.enrichedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SpeciesEnrichment && other.definitionId == definitionId;
  }

  @override
  int get hashCode => definitionId.hashCode;

  @override
  String toString() =>
      'SpeciesEnrichment($definitionId, $animalClass, $foodPreference, '
      '$climate, brawn:$brawn wit:$wit speed:$speed)';
}
