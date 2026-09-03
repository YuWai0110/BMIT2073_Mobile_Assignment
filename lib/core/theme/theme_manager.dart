import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeManager extends ChangeNotifier {
  ThemeManager(this._preferences) {
    final saved = _preferences.getString(preferenceKey);
    _themeMode = ThemeMode.values.firstWhere(
      (mode) => mode.name == saved,
      orElse: () => ThemeMode.system,
    );
  }

  static const preferenceKey = 'theme_mode';
  final SharedPreferences _preferences;
  late ThemeMode _themeMode;
  Future<void> _pendingWrite = Future.value();

  ThemeMode get themeMode => _themeMode;

  Future<bool> setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
    final result = _pendingWrite.then((_) async {
      try {
        return await _preferences.setString(preferenceKey, mode.name);
      } catch (_) {
        return false;
      }
    });
    _pendingWrite = result.then((_) {});
    return result;
  }
}
