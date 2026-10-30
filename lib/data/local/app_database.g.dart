// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CachedReadsTable extends CachedReads
    with TableInfo<$CachedReadsTable, CachedReadRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedReadsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ownerMeta = const VerificationMeta('owner');
  @override
  late final GeneratedColumn<String> owner = GeneratedColumn<String>(
    'owner',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _savedAtMeta = const VerificationMeta(
    'savedAt',
  );
  @override
  late final GeneratedColumn<DateTime> savedAt = GeneratedColumn<DateTime>(
    'saved_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [owner, key, body, savedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_reads';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedReadRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('owner')) {
      context.handle(
        _ownerMeta,
        owner.isAcceptableOrUnknown(data['owner']!, _ownerMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerMeta);
    }
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('saved_at')) {
      context.handle(
        _savedAtMeta,
        savedAt.isAcceptableOrUnknown(data['saved_at']!, _savedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_savedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {owner, key};
  @override
  CachedReadRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedReadRow(
      owner: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner'],
      )!,
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      savedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}saved_at'],
      )!,
    );
  }

  @override
  $CachedReadsTable createAlias(String alias) {
    return $CachedReadsTable(attachedDatabase, alias);
  }
}

class CachedReadRow extends DataClass implements Insertable<CachedReadRow> {
  /// Whose it is: `desk` on the front-desk device (everyone there sees the
  /// same front-desk data), `staff:<id>` on a personal phone.
  final String owner;

