// theme_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ColorBlindnessType {
  none,
  protanopia,
  deuteranopia,
  tritanopia,
  achromatopsia
}

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  ColorBlindnessType _colorBlindnessType = ColorBlindnessType.none;
  double _severity = 0.5; // Rango de 0 a 1

  ThemeProvider() {
    _loadTheme();
    _loadColorBlindnessSettings();
  }

  ThemeMode get themeMode => _themeMode;
  ColorBlindnessType get colorBlindnessType => _colorBlindnessType;
  double get severity => _severity;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt('themeMode') ?? ThemeMode.system.index;
    _themeMode = ThemeMode.values[themeIndex];
    notifyListeners();
  }

  Future<void> _loadColorBlindnessSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final typeIndex = prefs.getInt('colorBlindnessType') ?? ColorBlindnessType.none.index;
    _colorBlindnessType = ColorBlindnessType.values[typeIndex];
    _severity = prefs.getDouble('colorBlindnessSeverity') ?? 0.5;
    notifyListeners();
  }

  Future<void> toggleTheme(bool isOn) async {
    _themeMode = isOn ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeMode', _themeMode.index);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeMode', mode.index);
  }

  Future<void> setColorBlindness({
    required ColorBlindnessType type,
    required double severity,
  }) async {
    _colorBlindnessType = type;
    _severity = severity.clamp(0.0, 1.0);
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('colorBlindnessType', type.index);
    await prefs.setDouble('colorBlindnessSeverity', _severity);
  }
}