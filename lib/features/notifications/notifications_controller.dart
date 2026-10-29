import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/push_messaging.dart';
import '../../core/router/app_router.dart';
import '../../core/router/routes.dart';
import '../../core/storage/device_preferences.dart';
import '../../data/api/push_devices_api.dart';
import '../../shared/widgets/toast.dart';

enum NotificationStatus {
  /// This build has no Firebase project, or the phone cannot use it.
  unavailable,

  /// Turned off in Settings.
  off,

  /// Turned on, but the phone does not allow the app to notify.
  blocked,

  on,
}

/// Registers this phone for notifications while a staff member is signed
/// in on their own phone (the app watches it only then; never on the
/// front-desk device), opens the screen a tapped notification is
/// about, and shows a banner for ones that arrive while the app is open.
///
/// Registering is retried at the next app start when it fails (offline):
/// the server keeps phones until they log out or uninstall.
class NotificationsController extends Notifier<NotificationStatus> {
  final _subscriptions = <StreamSubscription<Object?>>[];
  bool _listening = false;

  PushMessaging get _push => ref.read(pushMessagingProvider);

  @override
  NotificationStatus build() {
    final toast = ref.read(toastProvider);
    ref.onDispose(() {
      for (final s in _subscriptions) {
        s.cancel();
      }
      // Signed out: one person's alert must not stay on screen for the next
      // (the phone may become the front-desk device).
      toast.clear();
    });
    if (!ref.watch(pushMessagingProvider).available) return NotificationStatus.unavailable;
    Future.microtask(_start);
    return NotificationStatus.off;
  }

  Future<void> _start() async {
    _listen();
    final enabled = await ref.read(devicePreferencesProvider).readNotificationsEnabled();
    if (!ref.mounted) return;
    if (enabled) await _enable();
    final initial = await _push.initialMessage();
    if (initial != null && ref.mounted) _open(initial);
  }

  /// From the Settings switch.
  Future<void> setEnabled(bool enabled) async {
    if (state == NotificationStatus.unavailable) return;
    await ref.read(devicePreferencesProvider).writeNotificationsEnabled(enabled);
    if (!ref.mounted) return;
    enabled ? await _enable() : await _disable();
  }

  Future<void> _enable() async {
    final push = _push;
    final api = ref.read(pushDevicesApiProvider);
    if (!await push.requestPermission()) {
      if (ref.mounted) state = NotificationStatus.blocked;
      return;
    }
    if (!ref.mounted) return;
    state = NotificationStatus.on;
    final token = await push.getToken();
    if (token != null) await _register(api, token);
  }

  Future<void> _disable() async {
    final push = _push;
    final api = ref.read(pushDevicesApiProvider);
    state = NotificationStatus.off;
    final token = await push.getToken();
    if (token != null) {
      try {
        await api.unregister(token);
      } catch (_) {
        // Offline: deleting the token below still stops delivery.
      }
    }
    await push.deleteToken();
  }

  Future<void> _register(PushDevicesApi api, String token) async {
    try {
      await api.register(token);
    } catch (_) {
      // Tried again at the next start.
    }
  }

  void _listen() {
    if (_listening) return;
    _listening = true;
    final push = _push;
    final api = ref.read(pushDevicesApiProvider);
    _subscriptions
      ..add(push.tokenRefresh.listen((token) {
        if (state == NotificationStatus.on) _register(api, token);
      }))
      ..add(push.openedMessages.listen(_open))
      ..add(push.foregroundMessages.listen(_showBanner));
  }

  /// A tab is opened directly; any other screen (a class roster) on top of
  /// the first tab, so Back has somewhere to go.
  void _open(PushMessage message) {
    final router = ref.read(routerProvider);
    final route = message.route;
    if (allTabs.any((t) => t.path == route)) {
      router.go(route);
    } else {
      router
        ..go(Routes.home)
        ..push(route);
    }
  }

  void _showBanner(PushMessage message) {
    final text = [message.title, message.body].whereType<String>().join(' · ');
    if (text.isEmpty) return;
    ref.read(toastProvider).show(text, actionLabel: 'View', onAction: () => _open(message), hold: const Duration(seconds: 6));
  }
}

/// Ends with the session: the next person to sign in registers afresh, and
/// the server already dropped this phone when the last one signed out.
final notificationsControllerProvider =
    NotifierProvider.autoDispose<NotificationsController, NotificationStatus>(
        NotificationsController.new);
