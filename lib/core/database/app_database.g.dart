// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $LocalCellProgressTableTable extends LocalCellProgressTable
    with TableInfo<$LocalCellProgressTableTable, LocalCellProgress> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalCellProgressTableTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _cellIdMeta = const VerificationMeta('cellId');
  @override
  late final GeneratedColumn<String> cellId = GeneratedColumn<String>(
      'cell_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _fogStateMeta =
      const VerificationMeta('fogState');
  @override
  late final GeneratedColumn<String> fogState = GeneratedColumn<String>(
      'fog_state', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _distanceWalkedMeta =
      const VerificationMeta('distanceWalked');
  @override
  late final GeneratedColumn<double> distanceWalked = GeneratedColumn<double>(
      'distance_walked', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _visitCountMeta =
      const VerificationMeta('visitCount');
  @override
  late final GeneratedColumn<int> visitCount = GeneratedColumn<int>(
      'visit_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _restorationLevelMeta =
      const VerificationMeta('restorationLevel');
  @override
  late final GeneratedColumn<double> restorationLevel = GeneratedColumn<double>(
      'restoration_level', aliasedName, false,
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
        userId,
        cellId,
        fogState,
        distanceWalked,
        visitCount,
        restorationLevel,
        lastVisited,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_cell_progress_table';
  @override
  VerificationContext validateIntegrity(Insertable<LocalCellProgress> instance,
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
    if (data.containsKey('cell_id')) {
      context.handle(_cellIdMeta,
          cellId.isAcceptableOrUnknown(data['cell_id']!, _cellIdMeta));
    } else if (isInserting) {
      context.missing(_cellIdMeta);
    }
    if (data.containsKey('fog_state')) {
      context.handle(_fogStateMeta,
          fogState.isAcceptableOrUnknown(data['fog_state']!, _fogStateMeta));
    } else if (isInserting) {
      context.missing(_fogStateMeta);
    }
    if (data.containsKey('distance_walked')) {
      context.handle(
          _distanceWalkedMeta,
          distanceWalked.isAcceptableOrUnknown(
              data['distance_walked']!, _distanceWalkedMeta));
    }
    if (data.containsKey('visit_count')) {
      context.handle(
          _visitCountMeta,
          visitCount.isAcceptableOrUnknown(
              data['visit_count']!, _visitCountMeta));
    }
    if (data.containsKey('restoration_level')) {
      context.handle(
          _restorationLevelMeta,
          restorationLevel.isAcceptableOrUnknown(
              data['restoration_level']!, _restorationLevelMeta));
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
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {userId, cellId},
      ];
  @override
  LocalCellProgress map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalCellProgress(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      cellId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cell_id'])!,
      fogState: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}fog_state'])!,
      distanceWalked: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}distance_walked'])!,
      visitCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}visit_count'])!,
      restorationLevel: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}restoration_level'])!,
      lastVisited: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}last_visited']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $LocalCellProgressTableTable createAlias(String alias) {
    return $LocalCellProgressTableTable(attachedDatabase, alias);
  }
}

