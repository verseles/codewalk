import 'package:flutter/material.dart';

import '../shared/theme/theme_preferences.dart';

/// In-memory appearance choices. Durable settings belong to V2-027/V2-071.
class AppPreferencesController extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  Locale? _locale;
  AppDensity _density = AppDensity.normal;
  VisualStyle _visualStyle = VisualStyle.classic;
  bool _disposed = false;

  ThemeMode get themeMode => _themeMode;
  Locale? get locale => _locale;
  AppDensity get density => _density;
  VisualStyle get visualStyle => _visualStyle;
  bool get isDisposed => _disposed;

  void setThemeMode(ThemeMode value) {
    if (_themeMode == value) return;
    _themeMode = value;
    notifyListeners();
  }

  void setLocale(Locale? value) {
    if (_locale == value) return;
    _locale = value;
    notifyListeners();
  }

  void setDensity(AppDensity value) {
    if (_density == value) return;
    _density = value;
    notifyListeners();
  }

  void setVisualStyle(VisualStyle value) {
    if (_visualStyle == value) return;
    _visualStyle = value;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    super.dispose();
  }
}
