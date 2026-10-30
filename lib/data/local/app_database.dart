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

/// Something done with no connection (or a dropped one), waiting to reach
/// the server. Sent in order, oldest first, with the same idempotency key
/// every time, so a resend after a lost reply counts once.
@DataClassName('OutboxRow')
class Outbox extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Whose it is, as for [CachedReads]: only that person (or the desk)
  /// sends it.
  TextColumn get owner => text()();

  /// What to do: `checkin`, `attended`, ... (see QueuedActions).
  TextColumn get kind => text()();
  TextColumn get payload => text()();
  TextColumn get idempotencyKey => text()();

  /// What it is about, for the screens: a member's name, say.
  TextColumn get label => text().nullable()();

  /// pending, sending, sent or failed (the server refused it).
  TextColumn get status => text()();

  /// Why the server refused it.
  TextColumn get message => text().nullable()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();

  /// Not before this, after a failed try (backing off).
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

@DriftDatabase(tables: [CachedReads, Outbox])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 2;

  /// Rows not refreshed for this long (a member opened once) are deleted
  /// when the app starts.
  static const keepFor = Duration(days: 14);

  /// Sent items are kept this long, then deleted.
  static const keepSentFor = Duration(days: 1);

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) await m.createTable(outbox);
        },
        beforeOpen: (_) async {
          final now = DateTime.now();
          await (delete(cachedReads)..where((r) => r.savedAt.isSmallerThanValue(now.subtract(keepFor)))).go();
          await (delete(outbox)
                ..where((o) => o.status.equals('sent') & o.createdAt.isSmallerThanValue(now.subtract(keepSentFor))))
              .go();
          // Cut off mid-send (the app was closed): the server may or may not
          // have it; the idempotency key makes sending again safe.
          await (update(outbox)..where((o) => o.status.equals('sending')))
              .write(const OutboxCompanion(status: Value('pending')));
        },
      );

  /// Everything, when the phone is signed out or stops being the front desk.
  Future<void> wipe() => transaction(() async {
        await delete(cachedReads).go();
        await delete(outbox).go();
      });
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
