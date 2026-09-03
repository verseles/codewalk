import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/i18n/l10n_context.dart';
import '../../../../domain/entities/experience_settings.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/desktop_window_chrome_service.dart';
import '../../../theme/brand_colors.dart';
import '../../../theme/opencode_theme_presets.dart';
import '../../../widgets/direct_provider.dart';
import '../../../widgets/searchable_dropdown_form_field.dart';
import '../widgets/settings_section_layout.dart';

enum _AppearanceThemeFamily { classic, presets }

bool get _isDesktopPlatform =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows);

String _contrastLabel(AppLocalizations l10n, double level) {
  if (level <= -0.83) return l10n.settingsAppearanceContrastReduced;
  if (level <= -0.17) return l10n.settingsAppearanceContrastLow;
  if (level <= 0.17) return l10n.settingsAppearanceContrastStandard;
  if (level <= 0.58) return l10n.settingsAppearanceContrastMedium;
  if (level <= 0.83) return l10n.settingsAppearanceContrastMediumHigh;
  return l10n.settingsAppearanceContrastHigh;
}

class AppearanceSettingsSection extends StatelessWidget {
  const AppearanceSettingsSection({super.key});

  Widget _buildWindowChromeCard(
    BuildContext context,
    SettingsProvider settingsProvider,
  ) {
    Future<void> select(DesktopWindowChrome? value) async {
      if (value == null || value == settingsProvider.desktopWindowChrome) {
        return;
      }
      await settingsProvider.setDesktopWindowChrome(value);
      // Applied immediately so the change is visible without a restart.
      await DesktopWindowChromeService.apply(value);
    }

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.settingsAppearanceWindowChrome,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  context.l10n.settingsAppearanceWindowChromeDescription,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          RadioListTile<DesktopWindowChrome>.adaptive(
            key: const ValueKey<String>('settings_window_chrome_integrated'),
            title: Text(context.l10n.settingsAppearanceWindowChromeIntegrated),
            subtitle: Text(
              context.l10n.settingsAppearanceWindowChromeIntegratedDescription,
            ),
            value: DesktopWindowChrome.integratedTabs,
            groupValue: settingsProvider.desktopWindowChrome,
            onChanged: (value) => unawaited(select(value)),
          ),
          RadioListTile<DesktopWindowChrome>.adaptive(
            key: const ValueKey<String>('settings_window_chrome_system'),
            title: Text(context.l10n.settingsAppearanceWindowChromeSystem),
            subtitle: Text(
              context.l10n.settingsAppearanceWindowChromeSystemDescription,
            ),
            value: DesktopWindowChrome.systemDecoration,
            groupValue: settingsProvider.desktopWindowChrome,
            onChanged: (value) => unawaited(select(value)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DirectConsumer<SettingsProvider>(
      builder: (context, settingsProvider, _) {
        final isDarkModeActive =
            Theme.of(context).brightness == Brightness.dark;
        final isPresetThemeActive = settingsProvider.themePreset != null;
        final selectedThemeFamily = isPresetThemeActive
            ? _AppearanceThemeFamily.presets
            : _AppearanceThemeFamily.classic;
        final selectedPreset =
            settingsProvider.themePreset ?? kDefaultOpenCodeThemePreset;
        final presetOptions = openCodeThemePresetOptions();
        final selectedVisualStyle = settingsProvider.visualStyle;
        // Show the persisted preference regardless of active theme.
        // The switch is disabled when dark mode is inactive.
        final amoledSwitchValue = settingsProvider.useAmoledDark;
        final selectedDensity = settingsProvider.appDensity;
        final densityOptions = <({AppDensity value, String label})>[
          (
            value: AppDensity.extraDense,
            label: context.l10n.settingsAppearanceDensityExtraDense,
          ),
          (
            value: AppDensity.dense,
            label: context.l10n.settingsAppearanceDensityDense,
          ),
          (
            value: AppDensity.normal,
            label: context.l10n.settingsAppearanceDensityNormal,
          ),
          (
            value: AppDensity.spacious,
            label: context.l10n.settingsAppearanceDensitySpacious,
          ),
          (
            value: AppDensity.extraSpacious,
            label: context.l10n.settingsAppearanceDensityExtraSpacious,
          ),
        ];
        final systemFontScale = settingsProvider.systemFontScale;
        final chatFontScale = settingsProvider.chatFontScale;
        final terminalFontSize = settingsProvider.terminalFontSize;
        const systemFontDivisions = 8;
        const chatFontDivisions = 8;
        const terminalFontDivisions = 13;
        return ListView(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          children: [
            SettingsSectionIntro(
              title: context.l10n.settingsAppearanceSectionTitle,
              description: context.l10n.settingsAppearanceSectionDescription,
            ),
            const SizedBox(height: 16),
            SettingsGroupHeader(title: context.l10n.settingsGroupThemeAndColor),
            const SizedBox(height: 8),
            // Theme mode card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.defaultPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.settingsAppearanceTheme,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.settingsAppearanceThemeDescription,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<ThemeModeOption>(
                        key: const ValueKey<String>(
                          'settings_theme_mode_segmented',
                        ),
                        segments: <ButtonSegment<ThemeModeOption>>[
                          ButtonSegment<ThemeModeOption>(
                            value: ThemeModeOption.system,
                            label: Text(context.l10n.settingsAppearanceSystem),
                            icon: const Icon(Symbols.brightness_auto),
                          ),
                          ButtonSegment<ThemeModeOption>(
                            value: ThemeModeOption.light,
                            label: Text(context.l10n.settingsAppearanceLight),
                            icon: const Icon(Symbols.light_mode),
                          ),
                          ButtonSegment<ThemeModeOption>(
                            value: ThemeModeOption.dark,
                            label: Text(context.l10n.settingsAppearanceDark),
                            icon: const Icon(Symbols.dark_mode),
                          ),
                        ],
                        selected: <ThemeModeOption>{settingsProvider.themeMode},
                        onSelectionChanged: (selected) => unawaited(
                          settingsProvider.setThemeMode(selected.first),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<_AppearanceThemeFamily>(
                        key: const ValueKey<String>(
                          'settings_theme_family_segmented',
                        ),
                        segments: <ButtonSegment<_AppearanceThemeFamily>>[
                          ButtonSegment<_AppearanceThemeFamily>(
                            value: _AppearanceThemeFamily.classic,
                            label: Text(
                              context.l10n.settingsAppearanceCodeWalkClassic,
                            ),
                            icon: const Icon(Symbols.palette),
                          ),
                          ButtonSegment<_AppearanceThemeFamily>(
                            value: _AppearanceThemeFamily.presets,
                            label: Text(
                              context.l10n.settingsAppearanceOpenCodePresets,
                            ),
                            icon: const Icon(Symbols.format_paint),
                          ),
                        ],
                        selected: <_AppearanceThemeFamily>{selectedThemeFamily},
                        onSelectionChanged: (selected) {
                          final nextFamily = selected.first;
                          if (nextFamily == _AppearanceThemeFamily.classic) {
                            unawaited(settingsProvider.setThemePreset(null));
                            return;
                          }
                          unawaited(
                            settingsProvider.setThemePreset(selectedPreset),
                          );
                        },
                      ),
                    ),
                    if (isPresetThemeActive) ...[
                      const SizedBox(height: 12),
                      SearchableDropdownFormField<OpenCodeThemePreset>(
                        key: const ValueKey<String>(
                          'settings_theme_preset_dropdown',
                        ),
                        value: selectedPreset,
                        decoration: InputDecoration(
                          labelText:
                              context.l10n.settingsAppearancePresetPalette,
                          border: const OutlineInputBorder(),
                          helperText:
                              context.l10n.settingsAppearancePresetHelper,
                        ),
                        isExpanded: true,
                        searchHintText:
                            context.l10n.settingsAppearanceSearchPreset,
                        emptyText: context.l10n.settingsAppearanceNoPresets,
                        searchTermsBuilder: (value) => <String>[
                          openCodeThemePresetLabel(value),
                          value.name,
                        ],
                        items: presetOptions
                            .map(
                              (preset) => DropdownMenuItem<OpenCodeThemePreset>(
                                value: preset,
                                child: Text(openCodeThemePresetLabel(preset)),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          unawaited(settingsProvider.setThemePreset(value));
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.l10n.settingsAppearancePresetNote,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      context.l10n.settingsAppearanceVisualStyle,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.settingsAppearanceVisualStyleDescription,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<VisualStyle>(
                        key: const ValueKey<String>(
                          'settings_visual_style_segmented',
                        ),
                        segments: <ButtonSegment<VisualStyle>>[
                          ButtonSegment<VisualStyle>(
                            value: VisualStyle.classic,
                            label: Text(
                              context.l10n.settingsAppearanceVisualStyleClassic,
                            ),
                            icon: const Icon(Symbols.tune),
                          ),
                          ButtonSegment<VisualStyle>(
                            value: VisualStyle.refined,
                            label: Text(
                              context.l10n.settingsAppearanceVisualStyleRefined,
                            ),
                            icon: const Icon(Symbols.auto_awesome),
                          ),
                        ],
                        selected: <VisualStyle>{selectedVisualStyle},
                        onSelectionChanged: (selected) => unawaited(
                          settingsProvider.setVisualStyle(selected.first),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      key: const ValueKey<String>(
                        'settings_toggle_amoled_dark',
                      ),
                      contentPadding: EdgeInsets.zero,
                      title: Text(context.l10n.settingsAppearanceAmoledDark),
                      subtitle: Text(
                        isDarkModeActive
                            ? context.l10n.settingsAppearanceAmoledDarkActive
                            : context.l10n.settingsAppearanceAmoledDarkInactive,
                      ),
                      value: amoledSwitchValue,
                      onChanged: isDarkModeActive
                          ? (value) => unawaited(
                              settingsProvider.setUseAmoledDark(value),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Color card
            Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dynamic color toggle — only on platforms that support it
                  if (settingsProvider.dynamicColorAvailable)
                    SwitchListTile.adaptive(
                      key: const ValueKey<String>(
                        'settings_toggle_dynamic_color',
                      ),
                      title: Text(
                        context.l10n.settingsAppearanceWallpaperColors,
                      ),
                      subtitle: Text(
                        isPresetThemeActive
                            ? context
                                  .l10n
                                  .settingsAppearanceWallpaperPresetBlocked
                            : context.l10n.settingsAppearanceWallpaperNormal,
                      ),
                      value: settingsProvider.useDynamicColor,
                      onChanged: isPresetThemeActive
                          ? null
                          : (value) => unawaited(
                              settingsProvider.setUseDynamicColor(value),
                            ),
                    ),
                  if (settingsProvider.dynamicColorAvailable)
                    const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(AppConstants.defaultPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.settingsAppearanceBrandColor,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isPresetThemeActive
                              ? context
                                    .l10n
                                    .settingsAppearanceBrandColorPresetBlocked
                              : settingsProvider.useDynamicColor &&
                                    settingsProvider.dynamicColorAvailable
                              ? context
                                    .l10n
                                    .settingsAppearanceBrandColorDynamicBlocked
                              : context.l10n.settingsAppearanceBrandColorNormal,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          key: const ValueKey<String>(
                            'settings_brand_color_wrap',
                          ),
                          spacing: 10,
                          runSpacing: 10,
                          children: BrandColor.values
                              .map((brand) {
                                final isSelected =
                                    settingsProvider.customColorSeed ==
                                    brand.value;
                                final isDisabled =
                                    isPresetThemeActive ||
                                    settingsProvider.useDynamicColor &&
                                        settingsProvider.dynamicColorAvailable;
                                return Tooltip(
                                  message: brand.label,
                                  child: ChoiceChip(
                                    key: ValueKey<String>(
                                      'settings_brand_color_${brand.name}',
                                    ),
                                    label: const SizedBox.shrink(),
                                    selected: isSelected,
                                    onSelected: isDisabled
                                        ? null
                                        : (_) => unawaited(
                                            settingsProvider.setCustomColorSeed(
                                              isSelected ? null : brand.value,
                                            ),
                                          ),
                                    avatar: CircleAvatar(
                                      backgroundColor: brand.seed,
                                    ),
                                    showCheckmark: isSelected,
                                    labelPadding: EdgeInsets.zero,
                                    padding: const EdgeInsets.all(4),
                                  ),
                                );
                              })
                              .toList(growable: false),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Contrast card — disabled when dynamic color is active because
            // contrastLevel only applies to ColorScheme.fromSeed, not to the
            // platform-provided dynamic scheme.
            Builder(
              builder: (context) {
                final isDynamicActive =
                    isPresetThemeActive ||
                    settingsProvider.useDynamicColor &&
                        settingsProvider.dynamicColorAvailable;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppConstants.defaultPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.settingsAppearanceContrast,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isDynamicActive
                              ? isPresetThemeActive
                                    ? context
                                          .l10n
                                          .settingsAppearanceContrastPresetBlocked
                                    : context
                                          .l10n
                                          .settingsAppearanceContrastDynamicBlocked
                              : context.l10n.settingsAppearanceContrastNormal,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              context.l10n.settingsAppearanceContrastReduced,
                            ),
                            Expanded(
                              child: Slider(
                                key: const ValueKey<String>(
                                  'settings_contrast_slider',
                                ),
                                value: settingsProvider.contrastLevel,
                                min: -1.0,
                                max: 1.0,
                                divisions: 6,
                                label: _contrastLabel(
                                  context.l10n,
                                  settingsProvider.contrastLevel,
                                ),
                                onChanged: isDynamicActive
                                    ? null
                                    : (value) => unawaited(
                                        settingsProvider.setContrastLevel(
                                          value,
                                        ),
                                      ),
                              ),
                            ),
                            Text(context.l10n.settingsAppearanceContrastHigh),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            SettingsGroupHeader(title: context.l10n.settingsGroupLayoutAndText),
            const SizedBox(height: 8),
            // Density card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.defaultPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.settingsAppearanceDensity,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.settingsAppearanceDensityDescription,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      key: const ValueKey<String>(
                        'settings_density_choice_wrap',
                      ),
                      spacing: 8,
                      runSpacing: 8,
                      children: densityOptions
                          .map(
                            (option) => ChoiceChip(
                              key: ValueKey<String>(
                                'settings_density_choice_${option.value.name}',
                              ),
                              label: Text(option.label),
                              selected: selectedDensity == option.value,
                              onSelected: (_) => unawaited(
                                settingsProvider.setAppDensity(option.value),
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Text size card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.defaultPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.settingsAppearanceFontSize,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.settingsAppearanceFontSizeDescription,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    _FontSizeSliderRow(
                      title: context.l10n.settingsAppearanceSystemFontScale,
                      description: context
                          .l10n
                          .settingsAppearanceSystemFontScaleDescription,
                      value: systemFontScale,
                      min: kMinSystemFontScale,
                      max: kMaxSystemFontScale,
                      divisions: systemFontDivisions,
                      valueLabel: '${(systemFontScale * 100).round()}%',
                      valueKeySuffix: 'system',
                      onChanged: (value) =>
                          unawaited(settingsProvider.setSystemFontScale(value)),
                    ),
                    const SizedBox(height: 12),
                    _FontSizeSliderRow(
                      title: context.l10n.settingsAppearanceChatFontScale,
                      description: context
                          .l10n
                          .settingsAppearanceChatFontScaleDescription,
                      value: chatFontScale,
                      min: kMinChatFontScale,
                      max: kMaxChatFontScale,
                      divisions: chatFontDivisions,
                      valueLabel: '${(chatFontScale * 100).round()}%',
                      valueKeySuffix: 'chat',
                      onChanged: (value) =>
                          unawaited(settingsProvider.setChatFontScale(value)),
                    ),
                    const SizedBox(height: 12),
                    _FontSizeSliderRow(
                      title: context.l10n.settingsAppearanceTerminalFontSize,
                      description: context
                          .l10n
                          .settingsAppearanceTerminalFontSizeDescription,
                      value: terminalFontSize,
                      min: kMinTerminalFontSize,
                      max: kMaxTerminalFontSize,
                      divisions: terminalFontDivisions,
                      valueLabel: '${terminalFontSize.toStringAsFixed(0)} pt',
                      valueKeySuffix: 'terminal',
                      onChanged: (value) => unawaited(
                        settingsProvider.setTerminalFontSize(value),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_isDesktopPlatform) ...[
              const SizedBox(height: 12),
              _buildWindowChromeCard(context, settingsProvider),
            ],
            const SizedBox(height: 20),
            SettingsGroupHeader(title: context.l10n.settingsGroupChatDisplay),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    key: const ValueKey<String>(
                      'settings_toggle_thinking_bubbles',
                    ),
                    title: Text(context.l10n.settingsAppearanceThinkingBubbles),
                    subtitle: Text(
                      context.l10n.settingsAppearanceThinkingBubblesDescription,
                    ),
                    value: settingsProvider.showThinkingBubbles,
                    onChanged: (value) => unawaited(
                      settingsProvider.setShowThinkingBubbles(value),
                    ),
                  ),
                  const Divider(height: 1),
                  SwitchListTile.adaptive(
                    key: const ValueKey<String>(
                      'settings_toggle_tool_call_bubbles',
                    ),
                    title: Text(context.l10n.settingsAppearanceToolCallBubbles),
                    subtitle: Text(
                      context.l10n.settingsAppearanceToolCallBubblesDescription,
                    ),
                    value: settingsProvider.showToolCallBubbles,
                    onChanged: (value) => unawaited(
                      settingsProvider.setShowToolCallBubbles(value),
                    ),
                  ),
                  const Divider(height: 1),
                  SwitchListTile.adaptive(
                    key: const ValueKey<String>('settings_toggle_task_list'),
                    title: Text(context.l10n.settingsAppearanceTaskList),
                    subtitle: Text(
                      context.l10n.settingsAppearanceTaskListDescription,
                    ),
                    value: settingsProvider.showTaskList,
                    onChanged: (value) =>
                        unawaited(settingsProvider.setShowTaskList(value)),
                  ),
                  const Divider(height: 1),
                  SwitchListTile.adaptive(
                    key: const ValueKey<String>(
                      'settings_toggle_composer_tips',
                    ),
                    title: Text(context.l10n.settingsAppearanceComposerTips),
                    subtitle: Text(
                      context.l10n.settingsAppearanceComposerTipsDescription,
                    ),
                    value: settingsProvider.showComposerTips,
                    onChanged: (value) =>
                        unawaited(settingsProvider.setShowComposerTips(value)),
                  ),
                  const Divider(height: 1),
                  SwitchListTile.adaptive(
                    key: const ValueKey<String>(
                      'settings_toggle_math_rendering',
                    ),
                    title: Text(context.l10n.settingsAppearanceMathRendering),
                    subtitle: Text(
                      context.l10n.settingsAppearanceMathRenderingDescription,
                    ),
                    value: settingsProvider.showMathRendering,
                    onChanged: (value) =>
                        unawaited(settingsProvider.setShowMathRendering(value)),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FontSizeSliderRow extends StatelessWidget {
  const _FontSizeSliderRow({
    required this.title,
    required this.description,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.valueLabel,
    required this.valueKeySuffix,
    required this.onChanged,
  });

  final String title;
  final String description;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String valueLabel;
  final String valueKeySuffix;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: textTheme.titleSmall)),
            Text(
              valueLabel,
              key: ValueKey<String>('settings_font_size_value_$valueKeySuffix'),
              style: textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(description, style: textTheme.bodySmall),
        Slider(
          key: ValueKey<String>('settings_font_size_slider_$valueKeySuffix'),
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          label: valueLabel,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
