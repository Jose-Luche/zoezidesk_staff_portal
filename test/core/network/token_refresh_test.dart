import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoezidesk_staff/core/network/auth_interceptor.dart';
import 'package:zoezidesk_staff/core/network/dio_client.dart';
import 'package:zoezidesk_staff/core/network/token_refresher.dart';
import 'package:zoezidesk_staff/core/storage/session_storage.dart';
import 'package:zoezidesk_staff/data/models/staff.dart';

import '../../helpers/fakes.dart';

void main() {
  late FakeAdapter adapter;
  late SessionStorage storage;
  late Dio dio;
  late int unauthorizedCalls;
  late List<StaffProfile> profiles;

  setUp(() async {
    adapter = FakeAdapter();
    storage = SessionStorage(InMemorySecureStore());
    await storage.saveSignIn(SignInResult.fromJson(signInJson(token: 'old', refresh: 'r1')));
    unauthorizedCalls = 0;
    profiles = [];
    dio = buildDio(
      baseUrl: 'https://api.test',
      auth: AuthInterceptor(
        readToken: storage.readToken,
        refresh: TokenRefresher(storage, onProfile: profiles.add).call,
        onUnauthorized: () => unauthorizedCalls++,
      ),
    );
    dio.httpClientAdapter = adapter;
  });

  test('an expired token is renewed, with the latest roles, and the request repeated', () async {
    adapter
      ..reply(401, {'message': 'Unauthenticated.'})
      ..reply(200, signInJson(token: 'new', refresh: 'r2', permissions: trainerPermissions))
      ..reply(200, {'ok': true});

    final res = await dio.get<Map<String, dynamic>>('/staff/me');

    expect(res.data, {'ok': true});
    expect(adapter.requests[1].path, '/staff/token/refresh');
    expect(adapter.requests[1].data, {'refresh_token': 'r1'});
    expect(adapter.requests[2].headers['Authorization'], 'Bearer new');
    expect(await storage.readRefreshToken(), 'r2');
    expect((await storage.readStaff())!.permissions, trainerPermissions);
    expect(profiles.single.permissions, trainerPermissions);
    expect(unauthorizedCalls, 0);
  });

  test('a refused refresh ends the session', () async {
    adapter
      ..reply(401, {'message': 'Unauthenticated.'})
      ..reply(401, {'message': 'Your session has ended.'});

    await expectLater(dio.get<void>('/staff/me'), throwsA(isA<DioException>()));
    expect(unauthorizedCalls, 1);
  });

  test('signing out keeps the front-desk device enrolled', () async {
    await storage.saveDevice('device-token', const FrontDeskDevice(id: 1, name: 'Desk', gymName: 'Gym'));

    await storage.clearSession();

    expect(await storage.readToken(), isNull);
    expect(await storage.readStaff(), isNull);
    expect(await storage.readDeviceToken(), 'device-token');
    expect((await storage.readDevice())!.name, 'Desk');
  });
}
