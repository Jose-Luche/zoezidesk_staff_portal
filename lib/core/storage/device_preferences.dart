import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'session_storage.dart';

/// Settings that belong to the phone, not the member (theme, whether to
/// show notifications). They are
/// kept in secure storage, like everything else the app stores, and
/// survive logout (see LocalDataWiper).
class DevicePreferences {
  const DevicePreferences(this._store);

  static const themeModeKey = 'pref_theme_mode';
  static const notificationsKey = 'pref_notifications';

  /// Keys LocalDataWiper keeps when it wipes secure storage.
  static const keys = [themeModeKey, notificationsKey];

  final SecureStore _store;

  Future<ThemeMode?> readThemeMode() async {
    final saved = await _store.read(themeModeKey);
    return ThemeMode.values.where((m) => m.name == saved).firstOrNull;
  }

  Future<void> writeThemeMode(ThemeMode mode) => _store.write(themeModeKey, mode.name);

  /// On unless the member turned notifications off on this phone.
  Future<bool> readNotificationsEnabled() async =>
      await _store.read(notificationsKey) != 'off';

  Future<void> writeNotificationsEnabled(bool enabled) =>
      _store.write(notificationsKey, enabled ? 'on' : 'off');
}

final devicePreferencesProvider =
    Provider<DevicePreferences>((ref) => DevicePreferences(ref.watch(secureStoreProvider)));
