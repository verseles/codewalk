part of '../chat_page.dart';

/// Defines a single action that can appear in the mobile app bar overflow
/// menu or be pinned to the main app bar.
class _MobileAppBarActionDef {
  const _MobileAppBarActionDef({
    required this.id,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.visible = _defaultVisible,
  });

  static bool _defaultVisible() => true;

  final String id;
  final IconData icon;
  final String tooltip;
  final VoidCallback? Function() onTap;
  final bool Function() visible;
}

extension _ChatPageMobileOverflow on _ChatPageState {
  static const String _pinnedActionsPrefKey =
      'codewalk.mobile_appbar_pinned_actions';
  static const int _maxPinnedMobileActions = 3;

  List<String> _normalizePinnedMobileActionIds(Iterable<String> ids) {
    final normalized = <String>[];
    for (final rawId in ids) {
      final id = rawId.trim();
      if (id.isEmpty) {
        continue;
      }
      normalized.remove(id);
      normalized.add(id);
    }
    if (normalized.length <= _maxPinnedMobileActions) {
      return normalized;
    }
    return normalized.sublist(normalized.length - _maxPinnedMobileActions);
  }

  Future<void> _loadPinnedMobileActionsFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList(_pinnedActionsPrefKey);
      if (ids != null && mounted) {
        final normalizedIds = _normalizePinnedMobileActionIds(ids);
        _setState(() {
          _pinnedMobileAppBarActionIds = normalizedIds;
        });
        unawaited(_savePinnedMobileActionsToPrefs());
      }
    } catch (_) {
      // Non-critical; defaults to an empty list.
    }
  }

  Future<void> _savePinnedMobileActionsToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _pinnedActionsPrefKey,
        _pinnedMobileAppBarActionIds.toList(growable: false),
      );
    } catch (_) {}
  }

  void _toggleMobileActionPin(String actionId) {
    final wasPinned = _pinnedMobileAppBarActionIds.contains(actionId);
    _setState(() {
      if (wasPinned) {
        _pinnedMobileAppBarActionIds.remove(actionId);
      } else {
        if (_pinnedMobileAppBarActionIds.length >= _maxPinnedMobileActions) {
          _pinnedMobileAppBarActionIds.removeAt(0);
        }
        _pinnedMobileAppBarActionIds.add(actionId);
      }
    });
    unawaited(_savePinnedMobileActionsToPrefs());
  }

  List<_MobileAppBarActionDef> _buildMobileAppBarActionDefs() {
    final chatProvider = _chatProvider ?? context.read<ChatProvider>();
    final settingsProvider =
        _settingsProvider ?? context.read<SettingsProvider>();
    return [
      _MobileAppBarActionDef(
        id: 'undo',
        icon: Symbols.undo_rounded,
        tooltip: context.l10n.chatUndoLastTurn,
        onTap: () => chatProvider.canUndoCurrentSession
            ? () => unawaited(
                _triggerHistoryAction(
                  chatProvider,
                  action: _HistoryToolbarAction.undo,
                ),
              )
            : null,
      ),
      _MobileAppBarActionDef(
        id: 'redo',
        icon: Symbols.redo_rounded,
        tooltip: context.l10n.chatRedoLastTurn,
        visible: () => chatProvider.canRedoCurrentSession,
        onTap: () =>
            () => unawaited(
              _triggerHistoryAction(
                chatProvider,
                action: _HistoryToolbarAction.redo,
              ),
            ),
      ),
      _MobileAppBarActionDef(
        id: 'search',
        icon: Symbols.search,
        tooltip: context.l10n.chatSearchTimeline,
        onTap: () => _openTimelineSearch,
      ),
      _MobileAppBarActionDef(
        id: 'display',
        icon: Symbols.bottom_panel_close,
        tooltip: context.l10n.chatDisplayToggles,
        onTap: () =>
            () => unawaited(_openMobileDisplayTogglesDialog(settingsProvider)),
      ),
      _MobileAppBarActionDef(
        id: 'terminal',
        icon: Symbols.terminal_rounded,
        tooltip: settingsProvider.terminalPanelVisible
            ? context.l10n.terminalHide
            : (_terminalController.supportsRemoteTerminal
                  ? context.l10n.terminalOpen
                  : context.l10n.terminalOpenInfo),
        onTap: () =>
            () => unawaited(_toggleTerminalPanel()),
      ),
      _MobileAppBarActionDef(
        id: 'quickOpen',
        icon: Symbols.account_tree,
        tooltip: context.l10n.chatOpenFiles,
        onTap: () =>
            () => unawaited(_openMobileFilesDialog()),
      ),
      _MobileAppBarActionDef(
        id: 'newChat',
        icon: Symbols.add_comment,
        tooltip: context.l10n.chatNewChat,
        onTap: () => _createNewSession,
      ),
      if (!FeatureFlags.refreshlessRealtime)
        _MobileAppBarActionDef(
          id: 'refresh',
          icon: Symbols.refresh,
          tooltip: context.l10n.chatRefresh,
          onTap: () => _refreshData,
        ),
    ];
  }

  /// Renders all mobile app bar actions as a pinned-row + overflow.
  Widget _buildMobileAppBarActionsRow() {
    final allDefs = _buildMobileAppBarActionDefs();
    final visibleDefs = allDefs
        .where((def) => def.visible())
        .toList(growable: false);
    final visibleDefsById = <String, _MobileAppBarActionDef>{
      for (final def in visibleDefs) def.id: def,
    };
    final pinnedDefs = _pinnedMobileAppBarActionIds
        .map((id) => visibleDefsById[id])
        .whereType<_MobileAppBarActionDef>()
        .toList(growable: false);
    final overflowDefs = visibleDefs
        .where((def) => !pinnedDefs.contains(def))
        .toList(growable: false);

    final children = <Widget>[
      for (var index = 0; index < pinnedDefs.length; index += 1)
        SizedBox(
          key: ValueKey<String>('mobile_appbar_pinned_slot_$index'),
          width: kMinInteractiveDimension,
          height: kMinInteractiveDimension,
          child: _buildPinnableMobileAction(
            pinnedDefs[index],
            isPinned: true,
            child: IconButton(
              key: ValueKey<String>(
                'appbar_pinned_${pinnedDefs[index].id}_button',
              ),
              icon: Icon(pinnedDefs[index].icon),
              onPressed: pinnedDefs[index].onTap(),
            ),
          ),
        ),
    ];

    if (overflowDefs.isNotEmpty) {
      children.add(_buildMobileOverflowMenu(overflowDefs: overflowDefs));
    }

    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }

  Widget _buildMobileOverflowMenu({
    required List<_MobileAppBarActionDef> overflowDefs,
  }) {
    final allItems = overflowDefs;
    final menuChildren = <Widget>[];
    for (final def in allItems) {
      final onTap = def.onTap();
      final isPinned = _pinnedMobileAppBarActionIds.contains(def.id);
      final icon = isPinned
          ? Icon(def.icon, color: Theme.of(context).colorScheme.primary)
          : Icon(def.icon);
      menuChildren.add(
        MenuItemButton(
          key: ValueKey<String>('mobile_overflow_item_${def.id}'),
          leadingIcon: icon,
          trailingIcon: GestureDetector(
            onTap: () => _toggleMobileActionPin(def.id),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                Symbols.push_pin,
                size: 18,
                color: isPinned
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          onPressed: onTap,
          child: Text(def.tooltip),
        ),
      );
      if (def != allItems.last) {
        menuChildren.add(const Divider(height: 1));
      }
    }

    return MenuAnchor(
      key: const ValueKey<String>('mobile_appbar_overflow_anchor'),
      menuChildren: menuChildren,
      builder: (context, controller, child) {
        return IconButton(
          key: const ValueKey<String>('mobile_appbar_overflow_button'),
          icon: const Icon(Symbols.more_vert),
          tooltip: context.l10n.chatAppBarMoreActions,
          onPressed: controller.isOpen ? controller.close : controller.open,
        );
      },
    );
  }

  /// Wraps an action button with long-press support for pin/unpin.
  Widget _buildPinnableMobileAction(
    _MobileAppBarActionDef def, {
    required bool isPinned,
    required Widget child,
  }) {
    return GestureDetector(
      onLongPress: () => _showMobileActionPinDialog(def, isPinned),
      child: child,
    );
  }

  Future<void> _showMobileActionPinDialog(
    _MobileAppBarActionDef def,
    bool isPinned,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          key: ValueKey<String>('mobile_action_pin_dialog_${def.id}'),
          title: Text(def.tooltip),
          content: Text(
            isPinned
                ? context.l10n.chatAppBarUnpinDescription
                : context.l10n.chatAppBarPinDescription,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(context.l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                isPinned
                    ? context.l10n.chatAppBarUnpinAction
                    : context.l10n.chatAppBarPinAction,
              ),
            ),
          ],
        );
      },
    );
    if (result == true && mounted) {
      _toggleMobileActionPin(def.id);
    }
  }

  Future<void> _openMobileDisplayTogglesDialog(
    SettingsProvider settingsProvider,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final showThinking = settingsProvider.showThinkingBubbles;
            final showToolCalls = settingsProvider.showToolCallBubbles;
            final showTaskList = settingsProvider.showTaskList;
            final showReviewChanges = settingsProvider.showReviewChanges;
            final showRecentSessions = settingsProvider.showRecentSessions;
            final showSessionTabs = settingsProvider.showSessionTabs;
            final showComposerTips = settingsProvider.showComposerTips;
            return AlertDialog(
              key: const ValueKey<String>('mobile_display_toggles_dialog'),
              title: Text(context.l10n.chatDisplayToggles),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CheckboxListTile(
                      value: showThinking,
                      onChanged: (v) {
                        unawaited(
                          settingsProvider.setShowThinkingBubbles(v ?? false),
                        );
                        setDialogState(() {});
                      },
                      title: Text(
                        _displayToggleLabel(
                          _DisplayToggleAction.thinkingBubbles,
                        ),
                      ),
                    ),
                    CheckboxListTile(
                      value: showToolCalls,
                      onChanged: (v) {
                        unawaited(
                          settingsProvider.setShowToolCallBubbles(v ?? false),
                        );
                        setDialogState(() {});
                      },
                      title: Text(
                        _displayToggleLabel(
                          _DisplayToggleAction.toolCallBubbles,
                        ),
                      ),
                    ),
                    CheckboxListTile(
                      value: showTaskList,
                      onChanged: (v) {
                        unawaited(settingsProvider.setShowTaskList(v ?? false));
                        setDialogState(() {});
                      },
                      title: Text(
                        _displayToggleLabel(_DisplayToggleAction.taskList),
                      ),
                    ),
                    CheckboxListTile(
                      value: showReviewChanges,
                      onChanged: (v) {
                        unawaited(
                          settingsProvider.setShowReviewChanges(v ?? false),
                        );
                        setDialogState(() {});
                      },
                      title: Text(
                        _displayToggleLabel(_DisplayToggleAction.reviewChanges),
                      ),
                    ),
                    CheckboxListTile(
                      value: showRecentSessions,
                      onChanged: (v) {
                        unawaited(
                          settingsProvider.setShowRecentSessions(v ?? false),
                        );
                        setDialogState(() {});
                      },
                      title: Text(
                        _displayToggleLabel(
                          _DisplayToggleAction.recentSessions,
                        ),
                      ),
                    ),
                    CheckboxListTile(
                      key: const ValueKey<String>(
                        'display_toggle_item_session_tabs',
                      ),
                      value: showSessionTabs,
                      onChanged: (v) {
                        unawaited(
                          settingsProvider.setShowSessionTabsOverride(
                            v ?? false,
                          ),
                        );
                        setDialogState(() {});
                      },
                      title: Text(
                        _displayToggleLabel(_DisplayToggleAction.sessionTabs),
                      ),
                    ),
                    CheckboxListTile(
                      value: showComposerTips,
                      onChanged: (v) {
                        unawaited(
                          settingsProvider.setShowComposerTips(v ?? false),
                        );
                        setDialogState(() {});
                      },
                      title: Text(
                        _displayToggleLabel(_DisplayToggleAction.composerTips),
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      key: const ValueKey<String>(
                        'display_toggle_item_replay_tour',
                      ),
                      title: Text(
                        _displayToggleLabel(_DisplayToggleAction.replayTour),
                      ),
                      onTap: () {
                        Navigator.of(dialogContext).pop();
                        unawaited(_restartPostOnboardingTour());
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(context.l10n.chatClose),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
