import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// StateNotifier for managing theme mode
class ThemeNotifier extends StateNotifier<ThemeMode> {
  final SharedPreferences _prefs;
  static const String _key = 'themeMode';

  ThemeNotifier(this._prefs) : super(ThemeMode.dark) {
    _loadThemePreference();
  }

  /// Load theme preference from persistent storage
  void _loadThemePreference() {
    final themeModeString = _prefs.getString(_key);
    if (themeModeString != null) {
      state = ThemeMode.values.firstWhere(
        (mode) => mode.toString() == themeModeString,
        orElse: () => ThemeMode.dark,
      );
    }
  }

  /// Change the theme mode and persist it
  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await _prefs.setString(_key, mode.toString());
  }

  /// Toggle between light and dark mode
  Future<void> toggleTheme() async {
    final newMode = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    await setThemeMode(newMode);
  }
}