  /// The request: path and query.
  final String key;
  final String body;
  final DateTime savedAt;
  const CachedReadRow({
    required this.owner,
    required this.key,
    required this.body,
    required this.savedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['owner'] = Variable<String>(owner);
    map['key'] = Variable<String>(key);
    map['body'] = Variable<String>(body);
    map['saved_at'] = Variable<DateTime>(savedAt);
    return map;
  }

  CachedReadsCompanion toCompanion(bool nullToAbsent) {
    return CachedReadsCompanion(
      owner: Value(owner),
      key: Value(key),
      body: Value(body),
      savedAt: Value(savedAt),
    );
  }

  factory CachedReadRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedReadRow(
      owner: serializer.fromJson<String>(json['owner']),
      key: serializer.fromJson<String>(json['key']),
      body: serializer.fromJson<String>(json['body']),
      savedAt: serializer.fromJson<DateTime>(json['savedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'owner': serializer.toJson<String>(owner),
      'key': serializer.toJson<String>(key),
      'body': serializer.toJson<String>(body),
      'savedAt': serializer.toJson<DateTime>(savedAt),
    };
  }

  CachedReadRow copyWith({
    String? owner,
    String? key,
    String? body,
    DateTime? savedAt,
  }) => CachedReadRow(
    owner: owner ?? this.owner,
    key: key ?? this.key,
    body: body ?? this.body,
    savedAt: savedAt ?? this.savedAt,
  );
  CachedReadRow copyWithCompanion(CachedReadsCompanion data) {
    return CachedReadRow(
      owner: data.owner.present ? data.owner.value : this.owner,
      key: data.key.present ? data.key.value : this.key,
      body: data.body.present ? data.body.value : this.body,
      savedAt: data.savedAt.present ? data.savedAt.value : this.savedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedReadRow(')
          ..write('owner: $owner, ')
          ..write('key: $key, ')
          ..write('body: $body, ')
          ..write('savedAt: $savedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(owner, key, body, savedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedReadRow &&
          other.owner == this.owner &&
          other.key == this.key &&
          other.body == this.body &&
          other.savedAt == this.savedAt);
}

class CachedReadsCompanion extends UpdateCompanion<CachedReadRow> {
  final Value<String> owner;
  final Value<String> key;
  final Value<String> body;
  final Value<DateTime> savedAt;
  final Value<int> rowid;
  const CachedReadsCompanion({
    this.owner = const Value.absent(),
    this.key = const Value.absent(),
    this.body = const Value.absent(),
    this.savedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedReadsCompanion.insert({
    required String owner,
    required String key,
    required String body,
    required DateTime savedAt,
    this.rowid = const Value.absent(),
  }) : owner = Value(owner),
       key = Value(key),
       body = Value(body),
       savedAt = Value(savedAt);
  static Insertable<CachedReadRow> custom({
    Expression<String>? owner,
    Expression<String>? key,
    Expression<String>? body,
    Expression<DateTime>? savedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (owner != null) 'owner': owner,
      if (key != null) 'key': key,
      if (body != null) 'body': body,
      if (savedAt != null) 'saved_at': savedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedReadsCompanion copyWith({
    Value<String>? owner,
    Value<String>? key,
    Value<String>? body,
    Value<DateTime>? savedAt,
    Value<int>? rowid,
  }) {
    return CachedReadsCompanion(
      owner: owner ?? this.owner,
      key: key ?? this.key,
      body: body ?? this.body,
      savedAt: savedAt ?? this.savedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (owner.present) {
      map['owner'] = Variable<String>(owner.value);
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (savedAt.present) {
      map['saved_at'] = Variable<DateTime>(savedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedReadsCompanion(')
          ..write('owner: $owner, ')
          ..write('key: $key, ')
          ..write('body: $body, ')
          ..write('savedAt: $savedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CachedReadsTable cachedReads = $CachedReadsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [cachedReads];
}

typedef $$CachedReadsTableCreateCompanionBuilder =
    CachedReadsCompanion Function({
      required String owner,
      required String key,
      required String body,
      required DateTime savedAt,
      Value<int> rowid,
    });
typedef $$CachedReadsTableUpdateCompanionBuilder =
    CachedReadsCompanion Function({
      Value<String> owner,
      Value<String> key,
      Value<String> body,
      Value<DateTime> savedAt,
      Value<int> rowid,
    });

class $$CachedReadsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedReadsTable> {
  $$CachedReadsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get owner => $composableBuilder(
    column: $table.owner,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get savedAt => $composableBuilder(
    column: $table.savedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedReadsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedReadsTable> {
  $$CachedReadsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get owner => $composableBuilder(
    column: $table.owner,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get savedAt => $composableBuilder(
    column: $table.savedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedReadsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedReadsTable> {
  $$CachedReadsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get owner =>
      $composableBuilder(column: $table.owner, builder: (column) => column);

  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<DateTime> get savedAt =>
      $composableBuilder(column: $table.savedAt, builder: (column) => column);
}

class $$CachedReadsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedReadsTable,
          CachedReadRow,
          $$CachedReadsTableFilterComposer,
          $$CachedReadsTableOrderingComposer,
          $$CachedReadsTableAnnotationComposer,
          $$CachedReadsTableCreateCompanionBuilder,
          $$CachedReadsTableUpdateCompanionBuilder,
          (
            CachedReadRow,
            BaseReferences<_$AppDatabase, $CachedReadsTable, CachedReadRow>,
          ),
          CachedReadRow,
          PrefetchHooks Function()
        > {
  $$CachedReadsTableTableManager(_$AppDatabase db, $CachedReadsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedReadsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedReadsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedReadsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> owner = const Value.absent(),
                Value<String> key = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<DateTime> savedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedReadsCompanion(
                owner: owner,
                key: key,
                body: body,
                savedAt: savedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String owner,
                required String key,
                required String body,
                required DateTime savedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedReadsCompanion.insert(
                owner: owner,
                key: key,
                body: body,
                savedAt: savedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CachedReadsTable, CachedReadRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $CachedReadsTable,
                    CachedReadRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedReadsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedReadsTable,
      CachedReadRow,
      $$CachedReadsTableFilterComposer,
      $$CachedReadsTableOrderingComposer,
      $$CachedReadsTableAnnotationComposer,
      $$CachedReadsTableCreateCompanionBuilder,
      $$CachedReadsTableUpdateCompanionBuilder,
      (
        CachedReadRow,
        BaseReferences<_$AppDatabase, $CachedReadsTable, CachedReadRow>,
      ),
      CachedReadRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CachedReadsTableTableManager get cachedReads =>
      $$CachedReadsTableTableManager(_db, _db.cachedReads);
}
