import 'package:flutter/material.dart';

import '../platform/storage/metadata_store.dart';
import '../shared/theme/opencode_theme_preferences.dart';
import '../shared/theme/theme_preferences.dart';

/// Appearance uses only the v2 metadata namespace; locale remains transient.
class AppPreferencesController extends ChangeNotifier {
  AppPreferencesController({V2MetadataStore? store}) : _store = store;

  final V2MetadataStore? _store;
  ThemeMode _themeMode = ThemeMode.system;
  Locale? _locale;
  AppDensity _density = AppDensity.normal;
  VisualStyle _visualStyle = VisualStyle.refined;
  OpenCodeThemePreset? _themePreset;
  int? _customColorSeed;
  double _contrastLevel = 0;
  bool _useAmoledDark = false;
  bool _useDynamicColor = true;
  bool _dynamicColorAvailable = false;
  bool _disposed = false;
  bool _loadFailed = false;
  Future<void>? _initialization;
  final Map<String, int> _revisions = {};
  final Set<String> _failedKeys = {};
  final Set<Future<void>> _pending = {};

  ThemeMode get themeMode => _themeMode;
  Locale? get locale => _locale;
  AppDensity get density => _density;
  VisualStyle get visualStyle => _visualStyle;
  OpenCodeThemePreset? get themePreset => _themePreset;
  int? get customColorSeed => _customColorSeed;
  double get contrastLevel => _contrastLevel;
  bool get useAmoledDark => _useAmoledDark;
  bool get useDynamicColor => _useDynamicColor;
  bool get dynamicColorAvailable => _dynamicColorAvailable;
  bool get hasPersistenceError => _loadFailed || _failedKeys.isNotEmpty;
  bool get isDisposed => _disposed;

  Map<String, Object?> get _values => {
    'themeMode': _themeMode.name,
    'visualStyle': _visualStyle.name,
    'themePreset': _themePreset == null
        ? null
        : openCodeThemePresetKey(_themePreset!),
    'appDensity': switch (_density) {
      AppDensity.extraDense => 'extra_dense',
      AppDensity.extraSpacious => 'extra_spacious',
      _ => _density.name,
    },
    'customColorSeed': _customColorSeed,
    'contrastLevel': _contrastLevel,
    'useAmoledDark': _useAmoledDark,
    'useDynamicColor': _useDynamicColor,
  };

  Future<void> initialize() => _initialization ??= _load();

  Future<void> _load() async {
    final store = _store;
    if (store == null || _disposed) return;
    final revisions = Map<String, int>.of(_revisions);
    try {
      await store.ensureSchema();
      final values = <String, Object?>{};
      for (final key in _values.keys) {
        values[key] = await store.read('cw2.settings.$key');
      }
      if (_disposed) return;
      // A choice made while storage was loading always wins over the snapshot.
      Object? value(String key) =>
          revisions[key] == null && _revisions[key] == null
          ? values[key]
          : null;
      final mode = value('themeMode');
      if (mode is String) {
        _themeMode = ThemeMode.values.firstWhere(
          (m) => m.name == mode,
          orElse: () => ThemeMode.system,
        );
      }
      final style = value('visualStyle');
      if (style is String) {
        _visualStyle = style.trim().toLowerCase() == 'refined'
            ? VisualStyle.refined
            : VisualStyle.classic;
      }
      final preset = value('themePreset');
      if (preset is String) _themePreset = openCodeThemePresetFromKey(preset);
      final density = value('appDensity');
      if (density is String) {
        _density = switch (density) {
          'extra_dense' => AppDensity.extraDense,
          'extra_spacious' => AppDensity.extraSpacious,
          'dense' => AppDensity.dense,
          'spacious' => AppDensity.spacious,
          _ => AppDensity.normal,
        };
      }
      final seed = value('customColorSeed');
      if (seed is num && seed.isFinite && seed >= 0 && seed <= 0xFFFFFFFF) {
        _customColorSeed = seed.toInt();
      }
      final contrast = value('contrastLevel');
      if (contrast is num && contrast.isFinite) {
        _contrastLevel = contrast.toDouble().clamp(-1, 1);
      }
      final amoled = value('useAmoledDark');
      if (amoled is bool) _useAmoledDark = amoled;
      final dynamic = value('useDynamicColor');
      if (dynamic is bool) _useDynamicColor = dynamic;
      _loadFailed = false;
      notifyListeners();
    } catch (_) {
      if (_disposed) return;
      _loadFailed = true;
      notifyListeners();
    }
  }

  void _changed(String key) {
    final revision = (_revisions[key] ?? 0) + 1;
    _revisions[key] = revision;
    _persist(key, _values[key], revision);
    notifyListeners();
  }

  void _persist(String key, Object? value, int revision) {
    final store = _store;
    if (store == null) return;
    final operation = value == null
        ? store.remove('cw2.settings.$key')
        : store.write('cw2.settings.$key', value);
    late final Future<void> pending;
    pending = operation
        .then<void>(
          (_) {
            if (_disposed || _revisions[key] != revision) return;
            if (_failedKeys.remove(key)) notifyListeners();
          },
          onError: (Object _, StackTrace _) {
            if (_disposed || _revisions[key] != revision) return;
            if (_failedKeys.add(key)) notifyListeners();
          },
        )
        .whenComplete(() => _pending.remove(pending));
    _pending.add(pending);
  }

  Future<void> flush() async {
    while (_pending.isNotEmpty) {
      await Future.wait(_pending.toList());
    }
  }

  Future<void> retryPersistence() async {
    if (_disposed) return;
    if (_loadFailed) {
      _initialization = null;
      await initialize();
    }
    if (_disposed) return;
    for (final key in _failedKeys.toList()) {
      _persist(key, _values[key], _revisions[key] ?? 0);
    }
    await flush();
  }

  void setThemeMode(ThemeMode value) {
    if (_disposed || _themeMode == value) return;
    _themeMode = value;
    _changed('themeMode');
  }

  void setLocale(Locale? value) {
    if (_disposed || _locale == value) return;
    _locale = value;
    notifyListeners();
  }

  void setDensity(AppDensity value) {
    if (_disposed || _density == value) return;
    _density = value;
    _changed('appDensity');
  }

  void setVisualStyle(VisualStyle value) {
    if (_disposed || _visualStyle == value) return;
    _visualStyle = value;
    _changed('visualStyle');
  }

  void setThemePreset(OpenCodeThemePreset? value) {
    if (_disposed || _themePreset == value) return;
    _themePreset = value;
    _changed('themePreset');
  }

  void setCustomColorSeed(int? value) {
    if (value != null && (value < 0 || value > 0xFFFFFFFF)) {
      throw ArgumentError.value(value);
    }
    if (_disposed || _customColorSeed == value) return;
    _customColorSeed = value;
    _changed('customColorSeed');
  }

  void setContrastLevel(double value) {
    if (!value.isFinite) throw ArgumentError.value(value);
    value = value.clamp(-1, 1);
    if (_disposed || _contrastLevel == value) return;
    _contrastLevel = value;
    _changed('contrastLevel');
  }

  void setUseAmoledDark(bool value) {
    if (_disposed || _useAmoledDark == value) return;
    _useAmoledDark = value;
    _changed('useAmoledDark');
  }

  void setUseDynamicColor(bool value) {
    if (_disposed || _useDynamicColor == value) return;
    _useDynamicColor = value;
    _changed('useDynamicColor');
  }

  void setDynamicColorAvailable(bool value) {
    if (_disposed || _dynamicColorAvailable == value) return;
    _dynamicColorAvailable = value;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    super.dispose();
  }
}
