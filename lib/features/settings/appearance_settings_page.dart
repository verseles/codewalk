import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_preferences_controller.dart';
import '../../shared/l10n/generated/v2_localizations.dart';
import '../../shared/l10n/l10n_context.dart';
import '../../shared/theme/brand_colors.dart';
import '../../shared/theme/opencode_theme_preferences.dart';
import '../../shared/theme/opencode_theme_presets.dart';
import '../../shared/theme/theme_preferences.dart';
import '../../shared/widgets/searchable_picker.dart';

enum _ThemeFamily { classic, presets }

/// Ported appearance controls; the broader settings shell belongs to V2-071C.
class AppearanceSettingsPage extends StatelessWidget {
  const AppearanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppPreferencesController>();
    final l = context.v2L10n;
    final presetActive = p.themePreset != null;
    final dynamicActive = p.useDynamicColor && p.dynamicColorAvailable;
    final colorsEnabled = !presetActive && !dynamicActive;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final densityLabels = [
      l.settingsAppearanceDensityExtraDense,
      l.settingsAppearanceDensityDense,
      l.settingsAppearanceDensityNormal,
      l.settingsAppearanceDensitySpacious,
      l.settingsAppearanceDensityExtraSpacious,
    ];
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          key: const ValueKey('appearance_settings_list'),
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              l.settingsAppearanceSectionTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (p.hasPersistenceError)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.settingsStorageError),
                      TextButton(
                        onPressed: p.retryPersistence,
                        child: Text(l.chatRetry),
                      ),
                    ],
                  ),
                ),
              ),
            _card(context, l.settingsAppearanceTheme, [
              Text(l.settingsAppearanceThemeDescription),
              const SizedBox(height: 12),
              _choice<ThemeMode>(
                key: const ValueKey('settings_theme_mode_segmented'),
                label: l.settingsAppearanceTheme,
                value: p.themeMode,
                options: {
                  ThemeMode.system: l.settingsAppearanceSystem,
                  ThemeMode.light: l.settingsAppearanceLight,
                  ThemeMode.dark: l.settingsAppearanceDark,
                },
                onChanged: p.setThemeMode,
              ),
              const SizedBox(height: 12),
              _choice<_ThemeFamily>(
                key: const ValueKey('settings_theme_family_segmented'),
                label: l.settingsAppearancePresetPalette,
                value: presetActive
                    ? _ThemeFamily.presets
                    : _ThemeFamily.classic,
                options: {
                  _ThemeFamily.classic: l.settingsAppearanceCodeWalkClassic,
                  _ThemeFamily.presets: l.settingsAppearanceOpenCodePresets,
                },
                onChanged: (family) => p.setThemePreset(
                  family == _ThemeFamily.classic
                      ? null
                      : kDefaultOpenCodeThemePreset,
                ),
              ),
              if (presetActive) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  key: const ValueKey('settings_theme_preset_dropdown'),
                  onPressed: () => _pickPreset(context, p),
                  child: Text(
                    '${l.settingsAppearancePresetPalette}: ${openCodeThemePresetLabel(p.themePreset!)}',
                  ),
                ),
                Text(
                  l.settingsAppearancePresetHelper,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 12),
              Text(
                l.settingsAppearanceVisualStyle,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(l.settingsAppearanceVisualStyleDescription),
              const SizedBox(height: 8),
              _choice<VisualStyle>(
                key: const ValueKey('settings_visual_style_segmented'),
                label: l.settingsAppearanceVisualStyle,
                value: p.visualStyle,
                options: {
                  VisualStyle.classic: l.settingsAppearanceVisualStyleClassic,
                  VisualStyle.refined: l.settingsAppearanceVisualStyleRefined,
                },
                onChanged: p.setVisualStyle,
              ),
              SwitchListTile.adaptive(
                key: const ValueKey('settings_toggle_amoled_dark'),
                contentPadding: EdgeInsets.zero,
                title: Text(l.settingsAppearanceAmoledDark),
                subtitle: Text(
                  dark
                      ? l.settingsAppearanceAmoledDarkActive
                      : l.settingsAppearanceAmoledDarkInactive,
                ),
                value: p.useAmoledDark,
                onChanged: dark ? p.setUseAmoledDark : null,
              ),
            ]),
            _card(context, l.settingsAppearanceBrandColor, [
              if (p.dynamicColorAvailable)
                SwitchListTile.adaptive(
                  key: const ValueKey('settings_toggle_dynamic_color'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.settingsAppearanceWallpaperColors),
                  subtitle: Text(
                    presetActive
                        ? l.settingsAppearanceWallpaperPresetBlocked
                        : l.settingsAppearanceWallpaperNormal,
                  ),
                  value: p.useDynamicColor,
                  onChanged: presetActive ? null : p.setUseDynamicColor,
                ),
              Text(
                presetActive
                    ? l.settingsAppearanceBrandColorPresetBlocked
                    : dynamicActive
                    ? l.settingsAppearanceBrandColorDynamicBlocked
                    : l.settingsAppearanceBrandColorNormal,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final color in BrandColor.values)
                    FilterChip(
                      key: ValueKey('settings_brand_${color.name}'),
                      label: Text(color.label),
                      avatar: CircleAvatar(backgroundColor: color.seed),
                      selected: p.customColorSeed == color.value,
                      onSelected: colorsEnabled
                          ? (selected) => p.setCustomColorSeed(
                              selected ? color.value : null,
                            )
                          : null,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '${l.settingsAppearanceContrast}: ${_contrastLabel(l, p.contrastLevel)}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                presetActive
                    ? l.settingsAppearanceContrastPresetBlocked
                    : dynamicActive
                    ? l.settingsAppearanceContrastDynamicBlocked
                    : l.settingsAppearanceContrastNormal,
              ),
              Slider(
                key: const ValueKey('settings_contrast_slider'),
                min: -1,
                max: 1,
                divisions: 6,
                value: p.contrastLevel,
                label: _contrastLabel(l, p.contrastLevel),
                onChanged: colorsEnabled ? p.setContrastLevel : null,
              ),
            ]),
            _card(context, l.settingsAppearanceDensity, [
              Text(l.settingsAppearanceDensityDescription),
              const SizedBox(height: 12),
              SearchablePickerField<AppDensity>(
                key: ValueKey('settings_density_${p.density.name}'),
                label: l.settingsAppearanceDensity,
                value: p.density,
                options: {
                  for (final density in AppDensity.values)
                    density: densityLabels[density.index],
                },
                onChanged: p.setDensity,
              ),
            ]),
            _card(context, l.settingsAppearanceFontSize, [
              _scale(
                context,
                key: const ValueKey('settings_system_text_scale'),
                title: l.settingsAppearanceSystemFontScale,
                description: l.settingsAppearanceSystemFontScaleDescription,
                value: p.systemTextScale,
                onChanged: p.setSystemTextScale,
              ),
              const SizedBox(height: 12),
              _scale(
                context,
                key: const ValueKey('settings_conversation_text_scale'),
                title: l.settingsAppearanceChatFontScale,
                description: l.settingsAppearanceChatFontScaleDescription,
                value: p.conversationTextScale,
                onChanged: p.setConversationTextScale,
              ),
            ]),
            _card(context, l.settingsAppearanceMathRendering, [
              SwitchListTile.adaptive(
                key: const ValueKey('settings_toggle_math_rendering'),
                contentPadding: EdgeInsets.zero,
                title: Text(l.settingsAppearanceMathRenderingDescription),
                value: p.mathRendering,
                onChanged: p.setMathRendering,
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _card(BuildContext context, String title, List<Widget> children) =>
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...children,
            ],
          ),
        ),
      );

  Widget _scale(
    BuildContext context, {
    required Key key,
    required String title,
    required String description,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    final percent = '${(value * 100).round()}%';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('$title: $percent', style: Theme.of(context).textTheme.titleSmall),
        Text(description),
        Slider(
          key: key,
          min: AppPreferencesController.textScaleMin,
          max: AppPreferencesController.textScaleMax,
          divisions: 16,
          value: value,
          label: percent,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Future<void> _pickPreset(
    BuildContext context,
    AppPreferencesController p,
  ) async {
    final selected = await showSearchablePicker<OpenCodeThemePreset>(
      context,
      title: context.v2L10n.settingsAppearancePresetPalette,
      options: {
        for (final preset in openCodeThemePresetOptions())
          preset: openCodeThemePresetLabel(preset),
      },
      selected: p.themePreset,
    );
    if (selected != null && !p.isDisposed) p.setThemePreset(selected);
  }
}

Widget _choice<T extends Object>({
  required Key key,
  required String label,
  required T value,
  required Map<T, String> options,
  required ValueChanged<T> onChanged,
}) => LayoutBuilder(
  builder: (context, constraints) {
    // Long translations and enlarged text retain usable controls on phones.
    if (constraints.maxWidth < 380 ||
        MediaQuery.textScalerOf(context).scale(14) > 18) {
      return SearchablePickerField<T>(
        key: ValueKey((key, value)),
        label: label,
        value: value,
        options: options,
        onChanged: onChanged,
      );
    }
    return SegmentedButton<T>(
      key: key,
      segments: [
        for (final option in options.entries)
          ButtonSegment(value: option.key, label: Text(option.value)),
      ],
      selected: {value},
      onSelectionChanged: (next) => onChanged(next.first),
    );
  },
);

String _contrastLabel(V2Localizations l, double value) {
  if (value <= -0.83) return l.settingsAppearanceContrastReduced;
  if (value <= -0.17) return l.settingsAppearanceContrastLow;
  if (value <= 0.17) return l.settingsAppearanceContrastStandard;
  if (value <= 0.58) return l.settingsAppearanceContrastMedium;
  if (value <= 0.83) return l.settingsAppearanceContrastMediumHigh;
  return l.settingsAppearanceContrastHigh;
}
