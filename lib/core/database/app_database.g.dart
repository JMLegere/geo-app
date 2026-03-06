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
        status
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
      required this.status});
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
          String? status}) =>
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
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, userId, definitionId, affixes, parentAId,
      parentBId, acquiredAt, acquiredInCellId, dailySeed, status);
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
          other.status == this.status);
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

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LocalCellProgressTableTable localCellProgressTable =
      $LocalCellProgressTableTable(this);
  late final $LocalItemInstanceTableTable localItemInstanceTable =
      $LocalItemInstanceTableTable(this);
  late final $LocalPlayerProfileTableTable localPlayerProfileTable =
      $LocalPlayerProfileTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [localCellProgressTable, localItemInstanceTable, localPlayerProfileTable];
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
}
