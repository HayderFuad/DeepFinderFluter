import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

/// Manages Light & Dark Mode switching and persists the user's choice in `shared_preferences`.
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  static const String _prefKey = 'deepfinder_v1_theme_mode';

  ThemeModeNotifier() : super(ThemeMode.light) {
    _loadSavedTheme();
  }

  Future<void> _loadSavedTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_prefKey) ?? false;
    state = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> toggleTheme() async {
    final nextMode =
        state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    state = nextMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, nextMode == ThemeMode.dark);
  }
}
