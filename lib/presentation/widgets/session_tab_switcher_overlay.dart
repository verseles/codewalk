import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/i18n/l10n_context.dart';
import '../../core/utils/path_utils.dart';
import '../../domain/entities/project.dart';
import '../providers/chat_provider.dart';
import '../services/session_tab_icon_presets.dart';
import '../utils/window_size_class.dart';
import 'project_icon.dart';
import 'session_tab_strip.dart';

/// Browser-style tab switcher overlay (issue #171, decision 2B completo).
///
/// Purely visual: the parent owns the MRU snapshot, the preview index, and
/// activation. This widget only renders the list, highlights [previewIndex],
/// marks the current tab, and forwards tap/confirm intents.
class SessionTabSwitcherOverlay extends StatefulWidget {
  const SessionTabSwitcherOverlay({
    super.key,
    required this.tabs,
    required this.previewIndex,
    required this.projects,
    required this.onSelect,
    required this.onDismiss,
  });

  final List<SessionTabRecord> tabs;
  final int previewIndex;
  final List<Project> projects;
  final ValueChanged<int> onSelect;
  final VoidCallback onDismiss;

  @override
  State<SessionTabSwitcherOverlay> createState() =>
      _SessionTabSwitcherOverlayState();
}

class _SessionTabSwitcherOverlayState extends State<SessionTabSwitcherOverlay> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureVisible());
  }

  @override
  void didUpdateWidget(SessionTabSwitcherOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.previewIndex != widget.previewIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _ensureVisible());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _ensureVisible() {
    if (!mounted || !_scrollController.hasClients) return;
    const itemExtent = _kSwitcherItemExtent;
    final offset = widget.previewIndex * itemExtent;
    final viewport = _scrollController.position.viewportDimension;
    final current = _scrollController.offset;
    if (offset < current) {
      _scrollController.jumpTo(
        offset.clamp(0.0, _scrollController.position.maxScrollExtent),
      );
    } else if (offset + itemExtent > current + viewport) {
      _scrollController.jumpTo(
        (offset + itemExtent - viewport).clamp(
          0.0,
          _scrollController.position.maxScrollExtent,
        ),
      );
    }
  }

  Project? _projectFor(SessionTabRecord tab) {
    for (final project in widget.projects) {
      if (tab.projectId != null && project.id == tab.projectId) return project;
      if (areEquivalentFilePaths(project.path, tab.identity.directory)) {
        return project;
      }
    }
    return null;
  }

  String _title(BuildContext context, SessionTabRecord tab) {
    final trimmed = tab.title.trim();
    return trimmed.isEmpty ? context.l10n.sessionExportUntitled : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (widget.tabs.isEmpty) return const SizedBox.shrink();
    final safeIndex = widget.previewIndex.clamp(0, widget.tabs.length - 1);
    final previewTab = widget.tabs[safeIndex];
    final previewTitle = _title(context, previewTab);
    final width = MediaQuery.sizeOf(context).width;
    final height = MediaQuery.sizeOf(context).height;
    final isCompact = WindowSizeClass.fromWidth(width).isCompact;

    return Semantics(
      container: true,
      liveRegion: true,
      label:
          '${context.l10n.sessionTabSwitcherTitle}: $previewTitle '
          '(${safeIndex + 1} of ${widget.tabs.length})',
      child: Stack(
        key: const ValueKey<String>('session_tab_switcher_overlay'),
        children: [
          Positioned.fill(
            child: GestureDetector(
              key: const ValueKey<String>('session_tab_switcher_barrier'),
              behavior: HitTestBehavior.opaque,
              onTap: widget.onDismiss,
              child: Container(color: Colors.black26),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isCompact ? width - 32 : 420,
                maxHeight: height * 0.6,
              ),
              child: Card(
                elevation: 6,
                color: colorScheme.surfaceContainerHigh,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text(
                        context.l10n.sessionTabSwitcherTitle,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    Flexible(
                      child: ListView.builder(
                        controller: _scrollController,
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemExtent: _kSwitcherItemExtent,
                        itemCount: widget.tabs.length,
                        itemBuilder: (context, index) {
                          final tab = widget.tabs[index];
                          final key = sessionTabIdentityKey(tab.identity);
                          final isPreview = index == safeIndex;
                          final isCurrent = tab.isSelected;
                          final project = _projectFor(tab);
                          final subtitle =
                              (project?.name.trim().isNotEmpty ?? false)
                              ? project!.name.trim()
                              : fileBasename(tab.identity.directory);
                          return Semantics(
                            button: true,
                            selected: isPreview,
                            label: _title(context, tab),
                            child: Material(
                              key: ValueKey<String>(
                                isPreview
                                    ? 'session_tab_switcher_highlight_$key'
                                    : 'session_tab_switcher_item_$key',
                              ),
                              color: isPreview
                                  ? colorScheme.primaryContainer
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              child: ListTile(
                                dense: true,
                                minVerticalPadding: 4,
                                leading: _SwitcherLeading(
                                  tab: tab,
                                  identityKey: key,
                                  project: project,
                                ),
                                title: Text(
                                  _title(context, tab),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: isPreview
                                            ? colorScheme.onPrimaryContainer
                                            : null,
                                        fontWeight: isPreview
                                            ? FontWeight.w600
                                            : null,
                                      ),
                                ),
                                subtitle: Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: isPreview
                                            ? colorScheme.onPrimaryContainer
                                            : colorScheme.onSurfaceVariant,
                                      ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (tab.isPinned)
                                      Icon(
                                        Symbols.keep,
                                        size: 16,
                                        color: isPreview
                                            ? colorScheme.onPrimaryContainer
                                            : colorScheme.onSurfaceVariant,
                                      ),
                                    if (isCurrent)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 4),
                                        child: Icon(
                                          Symbols.check,
                                          size: 18,
                                          color: isPreview
                                              ? colorScheme.onPrimaryContainer
                                              : colorScheme.primary,
                                        ),
                                      ),
                                  ],
                                ),
                                onTap: () => widget.onSelect(index),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      child: Text(
                        context.l10n.sessionTabSwitcherHint,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const double _kSwitcherItemExtent = 56;

class _SwitcherLeading extends StatelessWidget {
  const _SwitcherLeading({
    required this.tab,
    required this.identityKey,
    this.project,
  });

  final SessionTabRecord tab;
  final String identityKey;
  final Project? project;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    Widget leading;
    if (tab.hasUnseenError) {
      leading = _dot(
        key: 'session_tab_switcher_error_$identityKey',
        icon: Symbols.error,
        background: colorScheme.errorContainer,
        foreground: colorScheme.onErrorContainer,
      );
    } else if (tab.hasUnseenQuestion) {
      leading = _dot(
        key: 'session_tab_switcher_question_$identityKey',
        icon: Symbols.help,
        background: colorScheme.tertiaryContainer,
        foreground: colorScheme.onTertiaryContainer,
      );
    } else if (tab.hasUnseenCompletion) {
      leading = _dot(
        key: 'session_tab_switcher_completion_$identityKey',
        icon: Symbols.notifications_active,
        background: colorScheme.primaryContainer,
        foreground: colorScheme.onPrimaryContainer,
      );
    } else {
      final preset = SessionTabIconPreset.fromId(tab.iconPresetId);
      if (preset != null) {
        leading = Icon(
          preset.icon,
          key: ValueKey<String>(
            'session_tab_switcher_custom_icon_$identityKey',
          ),
          size: 20,
          color: colorScheme.onSurfaceVariant,
        );
      } else if (project != null) {
        leading = ProjectIcon(
          key: ValueKey<String>(
            'session_tab_switcher_project_icon_$identityKey',
          ),
          project: project!,
          size: 20,
          autoDiscover: false,
        );
      } else {
        leading = Icon(
          key: ValueKey<String>('session_tab_switcher_default_$identityKey'),
          Symbols.chat_bubble_outline,
          size: 20,
          color: colorScheme.onSurfaceVariant,
        );
      }
    }
    return Stack(
      alignment: Alignment.center,
      children: [
        leading,
        if (tab.isBusy)
          PositionedDirectional(
            end: 0,
            bottom: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Symbols.sync_rounded,
                size: 9,
                color: colorScheme.onPrimary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _dot({
    required String key,
    required IconData icon,
    required Color background,
    required Color foreground,
  }) {
    return Container(
      key: ValueKey<String>(key),
      width: 28,
      height: 28,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Icon(icon, size: 18, color: foreground),
    );
  }
}
