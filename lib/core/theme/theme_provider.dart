import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ══════════════════════════════════════════════════════════════════
//  ScanGo Tech Theme Provider
//  Manages ThemeMode with persistence via SharedPreferences.
//  Default: ThemeMode.dark (technicians work outdoors, dark is default)
// ══════════════════════════════════════════════════════════════════

const _kThemePrefKey = 'scango_tech_theme_mode';

class TechThemeNotifier extends StateNotifier<ThemeMode> {
  TechThemeNotifier() : super(ThemeMode.dark) {
    _loadPersistedTheme();
  }

  Future<void> _loadPersistedTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMode = prefs.getString(_kThemePrefKey);
      if (savedMode == 'light') {
        state = ThemeMode.light;
      } else {
        state = ThemeMode.dark;
      }
    } catch (_) {
      state = ThemeMode.dark;
    }
  }

  Future<void> toggleTheme() async {
    final newMode = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    state = newMode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kThemePrefKey, newMode == ThemeMode.dark ? 'dark' : 'light');
    } catch (_) {}
  }

  bool get isDark => state == ThemeMode.dark;
}

final themeProvider = StateNotifierProvider<TechThemeNotifier, ThemeMode>(
  (ref) => TechThemeNotifier(),
);
