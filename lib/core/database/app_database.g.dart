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

class $LocalItemInstanceTableTable extends LocalItemInstanceTable
    with TableInfo<$LocalItemInstanceTableTable, LocalItemInstance> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalItemInstanceTableTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _affixesMeta =
      const VerificationMeta('affixes');
  @override
  late final GeneratedColumn<String> affixes = GeneratedColumn<String>(
      'affixes', aliasedName, false,
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
  static const VerificationMeta _animalClassNameMeta =
      const VerificationMeta('animalClassName');
  @override
  late final GeneratedColumn<String> animalClassName = GeneratedColumn<String>(
      'animal_class_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _animalClassNameEnrichverMeta =
      const VerificationMeta('animalClassNameEnrichver');
  @override
  late final GeneratedColumn<String> animalClassNameEnrichver =
      GeneratedColumn<String>('animal_class_name_enrichver', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _foodPreferenceNameMeta =
      const VerificationMeta('foodPreferenceName');
  @override
  late final GeneratedColumn<String> foodPreferenceName =
      GeneratedColumn<String>('food_preference_name', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _foodPreferenceNameEnrichverMeta =
      const VerificationMeta('foodPreferenceNameEnrichver');
  @override
  late final GeneratedColumn<String> foodPreferenceNameEnrichver =
      GeneratedColumn<String>(
          'food_preference_name_enrichver', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _climateNameMeta =
      const VerificationMeta('climateName');
  @override
  late final GeneratedColumn<String> climateName = GeneratedColumn<String>(
      'climate_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _climateNameEnrichverMeta =
      const VerificationMeta('climateNameEnrichver');
  @override
  late final GeneratedColumn<String> climateNameEnrichver =
      GeneratedColumn<String>('climate_name_enrichver', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _brawnMeta = const VerificationMeta('brawn');
  @override
  late final GeneratedColumn<int> brawn = GeneratedColumn<int>(
      'brawn', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _brawnEnrichverMeta =
      const VerificationMeta('brawnEnrichver');
  @override
  late final GeneratedColumn<String> brawnEnrichver = GeneratedColumn<String>(
      'brawn_enrichver', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _witMeta = const VerificationMeta('wit');
  @override
  late final GeneratedColumn<int> wit = GeneratedColumn<int>(
      'wit', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _witEnrichverMeta =
      const VerificationMeta('witEnrichver');
  @override
  late final GeneratedColumn<String> witEnrichver = GeneratedColumn<String>(
      'wit_enrichver', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _speedMeta = const VerificationMeta('speed');
  @override
  late final GeneratedColumn<int> speed = GeneratedColumn<int>(
      'speed', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _speedEnrichverMeta =
      const VerificationMeta('speedEnrichver');
  @override
  late final GeneratedColumn<String> speedEnrichver = GeneratedColumn<String>(
      'speed_enrichver', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sizeNameMeta =
      const VerificationMeta('sizeName');
  @override
  late final GeneratedColumn<String> sizeName = GeneratedColumn<String>(
      'size_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sizeNameEnrichverMeta =
      const VerificationMeta('sizeNameEnrichver');
  @override
  late final GeneratedColumn<String> sizeNameEnrichver =
      GeneratedColumn<String>('size_name_enrichver', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _iconUrlEnrichverMeta =
      const VerificationMeta('iconUrlEnrichver');
  @override
  late final GeneratedColumn<String> iconUrlEnrichver = GeneratedColumn<String>(
      'icon_url_enrichver', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _artUrlEnrichverMeta =
      const VerificationMeta('artUrlEnrichver');
  @override
  late final GeneratedColumn<String> artUrlEnrichver = GeneratedColumn<String>(
      'art_url_enrichver', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _cellHabitatNameMeta =
      const VerificationMeta('cellHabitatName');
  @override
  late final GeneratedColumn<String> cellHabitatName = GeneratedColumn<String>(
      'cell_habitat_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _cellHabitatNameEnrichverMeta =
      const VerificationMeta('cellHabitatNameEnrichver');
  @override
  late final GeneratedColumn<String> cellHabitatNameEnrichver =
      GeneratedColumn<String>('cell_habitat_name_enrichver', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _cellClimateNameMeta =
      const VerificationMeta('cellClimateName');
  @override
  late final GeneratedColumn<String> cellClimateName = GeneratedColumn<String>(
      'cell_climate_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _cellClimateNameEnrichverMeta =
      const VerificationMeta('cellClimateNameEnrichver');
  @override
  late final GeneratedColumn<String> cellClimateNameEnrichver =
      GeneratedColumn<String>('cell_climate_name_enrichver', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _cellContinentNameMeta =
      const VerificationMeta('cellContinentName');
  @override
  late final GeneratedColumn<String> cellContinentName =
      GeneratedColumn<String>('cell_continent_name', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _cellContinentNameEnrichverMeta =
      const VerificationMeta('cellContinentNameEnrichver');
  @override
  late final GeneratedColumn<String> cellContinentNameEnrichver =
      GeneratedColumn<String>(
          'cell_continent_name_enrichver', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _locationDistrictMeta =
      const VerificationMeta('locationDistrict');
  @override
  late final GeneratedColumn<String> locationDistrict = GeneratedColumn<String>(
      'location_district', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _locationDistrictEnrichverMeta =
      const VerificationMeta('locationDistrictEnrichver');
  @override
  late final GeneratedColumn<String> locationDistrictEnrichver =
      GeneratedColumn<String>('location_district_enrichver', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _locationCityMeta =
      const VerificationMeta('locationCity');
  @override
  late final GeneratedColumn<String> locationCity = GeneratedColumn<String>(
      'location_city', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _locationCityEnrichverMeta =
      const VerificationMeta('locationCityEnrichver');
  @override
  late final GeneratedColumn<String> locationCityEnrichver =
      GeneratedColumn<String>('location_city_enrichver', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _locationStateMeta =
      const VerificationMeta('locationState');
  @override
  late final GeneratedColumn<String> locationState = GeneratedColumn<String>(
      'location_state', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _locationStateEnrichverMeta =
      const VerificationMeta('locationStateEnrichver');
  @override
  late final GeneratedColumn<String> locationStateEnrichver =
      GeneratedColumn<String>('location_state_enrichver', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _locationCountryMeta =
      const VerificationMeta('locationCountry');
  @override
  late final GeneratedColumn<String> locationCountry = GeneratedColumn<String>(
      'location_country', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _locationCountryEnrichverMeta =
      const VerificationMeta('locationCountryEnrichver');
  @override
  late final GeneratedColumn<String> locationCountryEnrichver =
      GeneratedColumn<String>('location_country_enrichver', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _locationCountryCodeMeta =
      const VerificationMeta('locationCountryCode');
  @override
  late final GeneratedColumn<String> locationCountryCode =
      GeneratedColumn<String>('location_country_code', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _locationCountryCodeEnrichverMeta =
      const VerificationMeta('locationCountryCodeEnrichver');
  @override
  late final GeneratedColumn<String> locationCountryCodeEnrichver =
      GeneratedColumn<String>(
          'location_country_code_enrichver', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        userId,
        definitionId,
        affixes,
        parentAId,
        parentBId,
        acquiredAt,
        acquiredInCellId,
        dailySeed,
        status,
        badgesJson,
        displayName,
        scientificName,
        categoryName,
        rarityName,
        habitatsJson,
        continentsJson,
        taxonomicClass,
        iconUrl,
        artUrl,
        animalClassName,
        animalClassNameEnrichver,
        foodPreferenceName,
        foodPreferenceNameEnrichver,
        climateName,
        climateNameEnrichver,
        brawn,
        brawnEnrichver,
        wit,
        witEnrichver,
        speed,
        speedEnrichver,
        sizeName,
        sizeNameEnrichver,
        iconUrlEnrichver,
        artUrlEnrichver,
        cellHabitatName,
        cellHabitatNameEnrichver,
        cellClimateName,
        cellClimateNameEnrichver,
        cellContinentName,
        cellContinentNameEnrichver,
        locationDistrict,
        locationDistrictEnrichver,
        locationCity,
        locationCityEnrichver,
        locationState,
        locationStateEnrichver,
        locationCountry,
        locationCountryEnrichver,
        locationCountryCode,
        locationCountryCodeEnrichver
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_item_instance_table';
  @override
  VerificationContext validateIntegrity(Insertable<LocalItemInstance> instance,
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
    if (data.containsKey('affixes')) {
      context.handle(_affixesMeta,
          affixes.isAcceptableOrUnknown(data['affixes']!, _affixesMeta));
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
    if (data.containsKey('icon_url')) {
      context.handle(_iconUrlMeta,
          iconUrl.isAcceptableOrUnknown(data['icon_url']!, _iconUrlMeta));
    }
    if (data.containsKey('art_url')) {
      context.handle(_artUrlMeta,
          artUrl.isAcceptableOrUnknown(data['art_url']!, _artUrlMeta));
    }
    if (data.containsKey('animal_class_name')) {
      context.handle(
          _animalClassNameMeta,
          animalClassName.isAcceptableOrUnknown(
              data['animal_class_name']!, _animalClassNameMeta));
    }
    if (data.containsKey('animal_class_name_enrichver')) {
      context.handle(
          _animalClassNameEnrichverMeta,
          animalClassNameEnrichver.isAcceptableOrUnknown(
              data['animal_class_name_enrichver']!,
              _animalClassNameEnrichverMeta));
    }
    if (data.containsKey('food_preference_name')) {
      context.handle(
          _foodPreferenceNameMeta,
          foodPreferenceName.isAcceptableOrUnknown(
              data['food_preference_name']!, _foodPreferenceNameMeta));
    }
    if (data.containsKey('food_preference_name_enrichver')) {
      context.handle(
          _foodPreferenceNameEnrichverMeta,
          foodPreferenceNameEnrichver.isAcceptableOrUnknown(
              data['food_preference_name_enrichver']!,
              _foodPreferenceNameEnrichverMeta));
    }
    if (data.containsKey('climate_name')) {
      context.handle(
          _climateNameMeta,
          climateName.isAcceptableOrUnknown(
              data['climate_name']!, _climateNameMeta));
    }
    if (data.containsKey('climate_name_enrichver')) {
      context.handle(
          _climateNameEnrichverMeta,
          climateNameEnrichver.isAcceptableOrUnknown(
              data['climate_name_enrichver']!, _climateNameEnrichverMeta));
    }
    if (data.containsKey('brawn')) {
      context.handle(
          _brawnMeta, brawn.isAcceptableOrUnknown(data['brawn']!, _brawnMeta));
    }
    if (data.containsKey('brawn_enrichver')) {
      context.handle(
          _brawnEnrichverMeta,
          brawnEnrichver.isAcceptableOrUnknown(
              data['brawn_enrichver']!, _brawnEnrichverMeta));
    }
    if (data.containsKey('wit')) {
      context.handle(
          _witMeta, wit.isAcceptableOrUnknown(data['wit']!, _witMeta));
    }
    if (data.containsKey('wit_enrichver')) {
      context.handle(
          _witEnrichverMeta,
          witEnrichver.isAcceptableOrUnknown(
              data['wit_enrichver']!, _witEnrichverMeta));
    }
    if (data.containsKey('speed')) {
      context.handle(
          _speedMeta, speed.isAcceptableOrUnknown(data['speed']!, _speedMeta));
    }
    if (data.containsKey('speed_enrichver')) {
      context.handle(
          _speedEnrichverMeta,
          speedEnrichver.isAcceptableOrUnknown(
              data['speed_enrichver']!, _speedEnrichverMeta));
    }
    if (data.containsKey('size_name')) {
      context.handle(_sizeNameMeta,
          sizeName.isAcceptableOrUnknown(data['size_name']!, _sizeNameMeta));
    }
    if (data.containsKey('size_name_enrichver')) {
      context.handle(
          _sizeNameEnrichverMeta,
          sizeNameEnrichver.isAcceptableOrUnknown(
              data['size_name_enrichver']!, _sizeNameEnrichverMeta));
    }
    if (data.containsKey('icon_url_enrichver')) {
      context.handle(
          _iconUrlEnrichverMeta,
          iconUrlEnrichver.isAcceptableOrUnknown(
              data['icon_url_enrichver']!, _iconUrlEnrichverMeta));
    }
    if (data.containsKey('art_url_enrichver')) {
      context.handle(
          _artUrlEnrichverMeta,
          artUrlEnrichver.isAcceptableOrUnknown(
              data['art_url_enrichver']!, _artUrlEnrichverMeta));
    }
    if (data.containsKey('cell_habitat_name')) {
      context.handle(
          _cellHabitatNameMeta,
          cellHabitatName.isAcceptableOrUnknown(
              data['cell_habitat_name']!, _cellHabitatNameMeta));
    }
    if (data.containsKey('cell_habitat_name_enrichver')) {
      context.handle(
          _cellHabitatNameEnrichverMeta,
          cellHabitatNameEnrichver.isAcceptableOrUnknown(
              data['cell_habitat_name_enrichver']!,
              _cellHabitatNameEnrichverMeta));
    }
    if (data.containsKey('cell_climate_name')) {
      context.handle(
          _cellClimateNameMeta,
          cellClimateName.isAcceptableOrUnknown(
              data['cell_climate_name']!, _cellClimateNameMeta));
    }
    if (data.containsKey('cell_climate_name_enrichver')) {
      context.handle(
          _cellClimateNameEnrichverMeta,
          cellClimateNameEnrichver.isAcceptableOrUnknown(
              data['cell_climate_name_enrichver']!,
              _cellClimateNameEnrichverMeta));
    }
    if (data.containsKey('cell_continent_name')) {
      context.handle(
          _cellContinentNameMeta,
          cellContinentName.isAcceptableOrUnknown(
              data['cell_continent_name']!, _cellContinentNameMeta));
    }
    if (data.containsKey('cell_continent_name_enrichver')) {
      context.handle(
          _cellContinentNameEnrichverMeta,
          cellContinentNameEnrichver.isAcceptableOrUnknown(
              data['cell_continent_name_enrichver']!,
              _cellContinentNameEnrichverMeta));
    }
    if (data.containsKey('location_district')) {
      context.handle(
          _locationDistrictMeta,
          locationDistrict.isAcceptableOrUnknown(
              data['location_district']!, _locationDistrictMeta));
    }
    if (data.containsKey('location_district_enrichver')) {
      context.handle(
          _locationDistrictEnrichverMeta,
          locationDistrictEnrichver.isAcceptableOrUnknown(
              data['location_district_enrichver']!,
              _locationDistrictEnrichverMeta));
    }
    if (data.containsKey('location_city')) {
      context.handle(
          _locationCityMeta,
          locationCity.isAcceptableOrUnknown(
              data['location_city']!, _locationCityMeta));
    }
    if (data.containsKey('location_city_enrichver')) {
      context.handle(
          _locationCityEnrichverMeta,
          locationCityEnrichver.isAcceptableOrUnknown(
              data['location_city_enrichver']!, _locationCityEnrichverMeta));
    }
    if (data.containsKey('location_state')) {
      context.handle(
          _locationStateMeta,
          locationState.isAcceptableOrUnknown(
              data['location_state']!, _locationStateMeta));
    }
    if (data.containsKey('location_state_enrichver')) {
      context.handle(
          _locationStateEnrichverMeta,
          locationStateEnrichver.isAcceptableOrUnknown(
              data['location_state_enrichver']!, _locationStateEnrichverMeta));
    }
    if (data.containsKey('location_country')) {
      context.handle(
          _locationCountryMeta,
          locationCountry.isAcceptableOrUnknown(
              data['location_country']!, _locationCountryMeta));
    }
    if (data.containsKey('location_country_enrichver')) {
      context.handle(
          _locationCountryEnrichverMeta,
          locationCountryEnrichver.isAcceptableOrUnknown(
              data['location_country_enrichver']!,
              _locationCountryEnrichverMeta));
    }
    if (data.containsKey('location_country_code')) {
      context.handle(
          _locationCountryCodeMeta,
          locationCountryCode.isAcceptableOrUnknown(
              data['location_country_code']!, _locationCountryCodeMeta));
    }
    if (data.containsKey('location_country_code_enrichver')) {
      context.handle(
          _locationCountryCodeEnrichverMeta,
          locationCountryCodeEnrichver.isAcceptableOrUnknown(
              data['location_country_code_enrichver']!,
              _locationCountryCodeEnrichverMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalItemInstance map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalItemInstance(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      definitionId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}definition_id'])!,
      affixes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}affixes'])!,
      parentAId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}parent_a_id']),
      parentBId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}parent_b_id']),
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
      iconUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}icon_url']),
      artUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}art_url']),
      animalClassName: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}animal_class_name']),
      animalClassNameEnrichver: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}animal_class_name_enrichver']),
      foodPreferenceName: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}food_preference_name']),
      foodPreferenceNameEnrichver: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}food_preference_name_enrichver']),
      climateName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}climate_name']),
      climateNameEnrichver: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}climate_name_enrichver']),
      brawn: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}brawn']),
      brawnEnrichver: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}brawn_enrichver']),
      wit: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}wit']),
      witEnrichver: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}wit_enrichver']),
      speed: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}speed']),
      speedEnrichver: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}speed_enrichver']),
      sizeName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}size_name']),
      sizeNameEnrichver: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}size_name_enrichver']),
      iconUrlEnrichver: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}icon_url_enrichver']),
      artUrlEnrichver: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}art_url_enrichver']),
      cellHabitatName: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}cell_habitat_name']),
      cellHabitatNameEnrichver: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}cell_habitat_name_enrichver']),
      cellClimateName: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}cell_climate_name']),
      cellClimateNameEnrichver: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}cell_climate_name_enrichver']),
      cellContinentName: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}cell_continent_name']),
      cellContinentNameEnrichver: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}cell_continent_name_enrichver']),
      locationDistrict: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}location_district']),
      locationDistrictEnrichver: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}location_district_enrichver']),
      locationCity: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}location_city']),
      locationCityEnrichver: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}location_city_enrichver']),
      locationState: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}location_state']),
      locationStateEnrichver: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}location_state_enrichver']),
      locationCountry: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}location_country']),
      locationCountryEnrichver: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}location_country_enrichver']),
      locationCountryCode: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}location_country_code']),
      locationCountryCodeEnrichver: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}location_country_code_enrichver']),
    );
  }

  @override
  $LocalItemInstanceTableTable createAlias(String alias) {
    return $LocalItemInstanceTableTable(attachedDatabase, alias);
  }
}

