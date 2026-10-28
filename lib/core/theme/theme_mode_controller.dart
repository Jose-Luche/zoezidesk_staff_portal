import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/device_preferences.dart';

/// The saved choice, read before the first frame (see main.dart) so the app
/// never flashes the wrong theme. Dark is the default.
final initialThemeModeProvider = Provider<ThemeMode>((_) => ThemeMode.dark);

/// App-wide theme choice: dark, light, or match the phone.
class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.watch(initialThemeModeProvider);

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref.read(devicePreferencesProvider).writeThemeMode(mode);
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);
