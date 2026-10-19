import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppThemeController {
  static const _key = 'hps_theme_mode';
  static final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.light);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    mode.value = prefs.getString(_key) == 'dark' ? ThemeMode.dark : ThemeMode.light;
  }

  static Future<void> setMode(ThemeMode value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, value == ThemeMode.dark ? 'dark' : 'light');
    mode.value = value;
  }
}