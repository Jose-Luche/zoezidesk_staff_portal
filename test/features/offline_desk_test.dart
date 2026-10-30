import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoezidesk_staff/core/errors/app_failure.dart';
import 'package:zoezidesk_staff/core/network/retry_interceptor.dart';
import 'package:zoezidesk_staff/core/storage/session_storage.dart';
import 'package:zoezidesk_staff/data/api/staff_api.dart';
import 'package:zoezidesk_staff/data/local/app_database.dart';
import 'package:zoezidesk_staff/data/models/staff.dart';
import 'package:zoezidesk_staff/data/repositories/outbox.dart';
import 'package:zoezidesk_staff/features/auth/screens/lock_screen.dart';
import 'package:zoezidesk_staff/features/auth/state/session_controller.dart';
import 'package:zoezidesk_staff/features/desk/offline_desk.dart';

import '../helpers/fakes.dart';

class MemoryListFile implements OfflineListFile {
  String? contents;

  @override
  Future<String?> read() async => contents;

  @override
  Future<void> write(String contents) async => this.contents = contents;

  @override
  Future<void> delete() async => contents = null;
}

void main() {
  late FakeAdapter adapter;
  late InMemorySecureStore store;
  late MemoryListFile file;
  late AppDatabase db;

  String hash(String code) => sha256.convert(utf8.encode(code)).toString();

  Map<String, dynamic> card(int id, String code, {String expires = '2099-01-01'}) => {
        'qr_hash': hash(code),
        'id': id,
        'name': 'Member $id',
        'initials': 'M$id',
        'member_number': 'TG-$id',
        'phone': '25471100000$id',
        'photo_url': null,
        'status': 'active',
        'membership': {'plan': 'Monthly', 'expires_at': expires, 'days_left': 20, 'current': true},
      };

  Map<String, dynamic> checkedIn(int id) =>
      {'success': true, 'duplicate': false, 'message': 'Welcome!', 'member': card(id, 'x')..remove('qr_hash')};

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

  ProviderContainer container() {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))..httpClientAdapter = adapter;
    final c = ProviderContainer(overrides: [
      staffApiProvider.overrideWithValue(StaffApi(dio)),
      secureStoreProvider.overrideWithValue(store),
      offlineListFileProvider.overrideWithValue(file),
      appDatabaseProvider.overrideWithValue(db),
      connectionBackProvider.overrideWithValue(const Stream.empty()),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  /// The front-desk device, someone signed in, as the app runs it.
  Future<ProviderContainer> start() async {
    final c = container();
    c.read(sessionControllerProvider);
    await settle(); // the stored session: nobody
    c.read(sessionControllerProvider.notifier).signedIn(staffWith(receptionistPermissions, shared: true));
    c
      ..listen(outboxProvider, (_, _) {})
      ..listen(offlineDeskProvider, (_, _) {});
    return c;
  }

  Future<List<OutboxRow>> outbox() => db.select(db.outbox).get();

  Future<void> until(bool Function() done) async {
    for (var i = 0; i < 100 && !done(); i++) {
      await settle();
    }
  }

  setUp(() {
    adapter = FakeAdapter();
    store = InMemorySecureStore();
    file = MemoryListFile();
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
  });

  test('downloads the list and matches scans by their hash', () async {
    adapter.reply(200, {'members': [card(1, 'qr-one'), card(2, 'qr-old', expires: '2020-01-01')]});
    final c = await start();
    await until(() => c.read(offlineDeskProvider).listSize > 0);

    final desk = c.read(offlineDeskProvider.notifier);
    expect(c.read(offlineDeskProvider).listSize, 2);
    expect(desk.match('qr-one')?.name, 'Member 1');
    expect(desk.match('qr-old'), isNull, reason: 'membership ended');
    expect(desk.match('unknown'), isNull);
    expect(file.contents, isNot(contains('qr-one')), reason: 'only hashes are saved');
  });

  test('the saved list is used when the phone starts offline', () async {
    file.contents = jsonEncode({'saved_at': DateTime.now().toUtc().toIso8601String(), 'members': [card(1, 'qr-one')]});
    final c = await start();
    await settle();

    expect(c.read(offlineDeskProvider.notifier).match('qr-one')?.name, 'Member 1');
  });

  test('offline check-ins are kept, then sent in order with their time and key', () async {
    final c = await start(); // offline: nothing queued on the adapter
    await settle();
    final desk = c.read(offlineDeskProvider.notifier);

    await desk.record('qr-one', name: 'Member 1');
    await desk.record('qr-two');
    await settle();
    expect(c.read(offlineDeskProvider).pending, hasLength(2));
    expect((await outbox()).map((r) => r.owner), ['desk', 'desk']);

    await desk.send(); // still offline
    await settle();
    expect(c.read(offlineDeskProvider).pending, hasLength(2));

    final keys = [for (final e in c.read(offlineDeskProvider).pending) e.key];
    adapter.requests.clear();
    adapter
      ..reply(200, checkedIn(1))
      ..reply(422, {'success': false, 'message': 'No active membership. Renewal required.', 'member': null});
    await desk.send();
    await settle();

    final state = c.read(offlineDeskProvider);
    expect(state.pending, isEmpty);
    expect(state.refused.single.name, 'Unknown QR code');
    expect(state.refused.single.message, 'No active membership. Renewal required.');
    expect((await outbox()).map((r) => r.status), ['sent', 'failed']);

    await desk.dismissRefused();
    await settle();
    expect(c.read(offlineDeskProvider).refused, isEmpty);

    final sent = adapter.requests.where((r) => r.path == '/staff/checkins').toList();
    expect([for (final r in sent) (r.data as Map)['qr_code']], ['qr-one', 'qr-two']);
    expect([for (final r in sent) r.headers[RetryInterceptor.idempotencyHeader]], keys);
    expect((sent.first.data as Map)['checked_in_at'], isNotNull);
  });

  test('the queue survives a restart (the front-desk device locking)', () async {
    var c = await start();
    await settle();
    await c.read(offlineDeskProvider.notifier).record('qr-one', name: 'Member 1');
    c.dispose();

    c = await start();
    await settle();
    expect(c.read(offlineDeskProvider).pending.single.name, 'Member 1');
  });

  test('check-ins queued by the version before the outbox move over with their key and time', () async {
    final at = DateTime.utc(2026, 10, 30, 7, 15);
    store.values[OfflineDesk.legacyQueueKey] = jsonEncode([
      QueuedCheckIn(key: 'k1', qrCode: 'qr-one', at: at, name: 'Member 1').toJson(),
    ]);
    final c = await start();
    await settle();

    final queued = c.read(offlineDeskProvider).pending.single;
    expect(queued.key, 'k1');
    expect(queued.at, at);
    expect(queued.name, 'Member 1');
    expect(store.values.containsKey(OfflineDesk.legacyQueueKey), isFalse);
  });

  test('only the front desk and staff who browse all members keep the list', () {
    expect(canCheckInOffline(staffWith(receptionistPermissions)), isTrue);
    expect(canCheckInOffline(staffWith(trainerPermissions, browseAll: false)), isFalse);
    expect(canCheckInOffline(staffWith(trainerPermissions, browseAll: false, shared: true)), isTrue);
  });

  group('the member list leaves with the front desk', () {
    const device = FrontDeskDevice(id: 3, name: 'Front desk', gymName: 'Test Gym');

    /// Locked, with a check-in waiting.
    Future<ProviderContainer> enrolledDesk() async {
      file.contents = jsonEncode({'saved_at': DateTime.now().toUtc().toIso8601String(), 'members': [card(1, 'qr-one')]});
      await db.into(db.outbox).insert(OutboxCompanion.insert(
            owner: 'desk',
            kind: 'checkin',
            payload: jsonEncode({'qr_code': 'qr-one', 'at': DateTime.now().toUtc().toIso8601String()}),
            idempotencyKey: 'k1',
            status: 'pending',
            createdAt: DateTime.now(),
          ));
      return container();
    }

    test('unsent check-ins are counted for the warning', () async {
      await enrolledDesk();
      expect(await unsentActions(db, 'desk'), 1);
      expect(await unsentActions(db, 'staff:7'), 0);
    });

    test('stopping using the phone as the front desk deletes them', () async {
      final c = await enrolledDesk();
      await SessionStorage(store).saveDevice('device-token', device);
      c.read(sessionControllerProvider);
      await settle();

      await c.read(sessionControllerProvider.notifier).forgetDevice();

      expect(file.contents, isNull);
      expect(await outbox(), isEmpty);
    });

    test('a device revoked on the web deletes them without anyone tapping', () async {
      final c = await enrolledDesk();
      await SessionStorage(store).saveDevice('device-token', device);
      adapter.reply(401, {'success': false, 'message': 'This device was removed.'});

      final sub = c.listen(lockScreenStaffProvider, (_, _) {});
      addTearDown(sub.close);
      await until(() => file.contents == null);
      await settle();

      expect(file.contents, isNull);
      expect(await outbox(), isEmpty);
      expect(c.read(lockScreenStaffProvider).error, isA<UnauthorizedFailure>());
    });
  });
}
