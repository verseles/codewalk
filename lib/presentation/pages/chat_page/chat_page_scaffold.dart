part of '../chat_page.dart';

extension _ChatPageScaffold on _ChatPageState {
  Widget _buildSessionDrawer() {
    return Drawer(
      child: SafeArea(
        child: _buildSessionPanel(closeOnSelect: true, isMobileLayout: true),
      ),
    );
  }

  Widget _buildSidebarNavigation({required bool closeOnSelect}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      child: Row(
        children: [
          Expanded(
            child: _buildServerStatusControl(closeOnSelect: closeOnSelect),
          ),
          const SizedBox(width: 6),
          IconButton(
            key: const ValueKey<String>('sidebar_settings_icon_button'),
            tooltip: context.l10n.chatSettings,
            style: ButtonStyle(
              minimumSize: const WidgetStatePropertyAll<Size>(Size.square(40)),
              padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
                EdgeInsets.zero,
              ),
              tapTargetSize: MaterialTapTargetSize.padded,
              foregroundColor: WidgetStatePropertyAll<Color>(
                colorScheme.onSurfaceVariant,
              ),
              backgroundColor: const WidgetStatePropertyAll<Color>(
                Colors.transparent,
              ),
              overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
                if (states.contains(WidgetState.focused)) {
                  return colorScheme.primary.withValues(alpha: 0.12);
                }
                if (states.contains(WidgetState.pressed) ||
                    states.contains(WidgetState.hovered)) {
                  return colorScheme.onSurfaceVariant.withValues(alpha: 0.10);
                }
                return null;
              }),
            ),
            onPressed: () =>
                unawaited(_openSettingsPage(closeOnSelect: closeOnSelect)),
            icon: const Icon(Symbols.settings, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionPanel({
    required bool closeOnSelect,
    required bool isMobileLayout,
    VoidCallback? onCollapseRequested,
  }) {
    return Selector2<ChatProvider, ProjectProvider, _SessionPanelBuildKey>(
      selector: (_, chatProvider, projectProvider) =>
          _sessionPanelBuildKey(chatProvider, projectProvider),
      builder: (context, _, _) {
        final chatProvider = context.read<ChatProvider>();
        final projectProvider = context.read<ProjectProvider>();
        if (_sessionSearchController.text != chatProvider.sessionSearchQuery) {
          _sessionSearchController.value = TextEditingValue(
            text: chatProvider.sessionSearchQuery,
            selection: TextSelection.collapsed(
              offset: chatProvider.sessionSearchQuery.length,
            ),
          );
        }
        final hasSessionSearchQuery = chatProvider.sessionSearchQuery
            .trim()
            .isNotEmpty;
        final isSessionSearchExpanded =
            _isSessionSearchExpanded || hasSessionSearchQuery;

        void expandSessionSearch() {
          if (!_isSessionSearchExpanded) {
            _setState(() => _isSessionSearchExpanded = true);
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _sessionSearchFocusNode.requestFocus();
            }
          });
        }

        void collapseSessionSearch({required bool clearQuery}) {
          if (clearQuery && _sessionSearchController.text.isNotEmpty) {
            _sessionSearchController.clear();
            chatProvider.setSessionSearchQuery('');
          }
          _sessionSearchFocusNode.unfocus();
          if (_isSessionSearchExpanded) {
            _setState(() => _isSessionSearchExpanded = false);
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSidebarNavigation(closeOnSelect: closeOnSelect),
            if (closeOnSelect && isMobileLayout)
              _buildHamburgerReasonNotice(
                chatProvider: chatProvider,
                closeOnSelect: closeOnSelect,
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: AppAnimations.standard,
                          switchInCurve: AppAnimations.emphasizedCurve,
                          switchOutCurve: AppAnimations.accelerateCurve,
                          child: isSessionSearchExpanded
                              ? SizedBox(
                                  key: const ValueKey<String>(
                                    'session_search_field',
                                  ),
                                  height: 40,
                                  child: Focus(
                                    onKeyEvent: (node, event) {
                                      if (event is KeyDownEvent &&
                                          event.logicalKey ==
                                              LogicalKeyboardKey.escape) {
                                        collapseSessionSearch(clearQuery: true);
                                        return KeyEventResult.handled;
                                      }
                                      return KeyEventResult.ignored;
                                    },
                                    child: TextField(
                                      controller: _sessionSearchController,
                                      focusNode: _sessionSearchFocusNode,
                                      onTap: expandSessionSearch,
                                      onChanged: (query) {
                                        if (!_isSessionSearchExpanded) {
                                          _setState(
                                            () =>
                                                _isSessionSearchExpanded = true,
                                          );
                                        }
                                        chatProvider.setSessionSearchQuery(
                                          query,
                                        );
                                      },
                                      onTapOutside: (event) {
                                        if (_sessionSearchController.text
                                            .trim()
                                            .isEmpty) {
                                          collapseSessionSearch(
                                            clearQuery: false,
                                          );
                                        } else {
                                          // Dismiss keyboard but keep field
                                          // visible (query is still active).
                                          _sessionSearchFocusNode.unfocus();
                                        }
                                      },
                                      onSubmitted: (value) {
                                        if (value.trim().isEmpty) {
                                          collapseSessionSearch(
                                            clearQuery: false,
                                          );
                                        } else {
                                          // Dismiss keyboard but keep field
                                          // visible (query is still active).
                                          _sessionSearchFocusNode.unfocus();
                                        }
                                      },
                                      decoration: InputDecoration(
                                        hintText: context
                                            .l10n
                                            .chatSearchConversations,
                                        prefixIcon: const Icon(Symbols.search),
                                        suffixIcon: IconButton(
                                          icon: const Icon(Symbols.close),
                                          onPressed: () =>
                                              collapseSessionSearch(
                                                clearQuery: true,
                                              ),
                                          tooltip: context.l10n.onboardingClear,
                                        ),
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              vertical: 10,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              : Align(
                                  key: const ValueKey<String>(
                                    'session_search_title',
                                  ),
                                  alignment: AlignmentDirectional.centerStart,
                                  child: Text(
                                    context.l10n.chatConversations,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                ),
                        ),
                      ),
                      AnimatedSize(
                        duration: AppAnimations.standard,
                        curve: AppAnimations.emphasizedCurve,
                        alignment: AlignmentDirectional.centerEnd,
                        child: AnimatedSwitcher(
                          duration: AppAnimations.standard,
                          switchInCurve: AppAnimations.emphasizedCurve,
                          switchOutCurve: AppAnimations.accelerateCurve,
                          child: isSessionSearchExpanded
                              ? const SizedBox.shrink(
                                  key: ValueKey<String>(
                                    'session_header_actions_hidden',
                                  ),
                                )
                              : Row(
                                  key: const ValueKey<String>(
                                    'session_header_actions',
                                  ),
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Symbols.search),
                                      onPressed: expandSessionSearch,
                                      tooltip:
                                          context.l10n.chatSearchConversations,
                                    ),
                                    _buildSessionHeaderFilterButton(
                                      chatProvider,
                                    ),
                                    _buildTourTarget(
                                      showcaseKey: _projectContextTourKey,
                                      targetKey: _projectContextTourTargetKey,
                                      title: postOnboardingSidebarTourCopy(
                                        context: context,
                                        isMobile: false,
                                        showConversationPane: true,
                                      ).title,
                                      description:
                                          postOnboardingSidebarTourCopy(
                                            context: context,
                                            isMobile: false,
                                            showConversationPane: true,
                                          ).description,
                                      tooltipPosition: TooltipPosition.right,
                                      child: IconButton(
                                        key: const ValueKey<String>(
                                          'conversations_project_context_button',
                                        ),
                                        icon:
                                            projectProvider.currentProject ==
                                                null
                                            ? const Icon(Symbols.folder_open)
                                            : ProjectIcon(
                                                project: projectProvider
                                                    .currentProject!,
                                                size: 20,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                                autoDiscover: true,
                                              ),
                                        onPressed: () => unawaited(
                                          _openProjectSelectorDialog(),
                                        ),
                                        tooltip:
                                            context.l10n.chatProjectContext,
                                      ),
                                    ),
                                    IconButton(
                                      key: const ValueKey<String>(
                                        'sidebar_new_chat_button',
                                      ),
                                      icon: const Icon(Symbols.add),
                                      onPressed: () => unawaited(
                                        _createNewSession(
                                          closeDrawerOnCreate: closeOnSelect,
                                        ),
                                      ),
                                      tooltip: context.l10n.chatNewChat,
                                    ),
                                    if (!FeatureFlags.refreshlessRealtime)
                                      IconButton(
                                        icon: const Icon(Symbols.refresh),
                                        onPressed: _refreshData,
                                        tooltip: context.l10n.chatRefresh,
                                      ),
                                    if (onCollapseRequested != null)
                                      IconButton(
                                        key: const ValueKey<String>(
                                          'hide_conversations_sidebar_button',
                                        ),
                                        icon: const Icon(
                                          Symbols.left_panel_close_rounded,
                                        ),
                                        onPressed: onCollapseRequested,
                                        tooltip: context
                                            .l10n
                                            .chatHideConversationsSidebar,
                                      ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: _buildGroupedConversationsList(
                chatProvider: chatProvider,
                projectProvider: projectProvider,
                closeOnSelect: closeOnSelect,
                isMobileLayout: isMobileLayout,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHamburgerReasonNotice({
    required ChatProvider chatProvider,
    required bool closeOnSelect,
  }) {
    final appProvider = context.watch<AppProvider>();
    final settingsProvider = context.watch<SettingsProvider>();
    final visualTokens = Theme.of(context).visualStyleTokens;
    final badgeReason = _resolveHamburgerBadgeReason(
      chatProvider: chatProvider,
      appProvider: appProvider,
      settingsProvider: settingsProvider,
    );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeOutCubic,
      child: !badgeReason.hasBadge
          ? const SizedBox.shrink()
          : Padding(
              key: ValueKey<_HamburgerBadgeReasonKind>(badgeReason.kind),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: InkWell(
                key: const ValueKey<String>('drawer_hamburger_reason_notice'),
                onTap: _hamburgerReasonHasAction(badgeReason)
                    ? () => unawaited(
                        _handleHamburgerReasonTap(
                          badgeReason: badgeReason,
                          closeOnSelect: closeOnSelect,
                        ),
                      )
                    : null,
                borderRadius: visualTokens.isRefined
                    ? visualTokens.controlRadius
                    : BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _hamburgerReasonColor(
                            context,
                            badgeReason.kind,
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _hamburgerReasonMessage(badgeReason),
                          key: const ValueKey<String>(
                            'drawer_hamburger_reason_notice_text',
                          ),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      if (_hamburgerReasonHasAction(badgeReason)) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Symbols.arrow_forward,
                          size: 18,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  String _hamburgerReasonMessage(_HamburgerBadgeReasonState badgeReason) {
    return switch (badgeReason.kind) {
      _HamburgerBadgeReasonKind.serverAlert =>
        context.l10n.serverConnectionAttention,
      _HamburgerBadgeReasonKind.sessionError => context.l10n.sessionHasError(
        badgeReason.sessionTitle ?? context.l10n.chatConversation,
      ),
      _HamburgerBadgeReasonKind.sessionPendingInteraction =>
        context.l10n.sessionNeedsInput(
          badgeReason.sessionTitle ?? context.l10n.chatConversation,
        ),
      _HamburgerBadgeReasonKind.sessionUnreadCompletion =>
        context.l10n.sessionHasNewReply(
          badgeReason.sessionTitle ?? context.l10n.chatConversation,
        ),
      _HamburgerBadgeReasonKind.syncLoading => context.l10n.sessionSyncing,
      _HamburgerBadgeReasonKind.dataSaver =>
        context.l10n.behaviorCellularDataSaverActive,
      _HamburgerBadgeReasonKind.none => '',
    };
  }

  bool _hamburgerReasonHasAction(_HamburgerBadgeReasonState badgeReason) {
    return switch (badgeReason.kind) {
      _HamburgerBadgeReasonKind.serverAlert ||
      _HamburgerBadgeReasonKind.sessionError ||
      _HamburgerBadgeReasonKind.sessionPendingInteraction ||
      _HamburgerBadgeReasonKind.sessionUnreadCompletion ||
      _HamburgerBadgeReasonKind.dataSaver => true,
      _HamburgerBadgeReasonKind.syncLoading ||
      _HamburgerBadgeReasonKind.none => false,
    };
  }

  Color _hamburgerReasonColor(
    BuildContext context,
    _HamburgerBadgeReasonKind kind,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return switch (kind) {
      _HamburgerBadgeReasonKind.serverAlert => _hamburgerServerAlertColor(
        context,
      ),
      _HamburgerBadgeReasonKind.sessionError => colorScheme.error,
      _HamburgerBadgeReasonKind.sessionPendingInteraction =>
        colorScheme.tertiary,
      _HamburgerBadgeReasonKind.sessionUnreadCompletion ||
      _HamburgerBadgeReasonKind.syncLoading => colorScheme.primary,
      _HamburgerBadgeReasonKind.dataSaver => colorScheme.tertiary,
      _HamburgerBadgeReasonKind.none => colorScheme.outline,
    };
  }

  Color _hamburgerServerAlertColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final appProvider = context.read<AppProvider>();
    final chatProvider = context.read<ChatProvider>();
    final health = _activeServerHealth(appProvider);
    if (health == ServerHealthStatus.unhealthy) {
      return colorScheme.error;
    }
    if (_isRecoverableSyncState(chatProvider: chatProvider) &&
        chatProvider.isRecoverableSyncAlertEscalated) {
      return Colors.orange;
    }
    return _serverStatusColor(context: context, appProvider: appProvider);
  }

  Future<void> _handleHamburgerReasonTap({
    required _HamburgerBadgeReasonState badgeReason,
    required bool closeOnSelect,
  }) async {
    switch (badgeReason.kind) {
      case _HamburgerBadgeReasonKind.serverAlert:
        await _openSettingsPage(
          closeOnSelect: closeOnSelect,
          initialSectionId: 'servers',
        );
        return;
      case _HamburgerBadgeReasonKind.dataSaver:
        await _openSettingsPage(
          closeOnSelect: closeOnSelect,
          initialSectionId: 'behavior',
        );
        return;
      case _HamburgerBadgeReasonKind.sessionError:
      case _HamburgerBadgeReasonKind.sessionPendingInteraction:
      case _HamburgerBadgeReasonKind.sessionUnreadCompletion:
        final sessionId = badgeReason.sessionId?.trim();
        if (sessionId == null || sessionId.isEmpty) {
          return;
        }
        final target = context
            .read<ChatProvider>()
            .visibleSessions
            .where((item) => item.id == sessionId)
            .firstOrNull;
        if (target == null) {
          return;
        }
        await _handleSessionSwitch(target);
        _closeDrawerIfNeeded(closeOnSelect: closeOnSelect);
        return;
      case _HamburgerBadgeReasonKind.syncLoading:
      case _HamburgerBadgeReasonKind.none:
        return;
    }
  }

  Widget _buildSessionHeaderFilterButton(ChatProvider chatProvider) {
    final colorScheme = Theme.of(context).colorScheme;
    final filterLabel = _sessionFilterLabel(chatProvider.sessionListFilter);
    final sortLabel = _sessionSortLabel(
      chatProvider.sessionListSort,
      compact: true,
    );
    return PopupMenuButton<_SessionHeaderMenuAction>(
      key: const ValueKey<String>('sidebar_session_filter_button'),
      tooltip: '${context.l10n.chatFilterSessions}: $filterLabel / $sortLabel',
      onSelected: (action) =>
          _handleSessionHeaderMenuAction(action, chatProvider),
      itemBuilder: (context) => [
        PopupMenuItem<_SessionHeaderMenuAction>(
          enabled: false,
          child: Text(
            context.l10n.chatFilterSessions,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        CheckedPopupMenuItem<_SessionHeaderMenuAction>(
          key: const ValueKey<String>('sidebar_session_filter_active_item'),
          value: _SessionHeaderMenuAction.filterActive,
          checked: chatProvider.sessionListFilter == SessionListFilter.active,
          child: Text(context.l10n.chatFilterActive),
        ),
        CheckedPopupMenuItem<_SessionHeaderMenuAction>(
          key: const ValueKey<String>('sidebar_session_filter_archived_item'),
          value: _SessionHeaderMenuAction.filterArchived,
          checked: chatProvider.sessionListFilter == SessionListFilter.archived,
          child: Text(context.l10n.chatFilterArchived),
        ),
        CheckedPopupMenuItem<_SessionHeaderMenuAction>(
          key: const ValueKey<String>('sidebar_session_filter_all_item'),
          value: _SessionHeaderMenuAction.filterAll,
          checked: chatProvider.sessionListFilter == SessionListFilter.all,
          child: Text(context.l10n.chatFilterAll),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<_SessionHeaderMenuAction>(
          enabled: false,
          child: Text(
            context.l10n.chatSortSessions,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        CheckedPopupMenuItem<_SessionHeaderMenuAction>(
          key: const ValueKey<String>('sidebar_session_sort_recent_item'),
          value: _SessionHeaderMenuAction.sortRecent,
          checked: chatProvider.sessionListSort == SessionListSort.recent,
          child: Text(context.l10n.chatSortMostRecent),
        ),
        CheckedPopupMenuItem<_SessionHeaderMenuAction>(
          key: const ValueKey<String>('sidebar_session_sort_oldest_item'),
          value: _SessionHeaderMenuAction.sortOldest,
          checked: chatProvider.sessionListSort == SessionListSort.oldest,
          child: Text(context.l10n.chatSortOldest),
        ),
        CheckedPopupMenuItem<_SessionHeaderMenuAction>(
          key: const ValueKey<String>('sidebar_session_sort_title_item'),
          value: _SessionHeaderMenuAction.sortTitle,
          checked: chatProvider.sessionListSort == SessionListSort.title,
          child: Text(context.l10n.chatSortTitle),
        ),
      ],
      child: SizedBox(
        width: 44,
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(Symbols.filter_list),
            PositionedDirectional(
              top: 5,
              end: 0,
              child: Container(
                width: 30,
                height: 16,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 2),
                decoration: ShapeDecoration(
                  color: colorScheme.secondaryContainer,
                  shape: const StadiumBorder(),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _sessionHeaderFilterBadgeLabel(chatProvider),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSessionHeaderMenuAction(
    _SessionHeaderMenuAction action,
    ChatProvider chatProvider,
  ) {
    switch (action) {
      case _SessionHeaderMenuAction.filterActive:
        chatProvider.setSessionListFilter(SessionListFilter.active);
        return;
      case _SessionHeaderMenuAction.filterArchived:
        chatProvider.setSessionListFilter(SessionListFilter.archived);
        return;
      case _SessionHeaderMenuAction.filterAll:
        chatProvider.setSessionListFilter(SessionListFilter.all);
        return;
      case _SessionHeaderMenuAction.sortRecent:
        chatProvider.setSessionListSort(SessionListSort.recent);
        return;
      case _SessionHeaderMenuAction.sortOldest:
        chatProvider.setSessionListSort(SessionListSort.oldest);
        return;
      case _SessionHeaderMenuAction.sortTitle:
        chatProvider.setSessionListSort(SessionListSort.title);
        return;
    }
  }

  String _sessionFilterLabel(SessionListFilter filter) {
    return switch (filter) {
      SessionListFilter.active => context.l10n.chatFilterActive,
      SessionListFilter.archived => context.l10n.chatFilterArchived,
      SessionListFilter.all => context.l10n.chatFilterAll,
    };
  }

  String _sessionSortLabel(SessionListSort sort, {required bool compact}) {
    return switch (sort) {
      SessionListSort.recent =>
        compact ? context.l10n.chatSortRecent : context.l10n.chatSortMostRecent,
      SessionListSort.oldest => context.l10n.chatSortOldest,
      SessionListSort.title => context.l10n.chatSortTitle,
    };
  }

  String _sessionHeaderFilterBadgeLabel(ChatProvider chatProvider) {
    // Keep badge codes ASCII and bounded; tooltip/menu expose localized names.
    final filterCode = switch (chatProvider.sessionListFilter) {
      SessionListFilter.active => 'A',
      SessionListFilter.archived => 'Ar',
      SessionListFilter.all => 'All',
    };
    final sortCode = switch (chatProvider.sessionListSort) {
      SessionListSort.recent => 'R',
      SessionListSort.oldest => 'O',
      SessionListSort.title => 'T',
    };
    return '$filterCode/$sortCode';
  }

  Widget _buildGroupedConversationsList({
    required ChatProvider chatProvider,
    required ProjectProvider projectProvider,
    required bool closeOnSelect,
    required bool isMobileLayout,
  }) {
    final settingsProvider = context.watch<SettingsProvider>();
    final openProjects = projectProvider.openProjects;
    final currentProjectId = projectProvider.currentProject?.id;
    final openProjectIds = openProjects.map((project) => project.id).toSet();
    _projectGroupExpandedById.removeWhere(
      (projectId, _) => !openProjectIds.contains(projectId),
    );
    final recentEntries = settingsProvider.showRecentSessions
        ? _recentRootSessionEntries(
            chatProvider: chatProvider,
            openProjects: openProjects,
          )
        : const <MapEntry<Project, ChatSession>>[];

    final children = <Widget>[];
    if (recentEntries.isNotEmpty) {
      children.add(
        _buildRecentSessionsCard(
          chatProvider: chatProvider,
          entries: recentEntries,
          closeOnSelect: closeOnSelect,
          isMobileLayout: isMobileLayout,
        ),
      );
      children.add(SizedBox(height: isMobileLayout ? 6 : 4));
    }

    for (var index = 0; index < openProjects.length; index += 1) {
      final project = openProjects[index];
      final selected = project.id == currentProjectId;
      children.add(
        _buildProjectGroupTile(
          chatProvider: chatProvider,
          project: project,
          selected: selected,
          closeOnSelect: closeOnSelect,
          isMobileLayout: isMobileLayout,
        ),
      );
      if (index != openProjects.length - 1) {
        children.add(SizedBox(height: isMobileLayout ? 6 : 4));
      }
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(8, 0, 8, isMobileLayout ? 8 : 6),
      children: children,
    );
  }

  List<MapEntry<Project, ChatSession>> _recentRootSessionEntries({
    required ChatProvider chatProvider,
    required List<Project> openProjects,
  }) {
    final entries = <MapEntry<Project, ChatSession>>[];
    final seenSessionIds = <String>{};
    for (final project in openProjects) {
      final scopeId = _scopeIdForProject(project);
      for (final session in chatProvider.recentRootSessionsForScopeId(
        scopeId,
      )) {
        if (!seenSessionIds.add(session.id)) {
          continue;
        }
        entries.add(MapEntry<Project, ChatSession>(project, session));
      }
    }
    entries.sort((a, b) => b.value.time.compareTo(a.value.time));
    return entries.take(5).toList(growable: false);
  }

  Widget _buildRecentSessionsCard({
    required ChatProvider chatProvider,
    required List<MapEntry<Project, ChatSession>> entries,
    required bool closeOnSelect,
    required bool isMobileLayout,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(8, 8, 8, isMobileLayout ? 8 : 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Text(
              context.l10n.chatRecentSessions,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _buildRecentSessionTile(
                chatProvider: chatProvider,
                project: entry.key,
                session: entry.value,
                closeOnSelect: closeOnSelect,
                isMobileLayout: isMobileLayout,
                colorScheme: colorScheme,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecentSessionTile({
    required ChatProvider chatProvider,
    required Project project,
    required ChatSession session,
    required bool closeOnSelect,
    required bool isMobileLayout,
    required ColorScheme colorScheme,
  }) {
    final attention = chatProvider.sessionAttentionForScope(
      session.id,
      scopeId: _scopeIdForProject(project),
    );
    final isCurrentSession = chatProvider.currentSession?.id == session.id;
    final highlighted = attention.hasRecentUnreadCompletion;
    final isBusy = attention.isActive;
    final showBusySweep = isBusy && !isCurrentSession;
    final attentionKind = isCurrentSession
        ? SessionAttentionKind.none
        : attention.primaryKind;
    final menuActions = _sessionContextMenuActions(
      chatProvider: chatProvider,
      closeOnSelect: closeOnSelect,
    );
    final selectedForeground = colorScheme.primary;
    final projectLabelColor = isCurrentSession
        ? colorScheme.onSecondaryContainer
        : colorScheme.onSurfaceVariant;
    final visualTokens = Theme.of(context).visualStyleTokens;
    final projectChipColor = isCurrentSession
        ? colorScheme.secondaryContainer
        : (visualTokens.isRefined
              ? visualTokens.mutedControlSurface
              : colorScheme.surfaceContainerHighest);
    final recentTileRadius = visualTokens.isRefined
        ? visualTokens.controlRadius
        : BorderRadius.circular(16);
    final titleStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontWeight: (highlighted || isCurrentSession)
          ? FontWeight.w700
          : FontWeight.w500,
      color: (isCurrentSession || highlighted) ? selectedForeground : null,
    );
    return SidebarSelectionIndicator(
      selected: isCurrentSession,
      padding: const EdgeInsetsDirectional.only(start: 3),
      child: SessionContextMenuRegion(
        session: session,
        actions: menuActions,
        surface: 'recent',
        child: Builder(
          builder: (tileContext) {
            void openRecentContextMenu() {
              final renderObject = tileContext.findRenderObject();
              if (renderObject is! RenderBox) {
                return;
              }
              unawaited(
                showSessionContextMenu(
                  tileContext,
                  session: session,
                  actions: menuActions,
                  surface: 'recent',
                  globalPosition: renderObject.localToGlobal(
                    renderObject.size.center(Offset.zero),
                  ),
                  haptic: true,
                ),
              );
            }

            return CallbackShortcuts(
              bindings: <ShortcutActivator, VoidCallback>{
                const SingleActivator(LogicalKeyboardKey.contextMenu):
                    openRecentContextMenu,
                const SingleActivator(LogicalKeyboardKey.f10, shift: true):
                    openRecentContextMenu,
              },
              child: Semantics(
                label: context.l10n.chatSessionChatSessionSession(
                  _sessionDisplayTitle(session),
                ),
                selected: isCurrentSession,
                onLongPress: openRecentContextMenu,
                child: Material(
                  color: Colors.transparent,
                  borderRadius: recentTileRadius,
                  child: InkWell(
                    key: ValueKey<String>('recent_session_tile_${session.id}'),
                    borderRadius: recentTileRadius,
                    onTap: () => unawaited(
                      _openSessionFromProjectGroup(
                        projectId: project.id,
                        sessionId: session.id,
                        closeOnSelect: closeOnSelect,
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        10,
                        isMobileLayout ? 4 : 1,
                        8,
                        isMobileLayout ? 4 : 1,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: KeyedSubtree(
                              key: ValueKey<String>(
                                'recent_session_title_${session.id}',
                              ),
                              child: showBusySweep
                                  ? _ComposerStatusLanternText(
                                      key: ValueKey<String>(
                                        'recent_session_busy_title_${session.id}',
                                      ),
                                      text: _sessionDisplayTitle(session),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: titleStyle,
                                    )
                                  : Text(
                                      _sessionDisplayTitle(session),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: titleStyle,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (attentionKind != SessionAttentionKind.none) ...[
                            _buildRecentSessionAttentionBadge(
                              sessionId: session.id,
                              colorScheme: colorScheme,
                              kind: attentionKind,
                            ),
                            const SizedBox(width: 6),
                          ],
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 96),
                            child: Ink(
                              key: ValueKey<String>(
                                'recent_session_project_${session.id}',
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: projectChipColor,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ProjectIcon(
                                    project: project,
                                    size: 13,
                                    color: projectLabelColor,
                                    autoDiscover: true,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      _projectDisplayLabel(project),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(color: projectLabelColor),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRecentSessionAttentionBadge({
    required String sessionId,
    required ColorScheme colorScheme,
    required SessionAttentionKind kind,
  }) {
    final badgeColor = switch (kind) {
      SessionAttentionKind.error => colorScheme.error,
      SessionAttentionKind.pendingInteraction => colorScheme.tertiary,
      SessionAttentionKind.unreadCompletion => colorScheme.primary,
      SessionAttentionKind.active => colorScheme.primary,
      SessionAttentionKind.none => colorScheme.outline,
    };
    final iconColor = switch (kind) {
      SessionAttentionKind.error => colorScheme.onError,
      SessionAttentionKind.pendingInteraction => colorScheme.onTertiary,
      SessionAttentionKind.active => colorScheme.onPrimary,
      SessionAttentionKind.unreadCompletion ||
      SessionAttentionKind.none => colorScheme.onSurface,
    };
    final icon = switch (kind) {
      SessionAttentionKind.error => Symbols.error,
      SessionAttentionKind.pendingInteraction => Symbols.help,
      SessionAttentionKind.active => Symbols.sync_rounded,
      SessionAttentionKind.unreadCompletion => Symbols.circle,
      SessionAttentionKind.none => Symbols.circle,
    };
    if (kind == SessionAttentionKind.unreadCompletion) {
      return Container(
        key: ValueKey<String>(
          'recent_session_attention_badge_${kind.name}_$sessionId',
        ),
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle),
      );
    }
    return Container(
      key: ValueKey<String>(
        'recent_session_attention_badge_${kind.name}_$sessionId',
      ),
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Icon(icon, size: 11, color: iconColor),
    );
  }

  SessionContextMenuActions _sessionContextMenuActions({
    required ChatProvider chatProvider,
    required bool closeOnSelect,
  }) {
    return SessionContextMenuActions(
      onSessionDeleted: (session) async {
        await chatProvider.deleteSession(session.id);
      },
      onSessionRenamed: (session, title) {
        return chatProvider.renameSession(session, title);
      },
      onSessionShareToggled: (session) {
        return chatProvider.toggleSessionShare(session);
      },
      onSessionArchiveToggled: (session, archived) {
        return chatProvider.setSessionArchived(session, archived);
      },
      onSessionPinToggled: (session) {
        return chatProvider.toggleSessionPinned(session);
      },
      onSessionForked: (session) async {
        final created = await chatProvider.forkSession(session);
        if (!context.mounted) {
          return;
        }
        if (created == null) {
          _showChatPageMessageSnackBar(
            context.l10n.sessionForkFailed,
            hideCurrent: false,
          );
          return;
        }
        _showChatPageMessageSnackBar(
          context.l10n.sessionForked,
          hideCurrent: false,
        );
        _closeDrawerIfNeeded(closeOnSelect: closeOnSelect);
      },
      pinnedSessionIds: chatProvider.pinnedSessionIds,
    );
  }

  bool _isProjectGroupExpanded({
    required String projectId,
    required bool selected,
  }) {
    return _projectGroupExpandedById[projectId] ?? selected;
  }

  void _toggleProjectGroupExpanded({
    required String projectId,
    required bool selected,
  }) {
    final current = _isProjectGroupExpanded(
      projectId: projectId,
      selected: selected,
    );
    _setState(() {
      _projectGroupExpandedById[projectId] = !current;
    });
  }

  Widget _buildProjectGroupTile({
    required ChatProvider chatProvider,
    required Project project,
    required bool selected,
    required bool closeOnSelect,
    required bool isMobileLayout,
  }) {
    final scopeId = _scopeIdForProject(project);
    final sessions = chatProvider.visibleSessionsForScopeId(scopeId);
    final preview = sessions.take(6).toList(growable: false);
    final hasSnapshot = chatProvider.hasSnapshotForScopeId(scopeId);
    final expanded = _isProjectGroupExpanded(
      projectId: project.id,
      selected: selected,
    );
    final displayName = _projectDisplayLabel(project);
    final subtitle = _directoryLabel(project.path);
    final colorScheme = Theme.of(context).colorScheme;
    final selectedForeground = colorScheme.primary;
    final secondaryForeground = colorScheme.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          SidebarSelectionIndicator(
            selected: selected,
            child: ListTile(
              key: ValueKey<String>('project_group_tile_${project.id}'),
              dense: _useDenseListTiles(context),
              visualDensity: isMobileLayout ? VisualDensity.compact : null,
              contentPadding: EdgeInsets.symmetric(
                horizontal: isMobileLayout ? 6 : 8,
              ),
              leading: ProjectIcon(
                project: project,
                size: 20,
                color: selected ? selectedForeground : secondaryForeground,
                autoDiscover: true,
              ),
              title: Text(
                displayName,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: selected ? selectedForeground : null,
                  fontWeight: selected ? FontWeight.w700 : null,
                ),
              ),
              subtitle: subtitle == displayName
                  ? null
                  : Directionality(
                      textDirection: TextDirection.rtl,
                      child: Text(
                        subtitle,
                        textAlign: TextAlign.left,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: secondaryForeground,
                        ),
                      ),
                    ),
              selected: selected,
              onTap: () {
                if (selected) {
                  _toggleProjectGroupExpanded(
                    projectId: project.id,
                    selected: selected,
                  );
                  return;
                }
                unawaited(
                  _switchProjectFromGroup(
                    projectId: project.id,
                    closeOnSelect: closeOnSelect,
                  ),
                );
              },
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!selected && !hasSnapshot)
                    Tooltip(
                      message: context.l10n.sessionNoCachedConversations,
                      child: Icon(
                        Symbols.cloud_off,
                        size: 16,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '${sessions.length}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: selected
                            ? selectedForeground
                            : secondaryForeground,
                        fontWeight: selected ? FontWeight.w700 : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  IconButton(
                    key: ValueKey<String>('project_group_expand_${project.id}'),
                    icon: Icon(
                      expanded ? Symbols.expand_less : Symbols.expand_more,
                    ),
                    tooltip: expanded
                        ? context.l10n.chatCollapseGroup
                        : context.l10n.chatExpandGroup,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 32,
                    ),
                    onPressed: () => _toggleProjectGroupExpanded(
                      projectId: project.id,
                      selected: selected,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            if (selected)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: Column(
                  children: [
                    ChatSessionList(
                      sessions: sessions,
                      currentSession: chatProvider.currentSession,
                      pinnedSessionIds: chatProvider.pinnedSessionIds,
                      isSessionActive: chatProvider.isSessionActivelyResponding,
                      sessionAttentionFor: chatProvider.sessionAttentionFor,
                      isMobileLayout: isMobileLayout,
                      onSessionSelected: (session) async {
                        if (closeOnSelect) {
                          unawaited(
                            Future.delayed(
                              const Duration(milliseconds: 50),
                              () {
                                _closeDrawerIfNeeded(
                                  closeOnSelect: closeOnSelect,
                                );
                              },
                            ),
                          );
                          await _handleSessionSwitch(session);
                          return;
                        }
                        await _handleSessionSwitch(session);
                      },
                      onSessionDeleted: (session) async {
                        await chatProvider.deleteSession(session.id);
                      },
                      onSessionRenamed: (session, title) {
                        return chatProvider.renameSession(session, title);
                      },
                      onSessionShareToggled: (session) {
                        return chatProvider.toggleSessionShare(session);
                      },
                      onSessionArchiveToggled: (session, archived) {
                        return chatProvider.setSessionArchived(
                          session,
                          archived,
                        );
                      },
                      onSessionPinToggled: (session) {
                        return chatProvider.toggleSessionPinned(session);
                      },
                      onSessionForked: (session) async {
                        final created = await chatProvider.forkSession(session);
                        if (!context.mounted) {
                          return;
                        }
                        if (created == null) {
                          _showChatPageMessageSnackBar(
                            context.l10n.sessionForkFailed,
                            hideCurrent: false,
                          );
                          return;
                        }
                        _showChatPageMessageSnackBar(
                          context.l10n.sessionForked,
                          hideCurrent: false,
                        );
                        _closeDrawerIfNeeded(closeOnSelect: closeOnSelect);
                      },
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        4,
                        0,
                        4,
                        isMobileLayout ? 4 : 8,
                      ),
                      verticalTilePadding: isMobileLayout ? 3 : 0,
                    ),
                    if (chatProvider.canLoadMoreSessions)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                        child: OutlinedButton.icon(
                          onPressed: chatProvider.loadMoreSessions,
                          icon: const Icon(Symbols.expand_more),
                          label: Text(context.l10n.chatLoadMore),
                        ),
                      ),
                  ],
                ),
              )
            else if (preview.isNotEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(isMobileLayout ? 12 : 20, 0, 8, 8),
                child: Column(
                  children: [
                    for (final session in preview)
                      ListTile(
                        key: ValueKey<String>(
                          'project_group_session_preview_${project.id}_${session.id}',
                        ),
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 6,
                        ),
                        visualDensity: VisualDensity.compact,
                        leading: const Icon(Symbols.chat_bubble, size: 16),
                        title: Text(
                          _sessionDisplayTitle(session),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        onTap: () => unawaited(
                          _openSessionFromProjectGroup(
                            projectId: project.id,
                            sessionId: session.id,
                            closeOnSelect: closeOnSelect,
                          ),
                        ),
                      ),
                  ],
                ),
              )
            else
              Padding(
                padding: EdgeInsets.fromLTRB(
                  isMobileLayout ? 12 : 20,
                  0,
                  8,
                  12,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    hasSnapshot
                        ? context.l10n.sessionNoConversationsInProject
                        : context.l10n.sessionOpenProjectToLoad,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _switchProjectFromGroup({
    required String projectId,
    required bool closeOnSelect,
  }) async {
    await _switchProjectContext(projectId);
    if (!mounted) {
      return;
    }
    final openProjects = context.read<ProjectProvider>().openProjects;
    final openProjectIds = openProjects.map((item) => item.id).toSet();
    _setState(() {
      _projectGroupExpandedById.removeWhere(
        (id, _) => !openProjectIds.contains(id),
      );
      for (final id in openProjectIds) {
        _projectGroupExpandedById[id] = id == projectId;
      }
    });
    _closeDrawerIfNeeded(closeOnSelect: closeOnSelect);
  }

  Future<void> _openSessionFromProjectGroup({
    required String projectId,
    required String sessionId,
    required bool closeOnSelect,
  }) async {
    await _switchProjectContext(projectId);
    if (!mounted) {
      return;
    }

    final chatProvider = context.read<ChatProvider>();
    var target = chatProvider.sessions
        .where((item) => item.id == sessionId)
        .firstOrNull;
    for (var attempt = 0; target == null && attempt < 8; attempt += 1) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (!mounted) {
        return;
      }
      target = chatProvider.sessions
          .where((item) => item.id == sessionId)
          .firstOrNull;
    }

    if (target == null) {
      if (!mounted) {
        return;
      }
      _showChatPageMessageSnackBar(
        context.l10n.sessionNotAvailable,
        hideCurrent: false,
      );
      return;
    }

    await _handleSessionSwitch(target);
    _closeDrawerIfNeeded(closeOnSelect: closeOnSelect);
  }

  String _scopeIdForProject(Project project) {
    final path = project.path.trim();
    if (path.isEmpty || path == '/' || path == '-') {
      return project.id;
    }
    return path;
  }

  Widget _buildDesktopUtilityPane({VoidCallback? onCollapseRequested}) {
    return Selector2<
      ChatProvider,
      SettingsProvider,
      _DesktopUtilityPaneBuildKey
    >(
      selector: (_, chatProvider, settingsProvider) =>
          _desktopUtilityPaneBuildKey(chatProvider, settingsProvider),
      builder: (context, _, _) {
        final chatProvider = context.read<ChatProvider>();
        final settingsProvider = context.read<SettingsProvider>();
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              if (onCollapseRequested != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    key: const ValueKey<String>('hide_utility_sidebar_button'),
                    tooltip: context.l10n.chatHideUtilitySidebar,
                    onPressed: onCollapseRequested,
                    icon: const Icon(Symbols.right_panel_close_rounded),
                  ),
                ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.sessionKeyboardShortcuts,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final hint in _keyboardShortcutHints(settingsProvider))
                    _buildShortcutHint(hint.shortcut, hint.description),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _createNewSession,
                icon: const Icon(Symbols.add_comment),
                label: Text(context.l10n.chatNewChat),
              ),
              if (!FeatureFlags.refreshlessRealtime) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _refreshData,
                  icon: const Icon(Symbols.refresh),
                  label: Text(context.l10n.chatRefresh),
                ),
              ],
              const SizedBox(height: 12),
              if (chatProvider.currentSession != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Builder(
                            builder: (context) {
                              final currentSession =
                                  chatProvider.currentSession!;
                              return SessionTitleInlineEditor(
                                key: ValueKey<String>(
                                  'desktop_session_title_editor_${currentSession.id}',
                                ),
                                title: _sessionDisplayTitle(currentSession),
                                editingValue: _sessionEditingValue(
                                  currentSession,
                                ),
                                textStyle: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                                onRename: (title) => chatProvider.renameSession(
                                  currentSession,
                                  title,
                                ),
                              );
                            },
                          ),
                        ),
                        if (!FeatureFlags.refreshlessRealtime)
                          IconButton(
                            onPressed: () {
                              final session = chatProvider.currentSession;
                              if (session != null) {
                                unawaited(
                                  chatProvider.loadSessionInsights(
                                    session.id,
                                    userInitiated: true,
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Symbols.sync, size: 18),
                            tooltip: context.l10n.chatRefreshSessionDetails,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _sessionStatusLabel(
                        chatProvider.currentSessionStatus ??
                            const SessionStatusInfo(
                              type: SessionStatusType.idle,
                            ),
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.l10n.sessionChildrenCount(
                        chatProvider.currentSessionChildren.length,
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    SessionTodoListWidget(
                      todos: chatProvider.currentSessionTodo,
                      collapsed: settingsProvider.taskListCollapsed,
                      onToggleCollapsed: () => unawaited(
                        settingsProvider.setTaskListCollapsed(
                          !settingsProvider.taskListCollapsed,
                        ),
                      ),
                      maxVisibleItems: 10,
                    ),
                    if (settingsProvider.showReviewChanges) ...[
                      if (chatProvider.currentSessionDiff.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        SessionDiffViewer(
                          key: ValueKey<String>(
                            'desktop_session_diff_${chatProvider.currentSession?.id ?? 'none'}',
                          ),
                          diffs: chatProvider.currentSessionDiff,
                          compact: false,
                          onFileTap: (path, line) =>
                              unawaited(_onFilePathTap(path, line, null)),
                        ),
                      ] else if (chatProvider.isCurrentSessionDiffLoaded)
                        Text(
                          context.l10n.sessionDiffFilesCount(0),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                    if (chatProvider.isLoadingSessionInsights)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                    if (chatProvider.sessionInsightsError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          chatProvider.sessionInsightsError!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.error,
                              ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleSessionSwitch(
    ChatSession session, {
    bool cacheFirst = false,
  }) async {
    if (di.sl.isRegistered<ReadAloudService>()) {
      unawaited(di.sl<ReadAloudService>().stop());
    }
    await context.read<ChatProvider>().selectSession(
      session,
      awaitNetwork: !cacheFirst,
    );
  }
}
