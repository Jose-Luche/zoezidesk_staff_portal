import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/storage/device_preferences.dart';
import 'core/storage/session_storage.dart';
import 'core/theme/theme_mode_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!Env.isConfigured) {
    throw StateError(
      'API_BASE_URL is not set. Run with '
      '--dart-define-from-file=env/dev.json (see env/example.json).',
    );
  }

  // Before the first frame, so a light-theme choice never flashes dark.
  ThemeMode? themeMode;
  try {
    themeMode = await const DevicePreferences(FlutterSecureStore()).readThemeMode();
  } catch (_) {
    // Unreadable storage: use the default.
  }

  runApp(ProviderScope(
    overrides: [
      if (themeMode != null) initialThemeModeProvider.overrideWithValue(themeMode),
    ],
    child: const ZoeziStaffApp(),
  ));
}
