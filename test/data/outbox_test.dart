import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:zoezidesk_staff/core/network/retry_interceptor.dart';
import 'package:zoezidesk_staff/core/storage/session_storage.dart';
import 'package:zoezidesk_staff/data/api/staff_api.dart';
import 'package:zoezidesk_staff/data/local/app_database.dart';
import 'package:zoezidesk_staff/data/models/staff.dart';
import 'package:zoezidesk_staff/data/repositories/outbox.dart';
import 'package:zoezidesk_staff/features/auth/state/session_controller.dart';
import 'package:zoezidesk_staff/features/classes/classes_screen.dart';
import 'package:zoezidesk_staff/features/sync/queued_actions.dart';

import '../helpers/fakes.dart';

void main() {
  late AppDatabase db;
  late FakeAdapter adapter;
  late InMemorySecureStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    adapter = FakeAdapter();
    store = InMemorySecureStore();
    addTearDown(db.close);
  });

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

  Future<ProviderContainer> start([StaffProfile? staff]) async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))..httpClientAdapter = adapter;
    final c = ProviderContainer(overrides: [
      staffApiProvider.overrideWithValue(StaffApi(dio)),
      secureStoreProvider.overrideWithValue(store),
      appDatabaseProvider.overrideWithValue(db),
      connectionBackProvider.overrideWithValue(const Stream.empty()),
    ]);
    addTearDown(c.dispose);
    c.read(sessionControllerProvider);
    await settle(); // the stored session: nobody
    c.read(sessionControllerProvider.notifier).signedIn(staff ?? staffWith(receptionistPermissions));
    c.listen(outboxProvider, (_, _) {});
    await settle();
    return c;
  }

  OutboxController outboxOf(ProviderContainer c) => c.read(outboxProvider.notifier);
  Future<List<OutboxRow>> rows() => db.select(db.outbox).get();
  const tick = {'class_id': 5, 'member_id': 12, 'attended': true};

  test('online, an action goes straight away and its answer comes back', () async {
    final c = await start();
    adapter.reply(200, {'success': true, 'message': 'Jane Wanjiku is booked in.'});

    final delivery = await outboxOf(c).submit(QueuedKinds.book, {'class_id': 5, 'member_id': 12}, label: 'Jane');

    expect((delivery as Delivered).result, 'Jane Wanjiku is booked in.');
    expect((await rows()).single.status, 'sent');
    expect(adapter.requests.single.headers[RetryInterceptor.idempotencyHeader], (await rows()).single.idempotencyKey);
  });

  test('offline, it is kept as pending and shown as waiting', () async {
    final c = await start();

    final delivery = await outboxOf(c).submit(QueuedKinds.attended, tick, label: 'Jane');
    await settle();

    expect(delivery, isA<Queued>());
    final row = (await rows()).single;
    expect(row.status, 'pending');
    expect(row.attempts, 1);
    expect(row.nextAttemptAt!.isAfter(DateTime.now()), isTrue);
    expect(c.read(outboxProvider).single.waiting, isTrue);
    expect(c.read(outboxProvider).single.label, 'Jane');
  });

  test('a waiting action is tried again with the same key, once the back-off allows', () async {
    final c = await start();
    await outboxOf(c).submit(QueuedKinds.attended, tick);
    final key = (await rows()).single.idempotencyKey;

    adapter.reply(200, {'success': true});
    await outboxOf(c).flush(); // the timer's flush: still backing off
    expect((await rows()).single.status, 'pending');

    await outboxOf(c).flush(force: true); // the connection came back
    expect((await rows()).single.status, 'sent');
    expect([for (final r in adapter.requests) r.headers[RetryInterceptor.idempotencyHeader]], [key, key]);
  });

  test('actions go in order and stop at the first that cannot get through', () async {
    final c = await start();
    final outbox = outboxOf(c);
    await outbox.enqueue(QueuedKinds.attended, {...tick, 'member_id': 1});
    await outbox.enqueue(QueuedKinds.attended, {...tick, 'member_id': 2});
    await outbox.enqueue(QueuedKinds.attended, {...tick, 'member_id': 3});

    adapter.reply(200, {'success': true}); // then offline
    await outbox.flush(force: true);

    expect(adapter.requests.map((r) => r.path), [
      '/staff/classes/5/bookings/1/attended',
      '/staff/classes/5/bookings/2/attended',
    ]);
    expect((await rows()).map((r) => r.status), ['sent', 'pending', 'pending']);
  });

  test('a refusal says why and does not hold up the rest', () async {
    final c = await start();
    final outbox = outboxOf(c);
    await outbox.enqueue(QueuedKinds.attended, {...tick, 'member_id': 1}, label: 'Jane');
    await outbox.enqueue(QueuedKinds.attended, {...tick, 'member_id': 2});

    adapter
      ..reply(422, {'success': false, 'message': 'This member is not booked into the class.'})
      ..reply(200, {'success': true});
    await outbox.flush(force: true);
    await settle();

    expect((await rows()).map((r) => r.status), ['failed', 'sent']);
    final refused = c.read(outboxProvider).single;
    expect(refused.message, 'This member is not booked into the class.');
    expect(refused.label, 'Jane');

    await outbox.dismissRefused(QueuedKinds.attended);
    await settle();
    expect(c.read(outboxProvider), isEmpty);
  });

  test('refused straight away: said there and then, not kept', () async {
    final c = await start();
    adapter.reply(422, {'success': false, 'message': 'The class is full.'});

    final delivery = await outboxOf(c).submit(QueuedKinds.book, {'class_id': 5, 'member_id': 12});

    expect((delivery as Refused).message, 'The class is full.');
    expect(await rows(), isEmpty);
  });

  test('server trouble and a key still in use are tried again later, not refused', () async {
    final c = await start();
    adapter
      ..reply(503, {'message': 'Down for maintenance'})
      ..reply(409, {'message': 'Still working on it'});

    expect(await outboxOf(c).submit(QueuedKinds.attended, tick), isA<Queued>());
    await outboxOf(c).flush(force: true);
    expect((await rows()).single.status, 'pending');
    expect((await rows()).single.attempts, 2);
  });

  test('back-off grows from 5 seconds to at most 5 minutes', () async {
    final outbox = outboxOf(await start());
    expect(outbox.backoff(1).inSeconds, 5);
    expect(outbox.backoff(2).inSeconds, 10);
    expect(outbox.backoff(4).inSeconds, 40);
    expect(outbox.backoff(30), lessThan(const Duration(minutes: 5, seconds: 1)));
  });

  test('one person\'s waiting actions are never sent as someone else', () async {
    final c = await start();
    await outboxOf(c).enqueue(QueuedKinds.attended, tick);
    c.dispose();

    adapter.reply(200, {'success': true});
    final other = await start(staffWith(receptionistPermissions, id: 8));
    await outboxOf(other).flush(force: true);

    expect(adapter.requests, isEmpty);
    expect(other.read(outboxProvider), isEmpty);
  });

  test('once in, the screens that show it are fetched again', () async {
    final c = await start();
    adapter.reply(200, {'bookings': []});
    final roster = c.listen(rosterProvider(5), (_, _) {});
    addTearDown(roster.close);
    await c.read(rosterProvider(5).future);

    adapter
      ..reply(200, {'success': true})
      ..reply(200, {'bookings': []});
    await outboxOf(c).submit(QueuedKinds.attended, tick);
    for (var i = 0; i < 100 && adapter.requests.length < 3; i++) {
      await settle();
    }

    expect(adapter.requests.map((r) => r.path), [
      '/staff/classes/5/roster',
      '/staff/classes/5/bookings/12/attended',
      '/staff/classes/5/roster',
    ]);
  });

  test('cut off mid-send (the app closed): sent again on the next start', () async {
    final dir = await Directory.systemTemp.createTemp('zoezi_outbox_test');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/cache.db');
    final before = AppDatabase(NativeDatabase(file));
    await before.into(before.outbox).insert(OutboxCompanion.insert(
          owner: 'staff:7',
          kind: QueuedKinds.attended,
          payload: '{"class_id": 5, "member_id": 12, "attended": true}',
          idempotencyKey: 'k1',
          status: 'sending',
          createdAt: DateTime.now(),
        ));
    await before.close();

    db = AppDatabase(NativeDatabase(file)); // the next start
    addTearDown(db.close);
    adapter.reply(200, {'success': true});
    await start();
    await settle();

    expect((await rows()).single.status, 'sent');
    expect(adapter.requests.single.headers[RetryInterceptor.idempotencyHeader], 'k1');
  });

  test('a phone on the first version of the database keeps its saved screens and gets the outbox', () async {
    final dir = await Directory.systemTemp.createTemp('zoezi_upgrade_test');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/cache.db');
    // As schema 1 left it.
    final v1 = sqlite3.open(file.path)
      ..execute('CREATE TABLE cached_reads (owner TEXT NOT NULL, "key" TEXT NOT NULL, body TEXT NOT NULL, '
          'saved_at INTEGER NOT NULL, PRIMARY KEY (owner, "key"))')
      ..execute("INSERT INTO cached_reads VALUES ('desk', '/staff/leads', '{}', "
          '${DateTime.now().millisecondsSinceEpoch ~/ 1000})')
      ..execute('PRAGMA user_version = 1');
    v1.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);
    expect((await upgraded.select(upgraded.cachedReads).get()).single.key, '/staff/leads');
    expect(await upgraded.select(upgraded.outbox).get(), isEmpty);
  });
}