class LocalItemInstance extends DataClass
    implements Insertable<LocalItemInstance> {
  /// UUID v4 — globally unique item ID.
  final String id;

  /// Owner's user ID.
  final String userId;

  /// References ItemDefinition.id (e.g. "fauna_vulpes_vulpes").
  final String definitionId;

  /// JSON-encoded list of Affix objects.
  final String affixes;

  /// Null for wild-caught. Set for bred offspring.
  final String? parentAId;

  /// Null for wild-caught. Set for bred offspring.
  final String? parentBId;

  /// When the player acquired this item.
  final DateTime acquiredAt;

  /// Cell where this item was found. Null for bred items.
  final String? acquiredInCellId;

  /// Daily seed used for this roll (server re-derivation).
  final String? dailySeed;

  /// Lifecycle status: active, donated, placed, released, traded.
  final String status;

  /// JSON-encoded list of badge strings (e.g. '["first_discovery","beta"]').
  final String badgesJson;

  /// Human-readable display name (e.g. "Red Fox"). Snapshotted at discovery.
  final String displayName;

  /// Scientific name. Null for non-biological items.
  final String? scientificName;

  /// Item category (e.g. "fauna", "flora"). Snapshotted at discovery.
  final String categoryName;

  /// IUCN rarity tier name (e.g. "leastConcern"). Null if no rarity.
  final String? rarityName;

  /// JSON-encoded list of habitat name strings (e.g. '["forest","plains"]').
  final String habitatsJson;

  /// JSON-encoded list of continent name strings (e.g. '["asia","europe"]').
  final String continentsJson;

  /// Taxonomic class string (e.g. "Mammalia"). Fauna only — null otherwise.
  final String? taxonomicClass;

  /// Denormalized icon URL (from species enrichment). Null = not enriched yet.
  final String? iconUrl;

  /// Denormalized art URL (from species enrichment). Null = not enriched yet.
  final String? artUrl;
  final String? animalClassName;
  final String? animalClassNameEnrichver;
  final String? foodPreferenceName;
  final String? foodPreferenceNameEnrichver;
  final String? climateName;
  final String? climateNameEnrichver;
  final int? brawn;
  final String? brawnEnrichver;
  final int? wit;
  final String? witEnrichver;
  final int? speed;
  final String? speedEnrichver;
  final String? sizeName;
  final String? sizeNameEnrichver;
  final String? iconUrlEnrichver;
  final String? artUrlEnrichver;
  final String? cellHabitatName;
  final String? cellHabitatNameEnrichver;
  final String? cellClimateName;
  final String? cellClimateNameEnrichver;
  final String? cellContinentName;
  final String? cellContinentNameEnrichver;
  final String? locationDistrict;
  final String? locationDistrictEnrichver;
  final String? locationCity;
  final String? locationCityEnrichver;
  final String? locationState;
  final String? locationStateEnrichver;
  final String? locationCountry;
  final String? locationCountryEnrichver;
  final String? locationCountryCode;
  final String? locationCountryCodeEnrichver;
  const LocalItemInstance(
      {required this.id,
      required this.userId,
      required this.definitionId,
      required this.affixes,
      this.parentAId,
      this.parentBId,
      required this.acquiredAt,
      this.acquiredInCellId,
      this.dailySeed,
      required this.status,
      required this.badgesJson,
      required this.displayName,
      this.scientificName,
      required this.categoryName,
      this.rarityName,
      required this.habitatsJson,
      required this.continentsJson,
      this.taxonomicClass,
      this.iconUrl,
      this.artUrl,
      this.animalClassName,
      this.animalClassNameEnrichver,
      this.foodPreferenceName,
      this.foodPreferenceNameEnrichver,
      this.climateName,
      this.climateNameEnrichver,
      this.brawn,
      this.brawnEnrichver,
      this.wit,
      this.witEnrichver,
      this.speed,
      this.speedEnrichver,
      this.sizeName,
      this.sizeNameEnrichver,
      this.iconUrlEnrichver,
      this.artUrlEnrichver,
      this.cellHabitatName,
      this.cellHabitatNameEnrichver,
      this.cellClimateName,
      this.cellClimateNameEnrichver,
      this.cellContinentName,
      this.cellContinentNameEnrichver,
      this.locationDistrict,
      this.locationDistrictEnrichver,
      this.locationCity,
      this.locationCityEnrichver,
      this.locationState,
      this.locationStateEnrichver,
      this.locationCountry,
      this.locationCountryEnrichver,
      this.locationCountryCode,
      this.locationCountryCodeEnrichver});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['definition_id'] = Variable<String>(definitionId);
    map['affixes'] = Variable<String>(affixes);
    if (!nullToAbsent || parentAId != null) {
      map['parent_a_id'] = Variable<String>(parentAId);
    }
    if (!nullToAbsent || parentBId != null) {
      map['parent_b_id'] = Variable<String>(parentBId);
    }
    map['acquired_at'] = Variable<DateTime>(acquiredAt);
    if (!nullToAbsent || acquiredInCellId != null) {
      map['acquired_in_cell_id'] = Variable<String>(acquiredInCellId);
    }
    if (!nullToAbsent || dailySeed != null) {
      map['daily_seed'] = Variable<String>(dailySeed);
    }
    map['status'] = Variable<String>(status);
    map['badges_json'] = Variable<String>(badgesJson);
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
    if (!nullToAbsent || iconUrl != null) {
      map['icon_url'] = Variable<String>(iconUrl);
    }
    if (!nullToAbsent || artUrl != null) {
      map['art_url'] = Variable<String>(artUrl);
    }
    if (!nullToAbsent || animalClassName != null) {
      map['animal_class_name'] = Variable<String>(animalClassName);
    }
    if (!nullToAbsent || animalClassNameEnrichver != null) {
      map['animal_class_name_enrichver'] =
          Variable<String>(animalClassNameEnrichver);
    }
    if (!nullToAbsent || foodPreferenceName != null) {
      map['food_preference_name'] = Variable<String>(foodPreferenceName);
    }
    if (!nullToAbsent || foodPreferenceNameEnrichver != null) {
      map['food_preference_name_enrichver'] =
          Variable<String>(foodPreferenceNameEnrichver);
    }
    if (!nullToAbsent || climateName != null) {
      map['climate_name'] = Variable<String>(climateName);
    }
    if (!nullToAbsent || climateNameEnrichver != null) {
      map['climate_name_enrichver'] = Variable<String>(climateNameEnrichver);
    }
    if (!nullToAbsent || brawn != null) {
      map['brawn'] = Variable<int>(brawn);
    }
    if (!nullToAbsent || brawnEnrichver != null) {
      map['brawn_enrichver'] = Variable<String>(brawnEnrichver);
    }
    if (!nullToAbsent || wit != null) {
      map['wit'] = Variable<int>(wit);
    }
    if (!nullToAbsent || witEnrichver != null) {
      map['wit_enrichver'] = Variable<String>(witEnrichver);
    }
    if (!nullToAbsent || speed != null) {
      map['speed'] = Variable<int>(speed);
    }
    if (!nullToAbsent || speedEnrichver != null) {
      map['speed_enrichver'] = Variable<String>(speedEnrichver);
    }
    if (!nullToAbsent || sizeName != null) {
      map['size_name'] = Variable<String>(sizeName);
    }
    if (!nullToAbsent || sizeNameEnrichver != null) {
      map['size_name_enrichver'] = Variable<String>(sizeNameEnrichver);
    }
    if (!nullToAbsent || iconUrlEnrichver != null) {
      map['icon_url_enrichver'] = Variable<String>(iconUrlEnrichver);
    }
    if (!nullToAbsent || artUrlEnrichver != null) {
      map['art_url_enrichver'] = Variable<String>(artUrlEnrichver);
    }
    if (!nullToAbsent || cellHabitatName != null) {
      map['cell_habitat_name'] = Variable<String>(cellHabitatName);
    }
    if (!nullToAbsent || cellHabitatNameEnrichver != null) {
      map['cell_habitat_name_enrichver'] =
          Variable<String>(cellHabitatNameEnrichver);
    }
    if (!nullToAbsent || cellClimateName != null) {
      map['cell_climate_name'] = Variable<String>(cellClimateName);
    }
    if (!nullToAbsent || cellClimateNameEnrichver != null) {
      map['cell_climate_name_enrichver'] =
          Variable<String>(cellClimateNameEnrichver);
    }
    if (!nullToAbsent || cellContinentName != null) {
      map['cell_continent_name'] = Variable<String>(cellContinentName);
    }
    if (!nullToAbsent || cellContinentNameEnrichver != null) {
      map['cell_continent_name_enrichver'] =
          Variable<String>(cellContinentNameEnrichver);
    }
    if (!nullToAbsent || locationDistrict != null) {
      map['location_district'] = Variable<String>(locationDistrict);
    }
    if (!nullToAbsent || locationDistrictEnrichver != null) {
      map['location_district_enrichver'] =
          Variable<String>(locationDistrictEnrichver);
    }
    if (!nullToAbsent || locationCity != null) {
      map['location_city'] = Variable<String>(locationCity);
    }
    if (!nullToAbsent || locationCityEnrichver != null) {
      map['location_city_enrichver'] = Variable<String>(locationCityEnrichver);
    }
    if (!nullToAbsent || locationState != null) {
      map['location_state'] = Variable<String>(locationState);
    }
    if (!nullToAbsent || locationStateEnrichver != null) {
      map['location_state_enrichver'] =
          Variable<String>(locationStateEnrichver);
    }
    if (!nullToAbsent || locationCountry != null) {
      map['location_country'] = Variable<String>(locationCountry);
    }
    if (!nullToAbsent || locationCountryEnrichver != null) {
      map['location_country_enrichver'] =
          Variable<String>(locationCountryEnrichver);
    }
    if (!nullToAbsent || locationCountryCode != null) {
      map['location_country_code'] = Variable<String>(locationCountryCode);
    }
    if (!nullToAbsent || locationCountryCodeEnrichver != null) {
      map['location_country_code_enrichver'] =
          Variable<String>(locationCountryCodeEnrichver);
    }
    return map;
  }

  LocalItemInstanceTableCompanion toCompanion(bool nullToAbsent) {
    return LocalItemInstanceTableCompanion(
      id: Value(id),
      userId: Value(userId),
      definitionId: Value(definitionId),
      affixes: Value(affixes),
      parentAId: parentAId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentAId),
      parentBId: parentBId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentBId),
      acquiredAt: Value(acquiredAt),
      acquiredInCellId: acquiredInCellId == null && nullToAbsent
          ? const Value.absent()
          : Value(acquiredInCellId),
      dailySeed: dailySeed == null && nullToAbsent
          ? const Value.absent()
          : Value(dailySeed),
      status: Value(status),
      badgesJson: Value(badgesJson),
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
      iconUrl: iconUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(iconUrl),
      artUrl:
          artUrl == null && nullToAbsent ? const Value.absent() : Value(artUrl),
      animalClassName: animalClassName == null && nullToAbsent
          ? const Value.absent()
          : Value(animalClassName),
      animalClassNameEnrichver: animalClassNameEnrichver == null && nullToAbsent
          ? const Value.absent()
          : Value(animalClassNameEnrichver),
      foodPreferenceName: foodPreferenceName == null && nullToAbsent
          ? const Value.absent()
          : Value(foodPreferenceName),
      foodPreferenceNameEnrichver:
          foodPreferenceNameEnrichver == null && nullToAbsent
              ? const Value.absent()
              : Value(foodPreferenceNameEnrichver),
      climateName: climateName == null && nullToAbsent
          ? const Value.absent()
          : Value(climateName),
      climateNameEnrichver: climateNameEnrichver == null && nullToAbsent
          ? const Value.absent()
          : Value(climateNameEnrichver),
      brawn:
          brawn == null && nullToAbsent ? const Value.absent() : Value(brawn),
      brawnEnrichver: brawnEnrichver == null && nullToAbsent
          ? const Value.absent()
          : Value(brawnEnrichver),
      wit: wit == null && nullToAbsent ? const Value.absent() : Value(wit),
      witEnrichver: witEnrichver == null && nullToAbsent
          ? const Value.absent()
          : Value(witEnrichver),
      speed:
          speed == null && nullToAbsent ? const Value.absent() : Value(speed),
      speedEnrichver: speedEnrichver == null && nullToAbsent
          ? const Value.absent()
          : Value(speedEnrichver),
      sizeName: sizeName == null && nullToAbsent
          ? const Value.absent()
          : Value(sizeName),
      sizeNameEnrichver: sizeNameEnrichver == null && nullToAbsent
          ? const Value.absent()
          : Value(sizeNameEnrichver),
      iconUrlEnrichver: iconUrlEnrichver == null && nullToAbsent
          ? const Value.absent()
          : Value(iconUrlEnrichver),
      artUrlEnrichver: artUrlEnrichver == null && nullToAbsent
          ? const Value.absent()
          : Value(artUrlEnrichver),
      cellHabitatName: cellHabitatName == null && nullToAbsent
          ? const Value.absent()
          : Value(cellHabitatName),
      cellHabitatNameEnrichver: cellHabitatNameEnrichver == null && nullToAbsent
          ? const Value.absent()
          : Value(cellHabitatNameEnrichver),
      cellClimateName: cellClimateName == null && nullToAbsent
          ? const Value.absent()
          : Value(cellClimateName),
      cellClimateNameEnrichver: cellClimateNameEnrichver == null && nullToAbsent
          ? const Value.absent()
          : Value(cellClimateNameEnrichver),
      cellContinentName: cellContinentName == null && nullToAbsent
          ? const Value.absent()
          : Value(cellContinentName),
      cellContinentNameEnrichver:
          cellContinentNameEnrichver == null && nullToAbsent
              ? const Value.absent()
              : Value(cellContinentNameEnrichver),
      locationDistrict: locationDistrict == null && nullToAbsent
          ? const Value.absent()
          : Value(locationDistrict),
      locationDistrictEnrichver:
          locationDistrictEnrichver == null && nullToAbsent
              ? const Value.absent()
              : Value(locationDistrictEnrichver),
      locationCity: locationCity == null && nullToAbsent
          ? const Value.absent()
          : Value(locationCity),
      locationCityEnrichver: locationCityEnrichver == null && nullToAbsent
          ? const Value.absent()
          : Value(locationCityEnrichver),
      locationState: locationState == null && nullToAbsent
          ? const Value.absent()
          : Value(locationState),
      locationStateEnrichver: locationStateEnrichver == null && nullToAbsent
          ? const Value.absent()
          : Value(locationStateEnrichver),
      locationCountry: locationCountry == null && nullToAbsent
          ? const Value.absent()
          : Value(locationCountry),
      locationCountryEnrichver: locationCountryEnrichver == null && nullToAbsent
          ? const Value.absent()
          : Value(locationCountryEnrichver),
      locationCountryCode: locationCountryCode == null && nullToAbsent
          ? const Value.absent()
          : Value(locationCountryCode),
      locationCountryCodeEnrichver:
          locationCountryCodeEnrichver == null && nullToAbsent
              ? const Value.absent()
              : Value(locationCountryCodeEnrichver),
    );
  }

  factory LocalItemInstance.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalItemInstance(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      definitionId: serializer.fromJson<String>(json['definitionId']),
      affixes: serializer.fromJson<String>(json['affixes']),
      parentAId: serializer.fromJson<String?>(json['parentAId']),
      parentBId: serializer.fromJson<String?>(json['parentBId']),
      acquiredAt: serializer.fromJson<DateTime>(json['acquiredAt']),
      acquiredInCellId: serializer.fromJson<String?>(json['acquiredInCellId']),
      dailySeed: serializer.fromJson<String?>(json['dailySeed']),
      status: serializer.fromJson<String>(json['status']),
      badgesJson: serializer.fromJson<String>(json['badgesJson']),
      displayName: serializer.fromJson<String>(json['displayName']),
      scientificName: serializer.fromJson<String?>(json['scientificName']),
      categoryName: serializer.fromJson<String>(json['categoryName']),
      rarityName: serializer.fromJson<String?>(json['rarityName']),
      habitatsJson: serializer.fromJson<String>(json['habitatsJson']),
      continentsJson: serializer.fromJson<String>(json['continentsJson']),
      taxonomicClass: serializer.fromJson<String?>(json['taxonomicClass']),
      iconUrl: serializer.fromJson<String?>(json['iconUrl']),
      artUrl: serializer.fromJson<String?>(json['artUrl']),
      animalClassName: serializer.fromJson<String?>(json['animalClassName']),
      animalClassNameEnrichver:
          serializer.fromJson<String?>(json['animalClassNameEnrichver']),
      foodPreferenceName:
          serializer.fromJson<String?>(json['foodPreferenceName']),
      foodPreferenceNameEnrichver:
          serializer.fromJson<String?>(json['foodPreferenceNameEnrichver']),
      climateName: serializer.fromJson<String?>(json['climateName']),
      climateNameEnrichver:
          serializer.fromJson<String?>(json['climateNameEnrichver']),
      brawn: serializer.fromJson<int?>(json['brawn']),
      brawnEnrichver: serializer.fromJson<String?>(json['brawnEnrichver']),
      wit: serializer.fromJson<int?>(json['wit']),
      witEnrichver: serializer.fromJson<String?>(json['witEnrichver']),
      speed: serializer.fromJson<int?>(json['speed']),
      speedEnrichver: serializer.fromJson<String?>(json['speedEnrichver']),
      sizeName: serializer.fromJson<String?>(json['sizeName']),
      sizeNameEnrichver:
          serializer.fromJson<String?>(json['sizeNameEnrichver']),
      iconUrlEnrichver: serializer.fromJson<String?>(json['iconUrlEnrichver']),
      artUrlEnrichver: serializer.fromJson<String?>(json['artUrlEnrichver']),
      cellHabitatName: serializer.fromJson<String?>(json['cellHabitatName']),
      cellHabitatNameEnrichver:
          serializer.fromJson<String?>(json['cellHabitatNameEnrichver']),
      cellClimateName: serializer.fromJson<String?>(json['cellClimateName']),
      cellClimateNameEnrichver:
          serializer.fromJson<String?>(json['cellClimateNameEnrichver']),
      cellContinentName:
          serializer.fromJson<String?>(json['cellContinentName']),
      cellContinentNameEnrichver:
          serializer.fromJson<String?>(json['cellContinentNameEnrichver']),
      locationDistrict: serializer.fromJson<String?>(json['locationDistrict']),
      locationDistrictEnrichver:
          serializer.fromJson<String?>(json['locationDistrictEnrichver']),
      locationCity: serializer.fromJson<String?>(json['locationCity']),
      locationCityEnrichver:
          serializer.fromJson<String?>(json['locationCityEnrichver']),
      locationState: serializer.fromJson<String?>(json['locationState']),
      locationStateEnrichver:
          serializer.fromJson<String?>(json['locationStateEnrichver']),
      locationCountry: serializer.fromJson<String?>(json['locationCountry']),
      locationCountryEnrichver:
          serializer.fromJson<String?>(json['locationCountryEnrichver']),
      locationCountryCode:
          serializer.fromJson<String?>(json['locationCountryCode']),
      locationCountryCodeEnrichver:
          serializer.fromJson<String?>(json['locationCountryCodeEnrichver']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'definitionId': serializer.toJson<String>(definitionId),
      'affixes': serializer.toJson<String>(affixes),
      'parentAId': serializer.toJson<String?>(parentAId),
      'parentBId': serializer.toJson<String?>(parentBId),
      'acquiredAt': serializer.toJson<DateTime>(acquiredAt),
      'acquiredInCellId': serializer.toJson<String?>(acquiredInCellId),
      'dailySeed': serializer.toJson<String?>(dailySeed),
      'status': serializer.toJson<String>(status),
      'badgesJson': serializer.toJson<String>(badgesJson),
      'displayName': serializer.toJson<String>(displayName),
      'scientificName': serializer.toJson<String?>(scientificName),
      'categoryName': serializer.toJson<String>(categoryName),
      'rarityName': serializer.toJson<String?>(rarityName),
      'habitatsJson': serializer.toJson<String>(habitatsJson),
      'continentsJson': serializer.toJson<String>(continentsJson),
      'taxonomicClass': serializer.toJson<String?>(taxonomicClass),
      'iconUrl': serializer.toJson<String?>(iconUrl),
      'artUrl': serializer.toJson<String?>(artUrl),
      'animalClassName': serializer.toJson<String?>(animalClassName),
      'animalClassNameEnrichver':
          serializer.toJson<String?>(animalClassNameEnrichver),
      'foodPreferenceName': serializer.toJson<String?>(foodPreferenceName),
      'foodPreferenceNameEnrichver':
          serializer.toJson<String?>(foodPreferenceNameEnrichver),
      'climateName': serializer.toJson<String?>(climateName),
      'climateNameEnrichver': serializer.toJson<String?>(climateNameEnrichver),
      'brawn': serializer.toJson<int?>(brawn),
      'brawnEnrichver': serializer.toJson<String?>(brawnEnrichver),
      'wit': serializer.toJson<int?>(wit),
      'witEnrichver': serializer.toJson<String?>(witEnrichver),
      'speed': serializer.toJson<int?>(speed),
      'speedEnrichver': serializer.toJson<String?>(speedEnrichver),
      'sizeName': serializer.toJson<String?>(sizeName),
      'sizeNameEnrichver': serializer.toJson<String?>(sizeNameEnrichver),
      'iconUrlEnrichver': serializer.toJson<String?>(iconUrlEnrichver),
      'artUrlEnrichver': serializer.toJson<String?>(artUrlEnrichver),
      'cellHabitatName': serializer.toJson<String?>(cellHabitatName),
      'cellHabitatNameEnrichver':
          serializer.toJson<String?>(cellHabitatNameEnrichver),
      'cellClimateName': serializer.toJson<String?>(cellClimateName),
      'cellClimateNameEnrichver':
          serializer.toJson<String?>(cellClimateNameEnrichver),
      'cellContinentName': serializer.toJson<String?>(cellContinentName),
      'cellContinentNameEnrichver':
          serializer.toJson<String?>(cellContinentNameEnrichver),
      'locationDistrict': serializer.toJson<String?>(locationDistrict),
      'locationDistrictEnrichver':
          serializer.toJson<String?>(locationDistrictEnrichver),
      'locationCity': serializer.toJson<String?>(locationCity),
      'locationCityEnrichver':
          serializer.toJson<String?>(locationCityEnrichver),
      'locationState': serializer.toJson<String?>(locationState),
      'locationStateEnrichver':
          serializer.toJson<String?>(locationStateEnrichver),
      'locationCountry': serializer.toJson<String?>(locationCountry),
      'locationCountryEnrichver':
          serializer.toJson<String?>(locationCountryEnrichver),
      'locationCountryCode': serializer.toJson<String?>(locationCountryCode),
      'locationCountryCodeEnrichver':
          serializer.toJson<String?>(locationCountryCodeEnrichver),
    };
  }

  LocalItemInstance copyWith(
          {String? id,
          String? userId,
          String? definitionId,
          String? affixes,
          Value<String?> parentAId = const Value.absent(),
          Value<String?> parentBId = const Value.absent(),
          DateTime? acquiredAt,
          Value<String?> acquiredInCellId = const Value.absent(),
          Value<String?> dailySeed = const Value.absent(),
          String? status,
          String? badgesJson,
          String? displayName,
          Value<String?> scientificName = const Value.absent(),
          String? categoryName,
          Value<String?> rarityName = const Value.absent(),
          String? habitatsJson,
          String? continentsJson,
          Value<String?> taxonomicClass = const Value.absent(),
          Value<String?> iconUrl = const Value.absent(),
          Value<String?> artUrl = const Value.absent(),
          Value<String?> animalClassName = const Value.absent(),
          Value<String?> animalClassNameEnrichver = const Value.absent(),
          Value<String?> foodPreferenceName = const Value.absent(),
          Value<String?> foodPreferenceNameEnrichver = const Value.absent(),
          Value<String?> climateName = const Value.absent(),
          Value<String?> climateNameEnrichver = const Value.absent(),
          Value<int?> brawn = const Value.absent(),
          Value<String?> brawnEnrichver = const Value.absent(),
          Value<int?> wit = const Value.absent(),
          Value<String?> witEnrichver = const Value.absent(),
          Value<int?> speed = const Value.absent(),
          Value<String?> speedEnrichver = const Value.absent(),
          Value<String?> sizeName = const Value.absent(),
          Value<String?> sizeNameEnrichver = const Value.absent(),
          Value<String?> iconUrlEnrichver = const Value.absent(),
          Value<String?> artUrlEnrichver = const Value.absent(),
          Value<String?> cellHabitatName = const Value.absent(),
          Value<String?> cellHabitatNameEnrichver = const Value.absent(),
          Value<String?> cellClimateName = const Value.absent(),
          Value<String?> cellClimateNameEnrichver = const Value.absent(),
          Value<String?> cellContinentName = const Value.absent(),
          Value<String?> cellContinentNameEnrichver = const Value.absent(),
          Value<String?> locationDistrict = const Value.absent(),
          Value<String?> locationDistrictEnrichver = const Value.absent(),
          Value<String?> locationCity = const Value.absent(),
          Value<String?> locationCityEnrichver = const Value.absent(),
          Value<String?> locationState = const Value.absent(),
          Value<String?> locationStateEnrichver = const Value.absent(),
          Value<String?> locationCountry = const Value.absent(),
          Value<String?> locationCountryEnrichver = const Value.absent(),
          Value<String?> locationCountryCode = const Value.absent(),
          Value<String?> locationCountryCodeEnrichver =
              const Value.absent()}) =>
      LocalItemInstance(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        definitionId: definitionId ?? this.definitionId,
        affixes: affixes ?? this.affixes,
        parentAId: parentAId.present ? parentAId.value : this.parentAId,
        parentBId: parentBId.present ? parentBId.value : this.parentBId,
        acquiredAt: acquiredAt ?? this.acquiredAt,
        acquiredInCellId: acquiredInCellId.present
            ? acquiredInCellId.value
            : this.acquiredInCellId,
        dailySeed: dailySeed.present ? dailySeed.value : this.dailySeed,
        status: status ?? this.status,
        badgesJson: badgesJson ?? this.badgesJson,
        displayName: displayName ?? this.displayName,
        scientificName:
            scientificName.present ? scientificName.value : this.scientificName,
        categoryName: categoryName ?? this.categoryName,
        rarityName: rarityName.present ? rarityName.value : this.rarityName,
        habitatsJson: habitatsJson ?? this.habitatsJson,
        continentsJson: continentsJson ?? this.continentsJson,
        taxonomicClass:
            taxonomicClass.present ? taxonomicClass.value : this.taxonomicClass,
        iconUrl: iconUrl.present ? iconUrl.value : this.iconUrl,
        artUrl: artUrl.present ? artUrl.value : this.artUrl,
        animalClassName: animalClassName.present
            ? animalClassName.value
            : this.animalClassName,
        animalClassNameEnrichver: animalClassNameEnrichver.present
            ? animalClassNameEnrichver.value
            : this.animalClassNameEnrichver,
        foodPreferenceName: foodPreferenceName.present
            ? foodPreferenceName.value
            : this.foodPreferenceName,
        foodPreferenceNameEnrichver: foodPreferenceNameEnrichver.present
            ? foodPreferenceNameEnrichver.value
            : this.foodPreferenceNameEnrichver,
        climateName: climateName.present ? climateName.value : this.climateName,
        climateNameEnrichver: climateNameEnrichver.present
            ? climateNameEnrichver.value
            : this.climateNameEnrichver,
        brawn: brawn.present ? brawn.value : this.brawn,
        brawnEnrichver:
            brawnEnrichver.present ? brawnEnrichver.value : this.brawnEnrichver,
        wit: wit.present ? wit.value : this.wit,
        witEnrichver:
            witEnrichver.present ? witEnrichver.value : this.witEnrichver,
        speed: speed.present ? speed.value : this.speed,
        speedEnrichver:
            speedEnrichver.present ? speedEnrichver.value : this.speedEnrichver,
        sizeName: sizeName.present ? sizeName.value : this.sizeName,
        sizeNameEnrichver: sizeNameEnrichver.present
            ? sizeNameEnrichver.value
            : this.sizeNameEnrichver,
        iconUrlEnrichver: iconUrlEnrichver.present
            ? iconUrlEnrichver.value
            : this.iconUrlEnrichver,
        artUrlEnrichver: artUrlEnrichver.present
            ? artUrlEnrichver.value
            : this.artUrlEnrichver,
        cellHabitatName: cellHabitatName.present
            ? cellHabitatName.value
            : this.cellHabitatName,
        cellHabitatNameEnrichver: cellHabitatNameEnrichver.present
            ? cellHabitatNameEnrichver.value
            : this.cellHabitatNameEnrichver,
        cellClimateName: cellClimateName.present
            ? cellClimateName.value
            : this.cellClimateName,
        cellClimateNameEnrichver: cellClimateNameEnrichver.present
            ? cellClimateNameEnrichver.value
            : this.cellClimateNameEnrichver,
        cellContinentName: cellContinentName.present
            ? cellContinentName.value
            : this.cellContinentName,
        cellContinentNameEnrichver: cellContinentNameEnrichver.present
            ? cellContinentNameEnrichver.value
            : this.cellContinentNameEnrichver,
        locationDistrict: locationDistrict.present
            ? locationDistrict.value
            : this.locationDistrict,
        locationDistrictEnrichver: locationDistrictEnrichver.present
            ? locationDistrictEnrichver.value
            : this.locationDistrictEnrichver,
        locationCity:
            locationCity.present ? locationCity.value : this.locationCity,
        locationCityEnrichver: locationCityEnrichver.present
            ? locationCityEnrichver.value
            : this.locationCityEnrichver,
        locationState:
            locationState.present ? locationState.value : this.locationState,
        locationStateEnrichver: locationStateEnrichver.present
            ? locationStateEnrichver.value
            : this.locationStateEnrichver,
        locationCountry: locationCountry.present
            ? locationCountry.value
            : this.locationCountry,
        locationCountryEnrichver: locationCountryEnrichver.present
            ? locationCountryEnrichver.value
            : this.locationCountryEnrichver,
        locationCountryCode: locationCountryCode.present
            ? locationCountryCode.value
            : this.locationCountryCode,
        locationCountryCodeEnrichver: locationCountryCodeEnrichver.present
            ? locationCountryCodeEnrichver.value
            : this.locationCountryCodeEnrichver,
      );
  LocalItemInstance copyWithCompanion(LocalItemInstanceTableCompanion data) {
    return LocalItemInstance(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      definitionId: data.definitionId.present
          ? data.definitionId.value
          : this.definitionId,
      affixes: data.affixes.present ? data.affixes.value : this.affixes,
      parentAId: data.parentAId.present ? data.parentAId.value : this.parentAId,
      parentBId: data.parentBId.present ? data.parentBId.value : this.parentBId,
      acquiredAt:
          data.acquiredAt.present ? data.acquiredAt.value : this.acquiredAt,
      acquiredInCellId: data.acquiredInCellId.present
          ? data.acquiredInCellId.value
          : this.acquiredInCellId,
      dailySeed: data.dailySeed.present ? data.dailySeed.value : this.dailySeed,
      status: data.status.present ? data.status.value : this.status,
      badgesJson:
          data.badgesJson.present ? data.badgesJson.value : this.badgesJson,
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
      iconUrl: data.iconUrl.present ? data.iconUrl.value : this.iconUrl,
      artUrl: data.artUrl.present ? data.artUrl.value : this.artUrl,
      animalClassName: data.animalClassName.present
          ? data.animalClassName.value
          : this.animalClassName,
      animalClassNameEnrichver: data.animalClassNameEnrichver.present
          ? data.animalClassNameEnrichver.value
          : this.animalClassNameEnrichver,
      foodPreferenceName: data.foodPreferenceName.present
          ? data.foodPreferenceName.value
          : this.foodPreferenceName,
      foodPreferenceNameEnrichver: data.foodPreferenceNameEnrichver.present
          ? data.foodPreferenceNameEnrichver.value
          : this.foodPreferenceNameEnrichver,
      climateName:
          data.climateName.present ? data.climateName.value : this.climateName,
      climateNameEnrichver: data.climateNameEnrichver.present
          ? data.climateNameEnrichver.value
          : this.climateNameEnrichver,
      brawn: data.brawn.present ? data.brawn.value : this.brawn,
      brawnEnrichver: data.brawnEnrichver.present
          ? data.brawnEnrichver.value
          : this.brawnEnrichver,
      wit: data.wit.present ? data.wit.value : this.wit,
      witEnrichver: data.witEnrichver.present
          ? data.witEnrichver.value
          : this.witEnrichver,
      speed: data.speed.present ? data.speed.value : this.speed,
      speedEnrichver: data.speedEnrichver.present
          ? data.speedEnrichver.value
          : this.speedEnrichver,
      sizeName: data.sizeName.present ? data.sizeName.value : this.sizeName,
      sizeNameEnrichver: data.sizeNameEnrichver.present
          ? data.sizeNameEnrichver.value
          : this.sizeNameEnrichver,
      iconUrlEnrichver: data.iconUrlEnrichver.present
          ? data.iconUrlEnrichver.value
          : this.iconUrlEnrichver,
      artUrlEnrichver: data.artUrlEnrichver.present
          ? data.artUrlEnrichver.value
          : this.artUrlEnrichver,
      cellHabitatName: data.cellHabitatName.present
          ? data.cellHabitatName.value
          : this.cellHabitatName,
      cellHabitatNameEnrichver: data.cellHabitatNameEnrichver.present
          ? data.cellHabitatNameEnrichver.value
          : this.cellHabitatNameEnrichver,
      cellClimateName: data.cellClimateName.present
          ? data.cellClimateName.value
          : this.cellClimateName,
      cellClimateNameEnrichver: data.cellClimateNameEnrichver.present
          ? data.cellClimateNameEnrichver.value
          : this.cellClimateNameEnrichver,
      cellContinentName: data.cellContinentName.present
          ? data.cellContinentName.value
          : this.cellContinentName,
      cellContinentNameEnrichver: data.cellContinentNameEnrichver.present
          ? data.cellContinentNameEnrichver.value
          : this.cellContinentNameEnrichver,
      locationDistrict: data.locationDistrict.present
          ? data.locationDistrict.value
          : this.locationDistrict,
      locationDistrictEnrichver: data.locationDistrictEnrichver.present
          ? data.locationDistrictEnrichver.value
          : this.locationDistrictEnrichver,
      locationCity: data.locationCity.present
          ? data.locationCity.value
          : this.locationCity,
      locationCityEnrichver: data.locationCityEnrichver.present
          ? data.locationCityEnrichver.value
          : this.locationCityEnrichver,
      locationState: data.locationState.present
          ? data.locationState.value
          : this.locationState,
      locationStateEnrichver: data.locationStateEnrichver.present
          ? data.locationStateEnrichver.value
          : this.locationStateEnrichver,
      locationCountry: data.locationCountry.present
          ? data.locationCountry.value
          : this.locationCountry,
      locationCountryEnrichver: data.locationCountryEnrichver.present
          ? data.locationCountryEnrichver.value
          : this.locationCountryEnrichver,
      locationCountryCode: data.locationCountryCode.present
          ? data.locationCountryCode.value
          : this.locationCountryCode,
      locationCountryCodeEnrichver: data.locationCountryCodeEnrichver.present
          ? data.locationCountryCodeEnrichver.value
          : this.locationCountryCodeEnrichver,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalItemInstance(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('definitionId: $definitionId, ')
          ..write('affixes: $affixes, ')
          ..write('parentAId: $parentAId, ')
          ..write('parentBId: $parentBId, ')
          ..write('acquiredAt: $acquiredAt, ')
          ..write('acquiredInCellId: $acquiredInCellId, ')
          ..write('dailySeed: $dailySeed, ')
          ..write('status: $status, ')
          ..write('badgesJson: $badgesJson, ')
          ..write('displayName: $displayName, ')
          ..write('scientificName: $scientificName, ')
          ..write('categoryName: $categoryName, ')
          ..write('rarityName: $rarityName, ')
          ..write('habitatsJson: $habitatsJson, ')
          ..write('continentsJson: $continentsJson, ')
          ..write('taxonomicClass: $taxonomicClass, ')
          ..write('iconUrl: $iconUrl, ')
          ..write('artUrl: $artUrl, ')
          ..write('animalClassName: $animalClassName, ')
          ..write('animalClassNameEnrichver: $animalClassNameEnrichver, ')
          ..write('foodPreferenceName: $foodPreferenceName, ')
          ..write('foodPreferenceNameEnrichver: $foodPreferenceNameEnrichver, ')
          ..write('climateName: $climateName, ')
          ..write('climateNameEnrichver: $climateNameEnrichver, ')
          ..write('brawn: $brawn, ')
          ..write('brawnEnrichver: $brawnEnrichver, ')
          ..write('wit: $wit, ')
          ..write('witEnrichver: $witEnrichver, ')
          ..write('speed: $speed, ')
          ..write('speedEnrichver: $speedEnrichver, ')
          ..write('sizeName: $sizeName, ')
          ..write('sizeNameEnrichver: $sizeNameEnrichver, ')
          ..write('iconUrlEnrichver: $iconUrlEnrichver, ')
          ..write('artUrlEnrichver: $artUrlEnrichver, ')
          ..write('cellHabitatName: $cellHabitatName, ')
          ..write('cellHabitatNameEnrichver: $cellHabitatNameEnrichver, ')
          ..write('cellClimateName: $cellClimateName, ')
          ..write('cellClimateNameEnrichver: $cellClimateNameEnrichver, ')
          ..write('cellContinentName: $cellContinentName, ')
          ..write('cellContinentNameEnrichver: $cellContinentNameEnrichver, ')
          ..write('locationDistrict: $locationDistrict, ')
          ..write('locationDistrictEnrichver: $locationDistrictEnrichver, ')
          ..write('locationCity: $locationCity, ')
          ..write('locationCityEnrichver: $locationCityEnrichver, ')
          ..write('locationState: $locationState, ')
          ..write('locationStateEnrichver: $locationStateEnrichver, ')
          ..write('locationCountry: $locationCountry, ')
          ..write('locationCountryEnrichver: $locationCountryEnrichver, ')
          ..write('locationCountryCode: $locationCountryCode, ')
          ..write('locationCountryCodeEnrichver: $locationCountryCodeEnrichver')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
        id,
        userId,
        definitionId,
        affixes,
        parentAId,
        parentBId,
        acquiredAt,
        acquiredInCellId,
        dailySeed,
        status,
        badgesJson,
        displayName,
        scientificName,
        categoryName,
        rarityName,
        habitatsJson,
        continentsJson,
        taxonomicClass,
        iconUrl,
        artUrl,
        animalClassName,
        animalClassNameEnrichver,
        foodPreferenceName,
        foodPreferenceNameEnrichver,
        climateName,
        climateNameEnrichver,
        brawn,
        brawnEnrichver,
        wit,
        witEnrichver,
        speed,
        speedEnrichver,
        sizeName,
        sizeNameEnrichver,
        iconUrlEnrichver,
        artUrlEnrichver,
        cellHabitatName,
        cellHabitatNameEnrichver,
        cellClimateName,
        cellClimateNameEnrichver,
        cellContinentName,
        cellContinentNameEnrichver,
        locationDistrict,
        locationDistrictEnrichver,
        locationCity,
        locationCityEnrichver,
        locationState,
        locationStateEnrichver,
        locationCountry,
        locationCountryEnrichver,
        locationCountryCode,
        locationCountryCodeEnrichver
      ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalItemInstance &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.definitionId == this.definitionId &&
          other.affixes == this.affixes &&
          other.parentAId == this.parentAId &&
          other.parentBId == this.parentBId &&
          other.acquiredAt == this.acquiredAt &&
          other.acquiredInCellId == this.acquiredInCellId &&
          other.dailySeed == this.dailySeed &&
          other.status == this.status &&
          other.badgesJson == this.badgesJson &&
          other.displayName == this.displayName &&
          other.scientificName == this.scientificName &&
          other.categoryName == this.categoryName &&
          other.rarityName == this.rarityName &&
          other.habitatsJson == this.habitatsJson &&
          other.continentsJson == this.continentsJson &&
          other.taxonomicClass == this.taxonomicClass &&
          other.iconUrl == this.iconUrl &&
          other.artUrl == this.artUrl &&
          other.animalClassName == this.animalClassName &&
          other.animalClassNameEnrichver == this.animalClassNameEnrichver &&
          other.foodPreferenceName == this.foodPreferenceName &&
          other.foodPreferenceNameEnrichver ==
              this.foodPreferenceNameEnrichver &&
          other.climateName == this.climateName &&
          other.climateNameEnrichver == this.climateNameEnrichver &&
          other.brawn == this.brawn &&
          other.brawnEnrichver == this.brawnEnrichver &&
          other.wit == this.wit &&
          other.witEnrichver == this.witEnrichver &&
          other.speed == this.speed &&
          other.speedEnrichver == this.speedEnrichver &&
          other.sizeName == this.sizeName &&
          other.sizeNameEnrichver == this.sizeNameEnrichver &&
          other.iconUrlEnrichver == this.iconUrlEnrichver &&
          other.artUrlEnrichver == this.artUrlEnrichver &&
          other.cellHabitatName == this.cellHabitatName &&
          other.cellHabitatNameEnrichver == this.cellHabitatNameEnrichver &&
          other.cellClimateName == this.cellClimateName &&
          other.cellClimateNameEnrichver == this.cellClimateNameEnrichver &&
          other.cellContinentName == this.cellContinentName &&
          other.cellContinentNameEnrichver == this.cellContinentNameEnrichver &&
          other.locationDistrict == this.locationDistrict &&
          other.locationDistrictEnrichver == this.locationDistrictEnrichver &&
          other.locationCity == this.locationCity &&
          other.locationCityEnrichver == this.locationCityEnrichver &&
          other.locationState == this.locationState &&
          other.locationStateEnrichver == this.locationStateEnrichver &&
          other.locationCountry == this.locationCountry &&
          other.locationCountryEnrichver == this.locationCountryEnrichver &&
          other.locationCountryCode == this.locationCountryCode &&
          other.locationCountryCodeEnrichver ==
              this.locationCountryCodeEnrichver);
}

class LocalItemInstanceTableCompanion
    extends UpdateCompanion<LocalItemInstance> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> definitionId;
  final Value<String> affixes;
  final Value<String?> parentAId;
  final Value<String?> parentBId;
  final Value<DateTime> acquiredAt;
  final Value<String?> acquiredInCellId;
  final Value<String?> dailySeed;
  final Value<String> status;
  final Value<String> badgesJson;
  final Value<String> displayName;
  final Value<String?> scientificName;
  final Value<String> categoryName;
  final Value<String?> rarityName;
  final Value<String> habitatsJson;
  final Value<String> continentsJson;
  final Value<String?> taxonomicClass;
  final Value<String?> iconUrl;
  final Value<String?> artUrl;
  final Value<String?> animalClassName;
  final Value<String?> animalClassNameEnrichver;
  final Value<String?> foodPreferenceName;
  final Value<String?> foodPreferenceNameEnrichver;
  final Value<String?> climateName;
  final Value<String?> climateNameEnrichver;
  final Value<int?> brawn;
  final Value<String?> brawnEnrichver;
  final Value<int?> wit;
  final Value<String?> witEnrichver;
  final Value<int?> speed;
  final Value<String?> speedEnrichver;
  final Value<String?> sizeName;
  final Value<String?> sizeNameEnrichver;
  final Value<String?> iconUrlEnrichver;
  final Value<String?> artUrlEnrichver;
  final Value<String?> cellHabitatName;
  final Value<String?> cellHabitatNameEnrichver;
  final Value<String?> cellClimateName;
  final Value<String?> cellClimateNameEnrichver;
  final Value<String?> cellContinentName;
  final Value<String?> cellContinentNameEnrichver;
  final Value<String?> locationDistrict;
  final Value<String?> locationDistrictEnrichver;
  final Value<String?> locationCity;
  final Value<String?> locationCityEnrichver;
  final Value<String?> locationState;
  final Value<String?> locationStateEnrichver;
  final Value<String?> locationCountry;
  final Value<String?> locationCountryEnrichver;
  final Value<String?> locationCountryCode;
  final Value<String?> locationCountryCodeEnrichver;
  final Value<int> rowid;
  const LocalItemInstanceTableCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.definitionId = const Value.absent(),
    this.affixes = const Value.absent(),
    this.parentAId = const Value.absent(),
    this.parentBId = const Value.absent(),
    this.acquiredAt = const Value.absent(),
    this.acquiredInCellId = const Value.absent(),
    this.dailySeed = const Value.absent(),
    this.status = const Value.absent(),
    this.badgesJson = const Value.absent(),
    this.displayName = const Value.absent(),
    this.scientificName = const Value.absent(),
    this.categoryName = const Value.absent(),
    this.rarityName = const Value.absent(),
    this.habitatsJson = const Value.absent(),
    this.continentsJson = const Value.absent(),
    this.taxonomicClass = const Value.absent(),
    this.iconUrl = const Value.absent(),
    this.artUrl = const Value.absent(),
    this.animalClassName = const Value.absent(),
    this.animalClassNameEnrichver = const Value.absent(),
    this.foodPreferenceName = const Value.absent(),
    this.foodPreferenceNameEnrichver = const Value.absent(),
    this.climateName = const Value.absent(),
    this.climateNameEnrichver = const Value.absent(),
    this.brawn = const Value.absent(),
    this.brawnEnrichver = const Value.absent(),
    this.wit = const Value.absent(),
    this.witEnrichver = const Value.absent(),
    this.speed = const Value.absent(),
    this.speedEnrichver = const Value.absent(),
    this.sizeName = const Value.absent(),
    this.sizeNameEnrichver = const Value.absent(),
    this.iconUrlEnrichver = const Value.absent(),
    this.artUrlEnrichver = const Value.absent(),
    this.cellHabitatName = const Value.absent(),
    this.cellHabitatNameEnrichver = const Value.absent(),
    this.cellClimateName = const Value.absent(),
    this.cellClimateNameEnrichver = const Value.absent(),
    this.cellContinentName = const Value.absent(),
    this.cellContinentNameEnrichver = const Value.absent(),
    this.locationDistrict = const Value.absent(),
    this.locationDistrictEnrichver = const Value.absent(),
    this.locationCity = const Value.absent(),
    this.locationCityEnrichver = const Value.absent(),
    this.locationState = const Value.absent(),
    this.locationStateEnrichver = const Value.absent(),
    this.locationCountry = const Value.absent(),
    this.locationCountryEnrichver = const Value.absent(),
    this.locationCountryCode = const Value.absent(),
    this.locationCountryCodeEnrichver = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalItemInstanceTableCompanion.insert({
    required String id,
    required String userId,
    required String definitionId,
    this.affixes = const Value.absent(),
    this.parentAId = const Value.absent(),
    this.parentBId = const Value.absent(),
    required DateTime acquiredAt,
    this.acquiredInCellId = const Value.absent(),
    this.dailySeed = const Value.absent(),
    this.status = const Value.absent(),
    this.badgesJson = const Value.absent(),
    this.displayName = const Value.absent(),
    this.scientificName = const Value.absent(),
    this.categoryName = const Value.absent(),
    this.rarityName = const Value.absent(),
    this.habitatsJson = const Value.absent(),
    this.continentsJson = const Value.absent(),
    this.taxonomicClass = const Value.absent(),
    this.iconUrl = const Value.absent(),
    this.artUrl = const Value.absent(),
    this.animalClassName = const Value.absent(),
    this.animalClassNameEnrichver = const Value.absent(),
    this.foodPreferenceName = const Value.absent(),
    this.foodPreferenceNameEnrichver = const Value.absent(),
    this.climateName = const Value.absent(),
    this.climateNameEnrichver = const Value.absent(),
    this.brawn = const Value.absent(),
    this.brawnEnrichver = const Value.absent(),
    this.wit = const Value.absent(),
    this.witEnrichver = const Value.absent(),
    this.speed = const Value.absent(),
    this.speedEnrichver = const Value.absent(),
    this.sizeName = const Value.absent(),
    this.sizeNameEnrichver = const Value.absent(),
    this.iconUrlEnrichver = const Value.absent(),
    this.artUrlEnrichver = const Value.absent(),
    this.cellHabitatName = const Value.absent(),
    this.cellHabitatNameEnrichver = const Value.absent(),
    this.cellClimateName = const Value.absent(),
    this.cellClimateNameEnrichver = const Value.absent(),
    this.cellContinentName = const Value.absent(),
    this.cellContinentNameEnrichver = const Value.absent(),
    this.locationDistrict = const Value.absent(),
    this.locationDistrictEnrichver = const Value.absent(),
    this.locationCity = const Value.absent(),
    this.locationCityEnrichver = const Value.absent(),
    this.locationState = const Value.absent(),
    this.locationStateEnrichver = const Value.absent(),
    this.locationCountry = const Value.absent(),
    this.locationCountryEnrichver = const Value.absent(),
    this.locationCountryCode = const Value.absent(),
    this.locationCountryCodeEnrichver = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        userId = Value(userId),
        definitionId = Value(definitionId),
        acquiredAt = Value(acquiredAt);
  static Insertable<LocalItemInstance> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? definitionId,
    Expression<String>? affixes,
    Expression<String>? parentAId,
    Expression<String>? parentBId,
    Expression<DateTime>? acquiredAt,
    Expression<String>? acquiredInCellId,
    Expression<String>? dailySeed,
    Expression<String>? status,
    Expression<String>? badgesJson,
    Expression<String>? displayName,
    Expression<String>? scientificName,
    Expression<String>? categoryName,
    Expression<String>? rarityName,
    Expression<String>? habitatsJson,
    Expression<String>? continentsJson,
    Expression<String>? taxonomicClass,
    Expression<String>? iconUrl,
    Expression<String>? artUrl,
    Expression<String>? animalClassName,
    Expression<String>? animalClassNameEnrichver,
    Expression<String>? foodPreferenceName,
    Expression<String>? foodPreferenceNameEnrichver,
    Expression<String>? climateName,
    Expression<String>? climateNameEnrichver,
    Expression<int>? brawn,
    Expression<String>? brawnEnrichver,
    Expression<int>? wit,
    Expression<String>? witEnrichver,
    Expression<int>? speed,
    Expression<String>? speedEnrichver,
    Expression<String>? sizeName,
    Expression<String>? sizeNameEnrichver,
    Expression<String>? iconUrlEnrichver,
    Expression<String>? artUrlEnrichver,
    Expression<String>? cellHabitatName,
    Expression<String>? cellHabitatNameEnrichver,
    Expression<String>? cellClimateName,
    Expression<String>? cellClimateNameEnrichver,
    Expression<String>? cellContinentName,
    Expression<String>? cellContinentNameEnrichver,
    Expression<String>? locationDistrict,
    Expression<String>? locationDistrictEnrichver,
    Expression<String>? locationCity,
    Expression<String>? locationCityEnrichver,
    Expression<String>? locationState,
    Expression<String>? locationStateEnrichver,
    Expression<String>? locationCountry,
    Expression<String>? locationCountryEnrichver,
    Expression<String>? locationCountryCode,
    Expression<String>? locationCountryCodeEnrichver,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (definitionId != null) 'definition_id': definitionId,
      if (affixes != null) 'affixes': affixes,
      if (parentAId != null) 'parent_a_id': parentAId,
      if (parentBId != null) 'parent_b_id': parentBId,
      if (acquiredAt != null) 'acquired_at': acquiredAt,
      if (acquiredInCellId != null) 'acquired_in_cell_id': acquiredInCellId,
      if (dailySeed != null) 'daily_seed': dailySeed,
      if (status != null) 'status': status,
      if (badgesJson != null) 'badges_json': badgesJson,
      if (displayName != null) 'display_name': displayName,
      if (scientificName != null) 'scientific_name': scientificName,
      if (categoryName != null) 'category_name': categoryName,
      if (rarityName != null) 'rarity_name': rarityName,
      if (habitatsJson != null) 'habitats_json': habitatsJson,
      if (continentsJson != null) 'continents_json': continentsJson,
      if (taxonomicClass != null) 'taxonomic_class': taxonomicClass,
      if (iconUrl != null) 'icon_url': iconUrl,
      if (artUrl != null) 'art_url': artUrl,
      if (animalClassName != null) 'animal_class_name': animalClassName,
      if (animalClassNameEnrichver != null)
        'animal_class_name_enrichver': animalClassNameEnrichver,
      if (foodPreferenceName != null)
        'food_preference_name': foodPreferenceName,
      if (foodPreferenceNameEnrichver != null)
        'food_preference_name_enrichver': foodPreferenceNameEnrichver,
      if (climateName != null) 'climate_name': climateName,
      if (climateNameEnrichver != null)
        'climate_name_enrichver': climateNameEnrichver,
      if (brawn != null) 'brawn': brawn,
      if (brawnEnrichver != null) 'brawn_enrichver': brawnEnrichver,
      if (wit != null) 'wit': wit,
      if (witEnrichver != null) 'wit_enrichver': witEnrichver,
      if (speed != null) 'speed': speed,
      if (speedEnrichver != null) 'speed_enrichver': speedEnrichver,
      if (sizeName != null) 'size_name': sizeName,
      if (sizeNameEnrichver != null) 'size_name_enrichver': sizeNameEnrichver,
      if (iconUrlEnrichver != null) 'icon_url_enrichver': iconUrlEnrichver,
      if (artUrlEnrichver != null) 'art_url_enrichver': artUrlEnrichver,
      if (cellHabitatName != null) 'cell_habitat_name': cellHabitatName,
      if (cellHabitatNameEnrichver != null)
        'cell_habitat_name_enrichver': cellHabitatNameEnrichver,
      if (cellClimateName != null) 'cell_climate_name': cellClimateName,
      if (cellClimateNameEnrichver != null)
        'cell_climate_name_enrichver': cellClimateNameEnrichver,
      if (cellContinentName != null) 'cell_continent_name': cellContinentName,
      if (cellContinentNameEnrichver != null)
        'cell_continent_name_enrichver': cellContinentNameEnrichver,
      if (locationDistrict != null) 'location_district': locationDistrict,
      if (locationDistrictEnrichver != null)
        'location_district_enrichver': locationDistrictEnrichver,
      if (locationCity != null) 'location_city': locationCity,
      if (locationCityEnrichver != null)
        'location_city_enrichver': locationCityEnrichver,
      if (locationState != null) 'location_state': locationState,
      if (locationStateEnrichver != null)
        'location_state_enrichver': locationStateEnrichver,
      if (locationCountry != null) 'location_country': locationCountry,
      if (locationCountryEnrichver != null)
        'location_country_enrichver': locationCountryEnrichver,
      if (locationCountryCode != null)
        'location_country_code': locationCountryCode,
      if (locationCountryCodeEnrichver != null)
        'location_country_code_enrichver': locationCountryCodeEnrichver,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalItemInstanceTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? userId,
      Value<String>? definitionId,
      Value<String>? affixes,
      Value<String?>? parentAId,
      Value<String?>? parentBId,
      Value<DateTime>? acquiredAt,
      Value<String?>? acquiredInCellId,
      Value<String?>? dailySeed,
      Value<String>? status,
      Value<String>? badgesJson,
      Value<String>? displayName,
      Value<String?>? scientificName,
      Value<String>? categoryName,
      Value<String?>? rarityName,
      Value<String>? habitatsJson,
      Value<String>? continentsJson,
      Value<String?>? taxonomicClass,
      Value<String?>? iconUrl,
      Value<String?>? artUrl,
      Value<String?>? animalClassName,
      Value<String?>? animalClassNameEnrichver,
      Value<String?>? foodPreferenceName,
      Value<String?>? foodPreferenceNameEnrichver,
      Value<String?>? climateName,
      Value<String?>? climateNameEnrichver,
      Value<int?>? brawn,
      Value<String?>? brawnEnrichver,
      Value<int?>? wit,
      Value<String?>? witEnrichver,
      Value<int?>? speed,
      Value<String?>? speedEnrichver,
      Value<String?>? sizeName,
      Value<String?>? sizeNameEnrichver,
      Value<String?>? iconUrlEnrichver,
      Value<String?>? artUrlEnrichver,
      Value<String?>? cellHabitatName,
      Value<String?>? cellHabitatNameEnrichver,
      Value<String?>? cellClimateName,
      Value<String?>? cellClimateNameEnrichver,
      Value<String?>? cellContinentName,
      Value<String?>? cellContinentNameEnrichver,
      Value<String?>? locationDistrict,
      Value<String?>? locationDistrictEnrichver,
      Value<String?>? locationCity,
      Value<String?>? locationCityEnrichver,
      Value<String?>? locationState,
      Value<String?>? locationStateEnrichver,
      Value<String?>? locationCountry,
      Value<String?>? locationCountryEnrichver,
      Value<String?>? locationCountryCode,
      Value<String?>? locationCountryCodeEnrichver,
      Value<int>? rowid}) {
    return LocalItemInstanceTableCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      definitionId: definitionId ?? this.definitionId,
      affixes: affixes ?? this.affixes,
      parentAId: parentAId ?? this.parentAId,
      parentBId: parentBId ?? this.parentBId,
      acquiredAt: acquiredAt ?? this.acquiredAt,
      acquiredInCellId: acquiredInCellId ?? this.acquiredInCellId,
      dailySeed: dailySeed ?? this.dailySeed,
      status: status ?? this.status,
      badgesJson: badgesJson ?? this.badgesJson,
      displayName: displayName ?? this.displayName,
      scientificName: scientificName ?? this.scientificName,
      categoryName: categoryName ?? this.categoryName,
      rarityName: rarityName ?? this.rarityName,
      habitatsJson: habitatsJson ?? this.habitatsJson,
      continentsJson: continentsJson ?? this.continentsJson,
      taxonomicClass: taxonomicClass ?? this.taxonomicClass,
      iconUrl: iconUrl ?? this.iconUrl,
      artUrl: artUrl ?? this.artUrl,
      animalClassName: animalClassName ?? this.animalClassName,
      animalClassNameEnrichver:
          animalClassNameEnrichver ?? this.animalClassNameEnrichver,
      foodPreferenceName: foodPreferenceName ?? this.foodPreferenceName,
      foodPreferenceNameEnrichver:
          foodPreferenceNameEnrichver ?? this.foodPreferenceNameEnrichver,
      climateName: climateName ?? this.climateName,
      climateNameEnrichver: climateNameEnrichver ?? this.climateNameEnrichver,
      brawn: brawn ?? this.brawn,
      brawnEnrichver: brawnEnrichver ?? this.brawnEnrichver,
      wit: wit ?? this.wit,
      witEnrichver: witEnrichver ?? this.witEnrichver,
      speed: speed ?? this.speed,
      speedEnrichver: speedEnrichver ?? this.speedEnrichver,
      sizeName: sizeName ?? this.sizeName,
      sizeNameEnrichver: sizeNameEnrichver ?? this.sizeNameEnrichver,
      iconUrlEnrichver: iconUrlEnrichver ?? this.iconUrlEnrichver,
      artUrlEnrichver: artUrlEnrichver ?? this.artUrlEnrichver,
      cellHabitatName: cellHabitatName ?? this.cellHabitatName,
      cellHabitatNameEnrichver:
          cellHabitatNameEnrichver ?? this.cellHabitatNameEnrichver,
      cellClimateName: cellClimateName ?? this.cellClimateName,
      cellClimateNameEnrichver:
          cellClimateNameEnrichver ?? this.cellClimateNameEnrichver,
      cellContinentName: cellContinentName ?? this.cellContinentName,
      cellContinentNameEnrichver:
          cellContinentNameEnrichver ?? this.cellContinentNameEnrichver,
      locationDistrict: locationDistrict ?? this.locationDistrict,
      locationDistrictEnrichver:
          locationDistrictEnrichver ?? this.locationDistrictEnrichver,
      locationCity: locationCity ?? this.locationCity,
      locationCityEnrichver:
          locationCityEnrichver ?? this.locationCityEnrichver,
      locationState: locationState ?? this.locationState,
      locationStateEnrichver:
          locationStateEnrichver ?? this.locationStateEnrichver,
      locationCountry: locationCountry ?? this.locationCountry,
      locationCountryEnrichver:
          locationCountryEnrichver ?? this.locationCountryEnrichver,
      locationCountryCode: locationCountryCode ?? this.locationCountryCode,
      locationCountryCodeEnrichver:
          locationCountryCodeEnrichver ?? this.locationCountryCodeEnrichver,
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
    if (affixes.present) {
      map['affixes'] = Variable<String>(affixes.value);
    }
    if (parentAId.present) {
      map['parent_a_id'] = Variable<String>(parentAId.value);
    }
    if (parentBId.present) {
      map['parent_b_id'] = Variable<String>(parentBId.value);
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
    if (iconUrl.present) {
      map['icon_url'] = Variable<String>(iconUrl.value);
    }
    if (artUrl.present) {
      map['art_url'] = Variable<String>(artUrl.value);
    }
    if (animalClassName.present) {
      map['animal_class_name'] = Variable<String>(animalClassName.value);
    }
    if (animalClassNameEnrichver.present) {
      map['animal_class_name_enrichver'] =
          Variable<String>(animalClassNameEnrichver.value);
    }
    if (foodPreferenceName.present) {
      map['food_preference_name'] = Variable<String>(foodPreferenceName.value);
    }
    if (foodPreferenceNameEnrichver.present) {
      map['food_preference_name_enrichver'] =
          Variable<String>(foodPreferenceNameEnrichver.value);
    }
    if (climateName.present) {
      map['climate_name'] = Variable<String>(climateName.value);
    }
    if (climateNameEnrichver.present) {
      map['climate_name_enrichver'] =
          Variable<String>(climateNameEnrichver.value);
    }
    if (brawn.present) {
      map['brawn'] = Variable<int>(brawn.value);
    }
    if (brawnEnrichver.present) {
      map['brawn_enrichver'] = Variable<String>(brawnEnrichver.value);
    }
    if (wit.present) {
      map['wit'] = Variable<int>(wit.value);
    }
    if (witEnrichver.present) {
      map['wit_enrichver'] = Variable<String>(witEnrichver.value);
    }
    if (speed.present) {
      map['speed'] = Variable<int>(speed.value);
    }
    if (speedEnrichver.present) {
      map['speed_enrichver'] = Variable<String>(speedEnrichver.value);
    }
    if (sizeName.present) {
      map['size_name'] = Variable<String>(sizeName.value);
    }
    if (sizeNameEnrichver.present) {
      map['size_name_enrichver'] = Variable<String>(sizeNameEnrichver.value);
    }
    if (iconUrlEnrichver.present) {
      map['icon_url_enrichver'] = Variable<String>(iconUrlEnrichver.value);
    }
    if (artUrlEnrichver.present) {
      map['art_url_enrichver'] = Variable<String>(artUrlEnrichver.value);
    }
    if (cellHabitatName.present) {
      map['cell_habitat_name'] = Variable<String>(cellHabitatName.value);
    }
    if (cellHabitatNameEnrichver.present) {
      map['cell_habitat_name_enrichver'] =
          Variable<String>(cellHabitatNameEnrichver.value);
    }
    if (cellClimateName.present) {
      map['cell_climate_name'] = Variable<String>(cellClimateName.value);
    }
    if (cellClimateNameEnrichver.present) {
      map['cell_climate_name_enrichver'] =
          Variable<String>(cellClimateNameEnrichver.value);
    }
    if (cellContinentName.present) {
      map['cell_continent_name'] = Variable<String>(cellContinentName.value);
    }
    if (cellContinentNameEnrichver.present) {
      map['cell_continent_name_enrichver'] =
          Variable<String>(cellContinentNameEnrichver.value);
    }
    if (locationDistrict.present) {
      map['location_district'] = Variable<String>(locationDistrict.value);
    }
    if (locationDistrictEnrichver.present) {
      map['location_district_enrichver'] =
          Variable<String>(locationDistrictEnrichver.value);
    }
    if (locationCity.present) {
      map['location_city'] = Variable<String>(locationCity.value);
    }
    if (locationCityEnrichver.present) {
      map['location_city_enrichver'] =
          Variable<String>(locationCityEnrichver.value);
    }
    if (locationState.present) {
      map['location_state'] = Variable<String>(locationState.value);
    }
    if (locationStateEnrichver.present) {
      map['location_state_enrichver'] =
          Variable<String>(locationStateEnrichver.value);
    }
    if (locationCountry.present) {
      map['location_country'] = Variable<String>(locationCountry.value);
    }
    if (locationCountryEnrichver.present) {
      map['location_country_enrichver'] =
          Variable<String>(locationCountryEnrichver.value);
    }
    if (locationCountryCode.present) {
      map['location_country_code'] =
          Variable<String>(locationCountryCode.value);
    }
    if (locationCountryCodeEnrichver.present) {
      map['location_country_code_enrichver'] =
          Variable<String>(locationCountryCodeEnrichver.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalItemInstanceTableCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('definitionId: $definitionId, ')
          ..write('affixes: $affixes, ')
          ..write('parentAId: $parentAId, ')
          ..write('parentBId: $parentBId, ')
          ..write('acquiredAt: $acquiredAt, ')
          ..write('acquiredInCellId: $acquiredInCellId, ')
          ..write('dailySeed: $dailySeed, ')
          ..write('status: $status, ')
          ..write('badgesJson: $badgesJson, ')
          ..write('displayName: $displayName, ')
          ..write('scientificName: $scientificName, ')
          ..write('categoryName: $categoryName, ')
          ..write('rarityName: $rarityName, ')
          ..write('habitatsJson: $habitatsJson, ')
          ..write('continentsJson: $continentsJson, ')
          ..write('taxonomicClass: $taxonomicClass, ')
          ..write('iconUrl: $iconUrl, ')
          ..write('artUrl: $artUrl, ')
          ..write('animalClassName: $animalClassName, ')
          ..write('animalClassNameEnrichver: $animalClassNameEnrichver, ')
          ..write('foodPreferenceName: $foodPreferenceName, ')
          ..write('foodPreferenceNameEnrichver: $foodPreferenceNameEnrichver, ')
          ..write('climateName: $climateName, ')
          ..write('climateNameEnrichver: $climateNameEnrichver, ')
          ..write('brawn: $brawn, ')
          ..write('brawnEnrichver: $brawnEnrichver, ')
          ..write('wit: $wit, ')
          ..write('witEnrichver: $witEnrichver, ')
          ..write('speed: $speed, ')
          ..write('speedEnrichver: $speedEnrichver, ')
          ..write('sizeName: $sizeName, ')
          ..write('sizeNameEnrichver: $sizeNameEnrichver, ')
          ..write('iconUrlEnrichver: $iconUrlEnrichver, ')
          ..write('artUrlEnrichver: $artUrlEnrichver, ')
          ..write('cellHabitatName: $cellHabitatName, ')
          ..write('cellHabitatNameEnrichver: $cellHabitatNameEnrichver, ')
          ..write('cellClimateName: $cellClimateName, ')
          ..write('cellClimateNameEnrichver: $cellClimateNameEnrichver, ')
          ..write('cellContinentName: $cellContinentName, ')
          ..write('cellContinentNameEnrichver: $cellContinentNameEnrichver, ')
          ..write('locationDistrict: $locationDistrict, ')
          ..write('locationDistrictEnrichver: $locationDistrictEnrichver, ')
          ..write('locationCity: $locationCity, ')
          ..write('locationCityEnrichver: $locationCityEnrichver, ')
          ..write('locationState: $locationState, ')
          ..write('locationStateEnrichver: $locationStateEnrichver, ')
          ..write('locationCountry: $locationCountry, ')
          ..write('locationCountryEnrichver: $locationCountryEnrichver, ')
          ..write('locationCountryCode: $locationCountryCode, ')
          ..write(
              'locationCountryCodeEnrichver: $locationCountryCodeEnrichver, ')
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
  static const VerificationMeta _lastLatMeta =
      const VerificationMeta('lastLat');
  @override
  late final GeneratedColumn<double> lastLat = GeneratedColumn<double>(
      'last_lat', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _lastLonMeta =
      const VerificationMeta('lastLon');
  @override
  late final GeneratedColumn<double> lastLon = GeneratedColumn<double>(
      'last_lon', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _totalStepsMeta =
      const VerificationMeta('totalSteps');
  @override
  late final GeneratedColumn<int> totalSteps = GeneratedColumn<int>(
      'total_steps', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _lastKnownStepCountMeta =
      const VerificationMeta('lastKnownStepCount');
  @override
  late final GeneratedColumn<int> lastKnownStepCount = GeneratedColumn<int>(
      'last_known_step_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
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
        hasCompletedOnboarding,
        lastLat,
        lastLon,
        totalSteps,
        lastKnownStepCount,
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
    if (data.containsKey('has_completed_onboarding')) {
      context.handle(
          _hasCompletedOnboardingMeta,
          hasCompletedOnboarding.isAcceptableOrUnknown(
              data['has_completed_onboarding']!, _hasCompletedOnboardingMeta));
    }
    if (data.containsKey('last_lat')) {
      context.handle(_lastLatMeta,
          lastLat.isAcceptableOrUnknown(data['last_lat']!, _lastLatMeta));
    }
    if (data.containsKey('last_lon')) {
      context.handle(_lastLonMeta,
          lastLon.isAcceptableOrUnknown(data['last_lon']!, _lastLonMeta));
    }
    if (data.containsKey('total_steps')) {
      context.handle(
          _totalStepsMeta,
          totalSteps.isAcceptableOrUnknown(
              data['total_steps']!, _totalStepsMeta));
    }
    if (data.containsKey('last_known_step_count')) {
      context.handle(
          _lastKnownStepCountMeta,
          lastKnownStepCount.isAcceptableOrUnknown(
              data['last_known_step_count']!, _lastKnownStepCountMeta));
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
      hasCompletedOnboarding: attachedDatabase.typeMapping.read(
          DriftSqlType.bool,
          data['${effectivePrefix}has_completed_onboarding'])!,
      lastLat: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}last_lat']),
      lastLon: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}last_lon']),
      totalSteps: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}total_steps'])!,
      lastKnownStepCount: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}last_known_step_count'])!,
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
  final bool hasCompletedOnboarding;
  final double? lastLat;
  final double? lastLon;
  final int totalSteps;
  final int lastKnownStepCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  const LocalPlayerProfile(
      {required this.id,
      required this.displayName,
      required this.currentStreak,
      required this.longestStreak,
      required this.totalDistanceKm,
      required this.currentSeason,
      required this.hasCompletedOnboarding,
      this.lastLat,
      this.lastLon,
      required this.totalSteps,
      required this.lastKnownStepCount,
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
    map['has_completed_onboarding'] = Variable<bool>(hasCompletedOnboarding);
    if (!nullToAbsent || lastLat != null) {
      map['last_lat'] = Variable<double>(lastLat);
    }
    if (!nullToAbsent || lastLon != null) {
      map['last_lon'] = Variable<double>(lastLon);
    }
    map['total_steps'] = Variable<int>(totalSteps);
    map['last_known_step_count'] = Variable<int>(lastKnownStepCount);
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
      hasCompletedOnboarding: Value(hasCompletedOnboarding),
      lastLat: lastLat == null && nullToAbsent
          ? const Value.absent()
          : Value(lastLat),
      lastLon: lastLon == null && nullToAbsent
          ? const Value.absent()
          : Value(lastLon),
      totalSteps: Value(totalSteps),
      lastKnownStepCount: Value(lastKnownStepCount),
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
      hasCompletedOnboarding:
          serializer.fromJson<bool>(json['hasCompletedOnboarding']),
      lastLat: serializer.fromJson<double?>(json['lastLat']),
      lastLon: serializer.fromJson<double?>(json['lastLon']),
      totalSteps: serializer.fromJson<int>(json['totalSteps']),
      lastKnownStepCount: serializer.fromJson<int>(json['lastKnownStepCount']),
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
      'hasCompletedOnboarding': serializer.toJson<bool>(hasCompletedOnboarding),
      'lastLat': serializer.toJson<double?>(lastLat),
      'lastLon': serializer.toJson<double?>(lastLon),
      'totalSteps': serializer.toJson<int>(totalSteps),
      'lastKnownStepCount': serializer.toJson<int>(lastKnownStepCount),
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
          bool? hasCompletedOnboarding,
          Value<double?> lastLat = const Value.absent(),
          Value<double?> lastLon = const Value.absent(),
          int? totalSteps,
          int? lastKnownStepCount,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      LocalPlayerProfile(
        id: id ?? this.id,
        displayName: displayName ?? this.displayName,
        currentStreak: currentStreak ?? this.currentStreak,
        longestStreak: longestStreak ?? this.longestStreak,
        totalDistanceKm: totalDistanceKm ?? this.totalDistanceKm,
        currentSeason: currentSeason ?? this.currentSeason,
        hasCompletedOnboarding:
            hasCompletedOnboarding ?? this.hasCompletedOnboarding,
        lastLat: lastLat.present ? lastLat.value : this.lastLat,
        lastLon: lastLon.present ? lastLon.value : this.lastLon,
        totalSteps: totalSteps ?? this.totalSteps,
        lastKnownStepCount: lastKnownStepCount ?? this.lastKnownStepCount,
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
      hasCompletedOnboarding: data.hasCompletedOnboarding.present
          ? data.hasCompletedOnboarding.value
          : this.hasCompletedOnboarding,
      lastLat: data.lastLat.present ? data.lastLat.value : this.lastLat,
      lastLon: data.lastLon.present ? data.lastLon.value : this.lastLon,
      totalSteps:
          data.totalSteps.present ? data.totalSteps.value : this.totalSteps,
      lastKnownStepCount: data.lastKnownStepCount.present
          ? data.lastKnownStepCount.value
          : this.lastKnownStepCount,
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
          ..write('hasCompletedOnboarding: $hasCompletedOnboarding, ')
          ..write('lastLat: $lastLat, ')
          ..write('lastLon: $lastLon, ')
          ..write('totalSteps: $totalSteps, ')
          ..write('lastKnownStepCount: $lastKnownStepCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      displayName,
      currentStreak,
      longestStreak,
      totalDistanceKm,
      currentSeason,
      hasCompletedOnboarding,
      lastLat,
      lastLon,
      totalSteps,
      lastKnownStepCount,
      createdAt,
      updatedAt);
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
          other.hasCompletedOnboarding == this.hasCompletedOnboarding &&
          other.lastLat == this.lastLat &&
          other.lastLon == this.lastLon &&
          other.totalSteps == this.totalSteps &&
          other.lastKnownStepCount == this.lastKnownStepCount &&
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
  final Value<bool> hasCompletedOnboarding;
  final Value<double?> lastLat;
  final Value<double?> lastLon;
  final Value<int> totalSteps;
  final Value<int> lastKnownStepCount;
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
    this.hasCompletedOnboarding = const Value.absent(),
    this.lastLat = const Value.absent(),
    this.lastLon = const Value.absent(),
    this.totalSteps = const Value.absent(),
    this.lastKnownStepCount = const Value.absent(),
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
    this.hasCompletedOnboarding = const Value.absent(),
    this.lastLat = const Value.absent(),
    this.lastLon = const Value.absent(),
    this.totalSteps = const Value.absent(),
    this.lastKnownStepCount = const Value.absent(),
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
    Expression<bool>? hasCompletedOnboarding,
    Expression<double>? lastLat,
    Expression<double>? lastLon,
    Expression<int>? totalSteps,
    Expression<int>? lastKnownStepCount,
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
      if (hasCompletedOnboarding != null)
        'has_completed_onboarding': hasCompletedOnboarding,
      if (lastLat != null) 'last_lat': lastLat,
      if (lastLon != null) 'last_lon': lastLon,
      if (totalSteps != null) 'total_steps': totalSteps,
      if (lastKnownStepCount != null)
        'last_known_step_count': lastKnownStepCount,
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
      Value<bool>? hasCompletedOnboarding,
      Value<double?>? lastLat,
      Value<double?>? lastLon,
      Value<int>? totalSteps,
      Value<int>? lastKnownStepCount,
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
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      lastLat: lastLat ?? this.lastLat,
      lastLon: lastLon ?? this.lastLon,
      totalSteps: totalSteps ?? this.totalSteps,
      lastKnownStepCount: lastKnownStepCount ?? this.lastKnownStepCount,
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
    if (hasCompletedOnboarding.present) {
      map['has_completed_onboarding'] =
          Variable<bool>(hasCompletedOnboarding.value);
    }
    if (lastLat.present) {
      map['last_lat'] = Variable<double>(lastLat.value);
    }
    if (lastLon.present) {
      map['last_lon'] = Variable<double>(lastLon.value);
    }
    if (totalSteps.present) {
      map['total_steps'] = Variable<int>(totalSteps.value);
    }
    if (lastKnownStepCount.present) {
      map['last_known_step_count'] = Variable<int>(lastKnownStepCount.value);
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
          ..write('hasCompletedOnboarding: $hasCompletedOnboarding, ')
          ..write('lastLat: $lastLat, ')
          ..write('lastLon: $lastLon, ')
          ..write('totalSteps: $totalSteps, ')
          ..write('lastKnownStepCount: $lastKnownStepCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalSpeciesTableTable extends LocalSpeciesTable
    with TableInfo<$LocalSpeciesTableTable, LocalSpecies> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalSpeciesTableTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _iconPromptMeta =
      const VerificationMeta('iconPrompt');
  @override
  late final GeneratedColumn<String> iconPrompt = GeneratedColumn<String>(
      'icon_prompt', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _artPromptMeta =
      const VerificationMeta('artPrompt');
  @override
  late final GeneratedColumn<String> artPrompt = GeneratedColumn<String>(
      'art_prompt', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _enrichedAtMeta =
      const VerificationMeta('enrichedAt');
  @override
  late final GeneratedColumn<DateTime> enrichedAt = GeneratedColumn<DateTime>(
      'enriched_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _animalClassEnrichverMeta =
      const VerificationMeta('animalClassEnrichver');
  @override
  late final GeneratedColumn<String> animalClassEnrichver =
      GeneratedColumn<String>('animal_class_enrichver', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _foodPreferenceEnrichverMeta =
      const VerificationMeta('foodPreferenceEnrichver');
  @override
  late final GeneratedColumn<String> foodPreferenceEnrichver =
      GeneratedColumn<String>('food_preference_enrichver', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _climateEnrichverMeta =
      const VerificationMeta('climateEnrichver');
  @override
  late final GeneratedColumn<String> climateEnrichver = GeneratedColumn<String>(
      'climate_enrichver', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _brawnEnrichverMeta =
      const VerificationMeta('brawnEnrichver');
  @override
  late final GeneratedColumn<String> brawnEnrichver = GeneratedColumn<String>(
      'brawn_enrichver', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _witEnrichverMeta =
      const VerificationMeta('witEnrichver');
  @override
  late final GeneratedColumn<String> witEnrichver = GeneratedColumn<String>(
      'wit_enrichver', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _speedEnrichverMeta =
      const VerificationMeta('speedEnrichver');
  @override
  late final GeneratedColumn<String> speedEnrichver = GeneratedColumn<String>(
      'speed_enrichver', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sizeEnrichverMeta =
      const VerificationMeta('sizeEnrichver');
  @override
  late final GeneratedColumn<String> sizeEnrichver = GeneratedColumn<String>(
      'size_enrichver', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _iconPromptEnrichverMeta =
      const VerificationMeta('iconPromptEnrichver');
  @override
  late final GeneratedColumn<String> iconPromptEnrichver =
      GeneratedColumn<String>('icon_prompt_enrichver', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _artPromptEnrichverMeta =
      const VerificationMeta('artPromptEnrichver');
  @override
  late final GeneratedColumn<String> artPromptEnrichver =
      GeneratedColumn<String>('art_prompt_enrichver', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _iconUrlEnrichverMeta =
      const VerificationMeta('iconUrlEnrichver');
  @override
  late final GeneratedColumn<String> iconUrlEnrichver = GeneratedColumn<String>(
      'icon_url_enrichver', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _artUrlEnrichverMeta =
      const VerificationMeta('artUrlEnrichver');
  @override
  late final GeneratedColumn<String> artUrlEnrichver = GeneratedColumn<String>(
      'art_url_enrichver', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
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
        iconPrompt,
        artPrompt,
        enrichedAt,
        animalClassEnrichver,
        foodPreferenceEnrichver,
        climateEnrichver,
        brawnEnrichver,
        witEnrichver,
        speedEnrichver,
        sizeEnrichver,
        iconPromptEnrichver,
        artPromptEnrichver,
        iconUrlEnrichver,
        artUrlEnrichver
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_species_table';
  @override
  VerificationContext validateIntegrity(Insertable<LocalSpecies> instance,
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
    if (data.containsKey('icon_prompt')) {
      context.handle(
          _iconPromptMeta,
          iconPrompt.isAcceptableOrUnknown(
              data['icon_prompt']!, _iconPromptMeta));
    }
    if (data.containsKey('art_prompt')) {
      context.handle(_artPromptMeta,
          artPrompt.isAcceptableOrUnknown(data['art_prompt']!, _artPromptMeta));
    }
    if (data.containsKey('enriched_at')) {
      context.handle(
          _enrichedAtMeta,
          enrichedAt.isAcceptableOrUnknown(
              data['enriched_at']!, _enrichedAtMeta));
    }
    if (data.containsKey('animal_class_enrichver')) {
      context.handle(
          _animalClassEnrichverMeta,
          animalClassEnrichver.isAcceptableOrUnknown(
              data['animal_class_enrichver']!, _animalClassEnrichverMeta));
    }
    if (data.containsKey('food_preference_enrichver')) {
      context.handle(
          _foodPreferenceEnrichverMeta,
          foodPreferenceEnrichver.isAcceptableOrUnknown(
              data['food_preference_enrichver']!,
              _foodPreferenceEnrichverMeta));
    }
    if (data.containsKey('climate_enrichver')) {
      context.handle(
          _climateEnrichverMeta,
          climateEnrichver.isAcceptableOrUnknown(
              data['climate_enrichver']!, _climateEnrichverMeta));
    }
    if (data.containsKey('brawn_enrichver')) {
      context.handle(
          _brawnEnrichverMeta,
          brawnEnrichver.isAcceptableOrUnknown(
              data['brawn_enrichver']!, _brawnEnrichverMeta));
    }
    if (data.containsKey('wit_enrichver')) {
      context.handle(
          _witEnrichverMeta,
          witEnrichver.isAcceptableOrUnknown(
              data['wit_enrichver']!, _witEnrichverMeta));
    }
    if (data.containsKey('speed_enrichver')) {
      context.handle(
          _speedEnrichverMeta,
          speedEnrichver.isAcceptableOrUnknown(
              data['speed_enrichver']!, _speedEnrichverMeta));
    }
    if (data.containsKey('size_enrichver')) {
      context.handle(
          _sizeEnrichverMeta,
          sizeEnrichver.isAcceptableOrUnknown(
              data['size_enrichver']!, _sizeEnrichverMeta));
    }
    if (data.containsKey('icon_prompt_enrichver')) {
      context.handle(
          _iconPromptEnrichverMeta,
          iconPromptEnrichver.isAcceptableOrUnknown(
              data['icon_prompt_enrichver']!, _iconPromptEnrichverMeta));
    }
    if (data.containsKey('art_prompt_enrichver')) {
      context.handle(
          _artPromptEnrichverMeta,
          artPromptEnrichver.isAcceptableOrUnknown(
              data['art_prompt_enrichver']!, _artPromptEnrichverMeta));
    }
    if (data.containsKey('icon_url_enrichver')) {
      context.handle(
          _iconUrlEnrichverMeta,
          iconUrlEnrichver.isAcceptableOrUnknown(
              data['icon_url_enrichver']!, _iconUrlEnrichverMeta));
    }
    if (data.containsKey('art_url_enrichver')) {
      context.handle(
          _artUrlEnrichverMeta,
          artUrlEnrichver.isAcceptableOrUnknown(
              data['art_url_enrichver']!, _artUrlEnrichverMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {definitionId};
  @override
  LocalSpecies map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalSpecies(
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
      iconPrompt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}icon_prompt']),
      artPrompt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}art_prompt']),
      enrichedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}enriched_at']),
      animalClassEnrichver: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}animal_class_enrichver']),
      foodPreferenceEnrichver: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}food_preference_enrichver']),
      climateEnrichver: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}climate_enrichver']),
      brawnEnrichver: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}brawn_enrichver']),
      witEnrichver: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}wit_enrichver']),
      speedEnrichver: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}speed_enrichver']),
      sizeEnrichver: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}size_enrichver']),
      iconPromptEnrichver: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}icon_prompt_enrichver']),
      artPromptEnrichver: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}art_prompt_enrichver']),
      iconUrlEnrichver: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}icon_url_enrichver']),
      artUrlEnrichver: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}art_url_enrichver']),
    );
  }

  @override
  $LocalSpeciesTableTable createAlias(String alias) {
    return $LocalSpeciesTableTable(attachedDatabase, alias);
  }
}

class LocalSpecies extends DataClass implements Insertable<LocalSpecies> {
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
  final String? iconPrompt;
  final String? artPrompt;
  final DateTime? enrichedAt;
  final String? animalClassEnrichver;
  final String? foodPreferenceEnrichver;
  final String? climateEnrichver;
  final String? brawnEnrichver;
  final String? witEnrichver;
  final String? speedEnrichver;
  final String? sizeEnrichver;
  final String? iconPromptEnrichver;
  final String? artPromptEnrichver;
  final String? iconUrlEnrichver;
  final String? artUrlEnrichver;
  const LocalSpecies(
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
      this.iconPrompt,
      this.artPrompt,
      this.enrichedAt,
      this.animalClassEnrichver,
      this.foodPreferenceEnrichver,
      this.climateEnrichver,
      this.brawnEnrichver,
      this.witEnrichver,
      this.speedEnrichver,
      this.sizeEnrichver,
      this.iconPromptEnrichver,
      this.artPromptEnrichver,
      this.iconUrlEnrichver,
      this.artUrlEnrichver});
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
    if (!nullToAbsent || iconPrompt != null) {
      map['icon_prompt'] = Variable<String>(iconPrompt);
    }
    if (!nullToAbsent || artPrompt != null) {
      map['art_prompt'] = Variable<String>(artPrompt);
    }
    if (!nullToAbsent || enrichedAt != null) {
      map['enriched_at'] = Variable<DateTime>(enrichedAt);
    }
    if (!nullToAbsent || animalClassEnrichver != null) {
      map['animal_class_enrichver'] = Variable<String>(animalClassEnrichver);
    }
    if (!nullToAbsent || foodPreferenceEnrichver != null) {
      map['food_preference_enrichver'] =
          Variable<String>(foodPreferenceEnrichver);
    }
    if (!nullToAbsent || climateEnrichver != null) {
      map['climate_enrichver'] = Variable<String>(climateEnrichver);
    }
    if (!nullToAbsent || brawnEnrichver != null) {
      map['brawn_enrichver'] = Variable<String>(brawnEnrichver);
    }
    if (!nullToAbsent || witEnrichver != null) {
      map['wit_enrichver'] = Variable<String>(witEnrichver);
    }
    if (!nullToAbsent || speedEnrichver != null) {
      map['speed_enrichver'] = Variable<String>(speedEnrichver);
    }
    if (!nullToAbsent || sizeEnrichver != null) {
      map['size_enrichver'] = Variable<String>(sizeEnrichver);
    }
    if (!nullToAbsent || iconPromptEnrichver != null) {
      map['icon_prompt_enrichver'] = Variable<String>(iconPromptEnrichver);
    }
    if (!nullToAbsent || artPromptEnrichver != null) {
      map['art_prompt_enrichver'] = Variable<String>(artPromptEnrichver);
    }
    if (!nullToAbsent || iconUrlEnrichver != null) {
      map['icon_url_enrichver'] = Variable<String>(iconUrlEnrichver);
    }
    if (!nullToAbsent || artUrlEnrichver != null) {
      map['art_url_enrichver'] = Variable<String>(artUrlEnrichver);
    }
    return map;
  }

  LocalSpeciesTableCompanion toCompanion(bool nullToAbsent) {
    return LocalSpeciesTableCompanion(
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
      iconPrompt: iconPrompt == null && nullToAbsent
          ? const Value.absent()
          : Value(iconPrompt),
      artPrompt: artPrompt == null && nullToAbsent
          ? const Value.absent()
          : Value(artPrompt),
      enrichedAt: enrichedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(enrichedAt),
      animalClassEnrichver: animalClassEnrichver == null && nullToAbsent
          ? const Value.absent()
          : Value(animalClassEnrichver),
      foodPreferenceEnrichver: foodPreferenceEnrichver == null && nullToAbsent
          ? const Value.absent()
          : Value(foodPreferenceEnrichver),
      climateEnrichver: climateEnrichver == null && nullToAbsent
          ? const Value.absent()
          : Value(climateEnrichver),
      brawnEnrichver: brawnEnrichver == null && nullToAbsent
          ? const Value.absent()
          : Value(brawnEnrichver),
      witEnrichver: witEnrichver == null && nullToAbsent
          ? const Value.absent()
          : Value(witEnrichver),
      speedEnrichver: speedEnrichver == null && nullToAbsent
          ? const Value.absent()
          : Value(speedEnrichver),
      sizeEnrichver: sizeEnrichver == null && nullToAbsent
          ? const Value.absent()
          : Value(sizeEnrichver),
      iconPromptEnrichver: iconPromptEnrichver == null && nullToAbsent
          ? const Value.absent()
          : Value(iconPromptEnrichver),
      artPromptEnrichver: artPromptEnrichver == null && nullToAbsent
          ? const Value.absent()
          : Value(artPromptEnrichver),
      iconUrlEnrichver: iconUrlEnrichver == null && nullToAbsent
          ? const Value.absent()
          : Value(iconUrlEnrichver),
      artUrlEnrichver: artUrlEnrichver == null && nullToAbsent
          ? const Value.absent()
          : Value(artUrlEnrichver),
    );
  }

  factory LocalSpecies.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalSpecies(
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
      iconPrompt: serializer.fromJson<String?>(json['iconPrompt']),
      artPrompt: serializer.fromJson<String?>(json['artPrompt']),
      enrichedAt: serializer.fromJson<DateTime?>(json['enrichedAt']),
      animalClassEnrichver:
          serializer.fromJson<String?>(json['animalClassEnrichver']),
      foodPreferenceEnrichver:
          serializer.fromJson<String?>(json['foodPreferenceEnrichver']),
      climateEnrichver: serializer.fromJson<String?>(json['climateEnrichver']),
      brawnEnrichver: serializer.fromJson<String?>(json['brawnEnrichver']),
      witEnrichver: serializer.fromJson<String?>(json['witEnrichver']),
      speedEnrichver: serializer.fromJson<String?>(json['speedEnrichver']),
      sizeEnrichver: serializer.fromJson<String?>(json['sizeEnrichver']),
      iconPromptEnrichver:
          serializer.fromJson<String?>(json['iconPromptEnrichver']),
      artPromptEnrichver:
          serializer.fromJson<String?>(json['artPromptEnrichver']),
      iconUrlEnrichver: serializer.fromJson<String?>(json['iconUrlEnrichver']),
      artUrlEnrichver: serializer.fromJson<String?>(json['artUrlEnrichver']),
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
      'iconPrompt': serializer.toJson<String?>(iconPrompt),
      'artPrompt': serializer.toJson<String?>(artPrompt),
      'enrichedAt': serializer.toJson<DateTime?>(enrichedAt),
      'animalClassEnrichver': serializer.toJson<String?>(animalClassEnrichver),
      'foodPreferenceEnrichver':
          serializer.toJson<String?>(foodPreferenceEnrichver),
      'climateEnrichver': serializer.toJson<String?>(climateEnrichver),
      'brawnEnrichver': serializer.toJson<String?>(brawnEnrichver),
      'witEnrichver': serializer.toJson<String?>(witEnrichver),
      'speedEnrichver': serializer.toJson<String?>(speedEnrichver),
      'sizeEnrichver': serializer.toJson<String?>(sizeEnrichver),
      'iconPromptEnrichver': serializer.toJson<String?>(iconPromptEnrichver),
      'artPromptEnrichver': serializer.toJson<String?>(artPromptEnrichver),
      'iconUrlEnrichver': serializer.toJson<String?>(iconUrlEnrichver),
      'artUrlEnrichver': serializer.toJson<String?>(artUrlEnrichver),
    };
  }

  LocalSpecies copyWith(
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
          Value<String?> iconPrompt = const Value.absent(),
          Value<String?> artPrompt = const Value.absent(),
          Value<DateTime?> enrichedAt = const Value.absent(),
          Value<String?> animalClassEnrichver = const Value.absent(),
          Value<String?> foodPreferenceEnrichver = const Value.absent(),
          Value<String?> climateEnrichver = const Value.absent(),
          Value<String?> brawnEnrichver = const Value.absent(),
          Value<String?> witEnrichver = const Value.absent(),
          Value<String?> speedEnrichver = const Value.absent(),
          Value<String?> sizeEnrichver = const Value.absent(),
          Value<String?> iconPromptEnrichver = const Value.absent(),
          Value<String?> artPromptEnrichver = const Value.absent(),
          Value<String?> iconUrlEnrichver = const Value.absent(),
          Value<String?> artUrlEnrichver = const Value.absent()}) =>
      LocalSpecies(
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
        iconPrompt: iconPrompt.present ? iconPrompt.value : this.iconPrompt,
        artPrompt: artPrompt.present ? artPrompt.value : this.artPrompt,
        enrichedAt: enrichedAt.present ? enrichedAt.value : this.enrichedAt,
        animalClassEnrichver: animalClassEnrichver.present
            ? animalClassEnrichver.value
            : this.animalClassEnrichver,
        foodPreferenceEnrichver: foodPreferenceEnrichver.present
            ? foodPreferenceEnrichver.value
            : this.foodPreferenceEnrichver,
        climateEnrichver: climateEnrichver.present
            ? climateEnrichver.value
            : this.climateEnrichver,
        brawnEnrichver:
            brawnEnrichver.present ? brawnEnrichver.value : this.brawnEnrichver,
        witEnrichver:
            witEnrichver.present ? witEnrichver.value : this.witEnrichver,
        speedEnrichver:
            speedEnrichver.present ? speedEnrichver.value : this.speedEnrichver,
        sizeEnrichver:
            sizeEnrichver.present ? sizeEnrichver.value : this.sizeEnrichver,
        iconPromptEnrichver: iconPromptEnrichver.present
            ? iconPromptEnrichver.value
            : this.iconPromptEnrichver,
        artPromptEnrichver: artPromptEnrichver.present
            ? artPromptEnrichver.value
            : this.artPromptEnrichver,
        iconUrlEnrichver: iconUrlEnrichver.present
            ? iconUrlEnrichver.value
            : this.iconUrlEnrichver,
        artUrlEnrichver: artUrlEnrichver.present
            ? artUrlEnrichver.value
            : this.artUrlEnrichver,
      );
  LocalSpecies copyWithCompanion(LocalSpeciesTableCompanion data) {
    return LocalSpecies(
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
      iconPrompt:
          data.iconPrompt.present ? data.iconPrompt.value : this.iconPrompt,
      artPrompt: data.artPrompt.present ? data.artPrompt.value : this.artPrompt,
      enrichedAt:
          data.enrichedAt.present ? data.enrichedAt.value : this.enrichedAt,
      animalClassEnrichver: data.animalClassEnrichver.present
          ? data.animalClassEnrichver.value
          : this.animalClassEnrichver,
      foodPreferenceEnrichver: data.foodPreferenceEnrichver.present
          ? data.foodPreferenceEnrichver.value
          : this.foodPreferenceEnrichver,
      climateEnrichver: data.climateEnrichver.present
          ? data.climateEnrichver.value
          : this.climateEnrichver,
      brawnEnrichver: data.brawnEnrichver.present
          ? data.brawnEnrichver.value
          : this.brawnEnrichver,
      witEnrichver: data.witEnrichver.present
          ? data.witEnrichver.value
          : this.witEnrichver,
      speedEnrichver: data.speedEnrichver.present
          ? data.speedEnrichver.value
          : this.speedEnrichver,
      sizeEnrichver: data.sizeEnrichver.present
          ? data.sizeEnrichver.value
          : this.sizeEnrichver,
      iconPromptEnrichver: data.iconPromptEnrichver.present
          ? data.iconPromptEnrichver.value
          : this.iconPromptEnrichver,
      artPromptEnrichver: data.artPromptEnrichver.present
          ? data.artPromptEnrichver.value
          : this.artPromptEnrichver,
      iconUrlEnrichver: data.iconUrlEnrichver.present
          ? data.iconUrlEnrichver.value
          : this.iconUrlEnrichver,
      artUrlEnrichver: data.artUrlEnrichver.present
          ? data.artUrlEnrichver.value
          : this.artUrlEnrichver,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalSpecies(')
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
          ..write('iconPrompt: $iconPrompt, ')
          ..write('artPrompt: $artPrompt, ')
          ..write('enrichedAt: $enrichedAt, ')
          ..write('animalClassEnrichver: $animalClassEnrichver, ')
          ..write('foodPreferenceEnrichver: $foodPreferenceEnrichver, ')
          ..write('climateEnrichver: $climateEnrichver, ')
          ..write('brawnEnrichver: $brawnEnrichver, ')
          ..write('witEnrichver: $witEnrichver, ')
          ..write('speedEnrichver: $speedEnrichver, ')
          ..write('sizeEnrichver: $sizeEnrichver, ')
          ..write('iconPromptEnrichver: $iconPromptEnrichver, ')
          ..write('artPromptEnrichver: $artPromptEnrichver, ')
          ..write('iconUrlEnrichver: $iconUrlEnrichver, ')
          ..write('artUrlEnrichver: $artUrlEnrichver')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
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
        iconPrompt,
        artPrompt,
        enrichedAt,
        animalClassEnrichver,
        foodPreferenceEnrichver,
        climateEnrichver,
        brawnEnrichver,
        witEnrichver,
        speedEnrichver,
        sizeEnrichver,
        iconPromptEnrichver,
        artPromptEnrichver,
        iconUrlEnrichver,
        artUrlEnrichver
      ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalSpecies &&
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
          other.iconPrompt == this.iconPrompt &&
          other.artPrompt == this.artPrompt &&
          other.enrichedAt == this.enrichedAt &&
          other.animalClassEnrichver == this.animalClassEnrichver &&
          other.foodPreferenceEnrichver == this.foodPreferenceEnrichver &&
          other.climateEnrichver == this.climateEnrichver &&
          other.brawnEnrichver == this.brawnEnrichver &&
          other.witEnrichver == this.witEnrichver &&
          other.speedEnrichver == this.speedEnrichver &&
          other.sizeEnrichver == this.sizeEnrichver &&
          other.iconPromptEnrichver == this.iconPromptEnrichver &&
          other.artPromptEnrichver == this.artPromptEnrichver &&
          other.iconUrlEnrichver == this.iconUrlEnrichver &&
          other.artUrlEnrichver == this.artUrlEnrichver);
}

class LocalSpeciesTableCompanion extends UpdateCompanion<LocalSpecies> {
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
  final Value<String?> iconPrompt;
  final Value<String?> artPrompt;
  final Value<DateTime?> enrichedAt;
  final Value<String?> animalClassEnrichver;
  final Value<String?> foodPreferenceEnrichver;
  final Value<String?> climateEnrichver;
  final Value<String?> brawnEnrichver;
  final Value<String?> witEnrichver;
  final Value<String?> speedEnrichver;
  final Value<String?> sizeEnrichver;
  final Value<String?> iconPromptEnrichver;
  final Value<String?> artPromptEnrichver;
  final Value<String?> iconUrlEnrichver;
  final Value<String?> artUrlEnrichver;
  final Value<int> rowid;
  const LocalSpeciesTableCompanion({
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
    this.iconPrompt = const Value.absent(),
    this.artPrompt = const Value.absent(),
    this.enrichedAt = const Value.absent(),
    this.animalClassEnrichver = const Value.absent(),
    this.foodPreferenceEnrichver = const Value.absent(),
    this.climateEnrichver = const Value.absent(),
    this.brawnEnrichver = const Value.absent(),
    this.witEnrichver = const Value.absent(),
    this.speedEnrichver = const Value.absent(),
    this.sizeEnrichver = const Value.absent(),
    this.iconPromptEnrichver = const Value.absent(),
    this.artPromptEnrichver = const Value.absent(),
    this.iconUrlEnrichver = const Value.absent(),
    this.artUrlEnrichver = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalSpeciesTableCompanion.insert({
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
    this.iconPrompt = const Value.absent(),
    this.artPrompt = const Value.absent(),
    this.enrichedAt = const Value.absent(),
    this.animalClassEnrichver = const Value.absent(),
    this.foodPreferenceEnrichver = const Value.absent(),
    this.climateEnrichver = const Value.absent(),
    this.brawnEnrichver = const Value.absent(),
    this.witEnrichver = const Value.absent(),
    this.speedEnrichver = const Value.absent(),
    this.sizeEnrichver = const Value.absent(),
    this.iconPromptEnrichver = const Value.absent(),
    this.artPromptEnrichver = const Value.absent(),
    this.iconUrlEnrichver = const Value.absent(),
    this.artUrlEnrichver = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : definitionId = Value(definitionId),
        scientificName = Value(scientificName),
        commonName = Value(commonName),
        taxonomicClass = Value(taxonomicClass),
        iucnStatus = Value(iucnStatus),
        habitatsJson = Value(habitatsJson),
        continentsJson = Value(continentsJson);
  static Insertable<LocalSpecies> custom({
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
    Expression<String>? iconPrompt,
    Expression<String>? artPrompt,
    Expression<DateTime>? enrichedAt,
    Expression<String>? animalClassEnrichver,
    Expression<String>? foodPreferenceEnrichver,
    Expression<String>? climateEnrichver,
    Expression<String>? brawnEnrichver,
    Expression<String>? witEnrichver,
    Expression<String>? speedEnrichver,
    Expression<String>? sizeEnrichver,
    Expression<String>? iconPromptEnrichver,
    Expression<String>? artPromptEnrichver,
    Expression<String>? iconUrlEnrichver,
    Expression<String>? artUrlEnrichver,
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
      if (iconPrompt != null) 'icon_prompt': iconPrompt,
      if (artPrompt != null) 'art_prompt': artPrompt,
      if (enrichedAt != null) 'enriched_at': enrichedAt,
      if (animalClassEnrichver != null)
        'animal_class_enrichver': animalClassEnrichver,
      if (foodPreferenceEnrichver != null)
        'food_preference_enrichver': foodPreferenceEnrichver,
      if (climateEnrichver != null) 'climate_enrichver': climateEnrichver,
      if (brawnEnrichver != null) 'brawn_enrichver': brawnEnrichver,
      if (witEnrichver != null) 'wit_enrichver': witEnrichver,
      if (speedEnrichver != null) 'speed_enrichver': speedEnrichver,
      if (sizeEnrichver != null) 'size_enrichver': sizeEnrichver,
      if (iconPromptEnrichver != null)
        'icon_prompt_enrichver': iconPromptEnrichver,
      if (artPromptEnrichver != null)
        'art_prompt_enrichver': artPromptEnrichver,
      if (iconUrlEnrichver != null) 'icon_url_enrichver': iconUrlEnrichver,
      if (artUrlEnrichver != null) 'art_url_enrichver': artUrlEnrichver,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalSpeciesTableCompanion copyWith(
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
      Value<String?>? iconPrompt,
      Value<String?>? artPrompt,
      Value<DateTime?>? enrichedAt,
      Value<String?>? animalClassEnrichver,
      Value<String?>? foodPreferenceEnrichver,
      Value<String?>? climateEnrichver,
      Value<String?>? brawnEnrichver,
      Value<String?>? witEnrichver,
      Value<String?>? speedEnrichver,
      Value<String?>? sizeEnrichver,
      Value<String?>? iconPromptEnrichver,
      Value<String?>? artPromptEnrichver,
      Value<String?>? iconUrlEnrichver,
      Value<String?>? artUrlEnrichver,
      Value<int>? rowid}) {
    return LocalSpeciesTableCompanion(
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
      iconPrompt: iconPrompt ?? this.iconPrompt,
      artPrompt: artPrompt ?? this.artPrompt,
      enrichedAt: enrichedAt ?? this.enrichedAt,
      animalClassEnrichver: animalClassEnrichver ?? this.animalClassEnrichver,
      foodPreferenceEnrichver:
          foodPreferenceEnrichver ?? this.foodPreferenceEnrichver,
      climateEnrichver: climateEnrichver ?? this.climateEnrichver,
      brawnEnrichver: brawnEnrichver ?? this.brawnEnrichver,
      witEnrichver: witEnrichver ?? this.witEnrichver,
      speedEnrichver: speedEnrichver ?? this.speedEnrichver,
      sizeEnrichver: sizeEnrichver ?? this.sizeEnrichver,
      iconPromptEnrichver: iconPromptEnrichver ?? this.iconPromptEnrichver,
      artPromptEnrichver: artPromptEnrichver ?? this.artPromptEnrichver,
      iconUrlEnrichver: iconUrlEnrichver ?? this.iconUrlEnrichver,
      artUrlEnrichver: artUrlEnrichver ?? this.artUrlEnrichver,
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
    if (iconPrompt.present) {
      map['icon_prompt'] = Variable<String>(iconPrompt.value);
    }
    if (artPrompt.present) {
      map['art_prompt'] = Variable<String>(artPrompt.value);
    }
    if (enrichedAt.present) {
      map['enriched_at'] = Variable<DateTime>(enrichedAt.value);
    }
    if (animalClassEnrichver.present) {
      map['animal_class_enrichver'] =
          Variable<String>(animalClassEnrichver.value);
    }
    if (foodPreferenceEnrichver.present) {
      map['food_preference_enrichver'] =
          Variable<String>(foodPreferenceEnrichver.value);
    }
    if (climateEnrichver.present) {
      map['climate_enrichver'] = Variable<String>(climateEnrichver.value);
    }
    if (brawnEnrichver.present) {
      map['brawn_enrichver'] = Variable<String>(brawnEnrichver.value);
    }
    if (witEnrichver.present) {
      map['wit_enrichver'] = Variable<String>(witEnrichver.value);
    }
    if (speedEnrichver.present) {
      map['speed_enrichver'] = Variable<String>(speedEnrichver.value);
    }
    if (sizeEnrichver.present) {
      map['size_enrichver'] = Variable<String>(sizeEnrichver.value);
    }
    if (iconPromptEnrichver.present) {
      map['icon_prompt_enrichver'] =
          Variable<String>(iconPromptEnrichver.value);
    }
    if (artPromptEnrichver.present) {
      map['art_prompt_enrichver'] = Variable<String>(artPromptEnrichver.value);
    }
    if (iconUrlEnrichver.present) {
      map['icon_url_enrichver'] = Variable<String>(iconUrlEnrichver.value);
    }
    if (artUrlEnrichver.present) {
      map['art_url_enrichver'] = Variable<String>(artUrlEnrichver.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalSpeciesTableCompanion(')
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
          ..write('iconPrompt: $iconPrompt, ')
          ..write('artPrompt: $artPrompt, ')
          ..write('enrichedAt: $enrichedAt, ')
          ..write('animalClassEnrichver: $animalClassEnrichver, ')
          ..write('foodPreferenceEnrichver: $foodPreferenceEnrichver, ')
          ..write('climateEnrichver: $climateEnrichver, ')
          ..write('brawnEnrichver: $brawnEnrichver, ')
          ..write('witEnrichver: $witEnrichver, ')
          ..write('speedEnrichver: $speedEnrichver, ')
          ..write('sizeEnrichver: $sizeEnrichver, ')
          ..write('iconPromptEnrichver: $iconPromptEnrichver, ')
          ..write('artPromptEnrichver: $artPromptEnrichver, ')
          ..write('iconUrlEnrichver: $iconUrlEnrichver, ')
          ..write('artUrlEnrichver: $artUrlEnrichver, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalWriteQueueTableTable extends LocalWriteQueueTable
    with TableInfo<$LocalWriteQueueTableTable, LocalWriteQueueEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalWriteQueueTableTable(this.attachedDatabase, [this._alias]);
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
  static const String $name = 'local_write_queue_table';
  @override
  VerificationContext validateIntegrity(
      Insertable<LocalWriteQueueEntry> instance,
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
  LocalWriteQueueEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalWriteQueueEntry(
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
  $LocalWriteQueueTableTable createAlias(String alias) {
    return $LocalWriteQueueTableTable(attachedDatabase, alias);
  }
}

class LocalWriteQueueEntry extends DataClass
    implements Insertable<LocalWriteQueueEntry> {
  /// Auto-incremented local ID. Entries are deleted after server confirmation.
  final int id;

  /// Entity type: 'itemInstance', 'cellProgress', 'profile'.
  final String entityType;

  /// Primary key of the entity being synced.
  final String entityId;

  /// Operation: 'upsert' or 'delete'.
  final String operation;

  /// JSON-encoded snapshot of the entity at time of queuing.
  final String payload;

  /// Owner's user ID.
  final String userId;

  /// Processing status: 'pending' or 'rejected'.
  final String status;

  /// Number of sync attempts so far.
  final int attempts;

  /// Last error message from a failed sync attempt.
  final String? lastError;

  /// When this entry was created.
  final DateTime createdAt;

  /// When this entry was last updated.
  final DateTime updatedAt;
  const LocalWriteQueueEntry(
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

  LocalWriteQueueTableCompanion toCompanion(bool nullToAbsent) {
    return LocalWriteQueueTableCompanion(
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

  factory LocalWriteQueueEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalWriteQueueEntry(
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

  LocalWriteQueueEntry copyWith(
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
      LocalWriteQueueEntry(
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
  LocalWriteQueueEntry copyWithCompanion(LocalWriteQueueTableCompanion data) {
    return LocalWriteQueueEntry(
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
    return (StringBuffer('LocalWriteQueueEntry(')
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
      (other is LocalWriteQueueEntry &&
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

class LocalWriteQueueTableCompanion
    extends UpdateCompanion<LocalWriteQueueEntry> {
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
  const LocalWriteQueueTableCompanion({
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
  LocalWriteQueueTableCompanion.insert({
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
  static Insertable<LocalWriteQueueEntry> custom({
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

  LocalWriteQueueTableCompanion copyWith(
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
    return LocalWriteQueueTableCompanion(
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
    return (StringBuffer('LocalWriteQueueTableCompanion(')
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

class $LocalCellPropertiesTableTable extends LocalCellPropertiesTable
    with TableInfo<$LocalCellPropertiesTableTable, LocalCellProperties> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalCellPropertiesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _cellIdMeta = const VerificationMeta('cellId');
  @override
  late final GeneratedColumn<String> cellId = GeneratedColumn<String>(
      'cell_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _habitatsMeta =
      const VerificationMeta('habitats');
  @override
  late final GeneratedColumn<String> habitats = GeneratedColumn<String>(
      'habitats', aliasedName, false,
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
      [cellId, habitats, climate, continent, locationId, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_cell_properties_table';
  @override
  VerificationContext validateIntegrity(
      Insertable<LocalCellProperties> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('cell_id')) {
      context.handle(_cellIdMeta,
          cellId.isAcceptableOrUnknown(data['cell_id']!, _cellIdMeta));
    } else if (isInserting) {
      context.missing(_cellIdMeta);
    }
    if (data.containsKey('habitats')) {
      context.handle(_habitatsMeta,
          habitats.isAcceptableOrUnknown(data['habitats']!, _habitatsMeta));
    } else if (isInserting) {
      context.missing(_habitatsMeta);
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
  LocalCellProperties map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalCellProperties(
      cellId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cell_id'])!,
      habitats: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}habitats'])!,
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
  $LocalCellPropertiesTableTable createAlias(String alias) {
    return $LocalCellPropertiesTableTable(attachedDatabase, alias);
  }
}

class LocalCellProperties extends DataClass
    implements Insertable<LocalCellProperties> {
  final String cellId;
  final String habitats;
  final String climate;
  final String continent;
  final String? locationId;
  final DateTime createdAt;
  const LocalCellProperties(
      {required this.cellId,
      required this.habitats,
      required this.climate,
      required this.continent,
      this.locationId,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['cell_id'] = Variable<String>(cellId);
    map['habitats'] = Variable<String>(habitats);
    map['climate'] = Variable<String>(climate);
    map['continent'] = Variable<String>(continent);
    if (!nullToAbsent || locationId != null) {
      map['location_id'] = Variable<String>(locationId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  LocalCellPropertiesTableCompanion toCompanion(bool nullToAbsent) {
    return LocalCellPropertiesTableCompanion(
      cellId: Value(cellId),
      habitats: Value(habitats),
      climate: Value(climate),
      continent: Value(continent),
      locationId: locationId == null && nullToAbsent
          ? const Value.absent()
          : Value(locationId),
      createdAt: Value(createdAt),
    );
  }

  factory LocalCellProperties.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalCellProperties(
      cellId: serializer.fromJson<String>(json['cellId']),
      habitats: serializer.fromJson<String>(json['habitats']),
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
      'habitats': serializer.toJson<String>(habitats),
      'climate': serializer.toJson<String>(climate),
      'continent': serializer.toJson<String>(continent),
      'locationId': serializer.toJson<String?>(locationId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  LocalCellProperties copyWith(
          {String? cellId,
          String? habitats,
          String? climate,
          String? continent,
          Value<String?> locationId = const Value.absent(),
          DateTime? createdAt}) =>
      LocalCellProperties(
        cellId: cellId ?? this.cellId,
        habitats: habitats ?? this.habitats,
        climate: climate ?? this.climate,
        continent: continent ?? this.continent,
        locationId: locationId.present ? locationId.value : this.locationId,
        createdAt: createdAt ?? this.createdAt,
      );
  LocalCellProperties copyWithCompanion(
      LocalCellPropertiesTableCompanion data) {
    return LocalCellProperties(
      cellId: data.cellId.present ? data.cellId.value : this.cellId,
      habitats: data.habitats.present ? data.habitats.value : this.habitats,
      climate: data.climate.present ? data.climate.value : this.climate,
      continent: data.continent.present ? data.continent.value : this.continent,
      locationId:
          data.locationId.present ? data.locationId.value : this.locationId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalCellProperties(')
          ..write('cellId: $cellId, ')
          ..write('habitats: $habitats, ')
          ..write('climate: $climate, ')
          ..write('continent: $continent, ')
          ..write('locationId: $locationId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(cellId, habitats, climate, continent, locationId, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalCellProperties &&
          other.cellId == this.cellId &&
          other.habitats == this.habitats &&
          other.climate == this.climate &&
          other.continent == this.continent &&
          other.locationId == this.locationId &&
          other.createdAt == this.createdAt);
}

class LocalCellPropertiesTableCompanion
    extends UpdateCompanion<LocalCellProperties> {
  final Value<String> cellId;
  final Value<String> habitats;
  final Value<String> climate;
  final Value<String> continent;
  final Value<String?> locationId;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const LocalCellPropertiesTableCompanion({
    this.cellId = const Value.absent(),
    this.habitats = const Value.absent(),
    this.climate = const Value.absent(),
    this.continent = const Value.absent(),
    this.locationId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalCellPropertiesTableCompanion.insert({
    required String cellId,
    required String habitats,
    required String climate,
    required String continent,
    this.locationId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : cellId = Value(cellId),
        habitats = Value(habitats),
        climate = Value(climate),
        continent = Value(continent);
  static Insertable<LocalCellProperties> custom({
    Expression<String>? cellId,
    Expression<String>? habitats,
    Expression<String>? climate,
    Expression<String>? continent,
    Expression<String>? locationId,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (cellId != null) 'cell_id': cellId,
      if (habitats != null) 'habitats': habitats,
      if (climate != null) 'climate': climate,
      if (continent != null) 'continent': continent,
      if (locationId != null) 'location_id': locationId,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalCellPropertiesTableCompanion copyWith(
      {Value<String>? cellId,
      Value<String>? habitats,
      Value<String>? climate,
      Value<String>? continent,
      Value<String?>? locationId,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return LocalCellPropertiesTableCompanion(
      cellId: cellId ?? this.cellId,
      habitats: habitats ?? this.habitats,
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
    if (habitats.present) {
      map['habitats'] = Variable<String>(habitats.value);
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
    return (StringBuffer('LocalCellPropertiesTableCompanion(')
          ..write('cellId: $cellId, ')
          ..write('habitats: $habitats, ')
          ..write('climate: $climate, ')
          ..write('continent: $continent, ')
          ..write('locationId: $locationId, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalLocationNodeTableTable extends LocalLocationNodeTable
    with TableInfo<$LocalLocationNodeTableTable, LocalLocationNode> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalLocationNodeTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _osmIdMeta = const VerificationMeta('osmId');
  @override
  late final GeneratedColumn<int> osmId = GeneratedColumn<int>(
      'osm_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _adminLevelMeta =
      const VerificationMeta('adminLevel');
  @override
  late final GeneratedColumn<String> adminLevel = GeneratedColumn<String>(
      'admin_level', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _parentIdMeta =
      const VerificationMeta('parentId');
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
      'parent_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _colorHexMeta =
      const VerificationMeta('colorHex');
  @override
  late final GeneratedColumn<String> colorHex = GeneratedColumn<String>(
      'color_hex', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _geometryJsonMeta =
      const VerificationMeta('geometryJson');
  @override
  late final GeneratedColumn<String> geometryJson = GeneratedColumn<String>(
      'geometry_json', aliasedName, true,
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
        osmId,
        name,
        adminLevel,
        parentId,
        colorHex,
        geometryJson,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_location_node_table';
  @override
  VerificationContext validateIntegrity(Insertable<LocalLocationNode> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('osm_id')) {
      context.handle(
          _osmIdMeta, osmId.isAcceptableOrUnknown(data['osm_id']!, _osmIdMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('admin_level')) {
      context.handle(
          _adminLevelMeta,
          adminLevel.isAcceptableOrUnknown(
              data['admin_level']!, _adminLevelMeta));
    } else if (isInserting) {
      context.missing(_adminLevelMeta);
    }
    if (data.containsKey('parent_id')) {
      context.handle(_parentIdMeta,
          parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta));
    }
    if (data.containsKey('color_hex')) {
      context.handle(_colorHexMeta,
          colorHex.isAcceptableOrUnknown(data['color_hex']!, _colorHexMeta));
    }
    if (data.containsKey('geometry_json')) {
      context.handle(
          _geometryJsonMeta,
          geometryJson.isAcceptableOrUnknown(
              data['geometry_json']!, _geometryJsonMeta));
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
  LocalLocationNode map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalLocationNode(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      osmId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}osm_id']),
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      adminLevel: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}admin_level'])!,
      parentId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}parent_id']),
      colorHex: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}color_hex']),
      geometryJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}geometry_json']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $LocalLocationNodeTableTable createAlias(String alias) {
    return $LocalLocationNodeTableTable(attachedDatabase, alias);
  }
}

class LocalLocationNode extends DataClass
    implements Insertable<LocalLocationNode> {
  final String id;
  final int? osmId;
  final String name;
  final String adminLevel;
  final String? parentId;
  final String? colorHex;
  final String? geometryJson;
  final DateTime createdAt;
  const LocalLocationNode(
      {required this.id,
      this.osmId,
      required this.name,
      required this.adminLevel,
      this.parentId,
      this.colorHex,
      this.geometryJson,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || osmId != null) {
      map['osm_id'] = Variable<int>(osmId);
    }
    map['name'] = Variable<String>(name);
    map['admin_level'] = Variable<String>(adminLevel);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    if (!nullToAbsent || colorHex != null) {
      map['color_hex'] = Variable<String>(colorHex);
    }
    if (!nullToAbsent || geometryJson != null) {
      map['geometry_json'] = Variable<String>(geometryJson);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  LocalLocationNodeTableCompanion toCompanion(bool nullToAbsent) {
    return LocalLocationNodeTableCompanion(
      id: Value(id),
      osmId:
          osmId == null && nullToAbsent ? const Value.absent() : Value(osmId),
      name: Value(name),
      adminLevel: Value(adminLevel),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      colorHex: colorHex == null && nullToAbsent
          ? const Value.absent()
          : Value(colorHex),
      geometryJson: geometryJson == null && nullToAbsent
          ? const Value.absent()
          : Value(geometryJson),
      createdAt: Value(createdAt),
    );
  }

  factory LocalLocationNode.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalLocationNode(
      id: serializer.fromJson<String>(json['id']),
      osmId: serializer.fromJson<int?>(json['osmId']),
      name: serializer.fromJson<String>(json['name']),
      adminLevel: serializer.fromJson<String>(json['adminLevel']),
      parentId: serializer.fromJson<String?>(json['parentId']),
      colorHex: serializer.fromJson<String?>(json['colorHex']),
      geometryJson: serializer.fromJson<String?>(json['geometryJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'osmId': serializer.toJson<int?>(osmId),
      'name': serializer.toJson<String>(name),
      'adminLevel': serializer.toJson<String>(adminLevel),
      'parentId': serializer.toJson<String?>(parentId),
      'colorHex': serializer.toJson<String?>(colorHex),
      'geometryJson': serializer.toJson<String?>(geometryJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  LocalLocationNode copyWith(
          {String? id,
          Value<int?> osmId = const Value.absent(),
          String? name,
          String? adminLevel,
          Value<String?> parentId = const Value.absent(),
          Value<String?> colorHex = const Value.absent(),
          Value<String?> geometryJson = const Value.absent(),
          DateTime? createdAt}) =>
      LocalLocationNode(
        id: id ?? this.id,
        osmId: osmId.present ? osmId.value : this.osmId,
        name: name ?? this.name,
        adminLevel: adminLevel ?? this.adminLevel,
        parentId: parentId.present ? parentId.value : this.parentId,
        colorHex: colorHex.present ? colorHex.value : this.colorHex,
        geometryJson:
            geometryJson.present ? geometryJson.value : this.geometryJson,
        createdAt: createdAt ?? this.createdAt,
      );
  LocalLocationNode copyWithCompanion(LocalLocationNodeTableCompanion data) {
    return LocalLocationNode(
      id: data.id.present ? data.id.value : this.id,
      osmId: data.osmId.present ? data.osmId.value : this.osmId,
      name: data.name.present ? data.name.value : this.name,
      adminLevel:
          data.adminLevel.present ? data.adminLevel.value : this.adminLevel,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      colorHex: data.colorHex.present ? data.colorHex.value : this.colorHex,
      geometryJson: data.geometryJson.present
          ? data.geometryJson.value
          : this.geometryJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalLocationNode(')
          ..write('id: $id, ')
          ..write('osmId: $osmId, ')
          ..write('name: $name, ')
          ..write('adminLevel: $adminLevel, ')
          ..write('parentId: $parentId, ')
          ..write('colorHex: $colorHex, ')
          ..write('geometryJson: $geometryJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, osmId, name, adminLevel, parentId, colorHex, geometryJson, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalLocationNode &&
          other.id == this.id &&
          other.osmId == this.osmId &&
          other.name == this.name &&
          other.adminLevel == this.adminLevel &&
          other.parentId == this.parentId &&
          other.colorHex == this.colorHex &&
          other.geometryJson == this.geometryJson &&
          other.createdAt == this.createdAt);
}

class LocalLocationNodeTableCompanion
    extends UpdateCompanion<LocalLocationNode> {
  final Value<String> id;
  final Value<int?> osmId;
  final Value<String> name;
  final Value<String> adminLevel;
  final Value<String?> parentId;
  final Value<String?> colorHex;
  final Value<String?> geometryJson;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const LocalLocationNodeTableCompanion({
    this.id = const Value.absent(),
    this.osmId = const Value.absent(),
    this.name = const Value.absent(),
    this.adminLevel = const Value.absent(),
    this.parentId = const Value.absent(),
    this.colorHex = const Value.absent(),
    this.geometryJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalLocationNodeTableCompanion.insert({
    required String id,
    this.osmId = const Value.absent(),
    required String name,
    required String adminLevel,
    this.parentId = const Value.absent(),
    this.colorHex = const Value.absent(),
    this.geometryJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        adminLevel = Value(adminLevel);
  static Insertable<LocalLocationNode> custom({
    Expression<String>? id,
    Expression<int>? osmId,
    Expression<String>? name,
    Expression<String>? adminLevel,
    Expression<String>? parentId,
    Expression<String>? colorHex,
    Expression<String>? geometryJson,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (osmId != null) 'osm_id': osmId,
      if (name != null) 'name': name,
      if (adminLevel != null) 'admin_level': adminLevel,
      if (parentId != null) 'parent_id': parentId,
      if (colorHex != null) 'color_hex': colorHex,
      if (geometryJson != null) 'geometry_json': geometryJson,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalLocationNodeTableCompanion copyWith(
      {Value<String>? id,
      Value<int?>? osmId,
      Value<String>? name,
      Value<String>? adminLevel,
      Value<String?>? parentId,
      Value<String?>? colorHex,
      Value<String?>? geometryJson,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return LocalLocationNodeTableCompanion(
      id: id ?? this.id,
      osmId: osmId ?? this.osmId,
      name: name ?? this.name,
      adminLevel: adminLevel ?? this.adminLevel,
      parentId: parentId ?? this.parentId,
      colorHex: colorHex ?? this.colorHex,
      geometryJson: geometryJson ?? this.geometryJson,
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
    if (osmId.present) {
      map['osm_id'] = Variable<int>(osmId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (adminLevel.present) {
      map['admin_level'] = Variable<String>(adminLevel.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (colorHex.present) {
      map['color_hex'] = Variable<String>(colorHex.value);
    }
    if (geometryJson.present) {
      map['geometry_json'] = Variable<String>(geometryJson.value);
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
    return (StringBuffer('LocalLocationNodeTableCompanion(')
          ..write('id: $id, ')
          ..write('osmId: $osmId, ')
          ..write('name: $name, ')
          ..write('adminLevel: $adminLevel, ')
          ..write('parentId: $parentId, ')
          ..write('colorHex: $colorHex, ')
          ..write('geometryJson: $geometryJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalAppEventsTableTable extends LocalAppEventsTable
    with TableInfo<$LocalAppEventsTableTable, LocalAppEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalAppEventsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sessionIdMeta =
      const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
      'session_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _eventMeta = const VerificationMeta('event');
  @override
  late final GeneratedColumn<String> event = GeneratedColumn<String>(
      'event', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _dataJsonMeta =
      const VerificationMeta('dataJson');
  @override
  late final GeneratedColumn<String> dataJson = GeneratedColumn<String>(
      'data_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('{}'));
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
      [id, sessionId, userId, category, event, dataJson, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_app_events_table';
  @override
  VerificationContext validateIntegrity(Insertable<LocalAppEvent> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(_sessionIdMeta,
          sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta));
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('event')) {
      context.handle(
          _eventMeta, event.isAcceptableOrUnknown(data['event']!, _eventMeta));
    } else if (isInserting) {
      context.missing(_eventMeta);
    }
    if (data.containsKey('data_json')) {
      context.handle(_dataJsonMeta,
          dataJson.isAcceptableOrUnknown(data['data_json']!, _dataJsonMeta));
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
  LocalAppEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalAppEvent(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      sessionId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}session_id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id']),
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category'])!,
      event: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}event'])!,
      dataJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}data_json'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $LocalAppEventsTableTable createAlias(String alias) {
    return $LocalAppEventsTableTable(attachedDatabase, alias);
  }
}

class LocalAppEvent extends DataClass implements Insertable<LocalAppEvent> {
  /// UUID v4.
  final String id;

  /// Session UUID (one per app launch).
  final String sessionId;

  /// Supabase user ID (nullable — events fire before auth).
  final String? userId;

  /// Event category: event, log, js, ui.
  final String category;

  /// Event name (e.g. 'cell_visited', 'session_started').
  final String event;

  /// JSON-encoded event payload.
  final String dataJson;

  /// When the event occurred (UTC).
  final DateTime createdAt;
  const LocalAppEvent(
      {required this.id,
      required this.sessionId,
      this.userId,
      required this.category,
      required this.event,
      required this.dataJson,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
    map['category'] = Variable<String>(category);
    map['event'] = Variable<String>(event);
    map['data_json'] = Variable<String>(dataJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  LocalAppEventsTableCompanion toCompanion(bool nullToAbsent) {
    return LocalAppEventsTableCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      userId:
          userId == null && nullToAbsent ? const Value.absent() : Value(userId),
      category: Value(category),
      event: Value(event),
      dataJson: Value(dataJson),
      createdAt: Value(createdAt),
    );
  }

  factory LocalAppEvent.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalAppEvent(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      userId: serializer.fromJson<String?>(json['userId']),
      category: serializer.fromJson<String>(json['category']),
      event: serializer.fromJson<String>(json['event']),
      dataJson: serializer.fromJson<String>(json['dataJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'userId': serializer.toJson<String?>(userId),
      'category': serializer.toJson<String>(category),
      'event': serializer.toJson<String>(event),
      'dataJson': serializer.toJson<String>(dataJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  LocalAppEvent copyWith(
          {String? id,
          String? sessionId,
          Value<String?> userId = const Value.absent(),
          String? category,
          String? event,
          String? dataJson,
          DateTime? createdAt}) =>
      LocalAppEvent(
        id: id ?? this.id,
        sessionId: sessionId ?? this.sessionId,
        userId: userId.present ? userId.value : this.userId,
        category: category ?? this.category,
        event: event ?? this.event,
        dataJson: dataJson ?? this.dataJson,
        createdAt: createdAt ?? this.createdAt,
      );
  LocalAppEvent copyWithCompanion(LocalAppEventsTableCompanion data) {
    return LocalAppEvent(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      userId: data.userId.present ? data.userId.value : this.userId,
      category: data.category.present ? data.category.value : this.category,
      event: data.event.present ? data.event.value : this.event,
      dataJson: data.dataJson.present ? data.dataJson.value : this.dataJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalAppEvent(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('userId: $userId, ')
          ..write('category: $category, ')
          ..write('event: $event, ')
          ..write('dataJson: $dataJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, sessionId, userId, category, event, dataJson, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalAppEvent &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.userId == this.userId &&
          other.category == this.category &&
          other.event == this.event &&
          other.dataJson == this.dataJson &&
          other.createdAt == this.createdAt);
}

class LocalAppEventsTableCompanion extends UpdateCompanion<LocalAppEvent> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<String?> userId;
  final Value<String> category;
  final Value<String> event;
  final Value<String> dataJson;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const LocalAppEventsTableCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.userId = const Value.absent(),
    this.category = const Value.absent(),
    this.event = const Value.absent(),
    this.dataJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalAppEventsTableCompanion.insert({
    required String id,
    required String sessionId,
    this.userId = const Value.absent(),
    required String category,
    required String event,
    this.dataJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        sessionId = Value(sessionId),
        category = Value(category),
        event = Value(event);
  static Insertable<LocalAppEvent> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<String>? userId,
    Expression<String>? category,
    Expression<String>? event,
    Expression<String>? dataJson,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (userId != null) 'user_id': userId,
      if (category != null) 'category': category,
      if (event != null) 'event': event,
      if (dataJson != null) 'data_json': dataJson,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalAppEventsTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? sessionId,
      Value<String?>? userId,
      Value<String>? category,
      Value<String>? event,
      Value<String>? dataJson,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return LocalAppEventsTableCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      userId: userId ?? this.userId,
      category: category ?? this.category,
      event: event ?? this.event,
      dataJson: dataJson ?? this.dataJson,
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
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (event.present) {
      map['event'] = Variable<String>(event.value);
    }
    if (dataJson.present) {
      map['data_json'] = Variable<String>(dataJson.value);
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
    return (StringBuffer('LocalAppEventsTableCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('userId: $userId, ')
          ..write('category: $category, ')
          ..write('event: $event, ')
          ..write('dataJson: $dataJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LocalCellProgressTableTable localCellProgressTable =
      $LocalCellProgressTableTable(this);
  late final $LocalItemInstanceTableTable localItemInstanceTable =
      $LocalItemInstanceTableTable(this);
  late final $LocalPlayerProfileTableTable localPlayerProfileTable =
      $LocalPlayerProfileTableTable(this);
  late final $LocalSpeciesTableTable localSpeciesTable =
      $LocalSpeciesTableTable(this);
  late final $LocalWriteQueueTableTable localWriteQueueTable =
      $LocalWriteQueueTableTable(this);
  late final $LocalCellPropertiesTableTable localCellPropertiesTable =
      $LocalCellPropertiesTableTable(this);
  late final $LocalLocationNodeTableTable localLocationNodeTable =
      $LocalLocationNodeTableTable(this);
  late final $LocalAppEventsTableTable localAppEventsTable =
      $LocalAppEventsTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        localCellProgressTable,
        localItemInstanceTable,
        localPlayerProfileTable,
        localSpeciesTable,
        localWriteQueueTable,
        localCellPropertiesTable,
        localLocationNodeTable,
        localAppEventsTable
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
typedef $$LocalItemInstanceTableTableCreateCompanionBuilder
    = LocalItemInstanceTableCompanion Function({
  required String id,
  required String userId,
  required String definitionId,
  Value<String> affixes,
  Value<String?> parentAId,
  Value<String?> parentBId,
  required DateTime acquiredAt,
  Value<String?> acquiredInCellId,
  Value<String?> dailySeed,
  Value<String> status,
  Value<String> badgesJson,
  Value<String> displayName,
  Value<String?> scientificName,
  Value<String> categoryName,
  Value<String?> rarityName,
  Value<String> habitatsJson,
  Value<String> continentsJson,
  Value<String?> taxonomicClass,
  Value<String?> iconUrl,
  Value<String?> artUrl,
  Value<String?> animalClassName,
  Value<String?> animalClassNameEnrichver,
  Value<String?> foodPreferenceName,
  Value<String?> foodPreferenceNameEnrichver,
  Value<String?> climateName,
  Value<String?> climateNameEnrichver,
  Value<int?> brawn,
  Value<String?> brawnEnrichver,
  Value<int?> wit,
  Value<String?> witEnrichver,
  Value<int?> speed,
  Value<String?> speedEnrichver,
  Value<String?> sizeName,
  Value<String?> sizeNameEnrichver,
  Value<String?> iconUrlEnrichver,
  Value<String?> artUrlEnrichver,
  Value<String?> cellHabitatName,
  Value<String?> cellHabitatNameEnrichver,
  Value<String?> cellClimateName,
  Value<String?> cellClimateNameEnrichver,
  Value<String?> cellContinentName,
  Value<String?> cellContinentNameEnrichver,
  Value<String?> locationDistrict,
  Value<String?> locationDistrictEnrichver,
  Value<String?> locationCity,
  Value<String?> locationCityEnrichver,
  Value<String?> locationState,
  Value<String?> locationStateEnrichver,
  Value<String?> locationCountry,
  Value<String?> locationCountryEnrichver,
  Value<String?> locationCountryCode,
  Value<String?> locationCountryCodeEnrichver,
  Value<int> rowid,
});
typedef $$LocalItemInstanceTableTableUpdateCompanionBuilder
    = LocalItemInstanceTableCompanion Function({
  Value<String> id,
  Value<String> userId,
  Value<String> definitionId,
  Value<String> affixes,
  Value<String?> parentAId,
  Value<String?> parentBId,
  Value<DateTime> acquiredAt,
  Value<String?> acquiredInCellId,
  Value<String?> dailySeed,
  Value<String> status,
  Value<String> badgesJson,
  Value<String> displayName,
  Value<String?> scientificName,
  Value<String> categoryName,
  Value<String?> rarityName,
  Value<String> habitatsJson,
  Value<String> continentsJson,
  Value<String?> taxonomicClass,
  Value<String?> iconUrl,
  Value<String?> artUrl,
  Value<String?> animalClassName,
  Value<String?> animalClassNameEnrichver,
  Value<String?> foodPreferenceName,
  Value<String?> foodPreferenceNameEnrichver,
  Value<String?> climateName,
  Value<String?> climateNameEnrichver,
  Value<int?> brawn,
  Value<String?> brawnEnrichver,
  Value<int?> wit,
  Value<String?> witEnrichver,
  Value<int?> speed,
  Value<String?> speedEnrichver,
  Value<String?> sizeName,
  Value<String?> sizeNameEnrichver,
  Value<String?> iconUrlEnrichver,
  Value<String?> artUrlEnrichver,
  Value<String?> cellHabitatName,
  Value<String?> cellHabitatNameEnrichver,
  Value<String?> cellClimateName,
  Value<String?> cellClimateNameEnrichver,
  Value<String?> cellContinentName,
  Value<String?> cellContinentNameEnrichver,
  Value<String?> locationDistrict,
  Value<String?> locationDistrictEnrichver,
  Value<String?> locationCity,
  Value<String?> locationCityEnrichver,
  Value<String?> locationState,
  Value<String?> locationStateEnrichver,
  Value<String?> locationCountry,
  Value<String?> locationCountryEnrichver,
  Value<String?> locationCountryCode,
  Value<String?> locationCountryCodeEnrichver,
  Value<int> rowid,
});

class $$LocalItemInstanceTableTableFilterComposer
    extends Composer<_$AppDatabase, $LocalItemInstanceTableTable> {
  $$LocalItemInstanceTableTableFilterComposer({
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

  ColumnFilters<String> get affixes => $composableBuilder(
      column: $table.affixes, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get parentAId => $composableBuilder(
      column: $table.parentAId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get parentBId => $composableBuilder(
      column: $table.parentBId, builder: (column) => ColumnFilters(column));

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

  ColumnFilters<String> get iconUrl => $composableBuilder(
      column: $table.iconUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get artUrl => $composableBuilder(
      column: $table.artUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get animalClassName => $composableBuilder(
      column: $table.animalClassName,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get animalClassNameEnrichver => $composableBuilder(
      column: $table.animalClassNameEnrichver,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get foodPreferenceName => $composableBuilder(
      column: $table.foodPreferenceName,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get foodPreferenceNameEnrichver => $composableBuilder(
      column: $table.foodPreferenceNameEnrichver,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get climateName => $composableBuilder(
      column: $table.climateName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get climateNameEnrichver => $composableBuilder(
      column: $table.climateNameEnrichver,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get brawn => $composableBuilder(
      column: $table.brawn, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get brawnEnrichver => $composableBuilder(
      column: $table.brawnEnrichver,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get wit => $composableBuilder(
      column: $table.wit, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get witEnrichver => $composableBuilder(
      column: $table.witEnrichver, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get speed => $composableBuilder(
      column: $table.speed, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get speedEnrichver => $composableBuilder(
      column: $table.speedEnrichver,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sizeName => $composableBuilder(
      column: $table.sizeName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sizeNameEnrichver => $composableBuilder(
      column: $table.sizeNameEnrichver,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get iconUrlEnrichver => $composableBuilder(
      column: $table.iconUrlEnrichver,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get artUrlEnrichver => $composableBuilder(
      column: $table.artUrlEnrichver,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get cellHabitatName => $composableBuilder(
      column: $table.cellHabitatName,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get cellHabitatNameEnrichver => $composableBuilder(
      column: $table.cellHabitatNameEnrichver,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get cellClimateName => $composableBuilder(
      column: $table.cellClimateName,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get cellClimateNameEnrichver => $composableBuilder(
      column: $table.cellClimateNameEnrichver,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get cellContinentName => $composableBuilder(
      column: $table.cellContinentName,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get cellContinentNameEnrichver => $composableBuilder(
      column: $table.cellContinentNameEnrichver,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get locationDistrict => $composableBuilder(
      column: $table.locationDistrict,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get locationDistrictEnrichver => $composableBuilder(
      column: $table.locationDistrictEnrichver,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get locationCity => $composableBuilder(
      column: $table.locationCity, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get locationCityEnrichver => $composableBuilder(
      column: $table.locationCityEnrichver,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get locationState => $composableBuilder(
      column: $table.locationState, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get locationStateEnrichver => $composableBuilder(
      column: $table.locationStateEnrichver,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get locationCountry => $composableBuilder(
      column: $table.locationCountry,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get locationCountryEnrichver => $composableBuilder(
      column: $table.locationCountryEnrichver,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get locationCountryCode => $composableBuilder(
      column: $table.locationCountryCode,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get locationCountryCodeEnrichver => $composableBuilder(
      column: $table.locationCountryCodeEnrichver,
      builder: (column) => ColumnFilters(column));
}

class $$LocalItemInstanceTableTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalItemInstanceTableTable> {
  $$LocalItemInstanceTableTableOrderingComposer({
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

  ColumnOrderings<String> get affixes => $composableBuilder(
      column: $table.affixes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get parentAId => $composableBuilder(
      column: $table.parentAId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get parentBId => $composableBuilder(
      column: $table.parentBId, builder: (column) => ColumnOrderings(column));

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

  ColumnOrderings<String> get iconUrl => $composableBuilder(
      column: $table.iconUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get artUrl => $composableBuilder(
      column: $table.artUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get animalClassName => $composableBuilder(
      column: $table.animalClassName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get animalClassNameEnrichver => $composableBuilder(
      column: $table.animalClassNameEnrichver,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get foodPreferenceName => $composableBuilder(
      column: $table.foodPreferenceName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get foodPreferenceNameEnrichver => $composableBuilder(
      column: $table.foodPreferenceNameEnrichver,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get climateName => $composableBuilder(
      column: $table.climateName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get climateNameEnrichver => $composableBuilder(
      column: $table.climateNameEnrichver,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get brawn => $composableBuilder(
      column: $table.brawn, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get brawnEnrichver => $composableBuilder(
      column: $table.brawnEnrichver,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get wit => $composableBuilder(
      column: $table.wit, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get witEnrichver => $composableBuilder(
      column: $table.witEnrichver,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get speed => $composableBuilder(
      column: $table.speed, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get speedEnrichver => $composableBuilder(
      column: $table.speedEnrichver,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sizeName => $composableBuilder(
      column: $table.sizeName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sizeNameEnrichver => $composableBuilder(
      column: $table.sizeNameEnrichver,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get iconUrlEnrichver => $composableBuilder(
      column: $table.iconUrlEnrichver,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get artUrlEnrichver => $composableBuilder(
      column: $table.artUrlEnrichver,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get cellHabitatName => $composableBuilder(
      column: $table.cellHabitatName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get cellHabitatNameEnrichver => $composableBuilder(
      column: $table.cellHabitatNameEnrichver,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get cellClimateName => $composableBuilder(
      column: $table.cellClimateName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get cellClimateNameEnrichver => $composableBuilder(
      column: $table.cellClimateNameEnrichver,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get cellContinentName => $composableBuilder(
      column: $table.cellContinentName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get cellContinentNameEnrichver => $composableBuilder(
      column: $table.cellContinentNameEnrichver,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get locationDistrict => $composableBuilder(
      column: $table.locationDistrict,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get locationDistrictEnrichver => $composableBuilder(
      column: $table.locationDistrictEnrichver,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get locationCity => $composableBuilder(
      column: $table.locationCity,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get locationCityEnrichver => $composableBuilder(
      column: $table.locationCityEnrichver,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get locationState => $composableBuilder(
      column: $table.locationState,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get locationStateEnrichver => $composableBuilder(
      column: $table.locationStateEnrichver,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get locationCountry => $composableBuilder(
      column: $table.locationCountry,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get locationCountryEnrichver => $composableBuilder(
      column: $table.locationCountryEnrichver,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get locationCountryCode => $composableBuilder(
      column: $table.locationCountryCode,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get locationCountryCodeEnrichver =>
      $composableBuilder(
          column: $table.locationCountryCodeEnrichver,
          builder: (column) => ColumnOrderings(column));
}

class $$LocalItemInstanceTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalItemInstanceTableTable> {
  $$LocalItemInstanceTableTableAnnotationComposer({
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

  GeneratedColumn<String> get affixes =>
      $composableBuilder(column: $table.affixes, builder: (column) => column);

  GeneratedColumn<String> get parentAId =>
      $composableBuilder(column: $table.parentAId, builder: (column) => column);

  GeneratedColumn<String> get parentBId =>
      $composableBuilder(column: $table.parentBId, builder: (column) => column);

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

  GeneratedColumn<String> get iconUrl =>
      $composableBuilder(column: $table.iconUrl, builder: (column) => column);

  GeneratedColumn<String> get artUrl =>
      $composableBuilder(column: $table.artUrl, builder: (column) => column);

  GeneratedColumn<String> get animalClassName => $composableBuilder(
      column: $table.animalClassName, builder: (column) => column);

  GeneratedColumn<String> get animalClassNameEnrichver => $composableBuilder(
      column: $table.animalClassNameEnrichver, builder: (column) => column);

  GeneratedColumn<String> get foodPreferenceName => $composableBuilder(
      column: $table.foodPreferenceName, builder: (column) => column);

  GeneratedColumn<String> get foodPreferenceNameEnrichver => $composableBuilder(
      column: $table.foodPreferenceNameEnrichver, builder: (column) => column);

  GeneratedColumn<String> get climateName => $composableBuilder(
      column: $table.climateName, builder: (column) => column);

  GeneratedColumn<String> get climateNameEnrichver => $composableBuilder(
      column: $table.climateNameEnrichver, builder: (column) => column);

  GeneratedColumn<int> get brawn =>
      $composableBuilder(column: $table.brawn, builder: (column) => column);

  GeneratedColumn<String> get brawnEnrichver => $composableBuilder(
      column: $table.brawnEnrichver, builder: (column) => column);

  GeneratedColumn<int> get wit =>
      $composableBuilder(column: $table.wit, builder: (column) => column);

  GeneratedColumn<String> get witEnrichver => $composableBuilder(
      column: $table.witEnrichver, builder: (column) => column);

  GeneratedColumn<int> get speed =>
      $composableBuilder(column: $table.speed, builder: (column) => column);

  GeneratedColumn<String> get speedEnrichver => $composableBuilder(
      column: $table.speedEnrichver, builder: (column) => column);

  GeneratedColumn<String> get sizeName =>
      $composableBuilder(column: $table.sizeName, builder: (column) => column);

  GeneratedColumn<String> get sizeNameEnrichver => $composableBuilder(
      column: $table.sizeNameEnrichver, builder: (column) => column);

  GeneratedColumn<String> get iconUrlEnrichver => $composableBuilder(
      column: $table.iconUrlEnrichver, builder: (column) => column);

  GeneratedColumn<String> get artUrlEnrichver => $composableBuilder(
      column: $table.artUrlEnrichver, builder: (column) => column);

  GeneratedColumn<String> get cellHabitatName => $composableBuilder(
      column: $table.cellHabitatName, builder: (column) => column);

  GeneratedColumn<String> get cellHabitatNameEnrichver => $composableBuilder(
      column: $table.cellHabitatNameEnrichver, builder: (column) => column);

  GeneratedColumn<String> get cellClimateName => $composableBuilder(
      column: $table.cellClimateName, builder: (column) => column);

  GeneratedColumn<String> get cellClimateNameEnrichver => $composableBuilder(
      column: $table.cellClimateNameEnrichver, builder: (column) => column);

  GeneratedColumn<String> get cellContinentName => $composableBuilder(
      column: $table.cellContinentName, builder: (column) => column);

  GeneratedColumn<String> get cellContinentNameEnrichver => $composableBuilder(
      column: $table.cellContinentNameEnrichver, builder: (column) => column);

  GeneratedColumn<String> get locationDistrict => $composableBuilder(
      column: $table.locationDistrict, builder: (column) => column);

  GeneratedColumn<String> get locationDistrictEnrichver => $composableBuilder(
      column: $table.locationDistrictEnrichver, builder: (column) => column);

  GeneratedColumn<String> get locationCity => $composableBuilder(
      column: $table.locationCity, builder: (column) => column);

  GeneratedColumn<String> get locationCityEnrichver => $composableBuilder(
      column: $table.locationCityEnrichver, builder: (column) => column);

  GeneratedColumn<String> get locationState => $composableBuilder(
      column: $table.locationState, builder: (column) => column);

  GeneratedColumn<String> get locationStateEnrichver => $composableBuilder(
      column: $table.locationStateEnrichver, builder: (column) => column);

  GeneratedColumn<String> get locationCountry => $composableBuilder(
      column: $table.locationCountry, builder: (column) => column);

  GeneratedColumn<String> get locationCountryEnrichver => $composableBuilder(
      column: $table.locationCountryEnrichver, builder: (column) => column);

  GeneratedColumn<String> get locationCountryCode => $composableBuilder(
      column: $table.locationCountryCode, builder: (column) => column);

  GeneratedColumn<String> get locationCountryCodeEnrichver =>
      $composableBuilder(
          column: $table.locationCountryCodeEnrichver,
          builder: (column) => column);
}

class $$LocalItemInstanceTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LocalItemInstanceTableTable,
    LocalItemInstance,
    $$LocalItemInstanceTableTableFilterComposer,
    $$LocalItemInstanceTableTableOrderingComposer,
    $$LocalItemInstanceTableTableAnnotationComposer,
    $$LocalItemInstanceTableTableCreateCompanionBuilder,
    $$LocalItemInstanceTableTableUpdateCompanionBuilder,
    (
      LocalItemInstance,
      BaseReferences<_$AppDatabase, $LocalItemInstanceTableTable,
          LocalItemInstance>
    ),
    LocalItemInstance,
    PrefetchHooks Function()> {
  $$LocalItemInstanceTableTableTableManager(
      _$AppDatabase db, $LocalItemInstanceTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalItemInstanceTableTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalItemInstanceTableTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalItemInstanceTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<String> definitionId = const Value.absent(),
            Value<String> affixes = const Value.absent(),
            Value<String?> parentAId = const Value.absent(),
            Value<String?> parentBId = const Value.absent(),
            Value<DateTime> acquiredAt = const Value.absent(),
            Value<String?> acquiredInCellId = const Value.absent(),
            Value<String?> dailySeed = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String> badgesJson = const Value.absent(),
            Value<String> displayName = const Value.absent(),
            Value<String?> scientificName = const Value.absent(),
            Value<String> categoryName = const Value.absent(),
            Value<String?> rarityName = const Value.absent(),
            Value<String> habitatsJson = const Value.absent(),
            Value<String> continentsJson = const Value.absent(),
            Value<String?> taxonomicClass = const Value.absent(),
            Value<String?> iconUrl = const Value.absent(),
            Value<String?> artUrl = const Value.absent(),
            Value<String?> animalClassName = const Value.absent(),
            Value<String?> animalClassNameEnrichver = const Value.absent(),
            Value<String?> foodPreferenceName = const Value.absent(),
            Value<String?> foodPreferenceNameEnrichver = const Value.absent(),
            Value<String?> climateName = const Value.absent(),
            Value<String?> climateNameEnrichver = const Value.absent(),
            Value<int?> brawn = const Value.absent(),
            Value<String?> brawnEnrichver = const Value.absent(),
            Value<int?> wit = const Value.absent(),
            Value<String?> witEnrichver = const Value.absent(),
            Value<int?> speed = const Value.absent(),
            Value<String?> speedEnrichver = const Value.absent(),
            Value<String?> sizeName = const Value.absent(),
            Value<String?> sizeNameEnrichver = const Value.absent(),
            Value<String?> iconUrlEnrichver = const Value.absent(),
            Value<String?> artUrlEnrichver = const Value.absent(),
            Value<String?> cellHabitatName = const Value.absent(),
            Value<String?> cellHabitatNameEnrichver = const Value.absent(),
            Value<String?> cellClimateName = const Value.absent(),
            Value<String?> cellClimateNameEnrichver = const Value.absent(),
            Value<String?> cellContinentName = const Value.absent(),
            Value<String?> cellContinentNameEnrichver = const Value.absent(),
            Value<String?> locationDistrict = const Value.absent(),
            Value<String?> locationDistrictEnrichver = const Value.absent(),
            Value<String?> locationCity = const Value.absent(),
            Value<String?> locationCityEnrichver = const Value.absent(),
            Value<String?> locationState = const Value.absent(),
            Value<String?> locationStateEnrichver = const Value.absent(),
            Value<String?> locationCountry = const Value.absent(),
            Value<String?> locationCountryEnrichver = const Value.absent(),
            Value<String?> locationCountryCode = const Value.absent(),
            Value<String?> locationCountryCodeEnrichver = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalItemInstanceTableCompanion(
            id: id,
            userId: userId,
            definitionId: definitionId,
            affixes: affixes,
            parentAId: parentAId,
            parentBId: parentBId,
            acquiredAt: acquiredAt,
            acquiredInCellId: acquiredInCellId,
            dailySeed: dailySeed,
            status: status,
            badgesJson: badgesJson,
            displayName: displayName,
            scientificName: scientificName,
            categoryName: categoryName,
            rarityName: rarityName,
            habitatsJson: habitatsJson,
            continentsJson: continentsJson,
            taxonomicClass: taxonomicClass,
            iconUrl: iconUrl,
            artUrl: artUrl,
            animalClassName: animalClassName,
            animalClassNameEnrichver: animalClassNameEnrichver,
            foodPreferenceName: foodPreferenceName,
            foodPreferenceNameEnrichver: foodPreferenceNameEnrichver,
            climateName: climateName,
            climateNameEnrichver: climateNameEnrichver,
            brawn: brawn,
            brawnEnrichver: brawnEnrichver,
            wit: wit,
            witEnrichver: witEnrichver,
            speed: speed,
            speedEnrichver: speedEnrichver,
            sizeName: sizeName,
            sizeNameEnrichver: sizeNameEnrichver,
            iconUrlEnrichver: iconUrlEnrichver,
            artUrlEnrichver: artUrlEnrichver,
            cellHabitatName: cellHabitatName,
            cellHabitatNameEnrichver: cellHabitatNameEnrichver,
            cellClimateName: cellClimateName,
            cellClimateNameEnrichver: cellClimateNameEnrichver,
            cellContinentName: cellContinentName,
            cellContinentNameEnrichver: cellContinentNameEnrichver,
            locationDistrict: locationDistrict,
            locationDistrictEnrichver: locationDistrictEnrichver,
            locationCity: locationCity,
            locationCityEnrichver: locationCityEnrichver,
            locationState: locationState,
            locationStateEnrichver: locationStateEnrichver,
            locationCountry: locationCountry,
            locationCountryEnrichver: locationCountryEnrichver,
            locationCountryCode: locationCountryCode,
            locationCountryCodeEnrichver: locationCountryCodeEnrichver,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String userId,
            required String definitionId,
            Value<String> affixes = const Value.absent(),
            Value<String?> parentAId = const Value.absent(),
            Value<String?> parentBId = const Value.absent(),
            required DateTime acquiredAt,
            Value<String?> acquiredInCellId = const Value.absent(),
            Value<String?> dailySeed = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String> badgesJson = const Value.absent(),
            Value<String> displayName = const Value.absent(),
            Value<String?> scientificName = const Value.absent(),
            Value<String> categoryName = const Value.absent(),
            Value<String?> rarityName = const Value.absent(),
            Value<String> habitatsJson = const Value.absent(),
            Value<String> continentsJson = const Value.absent(),
            Value<String?> taxonomicClass = const Value.absent(),
            Value<String?> iconUrl = const Value.absent(),
            Value<String?> artUrl = const Value.absent(),
            Value<String?> animalClassName = const Value.absent(),
            Value<String?> animalClassNameEnrichver = const Value.absent(),
            Value<String?> foodPreferenceName = const Value.absent(),
            Value<String?> foodPreferenceNameEnrichver = const Value.absent(),
            Value<String?> climateName = const Value.absent(),
            Value<String?> climateNameEnrichver = const Value.absent(),
            Value<int?> brawn = const Value.absent(),
            Value<String?> brawnEnrichver = const Value.absent(),
            Value<int?> wit = const Value.absent(),
            Value<String?> witEnrichver = const Value.absent(),
            Value<int?> speed = const Value.absent(),
            Value<String?> speedEnrichver = const Value.absent(),
            Value<String?> sizeName = const Value.absent(),
            Value<String?> sizeNameEnrichver = const Value.absent(),
            Value<String?> iconUrlEnrichver = const Value.absent(),
            Value<String?> artUrlEnrichver = const Value.absent(),
            Value<String?> cellHabitatName = const Value.absent(),
            Value<String?> cellHabitatNameEnrichver = const Value.absent(),
            Value<String?> cellClimateName = const Value.absent(),
            Value<String?> cellClimateNameEnrichver = const Value.absent(),
            Value<String?> cellContinentName = const Value.absent(),
            Value<String?> cellContinentNameEnrichver = const Value.absent(),
            Value<String?> locationDistrict = const Value.absent(),
            Value<String?> locationDistrictEnrichver = const Value.absent(),
            Value<String?> locationCity = const Value.absent(),
            Value<String?> locationCityEnrichver = const Value.absent(),
            Value<String?> locationState = const Value.absent(),
            Value<String?> locationStateEnrichver = const Value.absent(),
            Value<String?> locationCountry = const Value.absent(),
            Value<String?> locationCountryEnrichver = const Value.absent(),
            Value<String?> locationCountryCode = const Value.absent(),
            Value<String?> locationCountryCodeEnrichver = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalItemInstanceTableCompanion.insert(
            id: id,
            userId: userId,
            definitionId: definitionId,
            affixes: affixes,
            parentAId: parentAId,
            parentBId: parentBId,
            acquiredAt: acquiredAt,
            acquiredInCellId: acquiredInCellId,
            dailySeed: dailySeed,
            status: status,
            badgesJson: badgesJson,
            displayName: displayName,
            scientificName: scientificName,
            categoryName: categoryName,
            rarityName: rarityName,
            habitatsJson: habitatsJson,
            continentsJson: continentsJson,
            taxonomicClass: taxonomicClass,
            iconUrl: iconUrl,
            artUrl: artUrl,
            animalClassName: animalClassName,
            animalClassNameEnrichver: animalClassNameEnrichver,
            foodPreferenceName: foodPreferenceName,
            foodPreferenceNameEnrichver: foodPreferenceNameEnrichver,
            climateName: climateName,
            climateNameEnrichver: climateNameEnrichver,
            brawn: brawn,
            brawnEnrichver: brawnEnrichver,
            wit: wit,
            witEnrichver: witEnrichver,
            speed: speed,
            speedEnrichver: speedEnrichver,
            sizeName: sizeName,
            sizeNameEnrichver: sizeNameEnrichver,
            iconUrlEnrichver: iconUrlEnrichver,
            artUrlEnrichver: artUrlEnrichver,
            cellHabitatName: cellHabitatName,
            cellHabitatNameEnrichver: cellHabitatNameEnrichver,
            cellClimateName: cellClimateName,
            cellClimateNameEnrichver: cellClimateNameEnrichver,
            cellContinentName: cellContinentName,
            cellContinentNameEnrichver: cellContinentNameEnrichver,
            locationDistrict: locationDistrict,
            locationDistrictEnrichver: locationDistrictEnrichver,
            locationCity: locationCity,
            locationCityEnrichver: locationCityEnrichver,
            locationState: locationState,
            locationStateEnrichver: locationStateEnrichver,
            locationCountry: locationCountry,
            locationCountryEnrichver: locationCountryEnrichver,
            locationCountryCode: locationCountryCode,
            locationCountryCodeEnrichver: locationCountryCodeEnrichver,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalItemInstanceTableTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $LocalItemInstanceTableTable,
        LocalItemInstance,
        $$LocalItemInstanceTableTableFilterComposer,
        $$LocalItemInstanceTableTableOrderingComposer,
        $$LocalItemInstanceTableTableAnnotationComposer,
        $$LocalItemInstanceTableTableCreateCompanionBuilder,
        $$LocalItemInstanceTableTableUpdateCompanionBuilder,
        (
          LocalItemInstance,
          BaseReferences<_$AppDatabase, $LocalItemInstanceTableTable,
              LocalItemInstance>
        ),
        LocalItemInstance,
        PrefetchHooks Function()>;
typedef $$LocalPlayerProfileTableTableCreateCompanionBuilder
    = LocalPlayerProfileTableCompanion Function({
  required String id,
  required String displayName,
  Value<int> currentStreak,
  Value<int> longestStreak,
  Value<double> totalDistanceKm,
  Value<String> currentSeason,
  Value<bool> hasCompletedOnboarding,
  Value<double?> lastLat,
  Value<double?> lastLon,
  Value<int> totalSteps,
  Value<int> lastKnownStepCount,
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
  Value<bool> hasCompletedOnboarding,
  Value<double?> lastLat,
  Value<double?> lastLon,
  Value<int> totalSteps,
  Value<int> lastKnownStepCount,
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

  ColumnFilters<bool> get hasCompletedOnboarding => $composableBuilder(
      column: $table.hasCompletedOnboarding,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get lastLat => $composableBuilder(
      column: $table.lastLat, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get lastLon => $composableBuilder(
      column: $table.lastLon, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get totalSteps => $composableBuilder(
      column: $table.totalSteps, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get lastKnownStepCount => $composableBuilder(
      column: $table.lastKnownStepCount,
      builder: (column) => ColumnFilters(column));

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

  ColumnOrderings<bool> get hasCompletedOnboarding => $composableBuilder(
      column: $table.hasCompletedOnboarding,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get lastLat => $composableBuilder(
      column: $table.lastLat, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get lastLon => $composableBuilder(
      column: $table.lastLon, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get totalSteps => $composableBuilder(
      column: $table.totalSteps, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get lastKnownStepCount => $composableBuilder(
      column: $table.lastKnownStepCount,
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

  GeneratedColumn<bool> get hasCompletedOnboarding => $composableBuilder(
      column: $table.hasCompletedOnboarding, builder: (column) => column);

  GeneratedColumn<double> get lastLat =>
      $composableBuilder(column: $table.lastLat, builder: (column) => column);

  GeneratedColumn<double> get lastLon =>
      $composableBuilder(column: $table.lastLon, builder: (column) => column);

  GeneratedColumn<int> get totalSteps => $composableBuilder(
      column: $table.totalSteps, builder: (column) => column);

  GeneratedColumn<int> get lastKnownStepCount => $composableBuilder(
      column: $table.lastKnownStepCount, builder: (column) => column);

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
            Value<bool> hasCompletedOnboarding = const Value.absent(),
            Value<double?> lastLat = const Value.absent(),
            Value<double?> lastLon = const Value.absent(),
            Value<int> totalSteps = const Value.absent(),
            Value<int> lastKnownStepCount = const Value.absent(),
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
            hasCompletedOnboarding: hasCompletedOnboarding,
            lastLat: lastLat,
            lastLon: lastLon,
            totalSteps: totalSteps,
            lastKnownStepCount: lastKnownStepCount,
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
            Value<bool> hasCompletedOnboarding = const Value.absent(),
            Value<double?> lastLat = const Value.absent(),
            Value<double?> lastLon = const Value.absent(),
            Value<int> totalSteps = const Value.absent(),
            Value<int> lastKnownStepCount = const Value.absent(),
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
            hasCompletedOnboarding: hasCompletedOnboarding,
            lastLat: lastLat,
            lastLon: lastLon,
            totalSteps: totalSteps,
            lastKnownStepCount: lastKnownStepCount,
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
typedef $$LocalSpeciesTableTableCreateCompanionBuilder
    = LocalSpeciesTableCompanion Function({
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
  Value<String?> iconPrompt,
  Value<String?> artPrompt,
  Value<DateTime?> enrichedAt,
  Value<String?> animalClassEnrichver,
  Value<String?> foodPreferenceEnrichver,
  Value<String?> climateEnrichver,
  Value<String?> brawnEnrichver,
  Value<String?> witEnrichver,
  Value<String?> speedEnrichver,
  Value<String?> sizeEnrichver,
  Value<String?> iconPromptEnrichver,
  Value<String?> artPromptEnrichver,
  Value<String?> iconUrlEnrichver,
  Value<String?> artUrlEnrichver,
  Value<int> rowid,
});
typedef $$LocalSpeciesTableTableUpdateCompanionBuilder
    = LocalSpeciesTableCompanion Function({
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
  Value<String?> iconPrompt,
  Value<String?> artPrompt,
  Value<DateTime?> enrichedAt,
  Value<String?> animalClassEnrichver,
  Value<String?> foodPreferenceEnrichver,
  Value<String?> climateEnrichver,
  Value<String?> brawnEnrichver,
  Value<String?> witEnrichver,
  Value<String?> speedEnrichver,
  Value<String?> sizeEnrichver,
  Value<String?> iconPromptEnrichver,
  Value<String?> artPromptEnrichver,
  Value<String?> iconUrlEnrichver,
  Value<String?> artUrlEnrichver,
  Value<int> rowid,
});

class $$LocalSpeciesTableTableFilterComposer
    extends Composer<_$AppDatabase, $LocalSpeciesTableTable> {
  $$LocalSpeciesTableTableFilterComposer({
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

  ColumnFilters<String> get iconPrompt => $composableBuilder(
      column: $table.iconPrompt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get artPrompt => $composableBuilder(
      column: $table.artPrompt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get enrichedAt => $composableBuilder(
      column: $table.enrichedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get animalClassEnrichver => $composableBuilder(
      column: $table.animalClassEnrichver,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get foodPreferenceEnrichver => $composableBuilder(
      column: $table.foodPreferenceEnrichver,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get climateEnrichver => $composableBuilder(
      column: $table.climateEnrichver,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get brawnEnrichver => $composableBuilder(
      column: $table.brawnEnrichver,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get witEnrichver => $composableBuilder(
      column: $table.witEnrichver, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get speedEnrichver => $composableBuilder(
      column: $table.speedEnrichver,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sizeEnrichver => $composableBuilder(
      column: $table.sizeEnrichver, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get iconPromptEnrichver => $composableBuilder(
      column: $table.iconPromptEnrichver,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get artPromptEnrichver => $composableBuilder(
      column: $table.artPromptEnrichver,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get iconUrlEnrichver => $composableBuilder(
      column: $table.iconUrlEnrichver,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get artUrlEnrichver => $composableBuilder(
      column: $table.artUrlEnrichver,
      builder: (column) => ColumnFilters(column));
}

class $$LocalSpeciesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalSpeciesTableTable> {
  $$LocalSpeciesTableTableOrderingComposer({
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

  ColumnOrderings<String> get iconPrompt => $composableBuilder(
      column: $table.iconPrompt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get artPrompt => $composableBuilder(
      column: $table.artPrompt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get enrichedAt => $composableBuilder(
      column: $table.enrichedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get animalClassEnrichver => $composableBuilder(
      column: $table.animalClassEnrichver,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get foodPreferenceEnrichver => $composableBuilder(
      column: $table.foodPreferenceEnrichver,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get climateEnrichver => $composableBuilder(
      column: $table.climateEnrichver,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get brawnEnrichver => $composableBuilder(
      column: $table.brawnEnrichver,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get witEnrichver => $composableBuilder(
      column: $table.witEnrichver,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get speedEnrichver => $composableBuilder(
      column: $table.speedEnrichver,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sizeEnrichver => $composableBuilder(
      column: $table.sizeEnrichver,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get iconPromptEnrichver => $composableBuilder(
      column: $table.iconPromptEnrichver,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get artPromptEnrichver => $composableBuilder(
      column: $table.artPromptEnrichver,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get iconUrlEnrichver => $composableBuilder(
      column: $table.iconUrlEnrichver,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get artUrlEnrichver => $composableBuilder(
      column: $table.artUrlEnrichver,
      builder: (column) => ColumnOrderings(column));
}

class $$LocalSpeciesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalSpeciesTableTable> {
  $$LocalSpeciesTableTableAnnotationComposer({
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

  GeneratedColumn<String> get iconPrompt => $composableBuilder(
      column: $table.iconPrompt, builder: (column) => column);

  GeneratedColumn<String> get artPrompt =>
      $composableBuilder(column: $table.artPrompt, builder: (column) => column);

  GeneratedColumn<DateTime> get enrichedAt => $composableBuilder(
      column: $table.enrichedAt, builder: (column) => column);

  GeneratedColumn<String> get animalClassEnrichver => $composableBuilder(
      column: $table.animalClassEnrichver, builder: (column) => column);

  GeneratedColumn<String> get foodPreferenceEnrichver => $composableBuilder(
      column: $table.foodPreferenceEnrichver, builder: (column) => column);

  GeneratedColumn<String> get climateEnrichver => $composableBuilder(
      column: $table.climateEnrichver, builder: (column) => column);

  GeneratedColumn<String> get brawnEnrichver => $composableBuilder(
      column: $table.brawnEnrichver, builder: (column) => column);

  GeneratedColumn<String> get witEnrichver => $composableBuilder(
      column: $table.witEnrichver, builder: (column) => column);

  GeneratedColumn<String> get speedEnrichver => $composableBuilder(
      column: $table.speedEnrichver, builder: (column) => column);

  GeneratedColumn<String> get sizeEnrichver => $composableBuilder(
      column: $table.sizeEnrichver, builder: (column) => column);

  GeneratedColumn<String> get iconPromptEnrichver => $composableBuilder(
      column: $table.iconPromptEnrichver, builder: (column) => column);

  GeneratedColumn<String> get artPromptEnrichver => $composableBuilder(
      column: $table.artPromptEnrichver, builder: (column) => column);

  GeneratedColumn<String> get iconUrlEnrichver => $composableBuilder(
      column: $table.iconUrlEnrichver, builder: (column) => column);

  GeneratedColumn<String> get artUrlEnrichver => $composableBuilder(
      column: $table.artUrlEnrichver, builder: (column) => column);
}

class $$LocalSpeciesTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LocalSpeciesTableTable,
    LocalSpecies,
    $$LocalSpeciesTableTableFilterComposer,
    $$LocalSpeciesTableTableOrderingComposer,
    $$LocalSpeciesTableTableAnnotationComposer,
    $$LocalSpeciesTableTableCreateCompanionBuilder,
    $$LocalSpeciesTableTableUpdateCompanionBuilder,
    (
      LocalSpecies,
      BaseReferences<_$AppDatabase, $LocalSpeciesTableTable, LocalSpecies>
    ),
    LocalSpecies,
    PrefetchHooks Function()> {
  $$LocalSpeciesTableTableTableManager(
      _$AppDatabase db, $LocalSpeciesTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalSpeciesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalSpeciesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalSpeciesTableTableAnnotationComposer(
                  $db: db, $table: table),
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
            Value<String?> iconPrompt = const Value.absent(),
            Value<String?> artPrompt = const Value.absent(),
            Value<DateTime?> enrichedAt = const Value.absent(),
            Value<String?> animalClassEnrichver = const Value.absent(),
            Value<String?> foodPreferenceEnrichver = const Value.absent(),
            Value<String?> climateEnrichver = const Value.absent(),
            Value<String?> brawnEnrichver = const Value.absent(),
            Value<String?> witEnrichver = const Value.absent(),
            Value<String?> speedEnrichver = const Value.absent(),
            Value<String?> sizeEnrichver = const Value.absent(),
            Value<String?> iconPromptEnrichver = const Value.absent(),
            Value<String?> artPromptEnrichver = const Value.absent(),
            Value<String?> iconUrlEnrichver = const Value.absent(),
            Value<String?> artUrlEnrichver = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalSpeciesTableCompanion(
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
            iconPrompt: iconPrompt,
            artPrompt: artPrompt,
            enrichedAt: enrichedAt,
            animalClassEnrichver: animalClassEnrichver,
            foodPreferenceEnrichver: foodPreferenceEnrichver,
            climateEnrichver: climateEnrichver,
            brawnEnrichver: brawnEnrichver,
            witEnrichver: witEnrichver,
            speedEnrichver: speedEnrichver,
            sizeEnrichver: sizeEnrichver,
            iconPromptEnrichver: iconPromptEnrichver,
            artPromptEnrichver: artPromptEnrichver,
            iconUrlEnrichver: iconUrlEnrichver,
            artUrlEnrichver: artUrlEnrichver,
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
            Value<String?> iconPrompt = const Value.absent(),
            Value<String?> artPrompt = const Value.absent(),
            Value<DateTime?> enrichedAt = const Value.absent(),
            Value<String?> animalClassEnrichver = const Value.absent(),
            Value<String?> foodPreferenceEnrichver = const Value.absent(),
            Value<String?> climateEnrichver = const Value.absent(),
            Value<String?> brawnEnrichver = const Value.absent(),
            Value<String?> witEnrichver = const Value.absent(),
            Value<String?> speedEnrichver = const Value.absent(),
            Value<String?> sizeEnrichver = const Value.absent(),
            Value<String?> iconPromptEnrichver = const Value.absent(),
            Value<String?> artPromptEnrichver = const Value.absent(),
            Value<String?> iconUrlEnrichver = const Value.absent(),
            Value<String?> artUrlEnrichver = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalSpeciesTableCompanion.insert(
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
            iconPrompt: iconPrompt,
            artPrompt: artPrompt,
            enrichedAt: enrichedAt,
            animalClassEnrichver: animalClassEnrichver,
            foodPreferenceEnrichver: foodPreferenceEnrichver,
            climateEnrichver: climateEnrichver,
            brawnEnrichver: brawnEnrichver,
            witEnrichver: witEnrichver,
            speedEnrichver: speedEnrichver,
            sizeEnrichver: sizeEnrichver,
            iconPromptEnrichver: iconPromptEnrichver,
            artPromptEnrichver: artPromptEnrichver,
            iconUrlEnrichver: iconUrlEnrichver,
            artUrlEnrichver: artUrlEnrichver,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalSpeciesTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $LocalSpeciesTableTable,
    LocalSpecies,
    $$LocalSpeciesTableTableFilterComposer,
    $$LocalSpeciesTableTableOrderingComposer,
    $$LocalSpeciesTableTableAnnotationComposer,
    $$LocalSpeciesTableTableCreateCompanionBuilder,
    $$LocalSpeciesTableTableUpdateCompanionBuilder,
    (
      LocalSpecies,
      BaseReferences<_$AppDatabase, $LocalSpeciesTableTable, LocalSpecies>
    ),
    LocalSpecies,
    PrefetchHooks Function()>;
typedef $$LocalWriteQueueTableTableCreateCompanionBuilder
    = LocalWriteQueueTableCompanion Function({
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
typedef $$LocalWriteQueueTableTableUpdateCompanionBuilder
    = LocalWriteQueueTableCompanion Function({
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

class $$LocalWriteQueueTableTableFilterComposer
    extends Composer<_$AppDatabase, $LocalWriteQueueTableTable> {
  $$LocalWriteQueueTableTableFilterComposer({
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

class $$LocalWriteQueueTableTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalWriteQueueTableTable> {
  $$LocalWriteQueueTableTableOrderingComposer({
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

class $$LocalWriteQueueTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalWriteQueueTableTable> {
  $$LocalWriteQueueTableTableAnnotationComposer({
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

class $$LocalWriteQueueTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LocalWriteQueueTableTable,
    LocalWriteQueueEntry,
    $$LocalWriteQueueTableTableFilterComposer,
    $$LocalWriteQueueTableTableOrderingComposer,
    $$LocalWriteQueueTableTableAnnotationComposer,
    $$LocalWriteQueueTableTableCreateCompanionBuilder,
    $$LocalWriteQueueTableTableUpdateCompanionBuilder,
    (
      LocalWriteQueueEntry,
      BaseReferences<_$AppDatabase, $LocalWriteQueueTableTable,
          LocalWriteQueueEntry>
    ),
    LocalWriteQueueEntry,
    PrefetchHooks Function()> {
  $$LocalWriteQueueTableTableTableManager(
      _$AppDatabase db, $LocalWriteQueueTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalWriteQueueTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalWriteQueueTableTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalWriteQueueTableTableAnnotationComposer(
                  $db: db, $table: table),
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
              LocalWriteQueueTableCompanion(
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
              LocalWriteQueueTableCompanion.insert(
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

typedef $$LocalWriteQueueTableTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $LocalWriteQueueTableTable,
        LocalWriteQueueEntry,
        $$LocalWriteQueueTableTableFilterComposer,
        $$LocalWriteQueueTableTableOrderingComposer,
        $$LocalWriteQueueTableTableAnnotationComposer,
        $$LocalWriteQueueTableTableCreateCompanionBuilder,
        $$LocalWriteQueueTableTableUpdateCompanionBuilder,
        (
          LocalWriteQueueEntry,
          BaseReferences<_$AppDatabase, $LocalWriteQueueTableTable,
              LocalWriteQueueEntry>
        ),
        LocalWriteQueueEntry,
        PrefetchHooks Function()>;
typedef $$LocalCellPropertiesTableTableCreateCompanionBuilder
    = LocalCellPropertiesTableCompanion Function({
  required String cellId,
  required String habitats,
  required String climate,
  required String continent,
  Value<String?> locationId,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$LocalCellPropertiesTableTableUpdateCompanionBuilder
    = LocalCellPropertiesTableCompanion Function({
  Value<String> cellId,
  Value<String> habitats,
  Value<String> climate,
  Value<String> continent,
  Value<String?> locationId,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$LocalCellPropertiesTableTableFilterComposer
    extends Composer<_$AppDatabase, $LocalCellPropertiesTableTable> {
  $$LocalCellPropertiesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get cellId => $composableBuilder(
      column: $table.cellId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get habitats => $composableBuilder(
      column: $table.habitats, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get climate => $composableBuilder(
      column: $table.climate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get continent => $composableBuilder(
      column: $table.continent, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get locationId => $composableBuilder(
      column: $table.locationId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$LocalCellPropertiesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalCellPropertiesTableTable> {
  $$LocalCellPropertiesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get cellId => $composableBuilder(
      column: $table.cellId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get habitats => $composableBuilder(
      column: $table.habitats, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get climate => $composableBuilder(
      column: $table.climate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get continent => $composableBuilder(
      column: $table.continent, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get locationId => $composableBuilder(
      column: $table.locationId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$LocalCellPropertiesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalCellPropertiesTableTable> {
  $$LocalCellPropertiesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get cellId =>
      $composableBuilder(column: $table.cellId, builder: (column) => column);

  GeneratedColumn<String> get habitats =>
      $composableBuilder(column: $table.habitats, builder: (column) => column);

  GeneratedColumn<String> get climate =>
      $composableBuilder(column: $table.climate, builder: (column) => column);

  GeneratedColumn<String> get continent =>
      $composableBuilder(column: $table.continent, builder: (column) => column);

  GeneratedColumn<String> get locationId => $composableBuilder(
      column: $table.locationId, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LocalCellPropertiesTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LocalCellPropertiesTableTable,
    LocalCellProperties,
    $$LocalCellPropertiesTableTableFilterComposer,
    $$LocalCellPropertiesTableTableOrderingComposer,
    $$LocalCellPropertiesTableTableAnnotationComposer,
    $$LocalCellPropertiesTableTableCreateCompanionBuilder,
    $$LocalCellPropertiesTableTableUpdateCompanionBuilder,
    (
      LocalCellProperties,
      BaseReferences<_$AppDatabase, $LocalCellPropertiesTableTable,
          LocalCellProperties>
    ),
    LocalCellProperties,
    PrefetchHooks Function()> {
  $$LocalCellPropertiesTableTableTableManager(
      _$AppDatabase db, $LocalCellPropertiesTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalCellPropertiesTableTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalCellPropertiesTableTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalCellPropertiesTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> cellId = const Value.absent(),
            Value<String> habitats = const Value.absent(),
            Value<String> climate = const Value.absent(),
            Value<String> continent = const Value.absent(),
            Value<String?> locationId = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalCellPropertiesTableCompanion(
            cellId: cellId,
            habitats: habitats,
            climate: climate,
            continent: continent,
            locationId: locationId,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String cellId,
            required String habitats,
            required String climate,
            required String continent,
            Value<String?> locationId = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalCellPropertiesTableCompanion.insert(
            cellId: cellId,
            habitats: habitats,
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

typedef $$LocalCellPropertiesTableTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $LocalCellPropertiesTableTable,
        LocalCellProperties,
        $$LocalCellPropertiesTableTableFilterComposer,
        $$LocalCellPropertiesTableTableOrderingComposer,
        $$LocalCellPropertiesTableTableAnnotationComposer,
        $$LocalCellPropertiesTableTableCreateCompanionBuilder,
        $$LocalCellPropertiesTableTableUpdateCompanionBuilder,
        (
          LocalCellProperties,
          BaseReferences<_$AppDatabase, $LocalCellPropertiesTableTable,
              LocalCellProperties>
        ),
        LocalCellProperties,
        PrefetchHooks Function()>;
typedef $$LocalLocationNodeTableTableCreateCompanionBuilder
    = LocalLocationNodeTableCompanion Function({
  required String id,
  Value<int?> osmId,
  required String name,
  required String adminLevel,
  Value<String?> parentId,
  Value<String?> colorHex,
  Value<String?> geometryJson,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$LocalLocationNodeTableTableUpdateCompanionBuilder
    = LocalLocationNodeTableCompanion Function({
  Value<String> id,
  Value<int?> osmId,
  Value<String> name,
  Value<String> adminLevel,
  Value<String?> parentId,
  Value<String?> colorHex,
  Value<String?> geometryJson,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$LocalLocationNodeTableTableFilterComposer
    extends Composer<_$AppDatabase, $LocalLocationNodeTableTable> {
  $$LocalLocationNodeTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get osmId => $composableBuilder(
      column: $table.osmId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get adminLevel => $composableBuilder(
      column: $table.adminLevel, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get parentId => $composableBuilder(
      column: $table.parentId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get colorHex => $composableBuilder(
      column: $table.colorHex, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get geometryJson => $composableBuilder(
      column: $table.geometryJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$LocalLocationNodeTableTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalLocationNodeTableTable> {
  $$LocalLocationNodeTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get osmId => $composableBuilder(
      column: $table.osmId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get adminLevel => $composableBuilder(
      column: $table.adminLevel, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get parentId => $composableBuilder(
      column: $table.parentId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get colorHex => $composableBuilder(
      column: $table.colorHex, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get geometryJson => $composableBuilder(
      column: $table.geometryJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$LocalLocationNodeTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalLocationNodeTableTable> {
  $$LocalLocationNodeTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get osmId =>
      $composableBuilder(column: $table.osmId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get adminLevel => $composableBuilder(
      column: $table.adminLevel, builder: (column) => column);

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<String> get colorHex =>
      $composableBuilder(column: $table.colorHex, builder: (column) => column);

  GeneratedColumn<String> get geometryJson => $composableBuilder(
      column: $table.geometryJson, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LocalLocationNodeTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LocalLocationNodeTableTable,
    LocalLocationNode,
    $$LocalLocationNodeTableTableFilterComposer,
    $$LocalLocationNodeTableTableOrderingComposer,
    $$LocalLocationNodeTableTableAnnotationComposer,
    $$LocalLocationNodeTableTableCreateCompanionBuilder,
    $$LocalLocationNodeTableTableUpdateCompanionBuilder,
    (
      LocalLocationNode,
      BaseReferences<_$AppDatabase, $LocalLocationNodeTableTable,
          LocalLocationNode>
    ),
    LocalLocationNode,
    PrefetchHooks Function()> {
  $$LocalLocationNodeTableTableTableManager(
      _$AppDatabase db, $LocalLocationNodeTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalLocationNodeTableTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalLocationNodeTableTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalLocationNodeTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<int?> osmId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> adminLevel = const Value.absent(),
            Value<String?> parentId = const Value.absent(),
            Value<String?> colorHex = const Value.absent(),
            Value<String?> geometryJson = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalLocationNodeTableCompanion(
            id: id,
            osmId: osmId,
            name: name,
            adminLevel: adminLevel,
            parentId: parentId,
            colorHex: colorHex,
            geometryJson: geometryJson,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            Value<int?> osmId = const Value.absent(),
            required String name,
            required String adminLevel,
            Value<String?> parentId = const Value.absent(),
            Value<String?> colorHex = const Value.absent(),
            Value<String?> geometryJson = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalLocationNodeTableCompanion.insert(
            id: id,
            osmId: osmId,
            name: name,
            adminLevel: adminLevel,
            parentId: parentId,
            colorHex: colorHex,
            geometryJson: geometryJson,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalLocationNodeTableTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $LocalLocationNodeTableTable,
        LocalLocationNode,
        $$LocalLocationNodeTableTableFilterComposer,
        $$LocalLocationNodeTableTableOrderingComposer,
        $$LocalLocationNodeTableTableAnnotationComposer,
        $$LocalLocationNodeTableTableCreateCompanionBuilder,
        $$LocalLocationNodeTableTableUpdateCompanionBuilder,
        (
          LocalLocationNode,
          BaseReferences<_$AppDatabase, $LocalLocationNodeTableTable,
              LocalLocationNode>
        ),
        LocalLocationNode,
        PrefetchHooks Function()>;
typedef $$LocalAppEventsTableTableCreateCompanionBuilder
    = LocalAppEventsTableCompanion Function({
  required String id,
  required String sessionId,
  Value<String?> userId,
  required String category,
  required String event,
  Value<String> dataJson,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$LocalAppEventsTableTableUpdateCompanionBuilder
    = LocalAppEventsTableCompanion Function({
  Value<String> id,
  Value<String> sessionId,
  Value<String?> userId,
  Value<String> category,
  Value<String> event,
  Value<String> dataJson,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$LocalAppEventsTableTableFilterComposer
    extends Composer<_$AppDatabase, $LocalAppEventsTableTable> {
  $$LocalAppEventsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sessionId => $composableBuilder(
      column: $table.sessionId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get event => $composableBuilder(
      column: $table.event, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get dataJson => $composableBuilder(
      column: $table.dataJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$LocalAppEventsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalAppEventsTableTable> {
  $$LocalAppEventsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sessionId => $composableBuilder(
      column: $table.sessionId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get event => $composableBuilder(
      column: $table.event, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get dataJson => $composableBuilder(
      column: $table.dataJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$LocalAppEventsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalAppEventsTableTable> {
  $$LocalAppEventsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get event =>
      $composableBuilder(column: $table.event, builder: (column) => column);

  GeneratedColumn<String> get dataJson =>
      $composableBuilder(column: $table.dataJson, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LocalAppEventsTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LocalAppEventsTableTable,
    LocalAppEvent,
    $$LocalAppEventsTableTableFilterComposer,
    $$LocalAppEventsTableTableOrderingComposer,
    $$LocalAppEventsTableTableAnnotationComposer,
    $$LocalAppEventsTableTableCreateCompanionBuilder,
    $$LocalAppEventsTableTableUpdateCompanionBuilder,
    (
      LocalAppEvent,
      BaseReferences<_$AppDatabase, $LocalAppEventsTableTable, LocalAppEvent>
    ),
    LocalAppEvent,
    PrefetchHooks Function()> {
  $$LocalAppEventsTableTableTableManager(
      _$AppDatabase db, $LocalAppEventsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalAppEventsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalAppEventsTableTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalAppEventsTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> sessionId = const Value.absent(),
            Value<String?> userId = const Value.absent(),
            Value<String> category = const Value.absent(),
            Value<String> event = const Value.absent(),
            Value<String> dataJson = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalAppEventsTableCompanion(
            id: id,
            sessionId: sessionId,
            userId: userId,
            category: category,
            event: event,
            dataJson: dataJson,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String sessionId,
            Value<String?> userId = const Value.absent(),
            required String category,
            required String event,
            Value<String> dataJson = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalAppEventsTableCompanion.insert(
            id: id,
            sessionId: sessionId,
            userId: userId,
            category: category,
            event: event,
            dataJson: dataJson,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalAppEventsTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $LocalAppEventsTableTable,
    LocalAppEvent,
    $$LocalAppEventsTableTableFilterComposer,
    $$LocalAppEventsTableTableOrderingComposer,
    $$LocalAppEventsTableTableAnnotationComposer,
    $$LocalAppEventsTableTableCreateCompanionBuilder,
    $$LocalAppEventsTableTableUpdateCompanionBuilder,
    (
      LocalAppEvent,
      BaseReferences<_$AppDatabase, $LocalAppEventsTableTable, LocalAppEvent>
    ),
    LocalAppEvent,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LocalCellProgressTableTableTableManager get localCellProgressTable =>
      $$LocalCellProgressTableTableTableManager(
          _db, _db.localCellProgressTable);
  $$LocalItemInstanceTableTableTableManager get localItemInstanceTable =>
      $$LocalItemInstanceTableTableTableManager(
          _db, _db.localItemInstanceTable);
  $$LocalPlayerProfileTableTableTableManager get localPlayerProfileTable =>
      $$LocalPlayerProfileTableTableTableManager(
          _db, _db.localPlayerProfileTable);
  $$LocalSpeciesTableTableTableManager get localSpeciesTable =>
      $$LocalSpeciesTableTableTableManager(_db, _db.localSpeciesTable);
  $$LocalWriteQueueTableTableTableManager get localWriteQueueTable =>
      $$LocalWriteQueueTableTableTableManager(_db, _db.localWriteQueueTable);
  $$LocalCellPropertiesTableTableTableManager get localCellPropertiesTable =>
      $$LocalCellPropertiesTableTableTableManager(
          _db, _db.localCellPropertiesTable);
  $$LocalLocationNodeTableTableTableManager get localLocationNodeTable =>
      $$LocalLocationNodeTableTableTableManager(
          _db, _db.localLocationNodeTable);
  $$LocalAppEventsTableTableTableManager get localAppEventsTable =>
      $$LocalAppEventsTableTableTableManager(_db, _db.localAppEventsTable);
}
