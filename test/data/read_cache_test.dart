import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:zoezidesk_staff/core/errors/app_failure.dart';
import 'package:zoezidesk_staff/core/storage/session_storage.dart';
import 'package:zoezidesk_staff/data/api/staff_api.dart';
import 'package:zoezidesk_staff/data/local/app_database.dart';
import 'package:zoezidesk_staff/data/models/staff.dart';
import 'package:zoezidesk_staff/data/repositories/read_cache.dart';
import 'package:zoezidesk_staff/features/auth/state/session_controller.dart';

import '../helpers/fakes.dart';

/// A read the tests control: `{"n": 1}` reads as 1.
ApiRead<int> _count({bool keep = true}) => ApiRead('/staff/count', (json) => json['n'] as int, keep: keep);

void main() {
  late AppDatabase db;
  late FakeAdapter adapter;
  late InMemorySecureStore store;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
    adapter = FakeAdapter();
    store = InMemorySecureStore();
    addTearDown(db.close);
  });

  /// The app, started (again) on the same device, with [staff] signed in.
  Future<ProviderContainer> start(StaffProfile staff) async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))..httpClientAdapter = adapter;
    final c = ProviderContainer(
      overrides: [
        staffApiProvider.overrideWithValue(StaffApi(dio)),
        secureStoreProvider.overrideWithValue(store),
        appDatabaseProvider.overrideWithValue(db),
      ],
      retry: (_, _) => null,
    );
    addTearDown(c.dispose);
    c.read(sessionControllerProvider);
    await Future<void>.delayed(const Duration(milliseconds: 5)); // the stored session: nobody
    c.read(sessionControllerProvider.notifier).signedIn(staff);
    return c;
  }

  Future<AsyncValue<int>> show(ProviderContainer c, AsyncNotifierProvider<CachedRead<int>, int> provider) async {
    final sub = c.listen(provider, (_, _) {});
    addTearDown(sub.close);
    try {
      await c.read(provider.future);
    } catch (_) {
      // Shown as an error.
    }
    return sub.read();
  }

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

  final me = staffWith(receptionistPermissions);

  test('the first time, a screen waits for the server and keeps its answer', () async {
    final c = await start(me);
    adapter.reply(200, {'n': 1});

    expect((await show(c, cachedRead((_) => _count()))).value, 1);
    final rows = await db.select(db.cachedReads).get();
    expect(rows.single.owner, 'staff:7');
    expect(rows.single.key, '/staff/count');
  });

  test('after a restart the saved answer shows at once, then the server\'s replaces it', () async {
    adapter.reply(200, {'n': 1});
    await show(await start(me), cachedRead((_) => _count()));

    final c = await start(me);
    adapter.reply(200, {'n': 2});
    final provider = cachedRead((_) => _count());
    expect((await show(c, provider)).value, 1);
    await settle();
    expect(c.read(provider).value, 2);
  });

  test('offline, the saved answer stays, marked out of date with when it was saved', () async {
    adapter.reply(200, {'n': 1});
    await show(await start(me), cachedRead((_) => _count()));
    final savedAt = (await db.select(db.cachedReads).getSingle()).savedAt;

    final c = await start(me); // nothing queued: offline
    final provider = cachedRead((_) => _count());
    await show(c, provider);
    await settle();

    final value = c.read(provider);
    expect(value.value, 1);
    expect(value.error, isA<OutOfDate>());
    expect((value.error! as OutOfDate).cause, isA<NetworkFailure>());
    expect((value.error! as OutOfDate).savedAt, savedAt);
  });

  test('offline with nothing saved shows offline, as before', () async {
    final value = await show(await start(me), cachedRead((_) => _count()));
    expect(value.hasValue, isFalse);
    expect(value.error, isA<NetworkFailure>());
  });

  test('searches are not kept', () async {
    adapter.reply(200, {'n': 1});
    await show(await start(me), cachedRead((_) => _count(keep: false)));
    expect(await db.select(db.cachedReads).get(), isEmpty);
  });

  test('one person\'s saved screens are never shown to another', () async {
    adapter.reply(200, {'n': 1});
    await show(await start(me), cachedRead((_) => _count()));

    final other = await start(staffWith(receptionistPermissions, id: 8));
    expect((await show(other, cachedRead((_) => _count()))).hasValue, isFalse);
  });

  test('on the front desk everyone shares the desk\'s saved screens', () async {
    adapter.reply(200, {'n': 1});
    await show(await start(staffWith(receptionistPermissions, shared: true)), cachedRead((_) => _count()));
    expect((await db.select(db.cachedReads).getSingle()).owner, 'desk');

    final next = await start(staffWith(receptionistPermissions, id: 8, shared: true));
    adapter.reply(200, {'n': 2});
    expect((await show(next, cachedRead((_) => _count()))).value, 1);
  });

  test('signing out of a personal phone deletes the saved screens', () async {
    final c = await start(me);
    adapter.reply(200, {'n': 1});
    await show(c, cachedRead((_) => _count()));
    adapter.reply(200, {'success': true}); // revoking the token

    await c.read(sessionControllerProvider.notifier).signOut();
    expect(await db.select(db.cachedReads).get(), isEmpty);
  });

  test('a saved screen that no longer parses is fetched again', () async {
    await db.into(db.cachedReads).insert(CachedReadsCompanion.insert(
          owner: 'staff:7',
          key: '/staff/count',
          body: '{"old": "shape"}',
          savedAt: DateTime.now(),
        ));
    final c = await start(me);
    adapter.reply(200, {'n': 3});
    expect((await show(c, cachedRead((_) => _count()))).value, 3);
  });

  test('screens\' keys put the query in a fixed order', () {
    expect(StaffReads.followUps.key, '/staff/members/expiring?days=7&lapsed_days=14');
    expect(StaffReads.members(page: 2).key, '/staff/members?page=2');
    expect(StaffReads.members(search: 'ami').keep, isFalse);
  });

  test('the database file is encrypted', () async {
    final dir = await Directory.systemTemp.createTemp('zoezi_cache_test');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/cache.db');
    final encrypted = AppDatabase(NativeDatabase(file, setup: (raw) => raw.execute("PRAGMA key = 'k1'")));
    await encrypted.into(encrypted.cachedReads).insert(CachedReadsCompanion.insert(
          owner: 'desk',
          key: '/staff/leads',
          body: '{"phone": "0712345678"}',
          savedAt: DateTime.now(),
        ));
    await encrypted.close();

    expect(String.fromCharCodes(await file.readAsBytes()).contains('0712345678'), isFalse);
    final raw = sqlite3.open(file.path);
    addTearDown(raw.close);
    expect(() => raw.select('SELECT * FROM cached_reads'), throwsA(isA<SqliteException>()));
  });
}
