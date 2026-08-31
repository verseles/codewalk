import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/i18n/l10n_context.dart';
import '../providers/settings_provider.dart';
import '../theme/app_animations.dart';
import '../utils/app_page_route.dart';
import '../utils/window_size_class.dart';
import '../widgets/settings_update_available_card.dart';
import 'logs_page.dart';
import 'onboarding_wizard_page.dart';
import 'settings/sections/about_settings_section.dart';
import 'settings/sections/appearance_settings_section.dart';
import 'settings/sections/behavior_settings_section.dart';
import 'settings/sections/notifications_settings_section.dart';
import 'settings/sections/servers_settings_section.dart';
import 'settings/sections/shortcuts_settings_section.dart';
import 'settings/sections/speech_settings_section.dart';
import 'settings/sections/text_to_speech_settings_section.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.initialSectionId = ''});

  final String initialSectionId;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsSection {
  const _SettingsSection({
    required this.id,
    required this.group,
    required this.title,
    required this.description,
    required this.icon,
    required this.builder,
  });

  final String id;
  final _SettingsNavigationGroup group;
  final String title;
  final String description;
  final IconData icon;
  final WidgetBuilder builder;
}

enum _SettingsNavigationGroup { setup, experience, input, support }

class _SettingsPageState extends State<SettingsPage> {
  // Split layout when expanded or wider (840dp+)
  static const Duration _doubleEscapeCloseThreshold = Duration(
    milliseconds: 500,
  );

  DateTime? _lastEscapeAt;
  bool _hasPhysicalKeyboard = false;
  String _version = '';
  String _buildNumber = '';

  _SettingsSection _section({
    required String id,
    required _SettingsNavigationGroup group,
    required String title,
    required String description,
    required IconData icon,
    required WidgetBuilder builder,
  }) {
    return _SettingsSection(
      id: id,
      group: group,
      title: title,
      description: description,
      icon: icon,
      builder: builder,
    );
  }

  List<_SettingsSection> get _sections => <_SettingsSection>[
    _section(
      id: 'servers',
      group: _SettingsNavigationGroup.setup,
      title: context.l10n.settingsServersTitle,
      description: context.l10n.settingsServersDescription,
      icon: Symbols.dns,
      builder: (_) => const ServersSettingsSection(),
    ),
    _section(
      id: 'appearance',
      group: _SettingsNavigationGroup.experience,
      title: context.l10n.settingsAppearanceTitle,
      description: context.l10n.settingsAppearanceDescription,
      icon: Symbols.tune_rounded,
      builder: (_) => const AppearanceSettingsSection(),
    ),
    _section(
      id: 'behavior',
      group: _SettingsNavigationGroup.experience,
      title: context.l10n.settingsBehaviorTitle,
      description: context.l10n.settingsBehaviorDescription,
      icon: Symbols.settings,
      builder: (_) => const BehaviorSettingsSection(),
    ),
    _section(
      id: 'notifications',
      group: _SettingsNavigationGroup.experience,
      title: context.l10n.settingsNotificationsTitle,
      description: context.l10n.settingsNotificationsDescription,
      icon: Symbols.notifications_active,
      builder: (_) => const NotificationsSettingsSection(),
    ),
    _section(
      id: 'speech',
      group: _SettingsNavigationGroup.input,
      title: context.l10n.settingsSpeechTitle,
      description: context.l10n.settingsSpeechDescription,
      icon: Symbols.mic_none_rounded,
      builder: (_) => const SpeechSettingsSection(),
    ),
    _section(
      id: 'tts',
      group: _SettingsNavigationGroup.input,
      title: context.l10n.settingsReadAloudSectionTitle,
      description: context.l10n.settingsReadAloudSectionDescription,
      icon: Symbols.volume_up_rounded,
      builder: (_) => const TextToSpeechSettingsSection(),
    ),
    _section(
      id: 'logs',
      group: _SettingsNavigationGroup.support,
      title: context.l10n.settingsLogsTitle,
      description: context.l10n.settingsLogsDescription,
      icon: Symbols.receipt_long_rounded,
      builder: (_) => const SizedBox.shrink(),
    ),
    _section(
      id: 'shortcuts',
      group: _SettingsNavigationGroup.input,
      title: context.l10n.settingsShortcutsTitle,
      description: context.l10n.settingsShortcutsDescription,
      icon: Symbols.keyboard_command_key_rounded,
      builder: (_) => const ShortcutsSettingsSection(),
    ),
    _section(
      id: 'about',
      group: _SettingsNavigationGroup.support,
      title: context.l10n.settingsAboutTitle,
      description: context.l10n.settingsAboutDescription,
      icon: Symbols.info,
      builder: (_) => const AboutSettingsSection(),
    ),
  ];

