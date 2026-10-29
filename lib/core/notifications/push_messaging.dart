import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import '../router/routes.dart';

/// A notification from the server: what the staff member reads, and the
/// app screen it is about (`data.url`).
class PushMessage {
  const PushMessage({this.title, this.body, required this.url});

  final String? title;
  final String? body;
  final String url;

  /// The server sends app paths. The router sends a tab this staff member
  /// doesn't have to their first tab.
  String get route => url.startsWith('/') && url != '/' ? url : Routes.home;
}

/// What the app needs from Firebase Cloud Messaging, so tests can replace it.
abstract interface class PushMessaging {
  /// False when the build has no Firebase project or it failed to start.
  bool get available;

  /// Asks to show notifications (Android 13+ shows a dialog once).
  Future<bool> requestPermission();

  Future<String?> getToken();

  Stream<String> get tokenRefresh;

  /// A new token is made next time, so the phone is not reachable by the
  /// old one.
  Future<void> deleteToken();

  /// Messages that arrive while the app is open (Android shows nothing).
  Stream<PushMessage> get foregroundMessages;

  /// Notifications tapped while the app was in the background.
  Stream<PushMessage> get openedMessages;

  /// The notification whose tap started the app, once.
  Future<PushMessage?> initialMessage();
}

/// Starts Firebase before the app runs. Returns whether it is usable.
Future<bool> initializeFirebase() async {
  if (!Env.hasFirebase) return false;
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: Env.firebaseApiKey,
        appId: Env.firebaseAppId,
        messagingSenderId: Env.firebaseSenderId,
        projectId: Env.firebaseProjectId,
      ),
    );
    return true;
  } catch (_) {
    // No Google Play services, or a bad config: run without notifications.
    return false;
  }
}

/// Uses FCM registration tokens, which the server targets with
/// `message.token` (HTTP v1). firebase_messaging 17 deprecates them in
/// favour of installation IDs (`register()`/`onRegistered`); moving needs
/// the server to send to those instead, so it is left for a later change.
// ignore_for_file: deprecated_member_use
class FirebasePushMessaging implements PushMessaging {
  FirebasePushMessaging([FirebaseMessaging? messaging])
      : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  @override
  bool get available => true;

  @override
  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<String?> getToken() => _messaging.getToken();

  @override
  Stream<String> get tokenRefresh => _messaging.onTokenRefresh;

  @override
  Future<void> deleteToken() => _messaging.deleteToken();

  @override
  Stream<PushMessage> get foregroundMessages => FirebaseMessaging.onMessage.map(_toMessage);

  @override
  Stream<PushMessage> get openedMessages => FirebaseMessaging.onMessageOpenedApp.map(_toMessage);

  @override
  Future<PushMessage?> initialMessage() async {
    final message = await _messaging.getInitialMessage();
    return message == null ? null : _toMessage(message);
  }

  static PushMessage _toMessage(RemoteMessage m) => PushMessage(
        title: m.notification?.title,
        body: m.notification?.body,
        url: m.data['url'] as String? ?? '',
      );
}

/// Used when the build has no Firebase project.
class UnavailablePushMessaging implements PushMessaging {
  const UnavailablePushMessaging();

  @override
  bool get available => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<String?> getToken() async => null;

  @override
  Stream<String> get tokenRefresh => const Stream.empty();

  @override
  Future<void> deleteToken() async {}

  @override
  Stream<PushMessage> get foregroundMessages => const Stream.empty();

  @override
  Stream<PushMessage> get openedMessages => const Stream.empty();

  @override
  Future<PushMessage?> initialMessage() async => null;
}

/// Overridden in main.dart once Firebase has started.
final pushMessagingProvider =
    Provider<PushMessaging>((_) => const UnavailablePushMessaging());
