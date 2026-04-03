// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $PlayersTableTable extends PlayersTable
    with TableInfo<$PlayersTableTable, Player> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlayersTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _displayNameMeta =
      const VerificationMeta('displayName');
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
      'display_name', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _totalDistanceKmMeta =
      const VerificationMeta('totalDistanceKm');
  @override
  late final GeneratedColumn<double> totalDistanceKm = GeneratedColumn<double>(
      'total_distance_km', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _cellsExploredMeta =
      const VerificationMeta('cellsExplored');
  @override
  late final GeneratedColumn<int> cellsExplored = GeneratedColumn<int>(
      'cells_explored', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _speciesDiscoveredMeta =
      const VerificationMeta('speciesDiscovered');
  @override
  late final GeneratedColumn<int> speciesDiscovered = GeneratedColumn<int>(
      'species_discovered', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _currentStreakMeta =
      const VerificationMeta('currentStreak');
  @override
  late final GeneratedColumn<int> currentStreak = GeneratedColumn<int>(
      'current_streak', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _longestStreakMeta =
      const VerificationMeta('longestStreak');
  @override
  late final GeneratedColumn<int> longestStreak = GeneratedColumn<int>(
      'longest_streak', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _hasCompletedOnboardingMeta =
      const VerificationMeta('hasCompletedOnboarding');
  @override
  late final GeneratedColumn<bool> hasCompletedOnboarding =
      GeneratedColumn<bool>('has_completed_onboarding', aliasedName, false,
          type: DriftSqlType.bool,
          requiredDuringInsert: false,
          defaultConstraints: GeneratedColumn.constraintIsAlways(
              'CHECK ("has_completed_onboarding" IN (0, 1))'),
          defaultValue: const Constant(false));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        displayName,
        totalDistanceKm,
        cellsExplored,
        speciesDiscovered,
        currentStreak,
        longestStreak,
        hasCompletedOnboarding,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'players_table';
  @override
  VerificationContext validateIntegrity(Insertable<Player> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
          _displayNameMeta,
          displayName.isAcceptableOrUnknown(
              data['display_name']!, _displayNameMeta));
    }
    if (data.containsKey('total_distance_km')) {
      context.handle(
          _totalDistanceKmMeta,
          totalDistanceKm.isAcceptableOrUnknown(
              data['total_distance_km']!, _totalDistanceKmMeta));
    }
    if (data.containsKey('cells_explored')) {
      context.handle(
          _cellsExploredMeta,
          cellsExplored.isAcceptableOrUnknown(
              data['cells_explored']!, _cellsExploredMeta));
    }
    if (data.containsKey('species_discovered')) {
      context.handle(
          _speciesDiscoveredMeta,
          speciesDiscovered.isAcceptableOrUnknown(
              data['species_discovered']!, _speciesDiscoveredMeta));
    }
    if (data.containsKey('current_streak')) {
      context.handle(
          _currentStreakMeta,
          currentStreak.isAcceptableOrUnknown(
              data['current_streak']!, _currentStreakMeta));
    }
    if (data.containsKey('longest_streak')) {
      context.handle(
          _longestStreakMeta,
          longestStreak.isAcceptableOrUnknown(
              data['longest_streak']!, _longestStreakMeta));
    }
    if (data.containsKey('has_completed_onboarding')) {
      context.handle(
          _hasCompletedOnboardingMeta,
          hasCompletedOnboarding.isAcceptableOrUnknown(
              data['has_completed_onboarding']!, _hasCompletedOnboardingMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Player map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Player(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      displayName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}display_name'])!,
      totalDistanceKm: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}total_distance_km'])!,
      cellsExplored: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}cells_explored'])!,
      speciesDiscovered: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}species_discovered'])!,
      currentStreak: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}current_streak'])!,
      longestStreak: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}longest_streak'])!,
      hasCompletedOnboarding: attachedDatabase.typeMapping.read(
          DriftSqlType.bool,
          data['${effectivePrefix}has_completed_onboarding'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $PlayersTableTable createAlias(String alias) {
    return $PlayersTableTable(attachedDatabase, alias);
  }
}

class Player extends DataClass implements Insertable<Player> {
  final String id;
  final String displayName;
  final double totalDistanceKm;
  final int cellsExplored;
  final int speciesDiscovered;
  final int currentStreak;
  final int longestStreak;
  final bool hasCompletedOnboarding;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Player(
      {required this.id,
      required this.displayName,
      required this.totalDistanceKm,
      required this.cellsExplored,
      required this.speciesDiscovered,
      required this.currentStreak,
      required this.longestStreak,
      required this.hasCompletedOnboarding,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['display_name'] = Variable<String>(displayName);
    map['total_distance_km'] = Variable<double>(totalDistanceKm);
    map['cells_explored'] = Variable<int>(cellsExplored);
    map['species_discovered'] = Variable<int>(speciesDiscovered);
    map['current_streak'] = Variable<int>(currentStreak);
    map['longest_streak'] = Variable<int>(longestStreak);
    map['has_completed_onboarding'] = Variable<bool>(hasCompletedOnboarding);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PlayersTableCompanion toCompanion(bool nullToAbsent) {
    return PlayersTableCompanion(
      id: Value(id),
      displayName: Value(displayName),
      totalDistanceKm: Value(totalDistanceKm),
      cellsExplored: Value(cellsExplored),
      speciesDiscovered: Value(speciesDiscovered),
      currentStreak: Value(currentStreak),
      longestStreak: Value(longestStreak),
      hasCompletedOnboarding: Value(hasCompletedOnboarding),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Player.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Player(
      id: serializer.fromJson<String>(json['id']),
      displayName: serializer.fromJson<String>(json['displayName']),
      totalDistanceKm: serializer.fromJson<double>(json['totalDistanceKm']),
      cellsExplored: serializer.fromJson<int>(json['cellsExplored']),
      speciesDiscovered: serializer.fromJson<int>(json['speciesDiscovered']),
      currentStreak: serializer.fromJson<int>(json['currentStreak']),
      longestStreak: serializer.fromJson<int>(json['longestStreak']),
      hasCompletedOnboarding:
          serializer.fromJson<bool>(json['hasCompletedOnboarding']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'displayName': serializer.toJson<String>(displayName),
      'totalDistanceKm': serializer.toJson<double>(totalDistanceKm),
      'cellsExplored': serializer.toJson<int>(cellsExplored),
      'speciesDiscovered': serializer.toJson<int>(speciesDiscovered),
      'currentStreak': serializer.toJson<int>(currentStreak),
      'longestStreak': serializer.toJson<int>(longestStreak),
      'hasCompletedOnboarding': serializer.toJson<bool>(hasCompletedOnboarding),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Player copyWith(
          {String? id,
          String? displayName,
          double? totalDistanceKm,
          int? cellsExplored,
          int? speciesDiscovered,
          int? currentStreak,
          int? longestStreak,
          bool? hasCompletedOnboarding,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      Player(
        id: id ?? this.id,
        displayName: displayName ?? this.displayName,
        totalDistanceKm: totalDistanceKm ?? this.totalDistanceKm,
        cellsExplored: cellsExplored ?? this.cellsExplored,
        speciesDiscovered: speciesDiscovered ?? this.speciesDiscovered,
        currentStreak: currentStreak ?? this.currentStreak,
        longestStreak: longestStreak ?? this.longestStreak,
        hasCompletedOnboarding:
            hasCompletedOnboarding ?? this.hasCompletedOnboarding,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  Player copyWithCompanion(PlayersTableCompanion data) {
    return Player(
      id: data.id.present ? data.id.value : this.id,
      displayName:
          data.displayName.present ? data.displayName.value : this.displayName,
      totalDistanceKm: data.totalDistanceKm.present
          ? data.totalDistanceKm.value
          : this.totalDistanceKm,
      cellsExplored: data.cellsExplored.present
          ? data.cellsExplored.value
          : this.cellsExplored,
      speciesDiscovered: data.speciesDiscovered.present
          ? data.speciesDiscovered.value
          : this.speciesDiscovered,
      currentStreak: data.currentStreak.present
          ? data.currentStreak.value
          : this.currentStreak,
      longestStreak: data.longestStreak.present
          ? data.longestStreak.value
          : this.longestStreak,
      hasCompletedOnboarding: data.hasCompletedOnboarding.present
          ? data.hasCompletedOnboarding.value
          : this.hasCompletedOnboarding,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Player(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('totalDistanceKm: $totalDistanceKm, ')
          ..write('cellsExplored: $cellsExplored, ')
          ..write('speciesDiscovered: $speciesDiscovered, ')
          ..write('currentStreak: $currentStreak, ')
          ..write('longestStreak: $longestStreak, ')
          ..write('hasCompletedOnboarding: $hasCompletedOnboarding, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      displayName,
      totalDistanceKm,
      cellsExplored,
      speciesDiscovered,
      currentStreak,
      longestStreak,
      hasCompletedOnboarding,
      createdAt,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Player &&
          other.id == this.id &&
          other.displayName == this.displayName &&
          other.totalDistanceKm == this.totalDistanceKm &&
          other.cellsExplored == this.cellsExplored &&
          other.speciesDiscovered == this.speciesDiscovered &&
          other.currentStreak == this.currentStreak &&
          other.longestStreak == this.longestStreak &&
          other.hasCompletedOnboarding == this.hasCompletedOnboarding &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class PlayersTableCompanion extends UpdateCompanion<Player> {
  final Value<String> id;
  final Value<String> displayName;
  final Value<double> totalDistanceKm;
  final Value<int> cellsExplored;
  final Value<int> speciesDiscovered;
  final Value<int> currentStreak;
  final Value<int> longestStreak;
  final Value<bool> hasCompletedOnboarding;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const PlayersTableCompanion({
    this.id = const Value.absent(),
    this.displayName = const Value.absent(),
    this.totalDistanceKm = const Value.absent(),
    this.cellsExplored = const Value.absent(),
    this.speciesDiscovered = const Value.absent(),
    this.currentStreak = const Value.absent(),
    this.longestStreak = const Value.absent(),
    this.hasCompletedOnboarding = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlayersTableCompanion.insert({
    required String id,
    this.displayName = const Value.absent(),
    this.totalDistanceKm = const Value.absent(),
    this.cellsExplored = const Value.absent(),
    this.speciesDiscovered = const Value.absent(),
    this.currentStreak = const Value.absent(),
    this.longestStreak = const Value.absent(),
    this.hasCompletedOnboarding = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<Player> custom({
    Expression<String>? id,
    Expression<String>? displayName,
    Expression<double>? totalDistanceKm,
    Expression<int>? cellsExplored,
    Expression<int>? speciesDiscovered,
    Expression<int>? currentStreak,
    Expression<int>? longestStreak,
    Expression<bool>? hasCompletedOnboarding,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (displayName != null) 'display_name': displayName,
      if (totalDistanceKm != null) 'total_distance_km': totalDistanceKm,
      if (cellsExplored != null) 'cells_explored': cellsExplored,
      if (speciesDiscovered != null) 'species_discovered': speciesDiscovered,
      if (currentStreak != null) 'current_streak': currentStreak,
      if (longestStreak != null) 'longest_streak': longestStreak,
      if (hasCompletedOnboarding != null)
        'has_completed_onboarding': hasCompletedOnboarding,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlayersTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? displayName,
      Value<double>? totalDistanceKm,
      Value<int>? cellsExplored,
      Value<int>? speciesDiscovered,
      Value<int>? currentStreak,
      Value<int>? longestStreak,
      Value<bool>? hasCompletedOnboarding,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return PlayersTableCompanion(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      totalDistanceKm: totalDistanceKm ?? this.totalDistanceKm,
      cellsExplored: cellsExplored ?? this.cellsExplored,
      speciesDiscovered: speciesDiscovered ?? this.speciesDiscovered,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (totalDistanceKm.present) {
      map['total_distance_km'] = Variable<double>(totalDistanceKm.value);
    }
    if (cellsExplored.present) {
      map['cells_explored'] = Variable<int>(cellsExplored.value);
    }
    if (speciesDiscovered.present) {
      map['species_discovered'] = Variable<int>(speciesDiscovered.value);
    }
    if (currentStreak.present) {
      map['current_streak'] = Variable<int>(currentStreak.value);
    }
    if (longestStreak.present) {
      map['longest_streak'] = Variable<int>(longestStreak.value);
    }
    if (hasCompletedOnboarding.present) {
      map['has_completed_onboarding'] =
          Variable<bool>(hasCompletedOnboarding.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlayersTableCompanion(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('totalDistanceKm: $totalDistanceKm, ')
          ..write('cellsExplored: $cellsExplored, ')
          ..write('speciesDiscovered: $speciesDiscovered, ')
          ..write('currentStreak: $currentStreak, ')
          ..write('longestStreak: $longestStreak, ')
          ..write('hasCompletedOnboarding: $hasCompletedOnboarding, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SpeciesTableTable extends SpeciesTable
    with TableInfo<$SpeciesTableTable, Species> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SpeciesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _definitionIdMeta =
      const VerificationMeta('definitionId');
  @override
  late final GeneratedColumn<String> definitionId = GeneratedColumn<String>(
      'definition_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _scientificNameMeta =
      const VerificationMeta('scientificName');
  @override
  late final GeneratedColumn<String> scientificName = GeneratedColumn<String>(
      'scientific_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _commonNameMeta =
      const VerificationMeta('commonName');
  @override
  late final GeneratedColumn<String> commonName = GeneratedColumn<String>(
      'common_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _taxonomicClassMeta =
      const VerificationMeta('taxonomicClass');
  @override
  late final GeneratedColumn<String> taxonomicClass = GeneratedColumn<String>(
      'taxonomic_class', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _iucnStatusMeta =
      const VerificationMeta('iucnStatus');
  @override
  late final GeneratedColumn<String> iucnStatus = GeneratedColumn<String>(
      'iucn_status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _habitatsJsonMeta =
      const VerificationMeta('habitatsJson');
  @override
  late final GeneratedColumn<String> habitatsJson = GeneratedColumn<String>(
      'habitats_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _continentsJsonMeta =
      const VerificationMeta('continentsJson');
  @override
  late final GeneratedColumn<String> continentsJson = GeneratedColumn<String>(
      'continents_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _animalClassMeta =
      const VerificationMeta('animalClass');
  @override
  late final GeneratedColumn<String> animalClass = GeneratedColumn<String>(
      'animal_class', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _foodPreferenceMeta =
      const VerificationMeta('foodPreference');
  @override
  late final GeneratedColumn<String> foodPreference = GeneratedColumn<String>(
      'food_preference', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _climateMeta =
      const VerificationMeta('climate');
  @override
  late final GeneratedColumn<String> climate = GeneratedColumn<String>(
      'climate', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _brawnMeta = const VerificationMeta('brawn');
  @override
  late final GeneratedColumn<int> brawn = GeneratedColumn<int>(
      'brawn', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _witMeta = const VerificationMeta('wit');
  @override
  late final GeneratedColumn<int> wit = GeneratedColumn<int>(
      'wit', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _speedMeta = const VerificationMeta('speed');
  @override
  late final GeneratedColumn<int> speed = GeneratedColumn<int>(
      'speed', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<String> size = GeneratedColumn<String>(
      'size', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _iconUrlMeta =
      const VerificationMeta('iconUrl');
  @override
  late final GeneratedColumn<String> iconUrl = GeneratedColumn<String>(
      'icon_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _artUrlMeta = const VerificationMeta('artUrl');
  @override
  late final GeneratedColumn<String> artUrl = GeneratedColumn<String>(
      'art_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _enrichedAtMeta =
      const VerificationMeta('enrichedAt');
  @override
  late final GeneratedColumn<DateTime> enrichedAt = GeneratedColumn<DateTime>(
      'enriched_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        definitionId,
        scientificName,
        commonName,
        taxonomicClass,
        iucnStatus,
        habitatsJson,
        continentsJson,
        animalClass,
        foodPreference,
        climate,
        brawn,
        wit,
        speed,
        size,
        iconUrl,
        artUrl,
        enrichedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'species_table';
  @override
  VerificationContext validateIntegrity(Insertable<Species> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('definition_id')) {
      context.handle(
          _definitionIdMeta,
          definitionId.isAcceptableOrUnknown(
              data['definition_id']!, _definitionIdMeta));
    } else if (isInserting) {
      context.missing(_definitionIdMeta);
    }
    if (data.containsKey('scientific_name')) {
      context.handle(
          _scientificNameMeta,
          scientificName.isAcceptableOrUnknown(
              data['scientific_name']!, _scientificNameMeta));
    } else if (isInserting) {
      context.missing(_scientificNameMeta);
    }
    if (data.containsKey('common_name')) {
      context.handle(
          _commonNameMeta,
          commonName.isAcceptableOrUnknown(
              data['common_name']!, _commonNameMeta));
    } else if (isInserting) {
      context.missing(_commonNameMeta);
    }
    if (data.containsKey('taxonomic_class')) {
      context.handle(
          _taxonomicClassMeta,
          taxonomicClass.isAcceptableOrUnknown(
              data['taxonomic_class']!, _taxonomicClassMeta));
    } else if (isInserting) {
      context.missing(_taxonomicClassMeta);
    }
    if (data.containsKey('iucn_status')) {
      context.handle(
          _iucnStatusMeta,
          iucnStatus.isAcceptableOrUnknown(
              data['iucn_status']!, _iucnStatusMeta));
    } else if (isInserting) {
      context.missing(_iucnStatusMeta);
    }
    if (data.containsKey('habitats_json')) {
      context.handle(
          _habitatsJsonMeta,
          habitatsJson.isAcceptableOrUnknown(
              data['habitats_json']!, _habitatsJsonMeta));
    } else if (isInserting) {
      context.missing(_habitatsJsonMeta);
    }
    if (data.containsKey('continents_json')) {
      context.handle(
          _continentsJsonMeta,
          continentsJson.isAcceptableOrUnknown(
              data['continents_json']!, _continentsJsonMeta));
    } else if (isInserting) {
      context.missing(_continentsJsonMeta);
    }
    if (data.containsKey('animal_class')) {
      context.handle(
          _animalClassMeta,
          animalClass.isAcceptableOrUnknown(
              data['animal_class']!, _animalClassMeta));
    }
    if (data.containsKey('food_preference')) {
      context.handle(
          _foodPreferenceMeta,
          foodPreference.isAcceptableOrUnknown(
              data['food_preference']!, _foodPreferenceMeta));
    }
    if (data.containsKey('climate')) {
      context.handle(_climateMeta,
          climate.isAcceptableOrUnknown(data['climate']!, _climateMeta));
    }
    if (data.containsKey('brawn')) {
      context.handle(
          _brawnMeta, brawn.isAcceptableOrUnknown(data['brawn']!, _brawnMeta));
    }
    if (data.containsKey('wit')) {
      context.handle(
          _witMeta, wit.isAcceptableOrUnknown(data['wit']!, _witMeta));
    }
    if (data.containsKey('speed')) {
      context.handle(
          _speedMeta, speed.isAcceptableOrUnknown(data['speed']!, _speedMeta));
    }
    if (data.containsKey('size')) {
      context.handle(
          _sizeMeta, size.isAcceptableOrUnknown(data['size']!, _sizeMeta));
    }
    if (data.containsKey('icon_url')) {
      context.handle(_iconUrlMeta,
          iconUrl.isAcceptableOrUnknown(data['icon_url']!, _iconUrlMeta));
    }
    if (data.containsKey('art_url')) {
      context.handle(_artUrlMeta,
          artUrl.isAcceptableOrUnknown(data['art_url']!, _artUrlMeta));
    }
    if (data.containsKey('enriched_at')) {
      context.handle(
          _enrichedAtMeta,
          enrichedAt.isAcceptableOrUnknown(
              data['enriched_at']!, _enrichedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {definitionId};
  @override
  Species map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Species(
      definitionId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}definition_id'])!,
      scientificName: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}scientific_name'])!,
      commonName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}common_name'])!,
      taxonomicClass: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}taxonomic_class'])!,
      iucnStatus: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}iucn_status'])!,
      habitatsJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}habitats_json'])!,
      continentsJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}continents_json'])!,
      animalClass: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}animal_class']),
      foodPreference: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}food_preference']),
      climate: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}climate']),
      brawn: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}brawn']),
      wit: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}wit']),
      speed: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}speed']),
      size: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}size']),
      iconUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}icon_url']),
      artUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}art_url']),
      enrichedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}enriched_at']),
    );
  }

  @override
  $SpeciesTableTable createAlias(String alias) {
    return $SpeciesTableTable(attachedDatabase, alias);
  }
}

class Species extends DataClass implements Insertable<Species> {
  final String definitionId;
  final String scientificName;
  final String commonName;
  final String taxonomicClass;
  final String iucnStatus;
  final String habitatsJson;
  final String continentsJson;
  final String? animalClass;
  final String? foodPreference;
  final String? climate;
  final int? brawn;
  final int? wit;
  final int? speed;
  final String? size;
  final String? iconUrl;
  final String? artUrl;
  final DateTime? enrichedAt;
  const Species(
      {required this.definitionId,
      required this.scientificName,
      required this.commonName,
      required this.taxonomicClass,
      required this.iucnStatus,
      required this.habitatsJson,
      required this.continentsJson,
      this.animalClass,
      this.foodPreference,
      this.climate,
      this.brawn,
      this.wit,
      this.speed,
      this.size,
      this.iconUrl,
      this.artUrl,
      this.enrichedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['definition_id'] = Variable<String>(definitionId);
    map['scientific_name'] = Variable<String>(scientificName);
    map['common_name'] = Variable<String>(commonName);
    map['taxonomic_class'] = Variable<String>(taxonomicClass);
    map['iucn_status'] = Variable<String>(iucnStatus);
    map['habitats_json'] = Variable<String>(habitatsJson);
    map['continents_json'] = Variable<String>(continentsJson);
    if (!nullToAbsent || animalClass != null) {
      map['animal_class'] = Variable<String>(animalClass);
    }
    if (!nullToAbsent || foodPreference != null) {
      map['food_preference'] = Variable<String>(foodPreference);
    }
    if (!nullToAbsent || climate != null) {
      map['climate'] = Variable<String>(climate);
    }
    if (!nullToAbsent || brawn != null) {
      map['brawn'] = Variable<int>(brawn);
    }
    if (!nullToAbsent || wit != null) {
      map['wit'] = Variable<int>(wit);
    }
    if (!nullToAbsent || speed != null) {
      map['speed'] = Variable<int>(speed);
    }
    if (!nullToAbsent || size != null) {
      map['size'] = Variable<String>(size);
    }
    if (!nullToAbsent || iconUrl != null) {
      map['icon_url'] = Variable<String>(iconUrl);
    }
    if (!nullToAbsent || artUrl != null) {
      map['art_url'] = Variable<String>(artUrl);
    }
    if (!nullToAbsent || enrichedAt != null) {
      map['enriched_at'] = Variable<DateTime>(enrichedAt);
    }
    return map;
  }

  SpeciesTableCompanion toCompanion(bool nullToAbsent) {
    return SpeciesTableCompanion(
      definitionId: Value(definitionId),
      scientificName: Value(scientificName),
      commonName: Value(commonName),
      taxonomicClass: Value(taxonomicClass),
      iucnStatus: Value(iucnStatus),
      habitatsJson: Value(habitatsJson),
      continentsJson: Value(continentsJson),
      animalClass: animalClass == null && nullToAbsent
          ? const Value.absent()
          : Value(animalClass),
      foodPreference: foodPreference == null && nullToAbsent
          ? const Value.absent()
          : Value(foodPreference),
      climate: climate == null && nullToAbsent
          ? const Value.absent()
          : Value(climate),
      brawn:
          brawn == null && nullToAbsent ? const Value.absent() : Value(brawn),
      wit: wit == null && nullToAbsent ? const Value.absent() : Value(wit),
      speed:
          speed == null && nullToAbsent ? const Value.absent() : Value(speed),
      size: size == null && nullToAbsent ? const Value.absent() : Value(size),
      iconUrl: iconUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(iconUrl),
      artUrl:
          artUrl == null && nullToAbsent ? const Value.absent() : Value(artUrl),
      enrichedAt: enrichedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(enrichedAt),
    );
  }

  factory Species.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Species(
      definitionId: serializer.fromJson<String>(json['definitionId']),
      scientificName: serializer.fromJson<String>(json['scientificName']),
      commonName: serializer.fromJson<String>(json['commonName']),
      taxonomicClass: serializer.fromJson<String>(json['taxonomicClass']),
      iucnStatus: serializer.fromJson<String>(json['iucnStatus']),
      habitatsJson: serializer.fromJson<String>(json['habitatsJson']),
      continentsJson: serializer.fromJson<String>(json['continentsJson']),
      animalClass: serializer.fromJson<String?>(json['animalClass']),
      foodPreference: serializer.fromJson<String?>(json['foodPreference']),
      climate: serializer.fromJson<String?>(json['climate']),
      brawn: serializer.fromJson<int?>(json['brawn']),
      wit: serializer.fromJson<int?>(json['wit']),
      speed: serializer.fromJson<int?>(json['speed']),
      size: serializer.fromJson<String?>(json['size']),
      iconUrl: serializer.fromJson<String?>(json['iconUrl']),
      artUrl: serializer.fromJson<String?>(json['artUrl']),
      enrichedAt: serializer.fromJson<DateTime?>(json['enrichedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'definitionId': serializer.toJson<String>(definitionId),
      'scientificName': serializer.toJson<String>(scientificName),
      'commonName': serializer.toJson<String>(commonName),
      'taxonomicClass': serializer.toJson<String>(taxonomicClass),
      'iucnStatus': serializer.toJson<String>(iucnStatus),
      'habitatsJson': serializer.toJson<String>(habitatsJson),
      'continentsJson': serializer.toJson<String>(continentsJson),
      'animalClass': serializer.toJson<String?>(animalClass),
      'foodPreference': serializer.toJson<String?>(foodPreference),
      'climate': serializer.toJson<String?>(climate),
      'brawn': serializer.toJson<int?>(brawn),
      'wit': serializer.toJson<int?>(wit),
      'speed': serializer.toJson<int?>(speed),
      'size': serializer.toJson<String?>(size),
      'iconUrl': serializer.toJson<String?>(iconUrl),
      'artUrl': serializer.toJson<String?>(artUrl),
      'enrichedAt': serializer.toJson<DateTime?>(enrichedAt),
    };
  }

  Species copyWith(
          {String? definitionId,
          String? scientificName,
          String? commonName,
          String? taxonomicClass,
          String? iucnStatus,
          String? habitatsJson,
          String? continentsJson,
          Value<String?> animalClass = const Value.absent(),
          Value<String?> foodPreference = const Value.absent(),
          Value<String?> climate = const Value.absent(),
          Value<int?> brawn = const Value.absent(),
          Value<int?> wit = const Value.absent(),
          Value<int?> speed = const Value.absent(),
          Value<String?> size = const Value.absent(),
          Value<String?> iconUrl = const Value.absent(),
          Value<String?> artUrl = const Value.absent(),
          Value<DateTime?> enrichedAt = const Value.absent()}) =>
      Species(
        definitionId: definitionId ?? this.definitionId,
        scientificName: scientificName ?? this.scientificName,
        commonName: commonName ?? this.commonName,
        taxonomicClass: taxonomicClass ?? this.taxonomicClass,
        iucnStatus: iucnStatus ?? this.iucnStatus,
        habitatsJson: habitatsJson ?? this.habitatsJson,
        continentsJson: continentsJson ?? this.continentsJson,
        animalClass: animalClass.present ? animalClass.value : this.animalClass,
        foodPreference:
            foodPreference.present ? foodPreference.value : this.foodPreference,
        climate: climate.present ? climate.value : this.climate,
        brawn: brawn.present ? brawn.value : this.brawn,
        wit: wit.present ? wit.value : this.wit,
        speed: speed.present ? speed.value : this.speed,
        size: size.present ? size.value : this.size,
        iconUrl: iconUrl.present ? iconUrl.value : this.iconUrl,
        artUrl: artUrl.present ? artUrl.value : this.artUrl,
        enrichedAt: enrichedAt.present ? enrichedAt.value : this.enrichedAt,
      );
  Species copyWithCompanion(SpeciesTableCompanion data) {
    return Species(
      definitionId: data.definitionId.present
          ? data.definitionId.value
          : this.definitionId,
      scientificName: data.scientificName.present
          ? data.scientificName.value
          : this.scientificName,
      commonName:
          data.commonName.present ? data.commonName.value : this.commonName,
      taxonomicClass: data.taxonomicClass.present
          ? data.taxonomicClass.value
          : this.taxonomicClass,
      iucnStatus:
          data.iucnStatus.present ? data.iucnStatus.value : this.iucnStatus,
      habitatsJson: data.habitatsJson.present
          ? data.habitatsJson.value
          : this.habitatsJson,
      continentsJson: data.continentsJson.present
          ? data.continentsJson.value
          : this.continentsJson,
      animalClass:
          data.animalClass.present ? data.animalClass.value : this.animalClass,
      foodPreference: data.foodPreference.present
          ? data.foodPreference.value
          : this.foodPreference,
      climate: data.climate.present ? data.climate.value : this.climate,
      brawn: data.brawn.present ? data.brawn.value : this.brawn,
      wit: data.wit.present ? data.wit.value : this.wit,
      speed: data.speed.present ? data.speed.value : this.speed,
      size: data.size.present ? data.size.value : this.size,
      iconUrl: data.iconUrl.present ? data.iconUrl.value : this.iconUrl,
      artUrl: data.artUrl.present ? data.artUrl.value : this.artUrl,
      enrichedAt:
          data.enrichedAt.present ? data.enrichedAt.value : this.enrichedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Species(')
          ..write('definitionId: $definitionId, ')
          ..write('scientificName: $scientificName, ')
          ..write('commonName: $commonName, ')
          ..write('taxonomicClass: $taxonomicClass, ')
          ..write('iucnStatus: $iucnStatus, ')
          ..write('habitatsJson: $habitatsJson, ')
          ..write('continentsJson: $continentsJson, ')
          ..write('animalClass: $animalClass, ')
          ..write('foodPreference: $foodPreference, ')
          ..write('climate: $climate, ')
          ..write('brawn: $brawn, ')
          ..write('wit: $wit, ')
          ..write('speed: $speed, ')
          ..write('size: $size, ')
          ..write('iconUrl: $iconUrl, ')
          ..write('artUrl: $artUrl, ')
          ..write('enrichedAt: $enrichedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      definitionId,
      scientificName,
      commonName,
      taxonomicClass,
      iucnStatus,
      habitatsJson,
      continentsJson,
      animalClass,
      foodPreference,
      climate,
      brawn,
      wit,
      speed,
      size,
      iconUrl,
      artUrl,
      enrichedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Species &&
          other.definitionId == this.definitionId &&
          other.scientificName == this.scientificName &&
          other.commonName == this.commonName &&
          other.taxonomicClass == this.taxonomicClass &&
          other.iucnStatus == this.iucnStatus &&
          other.habitatsJson == this.habitatsJson &&
          other.continentsJson == this.continentsJson &&
          other.animalClass == this.animalClass &&
          other.foodPreference == this.foodPreference &&
          other.climate == this.climate &&
          other.brawn == this.brawn &&
          other.wit == this.wit &&
          other.speed == this.speed &&
          other.size == this.size &&
          other.iconUrl == this.iconUrl &&
          other.artUrl == this.artUrl &&
          other.enrichedAt == this.enrichedAt);
}

class SpeciesTableCompanion extends UpdateCompanion<Species> {
  final Value<String> definitionId;
  final Value<String> scientificName;
  final Value<String> commonName;
  final Value<String> taxonomicClass;
  final Value<String> iucnStatus;
  final Value<String> habitatsJson;
  final Value<String> continentsJson;
  final Value<String?> animalClass;
  final Value<String?> foodPreference;
  final Value<String?> climate;
  final Value<int?> brawn;
  final Value<int?> wit;
  final Value<int?> speed;
  final Value<String?> size;
  final Value<String?> iconUrl;
  final Value<String?> artUrl;
  final Value<DateTime?> enrichedAt;
  final Value<int> rowid;
  const SpeciesTableCompanion({
    this.definitionId = const Value.absent(),
    this.scientificName = const Value.absent(),
    this.commonName = const Value.absent(),
    this.taxonomicClass = const Value.absent(),
    this.iucnStatus = const Value.absent(),
    this.habitatsJson = const Value.absent(),
    this.continentsJson = const Value.absent(),
    this.animalClass = const Value.absent(),
    this.foodPreference = const Value.absent(),
    this.climate = const Value.absent(),
    this.brawn = const Value.absent(),
    this.wit = const Value.absent(),
    this.speed = const Value.absent(),
    this.size = const Value.absent(),
    this.iconUrl = const Value.absent(),
    this.artUrl = const Value.absent(),
    this.enrichedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SpeciesTableCompanion.insert({
    required String definitionId,
    required String scientificName,
    required String commonName,
    required String taxonomicClass,
    required String iucnStatus,
    required String habitatsJson,
    required String continentsJson,
    this.animalClass = const Value.absent(),
    this.foodPreference = const Value.absent(),
    this.climate = const Value.absent(),
    this.brawn = const Value.absent(),
    this.wit = const Value.absent(),
    this.speed = const Value.absent(),
    this.size = const Value.absent(),
    this.iconUrl = const Value.absent(),
    this.artUrl = const Value.absent(),
    this.enrichedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : definitionId = Value(definitionId),
        scientificName = Value(scientificName),
        commonName = Value(commonName),
        taxonomicClass = Value(taxonomicClass),
        iucnStatus = Value(iucnStatus),
        habitatsJson = Value(habitatsJson),
        continentsJson = Value(continentsJson);
  static Insertable<Species> custom({
    Expression<String>? definitionId,
    Expression<String>? scientificName,
    Expression<String>? commonName,
    Expression<String>? taxonomicClass,
    Expression<String>? iucnStatus,
    Expression<String>? habitatsJson,
    Expression<String>? continentsJson,
    Expression<String>? animalClass,
    Expression<String>? foodPreference,
    Expression<String>? climate,
    Expression<int>? brawn,
    Expression<int>? wit,
    Expression<int>? speed,
    Expression<String>? size,
    Expression<String>? iconUrl,
    Expression<String>? artUrl,
    Expression<DateTime>? enrichedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (definitionId != null) 'definition_id': definitionId,
      if (scientificName != null) 'scientific_name': scientificName,
      if (commonName != null) 'common_name': commonName,
      if (taxonomicClass != null) 'taxonomic_class': taxonomicClass,
      if (iucnStatus != null) 'iucn_status': iucnStatus,
      if (habitatsJson != null) 'habitats_json': habitatsJson,
      if (continentsJson != null) 'continents_json': continentsJson,
      if (animalClass != null) 'animal_class': animalClass,
      if (foodPreference != null) 'food_preference': foodPreference,
      if (climate != null) 'climate': climate,
      if (brawn != null) 'brawn': brawn,
      if (wit != null) 'wit': wit,
      if (speed != null) 'speed': speed,
      if (size != null) 'size': size,
      if (iconUrl != null) 'icon_url': iconUrl,
      if (artUrl != null) 'art_url': artUrl,
      if (enrichedAt != null) 'enriched_at': enrichedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SpeciesTableCompanion copyWith(
      {Value<String>? definitionId,
      Value<String>? scientificName,
      Value<String>? commonName,
      Value<String>? taxonomicClass,
      Value<String>? iucnStatus,
      Value<String>? habitatsJson,
      Value<String>? continentsJson,
      Value<String?>? animalClass,
      Value<String?>? foodPreference,
      Value<String?>? climate,
      Value<int?>? brawn,
      Value<int?>? wit,
      Value<int?>? speed,
      Value<String?>? size,
      Value<String?>? iconUrl,
      Value<String?>? artUrl,
      Value<DateTime?>? enrichedAt,
      Value<int>? rowid}) {
    return SpeciesTableCompanion(
      definitionId: definitionId ?? this.definitionId,
      scientificName: scientificName ?? this.scientificName,
      commonName: commonName ?? this.commonName,
      taxonomicClass: taxonomicClass ?? this.taxonomicClass,
      iucnStatus: iucnStatus ?? this.iucnStatus,
      habitatsJson: habitatsJson ?? this.habitatsJson,
      continentsJson: continentsJson ?? this.continentsJson,
      animalClass: animalClass ?? this.animalClass,
      foodPreference: foodPreference ?? this.foodPreference,
      climate: climate ?? this.climate,
      brawn: brawn ?? this.brawn,
      wit: wit ?? this.wit,
      speed: speed ?? this.speed,
      size: size ?? this.size,
      iconUrl: iconUrl ?? this.iconUrl,
      artUrl: artUrl ?? this.artUrl,
      enrichedAt: enrichedAt ?? this.enrichedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (definitionId.present) {
      map['definition_id'] = Variable<String>(definitionId.value);
    }
    if (scientificName.present) {
      map['scientific_name'] = Variable<String>(scientificName.value);
    }
    if (commonName.present) {
      map['common_name'] = Variable<String>(commonName.value);
    }
    if (taxonomicClass.present) {
      map['taxonomic_class'] = Variable<String>(taxonomicClass.value);
    }
    if (iucnStatus.present) {
      map['iucn_status'] = Variable<String>(iucnStatus.value);
    }
    if (habitatsJson.present) {
      map['habitats_json'] = Variable<String>(habitatsJson.value);
    }
    if (continentsJson.present) {
      map['continents_json'] = Variable<String>(continentsJson.value);
    }
    if (animalClass.present) {
      map['animal_class'] = Variable<String>(animalClass.value);
    }
    if (foodPreference.present) {
      map['food_preference'] = Variable<String>(foodPreference.value);
    }
    if (climate.present) {
      map['climate'] = Variable<String>(climate.value);
    }
    if (brawn.present) {
      map['brawn'] = Variable<int>(brawn.value);
    }
    if (wit.present) {
      map['wit'] = Variable<int>(wit.value);
    }
    if (speed.present) {
      map['speed'] = Variable<int>(speed.value);
    }
    if (size.present) {
      map['size'] = Variable<String>(size.value);
    }
    if (iconUrl.present) {
      map['icon_url'] = Variable<String>(iconUrl.value);
    }
    if (artUrl.present) {
      map['art_url'] = Variable<String>(artUrl.value);
    }
    if (enrichedAt.present) {
      map['enriched_at'] = Variable<DateTime>(enrichedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SpeciesTableCompanion(')
          ..write('definitionId: $definitionId, ')
          ..write('scientificName: $scientificName, ')
          ..write('commonName: $commonName, ')
          ..write('taxonomicClass: $taxonomicClass, ')
          ..write('iucnStatus: $iucnStatus, ')
          ..write('habitatsJson: $habitatsJson, ')
          ..write('continentsJson: $continentsJson, ')
          ..write('animalClass: $animalClass, ')
          ..write('foodPreference: $foodPreference, ')
          ..write('climate: $climate, ')
          ..write('brawn: $brawn, ')
          ..write('wit: $wit, ')
          ..write('speed: $speed, ')
          ..write('size: $size, ')
          ..write('iconUrl: $iconUrl, ')
          ..write('artUrl: $artUrl, ')
          ..write('enrichedAt: $enrichedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ItemsTableTable extends ItemsTable
    with TableInfo<$ItemsTableTable, Item> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ItemsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _definitionIdMeta =
      const VerificationMeta('definitionId');
  @override
  late final GeneratedColumn<String> definitionId = GeneratedColumn<String>(
      'definition_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _affixesJsonMeta =
      const VerificationMeta('affixesJson');
  @override
  late final GeneratedColumn<String> affixesJson = GeneratedColumn<String>(
      'affixes_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _acquiredAtMeta =
      const VerificationMeta('acquiredAt');
  @override
  late final GeneratedColumn<DateTime> acquiredAt = GeneratedColumn<DateTime>(
      'acquired_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _acquiredInCellIdMeta =
      const VerificationMeta('acquiredInCellId');
  @override
  late final GeneratedColumn<String> acquiredInCellId = GeneratedColumn<String>(
      'acquired_in_cell_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _dailySeedMeta =
      const VerificationMeta('dailySeed');
  @override
  late final GeneratedColumn<String> dailySeed = GeneratedColumn<String>(
      'daily_seed', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('active'));
  static const VerificationMeta _badgesJsonMeta =
      const VerificationMeta('badgesJson');
  @override
  late final GeneratedColumn<String> badgesJson = GeneratedColumn<String>(
      'badges_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _parentAIdMeta =
      const VerificationMeta('parentAId');
  @override
  late final GeneratedColumn<String> parentAId = GeneratedColumn<String>(
      'parent_a_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _parentBIdMeta =
      const VerificationMeta('parentBId');
  @override
  late final GeneratedColumn<String> parentBId = GeneratedColumn<String>(
      'parent_b_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _displayNameMeta =
      const VerificationMeta('displayName');
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
      'display_name', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _scientificNameMeta =
      const VerificationMeta('scientificName');
  @override
  late final GeneratedColumn<String> scientificName = GeneratedColumn<String>(
      'scientific_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _categoryNameMeta =
      const VerificationMeta('categoryName');
  @override
  late final GeneratedColumn<String> categoryName = GeneratedColumn<String>(
      'category_name', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('fauna'));
  static const VerificationMeta _rarityNameMeta =
      const VerificationMeta('rarityName');
  @override
  late final GeneratedColumn<String> rarityName = GeneratedColumn<String>(
      'rarity_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _habitatsJsonMeta =
      const VerificationMeta('habitatsJson');
  @override
  late final GeneratedColumn<String> habitatsJson = GeneratedColumn<String>(
      'habitats_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _continentsJsonMeta =
      const VerificationMeta('continentsJson');
  @override
  late final GeneratedColumn<String> continentsJson = GeneratedColumn<String>(
      'continents_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _taxonomicClassMeta =
      const VerificationMeta('taxonomicClass');
  @override
  late final GeneratedColumn<String> taxonomicClass = GeneratedColumn<String>(
      'taxonomic_class', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _animalClassNameMeta =
      const VerificationMeta('animalClassName');
  @override
  late final GeneratedColumn<String> animalClassName = GeneratedColumn<String>(
      'animal_class_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _foodPreferenceNameMeta =
      const VerificationMeta('foodPreferenceName');
  @override
  late final GeneratedColumn<String> foodPreferenceName =
      GeneratedColumn<String>('food_preference_name', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _climateNameMeta =
      const VerificationMeta('climateName');
  @override
  late final GeneratedColumn<String> climateName = GeneratedColumn<String>(
      'climate_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _brawnMeta = const VerificationMeta('brawn');
  @override
  late final GeneratedColumn<int> brawn = GeneratedColumn<int>(
      'brawn', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _witMeta = const VerificationMeta('wit');
  @override
  late final GeneratedColumn<int> wit = GeneratedColumn<int>(
      'wit', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _speedMeta = const VerificationMeta('speed');
  @override
  late final GeneratedColumn<int> speed = GeneratedColumn<int>(
      'speed', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _sizeNameMeta =
      const VerificationMeta('sizeName');
  @override
  late final GeneratedColumn<String> sizeName = GeneratedColumn<String>(
      'size_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _iconUrlMeta =
      const VerificationMeta('iconUrl');
  @override
  late final GeneratedColumn<String> iconUrl = GeneratedColumn<String>(
      'icon_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _artUrlMeta = const VerificationMeta('artUrl');
  @override
  late final GeneratedColumn<String> artUrl = GeneratedColumn<String>(
      'art_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _cellHabitatNameMeta =
      const VerificationMeta('cellHabitatName');
  @override
  late final GeneratedColumn<String> cellHabitatName = GeneratedColumn<String>(
      'cell_habitat_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _cellClimateNameMeta =
      const VerificationMeta('cellClimateName');
  @override
  late final GeneratedColumn<String> cellClimateName = GeneratedColumn<String>(
      'cell_climate_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _cellContinentNameMeta =
      const VerificationMeta('cellContinentName');
  @override
  late final GeneratedColumn<String> cellContinentName =
      GeneratedColumn<String>('cell_continent_name', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _locationDistrictMeta =
      const VerificationMeta('locationDistrict');
  @override
  late final GeneratedColumn<String> locationDistrict = GeneratedColumn<String>(
      'location_district', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _locationCityMeta =
      const VerificationMeta('locationCity');
  @override
  late final GeneratedColumn<String> locationCity = GeneratedColumn<String>(
      'location_city', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _locationStateMeta =
      const VerificationMeta('locationState');
  @override
  late final GeneratedColumn<String> locationState = GeneratedColumn<String>(
      'location_state', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _locationCountryMeta =
      const VerificationMeta('locationCountry');
  @override
  late final GeneratedColumn<String> locationCountry = GeneratedColumn<String>(
      'location_country', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _locationCountryCodeMeta =
      const VerificationMeta('locationCountryCode');
  @override
  late final GeneratedColumn<String> locationCountryCode =
      GeneratedColumn<String>('location_country_code', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        userId,
        definitionId,
        affixesJson,
        acquiredAt,
        acquiredInCellId,
        dailySeed,
        status,
        badgesJson,
        parentAId,
        parentBId,
        displayName,
        scientificName,
        categoryName,
        rarityName,
        habitatsJson,
        continentsJson,
        taxonomicClass,
        animalClassName,
        foodPreferenceName,
        climateName,
        brawn,
        wit,
        speed,
        sizeName,
        iconUrl,
        artUrl,
        cellHabitatName,
        cellClimateName,
        cellContinentName,
        locationDistrict,
        locationCity,
        locationState,
        locationCountry,
        locationCountryCode
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'items_table';
  @override
  VerificationContext validateIntegrity(Insertable<Item> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('definition_id')) {
      context.handle(
          _definitionIdMeta,
          definitionId.isAcceptableOrUnknown(
              data['definition_id']!, _definitionIdMeta));
    } else if (isInserting) {
      context.missing(_definitionIdMeta);
    }
    if (data.containsKey('affixes_json')) {
      context.handle(
          _affixesJsonMeta,
          affixesJson.isAcceptableOrUnknown(
              data['affixes_json']!, _affixesJsonMeta));
    }
    if (data.containsKey('acquired_at')) {
      context.handle(
          _acquiredAtMeta,
          acquiredAt.isAcceptableOrUnknown(
              data['acquired_at']!, _acquiredAtMeta));
    } else if (isInserting) {
      context.missing(_acquiredAtMeta);
    }
    if (data.containsKey('acquired_in_cell_id')) {
      context.handle(
          _acquiredInCellIdMeta,
          acquiredInCellId.isAcceptableOrUnknown(
              data['acquired_in_cell_id']!, _acquiredInCellIdMeta));
    }
    if (data.containsKey('daily_seed')) {
      context.handle(_dailySeedMeta,
          dailySeed.isAcceptableOrUnknown(data['daily_seed']!, _dailySeedMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('badges_json')) {
      context.handle(
          _badgesJsonMeta,
          badgesJson.isAcceptableOrUnknown(
              data['badges_json']!, _badgesJsonMeta));
    }
    if (data.containsKey('parent_a_id')) {
      context.handle(
          _parentAIdMeta,
          parentAId.isAcceptableOrUnknown(
              data['parent_a_id']!, _parentAIdMeta));
    }
    if (data.containsKey('parent_b_id')) {
      context.handle(
          _parentBIdMeta,
          parentBId.isAcceptableOrUnknown(
              data['parent_b_id']!, _parentBIdMeta));
    }
    if (data.containsKey('display_name')) {
      context.handle(
          _displayNameMeta,
          displayName.isAcceptableOrUnknown(
              data['display_name']!, _displayNameMeta));
    }
    if (data.containsKey('scientific_name')) {
      context.handle(
          _scientificNameMeta,
          scientificName.isAcceptableOrUnknown(
              data['scientific_name']!, _scientificNameMeta));
    }
    if (data.containsKey('category_name')) {
      context.handle(
          _categoryNameMeta,
          categoryName.isAcceptableOrUnknown(
              data['category_name']!, _categoryNameMeta));
    }
    if (data.containsKey('rarity_name')) {
      context.handle(
          _rarityNameMeta,
          rarityName.isAcceptableOrUnknown(
              data['rarity_name']!, _rarityNameMeta));
    }
    if (data.containsKey('habitats_json')) {
      context.handle(
          _habitatsJsonMeta,
          habitatsJson.isAcceptableOrUnknown(
              data['habitats_json']!, _habitatsJsonMeta));
    }
    if (data.containsKey('continents_json')) {
      context.handle(
          _continentsJsonMeta,
          continentsJson.isAcceptableOrUnknown(
              data['continents_json']!, _continentsJsonMeta));
    }
    if (data.containsKey('taxonomic_class')) {
      context.handle(
          _taxonomicClassMeta,
          taxonomicClass.isAcceptableOrUnknown(
              data['taxonomic_class']!, _taxonomicClassMeta));
    }
    if (data.containsKey('animal_class_name')) {
      context.handle(
          _animalClassNameMeta,
          animalClassName.isAcceptableOrUnknown(
              data['animal_class_name']!, _animalClassNameMeta));
    }
    if (data.containsKey('food_preference_name')) {
      context.handle(
          _foodPreferenceNameMeta,
          foodPreferenceName.isAcceptableOrUnknown(
              data['food_preference_name']!, _foodPreferenceNameMeta));
    }
    if (data.containsKey('climate_name')) {
      context.handle(
          _climateNameMeta,
          climateName.isAcceptableOrUnknown(
              data['climate_name']!, _climateNameMeta));
    }
    if (data.containsKey('brawn')) {
      context.handle(
          _brawnMeta, brawn.isAcceptableOrUnknown(data['brawn']!, _brawnMeta));
    }
    if (data.containsKey('wit')) {
      context.handle(
          _witMeta, wit.isAcceptableOrUnknown(data['wit']!, _witMeta));
    }
    if (data.containsKey('speed')) {
      context.handle(
          _speedMeta, speed.isAcceptableOrUnknown(data['speed']!, _speedMeta));
    }
    if (data.containsKey('size_name')) {
      context.handle(_sizeNameMeta,
          sizeName.isAcceptableOrUnknown(data['size_name']!, _sizeNameMeta));
    }
    if (data.containsKey('icon_url')) {
      context.handle(_iconUrlMeta,
          iconUrl.isAcceptableOrUnknown(data['icon_url']!, _iconUrlMeta));
    }
    if (data.containsKey('art_url')) {
      context.handle(_artUrlMeta,
          artUrl.isAcceptableOrUnknown(data['art_url']!, _artUrlMeta));
    }
    if (data.containsKey('cell_habitat_name')) {
      context.handle(
          _cellHabitatNameMeta,
          cellHabitatName.isAcceptableOrUnknown(
              data['cell_habitat_name']!, _cellHabitatNameMeta));
    }
    if (data.containsKey('cell_climate_name')) {
      context.handle(
          _cellClimateNameMeta,
          cellClimateName.isAcceptableOrUnknown(
              data['cell_climate_name']!, _cellClimateNameMeta));
    }
    if (data.containsKey('cell_continent_name')) {
      context.handle(
          _cellContinentNameMeta,
          cellContinentName.isAcceptableOrUnknown(
              data['cell_continent_name']!, _cellContinentNameMeta));
    }
    if (data.containsKey('location_district')) {
      context.handle(
          _locationDistrictMeta,
          locationDistrict.isAcceptableOrUnknown(
              data['location_district']!, _locationDistrictMeta));
    }
    if (data.containsKey('location_city')) {
      context.handle(
          _locationCityMeta,
          locationCity.isAcceptableOrUnknown(
              data['location_city']!, _locationCityMeta));
    }
    if (data.containsKey('location_state')) {
      context.handle(
          _locationStateMeta,
          locationState.isAcceptableOrUnknown(
              data['location_state']!, _locationStateMeta));
    }
    if (data.containsKey('location_country')) {
      context.handle(
          _locationCountryMeta,
          locationCountry.isAcceptableOrUnknown(
              data['location_country']!, _locationCountryMeta));
    }
    if (data.containsKey('location_country_code')) {
      context.handle(
          _locationCountryCodeMeta,
          locationCountryCode.isAcceptableOrUnknown(
              data['location_country_code']!, _locationCountryCodeMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Item map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Item(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      definitionId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}definition_id'])!,
      affixesJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}affixes_json'])!,
      acquiredAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}acquired_at'])!,
      acquiredInCellId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}acquired_in_cell_id']),
      dailySeed: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}daily_seed']),
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      badgesJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}badges_json'])!,
      parentAId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}parent_a_id']),
      parentBId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}parent_b_id']),
      displayName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}display_name'])!,
      scientificName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}scientific_name']),
      categoryName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category_name'])!,
      rarityName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}rarity_name']),
      habitatsJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}habitats_json'])!,
      continentsJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}continents_json'])!,
      taxonomicClass: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}taxonomic_class']),
      animalClassName: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}animal_class_name']),
      foodPreferenceName: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}food_preference_name']),
      climateName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}climate_name']),
      brawn: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}brawn']),
      wit: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}wit']),
      speed: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}speed']),
      sizeName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}size_name']),
      iconUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}icon_url']),
      artUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}art_url']),
      cellHabitatName: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}cell_habitat_name']),
      cellClimateName: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}cell_climate_name']),
      cellContinentName: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}cell_continent_name']),
      locationDistrict: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}location_district']),
      locationCity: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}location_city']),
      locationState: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}location_state']),
      locationCountry: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}location_country']),
      locationCountryCode: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}location_country_code']),
    );
  }

  @override
  $ItemsTableTable createAlias(String alias) {
    return $ItemsTableTable(attachedDatabase, alias);
  }
}

class Item extends DataClass implements Insertable<Item> {
  final String id;
  final String userId;
  final String definitionId;
  final String affixesJson;
  final DateTime acquiredAt;
  final String? acquiredInCellId;
  final String? dailySeed;
  final String status;
  final String badgesJson;
  final String? parentAId;
  final String? parentBId;
  final String displayName;
  final String? scientificName;
  final String categoryName;
  final String? rarityName;
  final String habitatsJson;
  final String continentsJson;
  final String? taxonomicClass;
  final String? animalClassName;
  final String? foodPreferenceName;
  final String? climateName;
  final int? brawn;
  final int? wit;
  final int? speed;
  final String? sizeName;
  final String? iconUrl;
  final String? artUrl;
  final String? cellHabitatName;
  final String? cellClimateName;
  final String? cellContinentName;
  final String? locationDistrict;
  final String? locationCity;
  final String? locationState;
  final String? locationCountry;
  final String? locationCountryCode;
  const Item(
      {required this.id,
      required this.userId,
      required this.definitionId,
      required this.affixesJson,
      required this.acquiredAt,
      this.acquiredInCellId,
      this.dailySeed,
      required this.status,
      required this.badgesJson,
      this.parentAId,
      this.parentBId,
      required this.displayName,
      this.scientificName,
      required this.categoryName,
      this.rarityName,
      required this.habitatsJson,
      required this.continentsJson,
      this.taxonomicClass,
      this.animalClassName,
      this.foodPreferenceName,
      this.climateName,
      this.brawn,
      this.wit,
      this.speed,
      this.sizeName,
      this.iconUrl,
      this.artUrl,
      this.cellHabitatName,
      this.cellClimateName,
      this.cellContinentName,
      this.locationDistrict,
      this.locationCity,
      this.locationState,
      this.locationCountry,
      this.locationCountryCode});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['definition_id'] = Variable<String>(definitionId);
    map['affixes_json'] = Variable<String>(affixesJson);
    map['acquired_at'] = Variable<DateTime>(acquiredAt);
    if (!nullToAbsent || acquiredInCellId != null) {
      map['acquired_in_cell_id'] = Variable<String>(acquiredInCellId);
    }
    if (!nullToAbsent || dailySeed != null) {
      map['daily_seed'] = Variable<String>(dailySeed);
    }
    map['status'] = Variable<String>(status);
    map['badges_json'] = Variable<String>(badgesJson);
    if (!nullToAbsent || parentAId != null) {
      map['parent_a_id'] = Variable<String>(parentAId);
    }
    if (!nullToAbsent || parentBId != null) {
      map['parent_b_id'] = Variable<String>(parentBId);
    }
    map['display_name'] = Variable<String>(displayName);
    if (!nullToAbsent || scientificName != null) {
      map['scientific_name'] = Variable<String>(scientificName);
    }
    map['category_name'] = Variable<String>(categoryName);
    if (!nullToAbsent || rarityName != null) {
      map['rarity_name'] = Variable<String>(rarityName);
    }
    map['habitats_json'] = Variable<String>(habitatsJson);
    map['continents_json'] = Variable<String>(continentsJson);
    if (!nullToAbsent || taxonomicClass != null) {
      map['taxonomic_class'] = Variable<String>(taxonomicClass);
    }
    if (!nullToAbsent || animalClassName != null) {
      map['animal_class_name'] = Variable<String>(animalClassName);
    }
    if (!nullToAbsent || foodPreferenceName != null) {
      map['food_preference_name'] = Variable<String>(foodPreferenceName);
    }
    if (!nullToAbsent || climateName != null) {
      map['climate_name'] = Variable<String>(climateName);
    }
    if (!nullToAbsent || brawn != null) {
      map['brawn'] = Variable<int>(brawn);
    }
    if (!nullToAbsent || wit != null) {
      map['wit'] = Variable<int>(wit);
    }
    if (!nullToAbsent || speed != null) {
      map['speed'] = Variable<int>(speed);
    }
    if (!nullToAbsent || sizeName != null) {
      map['size_name'] = Variable<String>(sizeName);
    }
    if (!nullToAbsent || iconUrl != null) {
      map['icon_url'] = Variable<String>(iconUrl);
    }
    if (!nullToAbsent || artUrl != null) {
      map['art_url'] = Variable<String>(artUrl);
    }
    if (!nullToAbsent || cellHabitatName != null) {
      map['cell_habitat_name'] = Variable<String>(cellHabitatName);
    }
    if (!nullToAbsent || cellClimateName != null) {
      map['cell_climate_name'] = Variable<String>(cellClimateName);
    }
    if (!nullToAbsent || cellContinentName != null) {
      map['cell_continent_name'] = Variable<String>(cellContinentName);
    }
    if (!nullToAbsent || locationDistrict != null) {
      map['location_district'] = Variable<String>(locationDistrict);
    }
    if (!nullToAbsent || locationCity != null) {
      map['location_city'] = Variable<String>(locationCity);
    }
    if (!nullToAbsent || locationState != null) {
      map['location_state'] = Variable<String>(locationState);
    }
    if (!nullToAbsent || locationCountry != null) {
      map['location_country'] = Variable<String>(locationCountry);
    }
    if (!nullToAbsent || locationCountryCode != null) {
      map['location_country_code'] = Variable<String>(locationCountryCode);
    }
    return map;
  }

  ItemsTableCompanion toCompanion(bool nullToAbsent) {
    return ItemsTableCompanion(
      id: Value(id),
      userId: Value(userId),
      definitionId: Value(definitionId),
      affixesJson: Value(affixesJson),
      acquiredAt: Value(acquiredAt),
      acquiredInCellId: acquiredInCellId == null && nullToAbsent
          ? const Value.absent()
          : Value(acquiredInCellId),
      dailySeed: dailySeed == null && nullToAbsent
          ? const Value.absent()
          : Value(dailySeed),
      status: Value(status),
      badgesJson: Value(badgesJson),
      parentAId: parentAId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentAId),
      parentBId: parentBId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentBId),
      displayName: Value(displayName),
      scientificName: scientificName == null && nullToAbsent
          ? const Value.absent()
          : Value(scientificName),
      categoryName: Value(categoryName),
      rarityName: rarityName == null && nullToAbsent
          ? const Value.absent()
          : Value(rarityName),
      habitatsJson: Value(habitatsJson),
      continentsJson: Value(continentsJson),
      taxonomicClass: taxonomicClass == null && nullToAbsent
          ? const Value.absent()
          : Value(taxonomicClass),
      animalClassName: animalClassName == null && nullToAbsent
          ? const Value.absent()
          : Value(animalClassName),
      foodPreferenceName: foodPreferenceName == null && nullToAbsent
          ? const Value.absent()
          : Value(foodPreferenceName),
      climateName: climateName == null && nullToAbsent
          ? const Value.absent()
          : Value(climateName),
      brawn:
          brawn == null && nullToAbsent ? const Value.absent() : Value(brawn),
      wit: wit == null && nullToAbsent ? const Value.absent() : Value(wit),
      speed:
          speed == null && nullToAbsent ? const Value.absent() : Value(speed),
      sizeName: sizeName == null && nullToAbsent
          ? const Value.absent()
          : Value(sizeName),
      iconUrl: iconUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(iconUrl),
      artUrl:
          artUrl == null && nullToAbsent ? const Value.absent() : Value(artUrl),
      cellHabitatName: cellHabitatName == null && nullToAbsent
          ? const Value.absent()
          : Value(cellHabitatName),
      cellClimateName: cellClimateName == null && nullToAbsent
          ? const Value.absent()
          : Value(cellClimateName),
      cellContinentName: cellContinentName == null && nullToAbsent
          ? const Value.absent()
          : Value(cellContinentName),
      locationDistrict: locationDistrict == null && nullToAbsent
          ? const Value.absent()
          : Value(locationDistrict),
      locationCity: locationCity == null && nullToAbsent
          ? const Value.absent()
          : Value(locationCity),
      locationState: locationState == null && nullToAbsent
          ? const Value.absent()
          : Value(locationState),
      locationCountry: locationCountry == null && nullToAbsent
          ? const Value.absent()
          : Value(locationCountry),
      locationCountryCode: locationCountryCode == null && nullToAbsent
          ? const Value.absent()
          : Value(locationCountryCode),
    );
  }

  factory Item.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Item(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      definitionId: serializer.fromJson<String>(json['definitionId']),
      affixesJson: serializer.fromJson<String>(json['affixesJson']),
      acquiredAt: serializer.fromJson<DateTime>(json['acquiredAt']),
      acquiredInCellId: serializer.fromJson<String?>(json['acquiredInCellId']),
      dailySeed: serializer.fromJson<String?>(json['dailySeed']),
      status: serializer.fromJson<String>(json['status']),
      badgesJson: serializer.fromJson<String>(json['badgesJson']),
      parentAId: serializer.fromJson<String?>(json['parentAId']),
      parentBId: serializer.fromJson<String?>(json['parentBId']),
      displayName: serializer.fromJson<String>(json['displayName']),
      scientificName: serializer.fromJson<String?>(json['scientificName']),
      categoryName: serializer.fromJson<String>(json['categoryName']),
      rarityName: serializer.fromJson<String?>(json['rarityName']),
      habitatsJson: serializer.fromJson<String>(json['habitatsJson']),
      continentsJson: serializer.fromJson<String>(json['continentsJson']),
      taxonomicClass: serializer.fromJson<String?>(json['taxonomicClass']),
      animalClassName: serializer.fromJson<String?>(json['animalClassName']),
      foodPreferenceName:
          serializer.fromJson<String?>(json['foodPreferenceName']),
      climateName: serializer.fromJson<String?>(json['climateName']),
      brawn: serializer.fromJson<int?>(json['brawn']),
      wit: serializer.fromJson<int?>(json['wit']),
      speed: serializer.fromJson<int?>(json['speed']),
      sizeName: serializer.fromJson<String?>(json['sizeName']),
      iconUrl: serializer.fromJson<String?>(json['iconUrl']),
      artUrl: serializer.fromJson<String?>(json['artUrl']),
      cellHabitatName: serializer.fromJson<String?>(json['cellHabitatName']),
      cellClimateName: serializer.fromJson<String?>(json['cellClimateName']),
      cellContinentName:
          serializer.fromJson<String?>(json['cellContinentName']),
      locationDistrict: serializer.fromJson<String?>(json['locationDistrict']),
      locationCity: serializer.fromJson<String?>(json['locationCity']),
      locationState: serializer.fromJson<String?>(json['locationState']),
      locationCountry: serializer.fromJson<String?>(json['locationCountry']),
      locationCountryCode:
          serializer.fromJson<String?>(json['locationCountryCode']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'definitionId': serializer.toJson<String>(definitionId),
      'affixesJson': serializer.toJson<String>(affixesJson),
      'acquiredAt': serializer.toJson<DateTime>(acquiredAt),
      'acquiredInCellId': serializer.toJson<String?>(acquiredInCellId),
      'dailySeed': serializer.toJson<String?>(dailySeed),
      'status': serializer.toJson<String>(status),
      'badgesJson': serializer.toJson<String>(badgesJson),
      'parentAId': serializer.toJson<String?>(parentAId),
      'parentBId': serializer.toJson<String?>(parentBId),
      'displayName': serializer.toJson<String>(displayName),
      'scientificName': serializer.toJson<String?>(scientificName),
      'categoryName': serializer.toJson<String>(categoryName),
      'rarityName': serializer.toJson<String?>(rarityName),
      'habitatsJson': serializer.toJson<String>(habitatsJson),
      'continentsJson': serializer.toJson<String>(continentsJson),
      'taxonomicClass': serializer.toJson<String?>(taxonomicClass),
      'animalClassName': serializer.toJson<String?>(animalClassName),
      'foodPreferenceName': serializer.toJson<String?>(foodPreferenceName),
      'climateName': serializer.toJson<String?>(climateName),
      'brawn': serializer.toJson<int?>(brawn),
      'wit': serializer.toJson<int?>(wit),
      'speed': serializer.toJson<int?>(speed),
      'sizeName': serializer.toJson<String?>(sizeName),
      'iconUrl': serializer.toJson<String?>(iconUrl),
      'artUrl': serializer.toJson<String?>(artUrl),
      'cellHabitatName': serializer.toJson<String?>(cellHabitatName),
      'cellClimateName': serializer.toJson<String?>(cellClimateName),
      'cellContinentName': serializer.toJson<String?>(cellContinentName),
      'locationDistrict': serializer.toJson<String?>(locationDistrict),
      'locationCity': serializer.toJson<String?>(locationCity),
      'locationState': serializer.toJson<String?>(locationState),
      'locationCountry': serializer.toJson<String?>(locationCountry),
      'locationCountryCode': serializer.toJson<String?>(locationCountryCode),
    };
  }

  Item copyWith(
          {String? id,
          String? userId,
          String? definitionId,
          String? affixesJson,
          DateTime? acquiredAt,
          Value<String?> acquiredInCellId = const Value.absent(),
          Value<String?> dailySeed = const Value.absent(),
          String? status,
          String? badgesJson,
          Value<String?> parentAId = const Value.absent(),
          Value<String?> parentBId = const Value.absent(),
          String? displayName,
          Value<String?> scientificName = const Value.absent(),
          String? categoryName,
          Value<String?> rarityName = const Value.absent(),
          String? habitatsJson,
          String? continentsJson,
          Value<String?> taxonomicClass = const Value.absent(),
          Value<String?> animalClassName = const Value.absent(),
          Value<String?> foodPreferenceName = const Value.absent(),
          Value<String?> climateName = const Value.absent(),
          Value<int?> brawn = const Value.absent(),
          Value<int?> wit = const Value.absent(),
          Value<int?> speed = const Value.absent(),
          Value<String?> sizeName = const Value.absent(),
          Value<String?> iconUrl = const Value.absent(),
          Value<String?> artUrl = const Value.absent(),
          Value<String?> cellHabitatName = const Value.absent(),
          Value<String?> cellClimateName = const Value.absent(),
          Value<String?> cellContinentName = const Value.absent(),
          Value<String?> locationDistrict = const Value.absent(),
          Value<String?> locationCity = const Value.absent(),
          Value<String?> locationState = const Value.absent(),
          Value<String?> locationCountry = const Value.absent(),
          Value<String?> locationCountryCode = const Value.absent()}) =>
      Item(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        definitionId: definitionId ?? this.definitionId,
        affixesJson: affixesJson ?? this.affixesJson,
        acquiredAt: acquiredAt ?? this.acquiredAt,
        acquiredInCellId: acquiredInCellId.present
            ? acquiredInCellId.value
            : this.acquiredInCellId,
        dailySeed: dailySeed.present ? dailySeed.value : this.dailySeed,
        status: status ?? this.status,
        badgesJson: badgesJson ?? this.badgesJson,
        parentAId: parentAId.present ? parentAId.value : this.parentAId,
        parentBId: parentBId.present ? parentBId.value : this.parentBId,
        displayName: displayName ?? this.displayName,
        scientificName:
            scientificName.present ? scientificName.value : this.scientificName,
        categoryName: categoryName ?? this.categoryName,
        rarityName: rarityName.present ? rarityName.value : this.rarityName,
        habitatsJson: habitatsJson ?? this.habitatsJson,
        continentsJson: continentsJson ?? this.continentsJson,
        taxonomicClass:
            taxonomicClass.present ? taxonomicClass.value : this.taxonomicClass,
        animalClassName: animalClassName.present
            ? animalClassName.value
            : this.animalClassName,
        foodPreferenceName: foodPreferenceName.present
            ? foodPreferenceName.value
            : this.foodPreferenceName,
        climateName: climateName.present ? climateName.value : this.climateName,
        brawn: brawn.present ? brawn.value : this.brawn,
        wit: wit.present ? wit.value : this.wit,
        speed: speed.present ? speed.value : this.speed,
        sizeName: sizeName.present ? sizeName.value : this.sizeName,
        iconUrl: iconUrl.present ? iconUrl.value : this.iconUrl,
        artUrl: artUrl.present ? artUrl.value : this.artUrl,
        cellHabitatName: cellHabitatName.present
            ? cellHabitatName.value
            : this.cellHabitatName,
        cellClimateName: cellClimateName.present
            ? cellClimateName.value
            : this.cellClimateName,
        cellContinentName: cellContinentName.present
            ? cellContinentName.value
            : this.cellContinentName,
        locationDistrict: locationDistrict.present
            ? locationDistrict.value
            : this.locationDistrict,
        locationCity:
            locationCity.present ? locationCity.value : this.locationCity,
        locationState:
            locationState.present ? locationState.value : this.locationState,
        locationCountry: locationCountry.present
            ? locationCountry.value
            : this.locationCountry,
        locationCountryCode: locationCountryCode.present
            ? locationCountryCode.value
            : this.locationCountryCode,
      );
  Item copyWithCompanion(ItemsTableCompanion data) {
    return Item(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      definitionId: data.definitionId.present
          ? data.definitionId.value
          : this.definitionId,
      affixesJson:
          data.affixesJson.present ? data.affixesJson.value : this.affixesJson,
      acquiredAt:
          data.acquiredAt.present ? data.acquiredAt.value : this.acquiredAt,
      acquiredInCellId: data.acquiredInCellId.present
          ? data.acquiredInCellId.value
          : this.acquiredInCellId,
      dailySeed: data.dailySeed.present ? data.dailySeed.value : this.dailySeed,
      status: data.status.present ? data.status.value : this.status,
      badgesJson:
          data.badgesJson.present ? data.badgesJson.value : this.badgesJson,
      parentAId: data.parentAId.present ? data.parentAId.value : this.parentAId,
      parentBId: data.parentBId.present ? data.parentBId.value : this.parentBId,
      displayName:
          data.displayName.present ? data.displayName.value : this.displayName,
      scientificName: data.scientificName.present
          ? data.scientificName.value
          : this.scientificName,
      categoryName: data.categoryName.present
          ? data.categoryName.value
          : this.categoryName,
      rarityName:
          data.rarityName.present ? data.rarityName.value : this.rarityName,
      habitatsJson: data.habitatsJson.present
          ? data.habitatsJson.value
          : this.habitatsJson,
      continentsJson: data.continentsJson.present
          ? data.continentsJson.value
          : this.continentsJson,
      taxonomicClass: data.taxonomicClass.present
          ? data.taxonomicClass.value
          : this.taxonomicClass,
      animalClassName: data.animalClassName.present
          ? data.animalClassName.value
          : this.animalClassName,
      foodPreferenceName: data.foodPreferenceName.present
          ? data.foodPreferenceName.value
          : this.foodPreferenceName,
      climateName:
          data.climateName.present ? data.climateName.value : this.climateName,
      brawn: data.brawn.present ? data.brawn.value : this.brawn,
      wit: data.wit.present ? data.wit.value : this.wit,
      speed: data.speed.present ? data.speed.value : this.speed,
      sizeName: data.sizeName.present ? data.sizeName.value : this.sizeName,
      iconUrl: data.iconUrl.present ? data.iconUrl.value : this.iconUrl,
      artUrl: data.artUrl.present ? data.artUrl.value : this.artUrl,
      cellHabitatName: data.cellHabitatName.present
          ? data.cellHabitatName.value
          : this.cellHabitatName,
      cellClimateName: data.cellClimateName.present
          ? data.cellClimateName.value
          : this.cellClimateName,
      cellContinentName: data.cellContinentName.present
          ? data.cellContinentName.value
          : this.cellContinentName,
      locationDistrict: data.locationDistrict.present
          ? data.locationDistrict.value
          : this.locationDistrict,
      locationCity: data.locationCity.present
          ? data.locationCity.value
          : this.locationCity,
      locationState: data.locationState.present
          ? data.locationState.value
          : this.locationState,
      locationCountry: data.locationCountry.present
          ? data.locationCountry.value
          : this.locationCountry,
      locationCountryCode: data.locationCountryCode.present
          ? data.locationCountryCode.value
          : this.locationCountryCode,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Item(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('definitionId: $definitionId, ')
          ..write('affixesJson: $affixesJson, ')
          ..write('acquiredAt: $acquiredAt, ')
          ..write('acquiredInCellId: $acquiredInCellId, ')
          ..write('dailySeed: $dailySeed, ')
          ..write('status: $status, ')
          ..write('badgesJson: $badgesJson, ')
          ..write('parentAId: $parentAId, ')
          ..write('parentBId: $parentBId, ')
          ..write('displayName: $displayName, ')
          ..write('scientificName: $scientificName, ')
          ..write('categoryName: $categoryName, ')
          ..write('rarityName: $rarityName, ')
          ..write('habitatsJson: $habitatsJson, ')
          ..write('continentsJson: $continentsJson, ')
          ..write('taxonomicClass: $taxonomicClass, ')
          ..write('animalClassName: $animalClassName, ')
          ..write('foodPreferenceName: $foodPreferenceName, ')
          ..write('climateName: $climateName, ')
          ..write('brawn: $brawn, ')
          ..write('wit: $wit, ')
          ..write('speed: $speed, ')
          ..write('sizeName: $sizeName, ')
          ..write('iconUrl: $iconUrl, ')
          ..write('artUrl: $artUrl, ')
          ..write('cellHabitatName: $cellHabitatName, ')
          ..write('cellClimateName: $cellClimateName, ')
          ..write('cellContinentName: $cellContinentName, ')
          ..write('locationDistrict: $locationDistrict, ')
          ..write('locationCity: $locationCity, ')
          ..write('locationState: $locationState, ')
          ..write('locationCountry: $locationCountry, ')
          ..write('locationCountryCode: $locationCountryCode')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
        id,
        userId,
        definitionId,
        affixesJson,
        acquiredAt,
        acquiredInCellId,
        dailySeed,
        status,
        badgesJson,
        parentAId,
        parentBId,
        displayName,
        scientificName,
        categoryName,
        rarityName,
        habitatsJson,
        continentsJson,
        taxonomicClass,
        animalClassName,
        foodPreferenceName,
        climateName,
        brawn,
        wit,
        speed,
        sizeName,
        iconUrl,
        artUrl,
        cellHabitatName,
        cellClimateName,
        cellContinentName,
        locationDistrict,
        locationCity,
        locationState,
        locationCountry,
        locationCountryCode
      ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Item &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.definitionId == this.definitionId &&
          other.affixesJson == this.affixesJson &&
          other.acquiredAt == this.acquiredAt &&
          other.acquiredInCellId == this.acquiredInCellId &&
          other.dailySeed == this.dailySeed &&
          other.status == this.status &&
          other.badgesJson == this.badgesJson &&
          other.parentAId == this.parentAId &&
          other.parentBId == this.parentBId &&
          other.displayName == this.displayName &&
          other.scientificName == this.scientificName &&
          other.categoryName == this.categoryName &&
          other.rarityName == this.rarityName &&
          other.habitatsJson == this.habitatsJson &&
          other.continentsJson == this.continentsJson &&
          other.taxonomicClass == this.taxonomicClass &&
          other.animalClassName == this.animalClassName &&
          other.foodPreferenceName == this.foodPreferenceName &&
          other.climateName == this.climateName &&
          other.brawn == this.brawn &&
          other.wit == this.wit &&
          other.speed == this.speed &&
          other.sizeName == this.sizeName &&
          other.iconUrl == this.iconUrl &&
          other.artUrl == this.artUrl &&
          other.cellHabitatName == this.cellHabitatName &&
          other.cellClimateName == this.cellClimateName &&
          other.cellContinentName == this.cellContinentName &&
          other.locationDistrict == this.locationDistrict &&
          other.locationCity == this.locationCity &&
          other.locationState == this.locationState &&
          other.locationCountry == this.locationCountry &&
          other.locationCountryCode == this.locationCountryCode);
}

class ItemsTableCompanion extends UpdateCompanion<Item> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> definitionId;
  final Value<String> affixesJson;
  final Value<DateTime> acquiredAt;
  final Value<String?> acquiredInCellId;
  final Value<String?> dailySeed;
  final Value<String> status;
  final Value<String> badgesJson;
  final Value<String?> parentAId;
  final Value<String?> parentBId;
  final Value<String> displayName;
  final Value<String?> scientificName;
  final Value<String> categoryName;
  final Value<String?> rarityName;
  final Value<String> habitatsJson;
  final Value<String> continentsJson;
  final Value<String?> taxonomicClass;
  final Value<String?> animalClassName;
  final Value<String?> foodPreferenceName;
  final Value<String?> climateName;
  final Value<int?> brawn;
  final Value<int?> wit;
  final Value<int?> speed;
  final Value<String?> sizeName;
  final Value<String?> iconUrl;
  final Value<String?> artUrl;
  final Value<String?> cellHabitatName;
  final Value<String?> cellClimateName;
  final Value<String?> cellContinentName;
  final Value<String?> locationDistrict;
  final Value<String?> locationCity;
  final Value<String?> locationState;
  final Value<String?> locationCountry;
  final Value<String?> locationCountryCode;
  final Value<int> rowid;
  const ItemsTableCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.definitionId = const Value.absent(),
    this.affixesJson = const Value.absent(),
    this.acquiredAt = const Value.absent(),
    this.acquiredInCellId = const Value.absent(),
    this.dailySeed = const Value.absent(),
    this.status = const Value.absent(),
    this.badgesJson = const Value.absent(),
    this.parentAId = const Value.absent(),
    this.parentBId = const Value.absent(),
    this.displayName = const Value.absent(),
    this.scientificName = const Value.absent(),
    this.categoryName = const Value.absent(),
    this.rarityName = const Value.absent(),
    this.habitatsJson = const Value.absent(),
    this.continentsJson = const Value.absent(),
    this.taxonomicClass = const Value.absent(),
    this.animalClassName = const Value.absent(),
    this.foodPreferenceName = const Value.absent(),
    this.climateName = const Value.absent(),
    this.brawn = const Value.absent(),
    this.wit = const Value.absent(),
    this.speed = const Value.absent(),
    this.sizeName = const Value.absent(),
    this.iconUrl = const Value.absent(),
    this.artUrl = const Value.absent(),
    this.cellHabitatName = const Value.absent(),
    this.cellClimateName = const Value.absent(),
    this.cellContinentName = const Value.absent(),
    this.locationDistrict = const Value.absent(),
    this.locationCity = const Value.absent(),
    this.locationState = const Value.absent(),
    this.locationCountry = const Value.absent(),
    this.locationCountryCode = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ItemsTableCompanion.insert({
    required String id,
    required String userId,
    required String definitionId,
    this.affixesJson = const Value.absent(),
    required DateTime acquiredAt,
    this.acquiredInCellId = const Value.absent(),
    this.dailySeed = const Value.absent(),
    this.status = const Value.absent(),
    this.badgesJson = const Value.absent(),
    this.parentAId = const Value.absent(),
    this.parentBId = const Value.absent(),
    this.displayName = const Value.absent(),
    this.scientificName = const Value.absent(),
    this.categoryName = const Value.absent(),
    this.rarityName = const Value.absent(),
    this.habitatsJson = const Value.absent(),
    this.continentsJson = const Value.absent(),
    this.taxonomicClass = const Value.absent(),
    this.animalClassName = const Value.absent(),
    this.foodPreferenceName = const Value.absent(),
    this.climateName = const Value.absent(),
    this.brawn = const Value.absent(),
    this.wit = const Value.absent(),
    this.speed = const Value.absent(),
    this.sizeName = const Value.absent(),
    this.iconUrl = const Value.absent(),
    this.artUrl = const Value.absent(),
    this.cellHabitatName = const Value.absent(),
    this.cellClimateName = const Value.absent(),
    this.cellContinentName = const Value.absent(),
    this.locationDistrict = const Value.absent(),
    this.locationCity = const Value.absent(),
    this.locationState = const Value.absent(),
    this.locationCountry = const Value.absent(),
    this.locationCountryCode = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        userId = Value(userId),
        definitionId = Value(definitionId),
        acquiredAt = Value(acquiredAt);
  static Insertable<Item> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? definitionId,
    Expression<String>? affixesJson,
    Expression<DateTime>? acquiredAt,
    Expression<String>? acquiredInCellId,
    Expression<String>? dailySeed,
    Expression<String>? status,
    Expression<String>? badgesJson,
    Expression<String>? parentAId,
    Expression<String>? parentBId,
    Expression<String>? displayName,
    Expression<String>? scientificName,
    Expression<String>? categoryName,
    Expression<String>? rarityName,
    Expression<String>? habitatsJson,
    Expression<String>? continentsJson,
    Expression<String>? taxonomicClass,
    Expression<String>? animalClassName,
    Expression<String>? foodPreferenceName,
    Expression<String>? climateName,
    Expression<int>? brawn,
    Expression<int>? wit,
    Expression<int>? speed,
    Expression<String>? sizeName,
    Expression<String>? iconUrl,
    Expression<String>? artUrl,
    Expression<String>? cellHabitatName,
    Expression<String>? cellClimateName,
    Expression<String>? cellContinentName,
    Expression<String>? locationDistrict,
    Expression<String>? locationCity,
    Expression<String>? locationState,
    Expression<String>? locationCountry,
    Expression<String>? locationCountryCode,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (definitionId != null) 'definition_id': definitionId,
      if (affixesJson != null) 'affixes_json': affixesJson,
      if (acquiredAt != null) 'acquired_at': acquiredAt,
      if (acquiredInCellId != null) 'acquired_in_cell_id': acquiredInCellId,
      if (dailySeed != null) 'daily_seed': dailySeed,
      if (status != null) 'status': status,
      if (badgesJson != null) 'badges_json': badgesJson,
      if (parentAId != null) 'parent_a_id': parentAId,
      if (parentBId != null) 'parent_b_id': parentBId,
      if (displayName != null) 'display_name': displayName,
      if (scientificName != null) 'scientific_name': scientificName,
      if (categoryName != null) 'category_name': categoryName,
      if (rarityName != null) 'rarity_name': rarityName,
      if (habitatsJson != null) 'habitats_json': habitatsJson,
      if (continentsJson != null) 'continents_json': continentsJson,
      if (taxonomicClass != null) 'taxonomic_class': taxonomicClass,
      if (animalClassName != null) 'animal_class_name': animalClassName,
      if (foodPreferenceName != null)
        'food_preference_name': foodPreferenceName,
      if (climateName != null) 'climate_name': climateName,
      if (brawn != null) 'brawn': brawn,
      if (wit != null) 'wit': wit,
      if (speed != null) 'speed': speed,
      if (sizeName != null) 'size_name': sizeName,
      if (iconUrl != null) 'icon_url': iconUrl,
      if (artUrl != null) 'art_url': artUrl,
      if (cellHabitatName != null) 'cell_habitat_name': cellHabitatName,
      if (cellClimateName != null) 'cell_climate_name': cellClimateName,
      if (cellContinentName != null) 'cell_continent_name': cellContinentName,
      if (locationDistrict != null) 'location_district': locationDistrict,
      if (locationCity != null) 'location_city': locationCity,
      if (locationState != null) 'location_state': locationState,
      if (locationCountry != null) 'location_country': locationCountry,
      if (locationCountryCode != null)
        'location_country_code': locationCountryCode,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ItemsTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? userId,
      Value<String>? definitionId,
      Value<String>? affixesJson,
      Value<DateTime>? acquiredAt,
      Value<String?>? acquiredInCellId,
      Value<String?>? dailySeed,
      Value<String>? status,
      Value<String>? badgesJson,
      Value<String?>? parentAId,
      Value<String?>? parentBId,
      Value<String>? displayName,
      Value<String?>? scientificName,
      Value<String>? categoryName,
      Value<String?>? rarityName,
      Value<String>? habitatsJson,
      Value<String>? continentsJson,
      Value<String?>? taxonomicClass,
      Value<String?>? animalClassName,
      Value<String?>? foodPreferenceName,
      Value<String?>? climateName,
      Value<int?>? brawn,
      Value<int?>? wit,
      Value<int?>? speed,
      Value<String?>? sizeName,
      Value<String?>? iconUrl,
      Value<String?>? artUrl,
      Value<String?>? cellHabitatName,
      Value<String?>? cellClimateName,
      Value<String?>? cellContinentName,
      Value<String?>? locationDistrict,
      Value<String?>? locationCity,
      Value<String?>? locationState,
      Value<String?>? locationCountry,
      Value<String?>? locationCountryCode,
      Value<int>? rowid}) {
    return ItemsTableCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      definitionId: definitionId ?? this.definitionId,
      affixesJson: affixesJson ?? this.affixesJson,
      acquiredAt: acquiredAt ?? this.acquiredAt,
      acquiredInCellId: acquiredInCellId ?? this.acquiredInCellId,
      dailySeed: dailySeed ?? this.dailySeed,
      status: status ?? this.status,
      badgesJson: badgesJson ?? this.badgesJson,
      parentAId: parentAId ?? this.parentAId,
      parentBId: parentBId ?? this.parentBId,
      displayName: displayName ?? this.displayName,
      scientificName: scientificName ?? this.scientificName,
      categoryName: categoryName ?? this.categoryName,
      rarityName: rarityName ?? this.rarityName,
      habitatsJson: habitatsJson ?? this.habitatsJson,
      continentsJson: continentsJson ?? this.continentsJson,
      taxonomicClass: taxonomicClass ?? this.taxonomicClass,
      animalClassName: animalClassName ?? this.animalClassName,
      foodPreferenceName: foodPreferenceName ?? this.foodPreferenceName,
      climateName: climateName ?? this.climateName,
      brawn: brawn ?? this.brawn,
      wit: wit ?? this.wit,
      speed: speed ?? this.speed,
      sizeName: sizeName ?? this.sizeName,
      iconUrl: iconUrl ?? this.iconUrl,
      artUrl: artUrl ?? this.artUrl,
      cellHabitatName: cellHabitatName ?? this.cellHabitatName,
      cellClimateName: cellClimateName ?? this.cellClimateName,
      cellContinentName: cellContinentName ?? this.cellContinentName,
      locationDistrict: locationDistrict ?? this.locationDistrict,
      locationCity: locationCity ?? this.locationCity,
      locationState: locationState ?? this.locationState,
      locationCountry: locationCountry ?? this.locationCountry,
      locationCountryCode: locationCountryCode ?? this.locationCountryCode,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (definitionId.present) {
      map['definition_id'] = Variable<String>(definitionId.value);
    }
    if (affixesJson.present) {
      map['affixes_json'] = Variable<String>(affixesJson.value);
    }
    if (acquiredAt.present) {
      map['acquired_at'] = Variable<DateTime>(acquiredAt.value);
    }
    if (acquiredInCellId.present) {
      map['acquired_in_cell_id'] = Variable<String>(acquiredInCellId.value);
    }
    if (dailySeed.present) {
      map['daily_seed'] = Variable<String>(dailySeed.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (badgesJson.present) {
      map['badges_json'] = Variable<String>(badgesJson.value);
    }
    if (parentAId.present) {
      map['parent_a_id'] = Variable<String>(parentAId.value);
    }
    if (parentBId.present) {
      map['parent_b_id'] = Variable<String>(parentBId.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (scientificName.present) {
      map['scientific_name'] = Variable<String>(scientificName.value);
    }
    if (categoryName.present) {
      map['category_name'] = Variable<String>(categoryName.value);
    }
    if (rarityName.present) {
      map['rarity_name'] = Variable<String>(rarityName.value);
    }
    if (habitatsJson.present) {
      map['habitats_json'] = Variable<String>(habitatsJson.value);
    }
    if (continentsJson.present) {
      map['continents_json'] = Variable<String>(continentsJson.value);
    }
    if (taxonomicClass.present) {
      map['taxonomic_class'] = Variable<String>(taxonomicClass.value);
    }
    if (animalClassName.present) {
      map['animal_class_name'] = Variable<String>(animalClassName.value);
    }
    if (foodPreferenceName.present) {
      map['food_preference_name'] = Variable<String>(foodPreferenceName.value);
    }
    if (climateName.present) {
      map['climate_name'] = Variable<String>(climateName.value);
    }
    if (brawn.present) {
      map['brawn'] = Variable<int>(brawn.value);
    }
    if (wit.present) {
      map['wit'] = Variable<int>(wit.value);
    }
    if (speed.present) {
      map['speed'] = Variable<int>(speed.value);
    }
    if (sizeName.present) {
      map['size_name'] = Variable<String>(sizeName.value);
    }
    if (iconUrl.present) {
      map['icon_url'] = Variable<String>(iconUrl.value);
    }
    if (artUrl.present) {
      map['art_url'] = Variable<String>(artUrl.value);
    }
    if (cellHabitatName.present) {
      map['cell_habitat_name'] = Variable<String>(cellHabitatName.value);
    }
    if (cellClimateName.present) {
      map['cell_climate_name'] = Variable<String>(cellClimateName.value);
    }
    if (cellContinentName.present) {
      map['cell_continent_name'] = Variable<String>(cellContinentName.value);
    }
    if (locationDistrict.present) {
      map['location_district'] = Variable<String>(locationDistrict.value);
    }
    if (locationCity.present) {
      map['location_city'] = Variable<String>(locationCity.value);
    }
    if (locationState.present) {
      map['location_state'] = Variable<String>(locationState.value);
    }
    if (locationCountry.present) {
      map['location_country'] = Variable<String>(locationCountry.value);
    }
    if (locationCountryCode.present) {
      map['location_country_code'] =
          Variable<String>(locationCountryCode.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ItemsTableCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('definitionId: $definitionId, ')
          ..write('affixesJson: $affixesJson, ')
          ..write('acquiredAt: $acquiredAt, ')
          ..write('acquiredInCellId: $acquiredInCellId, ')
          ..write('dailySeed: $dailySeed, ')
          ..write('status: $status, ')
          ..write('badgesJson: $badgesJson, ')
          ..write('parentAId: $parentAId, ')
          ..write('parentBId: $parentBId, ')
          ..write('displayName: $displayName, ')
          ..write('scientificName: $scientificName, ')
          ..write('categoryName: $categoryName, ')
          ..write('rarityName: $rarityName, ')
          ..write('habitatsJson: $habitatsJson, ')
          ..write('continentsJson: $continentsJson, ')
          ..write('taxonomicClass: $taxonomicClass, ')
          ..write('animalClassName: $animalClassName, ')
          ..write('foodPreferenceName: $foodPreferenceName, ')
          ..write('climateName: $climateName, ')
          ..write('brawn: $brawn, ')
          ..write('wit: $wit, ')
          ..write('speed: $speed, ')
          ..write('sizeName: $sizeName, ')
          ..write('iconUrl: $iconUrl, ')
          ..write('artUrl: $artUrl, ')
          ..write('cellHabitatName: $cellHabitatName, ')
          ..write('cellClimateName: $cellClimateName, ')
          ..write('cellContinentName: $cellContinentName, ')
          ..write('locationDistrict: $locationDistrict, ')
          ..write('locationCity: $locationCity, ')
          ..write('locationState: $locationState, ')
          ..write('locationCountry: $locationCountry, ')
          ..write('locationCountryCode: $locationCountryCode, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CellVisitsTableTable extends CellVisitsTable
    with TableInfo<$CellVisitsTableTable, CellVisit> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CellVisitsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _cellIdMeta = const VerificationMeta('cellId');
  @override
  late final GeneratedColumn<String> cellId = GeneratedColumn<String>(
      'cell_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _visitCountMeta =
      const VerificationMeta('visitCount');
  @override
  late final GeneratedColumn<int> visitCount = GeneratedColumn<int>(
      'visit_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _distanceWalkedMeta =
      const VerificationMeta('distanceWalked');
  @override
  late final GeneratedColumn<double> distanceWalked = GeneratedColumn<double>(
      'distance_walked', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _lastVisitedMeta =
      const VerificationMeta('lastVisited');
  @override
  late final GeneratedColumn<DateTime> lastVisited = GeneratedColumn<DateTime>(
      'last_visited', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [userId, cellId, visitCount, distanceWalked, lastVisited, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cell_visits_table';
  @override
  VerificationContext validateIntegrity(Insertable<CellVisit> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('cell_id')) {
      context.handle(_cellIdMeta,
          cellId.isAcceptableOrUnknown(data['cell_id']!, _cellIdMeta));
    } else if (isInserting) {
      context.missing(_cellIdMeta);
    }
    if (data.containsKey('visit_count')) {
      context.handle(
          _visitCountMeta,
          visitCount.isAcceptableOrUnknown(
              data['visit_count']!, _visitCountMeta));
    }
    if (data.containsKey('distance_walked')) {
      context.handle(
          _distanceWalkedMeta,
          distanceWalked.isAcceptableOrUnknown(
              data['distance_walked']!, _distanceWalkedMeta));
    }
    if (data.containsKey('last_visited')) {
      context.handle(
          _lastVisitedMeta,
          lastVisited.isAcceptableOrUnknown(
              data['last_visited']!, _lastVisitedMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId, cellId};
  @override
  CellVisit map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CellVisit(
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      cellId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cell_id'])!,
      visitCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}visit_count'])!,
      distanceWalked: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}distance_walked'])!,
      lastVisited: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}last_visited']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $CellVisitsTableTable createAlias(String alias) {
    return $CellVisitsTableTable(attachedDatabase, alias);
  }
}

class CellVisit extends DataClass implements Insertable<CellVisit> {
  final String userId;
  final String cellId;
  final int visitCount;
  final double distanceWalked;
  final DateTime? lastVisited;
  final DateTime createdAt;
  const CellVisit(
      {required this.userId,
      required this.cellId,
      required this.visitCount,
      required this.distanceWalked,
      this.lastVisited,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['cell_id'] = Variable<String>(cellId);
    map['visit_count'] = Variable<int>(visitCount);
    map['distance_walked'] = Variable<double>(distanceWalked);
    if (!nullToAbsent || lastVisited != null) {
      map['last_visited'] = Variable<DateTime>(lastVisited);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  CellVisitsTableCompanion toCompanion(bool nullToAbsent) {
    return CellVisitsTableCompanion(
      userId: Value(userId),
      cellId: Value(cellId),
      visitCount: Value(visitCount),
      distanceWalked: Value(distanceWalked),
      lastVisited: lastVisited == null && nullToAbsent
          ? const Value.absent()
          : Value(lastVisited),
      createdAt: Value(createdAt),
    );
  }

  factory CellVisit.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CellVisit(
      userId: serializer.fromJson<String>(json['userId']),
      cellId: serializer.fromJson<String>(json['cellId']),
      visitCount: serializer.fromJson<int>(json['visitCount']),
      distanceWalked: serializer.fromJson<double>(json['distanceWalked']),
      lastVisited: serializer.fromJson<DateTime?>(json['lastVisited']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'cellId': serializer.toJson<String>(cellId),
      'visitCount': serializer.toJson<int>(visitCount),
      'distanceWalked': serializer.toJson<double>(distanceWalked),
      'lastVisited': serializer.toJson<DateTime?>(lastVisited),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  CellVisit copyWith(
          {String? userId,
          String? cellId,
          int? visitCount,
          double? distanceWalked,
          Value<DateTime?> lastVisited = const Value.absent(),
          DateTime? createdAt}) =>
      CellVisit(
        userId: userId ?? this.userId,
        cellId: cellId ?? this.cellId,
        visitCount: visitCount ?? this.visitCount,
        distanceWalked: distanceWalked ?? this.distanceWalked,
        lastVisited: lastVisited.present ? lastVisited.value : this.lastVisited,
        createdAt: createdAt ?? this.createdAt,
      );
  CellVisit copyWithCompanion(CellVisitsTableCompanion data) {
    return CellVisit(
      userId: data.userId.present ? data.userId.value : this.userId,
      cellId: data.cellId.present ? data.cellId.value : this.cellId,
      visitCount:
          data.visitCount.present ? data.visitCount.value : this.visitCount,
      distanceWalked: data.distanceWalked.present
          ? data.distanceWalked.value
          : this.distanceWalked,
      lastVisited:
          data.lastVisited.present ? data.lastVisited.value : this.lastVisited,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CellVisit(')
          ..write('userId: $userId, ')
          ..write('cellId: $cellId, ')
          ..write('visitCount: $visitCount, ')
          ..write('distanceWalked: $distanceWalked, ')
          ..write('lastVisited: $lastVisited, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      userId, cellId, visitCount, distanceWalked, lastVisited, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CellVisit &&
          other.userId == this.userId &&
          other.cellId == this.cellId &&
          other.visitCount == this.visitCount &&
          other.distanceWalked == this.distanceWalked &&
          other.lastVisited == this.lastVisited &&
          other.createdAt == this.createdAt);
}

class CellVisitsTableCompanion extends UpdateCompanion<CellVisit> {
  final Value<String> userId;
  final Value<String> cellId;
  final Value<int> visitCount;
  final Value<double> distanceWalked;
  final Value<DateTime?> lastVisited;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const CellVisitsTableCompanion({
    this.userId = const Value.absent(),
    this.cellId = const Value.absent(),
    this.visitCount = const Value.absent(),
    this.distanceWalked = const Value.absent(),
    this.lastVisited = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CellVisitsTableCompanion.insert({
    required String userId,
    required String cellId,
    this.visitCount = const Value.absent(),
    this.distanceWalked = const Value.absent(),
    this.lastVisited = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : userId = Value(userId),
        cellId = Value(cellId);
  static Insertable<CellVisit> custom({
    Expression<String>? userId,
    Expression<String>? cellId,
    Expression<int>? visitCount,
    Expression<double>? distanceWalked,
    Expression<DateTime>? lastVisited,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (cellId != null) 'cell_id': cellId,
      if (visitCount != null) 'visit_count': visitCount,
      if (distanceWalked != null) 'distance_walked': distanceWalked,
      if (lastVisited != null) 'last_visited': lastVisited,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CellVisitsTableCompanion copyWith(
      {Value<String>? userId,
      Value<String>? cellId,
      Value<int>? visitCount,
      Value<double>? distanceWalked,
      Value<DateTime?>? lastVisited,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return CellVisitsTableCompanion(
      userId: userId ?? this.userId,
      cellId: cellId ?? this.cellId,
      visitCount: visitCount ?? this.visitCount,
      distanceWalked: distanceWalked ?? this.distanceWalked,
      lastVisited: lastVisited ?? this.lastVisited,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (cellId.present) {
      map['cell_id'] = Variable<String>(cellId.value);
    }
    if (visitCount.present) {
      map['visit_count'] = Variable<int>(visitCount.value);
    }
    if (distanceWalked.present) {
      map['distance_walked'] = Variable<double>(distanceWalked.value);
    }
    if (lastVisited.present) {
      map['last_visited'] = Variable<DateTime>(lastVisited.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CellVisitsTableCompanion(')
          ..write('userId: $userId, ')
          ..write('cellId: $cellId, ')
          ..write('visitCount: $visitCount, ')
          ..write('distanceWalked: $distanceWalked, ')
          ..write('lastVisited: $lastVisited, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CellPropertiesTableTable extends CellPropertiesTable
    with TableInfo<$CellPropertiesTableTable, CellProperty> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CellPropertiesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _cellIdMeta = const VerificationMeta('cellId');
  @override
  late final GeneratedColumn<String> cellId = GeneratedColumn<String>(
      'cell_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _habitatsJsonMeta =
      const VerificationMeta('habitatsJson');
  @override
  late final GeneratedColumn<String> habitatsJson = GeneratedColumn<String>(
      'habitats_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _climateMeta =
      const VerificationMeta('climate');
  @override
  late final GeneratedColumn<String> climate = GeneratedColumn<String>(
      'climate', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _continentMeta =
      const VerificationMeta('continent');
  @override
  late final GeneratedColumn<String> continent = GeneratedColumn<String>(
      'continent', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _locationIdMeta =
      const VerificationMeta('locationId');
  @override
  late final GeneratedColumn<String> locationId = GeneratedColumn<String>(
      'location_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [cellId, habitatsJson, climate, continent, locationId, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cell_properties_table';
  @override
  VerificationContext validateIntegrity(Insertable<CellProperty> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('cell_id')) {
      context.handle(_cellIdMeta,
          cellId.isAcceptableOrUnknown(data['cell_id']!, _cellIdMeta));
    } else if (isInserting) {
      context.missing(_cellIdMeta);
    }
    if (data.containsKey('habitats_json')) {
      context.handle(
          _habitatsJsonMeta,
          habitatsJson.isAcceptableOrUnknown(
              data['habitats_json']!, _habitatsJsonMeta));
    } else if (isInserting) {
      context.missing(_habitatsJsonMeta);
    }
    if (data.containsKey('climate')) {
      context.handle(_climateMeta,
          climate.isAcceptableOrUnknown(data['climate']!, _climateMeta));
    } else if (isInserting) {
      context.missing(_climateMeta);
    }
    if (data.containsKey('continent')) {
      context.handle(_continentMeta,
          continent.isAcceptableOrUnknown(data['continent']!, _continentMeta));
    } else if (isInserting) {
      context.missing(_continentMeta);
    }
    if (data.containsKey('location_id')) {
      context.handle(
          _locationIdMeta,
          locationId.isAcceptableOrUnknown(
              data['location_id']!, _locationIdMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {cellId};
  @override
  CellProperty map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CellProperty(
      cellId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cell_id'])!,
      habitatsJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}habitats_json'])!,
      climate: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}climate'])!,
      continent: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}continent'])!,
      locationId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}location_id']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $CellPropertiesTableTable createAlias(String alias) {
    return $CellPropertiesTableTable(attachedDatabase, alias);
  }
}

class CellProperty extends DataClass implements Insertable<CellProperty> {
  final String cellId;
  final String habitatsJson;
  final String climate;
  final String continent;
  final String? locationId;
  final DateTime createdAt;
  const CellProperty(
      {required this.cellId,
      required this.habitatsJson,
      required this.climate,
      required this.continent,
      this.locationId,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['cell_id'] = Variable<String>(cellId);
    map['habitats_json'] = Variable<String>(habitatsJson);
    map['climate'] = Variable<String>(climate);
    map['continent'] = Variable<String>(continent);
    if (!nullToAbsent || locationId != null) {
      map['location_id'] = Variable<String>(locationId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  CellPropertiesTableCompanion toCompanion(bool nullToAbsent) {
    return CellPropertiesTableCompanion(
      cellId: Value(cellId),
      habitatsJson: Value(habitatsJson),
      climate: Value(climate),
      continent: Value(continent),
      locationId: locationId == null && nullToAbsent
          ? const Value.absent()
          : Value(locationId),
      createdAt: Value(createdAt),
    );
  }

  factory CellProperty.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CellProperty(
      cellId: serializer.fromJson<String>(json['cellId']),
      habitatsJson: serializer.fromJson<String>(json['habitatsJson']),
      climate: serializer.fromJson<String>(json['climate']),
      continent: serializer.fromJson<String>(json['continent']),
      locationId: serializer.fromJson<String?>(json['locationId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'cellId': serializer.toJson<String>(cellId),
      'habitatsJson': serializer.toJson<String>(habitatsJson),
      'climate': serializer.toJson<String>(climate),
      'continent': serializer.toJson<String>(continent),
      'locationId': serializer.toJson<String?>(locationId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  CellProperty copyWith(
          {String? cellId,
          String? habitatsJson,
          String? climate,
          String? continent,
          Value<String?> locationId = const Value.absent(),
          DateTime? createdAt}) =>
      CellProperty(
        cellId: cellId ?? this.cellId,
        habitatsJson: habitatsJson ?? this.habitatsJson,
        climate: climate ?? this.climate,
        continent: continent ?? this.continent,
        locationId: locationId.present ? locationId.value : this.locationId,
        createdAt: createdAt ?? this.createdAt,
      );
  CellProperty copyWithCompanion(CellPropertiesTableCompanion data) {
    return CellProperty(
      cellId: data.cellId.present ? data.cellId.value : this.cellId,
      habitatsJson: data.habitatsJson.present
          ? data.habitatsJson.value
          : this.habitatsJson,
      climate: data.climate.present ? data.climate.value : this.climate,
      continent: data.continent.present ? data.continent.value : this.continent,
      locationId:
          data.locationId.present ? data.locationId.value : this.locationId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CellProperty(')
          ..write('cellId: $cellId, ')
          ..write('habitatsJson: $habitatsJson, ')
          ..write('climate: $climate, ')
          ..write('continent: $continent, ')
          ..write('locationId: $locationId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      cellId, habitatsJson, climate, continent, locationId, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CellProperty &&
          other.cellId == this.cellId &&
          other.habitatsJson == this.habitatsJson &&
          other.climate == this.climate &&
          other.continent == this.continent &&
          other.locationId == this.locationId &&
          other.createdAt == this.createdAt);
}

class CellPropertiesTableCompanion extends UpdateCompanion<CellProperty> {
  final Value<String> cellId;
  final Value<String> habitatsJson;
  final Value<String> climate;
  final Value<String> continent;
  final Value<String?> locationId;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const CellPropertiesTableCompanion({
    this.cellId = const Value.absent(),
    this.habitatsJson = const Value.absent(),
    this.climate = const Value.absent(),
    this.continent = const Value.absent(),
    this.locationId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CellPropertiesTableCompanion.insert({
    required String cellId,
    required String habitatsJson,
    required String climate,
    required String continent,
    this.locationId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : cellId = Value(cellId),
        habitatsJson = Value(habitatsJson),
        climate = Value(climate),
        continent = Value(continent);
  static Insertable<CellProperty> custom({
    Expression<String>? cellId,
    Expression<String>? habitatsJson,
    Expression<String>? climate,
    Expression<String>? continent,
    Expression<String>? locationId,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (cellId != null) 'cell_id': cellId,
      if (habitatsJson != null) 'habitats_json': habitatsJson,
      if (climate != null) 'climate': climate,
      if (continent != null) 'continent': continent,
      if (locationId != null) 'location_id': locationId,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CellPropertiesTableCompanion copyWith(
      {Value<String>? cellId,
      Value<String>? habitatsJson,
      Value<String>? climate,
      Value<String>? continent,
      Value<String?>? locationId,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return CellPropertiesTableCompanion(
      cellId: cellId ?? this.cellId,
      habitatsJson: habitatsJson ?? this.habitatsJson,
      climate: climate ?? this.climate,
      continent: continent ?? this.continent,
      locationId: locationId ?? this.locationId,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (cellId.present) {
      map['cell_id'] = Variable<String>(cellId.value);
    }
    if (habitatsJson.present) {
      map['habitats_json'] = Variable<String>(habitatsJson.value);
    }
    if (climate.present) {
      map['climate'] = Variable<String>(climate.value);
    }
    if (continent.present) {
      map['continent'] = Variable<String>(continent.value);
    }
    if (locationId.present) {
      map['location_id'] = Variable<String>(locationId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CellPropertiesTableCompanion(')
          ..write('cellId: $cellId, ')
          ..write('habitatsJson: $habitatsJson, ')
          ..write('climate: $climate, ')
          ..write('continent: $continent, ')
          ..write('locationId: $locationId, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CountriesTableTable extends CountriesTable
    with TableInfo<$CountriesTableTable, HierarchyCountry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CountriesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _centroidLatMeta =
      const VerificationMeta('centroidLat');
  @override
  late final GeneratedColumn<double> centroidLat = GeneratedColumn<double>(
      'centroid_lat', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _centroidLonMeta =
      const VerificationMeta('centroidLon');
  @override
  late final GeneratedColumn<double> centroidLon = GeneratedColumn<double>(
      'centroid_lon', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _continentMeta =
      const VerificationMeta('continent');
  @override
  late final GeneratedColumn<String> continent = GeneratedColumn<String>(
      'continent', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _boundaryJsonMeta =
      const VerificationMeta('boundaryJson');
  @override
  late final GeneratedColumn<String> boundaryJson = GeneratedColumn<String>(
      'boundary_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, name, centroidLat, centroidLon, continent, boundaryJson, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'countries_table';
  @override
  VerificationContext validateIntegrity(Insertable<HierarchyCountry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('centroid_lat')) {
      context.handle(
          _centroidLatMeta,
          centroidLat.isAcceptableOrUnknown(
              data['centroid_lat']!, _centroidLatMeta));
    } else if (isInserting) {
      context.missing(_centroidLatMeta);
    }
    if (data.containsKey('centroid_lon')) {
      context.handle(
          _centroidLonMeta,
          centroidLon.isAcceptableOrUnknown(
              data['centroid_lon']!, _centroidLonMeta));
    } else if (isInserting) {
      context.missing(_centroidLonMeta);
    }
    if (data.containsKey('continent')) {
      context.handle(_continentMeta,
          continent.isAcceptableOrUnknown(data['continent']!, _continentMeta));
    } else if (isInserting) {
      context.missing(_continentMeta);
    }
    if (data.containsKey('boundary_json')) {
      context.handle(
          _boundaryJsonMeta,
          boundaryJson.isAcceptableOrUnknown(
              data['boundary_json']!, _boundaryJsonMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HierarchyCountry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HierarchyCountry(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      centroidLat: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}centroid_lat'])!,
      centroidLon: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}centroid_lon'])!,
      continent: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}continent'])!,
      boundaryJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}boundary_json']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $CountriesTableTable createAlias(String alias) {
    return $CountriesTableTable(attachedDatabase, alias);
  }
}

class HierarchyCountry extends DataClass
    implements Insertable<HierarchyCountry> {
  final String id;
  final String name;
  final double centroidLat;
  final double centroidLon;
  final String continent;
  final String? boundaryJson;
  final DateTime createdAt;
  const HierarchyCountry(
      {required this.id,
      required this.name,
      required this.centroidLat,
      required this.centroidLon,
      required this.continent,
      this.boundaryJson,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['centroid_lat'] = Variable<double>(centroidLat);
    map['centroid_lon'] = Variable<double>(centroidLon);
    map['continent'] = Variable<String>(continent);
    if (!nullToAbsent || boundaryJson != null) {
      map['boundary_json'] = Variable<String>(boundaryJson);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  CountriesTableCompanion toCompanion(bool nullToAbsent) {
    return CountriesTableCompanion(
      id: Value(id),
      name: Value(name),
      centroidLat: Value(centroidLat),
      centroidLon: Value(centroidLon),
      continent: Value(continent),
      boundaryJson: boundaryJson == null && nullToAbsent
          ? const Value.absent()
          : Value(boundaryJson),
      createdAt: Value(createdAt),
    );
  }

  factory HierarchyCountry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HierarchyCountry(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      centroidLat: serializer.fromJson<double>(json['centroidLat']),
      centroidLon: serializer.fromJson<double>(json['centroidLon']),
      continent: serializer.fromJson<String>(json['continent']),
      boundaryJson: serializer.fromJson<String?>(json['boundaryJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'centroidLat': serializer.toJson<double>(centroidLat),
      'centroidLon': serializer.toJson<double>(centroidLon),
      'continent': serializer.toJson<String>(continent),
      'boundaryJson': serializer.toJson<String?>(boundaryJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  HierarchyCountry copyWith(
          {String? id,
          String? name,
          double? centroidLat,
          double? centroidLon,
          String? continent,
          Value<String?> boundaryJson = const Value.absent(),
          DateTime? createdAt}) =>
      HierarchyCountry(
        id: id ?? this.id,
        name: name ?? this.name,
        centroidLat: centroidLat ?? this.centroidLat,
        centroidLon: centroidLon ?? this.centroidLon,
        continent: continent ?? this.continent,
        boundaryJson:
            boundaryJson.present ? boundaryJson.value : this.boundaryJson,
        createdAt: createdAt ?? this.createdAt,
      );
  HierarchyCountry copyWithCompanion(CountriesTableCompanion data) {
    return HierarchyCountry(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      centroidLat:
          data.centroidLat.present ? data.centroidLat.value : this.centroidLat,
      centroidLon:
          data.centroidLon.present ? data.centroidLon.value : this.centroidLon,
      continent: data.continent.present ? data.continent.value : this.continent,
      boundaryJson: data.boundaryJson.present
          ? data.boundaryJson.value
          : this.boundaryJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HierarchyCountry(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('centroidLat: $centroidLat, ')
          ..write('centroidLon: $centroidLon, ')
          ..write('continent: $continent, ')
          ..write('boundaryJson: $boundaryJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, name, centroidLat, centroidLon, continent, boundaryJson, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HierarchyCountry &&
          other.id == this.id &&
          other.name == this.name &&
          other.centroidLat == this.centroidLat &&
          other.centroidLon == this.centroidLon &&
          other.continent == this.continent &&
          other.boundaryJson == this.boundaryJson &&
          other.createdAt == this.createdAt);
}

class CountriesTableCompanion extends UpdateCompanion<HierarchyCountry> {
  final Value<String> id;
  final Value<String> name;
  final Value<double> centroidLat;
  final Value<double> centroidLon;
  final Value<String> continent;
  final Value<String?> boundaryJson;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const CountriesTableCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.centroidLat = const Value.absent(),
    this.centroidLon = const Value.absent(),
    this.continent = const Value.absent(),
    this.boundaryJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CountriesTableCompanion.insert({
    required String id,
    required String name,
    required double centroidLat,
    required double centroidLon,
    required String continent,
    this.boundaryJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        centroidLat = Value(centroidLat),
        centroidLon = Value(centroidLon),
        continent = Value(continent);
  static Insertable<HierarchyCountry> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<double>? centroidLat,
    Expression<double>? centroidLon,
    Expression<String>? continent,
    Expression<String>? boundaryJson,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (centroidLat != null) 'centroid_lat': centroidLat,
      if (centroidLon != null) 'centroid_lon': centroidLon,
      if (continent != null) 'continent': continent,
      if (boundaryJson != null) 'boundary_json': boundaryJson,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CountriesTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<double>? centroidLat,
      Value<double>? centroidLon,
      Value<String>? continent,
      Value<String?>? boundaryJson,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return CountriesTableCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      centroidLat: centroidLat ?? this.centroidLat,
      centroidLon: centroidLon ?? this.centroidLon,
      continent: continent ?? this.continent,
      boundaryJson: boundaryJson ?? this.boundaryJson,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (centroidLat.present) {
      map['centroid_lat'] = Variable<double>(centroidLat.value);
    }
    if (centroidLon.present) {
      map['centroid_lon'] = Variable<double>(centroidLon.value);
    }
    if (continent.present) {
      map['continent'] = Variable<String>(continent.value);
    }
    if (boundaryJson.present) {
      map['boundary_json'] = Variable<String>(boundaryJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CountriesTableCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('centroidLat: $centroidLat, ')
          ..write('centroidLon: $centroidLon, ')
          ..write('continent: $continent, ')
          ..write('boundaryJson: $boundaryJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StatesTableTable extends StatesTable
    with TableInfo<$StatesTableTable, HierarchyState> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StatesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _centroidLatMeta =
      const VerificationMeta('centroidLat');
  @override
  late final GeneratedColumn<double> centroidLat = GeneratedColumn<double>(
      'centroid_lat', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _centroidLonMeta =
      const VerificationMeta('centroidLon');
  @override
  late final GeneratedColumn<double> centroidLon = GeneratedColumn<double>(
      'centroid_lon', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _countryIdMeta =
      const VerificationMeta('countryId');
  @override
  late final GeneratedColumn<String> countryId = GeneratedColumn<String>(
      'country_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _boundaryJsonMeta =
      const VerificationMeta('boundaryJson');
  @override
  late final GeneratedColumn<String> boundaryJson = GeneratedColumn<String>(
      'boundary_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, name, centroidLat, centroidLon, countryId, boundaryJson, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'states_table';
  @override
  VerificationContext validateIntegrity(Insertable<HierarchyState> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('centroid_lat')) {
      context.handle(
          _centroidLatMeta,
          centroidLat.isAcceptableOrUnknown(
              data['centroid_lat']!, _centroidLatMeta));
    } else if (isInserting) {
      context.missing(_centroidLatMeta);
    }
    if (data.containsKey('centroid_lon')) {
      context.handle(
          _centroidLonMeta,
          centroidLon.isAcceptableOrUnknown(
              data['centroid_lon']!, _centroidLonMeta));
    } else if (isInserting) {
      context.missing(_centroidLonMeta);
    }
    if (data.containsKey('country_id')) {
      context.handle(_countryIdMeta,
          countryId.isAcceptableOrUnknown(data['country_id']!, _countryIdMeta));
    } else if (isInserting) {
      context.missing(_countryIdMeta);
    }
    if (data.containsKey('boundary_json')) {
      context.handle(
          _boundaryJsonMeta,
          boundaryJson.isAcceptableOrUnknown(
              data['boundary_json']!, _boundaryJsonMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HierarchyState map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HierarchyState(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      centroidLat: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}centroid_lat'])!,
      centroidLon: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}centroid_lon'])!,
      countryId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}country_id'])!,
      boundaryJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}boundary_json']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $StatesTableTable createAlias(String alias) {
    return $StatesTableTable(attachedDatabase, alias);
  }
}

class HierarchyState extends DataClass implements Insertable<HierarchyState> {
  final String id;
  final String name;
  final double centroidLat;
  final double centroidLon;
  final String countryId;
  final String? boundaryJson;
  final DateTime createdAt;
  const HierarchyState(
      {required this.id,
      required this.name,
      required this.centroidLat,
      required this.centroidLon,
      required this.countryId,
      this.boundaryJson,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['centroid_lat'] = Variable<double>(centroidLat);
    map['centroid_lon'] = Variable<double>(centroidLon);
    map['country_id'] = Variable<String>(countryId);
    if (!nullToAbsent || boundaryJson != null) {
      map['boundary_json'] = Variable<String>(boundaryJson);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  StatesTableCompanion toCompanion(bool nullToAbsent) {
    return StatesTableCompanion(
      id: Value(id),
      name: Value(name),
      centroidLat: Value(centroidLat),
      centroidLon: Value(centroidLon),
      countryId: Value(countryId),
      boundaryJson: boundaryJson == null && nullToAbsent
          ? const Value.absent()
          : Value(boundaryJson),
      createdAt: Value(createdAt),
    );
  }

  factory HierarchyState.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HierarchyState(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      centroidLat: serializer.fromJson<double>(json['centroidLat']),
      centroidLon: serializer.fromJson<double>(json['centroidLon']),
      countryId: serializer.fromJson<String>(json['countryId']),
      boundaryJson: serializer.fromJson<String?>(json['boundaryJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'centroidLat': serializer.toJson<double>(centroidLat),
      'centroidLon': serializer.toJson<double>(centroidLon),
      'countryId': serializer.toJson<String>(countryId),
      'boundaryJson': serializer.toJson<String?>(boundaryJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  HierarchyState copyWith(
          {String? id,
          String? name,
          double? centroidLat,
          double? centroidLon,
          String? countryId,
          Value<String?> boundaryJson = const Value.absent(),
          DateTime? createdAt}) =>
      HierarchyState(
        id: id ?? this.id,
        name: name ?? this.name,
        centroidLat: centroidLat ?? this.centroidLat,
        centroidLon: centroidLon ?? this.centroidLon,
        countryId: countryId ?? this.countryId,
        boundaryJson:
            boundaryJson.present ? boundaryJson.value : this.boundaryJson,
        createdAt: createdAt ?? this.createdAt,
      );
  HierarchyState copyWithCompanion(StatesTableCompanion data) {
    return HierarchyState(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      centroidLat:
          data.centroidLat.present ? data.centroidLat.value : this.centroidLat,
      centroidLon:
          data.centroidLon.present ? data.centroidLon.value : this.centroidLon,
      countryId: data.countryId.present ? data.countryId.value : this.countryId,
      boundaryJson: data.boundaryJson.present
          ? data.boundaryJson.value
          : this.boundaryJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HierarchyState(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('centroidLat: $centroidLat, ')
          ..write('centroidLon: $centroidLon, ')
          ..write('countryId: $countryId, ')
          ..write('boundaryJson: $boundaryJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, name, centroidLat, centroidLon, countryId, boundaryJson, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HierarchyState &&
          other.id == this.id &&
          other.name == this.name &&
          other.centroidLat == this.centroidLat &&
          other.centroidLon == this.centroidLon &&
          other.countryId == this.countryId &&
          other.boundaryJson == this.boundaryJson &&
          other.createdAt == this.createdAt);
}

class StatesTableCompanion extends UpdateCompanion<HierarchyState> {
  final Value<String> id;
  final Value<String> name;
  final Value<double> centroidLat;
  final Value<double> centroidLon;
  final Value<String> countryId;
  final Value<String?> boundaryJson;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const StatesTableCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.centroidLat = const Value.absent(),
    this.centroidLon = const Value.absent(),
    this.countryId = const Value.absent(),
    this.boundaryJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StatesTableCompanion.insert({
    required String id,
    required String name,
    required double centroidLat,
    required double centroidLon,
    required String countryId,
    this.boundaryJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        centroidLat = Value(centroidLat),
        centroidLon = Value(centroidLon),
        countryId = Value(countryId);
  static Insertable<HierarchyState> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<double>? centroidLat,
    Expression<double>? centroidLon,
    Expression<String>? countryId,
    Expression<String>? boundaryJson,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (centroidLat != null) 'centroid_lat': centroidLat,
      if (centroidLon != null) 'centroid_lon': centroidLon,
      if (countryId != null) 'country_id': countryId,
      if (boundaryJson != null) 'boundary_json': boundaryJson,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StatesTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<double>? centroidLat,
      Value<double>? centroidLon,
      Value<String>? countryId,
      Value<String?>? boundaryJson,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return StatesTableCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      centroidLat: centroidLat ?? this.centroidLat,
      centroidLon: centroidLon ?? this.centroidLon,
      countryId: countryId ?? this.countryId,
      boundaryJson: boundaryJson ?? this.boundaryJson,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (centroidLat.present) {
      map['centroid_lat'] = Variable<double>(centroidLat.value);
    }
    if (centroidLon.present) {
      map['centroid_lon'] = Variable<double>(centroidLon.value);
    }
    if (countryId.present) {
      map['country_id'] = Variable<String>(countryId.value);
    }
    if (boundaryJson.present) {
      map['boundary_json'] = Variable<String>(boundaryJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StatesTableCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('centroidLat: $centroidLat, ')
          ..write('centroidLon: $centroidLon, ')
          ..write('countryId: $countryId, ')
          ..write('boundaryJson: $boundaryJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CitiesTableTable extends CitiesTable
    with TableInfo<$CitiesTableTable, HierarchyCity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CitiesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _centroidLatMeta =
      const VerificationMeta('centroidLat');
  @override
  late final GeneratedColumn<double> centroidLat = GeneratedColumn<double>(
      'centroid_lat', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _centroidLonMeta =
      const VerificationMeta('centroidLon');
  @override
  late final GeneratedColumn<double> centroidLon = GeneratedColumn<double>(
      'centroid_lon', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _stateIdMeta =
      const VerificationMeta('stateId');
  @override
  late final GeneratedColumn<String> stateId = GeneratedColumn<String>(
      'state_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _boundaryJsonMeta =
      const VerificationMeta('boundaryJson');
  @override
  late final GeneratedColumn<String> boundaryJson = GeneratedColumn<String>(
      'boundary_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _cellsTotalMeta =
      const VerificationMeta('cellsTotal');
  @override
  late final GeneratedColumn<int> cellsTotal = GeneratedColumn<int>(
      'cells_total', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        centroidLat,
        centroidLon,
        stateId,
        boundaryJson,
        cellsTotal,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cities_table';
  @override
  VerificationContext validateIntegrity(Insertable<HierarchyCity> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('centroid_lat')) {
      context.handle(
          _centroidLatMeta,
          centroidLat.isAcceptableOrUnknown(
              data['centroid_lat']!, _centroidLatMeta));
    } else if (isInserting) {
      context.missing(_centroidLatMeta);
    }
    if (data.containsKey('centroid_lon')) {
      context.handle(
          _centroidLonMeta,
          centroidLon.isAcceptableOrUnknown(
              data['centroid_lon']!, _centroidLonMeta));
    } else if (isInserting) {
      context.missing(_centroidLonMeta);
    }
    if (data.containsKey('state_id')) {
      context.handle(_stateIdMeta,
          stateId.isAcceptableOrUnknown(data['state_id']!, _stateIdMeta));
    } else if (isInserting) {
      context.missing(_stateIdMeta);
    }
    if (data.containsKey('boundary_json')) {
      context.handle(
          _boundaryJsonMeta,
          boundaryJson.isAcceptableOrUnknown(
              data['boundary_json']!, _boundaryJsonMeta));
    }
    if (data.containsKey('cells_total')) {
      context.handle(
          _cellsTotalMeta,
          cellsTotal.isAcceptableOrUnknown(
              data['cells_total']!, _cellsTotalMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HierarchyCity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HierarchyCity(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      centroidLat: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}centroid_lat'])!,
      centroidLon: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}centroid_lon'])!,
      stateId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}state_id'])!,
      boundaryJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}boundary_json']),
      cellsTotal: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}cells_total']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $CitiesTableTable createAlias(String alias) {
    return $CitiesTableTable(attachedDatabase, alias);
  }
}

class HierarchyCity extends DataClass implements Insertable<HierarchyCity> {
  final String id;
  final String name;
  final double centroidLat;
  final double centroidLon;
  final String stateId;
  final String? boundaryJson;
  final int? cellsTotal;
  final DateTime createdAt;
  const HierarchyCity(
      {required this.id,
      required this.name,
      required this.centroidLat,
      required this.centroidLon,
      required this.stateId,
      this.boundaryJson,
      this.cellsTotal,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['centroid_lat'] = Variable<double>(centroidLat);
    map['centroid_lon'] = Variable<double>(centroidLon);
    map['state_id'] = Variable<String>(stateId);
    if (!nullToAbsent || boundaryJson != null) {
      map['boundary_json'] = Variable<String>(boundaryJson);
    }
    if (!nullToAbsent || cellsTotal != null) {
      map['cells_total'] = Variable<int>(cellsTotal);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  CitiesTableCompanion toCompanion(bool nullToAbsent) {
    return CitiesTableCompanion(
      id: Value(id),
      name: Value(name),
      centroidLat: Value(centroidLat),
      centroidLon: Value(centroidLon),
      stateId: Value(stateId),
      boundaryJson: boundaryJson == null && nullToAbsent
          ? const Value.absent()
          : Value(boundaryJson),
      cellsTotal: cellsTotal == null && nullToAbsent
          ? const Value.absent()
          : Value(cellsTotal),
      createdAt: Value(createdAt),
    );
  }

  factory HierarchyCity.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HierarchyCity(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      centroidLat: serializer.fromJson<double>(json['centroidLat']),
      centroidLon: serializer.fromJson<double>(json['centroidLon']),
      stateId: serializer.fromJson<String>(json['stateId']),
      boundaryJson: serializer.fromJson<String?>(json['boundaryJson']),
      cellsTotal: serializer.fromJson<int?>(json['cellsTotal']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'centroidLat': serializer.toJson<double>(centroidLat),
      'centroidLon': serializer.toJson<double>(centroidLon),
      'stateId': serializer.toJson<String>(stateId),
      'boundaryJson': serializer.toJson<String?>(boundaryJson),
      'cellsTotal': serializer.toJson<int?>(cellsTotal),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  HierarchyCity copyWith(
          {String? id,
          String? name,
          double? centroidLat,
          double? centroidLon,
          String? stateId,
          Value<String?> boundaryJson = const Value.absent(),
          Value<int?> cellsTotal = const Value.absent(),
          DateTime? createdAt}) =>
      HierarchyCity(
        id: id ?? this.id,
        name: name ?? this.name,
        centroidLat: centroidLat ?? this.centroidLat,
        centroidLon: centroidLon ?? this.centroidLon,
        stateId: stateId ?? this.stateId,
        boundaryJson:
            boundaryJson.present ? boundaryJson.value : this.boundaryJson,
        cellsTotal: cellsTotal.present ? cellsTotal.value : this.cellsTotal,
        createdAt: createdAt ?? this.createdAt,
      );
  HierarchyCity copyWithCompanion(CitiesTableCompanion data) {
    return HierarchyCity(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      centroidLat:
          data.centroidLat.present ? data.centroidLat.value : this.centroidLat,
      centroidLon:
          data.centroidLon.present ? data.centroidLon.value : this.centroidLon,
      stateId: data.stateId.present ? data.stateId.value : this.stateId,
      boundaryJson: data.boundaryJson.present
          ? data.boundaryJson.value
          : this.boundaryJson,
      cellsTotal:
          data.cellsTotal.present ? data.cellsTotal.value : this.cellsTotal,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HierarchyCity(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('centroidLat: $centroidLat, ')
          ..write('centroidLon: $centroidLon, ')
          ..write('stateId: $stateId, ')
          ..write('boundaryJson: $boundaryJson, ')
          ..write('cellsTotal: $cellsTotal, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, centroidLat, centroidLon, stateId,
      boundaryJson, cellsTotal, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HierarchyCity &&
          other.id == this.id &&
          other.name == this.name &&
          other.centroidLat == this.centroidLat &&
          other.centroidLon == this.centroidLon &&
          other.stateId == this.stateId &&
          other.boundaryJson == this.boundaryJson &&
          other.cellsTotal == this.cellsTotal &&
          other.createdAt == this.createdAt);
}

class CitiesTableCompanion extends UpdateCompanion<HierarchyCity> {
  final Value<String> id;
  final Value<String> name;
  final Value<double> centroidLat;
  final Value<double> centroidLon;
  final Value<String> stateId;
  final Value<String?> boundaryJson;
  final Value<int?> cellsTotal;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const CitiesTableCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.centroidLat = const Value.absent(),
    this.centroidLon = const Value.absent(),
    this.stateId = const Value.absent(),
    this.boundaryJson = const Value.absent(),
    this.cellsTotal = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CitiesTableCompanion.insert({
    required String id,
    required String name,
    required double centroidLat,
    required double centroidLon,
    required String stateId,
    this.boundaryJson = const Value.absent(),
    this.cellsTotal = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        centroidLat = Value(centroidLat),
        centroidLon = Value(centroidLon),
        stateId = Value(stateId);
  static Insertable<HierarchyCity> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<double>? centroidLat,
    Expression<double>? centroidLon,
    Expression<String>? stateId,
    Expression<String>? boundaryJson,
    Expression<int>? cellsTotal,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (centroidLat != null) 'centroid_lat': centroidLat,
      if (centroidLon != null) 'centroid_lon': centroidLon,
      if (stateId != null) 'state_id': stateId,
      if (boundaryJson != null) 'boundary_json': boundaryJson,
      if (cellsTotal != null) 'cells_total': cellsTotal,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CitiesTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<double>? centroidLat,
      Value<double>? centroidLon,
      Value<String>? stateId,
      Value<String?>? boundaryJson,
      Value<int?>? cellsTotal,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return CitiesTableCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      centroidLat: centroidLat ?? this.centroidLat,
      centroidLon: centroidLon ?? this.centroidLon,
      stateId: stateId ?? this.stateId,
      boundaryJson: boundaryJson ?? this.boundaryJson,
      cellsTotal: cellsTotal ?? this.cellsTotal,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (centroidLat.present) {
      map['centroid_lat'] = Variable<double>(centroidLat.value);
    }
    if (centroidLon.present) {
      map['centroid_lon'] = Variable<double>(centroidLon.value);
    }
    if (stateId.present) {
      map['state_id'] = Variable<String>(stateId.value);
    }
    if (boundaryJson.present) {
      map['boundary_json'] = Variable<String>(boundaryJson.value);
    }
    if (cellsTotal.present) {
      map['cells_total'] = Variable<int>(cellsTotal.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CitiesTableCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('centroidLat: $centroidLat, ')
          ..write('centroidLon: $centroidLon, ')
          ..write('stateId: $stateId, ')
          ..write('boundaryJson: $boundaryJson, ')
          ..write('cellsTotal: $cellsTotal, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DistrictsTableTable extends DistrictsTable
    with TableInfo<$DistrictsTableTable, HierarchyDistrict> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DistrictsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _centroidLatMeta =
      const VerificationMeta('centroidLat');
  @override
  late final GeneratedColumn<double> centroidLat = GeneratedColumn<double>(
      'centroid_lat', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _centroidLonMeta =
      const VerificationMeta('centroidLon');
  @override
  late final GeneratedColumn<double> centroidLon = GeneratedColumn<double>(
      'centroid_lon', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _cityIdMeta = const VerificationMeta('cityId');
  @override
  late final GeneratedColumn<String> cityId = GeneratedColumn<String>(
      'city_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _boundaryJsonMeta =
      const VerificationMeta('boundaryJson');
  @override
  late final GeneratedColumn<String> boundaryJson = GeneratedColumn<String>(
      'boundary_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _cellsTotalMeta =
      const VerificationMeta('cellsTotal');
  @override
  late final GeneratedColumn<int> cellsTotal = GeneratedColumn<int>(
      'cells_total', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
      'source', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('whosonfirst'));
  static const VerificationMeta _sourceIdMeta =
      const VerificationMeta('sourceId');
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
      'source_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        centroidLat,
        centroidLon,
        cityId,
        boundaryJson,
        cellsTotal,
        source,
        sourceId,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'districts_table';
  @override
  VerificationContext validateIntegrity(Insertable<HierarchyDistrict> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('centroid_lat')) {
      context.handle(
          _centroidLatMeta,
          centroidLat.isAcceptableOrUnknown(
              data['centroid_lat']!, _centroidLatMeta));
    } else if (isInserting) {
      context.missing(_centroidLatMeta);
    }
    if (data.containsKey('centroid_lon')) {
      context.handle(
          _centroidLonMeta,
          centroidLon.isAcceptableOrUnknown(
              data['centroid_lon']!, _centroidLonMeta));
    } else if (isInserting) {
      context.missing(_centroidLonMeta);
    }
    if (data.containsKey('city_id')) {
      context.handle(_cityIdMeta,
          cityId.isAcceptableOrUnknown(data['city_id']!, _cityIdMeta));
    } else if (isInserting) {
      context.missing(_cityIdMeta);
    }
    if (data.containsKey('boundary_json')) {
      context.handle(
          _boundaryJsonMeta,
          boundaryJson.isAcceptableOrUnknown(
              data['boundary_json']!, _boundaryJsonMeta));
    }
    if (data.containsKey('cells_total')) {
      context.handle(
          _cellsTotalMeta,
          cellsTotal.isAcceptableOrUnknown(
              data['cells_total']!, _cellsTotalMeta));
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta,
          source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    }
    if (data.containsKey('source_id')) {
      context.handle(_sourceIdMeta,
          sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HierarchyDistrict map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HierarchyDistrict(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      centroidLat: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}centroid_lat'])!,
      centroidLon: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}centroid_lon'])!,
      cityId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}city_id'])!,
      boundaryJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}boundary_json']),
      cellsTotal: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}cells_total']),
      source: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source'])!,
      sourceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source_id']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $DistrictsTableTable createAlias(String alias) {
    return $DistrictsTableTable(attachedDatabase, alias);
  }
}

class HierarchyDistrict extends DataClass
    implements Insertable<HierarchyDistrict> {
  final String id;
  final String name;
  final double centroidLat;
  final double centroidLon;
  final String cityId;
  final String? boundaryJson;
  final int? cellsTotal;
  final String source;
  final String? sourceId;
  final DateTime createdAt;
  const HierarchyDistrict(
      {required this.id,
      required this.name,
      required this.centroidLat,
      required this.centroidLon,
      required this.cityId,
      this.boundaryJson,
      this.cellsTotal,
      required this.source,
      this.sourceId,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['centroid_lat'] = Variable<double>(centroidLat);
    map['centroid_lon'] = Variable<double>(centroidLon);
    map['city_id'] = Variable<String>(cityId);
    if (!nullToAbsent || boundaryJson != null) {
      map['boundary_json'] = Variable<String>(boundaryJson);
    }
    if (!nullToAbsent || cellsTotal != null) {
      map['cells_total'] = Variable<int>(cellsTotal);
    }
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || sourceId != null) {
      map['source_id'] = Variable<String>(sourceId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  DistrictsTableCompanion toCompanion(bool nullToAbsent) {
    return DistrictsTableCompanion(
      id: Value(id),
      name: Value(name),
      centroidLat: Value(centroidLat),
      centroidLon: Value(centroidLon),
      cityId: Value(cityId),
      boundaryJson: boundaryJson == null && nullToAbsent
          ? const Value.absent()
          : Value(boundaryJson),
      cellsTotal: cellsTotal == null && nullToAbsent
          ? const Value.absent()
          : Value(cellsTotal),
      source: Value(source),
      sourceId: sourceId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceId),
      createdAt: Value(createdAt),
    );
  }

  factory HierarchyDistrict.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HierarchyDistrict(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      centroidLat: serializer.fromJson<double>(json['centroidLat']),
      centroidLon: serializer.fromJson<double>(json['centroidLon']),
      cityId: serializer.fromJson<String>(json['cityId']),
      boundaryJson: serializer.fromJson<String?>(json['boundaryJson']),
      cellsTotal: serializer.fromJson<int?>(json['cellsTotal']),
      source: serializer.fromJson<String>(json['source']),
      sourceId: serializer.fromJson<String?>(json['sourceId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'centroidLat': serializer.toJson<double>(centroidLat),
      'centroidLon': serializer.toJson<double>(centroidLon),
      'cityId': serializer.toJson<String>(cityId),
      'boundaryJson': serializer.toJson<String?>(boundaryJson),
      'cellsTotal': serializer.toJson<int?>(cellsTotal),
      'source': serializer.toJson<String>(source),
      'sourceId': serializer.toJson<String?>(sourceId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  HierarchyDistrict copyWith(
          {String? id,
          String? name,
          double? centroidLat,
          double? centroidLon,
          String? cityId,
          Value<String?> boundaryJson = const Value.absent(),
          Value<int?> cellsTotal = const Value.absent(),
          String? source,
          Value<String?> sourceId = const Value.absent(),
          DateTime? createdAt}) =>
      HierarchyDistrict(
        id: id ?? this.id,
        name: name ?? this.name,
        centroidLat: centroidLat ?? this.centroidLat,
        centroidLon: centroidLon ?? this.centroidLon,
        cityId: cityId ?? this.cityId,
        boundaryJson:
            boundaryJson.present ? boundaryJson.value : this.boundaryJson,
        cellsTotal: cellsTotal.present ? cellsTotal.value : this.cellsTotal,
        source: source ?? this.source,
        sourceId: sourceId.present ? sourceId.value : this.sourceId,
        createdAt: createdAt ?? this.createdAt,
      );
  HierarchyDistrict copyWithCompanion(DistrictsTableCompanion data) {
    return HierarchyDistrict(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      centroidLat:
          data.centroidLat.present ? data.centroidLat.value : this.centroidLat,
      centroidLon:
          data.centroidLon.present ? data.centroidLon.value : this.centroidLon,
      cityId: data.cityId.present ? data.cityId.value : this.cityId,
      boundaryJson: data.boundaryJson.present
          ? data.boundaryJson.value
          : this.boundaryJson,
      cellsTotal:
          data.cellsTotal.present ? data.cellsTotal.value : this.cellsTotal,
      source: data.source.present ? data.source.value : this.source,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HierarchyDistrict(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('centroidLat: $centroidLat, ')
          ..write('centroidLon: $centroidLon, ')
          ..write('cityId: $cityId, ')
          ..write('boundaryJson: $boundaryJson, ')
          ..write('cellsTotal: $cellsTotal, ')
          ..write('source: $source, ')
          ..write('sourceId: $sourceId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, centroidLat, centroidLon, cityId,
      boundaryJson, cellsTotal, source, sourceId, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HierarchyDistrict &&
          other.id == this.id &&
          other.name == this.name &&
          other.centroidLat == this.centroidLat &&
          other.centroidLon == this.centroidLon &&
          other.cityId == this.cityId &&
          other.boundaryJson == this.boundaryJson &&
          other.cellsTotal == this.cellsTotal &&
          other.source == this.source &&
          other.sourceId == this.sourceId &&
          other.createdAt == this.createdAt);
}

class DistrictsTableCompanion extends UpdateCompanion<HierarchyDistrict> {
  final Value<String> id;
  final Value<String> name;
  final Value<double> centroidLat;
  final Value<double> centroidLon;
  final Value<String> cityId;
  final Value<String?> boundaryJson;
  final Value<int?> cellsTotal;
  final Value<String> source;
  final Value<String?> sourceId;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const DistrictsTableCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.centroidLat = const Value.absent(),
    this.centroidLon = const Value.absent(),
    this.cityId = const Value.absent(),
    this.boundaryJson = const Value.absent(),
    this.cellsTotal = const Value.absent(),
    this.source = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DistrictsTableCompanion.insert({
    required String id,
    required String name,
    required double centroidLat,
    required double centroidLon,
    required String cityId,
    this.boundaryJson = const Value.absent(),
    this.cellsTotal = const Value.absent(),
    this.source = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        centroidLat = Value(centroidLat),
        centroidLon = Value(centroidLon),
        cityId = Value(cityId);
  static Insertable<HierarchyDistrict> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<double>? centroidLat,
    Expression<double>? centroidLon,
    Expression<String>? cityId,
    Expression<String>? boundaryJson,
    Expression<int>? cellsTotal,
    Expression<String>? source,
    Expression<String>? sourceId,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (centroidLat != null) 'centroid_lat': centroidLat,
      if (centroidLon != null) 'centroid_lon': centroidLon,
      if (cityId != null) 'city_id': cityId,
      if (boundaryJson != null) 'boundary_json': boundaryJson,
      if (cellsTotal != null) 'cells_total': cellsTotal,
      if (source != null) 'source': source,
      if (sourceId != null) 'source_id': sourceId,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DistrictsTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<double>? centroidLat,
      Value<double>? centroidLon,
      Value<String>? cityId,
      Value<String?>? boundaryJson,
      Value<int?>? cellsTotal,
      Value<String>? source,
      Value<String?>? sourceId,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return DistrictsTableCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      centroidLat: centroidLat ?? this.centroidLat,
      centroidLon: centroidLon ?? this.centroidLon,
      cityId: cityId ?? this.cityId,
      boundaryJson: boundaryJson ?? this.boundaryJson,
      cellsTotal: cellsTotal ?? this.cellsTotal,
      source: source ?? this.source,
      sourceId: sourceId ?? this.sourceId,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (centroidLat.present) {
      map['centroid_lat'] = Variable<double>(centroidLat.value);
    }
    if (centroidLon.present) {
      map['centroid_lon'] = Variable<double>(centroidLon.value);
    }
    if (cityId.present) {
      map['city_id'] = Variable<String>(cityId.value);
    }
    if (boundaryJson.present) {
      map['boundary_json'] = Variable<String>(boundaryJson.value);
    }
    if (cellsTotal.present) {
      map['cells_total'] = Variable<int>(cellsTotal.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DistrictsTableCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('centroidLat: $centroidLat, ')
          ..write('centroidLon: $centroidLon, ')
          ..write('cityId: $cityId, ')
          ..write('boundaryJson: $boundaryJson, ')
          ..write('cellsTotal: $cellsTotal, ')
          ..write('source: $source, ')
          ..write('sourceId: $sourceId, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WriteQueueTableTable extends WriteQueueTable
    with TableInfo<$WriteQueueTableTable, WriteQueueEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WriteQueueTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _entityTypeMeta =
      const VerificationMeta('entityType');
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
      'entity_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _entityIdMeta =
      const VerificationMeta('entityId');
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
      'entity_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _operationMeta =
      const VerificationMeta('operation');
  @override
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
      'operation', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _payloadMeta =
      const VerificationMeta('payload');
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
      'payload', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('pending'));
  static const VerificationMeta _attemptsMeta =
      const VerificationMeta('attempts');
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
      'attempts', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _lastErrorMeta =
      const VerificationMeta('lastError');
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
      'last_error', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        entityType,
        entityId,
        operation,
        payload,
        userId,
        status,
        attempts,
        lastError,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'write_queue_table';
  @override
  VerificationContext validateIntegrity(Insertable<WriteQueueEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('entity_type')) {
      context.handle(
          _entityTypeMeta,
          entityType.isAcceptableOrUnknown(
              data['entity_type']!, _entityTypeMeta));
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(_entityIdMeta,
          entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta));
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('operation')) {
      context.handle(_operationMeta,
          operation.isAcceptableOrUnknown(data['operation']!, _operationMeta));
    } else if (isInserting) {
      context.missing(_operationMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(_payloadMeta,
          payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta));
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('attempts')) {
      context.handle(_attemptsMeta,
          attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta));
    }
    if (data.containsKey('last_error')) {
      context.handle(_lastErrorMeta,
          lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WriteQueueEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WriteQueueEntry(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      entityType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entity_type'])!,
      entityId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entity_id'])!,
      operation: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}operation'])!,
      payload: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      attempts: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}attempts'])!,
      lastError: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}last_error']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $WriteQueueTableTable createAlias(String alias) {
    return $WriteQueueTableTable(attachedDatabase, alias);
  }
}

class WriteQueueEntry extends DataClass implements Insertable<WriteQueueEntry> {
  final int id;
  final String entityType;
  final String entityId;
  final String operation;
  final String payload;
  final String userId;
  final String status;
  final int attempts;
  final String? lastError;
  final DateTime createdAt;
  final DateTime updatedAt;
  const WriteQueueEntry(
      {required this.id,
      required this.entityType,
      required this.entityId,
      required this.operation,
      required this.payload,
      required this.userId,
      required this.status,
      required this.attempts,
      this.lastError,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['operation'] = Variable<String>(operation);
    map['payload'] = Variable<String>(payload);
    map['user_id'] = Variable<String>(userId);
    map['status'] = Variable<String>(status);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  WriteQueueTableCompanion toCompanion(bool nullToAbsent) {
    return WriteQueueTableCompanion(
      id: Value(id),
      entityType: Value(entityType),
      entityId: Value(entityId),
      operation: Value(operation),
      payload: Value(payload),
      userId: Value(userId),
      status: Value(status),
      attempts: Value(attempts),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory WriteQueueEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WriteQueueEntry(
      id: serializer.fromJson<int>(json['id']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      operation: serializer.fromJson<String>(json['operation']),
      payload: serializer.fromJson<String>(json['payload']),
      userId: serializer.fromJson<String>(json['userId']),
      status: serializer.fromJson<String>(json['status']),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'operation': serializer.toJson<String>(operation),
      'payload': serializer.toJson<String>(payload),
      'userId': serializer.toJson<String>(userId),
      'status': serializer.toJson<String>(status),
      'attempts': serializer.toJson<int>(attempts),
      'lastError': serializer.toJson<String?>(lastError),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  WriteQueueEntry copyWith(
          {int? id,
          String? entityType,
          String? entityId,
          String? operation,
          String? payload,
          String? userId,
          String? status,
          int? attempts,
          Value<String?> lastError = const Value.absent(),
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      WriteQueueEntry(
        id: id ?? this.id,
        entityType: entityType ?? this.entityType,
        entityId: entityId ?? this.entityId,
        operation: operation ?? this.operation,
        payload: payload ?? this.payload,
        userId: userId ?? this.userId,
        status: status ?? this.status,
        attempts: attempts ?? this.attempts,
        lastError: lastError.present ? lastError.value : this.lastError,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  WriteQueueEntry copyWithCompanion(WriteQueueTableCompanion data) {
    return WriteQueueEntry(
      id: data.id.present ? data.id.value : this.id,
      entityType:
          data.entityType.present ? data.entityType.value : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      operation: data.operation.present ? data.operation.value : this.operation,
      payload: data.payload.present ? data.payload.value : this.payload,
      userId: data.userId.present ? data.userId.value : this.userId,
      status: data.status.present ? data.status.value : this.status,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WriteQueueEntry(')
          ..write('id: $id, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('operation: $operation, ')
          ..write('payload: $payload, ')
          ..write('userId: $userId, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, entityType, entityId, operation, payload,
      userId, status, attempts, lastError, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WriteQueueEntry &&
          other.id == this.id &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.operation == this.operation &&
          other.payload == this.payload &&
          other.userId == this.userId &&
          other.status == this.status &&
          other.attempts == this.attempts &&
          other.lastError == this.lastError &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class WriteQueueTableCompanion extends UpdateCompanion<WriteQueueEntry> {
  final Value<int> id;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<String> operation;
  final Value<String> payload;
  final Value<String> userId;
  final Value<String> status;
  final Value<int> attempts;
  final Value<String?> lastError;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const WriteQueueTableCompanion({
    this.id = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.operation = const Value.absent(),
    this.payload = const Value.absent(),
    this.userId = const Value.absent(),
    this.status = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  WriteQueueTableCompanion.insert({
    this.id = const Value.absent(),
    required String entityType,
    required String entityId,
    required String operation,
    required String payload,
    required String userId,
    this.status = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  })  : entityType = Value(entityType),
        entityId = Value(entityId),
        operation = Value(operation),
        payload = Value(payload),
        userId = Value(userId);
  static Insertable<WriteQueueEntry> custom({
    Expression<int>? id,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<String>? operation,
    Expression<String>? payload,
    Expression<String>? userId,
    Expression<String>? status,
    Expression<int>? attempts,
    Expression<String>? lastError,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (operation != null) 'operation': operation,
      if (payload != null) 'payload': payload,
      if (userId != null) 'user_id': userId,
      if (status != null) 'status': status,
      if (attempts != null) 'attempts': attempts,
      if (lastError != null) 'last_error': lastError,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  WriteQueueTableCompanion copyWith(
      {Value<int>? id,
      Value<String>? entityType,
      Value<String>? entityId,
      Value<String>? operation,
      Value<String>? payload,
      Value<String>? userId,
      Value<String>? status,
      Value<int>? attempts,
      Value<String?>? lastError,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt}) {
    return WriteQueueTableCompanion(
      id: id ?? this.id,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      operation: operation ?? this.operation,
      payload: payload ?? this.payload,
      userId: userId ?? this.userId,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WriteQueueTableCompanion(')
          ..write('id: $id, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('operation: $operation, ')
          ..write('payload: $payload, ')
          ..write('userId: $userId, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $PlayersTableTable playersTable = $PlayersTableTable(this);
  late final $SpeciesTableTable speciesTable = $SpeciesTableTable(this);
  late final $ItemsTableTable itemsTable = $ItemsTableTable(this);
  late final $CellVisitsTableTable cellVisitsTable =
      $CellVisitsTableTable(this);
  late final $CellPropertiesTableTable cellPropertiesTable =
      $CellPropertiesTableTable(this);
  late final $CountriesTableTable countriesTable = $CountriesTableTable(this);
  late final $StatesTableTable statesTable = $StatesTableTable(this);
  late final $CitiesTableTable citiesTable = $CitiesTableTable(this);
  late final $DistrictsTableTable districtsTable = $DistrictsTableTable(this);
  late final $WriteQueueTableTable writeQueueTable =
      $WriteQueueTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        playersTable,
        speciesTable,
        itemsTable,
        cellVisitsTable,
        cellPropertiesTable,
        countriesTable,
        statesTable,
        citiesTable,
        districtsTable,
        writeQueueTable
      ];
}

typedef $$PlayersTableTableCreateCompanionBuilder = PlayersTableCompanion
    Function({
  required String id,
  Value<String> displayName,
  Value<double> totalDistanceKm,
  Value<int> cellsExplored,
  Value<int> speciesDiscovered,
  Value<int> currentStreak,
  Value<int> longestStreak,
  Value<bool> hasCompletedOnboarding,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});
typedef $$PlayersTableTableUpdateCompanionBuilder = PlayersTableCompanion
    Function({
  Value<String> id,
  Value<String> displayName,
  Value<double> totalDistanceKm,
  Value<int> cellsExplored,
  Value<int> speciesDiscovered,
  Value<int> currentStreak,
  Value<int> longestStreak,
  Value<bool> hasCompletedOnboarding,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$PlayersTableTableFilterComposer
    extends Composer<_$AppDatabase, $PlayersTableTable> {
  $$PlayersTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get totalDistanceKm => $composableBuilder(
      column: $table.totalDistanceKm,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get cellsExplored => $composableBuilder(
      column: $table.cellsExplored, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get speciesDiscovered => $composableBuilder(
      column: $table.speciesDiscovered,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get currentStreak => $composableBuilder(
      column: $table.currentStreak, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get longestStreak => $composableBuilder(
      column: $table.longestStreak, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get hasCompletedOnboarding => $composableBuilder(
      column: $table.hasCompletedOnboarding,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$PlayersTableTableOrderingComposer
    extends Composer<_$AppDatabase, $PlayersTableTable> {
  $$PlayersTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get totalDistanceKm => $composableBuilder(
      column: $table.totalDistanceKm,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get cellsExplored => $composableBuilder(
      column: $table.cellsExplored,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get speciesDiscovered => $composableBuilder(
      column: $table.speciesDiscovered,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get currentStreak => $composableBuilder(
      column: $table.currentStreak,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get longestStreak => $composableBuilder(
      column: $table.longestStreak,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get hasCompletedOnboarding => $composableBuilder(
      column: $table.hasCompletedOnboarding,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$PlayersTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlayersTableTable> {
  $$PlayersTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => column);

  GeneratedColumn<double> get totalDistanceKm => $composableBuilder(
      column: $table.totalDistanceKm, builder: (column) => column);

  GeneratedColumn<int> get cellsExplored => $composableBuilder(
      column: $table.cellsExplored, builder: (column) => column);

  GeneratedColumn<int> get speciesDiscovered => $composableBuilder(
      column: $table.speciesDiscovered, builder: (column) => column);

  GeneratedColumn<int> get currentStreak => $composableBuilder(
      column: $table.currentStreak, builder: (column) => column);

  GeneratedColumn<int> get longestStreak => $composableBuilder(
      column: $table.longestStreak, builder: (column) => column);

  GeneratedColumn<bool> get hasCompletedOnboarding => $composableBuilder(
      column: $table.hasCompletedOnboarding, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PlayersTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PlayersTableTable,
    Player,
    $$PlayersTableTableFilterComposer,
    $$PlayersTableTableOrderingComposer,
    $$PlayersTableTableAnnotationComposer,
    $$PlayersTableTableCreateCompanionBuilder,
    $$PlayersTableTableUpdateCompanionBuilder,
    (Player, BaseReferences<_$AppDatabase, $PlayersTableTable, Player>),
    Player,
    PrefetchHooks Function()> {
  $$PlayersTableTableTableManager(_$AppDatabase db, $PlayersTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlayersTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlayersTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlayersTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> displayName = const Value.absent(),
            Value<double> totalDistanceKm = const Value.absent(),
            Value<int> cellsExplored = const Value.absent(),
            Value<int> speciesDiscovered = const Value.absent(),
            Value<int> currentStreak = const Value.absent(),
            Value<int> longestStreak = const Value.absent(),
            Value<bool> hasCompletedOnboarding = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PlayersTableCompanion(
            id: id,
            displayName: displayName,
            totalDistanceKm: totalDistanceKm,
            cellsExplored: cellsExplored,
            speciesDiscovered: speciesDiscovered,
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            hasCompletedOnboarding: hasCompletedOnboarding,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            Value<String> displayName = const Value.absent(),
            Value<double> totalDistanceKm = const Value.absent(),
            Value<int> cellsExplored = const Value.absent(),
            Value<int> speciesDiscovered = const Value.absent(),
            Value<int> currentStreak = const Value.absent(),
            Value<int> longestStreak = const Value.absent(),
            Value<bool> hasCompletedOnboarding = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PlayersTableCompanion.insert(
            id: id,
            displayName: displayName,
            totalDistanceKm: totalDistanceKm,
            cellsExplored: cellsExplored,
            speciesDiscovered: speciesDiscovered,
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            hasCompletedOnboarding: hasCompletedOnboarding,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PlayersTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PlayersTableTable,
    Player,
    $$PlayersTableTableFilterComposer,
    $$PlayersTableTableOrderingComposer,
    $$PlayersTableTableAnnotationComposer,
    $$PlayersTableTableCreateCompanionBuilder,
    $$PlayersTableTableUpdateCompanionBuilder,
    (Player, BaseReferences<_$AppDatabase, $PlayersTableTable, Player>),
    Player,
    PrefetchHooks Function()>;
typedef $$SpeciesTableTableCreateCompanionBuilder = SpeciesTableCompanion
    Function({
  required String definitionId,
  required String scientificName,
  required String commonName,
  required String taxonomicClass,
  required String iucnStatus,
  required String habitatsJson,
  required String continentsJson,
  Value<String?> animalClass,
  Value<String?> foodPreference,
  Value<String?> climate,
  Value<int?> brawn,
  Value<int?> wit,
  Value<int?> speed,
  Value<String?> size,
  Value<String?> iconUrl,
  Value<String?> artUrl,
  Value<DateTime?> enrichedAt,
  Value<int> rowid,
});
typedef $$SpeciesTableTableUpdateCompanionBuilder = SpeciesTableCompanion
    Function({
  Value<String> definitionId,
  Value<String> scientificName,
  Value<String> commonName,
  Value<String> taxonomicClass,
  Value<String> iucnStatus,
  Value<String> habitatsJson,
  Value<String> continentsJson,
  Value<String?> animalClass,
  Value<String?> foodPreference,
  Value<String?> climate,
  Value<int?> brawn,
  Value<int?> wit,
  Value<int?> speed,
  Value<String?> size,
  Value<String?> iconUrl,
  Value<String?> artUrl,
  Value<DateTime?> enrichedAt,
  Value<int> rowid,
});

class $$SpeciesTableTableFilterComposer
    extends Composer<_$AppDatabase, $SpeciesTableTable> {
  $$SpeciesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get definitionId => $composableBuilder(
      column: $table.definitionId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get scientificName => $composableBuilder(
      column: $table.scientificName,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get commonName => $composableBuilder(
      column: $table.commonName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get taxonomicClass => $composableBuilder(
      column: $table.taxonomicClass,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get iucnStatus => $composableBuilder(
      column: $table.iucnStatus, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get habitatsJson => $composableBuilder(
      column: $table.habitatsJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get continentsJson => $composableBuilder(
      column: $table.continentsJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get animalClass => $composableBuilder(
      column: $table.animalClass, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get foodPreference => $composableBuilder(
      column: $table.foodPreference,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get climate => $composableBuilder(
      column: $table.climate, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get brawn => $composableBuilder(
      column: $table.brawn, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get wit => $composableBuilder(
      column: $table.wit, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get speed => $composableBuilder(
      column: $table.speed, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get size => $composableBuilder(
      column: $table.size, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get iconUrl => $composableBuilder(
      column: $table.iconUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get artUrl => $composableBuilder(
      column: $table.artUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get enrichedAt => $composableBuilder(
      column: $table.enrichedAt, builder: (column) => ColumnFilters(column));
}

class $$SpeciesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $SpeciesTableTable> {
  $$SpeciesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get definitionId => $composableBuilder(
      column: $table.definitionId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get scientificName => $composableBuilder(
      column: $table.scientificName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get commonName => $composableBuilder(
      column: $table.commonName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get taxonomicClass => $composableBuilder(
      column: $table.taxonomicClass,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get iucnStatus => $composableBuilder(
      column: $table.iucnStatus, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get habitatsJson => $composableBuilder(
      column: $table.habitatsJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get continentsJson => $composableBuilder(
      column: $table.continentsJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get animalClass => $composableBuilder(
      column: $table.animalClass, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get foodPreference => $composableBuilder(
      column: $table.foodPreference,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get climate => $composableBuilder(
      column: $table.climate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get brawn => $composableBuilder(
      column: $table.brawn, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get wit => $composableBuilder(
      column: $table.wit, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get speed => $composableBuilder(
      column: $table.speed, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get size => $composableBuilder(
      column: $table.size, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get iconUrl => $composableBuilder(
      column: $table.iconUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get artUrl => $composableBuilder(
      column: $table.artUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get enrichedAt => $composableBuilder(
      column: $table.enrichedAt, builder: (column) => ColumnOrderings(column));
}

class $$SpeciesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $SpeciesTableTable> {
  $$SpeciesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get definitionId => $composableBuilder(
      column: $table.definitionId, builder: (column) => column);

  GeneratedColumn<String> get scientificName => $composableBuilder(
      column: $table.scientificName, builder: (column) => column);

  GeneratedColumn<String> get commonName => $composableBuilder(
      column: $table.commonName, builder: (column) => column);

  GeneratedColumn<String> get taxonomicClass => $composableBuilder(
      column: $table.taxonomicClass, builder: (column) => column);

  GeneratedColumn<String> get iucnStatus => $composableBuilder(
      column: $table.iucnStatus, builder: (column) => column);

  GeneratedColumn<String> get habitatsJson => $composableBuilder(
      column: $table.habitatsJson, builder: (column) => column);

  GeneratedColumn<String> get continentsJson => $composableBuilder(
      column: $table.continentsJson, builder: (column) => column);

  GeneratedColumn<String> get animalClass => $composableBuilder(
      column: $table.animalClass, builder: (column) => column);

  GeneratedColumn<String> get foodPreference => $composableBuilder(
      column: $table.foodPreference, builder: (column) => column);

  GeneratedColumn<String> get climate =>
      $composableBuilder(column: $table.climate, builder: (column) => column);

  GeneratedColumn<int> get brawn =>
      $composableBuilder(column: $table.brawn, builder: (column) => column);

  GeneratedColumn<int> get wit =>
      $composableBuilder(column: $table.wit, builder: (column) => column);

  GeneratedColumn<int> get speed =>
      $composableBuilder(column: $table.speed, builder: (column) => column);

  GeneratedColumn<String> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<String> get iconUrl =>
      $composableBuilder(column: $table.iconUrl, builder: (column) => column);

  GeneratedColumn<String> get artUrl =>
      $composableBuilder(column: $table.artUrl, builder: (column) => column);

  GeneratedColumn<DateTime> get enrichedAt => $composableBuilder(
      column: $table.enrichedAt, builder: (column) => column);
}

class $$SpeciesTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SpeciesTableTable,
    Species,
    $$SpeciesTableTableFilterComposer,
    $$SpeciesTableTableOrderingComposer,
    $$SpeciesTableTableAnnotationComposer,
    $$SpeciesTableTableCreateCompanionBuilder,
    $$SpeciesTableTableUpdateCompanionBuilder,
    (Species, BaseReferences<_$AppDatabase, $SpeciesTableTable, Species>),
    Species,
    PrefetchHooks Function()> {
  $$SpeciesTableTableTableManager(_$AppDatabase db, $SpeciesTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SpeciesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SpeciesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SpeciesTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> definitionId = const Value.absent(),
            Value<String> scientificName = const Value.absent(),
            Value<String> commonName = const Value.absent(),
            Value<String> taxonomicClass = const Value.absent(),
            Value<String> iucnStatus = const Value.absent(),
            Value<String> habitatsJson = const Value.absent(),
            Value<String> continentsJson = const Value.absent(),
            Value<String?> animalClass = const Value.absent(),
            Value<String?> foodPreference = const Value.absent(),
            Value<String?> climate = const Value.absent(),
            Value<int?> brawn = const Value.absent(),
            Value<int?> wit = const Value.absent(),
            Value<int?> speed = const Value.absent(),
            Value<String?> size = const Value.absent(),
            Value<String?> iconUrl = const Value.absent(),
            Value<String?> artUrl = const Value.absent(),
            Value<DateTime?> enrichedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SpeciesTableCompanion(
            definitionId: definitionId,
            scientificName: scientificName,
            commonName: commonName,
            taxonomicClass: taxonomicClass,
            iucnStatus: iucnStatus,
            habitatsJson: habitatsJson,
            continentsJson: continentsJson,
            animalClass: animalClass,
            foodPreference: foodPreference,
            climate: climate,
            brawn: brawn,
            wit: wit,
            speed: speed,
            size: size,
            iconUrl: iconUrl,
            artUrl: artUrl,
            enrichedAt: enrichedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String definitionId,
            required String scientificName,
            required String commonName,
            required String taxonomicClass,
            required String iucnStatus,
            required String habitatsJson,
            required String continentsJson,
            Value<String?> animalClass = const Value.absent(),
            Value<String?> foodPreference = const Value.absent(),
            Value<String?> climate = const Value.absent(),
            Value<int?> brawn = const Value.absent(),
            Value<int?> wit = const Value.absent(),
            Value<int?> speed = const Value.absent(),
            Value<String?> size = const Value.absent(),
            Value<String?> iconUrl = const Value.absent(),
            Value<String?> artUrl = const Value.absent(),
            Value<DateTime?> enrichedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SpeciesTableCompanion.insert(
            definitionId: definitionId,
            scientificName: scientificName,
            commonName: commonName,
            taxonomicClass: taxonomicClass,
            iucnStatus: iucnStatus,
            habitatsJson: habitatsJson,
            continentsJson: continentsJson,
            animalClass: animalClass,
            foodPreference: foodPreference,
            climate: climate,
            brawn: brawn,
            wit: wit,
            speed: speed,
            size: size,
            iconUrl: iconUrl,
            artUrl: artUrl,
            enrichedAt: enrichedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SpeciesTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SpeciesTableTable,
    Species,
    $$SpeciesTableTableFilterComposer,
    $$SpeciesTableTableOrderingComposer,
    $$SpeciesTableTableAnnotationComposer,
    $$SpeciesTableTableCreateCompanionBuilder,
    $$SpeciesTableTableUpdateCompanionBuilder,
    (Species, BaseReferences<_$AppDatabase, $SpeciesTableTable, Species>),
    Species,
    PrefetchHooks Function()>;
typedef $$ItemsTableTableCreateCompanionBuilder = ItemsTableCompanion Function({
  required String id,
  required String userId,
  required String definitionId,
  Value<String> affixesJson,
  required DateTime acquiredAt,
  Value<String?> acquiredInCellId,
  Value<String?> dailySeed,
  Value<String> status,
  Value<String> badgesJson,
  Value<String?> parentAId,
  Value<String?> parentBId,
  Value<String> displayName,
  Value<String?> scientificName,
  Value<String> categoryName,
  Value<String?> rarityName,
  Value<String> habitatsJson,
  Value<String> continentsJson,
  Value<String?> taxonomicClass,
  Value<String?> animalClassName,
  Value<String?> foodPreferenceName,
  Value<String?> climateName,
  Value<int?> brawn,
  Value<int?> wit,
  Value<int?> speed,
  Value<String?> sizeName,
  Value<String?> iconUrl,
  Value<String?> artUrl,
  Value<String?> cellHabitatName,
  Value<String?> cellClimateName,
  Value<String?> cellContinentName,
  Value<String?> locationDistrict,
  Value<String?> locationCity,
  Value<String?> locationState,
  Value<String?> locationCountry,
  Value<String?> locationCountryCode,
  Value<int> rowid,
});
typedef $$ItemsTableTableUpdateCompanionBuilder = ItemsTableCompanion Function({
  Value<String> id,
  Value<String> userId,
  Value<String> definitionId,
  Value<String> affixesJson,
  Value<DateTime> acquiredAt,
  Value<String?> acquiredInCellId,
  Value<String?> dailySeed,
  Value<String> status,
  Value<String> badgesJson,
  Value<String?> parentAId,
  Value<String?> parentBId,
  Value<String> displayName,
  Value<String?> scientificName,
  Value<String> categoryName,
  Value<String?> rarityName,
  Value<String> habitatsJson,
  Value<String> continentsJson,
  Value<String?> taxonomicClass,
  Value<String?> animalClassName,
  Value<String?> foodPreferenceName,
  Value<String?> climateName,
  Value<int?> brawn,
  Value<int?> wit,
  Value<int?> speed,
  Value<String?> sizeName,
  Value<String?> iconUrl,
  Value<String?> artUrl,
  Value<String?> cellHabitatName,
  Value<String?> cellClimateName,
  Value<String?> cellContinentName,
  Value<String?> locationDistrict,
  Value<String?> locationCity,
  Value<String?> locationState,
  Value<String?> locationCountry,
  Value<String?> locationCountryCode,
  Value<int> rowid,
});

class $$ItemsTableTableFilterComposer
    extends Composer<_$AppDatabase, $ItemsTableTable> {
  $$ItemsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get definitionId => $composableBuilder(
      column: $table.definitionId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get affixesJson => $composableBuilder(
      column: $table.affixesJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get acquiredAt => $composableBuilder(
      column: $table.acquiredAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get acquiredInCellId => $composableBuilder(
      column: $table.acquiredInCellId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get dailySeed => $composableBuilder(
      column: $table.dailySeed, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get badgesJson => $composableBuilder(
      column: $table.badgesJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get parentAId => $composableBuilder(
      column: $table.parentAId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get parentBId => $composableBuilder(
      column: $table.parentBId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get scientificName => $composableBuilder(
      column: $table.scientificName,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get categoryName => $composableBuilder(
      column: $table.categoryName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get rarityName => $composableBuilder(
      column: $table.rarityName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get habitatsJson => $composableBuilder(
      column: $table.habitatsJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get continentsJson => $composableBuilder(
      column: $table.continentsJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get taxonomicClass => $composableBuilder(
      column: $table.taxonomicClass,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get animalClassName => $composableBuilder(
      column: $table.animalClassName,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get foodPreferenceName => $composableBuilder(
      column: $table.foodPreferenceName,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get climateName => $composableBuilder(
      column: $table.climateName, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get brawn => $composableBuilder(
      column: $table.brawn, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get wit => $composableBuilder(
      column: $table.wit, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get speed => $composableBuilder(
      column: $table.speed, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sizeName => $composableBuilder(
      column: $table.sizeName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get iconUrl => $composableBuilder(
      column: $table.iconUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get artUrl => $composableBuilder(
      column: $table.artUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get cellHabitatName => $composableBuilder(
      column: $table.cellHabitatName,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get cellClimateName => $composableBuilder(
      column: $table.cellClimateName,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get cellContinentName => $composableBuilder(
      column: $table.cellContinentName,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get locationDistrict => $composableBuilder(
      column: $table.locationDistrict,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get locationCity => $composableBuilder(
      column: $table.locationCity, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get locationState => $composableBuilder(
      column: $table.locationState, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get locationCountry => $composableBuilder(
      column: $table.locationCountry,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get locationCountryCode => $composableBuilder(
      column: $table.locationCountryCode,
      builder: (column) => ColumnFilters(column));
}

class $$ItemsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ItemsTableTable> {
  $$ItemsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get definitionId => $composableBuilder(
      column: $table.definitionId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get affixesJson => $composableBuilder(
      column: $table.affixesJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get acquiredAt => $composableBuilder(
      column: $table.acquiredAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get acquiredInCellId => $composableBuilder(
      column: $table.acquiredInCellId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get dailySeed => $composableBuilder(
      column: $table.dailySeed, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get badgesJson => $composableBuilder(
      column: $table.badgesJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get parentAId => $composableBuilder(
      column: $table.parentAId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get parentBId => $composableBuilder(
      column: $table.parentBId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get scientificName => $composableBuilder(
      column: $table.scientificName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get categoryName => $composableBuilder(
      column: $table.categoryName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get rarityName => $composableBuilder(
      column: $table.rarityName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get habitatsJson => $composableBuilder(
      column: $table.habitatsJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get continentsJson => $composableBuilder(
      column: $table.continentsJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get taxonomicClass => $composableBuilder(
      column: $table.taxonomicClass,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get animalClassName => $composableBuilder(
      column: $table.animalClassName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get foodPreferenceName => $composableBuilder(
      column: $table.foodPreferenceName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get climateName => $composableBuilder(
      column: $table.climateName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get brawn => $composableBuilder(
      column: $table.brawn, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get wit => $composableBuilder(
      column: $table.wit, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get speed => $composableBuilder(
      column: $table.speed, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sizeName => $composableBuilder(
      column: $table.sizeName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get iconUrl => $composableBuilder(
      column: $table.iconUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get artUrl => $composableBuilder(
      column: $table.artUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get cellHabitatName => $composableBuilder(
      column: $table.cellHabitatName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get cellClimateName => $composableBuilder(
      column: $table.cellClimateName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get cellContinentName => $composableBuilder(
      column: $table.cellContinentName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get locationDistrict => $composableBuilder(
      column: $table.locationDistrict,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get locationCity => $composableBuilder(
      column: $table.locationCity,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get locationState => $composableBuilder(
      column: $table.locationState,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get locationCountry => $composableBuilder(
      column: $table.locationCountry,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get locationCountryCode => $composableBuilder(
      column: $table.locationCountryCode,
      builder: (column) => ColumnOrderings(column));
}

class $$ItemsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ItemsTableTable> {
  $$ItemsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get definitionId => $composableBuilder(
      column: $table.definitionId, builder: (column) => column);

  GeneratedColumn<String> get affixesJson => $composableBuilder(
      column: $table.affixesJson, builder: (column) => column);

  GeneratedColumn<DateTime> get acquiredAt => $composableBuilder(
      column: $table.acquiredAt, builder: (column) => column);

  GeneratedColumn<String> get acquiredInCellId => $composableBuilder(
      column: $table.acquiredInCellId, builder: (column) => column);

  GeneratedColumn<String> get dailySeed =>
      $composableBuilder(column: $table.dailySeed, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get badgesJson => $composableBuilder(
      column: $table.badgesJson, builder: (column) => column);

  GeneratedColumn<String> get parentAId =>
      $composableBuilder(column: $table.parentAId, builder: (column) => column);

  GeneratedColumn<String> get parentBId =>
      $composableBuilder(column: $table.parentBId, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => column);

  GeneratedColumn<String> get scientificName => $composableBuilder(
      column: $table.scientificName, builder: (column) => column);

  GeneratedColumn<String> get categoryName => $composableBuilder(
      column: $table.categoryName, builder: (column) => column);

  GeneratedColumn<String> get rarityName => $composableBuilder(
      column: $table.rarityName, builder: (column) => column);

  GeneratedColumn<String> get habitatsJson => $composableBuilder(
      column: $table.habitatsJson, builder: (column) => column);

  GeneratedColumn<String> get continentsJson => $composableBuilder(
      column: $table.continentsJson, builder: (column) => column);

  GeneratedColumn<String> get taxonomicClass => $composableBuilder(
      column: $table.taxonomicClass, builder: (column) => column);

  GeneratedColumn<String> get animalClassName => $composableBuilder(
      column: $table.animalClassName, builder: (column) => column);

  GeneratedColumn<String> get foodPreferenceName => $composableBuilder(
      column: $table.foodPreferenceName, builder: (column) => column);

  GeneratedColumn<String> get climateName => $composableBuilder(
      column: $table.climateName, builder: (column) => column);

  GeneratedColumn<int> get brawn =>
      $composableBuilder(column: $table.brawn, builder: (column) => column);

  GeneratedColumn<int> get wit =>
      $composableBuilder(column: $table.wit, builder: (column) => column);

  GeneratedColumn<int> get speed =>
      $composableBuilder(column: $table.speed, builder: (column) => column);

  GeneratedColumn<String> get sizeName =>
      $composableBuilder(column: $table.sizeName, builder: (column) => column);

  GeneratedColumn<String> get iconUrl =>
      $composableBuilder(column: $table.iconUrl, builder: (column) => column);

  GeneratedColumn<String> get artUrl =>
      $composableBuilder(column: $table.artUrl, builder: (column) => column);

  GeneratedColumn<String> get cellHabitatName => $composableBuilder(
      column: $table.cellHabitatName, builder: (column) => column);

  GeneratedColumn<String> get cellClimateName => $composableBuilder(
      column: $table.cellClimateName, builder: (column) => column);

  GeneratedColumn<String> get cellContinentName => $composableBuilder(
      column: $table.cellContinentName, builder: (column) => column);

  GeneratedColumn<String> get locationDistrict => $composableBuilder(
      column: $table.locationDistrict, builder: (column) => column);

  GeneratedColumn<String> get locationCity => $composableBuilder(
      column: $table.locationCity, builder: (column) => column);

  GeneratedColumn<String> get locationState => $composableBuilder(
      column: $table.locationState, builder: (column) => column);

  GeneratedColumn<String> get locationCountry => $composableBuilder(
      column: $table.locationCountry, builder: (column) => column);

  GeneratedColumn<String> get locationCountryCode => $composableBuilder(
      column: $table.locationCountryCode, builder: (column) => column);
}

class $$ItemsTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ItemsTableTable,
    Item,
    $$ItemsTableTableFilterComposer,
    $$ItemsTableTableOrderingComposer,
    $$ItemsTableTableAnnotationComposer,
    $$ItemsTableTableCreateCompanionBuilder,
    $$ItemsTableTableUpdateCompanionBuilder,
    (Item, BaseReferences<_$AppDatabase, $ItemsTableTable, Item>),
    Item,
    PrefetchHooks Function()> {
  $$ItemsTableTableTableManager(_$AppDatabase db, $ItemsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ItemsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ItemsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ItemsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<String> definitionId = const Value.absent(),
            Value<String> affixesJson = const Value.absent(),
            Value<DateTime> acquiredAt = const Value.absent(),
            Value<String?> acquiredInCellId = const Value.absent(),
            Value<String?> dailySeed = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String> badgesJson = const Value.absent(),
            Value<String?> parentAId = const Value.absent(),
            Value<String?> parentBId = const Value.absent(),
            Value<String> displayName = const Value.absent(),
            Value<String?> scientificName = const Value.absent(),
            Value<String> categoryName = const Value.absent(),
            Value<String?> rarityName = const Value.absent(),
            Value<String> habitatsJson = const Value.absent(),
            Value<String> continentsJson = const Value.absent(),
            Value<String?> taxonomicClass = const Value.absent(),
            Value<String?> animalClassName = const Value.absent(),
            Value<String?> foodPreferenceName = const Value.absent(),
            Value<String?> climateName = const Value.absent(),
            Value<int?> brawn = const Value.absent(),
            Value<int?> wit = const Value.absent(),
            Value<int?> speed = const Value.absent(),
            Value<String?> sizeName = const Value.absent(),
            Value<String?> iconUrl = const Value.absent(),
            Value<String?> artUrl = const Value.absent(),
            Value<String?> cellHabitatName = const Value.absent(),
            Value<String?> cellClimateName = const Value.absent(),
            Value<String?> cellContinentName = const Value.absent(),
            Value<String?> locationDistrict = const Value.absent(),
            Value<String?> locationCity = const Value.absent(),
            Value<String?> locationState = const Value.absent(),
            Value<String?> locationCountry = const Value.absent(),
            Value<String?> locationCountryCode = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ItemsTableCompanion(
            id: id,
            userId: userId,
            definitionId: definitionId,
            affixesJson: affixesJson,
            acquiredAt: acquiredAt,
            acquiredInCellId: acquiredInCellId,
            dailySeed: dailySeed,
            status: status,
            badgesJson: badgesJson,
            parentAId: parentAId,
            parentBId: parentBId,
            displayName: displayName,
            scientificName: scientificName,
            categoryName: categoryName,
            rarityName: rarityName,
            habitatsJson: habitatsJson,
            continentsJson: continentsJson,
            taxonomicClass: taxonomicClass,
            animalClassName: animalClassName,
            foodPreferenceName: foodPreferenceName,
            climateName: climateName,
            brawn: brawn,
            wit: wit,
            speed: speed,
            sizeName: sizeName,
            iconUrl: iconUrl,
            artUrl: artUrl,
            cellHabitatName: cellHabitatName,
            cellClimateName: cellClimateName,
            cellContinentName: cellContinentName,
            locationDistrict: locationDistrict,
            locationCity: locationCity,
            locationState: locationState,
            locationCountry: locationCountry,
            locationCountryCode: locationCountryCode,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String userId,
            required String definitionId,
            Value<String> affixesJson = const Value.absent(),
            required DateTime acquiredAt,
            Value<String?> acquiredInCellId = const Value.absent(),
            Value<String?> dailySeed = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String> badgesJson = const Value.absent(),
            Value<String?> parentAId = const Value.absent(),
            Value<String?> parentBId = const Value.absent(),
            Value<String> displayName = const Value.absent(),
            Value<String?> scientificName = const Value.absent(),
            Value<String> categoryName = const Value.absent(),
            Value<String?> rarityName = const Value.absent(),
            Value<String> habitatsJson = const Value.absent(),
            Value<String> continentsJson = const Value.absent(),
            Value<String?> taxonomicClass = const Value.absent(),
            Value<String?> animalClassName = const Value.absent(),
            Value<String?> foodPreferenceName = const Value.absent(),
            Value<String?> climateName = const Value.absent(),
            Value<int?> brawn = const Value.absent(),
            Value<int?> wit = const Value.absent(),
            Value<int?> speed = const Value.absent(),
            Value<String?> sizeName = const Value.absent(),
            Value<String?> iconUrl = const Value.absent(),
            Value<String?> artUrl = const Value.absent(),
            Value<String?> cellHabitatName = const Value.absent(),
            Value<String?> cellClimateName = const Value.absent(),
            Value<String?> cellContinentName = const Value.absent(),
            Value<String?> locationDistrict = const Value.absent(),
            Value<String?> locationCity = const Value.absent(),
            Value<String?> locationState = const Value.absent(),
            Value<String?> locationCountry = const Value.absent(),
            Value<String?> locationCountryCode = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ItemsTableCompanion.insert(
            id: id,
            userId: userId,
            definitionId: definitionId,
            affixesJson: affixesJson,
            acquiredAt: acquiredAt,
            acquiredInCellId: acquiredInCellId,
            dailySeed: dailySeed,
            status: status,
            badgesJson: badgesJson,
            parentAId: parentAId,
            parentBId: parentBId,
            displayName: displayName,
            scientificName: scientificName,
            categoryName: categoryName,
            rarityName: rarityName,
            habitatsJson: habitatsJson,
            continentsJson: continentsJson,
            taxonomicClass: taxonomicClass,
            animalClassName: animalClassName,
            foodPreferenceName: foodPreferenceName,
            climateName: climateName,
            brawn: brawn,
            wit: wit,
            speed: speed,
            sizeName: sizeName,
            iconUrl: iconUrl,
            artUrl: artUrl,
            cellHabitatName: cellHabitatName,
            cellClimateName: cellClimateName,
            cellContinentName: cellContinentName,
            locationDistrict: locationDistrict,
            locationCity: locationCity,
            locationState: locationState,
            locationCountry: locationCountry,
            locationCountryCode: locationCountryCode,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ItemsTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ItemsTableTable,
    Item,
    $$ItemsTableTableFilterComposer,
    $$ItemsTableTableOrderingComposer,
    $$ItemsTableTableAnnotationComposer,
    $$ItemsTableTableCreateCompanionBuilder,
    $$ItemsTableTableUpdateCompanionBuilder,
    (Item, BaseReferences<_$AppDatabase, $ItemsTableTable, Item>),
    Item,
    PrefetchHooks Function()>;
typedef $$CellVisitsTableTableCreateCompanionBuilder = CellVisitsTableCompanion
    Function({
  required String userId,
  required String cellId,
  Value<int> visitCount,
  Value<double> distanceWalked,
  Value<DateTime?> lastVisited,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$CellVisitsTableTableUpdateCompanionBuilder = CellVisitsTableCompanion
    Function({
  Value<String> userId,
  Value<String> cellId,
  Value<int> visitCount,
  Value<double> distanceWalked,
  Value<DateTime?> lastVisited,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$CellVisitsTableTableFilterComposer
    extends Composer<_$AppDatabase, $CellVisitsTableTable> {
  $$CellVisitsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get cellId => $composableBuilder(
      column: $table.cellId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get visitCount => $composableBuilder(
      column: $table.visitCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get distanceWalked => $composableBuilder(
      column: $table.distanceWalked,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastVisited => $composableBuilder(
      column: $table.lastVisited, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$CellVisitsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $CellVisitsTableTable> {
  $$CellVisitsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get cellId => $composableBuilder(
      column: $table.cellId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get visitCount => $composableBuilder(
      column: $table.visitCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get distanceWalked => $composableBuilder(
      column: $table.distanceWalked,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastVisited => $composableBuilder(
      column: $table.lastVisited, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$CellVisitsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $CellVisitsTableTable> {
  $$CellVisitsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get cellId =>
      $composableBuilder(column: $table.cellId, builder: (column) => column);

  GeneratedColumn<int> get visitCount => $composableBuilder(
      column: $table.visitCount, builder: (column) => column);

  GeneratedColumn<double> get distanceWalked => $composableBuilder(
      column: $table.distanceWalked, builder: (column) => column);

  GeneratedColumn<DateTime> get lastVisited => $composableBuilder(
      column: $table.lastVisited, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$CellVisitsTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CellVisitsTableTable,
    CellVisit,
    $$CellVisitsTableTableFilterComposer,
    $$CellVisitsTableTableOrderingComposer,
    $$CellVisitsTableTableAnnotationComposer,
    $$CellVisitsTableTableCreateCompanionBuilder,
    $$CellVisitsTableTableUpdateCompanionBuilder,
    (
      CellVisit,
      BaseReferences<_$AppDatabase, $CellVisitsTableTable, CellVisit>
    ),
    CellVisit,
    PrefetchHooks Function()> {
  $$CellVisitsTableTableTableManager(
      _$AppDatabase db, $CellVisitsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CellVisitsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CellVisitsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CellVisitsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> userId = const Value.absent(),
            Value<String> cellId = const Value.absent(),
            Value<int> visitCount = const Value.absent(),
            Value<double> distanceWalked = const Value.absent(),
            Value<DateTime?> lastVisited = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CellVisitsTableCompanion(
            userId: userId,
            cellId: cellId,
            visitCount: visitCount,
            distanceWalked: distanceWalked,
            lastVisited: lastVisited,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String userId,
            required String cellId,
            Value<int> visitCount = const Value.absent(),
            Value<double> distanceWalked = const Value.absent(),
            Value<DateTime?> lastVisited = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CellVisitsTableCompanion.insert(
            userId: userId,
            cellId: cellId,
            visitCount: visitCount,
            distanceWalked: distanceWalked,
            lastVisited: lastVisited,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CellVisitsTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CellVisitsTableTable,
    CellVisit,
    $$CellVisitsTableTableFilterComposer,
    $$CellVisitsTableTableOrderingComposer,
    $$CellVisitsTableTableAnnotationComposer,
    $$CellVisitsTableTableCreateCompanionBuilder,
    $$CellVisitsTableTableUpdateCompanionBuilder,
    (
      CellVisit,
      BaseReferences<_$AppDatabase, $CellVisitsTableTable, CellVisit>
    ),
    CellVisit,
    PrefetchHooks Function()>;
typedef $$CellPropertiesTableTableCreateCompanionBuilder
    = CellPropertiesTableCompanion Function({
  required String cellId,
  required String habitatsJson,
  required String climate,
  required String continent,
  Value<String?> locationId,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$CellPropertiesTableTableUpdateCompanionBuilder
    = CellPropertiesTableCompanion Function({
  Value<String> cellId,
  Value<String> habitatsJson,
  Value<String> climate,
  Value<String> continent,
  Value<String?> locationId,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$CellPropertiesTableTableFilterComposer
    extends Composer<_$AppDatabase, $CellPropertiesTableTable> {
  $$CellPropertiesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get cellId => $composableBuilder(
      column: $table.cellId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get habitatsJson => $composableBuilder(
      column: $table.habitatsJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get climate => $composableBuilder(
      column: $table.climate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get continent => $composableBuilder(
      column: $table.continent, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get locationId => $composableBuilder(
      column: $table.locationId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$CellPropertiesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $CellPropertiesTableTable> {
  $$CellPropertiesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get cellId => $composableBuilder(
      column: $table.cellId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get habitatsJson => $composableBuilder(
      column: $table.habitatsJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get climate => $composableBuilder(
      column: $table.climate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get continent => $composableBuilder(
      column: $table.continent, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get locationId => $composableBuilder(
      column: $table.locationId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$CellPropertiesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $CellPropertiesTableTable> {
  $$CellPropertiesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get cellId =>
      $composableBuilder(column: $table.cellId, builder: (column) => column);

  GeneratedColumn<String> get habitatsJson => $composableBuilder(
      column: $table.habitatsJson, builder: (column) => column);

  GeneratedColumn<String> get climate =>
      $composableBuilder(column: $table.climate, builder: (column) => column);

  GeneratedColumn<String> get continent =>
      $composableBuilder(column: $table.continent, builder: (column) => column);

  GeneratedColumn<String> get locationId => $composableBuilder(
      column: $table.locationId, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$CellPropertiesTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CellPropertiesTableTable,
    CellProperty,
    $$CellPropertiesTableTableFilterComposer,
    $$CellPropertiesTableTableOrderingComposer,
    $$CellPropertiesTableTableAnnotationComposer,
    $$CellPropertiesTableTableCreateCompanionBuilder,
    $$CellPropertiesTableTableUpdateCompanionBuilder,
    (
      CellProperty,
      BaseReferences<_$AppDatabase, $CellPropertiesTableTable, CellProperty>
    ),
    CellProperty,
    PrefetchHooks Function()> {
  $$CellPropertiesTableTableTableManager(
      _$AppDatabase db, $CellPropertiesTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CellPropertiesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CellPropertiesTableTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CellPropertiesTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> cellId = const Value.absent(),
            Value<String> habitatsJson = const Value.absent(),
            Value<String> climate = const Value.absent(),
            Value<String> continent = const Value.absent(),
            Value<String?> locationId = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CellPropertiesTableCompanion(
            cellId: cellId,
            habitatsJson: habitatsJson,
            climate: climate,
            continent: continent,
            locationId: locationId,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String cellId,
            required String habitatsJson,
            required String climate,
            required String continent,
            Value<String?> locationId = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CellPropertiesTableCompanion.insert(
            cellId: cellId,
            habitatsJson: habitatsJson,
            climate: climate,
            continent: continent,
            locationId: locationId,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CellPropertiesTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CellPropertiesTableTable,
    CellProperty,
    $$CellPropertiesTableTableFilterComposer,
    $$CellPropertiesTableTableOrderingComposer,
    $$CellPropertiesTableTableAnnotationComposer,
    $$CellPropertiesTableTableCreateCompanionBuilder,
    $$CellPropertiesTableTableUpdateCompanionBuilder,
    (
      CellProperty,
      BaseReferences<_$AppDatabase, $CellPropertiesTableTable, CellProperty>
    ),
    CellProperty,
    PrefetchHooks Function()>;
typedef $$CountriesTableTableCreateCompanionBuilder = CountriesTableCompanion
    Function({
  required String id,
  required String name,
  required double centroidLat,
  required double centroidLon,
  required String continent,
  Value<String?> boundaryJson,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$CountriesTableTableUpdateCompanionBuilder = CountriesTableCompanion
    Function({
  Value<String> id,
  Value<String> name,
  Value<double> centroidLat,
  Value<double> centroidLon,
  Value<String> continent,
  Value<String?> boundaryJson,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$CountriesTableTableFilterComposer
    extends Composer<_$AppDatabase, $CountriesTableTable> {
  $$CountriesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get centroidLat => $composableBuilder(
      column: $table.centroidLat, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get centroidLon => $composableBuilder(
      column: $table.centroidLon, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get continent => $composableBuilder(
      column: $table.continent, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get boundaryJson => $composableBuilder(
      column: $table.boundaryJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$CountriesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $CountriesTableTable> {
  $$CountriesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get centroidLat => $composableBuilder(
      column: $table.centroidLat, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get centroidLon => $composableBuilder(
      column: $table.centroidLon, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get continent => $composableBuilder(
      column: $table.continent, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get boundaryJson => $composableBuilder(
      column: $table.boundaryJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$CountriesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $CountriesTableTable> {
  $$CountriesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get centroidLat => $composableBuilder(
      column: $table.centroidLat, builder: (column) => column);

  GeneratedColumn<double> get centroidLon => $composableBuilder(
      column: $table.centroidLon, builder: (column) => column);

  GeneratedColumn<String> get continent =>
      $composableBuilder(column: $table.continent, builder: (column) => column);

  GeneratedColumn<String> get boundaryJson => $composableBuilder(
      column: $table.boundaryJson, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$CountriesTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CountriesTableTable,
    HierarchyCountry,
    $$CountriesTableTableFilterComposer,
    $$CountriesTableTableOrderingComposer,
    $$CountriesTableTableAnnotationComposer,
    $$CountriesTableTableCreateCompanionBuilder,
    $$CountriesTableTableUpdateCompanionBuilder,
    (
      HierarchyCountry,
      BaseReferences<_$AppDatabase, $CountriesTableTable, HierarchyCountry>
    ),
    HierarchyCountry,
    PrefetchHooks Function()> {
  $$CountriesTableTableTableManager(
      _$AppDatabase db, $CountriesTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CountriesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CountriesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CountriesTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<double> centroidLat = const Value.absent(),
            Value<double> centroidLon = const Value.absent(),
            Value<String> continent = const Value.absent(),
            Value<String?> boundaryJson = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CountriesTableCompanion(
            id: id,
            name: name,
            centroidLat: centroidLat,
            centroidLon: centroidLon,
            continent: continent,
            boundaryJson: boundaryJson,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required double centroidLat,
            required double centroidLon,
            required String continent,
            Value<String?> boundaryJson = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CountriesTableCompanion.insert(
            id: id,
            name: name,
            centroidLat: centroidLat,
            centroidLon: centroidLon,
            continent: continent,
            boundaryJson: boundaryJson,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CountriesTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CountriesTableTable,
    HierarchyCountry,
    $$CountriesTableTableFilterComposer,
    $$CountriesTableTableOrderingComposer,
    $$CountriesTableTableAnnotationComposer,
    $$CountriesTableTableCreateCompanionBuilder,
    $$CountriesTableTableUpdateCompanionBuilder,
    (
      HierarchyCountry,
      BaseReferences<_$AppDatabase, $CountriesTableTable, HierarchyCountry>
    ),
    HierarchyCountry,
    PrefetchHooks Function()>;
typedef $$StatesTableTableCreateCompanionBuilder = StatesTableCompanion
    Function({
  required String id,
  required String name,
  required double centroidLat,
  required double centroidLon,
  required String countryId,
  Value<String?> boundaryJson,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$StatesTableTableUpdateCompanionBuilder = StatesTableCompanion
    Function({
  Value<String> id,
  Value<String> name,
  Value<double> centroidLat,
  Value<double> centroidLon,
  Value<String> countryId,
  Value<String?> boundaryJson,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$StatesTableTableFilterComposer
    extends Composer<_$AppDatabase, $StatesTableTable> {
  $$StatesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get centroidLat => $composableBuilder(
      column: $table.centroidLat, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get centroidLon => $composableBuilder(
      column: $table.centroidLon, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get countryId => $composableBuilder(
      column: $table.countryId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get boundaryJson => $composableBuilder(
      column: $table.boundaryJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$StatesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $StatesTableTable> {
  $$StatesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get centroidLat => $composableBuilder(
      column: $table.centroidLat, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get centroidLon => $composableBuilder(
      column: $table.centroidLon, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get countryId => $composableBuilder(
      column: $table.countryId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get boundaryJson => $composableBuilder(
      column: $table.boundaryJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$StatesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $StatesTableTable> {
  $$StatesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get centroidLat => $composableBuilder(
      column: $table.centroidLat, builder: (column) => column);

  GeneratedColumn<double> get centroidLon => $composableBuilder(
      column: $table.centroidLon, builder: (column) => column);

  GeneratedColumn<String> get countryId =>
      $composableBuilder(column: $table.countryId, builder: (column) => column);

  GeneratedColumn<String> get boundaryJson => $composableBuilder(
      column: $table.boundaryJson, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$StatesTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $StatesTableTable,
    HierarchyState,
    $$StatesTableTableFilterComposer,
    $$StatesTableTableOrderingComposer,
    $$StatesTableTableAnnotationComposer,
    $$StatesTableTableCreateCompanionBuilder,
    $$StatesTableTableUpdateCompanionBuilder,
    (
      HierarchyState,
      BaseReferences<_$AppDatabase, $StatesTableTable, HierarchyState>
    ),
    HierarchyState,
    PrefetchHooks Function()> {
  $$StatesTableTableTableManager(_$AppDatabase db, $StatesTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StatesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StatesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StatesTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<double> centroidLat = const Value.absent(),
            Value<double> centroidLon = const Value.absent(),
            Value<String> countryId = const Value.absent(),
            Value<String?> boundaryJson = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              StatesTableCompanion(
            id: id,
            name: name,
            centroidLat: centroidLat,
            centroidLon: centroidLon,
            countryId: countryId,
            boundaryJson: boundaryJson,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required double centroidLat,
            required double centroidLon,
            required String countryId,
            Value<String?> boundaryJson = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              StatesTableCompanion.insert(
            id: id,
            name: name,
            centroidLat: centroidLat,
            centroidLon: centroidLon,
            countryId: countryId,
            boundaryJson: boundaryJson,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$StatesTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $StatesTableTable,
    HierarchyState,
    $$StatesTableTableFilterComposer,
    $$StatesTableTableOrderingComposer,
    $$StatesTableTableAnnotationComposer,
    $$StatesTableTableCreateCompanionBuilder,
    $$StatesTableTableUpdateCompanionBuilder,
    (
      HierarchyState,
      BaseReferences<_$AppDatabase, $StatesTableTable, HierarchyState>
    ),
    HierarchyState,
    PrefetchHooks Function()>;
typedef $$CitiesTableTableCreateCompanionBuilder = CitiesTableCompanion
    Function({
  required String id,
  required String name,
  required double centroidLat,
  required double centroidLon,
  required String stateId,
  Value<String?> boundaryJson,
  Value<int?> cellsTotal,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$CitiesTableTableUpdateCompanionBuilder = CitiesTableCompanion
    Function({
  Value<String> id,
  Value<String> name,
  Value<double> centroidLat,
  Value<double> centroidLon,
  Value<String> stateId,
  Value<String?> boundaryJson,
  Value<int?> cellsTotal,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$CitiesTableTableFilterComposer
    extends Composer<_$AppDatabase, $CitiesTableTable> {
  $$CitiesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get centroidLat => $composableBuilder(
      column: $table.centroidLat, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get centroidLon => $composableBuilder(
      column: $table.centroidLon, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get stateId => $composableBuilder(
      column: $table.stateId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get boundaryJson => $composableBuilder(
      column: $table.boundaryJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get cellsTotal => $composableBuilder(
      column: $table.cellsTotal, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$CitiesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $CitiesTableTable> {
  $$CitiesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get centroidLat => $composableBuilder(
      column: $table.centroidLat, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get centroidLon => $composableBuilder(
      column: $table.centroidLon, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get stateId => $composableBuilder(
      column: $table.stateId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get boundaryJson => $composableBuilder(
      column: $table.boundaryJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get cellsTotal => $composableBuilder(
      column: $table.cellsTotal, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$CitiesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $CitiesTableTable> {
  $$CitiesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get centroidLat => $composableBuilder(
      column: $table.centroidLat, builder: (column) => column);

  GeneratedColumn<double> get centroidLon => $composableBuilder(
      column: $table.centroidLon, builder: (column) => column);

  GeneratedColumn<String> get stateId =>
      $composableBuilder(column: $table.stateId, builder: (column) => column);

  GeneratedColumn<String> get boundaryJson => $composableBuilder(
      column: $table.boundaryJson, builder: (column) => column);

  GeneratedColumn<int> get cellsTotal => $composableBuilder(
      column: $table.cellsTotal, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$CitiesTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CitiesTableTable,
    HierarchyCity,
    $$CitiesTableTableFilterComposer,
    $$CitiesTableTableOrderingComposer,
    $$CitiesTableTableAnnotationComposer,
    $$CitiesTableTableCreateCompanionBuilder,
    $$CitiesTableTableUpdateCompanionBuilder,
    (
      HierarchyCity,
      BaseReferences<_$AppDatabase, $CitiesTableTable, HierarchyCity>
    ),
    HierarchyCity,
    PrefetchHooks Function()> {
  $$CitiesTableTableTableManager(_$AppDatabase db, $CitiesTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CitiesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CitiesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CitiesTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<double> centroidLat = const Value.absent(),
            Value<double> centroidLon = const Value.absent(),
            Value<String> stateId = const Value.absent(),
            Value<String?> boundaryJson = const Value.absent(),
            Value<int?> cellsTotal = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CitiesTableCompanion(
            id: id,
            name: name,
            centroidLat: centroidLat,
            centroidLon: centroidLon,
            stateId: stateId,
            boundaryJson: boundaryJson,
            cellsTotal: cellsTotal,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required double centroidLat,
            required double centroidLon,
            required String stateId,
            Value<String?> boundaryJson = const Value.absent(),
            Value<int?> cellsTotal = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CitiesTableCompanion.insert(
            id: id,
            name: name,
            centroidLat: centroidLat,
            centroidLon: centroidLon,
            stateId: stateId,
            boundaryJson: boundaryJson,
            cellsTotal: cellsTotal,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CitiesTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CitiesTableTable,
    HierarchyCity,
    $$CitiesTableTableFilterComposer,
    $$CitiesTableTableOrderingComposer,
    $$CitiesTableTableAnnotationComposer,
    $$CitiesTableTableCreateCompanionBuilder,
    $$CitiesTableTableUpdateCompanionBuilder,
    (
      HierarchyCity,
      BaseReferences<_$AppDatabase, $CitiesTableTable, HierarchyCity>
    ),
    HierarchyCity,
    PrefetchHooks Function()>;
typedef $$DistrictsTableTableCreateCompanionBuilder = DistrictsTableCompanion
    Function({
  required String id,
  required String name,
  required double centroidLat,
  required double centroidLon,
  required String cityId,
  Value<String?> boundaryJson,
  Value<int?> cellsTotal,
  Value<String> source,
  Value<String?> sourceId,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$DistrictsTableTableUpdateCompanionBuilder = DistrictsTableCompanion
    Function({
  Value<String> id,
  Value<String> name,
  Value<double> centroidLat,
  Value<double> centroidLon,
  Value<String> cityId,
  Value<String?> boundaryJson,
  Value<int?> cellsTotal,
  Value<String> source,
  Value<String?> sourceId,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$DistrictsTableTableFilterComposer
    extends Composer<_$AppDatabase, $DistrictsTableTable> {
  $$DistrictsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get centroidLat => $composableBuilder(
      column: $table.centroidLat, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get centroidLon => $composableBuilder(
      column: $table.centroidLon, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get cityId => $composableBuilder(
      column: $table.cityId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get boundaryJson => $composableBuilder(
      column: $table.boundaryJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get cellsTotal => $composableBuilder(
      column: $table.cellsTotal, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sourceId => $composableBuilder(
      column: $table.sourceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$DistrictsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $DistrictsTableTable> {
  $$DistrictsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get centroidLat => $composableBuilder(
      column: $table.centroidLat, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get centroidLon => $composableBuilder(
      column: $table.centroidLon, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get cityId => $composableBuilder(
      column: $table.cityId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get boundaryJson => $composableBuilder(
      column: $table.boundaryJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get cellsTotal => $composableBuilder(
      column: $table.cellsTotal, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sourceId => $composableBuilder(
      column: $table.sourceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$DistrictsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $DistrictsTableTable> {
  $$DistrictsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get centroidLat => $composableBuilder(
      column: $table.centroidLat, builder: (column) => column);

  GeneratedColumn<double> get centroidLon => $composableBuilder(
      column: $table.centroidLon, builder: (column) => column);

  GeneratedColumn<String> get cityId =>
      $composableBuilder(column: $table.cityId, builder: (column) => column);

  GeneratedColumn<String> get boundaryJson => $composableBuilder(
      column: $table.boundaryJson, builder: (column) => column);

  GeneratedColumn<int> get cellsTotal => $composableBuilder(
      column: $table.cellsTotal, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$DistrictsTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $DistrictsTableTable,
    HierarchyDistrict,
    $$DistrictsTableTableFilterComposer,
    $$DistrictsTableTableOrderingComposer,
    $$DistrictsTableTableAnnotationComposer,
    $$DistrictsTableTableCreateCompanionBuilder,
    $$DistrictsTableTableUpdateCompanionBuilder,
    (
      HierarchyDistrict,
      BaseReferences<_$AppDatabase, $DistrictsTableTable, HierarchyDistrict>
    ),
    HierarchyDistrict,
    PrefetchHooks Function()> {
  $$DistrictsTableTableTableManager(
      _$AppDatabase db, $DistrictsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DistrictsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DistrictsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DistrictsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<double> centroidLat = const Value.absent(),
            Value<double> centroidLon = const Value.absent(),
            Value<String> cityId = const Value.absent(),
            Value<String?> boundaryJson = const Value.absent(),
            Value<int?> cellsTotal = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<String?> sourceId = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DistrictsTableCompanion(
            id: id,
            name: name,
            centroidLat: centroidLat,
            centroidLon: centroidLon,
            cityId: cityId,
            boundaryJson: boundaryJson,
            cellsTotal: cellsTotal,
            source: source,
            sourceId: sourceId,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required double centroidLat,
            required double centroidLon,
            required String cityId,
            Value<String?> boundaryJson = const Value.absent(),
            Value<int?> cellsTotal = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<String?> sourceId = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DistrictsTableCompanion.insert(
            id: id,
            name: name,
            centroidLat: centroidLat,
            centroidLon: centroidLon,
            cityId: cityId,
            boundaryJson: boundaryJson,
            cellsTotal: cellsTotal,
            source: source,
            sourceId: sourceId,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$DistrictsTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $DistrictsTableTable,
    HierarchyDistrict,
    $$DistrictsTableTableFilterComposer,
    $$DistrictsTableTableOrderingComposer,
    $$DistrictsTableTableAnnotationComposer,
    $$DistrictsTableTableCreateCompanionBuilder,
    $$DistrictsTableTableUpdateCompanionBuilder,
    (
      HierarchyDistrict,
      BaseReferences<_$AppDatabase, $DistrictsTableTable, HierarchyDistrict>
    ),
    HierarchyDistrict,
    PrefetchHooks Function()>;
typedef $$WriteQueueTableTableCreateCompanionBuilder = WriteQueueTableCompanion
    Function({
  Value<int> id,
  required String entityType,
  required String entityId,
  required String operation,
  required String payload,
  required String userId,
  Value<String> status,
  Value<int> attempts,
  Value<String?> lastError,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});
typedef $$WriteQueueTableTableUpdateCompanionBuilder = WriteQueueTableCompanion
    Function({
  Value<int> id,
  Value<String> entityType,
  Value<String> entityId,
  Value<String> operation,
  Value<String> payload,
  Value<String> userId,
  Value<String> status,
  Value<int> attempts,
  Value<String?> lastError,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});

class $$WriteQueueTableTableFilterComposer
    extends Composer<_$AppDatabase, $WriteQueueTableTable> {
  $$WriteQueueTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get entityId => $composableBuilder(
      column: $table.entityId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get operation => $composableBuilder(
      column: $table.operation, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get attempts => $composableBuilder(
      column: $table.attempts, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$WriteQueueTableTableOrderingComposer
    extends Composer<_$AppDatabase, $WriteQueueTableTable> {
  $$WriteQueueTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get entityId => $composableBuilder(
      column: $table.entityId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get operation => $composableBuilder(
      column: $table.operation, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get attempts => $composableBuilder(
      column: $table.attempts, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$WriteQueueTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $WriteQueueTableTable> {
  $$WriteQueueTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$WriteQueueTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $WriteQueueTableTable,
    WriteQueueEntry,
    $$WriteQueueTableTableFilterComposer,
    $$WriteQueueTableTableOrderingComposer,
    $$WriteQueueTableTableAnnotationComposer,
    $$WriteQueueTableTableCreateCompanionBuilder,
    $$WriteQueueTableTableUpdateCompanionBuilder,
    (
      WriteQueueEntry,
      BaseReferences<_$AppDatabase, $WriteQueueTableTable, WriteQueueEntry>
    ),
    WriteQueueEntry,
    PrefetchHooks Function()> {
  $$WriteQueueTableTableTableManager(
      _$AppDatabase db, $WriteQueueTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WriteQueueTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WriteQueueTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WriteQueueTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> entityType = const Value.absent(),
            Value<String> entityId = const Value.absent(),
            Value<String> operation = const Value.absent(),
            Value<String> payload = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<int> attempts = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              WriteQueueTableCompanion(
            id: id,
            entityType: entityType,
            entityId: entityId,
            operation: operation,
            payload: payload,
            userId: userId,
            status: status,
            attempts: attempts,
            lastError: lastError,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String entityType,
            required String entityId,
            required String operation,
            required String payload,
            required String userId,
            Value<String> status = const Value.absent(),
            Value<int> attempts = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              WriteQueueTableCompanion.insert(
            id: id,
            entityType: entityType,
            entityId: entityId,
            operation: operation,
            payload: payload,
            userId: userId,
            status: status,
            attempts: attempts,
            lastError: lastError,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$WriteQueueTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $WriteQueueTableTable,
    WriteQueueEntry,
    $$WriteQueueTableTableFilterComposer,
    $$WriteQueueTableTableOrderingComposer,
    $$WriteQueueTableTableAnnotationComposer,
    $$WriteQueueTableTableCreateCompanionBuilder,
    $$WriteQueueTableTableUpdateCompanionBuilder,
    (
      WriteQueueEntry,
      BaseReferences<_$AppDatabase, $WriteQueueTableTable, WriteQueueEntry>
    ),
    WriteQueueEntry,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PlayersTableTableTableManager get playersTable =>
      $$PlayersTableTableTableManager(_db, _db.playersTable);
  $$SpeciesTableTableTableManager get speciesTable =>
      $$SpeciesTableTableTableManager(_db, _db.speciesTable);
  $$ItemsTableTableTableManager get itemsTable =>
      $$ItemsTableTableTableManager(_db, _db.itemsTable);
  $$CellVisitsTableTableTableManager get cellVisitsTable =>
      $$CellVisitsTableTableTableManager(_db, _db.cellVisitsTable);
  $$CellPropertiesTableTableTableManager get cellPropertiesTable =>
      $$CellPropertiesTableTableTableManager(_db, _db.cellPropertiesTable);
  $$CountriesTableTableTableManager get countriesTable =>
      $$CountriesTableTableTableManager(_db, _db.countriesTable);
  $$StatesTableTableTableManager get statesTable =>
      $$StatesTableTableTableManager(_db, _db.statesTable);
  $$CitiesTableTableTableManager get citiesTable =>
      $$CitiesTableTableTableManager(_db, _db.citiesTable);
  $$DistrictsTableTableTableManager get districtsTable =>
      $$DistrictsTableTableTableManager(_db, _db.districtsTable);
  $$WriteQueueTableTableTableManager get writeQueueTable =>
      $$WriteQueueTableTableTableManager(_db, _db.writeQueueTable);
}
