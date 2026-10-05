import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// App-wide light/dark mode, same idea as [AppLang] in l10n.dart — a
/// toggle the customer can flip that changes the whole app, and that
/// survives closing and reopening the app.
class AppTheme {
  static final ValueNotifier<ThemeMode> notifier = ValueNotifier<ThemeMode>(ThemeMode.light);
  static const _storage = FlutterSecureStorage();
  static const _key = 'app_theme_mode';

  static Future<void> load() async {
    try {
      final v = await _storage.read(key: _key);
      if (v == 'dark') notifier.value = ThemeMode.dark;
    } catch (_) {}
  }

  static Future<void> toggle() async {
    notifier.value = notifier.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    try { await _storage.write(key: _key, value: notifier.value == ThemeMode.dark ? 'dark' : 'light'); } catch (_) {}
  }

  static bool get isDark => notifier.value == ThemeMode.dark;
}