  bool get _supportsShortcutsSection {
    if (kIsWeb) {
      return true;
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.linux ||
      TargetPlatform.macOS ||
      TargetPlatform.windows => true,
      _ => _hasPhysicalKeyboard,
    };
  }

  List<_SettingsSection> get _visibleSections {
    if (_supportsShortcutsSection) {
      return _sections;
    }
    return _sections
        .where((section) => section.id != 'shortcuts')
        .toList(growable: false);
  }

  String? _selectedSectionId;
  bool _showMobileDetail = false;
  final TextEditingController _settingsSearchController =
      TextEditingController();
  String _settingsQuery = '';

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleGlobalKeyEvent);
    unawaited(_loadVersion());
    final initialSectionId = widget.initialSectionId == 'logs'
        ? ''
        : widget.initialSectionId;
    // Section labels depend on Localizations, so the localized section list is
    // resolved during build instead of during initState.
    _selectedSectionId = initialSectionId.isEmpty
        ? 'servers'
        : initialSectionId;
    _showMobileDetail = initialSectionId.isNotEmpty;
    if (widget.initialSectionId == 'logs') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _openLogsPage();
      });
    }
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) {
      return;
    }
    setState(() {
      _version = info.version;
      _buildNumber = info.buildNumber;
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalKeyEvent);
    _settingsSearchController.dispose();
    super.dispose();
  }

  String _groupLabel(_SettingsNavigationGroup group) {
    return switch (group) {
      _SettingsNavigationGroup.setup =>
        context.l10n.settingsNavigationGroupSetup,
      _SettingsNavigationGroup.experience =>
        context.l10n.settingsNavigationGroupExperience,
      _SettingsNavigationGroup.input =>
        context.l10n.settingsNavigationGroupInput,
      _SettingsNavigationGroup.support =>
        context.l10n.settingsNavigationGroupSupport,
    };
  }

  List<_SettingsSection> get _filteredSections {
    final query = _settingsQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return _visibleSections;
    }
    return _visibleSections
        .where((section) {
          final searchable = <String>[
            section.title,
            section.description,
            _groupLabel(section.group),
          ].join(' ').toLowerCase();
          return searchable.contains(query);
        })
        .toList(growable: false);
  }

  bool _handleGlobalKeyEvent(KeyEvent event) {
    if (!mounted) {
      return false;
    }
    if (!_hasPhysicalKeyboard && event is KeyDownEvent) {
      setState(() {
        _hasPhysicalKeyboard = true;
      });
    }
    if (event is! KeyDownEvent) {
      return false;
    }
    if (event.logicalKey != LogicalKeyboardKey.escape) {
      return false;
    }
    if (HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isAltPressed ||
        HardwareKeyboard.instance.isShiftPressed) {
      return false;
    }

    final route = ModalRoute.of(context);
    if (route == null || !route.isCurrent) {
      return false;
    }

    final now = DateTime.now();
    final shouldClose =
        _lastEscapeAt != null &&
        now.difference(_lastEscapeAt!) <= _doubleEscapeCloseThreshold;
    _lastEscapeAt = now;
    if (!shouldClose) {
      return true;
    }

    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final visibleSections = _visibleSections;
    if (!visibleSections.any((item) => item.id == _selectedSectionId)) {
      _selectedSectionId = visibleSections.first.id;
    }
    final section = visibleSections
        .where((item) => item.id == _selectedSectionId)
        .firstOrNull;
    final sizeClass = context.windowSizeClass;
    final isSplit = sizeClass.isAtLeastExpanded;

    if (!isSplit) {
      return PopScope(
        canPop: !_showMobileDetail,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop || !_showMobileDetail) {
            return;
          }
          setState(() {
            _showMobileDetail = false;
          });
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              _showMobileDetail
                  ? (section?.title ?? context.l10n.settingsTitle)
                  : context.l10n.settingsTitle,
            ),
            leading: _showMobileDetail
                ? IconButton(
                    tooltip: context.l10n.permissionBack,
                    onPressed: () {
                      setState(() {
                        _showMobileDetail = false;
                      });
                    },
                    icon: const Icon(Symbols.arrow_back),
                  )
                : null,
          ),
          body: AnimatedSwitcher(
            duration: AppAnimations.emphasized,
            switchInCurve: AppAnimations.emphasizedCurve,
            switchOutCurve: AppAnimations.accelerateCurve,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.04, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: _showMobileDetail && section != null
                ? KeyedSubtree(
                    key: ValueKey<String>('section_${section.id}'),
                    child: section.builder(context),
                  )
                : KeyedSubtree(
                    key: const ValueKey<String>('section_list'),
                    child: _buildSectionList(isSplit: false),
                  ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settingsTitle)),
      body: Row(
        children: [
          SizedBox(width: 320, child: _buildSectionList(isSplit: true)),
          const VerticalDivider(width: 1),
          Expanded(
            child: AnimatedSwitcher(
              duration: AppAnimations.emphasized,
              switchInCurve: AppAnimations.emphasizedCurve,
              switchOutCurve: AppAnimations.accelerateCurve,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.04, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: section == null
                  ? const SizedBox.shrink(
                      key: ValueKey<String>('section_empty'),
                    )
                  : KeyedSubtree(
                      key: ValueKey<String>('section_${section.id}'),
                      child: section.builder(context),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSetupWizard() async {
    await Navigator.of(context).push(
      AppPageRoute(
        builder: (_) => OnboardingWizardPage(
          showSkipAction: false,
          onComplete: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  Future<void> _openLogsPage() async {
    await Navigator.of(
      context,
    ).push(AppPageRoute(builder: (_) => const LogsPage()));
  }

  Future<void> _replayChatTour() async {
    final settingsProvider = context.read<SettingsProvider>();
    if (settingsProvider.pendingPostOnboardingChatTour) {
      await settingsProvider.setPendingPostOnboardingChatTour(false);
    }
    await settingsProvider.setPendingPostOnboardingChatTour(true);
    if (!mounted) {
      return;
    }
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  Widget _buildSectionList({required bool isSplit}) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        final updateResult = settings.updateCheckResult;
        final filteredSections = _filteredSections;
        return ListView(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          children: [
            if (updateResult != null && updateResult.isNewer) ...[
              SettingsUpdateAvailableCard(
                settings: settings,
                result: updateResult,
                currentVersion: _version,
                currentBuildNumber: _buildNumber,
              ),
              const SizedBox(height: 10),
            ],
            TextField(
              key: const ValueKey<String>('settings_navigation_search'),
              controller: _settingsSearchController,
              decoration: InputDecoration(
                hintText: context.l10n.settingsNavigationSearchHint,
                prefixIcon: const Icon(Symbols.search),
                suffixIcon: _settingsQuery.isEmpty
                    ? null
                    : IconButton(
                        key: const ValueKey<String>(
                          'settings_navigation_search_clear',
                        ),
                        tooltip: context.l10n.logsCloseSearch,
                        onPressed: () {
                          _settingsSearchController.clear();
                          setState(() => _settingsQuery = '');
                        },
                        icon: const Icon(Symbols.close),
                      ),
              ),
              onChanged: (value) => setState(() => _settingsQuery = value),
            ),
            const SizedBox(height: 12),
            if (_settingsQuery.isEmpty) ...[
              FilledButton.icon(
                onPressed: _openSetupWizard,
                icon: const Icon(Symbols.auto_fix_high_rounded),
                label: Text(context.l10n.settingsSetupWizard),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                key: const ValueKey<String>('settings_replay_chat_tour_button'),
                onPressed: () => unawaited(_replayChatTour()),
                icon: const Icon(Symbols.play_circle_rounded),
                label: Text(context.l10n.settingsAboutReplayChatTour),
              ),
              const SizedBox(height: 16),
            ],
            if (filteredSections.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(context.l10n.settingsNavigationNoResults),
                ),
              )
            else
              for (final group in _SettingsNavigationGroup.values) ...[
                if (filteredSections.any((section) => section.group == group))
                  Semantics(
                    header: true,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                      child: Text(
                        _groupLabel(group),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                for (final section in filteredSections.where(
                  (section) => section.group == group,
                ))
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      selected: section.id == _selectedSectionId,
                      leading: Icon(section.icon),
                      title: Text(section.title),
                      subtitle: Text(section.description),
                      trailing: const Icon(Symbols.chevron_right),
                      onTap: () {
                        if (section.id == 'logs') {
                          _openLogsPage();
                          return;
                        }
                        setState(() {
                          _selectedSectionId = section.id;
                          _showMobileDetail = true;
                        });
                      },
                    ),
                  ),
              ],
          ],
        );
      },
    );
  }
}
