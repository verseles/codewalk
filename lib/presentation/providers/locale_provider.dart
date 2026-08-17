import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../core/i18n/app_locales.dart';
import '../../core/logging/app_logger.dart';
import 'settings_provider.dart';

class LocaleProvider extends ChangeNotifier {
  LocaleProvider({required SettingsProvider settingsProvider})
    : _settingsProvider = settingsProvider;

  final SettingsProvider _settingsProvider;

  String? _localeCode;
  Future<void>? _initFuture;

  String? get localeCode => _localeCode;
  Locale? get effectiveLocale => AppLocales.localeForCode(_localeCode);

  Future<void> initialize() async {
    _initFuture ??= _initializeInternal();
    await _initFuture;
  }

  Future<void> _initializeInternal() async {
    await _settingsProvider.initialize();
    _localeCode = _settingsProvider.localeCode;
    _settingsProvider.addListener(_handleSettingsChanged);
    notifyListeners();
  }

  @override
  void dispose() {
    _settingsProvider.removeListener(_handleSettingsChanged);
    super.dispose();
  }

  Future<void> setLocaleCode(String? code) async {
    final normalized = _normalizeLocaleCode(code);
    if (_localeCode == normalized) {
      return;
    }
    _localeCode = normalized;
    notifyListeners();
    await _settingsProvider.setLocaleCode(normalized);
  }

  static String? _normalizeLocaleCode(String? code) {
    final value = code?.trim().toLowerCase();
    if (value == null || value.isEmpty) {
      return null;
    }
    return AppLocales.infoForCode(value)?.code;
  }

  void _handleSettingsChanged() {
    try {
      final next = _normalizeLocaleCode(_settingsProvider.localeCode);
      if (_localeCode == next) {
        return;
      }
      _localeCode = next;
      notifyListeners();
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Settings listener failed in locale provider',
        error: error,
        stackTrace: stackTrace,
        tags: const <String>{'settings:listener', 'locale'},
      );
    }
  }
}
