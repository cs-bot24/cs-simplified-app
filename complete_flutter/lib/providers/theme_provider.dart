import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const _key = 'theme_mode';
  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;

  String get label {
    switch (_mode) {
      case ThemeMode.light:  return 'Light';
      case ThemeMode.dark:   return 'Dark';
      default:               return 'System';
    }
  }

  String get emoji {
    switch (_mode) {
      case ThemeMode.light:  return '☀️';
      case ThemeMode.dark:   return '🌙';
      default:               return '📱';
    }
  }

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key) ?? 'system';
    _mode = _fromString(saved);
    notifyListeners();
  }

  Future<void> setTheme(ThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _toString(mode));
  }

  ThemeMode _fromString(String s) {
    switch (s) {
      case 'light':  return ThemeMode.light;
      case 'dark':   return ThemeMode.dark;
      default:       return ThemeMode.system;
    }
  }

  String _toString(ThemeMode m) {
    switch (m) {
      case ThemeMode.light:  return 'light';
      case ThemeMode.dark:   return 'dark';
      default:               return 'system';
    }
  }
}
