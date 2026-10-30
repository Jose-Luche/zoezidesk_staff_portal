import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:zoezidesk_staff/data/local/app_database.dart';
import 'package:zoezidesk_staff/core/storage/session_storage.dart';
import 'package:zoezidesk_staff/data/models/staff.dart';

class InMemorySecureStore implements SecureStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

/// The cache database in memory, for a test's ProviderContainer.
Override memoryDatabase() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return appDatabaseProvider.overrideWith((ref) {
    final db = AppDatabase(NativeDatabase.memory());
    ref.onDispose(db.close);
    return db;
  });
}

/// A staff member with exactly [permissions] (see the backend's StaffPermissions).
StaffProfile staffWith(
  Set<String> permissions, {
  int id = 7,
  bool browseAll = true,
  bool shared = false,
  List<String> roles = const ['receptionist'],
}) =>
    StaffProfile(
      id: id,
      name: 'Amina Wanjiru',
      email: 'amina@test.com',
      roles: roles,
      roleLabel: roles.join(' · '),
      gymName: 'Test Gym',
      hasPin: true,
      sharedDevice: shared,
      permissions: permissions,
      browseAllMembers: browseAll,
    );

const receptionistPermissions = {
  'checkin.scan', 'members.view', 'members.create', 'members.edit', 'payments.record', 'classes.view',
};
const trainerPermissions = {'checkin.scan', 'members.view_assigned', 'members.view_training', 'classes.view', 'notes.manage'};
const ownerPermissions = {
  'checkin.scan', 'members.view', 'members.view_training', 'members.create', 'members.edit', 'members.delete',
  'payments.record', 'payments.view', 'payments.void', 'reports.view', 'classes.view', 'classes.manage',
  'notes.manage', 'staff.manage', 'settings.manage',
};

Map<String, dynamic> signInJson({String token = 't1', String refresh = 'r1', Set<String>? permissions}) => {
      'token': token,
      'refresh_token': refresh,
      'staff': staffWith(permissions ?? receptionistPermissions).toJson(),
    };

/// Answers dio requests from a queue of canned responses or errors.
class FakeAdapter implements HttpClientAdapter {
  final responses = <Object>[];
  final requests = <RequestOptions>[];

  void reply(int status, [Object? body]) => responses.add((status, body));

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    // Nothing queued behaves like being offline.
    if (responses.isEmpty) throw DioException(requestOptions: options, type: DioExceptionType.connectionError);
    final (status, body) = responses.removeAt(0) as (int, Object?);
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      status,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }

  @override
  void close({bool force = false}) {}
}
