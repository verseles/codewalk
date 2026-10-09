import 'dart:convert';

import 'package:flutter/material.dart';

import '../platform/storage/metadata_store.dart';
import '../shared/diagnostics/diagnostics_controller.dart';
import '../shared/shortcuts/shortcut_action.dart';
import '../shared/shortcuts/shortcut_binding_codec.dart';
import '../shared/theme/opencode_theme_preferences.dart';
import '../shared/theme/theme_preferences.dart';

/// Appearance uses only the v2 metadata namespace; locale remains transient.
class AppPreferencesController extends ChangeNotifier {
  AppPreferencesController({
    V2MetadataStore? store,
    DiagnosticsController? diagnostics,
  }) : _store = store,
       _diagnostics = diagnostics;

  final V2MetadataStore? _store;
  final DiagnosticsController? _diagnostics;
  bool _loggingEnabled = false;
  bool _loggingHydrated = false;
  bool get loggingEnabled => _loggingEnabled;

  void setLoggingEnabled(bool value) {
    if (_disposed || _loggingEnabled == value) return;
    _loggingEnabled = value;
    _diagnostics?.setEnabled(value);
    _changed('loggingEnabled');
  }

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
  bool _shortcutLoadFailed = false;
  bool _hasPhysicalKeyboard = false;
  Map<String, dynamic> _shortcutOverrides = {};
  final Map<String, String?> _shortcutEdits = {};
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
  bool get hasPersistenceError =>
      _loadFailed || _shortcutLoadFailed || _failedKeys.isNotEmpty;
  bool get isDisposed => _disposed;
  bool get hasPhysicalKeyboard => _hasPhysicalKeyboard;

  String shortcutBindingFor(ShortcutAction action) {
    if (!_shortcutOverrides.containsKey(action.key)) {
      return action.defaultBinding;
    }
    final value = _shortcutOverrides[action.key];
    return value is String ? value : '';
  }

  bool shortcutIsInvalid(ShortcutAction action) =>
      (_shortcutOverrides.containsKey(action.key) &&
          _shortcutOverrides[action.key] is! String) ||
      (shortcutBindingFor(action).isNotEmpty &&
          ShortcutBindingCodec.parse(shortcutBindingFor(action)) == null);

  ShortcutAction? shortcutConflict(ShortcutAction action, String binding) {
    final fingerprint = ShortcutBindingCodec.fingerprint(binding);
    if (fingerprint == null) return null;
    for (final other in ShortcutAction.values) {
      if (other != action &&
          fingerprint ==
              ShortcutBindingCodec.fingerprint(shortcutBindingFor(other))) {
        return other;
      }
    }
    return null;
  }

  /// Empty disables an action; null resets its override to the portable default.
  void setShortcutBinding(ShortcutAction action, String? binding) {
    if (_disposed) return;
    if (binding != null && binding.length > 128) {
      throw ArgumentError('Oversized shortcut');
    }
    final normalized = binding == null
        ? null
        : ShortcutBindingCodec.normalize(binding);
    if (normalized != null &&
        normalized.isNotEmpty &&
        (ShortcutBindingCodec.parse(normalized) == null ||
            shortcutConflict(action, normalized) != null)) {
      throw ArgumentError('Invalid or conflicting shortcut');
    }
    _shortcutEdits[action.key] = normalized;
    if (normalized == null) {
      _shortcutOverrides.remove(action.key);
    } else {
      _shortcutOverrides[action.key] = normalized;
    }
    _changed('shortcuts');
  }

  void resetAllShortcuts() {
    if (_disposed) return;
    for (final action in ShortcutAction.values) {
      _shortcutEdits[action.key] = null;
      _shortcutOverrides.remove(action.key);
    }
    _changed('shortcuts');
  }

  void observePhysicalKeyboard() {
    if (_disposed || _hasPhysicalKeyboard) return;
    _hasPhysicalKeyboard = true;
    notifyListeners();
  }

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
    'loggingEnabled': _loggingEnabled,
    // Shortcut JSON is serialized after hydration, preserving unknown fields.
    'shortcuts': null,
  };

  Future<void> initialize() => _initialization ??= _load();

  Future<void> _load() async {
    final store = _store;
    if (store == null || _disposed) return;
    _shortcutLoadFailed = true;
    final revisions = Map<String, int>.of(_revisions);
    try {
      await store.ensureSchema();
      final values = <String, Object?>{};
      for (final key in _values.keys) {
        values[key] = await store.read('cw2.settings.$key');
      }
      // Accepted shortcut writes must still merge their snapshot after disposal.
      _hydrateShortcuts(values['shortcuts']);
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
      final logging = value('loggingEnabled');
      if (logging is bool) _loggingEnabled = logging;
      _loggingHydrated = true;
      _diagnostics?.setEnabled(_loggingEnabled);
      _loadFailed = false;
      _diagnostics?.record(
        DiagnosticOperation.preferencesLoad,
        DiagnosticOutcome.success,
      );
      notifyListeners();
    } catch (_) {
      if (_disposed) return;
      _loadFailed = true;
      // Cold failure grants no consent; a failed reload preserves known intent.
      if (!_loggingHydrated && !_revisions.containsKey('loggingEnabled')) {
        _loggingEnabled = false;
        _diagnostics?.setEnabled(false);
      }
      _diagnostics?.record(
        DiagnosticOperation.preferencesLoad,
        DiagnosticOutcome.failure,
        severity: DiagnosticSeverity.error,
      );
      notifyListeners();
    }
  }

  void _hydrateShortcuts(Object? raw) {
    try {
      var loaded = <String, dynamic>{};
      if (raw != null) {
        if (raw is! String || raw.length > V2MetadataStore.maxPreferenceChars) {
          throw const FormatException('Invalid shortcut metadata');
        }
        final decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Invalid shortcut metadata');
        }
        loaded = decoded;
      }
      for (final edit in _shortcutEdits.entries) {
        if (edit.value == null) {
          loaded.remove(edit.key);
        } else {
          loaded[edit.key] = edit.value;
        }
      }
      _shortcutOverrides = loaded;
      _shortcutLoadFailed = false;
    } on FormatException {
      // Do not turn an unrelated edit into destruction of unreadable metadata.
      _shortcutLoadFailed = true;
    }
  }

  Future<bool> _persistShortcuts() async {
    await initialize();
    if (_shortcutLoadFailed) {
      throw const FormatException('Shortcut metadata could not be loaded');
    }
    final store = _store!;
    return _shortcutOverrides.isEmpty
        ? store.remove('cw2.settings.shortcuts')
        : store.write('cw2.settings.shortcuts', jsonEncode(_shortcutOverrides));
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
    final operation = key == 'shortcuts'
        ? _persistShortcuts()
        : value == null
        ? store.remove('cw2.settings.$key')
        : store.write('cw2.settings.$key', value);
    late final Future<void> pending;
    pending = operation
        .then<void>(
          (_) {
            if (_disposed || _revisions[key] != revision) return;
            _diagnostics?.record(
              DiagnosticOperation.preferencesSave,
              DiagnosticOutcome.success,
            );
            if (_failedKeys.remove(key)) notifyListeners();
          },
          onError: (Object _, StackTrace _) {
            if (_disposed || _revisions[key] != revision) return;
            _diagnostics?.record(
              DiagnosticOperation.preferencesSave,
              DiagnosticOutcome.failure,
              severity: DiagnosticSeverity.error,
            );
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
    if (_loadFailed || _shortcutLoadFailed) {
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
