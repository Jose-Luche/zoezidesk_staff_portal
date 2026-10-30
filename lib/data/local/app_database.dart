import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../core/storage/session_storage.dart';

part 'app_database.g.dart';

/// A screen's last answer from the server, as the server sent it, so it is
/// read back with the same parsing as a live answer.
@DataClassName('CachedReadRow')
class CachedReads extends Table {
  /// Whose it is: `desk` on the front-desk device (everyone there sees the
  /// same front-desk data), `staff:<id>` on a personal phone.
  TextColumn get owner => text()();

  /// The request: path and query.
  TextColumn get key => text()();
  TextColumn get body => text()();
  DateTimeColumn get savedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {owner, key};
}

@DriftDatabase(tables: [CachedReads])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  /// Rows not refreshed for this long (a member opened once) are deleted
  /// when the app starts.
  static const keepFor = Duration(days: 14);

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (_) async {
          final cutoff = DateTime.now().subtract(keepFor);
          await (delete(cachedReads)..where((r) => r.savedAt.isSmallerThanValue(cutoff))).go();
        },
      );

  /// Everything, when the phone is signed out or stops being the front desk.
  Future<void> wipe() => delete(cachedReads).go();
}

/// The database file, encrypted with a random key kept in secure storage.
/// A file the key no longer opens (secure storage cleared) is started again:
/// it only ever holds copies of what the server has.
LazyDatabase openAppDatabase(SecureStore store) => LazyDatabase(() async {
      final file = File('${(await getApplicationSupportDirectory()).path}/zoezi_cache.db');
      final key = await _databaseKey(store);
      if (await file.exists() && !_opens(file, key)) await file.delete();
      return NativeDatabase.createInBackground(file, setup: (raw) => raw.execute("PRAGMA key = '$key'"));
    });

bool _opens(File file, String key) {
  final raw = sqlite3.open(file.path);
  try {
    raw.execute("PRAGMA key = '$key'");
    raw.select('SELECT count(*) FROM sqlite_master');
    return true;
  } on SqliteException {
    return false;
  } finally {
    raw.close();
  }
}

const _keyName = 'cache_db_key';

Future<String> _databaseKey(SecureStore store) async {
  final saved = await store.read(_keyName);
  if (saved != null) return saved;
  final random = Random.secure();
  final key = [for (var i = 0; i < 32; i++) random.nextInt(256).toRadixString(16).padLeft(2, '0')].join();
  await store.write(_keyName, key);
  return key;
}

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(openAppDatabase(ref.watch(secureStoreProvider)));
  ref.onDispose(db.close);
  return db;
});
