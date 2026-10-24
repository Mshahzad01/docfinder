import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tiny wrapper over SharedPreferences for UI settings.
class SettingsService {
  SettingsService(this._prefs);
  final SharedPreferences _prefs;

  static Future<SettingsService> load() async =>
      SettingsService(await SharedPreferences.getInstance());

  ThemeMode get themeMode => switch (_prefs.getString('themeMode')) {
        'dark' => ThemeMode.dark,
        'light' => ThemeMode.light,
        _ => ThemeMode.system,
      };
  Future<void> setThemeMode(ThemeMode m) => _prefs.setString('themeMode', m.name);

  bool get gridView => _prefs.getBool('gridView') ?? false;
  Future<void> setGridView(bool v) => _prefs.setBool('gridView', v);
}
