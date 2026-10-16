import 'package:flutter/material.dart';
import '../../data/repositories/settings_repository.dart';

/// Provider managing active ThemeMode (Light, Dark, System) backed by SQLite persistence.
class ThemeProvider extends ChangeNotifier {
  final SettingsRepository _settingsRepo;
  ThemeMode _themeMode = ThemeMode.system;

  ThemeProvider({SettingsRepository? settingsRepo})
      : _settingsRepo = settingsRepo ?? SettingsRepository() {
    _loadPersistedTheme();
  }

  ThemeMode get themeMode => _themeMode;

  bool isDark(BuildContext context) {
    if (_themeMode == ThemeMode.system) {
      return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  Future<void> _loadPersistedTheme() async {
    try {
      final saved = await _settingsRepo.getSetting('theme_mode');
      if (saved == 'dark') {
        _themeMode = ThemeMode.dark;
      } else if (saved == 'light') {
        _themeMode = ThemeMode.light;
      } else {
        _themeMode = ThemeMode.system;
      }
      notifyListeners();
    } catch (_) {}
  }

  /// Updates active theme and saves preference to SQLite
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    try {
      await _settingsRepo.setSetting('theme_mode', mode.name);
    } catch (_) {}
  }

  /// 1-tap toggle between Light and Dark mode
  Future<void> toggleTheme(BuildContext context) async {
    final isCurrentlyDark = isDark(context);
    final newMode = isCurrentlyDark ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(newMode);
  }
}
