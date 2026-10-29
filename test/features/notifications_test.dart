import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoezidesk_staff/core/notifications/push_messaging.dart';
import 'package:zoezidesk_staff/core/router/routes.dart';
import 'package:zoezidesk_staff/core/storage/device_preferences.dart';
import 'package:zoezidesk_staff/data/api/push_devices_api.dart';
import 'package:zoezidesk_staff/features/notifications/notifications_controller.dart';

import '../helpers/fakes.dart';

class FakePush implements PushMessaging {
  bool allow = true;
  final calls = <String>[];
  final refreshes = StreamController<String>.broadcast();

  @override
  bool get available => true;

  @override
  Future<bool> requestPermission() async {
    calls.add('permission');
    return allow;
  }

  @override
  Future<String?> getToken() async => 'fcm-1';

  @override
  Stream<String> get tokenRefresh => refreshes.stream;

  @override
  Future<void> deleteToken() async => calls.add('deleteToken');

  @override
  Stream<PushMessage> get foregroundMessages => const Stream.empty();

  @override
  Stream<PushMessage> get openedMessages => const Stream.empty();

  @override
  Future<PushMessage?> initialMessage() async => null;
}

class FakePushDevicesApi implements PushDevicesApi {
  final registered = <String>[];
  final unregistered = <String>[];

  @override
  Future<void> register(String token) async => registered.add(token);

  @override
  Future<void> unregister(String token) async => unregistered.add(token);
}

void main() {
  late FakePush push;
  late FakePushDevicesApi api;
  late InMemorySecureStore store;

  ProviderContainer start() {
    final c = ProviderContainer(overrides: [
      pushMessagingProvider.overrideWithValue(push),
      pushDevicesApiProvider.overrideWithValue(api),
      devicePreferencesProvider.overrideWithValue(DevicePreferences(store)),
    ]);
    addTearDown(c.dispose);
    c.listen(notificationsControllerProvider, (_, _) {});
    return c;
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() {
    push = FakePush();
    api = FakePushDevicesApi();
    store = InMemorySecureStore();
  });

  test('a signed-in phone asks once and registers its token', () async {
    final c = start();
    await settle();

    expect(push.calls, ['permission']);
    expect(api.registered, ['fcm-1']);
    expect(c.read(notificationsControllerProvider), NotificationStatus.on);

    push.refreshes.add('fcm-2');
    await settle();
    expect(api.registered, ['fcm-1', 'fcm-2']);
  });

  test('when the phone blocks notifications, nothing is registered', () async {
    push.allow = false;
    final c = start();
    await settle();

    expect(c.read(notificationsControllerProvider), NotificationStatus.blocked);
    expect(api.registered, isEmpty);
  });

  test('turning notifications off unregisters and stays off', () async {
    final c = start();
    await settle();

    await c.read(notificationsControllerProvider.notifier).setEnabled(false);
    expect(c.read(notificationsControllerProvider), NotificationStatus.off);
    expect(api.unregistered, ['fcm-1']);
    expect(push.calls, contains('deleteToken'));
    expect(await DevicePreferences(store).readNotificationsEnabled(), isFalse);

    final again = start();
    await settle();
    expect(again.read(notificationsControllerProvider), NotificationStatus.off);
    expect(api.registered, ['fcm-1']);
  });

  test('builds without Firebase have no notifications', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(notificationsControllerProvider), NotificationStatus.unavailable);
  });

  test('the server sends app paths', () {
    expect(const PushMessage(url: '/desk').route, Routes.desk);
    expect(const PushMessage(url: '/').route, Routes.home);
    expect(const PushMessage(url: '').route, Routes.home);
  });

  testWidgets('signing out clears a banner left on screen', (tester) async {
    final c = ProviderContainer(overrides: [
      pushMessagingProvider.overrideWithValue(push),
      pushDevicesApiProvider.overrideWithValue(api),
      devicePreferencesProvider.overrideWithValue(DevicePreferences(store)),
    ]);
    addTearDown(c.dispose);
    final key = c.read(scaffoldMessengerKeyProvider);
    await tester.pumpWidget(MaterialApp(scaffoldMessengerKey: key, home: const Scaffold()));
    final watching = c.listen(notificationsControllerProvider, (_, _) {});
    await tester.pump();

    key.currentState!.showSnackBar(SnackBar(
      content: const Text('Today at Test Gym'),
      action: SnackBarAction(label: 'View', onPressed: () {}),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Today at Test Gym'), findsOneWidget);

    watching.close(); // the app stops watching it when signed out
    await tester.pumpAndSettle();
    expect(find.text('Today at Test Gym'), findsNothing);
  });
}
