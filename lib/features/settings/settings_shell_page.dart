import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/app_keyboard_shortcuts.dart';
import '../../app/app_preferences_controller.dart';
import '../../shared/l10n/l10n_context.dart';
import '../../shared/layout/window_size_class.dart';
import '../../shared/shortcuts/shortcut_action.dart';
import 'appearance_settings_page.dart';
import 'shortcuts_settings_page.dart';

enum SettingsSection { appearance, shortcuts }

class SettingsShellPage extends StatefulWidget {
  const SettingsShellPage({super.key});

  @override
  State<SettingsShellPage> createState() => _SettingsShellPageState();
}

class _SettingsShellPageState extends State<SettingsShellPage> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final _backFocus = FocusNode();
  final _detailKey = GlobalKey();
  final _sectionFocus = {
    for (final section in SettingsSection.values) section: FocusNode(),
  };
  SettingsSection? _selected;
  bool _wasWide = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final wide = context.windowSizeClass.isAtLeastExpanded;
    if (wide) {
      _selected ??= SettingsSection.appearance;
    }
    if (_wasWide && !wide && _selected != null) {
      _focusDetail(_selected!);
    }
    _wasWide = wide;
  }

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    _backFocus.dispose();
    for (final node in _sectionFocus.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _select(SettingsSection section) {
    _searchFocus.unfocus();
    setState(() => _selected = section);
    _focusDetail(section);
  }

  void _focusDetail(SettingsSection section) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _selected != section ||
          context.windowSizeClass.isAtLeastExpanded) {
        return;
      }
      final focused = FocusManager.instance.primaryFocus?.context;
      if (focused != null && focused.mounted) {
        if (ModalRoute.of(focused) is PopupRoute ||
            focused.findAncestorStateOfType<EditableTextState>() != null) {
          return;
        }
      }
      if (_backFocus.context?.mounted ?? false) _backFocus.requestFocus();
    });
  }

  void _back() {
    final previous = _selected;
    setState(() => _selected = null);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final node = _sectionFocus[previous];
      if (node?.context?.mounted ?? false) node!.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppPreferencesController>();
    final l = context.v2L10n;
    final wide = context.windowSizeClass.isAtLeastExpanded;
    final supportsShortcuts =
        kIsWeb ||
        p.hasPhysicalKeyboard ||
        const {
          TargetPlatform.linux,
          TargetPlatform.macOS,
          TargetPlatform.windows,
        }.contains(defaultTargetPlatform);
    final section = _selected;
    // Keep section form state and pending modal callbacks across reparenting.
    final detail = KeyedSubtree(
      key: _detailKey,
      child: section == SettingsSection.shortcuts
          ? const ShortcutsSettingsPage()
          : const AppearanceSettingsPage(),
    );
    return KeyboardActionScope(
      handlers: {if (!wide && section != null) ShortcutAction.escape: _back},
      child: PopScope(
        canPop: wide || section == null,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && !wide && section != null) _back();
        },
        child: wide
            ? Row(
                children: [
                  SizedBox(
                    width: 320,
                    child: _master(context, supportsShortcuts),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: detail),
                ],
              )
            : section == null
            ? _master(context, supportsShortcuts)
            : Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        key: const ValueKey('settings_detail_back'),
                        focusNode: _backFocus,
                        tooltip: l.settingsBack,
                        onPressed: _back,
                        icon: const Icon(Icons.arrow_back),
                      ),
                      Expanded(
                        child: Text(
                          l.settingsTitle,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ],
                  ),
                  Expanded(child: detail),
                ],
              ),
      ),
    );
  }

  Widget _master(BuildContext context, bool supportsShortcuts) {
    final l = context.v2L10n;
    final query = _search.text.trim().toLowerCase();
    bool matches(String title, String description, String group) =>
        '$title $description $group'.toLowerCase().contains(query);
    final appearanceDescription =
        '${l.settingsAppearanceThemeDescription} ${l.settingsAppearanceDensityDescription}';
    final servers = matches(
      l.settingsServersTitle,
      l.chatAddServerToStart,
      l.settingsNavigationGroupSetup,
    );
    final appearance = matches(
      l.settingsAppearanceTitle,
      appearanceDescription,
      l.settingsNavigationGroupExperience,
    );
    final shortcuts =
        supportsShortcuts &&
        matches(
          l.settingsShortcutsTitle,
          l.settingsShortcutsDescription,
          l.settingsNavigationGroupInput,
        );
    return ListView(
      key: const ValueKey('settings_destinations'),
      padding: const EdgeInsets.all(16),
      children: [
        Text(l.settingsTitle, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('settings_navigation_search'),
          controller: _search,
          focusNode: _searchFocus,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: l.settingsNavigationSearchHint,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    tooltip: l.settingsSearchClear,
                    onPressed: () => setState(_search.clear),
                    icon: const Icon(Icons.clear),
                  ),
          ),
        ),
        if (!servers && !appearance && !shortcuts)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l.settingsNavigationNoResults),
          ),
        if (servers) ...[
          _group(context, l.settingsNavigationGroupSetup),
          ListTile(
            key: const ValueKey('settings_destination_servers'),
            leading: const Icon(Icons.dns_outlined),
            title: Text(l.settingsServersTitle),
            subtitle: Text(l.chatAddServerToStart),
            onTap: () => context.go('/hosts'),
          ),
        ],
        if (appearance) ...[
          _group(context, l.settingsNavigationGroupExperience),
          _destination(
            SettingsSection.appearance,
            l.settingsAppearanceTitle,
            appearanceDescription,
            Icons.palette_outlined,
          ),
        ],
        if (shortcuts) ...[
          _group(context, l.settingsNavigationGroupInput),
          _destination(
            SettingsSection.shortcuts,
            l.settingsShortcutsTitle,
            l.settingsShortcutsDescription,
            Icons.keyboard_outlined,
          ),
        ],
      ],
    );
  }

  Widget _group(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(title, style: Theme.of(context).textTheme.titleSmall),
  );

  Widget _destination(
    SettingsSection section,
    String title,
    String description,
    IconData icon,
  ) => ListTile(
    key: ValueKey('settings_destination_${section.name}'),
    focusNode: _sectionFocus[section],
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(description, maxLines: 2, overflow: TextOverflow.ellipsis),
    selected: _selected == section,
    onTap: () => _select(section),
  );
}