class LocalCellProgress extends DataClass
    implements Insertable<LocalCellProgress> {
  final String id;
  final String userId;
  final String cellId;
  final String fogState;
  final double distanceWalked;
  final int visitCount;
  final double restorationLevel;
  final DateTime? lastVisited;
  final DateTime createdAt;
  final DateTime updatedAt;
  const LocalCellProgress(
      {required this.id,
      required this.userId,
      required this.cellId,
      required this.fogState,
      required this.distanceWalked,
      required this.visitCount,
      required this.restorationLevel,
      this.lastVisited,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['cell_id'] = Variable<String>(cellId);
    map['fog_state'] = Variable<String>(fogState);
    map['distance_walked'] = Variable<double>(distanceWalked);
    map['visit_count'] = Variable<int>(visitCount);
    map['restoration_level'] = Variable<double>(restorationLevel);
    if (!nullToAbsent || lastVisited != null) {
      map['last_visited'] = Variable<DateTime>(lastVisited);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LocalCellProgressTableCompanion toCompanion(bool nullToAbsent) {
    return LocalCellProgressTableCompanion(
      id: Value(id),
      userId: Value(userId),
      cellId: Value(cellId),
      fogState: Value(fogState),
      distanceWalked: Value(distanceWalked),
      visitCount: Value(visitCount),
      restorationLevel: Value(restorationLevel),
      lastVisited: lastVisited == null && nullToAbsent
          ? const Value.absent()
          : Value(lastVisited),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory LocalCellProgress.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalCellProgress(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      cellId: serializer.fromJson<String>(json['cellId']),
      fogState: serializer.fromJson<String>(json['fogState']),
      distanceWalked: serializer.fromJson<double>(json['distanceWalked']),
      visitCount: serializer.fromJson<int>(json['visitCount']),
      restorationLevel: serializer.fromJson<double>(json['restorationLevel']),
      lastVisited: serializer.fromJson<DateTime?>(json['lastVisited']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'cellId': serializer.toJson<String>(cellId),
      'fogState': serializer.toJson<String>(fogState),
      'distanceWalked': serializer.toJson<double>(distanceWalked),
      'visitCount': serializer.toJson<int>(visitCount),
      'restorationLevel': serializer.toJson<double>(restorationLevel),
      'lastVisited': serializer.toJson<DateTime?>(lastVisited),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LocalCellProgress copyWith(
          {String? id,
          String? userId,
          String? cellId,
          String? fogState,
          double? distanceWalked,
          int? visitCount,
          double? restorationLevel,
          Value<DateTime?> lastVisited = const Value.absent(),
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      LocalCellProgress(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        cellId: cellId ?? this.cellId,
        fogState: fogState ?? this.fogState,
        distanceWalked: distanceWalked ?? this.distanceWalked,
        visitCount: visitCount ?? this.visitCount,
        restorationLevel: restorationLevel ?? this.restorationLevel,
        lastVisited: lastVisited.present ? lastVisited.value : this.lastVisited,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  LocalCellProgress copyWithCompanion(LocalCellProgressTableCompanion data) {
    return LocalCellProgress(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      cellId: data.cellId.present ? data.cellId.value : this.cellId,
      fogState: data.fogState.present ? data.fogState.value : this.fogState,
      distanceWalked: data.distanceWalked.present
          ? data.distanceWalked.value
          : this.distanceWalked,
      visitCount:
          data.visitCount.present ? data.visitCount.value : this.visitCount,
      restorationLevel: data.restorationLevel.present
          ? data.restorationLevel.value
          : this.restorationLevel,
      lastVisited:
          data.lastVisited.present ? data.lastVisited.value : this.lastVisited,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalCellProgress(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('cellId: $cellId, ')
          ..write('fogState: $fogState, ')
          ..write('distanceWalked: $distanceWalked, ')
          ..write('visitCount: $visitCount, ')
          ..write('restorationLevel: $restorationLevel, ')
          ..write('lastVisited: $lastVisited, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, userId, cellId, fogState, distanceWalked,
      visitCount, restorationLevel, lastVisited, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalCellProgress &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.cellId == this.cellId &&
          other.fogState == this.fogState &&
          other.distanceWalked == this.distanceWalked &&
          other.visitCount == this.visitCount &&
          other.restorationLevel == this.restorationLevel &&
          other.lastVisited == this.lastVisited &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class LocalCellProgressTableCompanion
    extends UpdateCompanion<LocalCellProgress> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> cellId;
  final Value<String> fogState;
  final Value<double> distanceWalked;
  final Value<int> visitCount;
  final Value<double> restorationLevel;
  final Value<DateTime?> lastVisited;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const LocalCellProgressTableCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.cellId = const Value.absent(),
    this.fogState = const Value.absent(),
    this.distanceWalked = const Value.absent(),
    this.visitCount = const Value.absent(),
    this.restorationLevel = const Value.absent(),
    this.lastVisited = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalCellProgressTableCompanion.insert({
    required String id,
    required String userId,
    required String cellId,
    required String fogState,
    this.distanceWalked = const Value.absent(),
    this.visitCount = const Value.absent(),
    this.restorationLevel = const Value.absent(),
    this.lastVisited = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        userId = Value(userId),
        cellId = Value(cellId),
        fogState = Value(fogState);
  static Insertable<LocalCellProgress> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? cellId,
    Expression<String>? fogState,
    Expression<double>? distanceWalked,
    Expression<int>? visitCount,
    Expression<double>? restorationLevel,
    Expression<DateTime>? lastVisited,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (cellId != null) 'cell_id': cellId,
      if (fogState != null) 'fog_state': fogState,
      if (distanceWalked != null) 'distance_walked': distanceWalked,
      if (visitCount != null) 'visit_count': visitCount,
      if (restorationLevel != null) 'restoration_level': restorationLevel,
      if (lastVisited != null) 'last_visited': lastVisited,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalCellProgressTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? userId,
      Value<String>? cellId,
      Value<String>? fogState,
      Value<double>? distanceWalked,
      Value<int>? visitCount,
      Value<double>? restorationLevel,
      Value<DateTime?>? lastVisited,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return LocalCellProgressTableCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      cellId: cellId ?? this.cellId,
      fogState: fogState ?? this.fogState,
      distanceWalked: distanceWalked ?? this.distanceWalked,
      visitCount: visitCount ?? this.visitCount,
      restorationLevel: restorationLevel ?? this.restorationLevel,
      lastVisited: lastVisited ?? this.lastVisited,
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
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (cellId.present) {
      map['cell_id'] = Variable<String>(cellId.value);
    }
    if (fogState.present) {
      map['fog_state'] = Variable<String>(fogState.value);
    }
    if (distanceWalked.present) {
      map['distance_walked'] = Variable<double>(distanceWalked.value);
    }
    if (visitCount.present) {
      map['visit_count'] = Variable<int>(visitCount.value);
    }
    if (restorationLevel.present) {
      map['restoration_level'] = Variable<double>(restorationLevel.value);
    }
    if (lastVisited.present) {
      map['last_visited'] = Variable<DateTime>(lastVisited.value);
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
    return (StringBuffer('LocalCellProgressTableCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('cellId: $cellId, ')
          ..write('fogState: $fogState, ')
          ..write('distanceWalked: $distanceWalked, ')
          ..write('visitCount: $visitCount, ')
          ..write('restorationLevel: $restorationLevel, ')
          ..write('lastVisited: $lastVisited, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalCollectedSpeciesTableTable extends LocalCollectedSpeciesTable
    with TableInfo<$LocalCollectedSpeciesTableTable, LocalCollectedSpecies> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalCollectedSpeciesTableTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _speciesIdMeta =
      const VerificationMeta('speciesId');
  @override
  late final GeneratedColumn<String> speciesId = GeneratedColumn<String>(
      'species_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _cellIdMeta = const VerificationMeta('cellId');
  @override
  late final GeneratedColumn<String> cellId = GeneratedColumn<String>(
      'cell_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _collectedAtMeta =
      const VerificationMeta('collectedAt');
  @override
  late final GeneratedColumn<DateTime> collectedAt = GeneratedColumn<DateTime>(
      'collected_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, userId, speciesId, cellId, collectedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_collected_species_table';
  @override
  VerificationContext validateIntegrity(
      Insertable<LocalCollectedSpecies> instance,
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
    if (data.containsKey('species_id')) {
      context.handle(_speciesIdMeta,
          speciesId.isAcceptableOrUnknown(data['species_id']!, _speciesIdMeta));
    } else if (isInserting) {
      context.missing(_speciesIdMeta);
    }
    if (data.containsKey('cell_id')) {
      context.handle(_cellIdMeta,
          cellId.isAcceptableOrUnknown(data['cell_id']!, _cellIdMeta));
    } else if (isInserting) {
      context.missing(_cellIdMeta);
    }
    if (data.containsKey('collected_at')) {
      context.handle(
          _collectedAtMeta,
          collectedAt.isAcceptableOrUnknown(
              data['collected_at']!, _collectedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {userId, speciesId, cellId},
      ];
  @override
  LocalCollectedSpecies map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalCollectedSpecies(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      speciesId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}species_id'])!,
      cellId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cell_id'])!,
      collectedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}collected_at'])!,
    );
  }

  @override
  $LocalCollectedSpeciesTableTable createAlias(String alias) {
    return $LocalCollectedSpeciesTableTable(attachedDatabase, alias);
  }
}

class LocalCollectedSpecies extends DataClass
    implements Insertable<LocalCollectedSpecies> {
  final String id;
  final String userId;
  final String speciesId;
  final String cellId;
  final DateTime collectedAt;
  const LocalCollectedSpecies(
      {required this.id,
      required this.userId,
      required this.speciesId,
      required this.cellId,
      required this.collectedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['species_id'] = Variable<String>(speciesId);
    map['cell_id'] = Variable<String>(cellId);
    map['collected_at'] = Variable<DateTime>(collectedAt);
    return map;
  }

  LocalCollectedSpeciesTableCompanion toCompanion(bool nullToAbsent) {
    return LocalCollectedSpeciesTableCompanion(
      id: Value(id),
      userId: Value(userId),
      speciesId: Value(speciesId),
      cellId: Value(cellId),
      collectedAt: Value(collectedAt),
    );
  }

  factory LocalCollectedSpecies.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalCollectedSpecies(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      speciesId: serializer.fromJson<String>(json['speciesId']),
      cellId: serializer.fromJson<String>(json['cellId']),
      collectedAt: serializer.fromJson<DateTime>(json['collectedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'speciesId': serializer.toJson<String>(speciesId),
      'cellId': serializer.toJson<String>(cellId),
      'collectedAt': serializer.toJson<DateTime>(collectedAt),
    };
  }

  LocalCollectedSpecies copyWith(
          {String? id,
          String? userId,
          String? speciesId,
          String? cellId,
          DateTime? collectedAt}) =>
      LocalCollectedSpecies(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        speciesId: speciesId ?? this.speciesId,
        cellId: cellId ?? this.cellId,
        collectedAt: collectedAt ?? this.collectedAt,
      );
  LocalCollectedSpecies copyWithCompanion(
      LocalCollectedSpeciesTableCompanion data) {
    return LocalCollectedSpecies(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      speciesId: data.speciesId.present ? data.speciesId.value : this.speciesId,
      cellId: data.cellId.present ? data.cellId.value : this.cellId,
      collectedAt:
          data.collectedAt.present ? data.collectedAt.value : this.collectedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalCollectedSpecies(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('speciesId: $speciesId, ')
          ..write('cellId: $cellId, ')
          ..write('collectedAt: $collectedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, userId, speciesId, cellId, collectedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalCollectedSpecies &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.speciesId == this.speciesId &&
          other.cellId == this.cellId &&
          other.collectedAt == this.collectedAt);
}

class LocalCollectedSpeciesTableCompanion
    extends UpdateCompanion<LocalCollectedSpecies> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> speciesId;
  final Value<String> cellId;
  final Value<DateTime> collectedAt;
  final Value<int> rowid;
  const LocalCollectedSpeciesTableCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.speciesId = const Value.absent(),
    this.cellId = const Value.absent(),
    this.collectedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalCollectedSpeciesTableCompanion.insert({
    required String id,
    required String userId,
    required String speciesId,
    required String cellId,
    this.collectedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        userId = Value(userId),
        speciesId = Value(speciesId),
        cellId = Value(cellId);
  static Insertable<LocalCollectedSpecies> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? speciesId,
    Expression<String>? cellId,
    Expression<DateTime>? collectedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (speciesId != null) 'species_id': speciesId,
      if (cellId != null) 'cell_id': cellId,
      if (collectedAt != null) 'collected_at': collectedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalCollectedSpeciesTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? userId,
      Value<String>? speciesId,
      Value<String>? cellId,
      Value<DateTime>? collectedAt,
      Value<int>? rowid}) {
    return LocalCollectedSpeciesTableCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      speciesId: speciesId ?? this.speciesId,
      cellId: cellId ?? this.cellId,
      collectedAt: collectedAt ?? this.collectedAt,
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
    if (speciesId.present) {
      map['species_id'] = Variable<String>(speciesId.value);
    }
    if (cellId.present) {
      map['cell_id'] = Variable<String>(cellId.value);
    }
    if (collectedAt.present) {
      map['collected_at'] = Variable<DateTime>(collectedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalCollectedSpeciesTableCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('speciesId: $speciesId, ')
          ..write('cellId: $cellId, ')
          ..write('collectedAt: $collectedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalPlayerProfileTableTable extends LocalPlayerProfileTable
    with TableInfo<$LocalPlayerProfileTableTable, LocalPlayerProfile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalPlayerProfileTableTable(this.attachedDatabase, [this._alias]);
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
      type: DriftSqlType.string, requiredDuringInsert: true);
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
  static const VerificationMeta _totalDistanceKmMeta =
      const VerificationMeta('totalDistanceKm');
  @override
  late final GeneratedColumn<double> totalDistanceKm = GeneratedColumn<double>(
      'total_distance_km', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _currentSeasonMeta =
      const VerificationMeta('currentSeason');
  @override
  late final GeneratedColumn<String> currentSeason = GeneratedColumn<String>(
      'current_season', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('summer'));
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
        currentStreak,
        longestStreak,
        totalDistanceKm,
        currentSeason,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_player_profile_table';
  @override
  VerificationContext validateIntegrity(Insertable<LocalPlayerProfile> instance,
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
    } else if (isInserting) {
      context.missing(_displayNameMeta);
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
    if (data.containsKey('total_distance_km')) {
      context.handle(
          _totalDistanceKmMeta,
          totalDistanceKm.isAcceptableOrUnknown(
              data['total_distance_km']!, _totalDistanceKmMeta));
    }
    if (data.containsKey('current_season')) {
      context.handle(
          _currentSeasonMeta,
          currentSeason.isAcceptableOrUnknown(
              data['current_season']!, _currentSeasonMeta));
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
  LocalPlayerProfile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalPlayerProfile(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      displayName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}display_name'])!,
      currentStreak: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}current_streak'])!,
      longestStreak: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}longest_streak'])!,
      totalDistanceKm: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}total_distance_km'])!,
      currentSeason: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}current_season'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $LocalPlayerProfileTableTable createAlias(String alias) {
    return $LocalPlayerProfileTableTable(attachedDatabase, alias);
  }
}

class LocalPlayerProfile extends DataClass
    implements Insertable<LocalPlayerProfile> {
  final String id;
  final String displayName;
  final int currentStreak;
  final int longestStreak;
  final double totalDistanceKm;
  final String currentSeason;
  final DateTime createdAt;
  final DateTime updatedAt;
  const LocalPlayerProfile(
      {required this.id,
      required this.displayName,
      required this.currentStreak,
      required this.longestStreak,
      required this.totalDistanceKm,
      required this.currentSeason,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['display_name'] = Variable<String>(displayName);
    map['current_streak'] = Variable<int>(currentStreak);
    map['longest_streak'] = Variable<int>(longestStreak);
    map['total_distance_km'] = Variable<double>(totalDistanceKm);
    map['current_season'] = Variable<String>(currentSeason);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LocalPlayerProfileTableCompanion toCompanion(bool nullToAbsent) {
    return LocalPlayerProfileTableCompanion(
      id: Value(id),
      displayName: Value(displayName),
      currentStreak: Value(currentStreak),
      longestStreak: Value(longestStreak),
      totalDistanceKm: Value(totalDistanceKm),
      currentSeason: Value(currentSeason),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory LocalPlayerProfile.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalPlayerProfile(
      id: serializer.fromJson<String>(json['id']),
      displayName: serializer.fromJson<String>(json['displayName']),
      currentStreak: serializer.fromJson<int>(json['currentStreak']),
      longestStreak: serializer.fromJson<int>(json['longestStreak']),
      totalDistanceKm: serializer.fromJson<double>(json['totalDistanceKm']),
      currentSeason: serializer.fromJson<String>(json['currentSeason']),
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
      'currentStreak': serializer.toJson<int>(currentStreak),
      'longestStreak': serializer.toJson<int>(longestStreak),
      'totalDistanceKm': serializer.toJson<double>(totalDistanceKm),
      'currentSeason': serializer.toJson<String>(currentSeason),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LocalPlayerProfile copyWith(
          {String? id,
          String? displayName,
          int? currentStreak,
          int? longestStreak,
          double? totalDistanceKm,
          String? currentSeason,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      LocalPlayerProfile(
        id: id ?? this.id,
        displayName: displayName ?? this.displayName,
        currentStreak: currentStreak ?? this.currentStreak,
        longestStreak: longestStreak ?? this.longestStreak,
        totalDistanceKm: totalDistanceKm ?? this.totalDistanceKm,
        currentSeason: currentSeason ?? this.currentSeason,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  LocalPlayerProfile copyWithCompanion(LocalPlayerProfileTableCompanion data) {
    return LocalPlayerProfile(
      id: data.id.present ? data.id.value : this.id,
      displayName:
          data.displayName.present ? data.displayName.value : this.displayName,
      currentStreak: data.currentStreak.present
          ? data.currentStreak.value
          : this.currentStreak,
      longestStreak: data.longestStreak.present
          ? data.longestStreak.value
          : this.longestStreak,
      totalDistanceKm: data.totalDistanceKm.present
          ? data.totalDistanceKm.value
          : this.totalDistanceKm,
      currentSeason: data.currentSeason.present
          ? data.currentSeason.value
          : this.currentSeason,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalPlayerProfile(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('currentStreak: $currentStreak, ')
          ..write('longestStreak: $longestStreak, ')
          ..write('totalDistanceKm: $totalDistanceKm, ')
          ..write('currentSeason: $currentSeason, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, displayName, currentStreak, longestStreak,
      totalDistanceKm, currentSeason, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalPlayerProfile &&
          other.id == this.id &&
          other.displayName == this.displayName &&
          other.currentStreak == this.currentStreak &&
          other.longestStreak == this.longestStreak &&
          other.totalDistanceKm == this.totalDistanceKm &&
          other.currentSeason == this.currentSeason &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class LocalPlayerProfileTableCompanion
    extends UpdateCompanion<LocalPlayerProfile> {
  final Value<String> id;
  final Value<String> displayName;
  final Value<int> currentStreak;
  final Value<int> longestStreak;
  final Value<double> totalDistanceKm;
  final Value<String> currentSeason;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const LocalPlayerProfileTableCompanion({
    this.id = const Value.absent(),
    this.displayName = const Value.absent(),
    this.currentStreak = const Value.absent(),
    this.longestStreak = const Value.absent(),
    this.totalDistanceKm = const Value.absent(),
    this.currentSeason = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalPlayerProfileTableCompanion.insert({
    required String id,
    required String displayName,
    this.currentStreak = const Value.absent(),
    this.longestStreak = const Value.absent(),
    this.totalDistanceKm = const Value.absent(),
    this.currentSeason = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        displayName = Value(displayName);
  static Insertable<LocalPlayerProfile> custom({
    Expression<String>? id,
    Expression<String>? displayName,
    Expression<int>? currentStreak,
    Expression<int>? longestStreak,
    Expression<double>? totalDistanceKm,
    Expression<String>? currentSeason,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (displayName != null) 'display_name': displayName,
      if (currentStreak != null) 'current_streak': currentStreak,
      if (longestStreak != null) 'longest_streak': longestStreak,
      if (totalDistanceKm != null) 'total_distance_km': totalDistanceKm,
      if (currentSeason != null) 'current_season': currentSeason,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalPlayerProfileTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? displayName,
      Value<int>? currentStreak,
      Value<int>? longestStreak,
      Value<double>? totalDistanceKm,
      Value<String>? currentSeason,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return LocalPlayerProfileTableCompanion(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      totalDistanceKm: totalDistanceKm ?? this.totalDistanceKm,
      currentSeason: currentSeason ?? this.currentSeason,
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
    if (currentStreak.present) {
      map['current_streak'] = Variable<int>(currentStreak.value);
    }
    if (longestStreak.present) {
      map['longest_streak'] = Variable<int>(longestStreak.value);
    }
    if (totalDistanceKm.present) {
      map['total_distance_km'] = Variable<double>(totalDistanceKm.value);
    }
    if (currentSeason.present) {
      map['current_season'] = Variable<String>(currentSeason.value);
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
    return (StringBuffer('LocalPlayerProfileTableCompanion(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('currentStreak: $currentStreak, ')
          ..write('longestStreak: $longestStreak, ')
          ..write('totalDistanceKm: $totalDistanceKm, ')
          ..write('currentSeason: $currentSeason, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncQueueTableTable extends SyncQueueTable
    with TableInfo<$SyncQueueTableTable, SyncQueueEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncQueueTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
      'action', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _targetTableMeta =
      const VerificationMeta('targetTable');
  @override
  late final GeneratedColumn<String> targetTable = GeneratedColumn<String>(
      'target_table', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
      'data', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _timestampMeta =
      const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
      'timestamp', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, action, targetTable, data, timestamp];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_queue_table';
  @override
  VerificationContext validateIntegrity(Insertable<SyncQueueEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('action')) {
      context.handle(_actionMeta,
          action.isAcceptableOrUnknown(data['action']!, _actionMeta));
    } else if (isInserting) {
      context.missing(_actionMeta);
    }
    if (data.containsKey('target_table')) {
      context.handle(
          _targetTableMeta,
          targetTable.isAcceptableOrUnknown(
              data['target_table']!, _targetTableMeta));
    } else if (isInserting) {
      context.missing(_targetTableMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
          _dataMeta, this.data.isAcceptableOrUnknown(data['data']!, _dataMeta));
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta,
          timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncQueueEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncQueueEntry(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      action: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}action'])!,
      targetTable: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}target_table'])!,
      data: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}data'])!,
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}timestamp'])!,
    );
  }

  @override
  $SyncQueueTableTable createAlias(String alias) {
    return $SyncQueueTableTable(attachedDatabase, alias);
  }
}

class SyncQueueEntry extends DataClass implements Insertable<SyncQueueEntry> {
  final int id;
  final String action;
  final String targetTable;
  final String data;
  final DateTime timestamp;
  const SyncQueueEntry(
      {required this.id,
      required this.action,
      required this.targetTable,
      required this.data,
      required this.timestamp});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['action'] = Variable<String>(action);
    map['target_table'] = Variable<String>(targetTable);
    map['data'] = Variable<String>(data);
    map['timestamp'] = Variable<DateTime>(timestamp);
    return map;
  }

  SyncQueueTableCompanion toCompanion(bool nullToAbsent) {
    return SyncQueueTableCompanion(
      id: Value(id),
      action: Value(action),
      targetTable: Value(targetTable),
      data: Value(data),
      timestamp: Value(timestamp),
    );
  }

  factory SyncQueueEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncQueueEntry(
      id: serializer.fromJson<int>(json['id']),
      action: serializer.fromJson<String>(json['action']),
      targetTable: serializer.fromJson<String>(json['targetTable']),
      data: serializer.fromJson<String>(json['data']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'action': serializer.toJson<String>(action),
      'targetTable': serializer.toJson<String>(targetTable),
      'data': serializer.toJson<String>(data),
      'timestamp': serializer.toJson<DateTime>(timestamp),
    };
  }

  SyncQueueEntry copyWith(
          {int? id,
          String? action,
          String? targetTable,
          String? data,
          DateTime? timestamp}) =>
      SyncQueueEntry(
        id: id ?? this.id,
        action: action ?? this.action,
        targetTable: targetTable ?? this.targetTable,
        data: data ?? this.data,
        timestamp: timestamp ?? this.timestamp,
      );
  SyncQueueEntry copyWithCompanion(SyncQueueTableCompanion data) {
    return SyncQueueEntry(
      id: data.id.present ? data.id.value : this.id,
      action: data.action.present ? data.action.value : this.action,
      targetTable:
          data.targetTable.present ? data.targetTable.value : this.targetTable,
      data: data.data.present ? data.data.value : this.data,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueEntry(')
          ..write('id: $id, ')
          ..write('action: $action, ')
          ..write('targetTable: $targetTable, ')
          ..write('data: $data, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, action, targetTable, data, timestamp);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncQueueEntry &&
          other.id == this.id &&
          other.action == this.action &&
          other.targetTable == this.targetTable &&
          other.data == this.data &&
          other.timestamp == this.timestamp);
}

class SyncQueueTableCompanion extends UpdateCompanion<SyncQueueEntry> {
  final Value<int> id;
  final Value<String> action;
  final Value<String> targetTable;
  final Value<String> data;
  final Value<DateTime> timestamp;
  const SyncQueueTableCompanion({
    this.id = const Value.absent(),
    this.action = const Value.absent(),
    this.targetTable = const Value.absent(),
    this.data = const Value.absent(),
    this.timestamp = const Value.absent(),
  });
  SyncQueueTableCompanion.insert({
    this.id = const Value.absent(),
    required String action,
    required String targetTable,
    required String data,
    this.timestamp = const Value.absent(),
  })  : action = Value(action),
        targetTable = Value(targetTable),
        data = Value(data);
  static Insertable<SyncQueueEntry> custom({
    Expression<int>? id,
    Expression<String>? action,
    Expression<String>? targetTable,
    Expression<String>? data,
    Expression<DateTime>? timestamp,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (action != null) 'action': action,
      if (targetTable != null) 'target_table': targetTable,
      if (data != null) 'data': data,
      if (timestamp != null) 'timestamp': timestamp,
    });
  }

  SyncQueueTableCompanion copyWith(
      {Value<int>? id,
      Value<String>? action,
      Value<String>? targetTable,
      Value<String>? data,
      Value<DateTime>? timestamp}) {
    return SyncQueueTableCompanion(
      id: id ?? this.id,
      action: action ?? this.action,
      targetTable: targetTable ?? this.targetTable,
      data: data ?? this.data,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (targetTable.present) {
      map['target_table'] = Variable<String>(targetTable.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueTableCompanion(')
          ..write('id: $id, ')
          ..write('action: $action, ')
          ..write('targetTable: $targetTable, ')
          ..write('data: $data, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LocalCellProgressTableTable localCellProgressTable =
      $LocalCellProgressTableTable(this);
  late final $LocalCollectedSpeciesTableTable localCollectedSpeciesTable =
      $LocalCollectedSpeciesTableTable(this);
  late final $LocalPlayerProfileTableTable localPlayerProfileTable =
      $LocalPlayerProfileTableTable(this);
  late final $SyncQueueTableTable syncQueueTable = $SyncQueueTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        localCellProgressTable,
        localCollectedSpeciesTable,
        localPlayerProfileTable,
        syncQueueTable
      ];
}

typedef $$LocalCellProgressTableTableCreateCompanionBuilder
    = LocalCellProgressTableCompanion Function({
  required String id,
  required String userId,
  required String cellId,
  required String fogState,
  Value<double> distanceWalked,
  Value<int> visitCount,
  Value<double> restorationLevel,
  Value<DateTime?> lastVisited,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});
typedef $$LocalCellProgressTableTableUpdateCompanionBuilder
    = LocalCellProgressTableCompanion Function({
  Value<String> id,
  Value<String> userId,
  Value<String> cellId,
  Value<String> fogState,
  Value<double> distanceWalked,
  Value<int> visitCount,
  Value<double> restorationLevel,
  Value<DateTime?> lastVisited,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$LocalCellProgressTableTableFilterComposer
    extends Composer<_$AppDatabase, $LocalCellProgressTableTable> {
  $$LocalCellProgressTableTableFilterComposer({
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

  ColumnFilters<String> get cellId => $composableBuilder(
      column: $table.cellId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fogState => $composableBuilder(
      column: $table.fogState, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get distanceWalked => $composableBuilder(
      column: $table.distanceWalked,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get visitCount => $composableBuilder(
      column: $table.visitCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get restorationLevel => $composableBuilder(
      column: $table.restorationLevel,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastVisited => $composableBuilder(
      column: $table.lastVisited, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$LocalCellProgressTableTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalCellProgressTableTable> {
  $$LocalCellProgressTableTableOrderingComposer({
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

  ColumnOrderings<String> get cellId => $composableBuilder(
      column: $table.cellId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fogState => $composableBuilder(
      column: $table.fogState, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get distanceWalked => $composableBuilder(
      column: $table.distanceWalked,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get visitCount => $composableBuilder(
      column: $table.visitCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get restorationLevel => $composableBuilder(
      column: $table.restorationLevel,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastVisited => $composableBuilder(
      column: $table.lastVisited, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$LocalCellProgressTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalCellProgressTableTable> {
  $$LocalCellProgressTableTableAnnotationComposer({
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

  GeneratedColumn<String> get cellId =>
      $composableBuilder(column: $table.cellId, builder: (column) => column);

  GeneratedColumn<String> get fogState =>
      $composableBuilder(column: $table.fogState, builder: (column) => column);

  GeneratedColumn<double> get distanceWalked => $composableBuilder(
      column: $table.distanceWalked, builder: (column) => column);

  GeneratedColumn<int> get visitCount => $composableBuilder(
      column: $table.visitCount, builder: (column) => column);

  GeneratedColumn<double> get restorationLevel => $composableBuilder(
      column: $table.restorationLevel, builder: (column) => column);

  GeneratedColumn<DateTime> get lastVisited => $composableBuilder(
      column: $table.lastVisited, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LocalCellProgressTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LocalCellProgressTableTable,
    LocalCellProgress,
    $$LocalCellProgressTableTableFilterComposer,
    $$LocalCellProgressTableTableOrderingComposer,
    $$LocalCellProgressTableTableAnnotationComposer,
    $$LocalCellProgressTableTableCreateCompanionBuilder,
    $$LocalCellProgressTableTableUpdateCompanionBuilder,
    (
      LocalCellProgress,
      BaseReferences<_$AppDatabase, $LocalCellProgressTableTable,
          LocalCellProgress>
    ),
    LocalCellProgress,
    PrefetchHooks Function()> {
  $$LocalCellProgressTableTableTableManager(
      _$AppDatabase db, $LocalCellProgressTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalCellProgressTableTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalCellProgressTableTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalCellProgressTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<String> cellId = const Value.absent(),
            Value<String> fogState = const Value.absent(),
            Value<double> distanceWalked = const Value.absent(),
            Value<int> visitCount = const Value.absent(),
            Value<double> restorationLevel = const Value.absent(),
            Value<DateTime?> lastVisited = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalCellProgressTableCompanion(
            id: id,
            userId: userId,
            cellId: cellId,
            fogState: fogState,
            distanceWalked: distanceWalked,
            visitCount: visitCount,
            restorationLevel: restorationLevel,
            lastVisited: lastVisited,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String userId,
            required String cellId,
            required String fogState,
            Value<double> distanceWalked = const Value.absent(),
            Value<int> visitCount = const Value.absent(),
            Value<double> restorationLevel = const Value.absent(),
            Value<DateTime?> lastVisited = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalCellProgressTableCompanion.insert(
            id: id,
            userId: userId,
            cellId: cellId,
            fogState: fogState,
            distanceWalked: distanceWalked,
            visitCount: visitCount,
            restorationLevel: restorationLevel,
            lastVisited: lastVisited,
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

typedef $$LocalCellProgressTableTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $LocalCellProgressTableTable,
        LocalCellProgress,
        $$LocalCellProgressTableTableFilterComposer,
        $$LocalCellProgressTableTableOrderingComposer,
        $$LocalCellProgressTableTableAnnotationComposer,
        $$LocalCellProgressTableTableCreateCompanionBuilder,
        $$LocalCellProgressTableTableUpdateCompanionBuilder,
        (
          LocalCellProgress,
          BaseReferences<_$AppDatabase, $LocalCellProgressTableTable,
              LocalCellProgress>
        ),
        LocalCellProgress,
        PrefetchHooks Function()>;
typedef $$LocalCollectedSpeciesTableTableCreateCompanionBuilder
    = LocalCollectedSpeciesTableCompanion Function({
  required String id,
  required String userId,
  required String speciesId,
  required String cellId,
  Value<DateTime> collectedAt,
  Value<int> rowid,
});
typedef $$LocalCollectedSpeciesTableTableUpdateCompanionBuilder
    = LocalCollectedSpeciesTableCompanion Function({
  Value<String> id,
  Value<String> userId,
  Value<String> speciesId,
  Value<String> cellId,
  Value<DateTime> collectedAt,
  Value<int> rowid,
});

class $$LocalCollectedSpeciesTableTableFilterComposer
    extends Composer<_$AppDatabase, $LocalCollectedSpeciesTableTable> {
  $$LocalCollectedSpeciesTableTableFilterComposer({
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

  ColumnFilters<String> get speciesId => $composableBuilder(
      column: $table.speciesId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get cellId => $composableBuilder(
      column: $table.cellId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get collectedAt => $composableBuilder(
      column: $table.collectedAt, builder: (column) => ColumnFilters(column));
}

class $$LocalCollectedSpeciesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalCollectedSpeciesTableTable> {
  $$LocalCollectedSpeciesTableTableOrderingComposer({
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

  ColumnOrderings<String> get speciesId => $composableBuilder(
      column: $table.speciesId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get cellId => $composableBuilder(
      column: $table.cellId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get collectedAt => $composableBuilder(
      column: $table.collectedAt, builder: (column) => ColumnOrderings(column));
}

class $$LocalCollectedSpeciesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalCollectedSpeciesTableTable> {
  $$LocalCollectedSpeciesTableTableAnnotationComposer({
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

  GeneratedColumn<String> get speciesId =>
      $composableBuilder(column: $table.speciesId, builder: (column) => column);

  GeneratedColumn<String> get cellId =>
      $composableBuilder(column: $table.cellId, builder: (column) => column);

  GeneratedColumn<DateTime> get collectedAt => $composableBuilder(
      column: $table.collectedAt, builder: (column) => column);
}

class $$LocalCollectedSpeciesTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LocalCollectedSpeciesTableTable,
    LocalCollectedSpecies,
    $$LocalCollectedSpeciesTableTableFilterComposer,
    $$LocalCollectedSpeciesTableTableOrderingComposer,
    $$LocalCollectedSpeciesTableTableAnnotationComposer,
    $$LocalCollectedSpeciesTableTableCreateCompanionBuilder,
    $$LocalCollectedSpeciesTableTableUpdateCompanionBuilder,
    (
      LocalCollectedSpecies,
      BaseReferences<_$AppDatabase, $LocalCollectedSpeciesTableTable,
          LocalCollectedSpecies>
    ),
    LocalCollectedSpecies,
    PrefetchHooks Function()> {
  $$LocalCollectedSpeciesTableTableTableManager(
      _$AppDatabase db, $LocalCollectedSpeciesTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalCollectedSpeciesTableTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalCollectedSpeciesTableTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalCollectedSpeciesTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<String> speciesId = const Value.absent(),
            Value<String> cellId = const Value.absent(),
            Value<DateTime> collectedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalCollectedSpeciesTableCompanion(
            id: id,
            userId: userId,
            speciesId: speciesId,
            cellId: cellId,
            collectedAt: collectedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String userId,
            required String speciesId,
            required String cellId,
            Value<DateTime> collectedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalCollectedSpeciesTableCompanion.insert(
            id: id,
            userId: userId,
            speciesId: speciesId,
            cellId: cellId,
            collectedAt: collectedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalCollectedSpeciesTableTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $LocalCollectedSpeciesTableTable,
        LocalCollectedSpecies,
        $$LocalCollectedSpeciesTableTableFilterComposer,
        $$LocalCollectedSpeciesTableTableOrderingComposer,
        $$LocalCollectedSpeciesTableTableAnnotationComposer,
        $$LocalCollectedSpeciesTableTableCreateCompanionBuilder,
        $$LocalCollectedSpeciesTableTableUpdateCompanionBuilder,
        (
          LocalCollectedSpecies,
          BaseReferences<_$AppDatabase, $LocalCollectedSpeciesTableTable,
              LocalCollectedSpecies>
        ),
        LocalCollectedSpecies,
        PrefetchHooks Function()>;
typedef $$LocalPlayerProfileTableTableCreateCompanionBuilder
    = LocalPlayerProfileTableCompanion Function({
  required String id,
  required String displayName,
  Value<int> currentStreak,
  Value<int> longestStreak,
  Value<double> totalDistanceKm,
  Value<String> currentSeason,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});
typedef $$LocalPlayerProfileTableTableUpdateCompanionBuilder
    = LocalPlayerProfileTableCompanion Function({
  Value<String> id,
  Value<String> displayName,
  Value<int> currentStreak,
  Value<int> longestStreak,
  Value<double> totalDistanceKm,
  Value<String> currentSeason,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$LocalPlayerProfileTableTableFilterComposer
    extends Composer<_$AppDatabase, $LocalPlayerProfileTableTable> {
  $$LocalPlayerProfileTableTableFilterComposer({
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

  ColumnFilters<int> get currentStreak => $composableBuilder(
      column: $table.currentStreak, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get longestStreak => $composableBuilder(
      column: $table.longestStreak, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get totalDistanceKm => $composableBuilder(
      column: $table.totalDistanceKm,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currentSeason => $composableBuilder(
      column: $table.currentSeason, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$LocalPlayerProfileTableTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalPlayerProfileTableTable> {
  $$LocalPlayerProfileTableTableOrderingComposer({
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

  ColumnOrderings<int> get currentStreak => $composableBuilder(
      column: $table.currentStreak,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get longestStreak => $composableBuilder(
      column: $table.longestStreak,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get totalDistanceKm => $composableBuilder(
      column: $table.totalDistanceKm,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currentSeason => $composableBuilder(
      column: $table.currentSeason,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$LocalPlayerProfileTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalPlayerProfileTableTable> {
  $$LocalPlayerProfileTableTableAnnotationComposer({
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

  GeneratedColumn<int> get currentStreak => $composableBuilder(
      column: $table.currentStreak, builder: (column) => column);

  GeneratedColumn<int> get longestStreak => $composableBuilder(
      column: $table.longestStreak, builder: (column) => column);

  GeneratedColumn<double> get totalDistanceKm => $composableBuilder(
      column: $table.totalDistanceKm, builder: (column) => column);

  GeneratedColumn<String> get currentSeason => $composableBuilder(
      column: $table.currentSeason, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LocalPlayerProfileTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LocalPlayerProfileTableTable,
    LocalPlayerProfile,
    $$LocalPlayerProfileTableTableFilterComposer,
    $$LocalPlayerProfileTableTableOrderingComposer,
    $$LocalPlayerProfileTableTableAnnotationComposer,
    $$LocalPlayerProfileTableTableCreateCompanionBuilder,
    $$LocalPlayerProfileTableTableUpdateCompanionBuilder,
    (
      LocalPlayerProfile,
      BaseReferences<_$AppDatabase, $LocalPlayerProfileTableTable,
          LocalPlayerProfile>
    ),
    LocalPlayerProfile,
    PrefetchHooks Function()> {
  $$LocalPlayerProfileTableTableTableManager(
      _$AppDatabase db, $LocalPlayerProfileTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalPlayerProfileTableTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalPlayerProfileTableTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalPlayerProfileTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> displayName = const Value.absent(),
            Value<int> currentStreak = const Value.absent(),
            Value<int> longestStreak = const Value.absent(),
            Value<double> totalDistanceKm = const Value.absent(),
            Value<String> currentSeason = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalPlayerProfileTableCompanion(
            id: id,
            displayName: displayName,
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            totalDistanceKm: totalDistanceKm,
            currentSeason: currentSeason,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String displayName,
            Value<int> currentStreak = const Value.absent(),
            Value<int> longestStreak = const Value.absent(),
            Value<double> totalDistanceKm = const Value.absent(),
            Value<String> currentSeason = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalPlayerProfileTableCompanion.insert(
            id: id,
            displayName: displayName,
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            totalDistanceKm: totalDistanceKm,
            currentSeason: currentSeason,
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

typedef $$LocalPlayerProfileTableTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $LocalPlayerProfileTableTable,
        LocalPlayerProfile,
        $$LocalPlayerProfileTableTableFilterComposer,
        $$LocalPlayerProfileTableTableOrderingComposer,
        $$LocalPlayerProfileTableTableAnnotationComposer,
        $$LocalPlayerProfileTableTableCreateCompanionBuilder,
        $$LocalPlayerProfileTableTableUpdateCompanionBuilder,
        (
          LocalPlayerProfile,
          BaseReferences<_$AppDatabase, $LocalPlayerProfileTableTable,
              LocalPlayerProfile>
        ),
        LocalPlayerProfile,
        PrefetchHooks Function()>;
typedef $$SyncQueueTableTableCreateCompanionBuilder = SyncQueueTableCompanion
    Function({
  Value<int> id,
  required String action,
  required String targetTable,
  required String data,
  Value<DateTime> timestamp,
});
typedef $$SyncQueueTableTableUpdateCompanionBuilder = SyncQueueTableCompanion
    Function({
  Value<int> id,
  Value<String> action,
  Value<String> targetTable,
  Value<String> data,
  Value<DateTime> timestamp,
});

class $$SyncQueueTableTableFilterComposer
    extends Composer<_$AppDatabase, $SyncQueueTableTable> {
  $$SyncQueueTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get action => $composableBuilder(
      column: $table.action, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get targetTable => $composableBuilder(
      column: $table.targetTable, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get data => $composableBuilder(
      column: $table.data, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnFilters(column));
}

class $$SyncQueueTableTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncQueueTableTable> {
  $$SyncQueueTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get action => $composableBuilder(
      column: $table.action, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get targetTable => $composableBuilder(
      column: $table.targetTable, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get data => $composableBuilder(
      column: $table.data, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnOrderings(column));
}

class $$SyncQueueTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncQueueTableTable> {
  $$SyncQueueTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<String> get targetTable => $composableBuilder(
      column: $table.targetTable, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);
}

class $$SyncQueueTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SyncQueueTableTable,
    SyncQueueEntry,
    $$SyncQueueTableTableFilterComposer,
    $$SyncQueueTableTableOrderingComposer,
    $$SyncQueueTableTableAnnotationComposer,
    $$SyncQueueTableTableCreateCompanionBuilder,
    $$SyncQueueTableTableUpdateCompanionBuilder,
    (
      SyncQueueEntry,
      BaseReferences<_$AppDatabase, $SyncQueueTableTable, SyncQueueEntry>
    ),
    SyncQueueEntry,
    PrefetchHooks Function()> {
  $$SyncQueueTableTableTableManager(
      _$AppDatabase db, $SyncQueueTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncQueueTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncQueueTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncQueueTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> action = const Value.absent(),
            Value<String> targetTable = const Value.absent(),
            Value<String> data = const Value.absent(),
            Value<DateTime> timestamp = const Value.absent(),
          }) =>
              SyncQueueTableCompanion(
            id: id,
            action: action,
            targetTable: targetTable,
            data: data,
            timestamp: timestamp,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String action,
            required String targetTable,
            required String data,
            Value<DateTime> timestamp = const Value.absent(),
          }) =>
              SyncQueueTableCompanion.insert(
            id: id,
            action: action,
            targetTable: targetTable,
            data: data,
            timestamp: timestamp,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SyncQueueTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SyncQueueTableTable,
    SyncQueueEntry,
    $$SyncQueueTableTableFilterComposer,
    $$SyncQueueTableTableOrderingComposer,
    $$SyncQueueTableTableAnnotationComposer,
    $$SyncQueueTableTableCreateCompanionBuilder,
    $$SyncQueueTableTableUpdateCompanionBuilder,
    (
      SyncQueueEntry,
      BaseReferences<_$AppDatabase, $SyncQueueTableTable, SyncQueueEntry>
    ),
    SyncQueueEntry,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LocalCellProgressTableTableTableManager get localCellProgressTable =>
      $$LocalCellProgressTableTableTableManager(
          _db, _db.localCellProgressTable);
  $$LocalCollectedSpeciesTableTableTableManager
      get localCollectedSpeciesTable =>
          $$LocalCollectedSpeciesTableTableTableManager(
              _db, _db.localCollectedSpeciesTable);
  $$LocalPlayerProfileTableTableTableManager get localPlayerProfileTable =>
      $$LocalPlayerProfileTableTableTableManager(
          _db, _db.localPlayerProfileTable);
  $$SyncQueueTableTableTableManager get syncQueueTable =>
      $$SyncQueueTableTableTableManager(_db, _db.syncQueueTable);
}
