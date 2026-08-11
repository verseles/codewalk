part of '../chat_page.dart';

extension _ChatPageChrome on _ChatPageState {
  String _sessionActionLabel(
    _CurrentSessionAction action, {
    required bool isShared,
    required bool isPinned,
  }) {
    return switch (action) {
      _CurrentSessionAction.rename => context.l10n.sessionTabRenameAction,
      _CurrentSessionAction.pinToggle =>
        isPinned ? context.l10n.sessionUnpin : context.l10n.sessionPin,
      _CurrentSessionAction.shareToggle =>
        isShared ? context.l10n.sessionUnshare : context.l10n.sessionShare,
      _CurrentSessionAction.copyLink => context.l10n.sessionCopyLink,
      _CurrentSessionAction.exportMarkdown =>
        context.l10n.sessionExportMarkdown,
      _CurrentSessionAction.exportJson => context.l10n.sessionExportDebugJson,
      _CurrentSessionAction.viewTasks => context.l10n.sessionViewTasks,
      _CurrentSessionAction.reviewChanges => context.l10n.chatReviewChanges,
      _CurrentSessionAction.undo => context.l10n.chatUndoLastTurn,
      _CurrentSessionAction.redo => context.l10n.chatRedoLastTurn,
      _CurrentSessionAction.compactContext =>
        context.l10n.sessionCompactContext,
    };
  }

  IconData _sessionActionIcon(
    _CurrentSessionAction action, {
    required bool isShared,
    required bool isPinned,
  }) {
    return switch (action) {
      _CurrentSessionAction.rename => Symbols.edit,
      _CurrentSessionAction.pinToggle =>
        isPinned ? Symbols.keep_off : Symbols.keep,
      _CurrentSessionAction.shareToggle =>
        isShared ? Symbols.link_off : Symbols.link,
      _CurrentSessionAction.copyLink => Symbols.content_copy,
      _CurrentSessionAction.exportMarkdown => Symbols.description,
      _CurrentSessionAction.exportJson => Symbols.data_object,
      _CurrentSessionAction.viewTasks => Symbols.checklist,
      _CurrentSessionAction.reviewChanges => Symbols.preview,
      _CurrentSessionAction.undo => Symbols.undo_rounded,
      _CurrentSessionAction.redo => Symbols.redo_rounded,
      _CurrentSessionAction.compactContext => Symbols.compress,
    };
  }

  List<PopupMenuEntry<_CurrentSessionAction>> _buildCurrentSessionActionItems(
    ChatProvider chatProvider,
    ChatSession session,
  ) {
    final shareUrl = session.shareUrl?.trim();
    final hasShareUrl = shareUrl != null && shareUrl.isNotEmpty;
    final isPinned = chatProvider.isSessionPinned(session.id);
    final canCompact =
        !chatProvider.isCompactingContext &&
        !chatProvider.canAbortActiveResponse;

    PopupMenuItem<_CurrentSessionAction> buildItem(
      _CurrentSessionAction action, {
      bool enabled = true,
    }) {
      return PopupMenuItem<_CurrentSessionAction>(
        value: action,
        enabled: enabled,
        child: Row(
          children: [
            Icon(
              _sessionActionIcon(
                action,
                isShared: session.shared,
                isPinned: isPinned,
              ),
              size: 18,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _sessionActionLabel(
                  action,
                  isShared: session.shared,
                  isPinned: isPinned,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    return [
      buildItem(_CurrentSessionAction.rename),
      buildItem(_CurrentSessionAction.pinToggle),
      const PopupMenuDivider(),
      buildItem(_CurrentSessionAction.shareToggle),
      if (hasShareUrl) buildItem(_CurrentSessionAction.copyLink),
      buildItem(_CurrentSessionAction.exportMarkdown),
      buildItem(_CurrentSessionAction.exportJson),
      const PopupMenuDivider(),
      buildItem(_CurrentSessionAction.viewTasks),
      buildItem(_CurrentSessionAction.reviewChanges),
      const PopupMenuDivider(),
      buildItem(
        _CurrentSessionAction.undo,
        enabled: chatProvider.canUndoCurrentSession,
      ),
      buildItem(
        _CurrentSessionAction.redo,
        enabled: chatProvider.canRedoCurrentSession,
      ),
      buildItem(_CurrentSessionAction.compactContext, enabled: canCompact),
    ];
  }

  Future<void> _showCurrentSessionActionsMenu({
    required Offset globalPosition,
    required bool haptic,
  }) async {
    final chatProvider = context.read<ChatProvider>();
    final session = chatProvider.currentSession;
    if (session == null) return;
    if (haptic) {
      unawaited(HapticFeedback.mediumImpact());
    }
    final overlay = Overlay.of(context).context.findRenderObject();
    if (overlay is! RenderBox) return;
    final selected = await showMenu<_CurrentSessionAction>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 1, 1),
        Offset.zero & overlay.size,
      ),
      items: _buildCurrentSessionActionItems(chatProvider, session),
    );
    if (!mounted || selected == null) return;
    await _handleCurrentSessionAction(chatProvider, action: selected);
  }

  Future<void> _handleCurrentSessionAction(
    ChatProvider chatProvider, {
    required _CurrentSessionAction action,
  }) async {
    final session = chatProvider.currentSession;
    if (session == null) {
      return;
    }

    switch (action) {
      case _CurrentSessionAction.rename:
        showSessionRenameDialog(
          context,
          session,
          SessionContextMenuActions(
            onSessionRenamed: chatProvider.renameSession,
          ),
        );
        return;
      case _CurrentSessionAction.pinToggle:
        final wasPinned = chatProvider.isSessionPinned(session.id);
        await chatProvider.toggleSessionPinned(session);
        if (!mounted) return;
        _showChatPageMessageSnackBar(
          context.l10n.chatSessionConversationNextAction(
            wasPinned
                ? context.l10n.sessionActionUnpinned
                : context.l10n.sessionActionPinned,
          ),
          hideCurrent: false,
        );
        return;
      case _CurrentSessionAction.shareToggle:
        final wasShared = session.shared;
        final ok = await chatProvider.toggleSessionShare(session);
        if (!mounted) {
          return;
        }
        _showChatPageMessageSnackBar(
          ok
              ? (wasShared
                    ? context.l10n.sessionUnshared
                    : context.l10n.sessionShared)
              : (chatProvider.errorMessage ??
                    context.l10n.sessionFailedUpdateSharing),
          hideCurrent: false,
        );
        return;
      case _CurrentSessionAction.copyLink:
        final link = chatProvider.currentSession?.shareUrl?.trim();
        if (link == null || link.isEmpty) {
          _showChatPageMessageSnackBar(
            context.l10n.sessionShareLinkUnavailable,
            hideCurrent: false,
          );
          return;
        }
        await Clipboard.setData(ClipboardData(text: link));
        if (!mounted) {
          return;
        }
        _showChatPageMessageSnackBar(
          context.l10n.sessionShareLinkCopied,
          hideCurrent: false,
        );
        return;
      case _CurrentSessionAction.exportMarkdown:
        await _exportCurrentSession(
          chatProvider,
          format: _SessionExportFormat.markdown,
        );
        return;
      case _CurrentSessionAction.exportJson:
        await _exportCurrentSession(
          chatProvider,
          format: _SessionExportFormat.json,
        );
        return;
      case _CurrentSessionAction.viewTasks:
        await _openCurrentSessionInsightsDialog(
          chatProvider,
          reviewFirst: false,
        );
        return;
      case _CurrentSessionAction.reviewChanges:
        await _openCurrentSessionInsightsDialog(
          chatProvider,
          reviewFirst: true,
        );
        return;
      case _CurrentSessionAction.undo:
        await _triggerHistoryAction(
          chatProvider,
          action: _HistoryToolbarAction.undo,
        );
        return;
      case _CurrentSessionAction.redo:
        await _triggerHistoryAction(
          chatProvider,
          action: _HistoryToolbarAction.redo,
        );
        return;
      case _CurrentSessionAction.compactContext:
        await _compactCurrentSession(chatProvider);
        return;
    }
  }

  Future<void> _exportCurrentSession(
    ChatProvider chatProvider, {
    required _SessionExportFormat format,
  }) async {
    final session = chatProvider.currentSession;
    if (session == null) {
      return;
    }

    if (chatProvider.hasMoreOldMessages) {
      await chatProvider.loadOlderMessages();
    }

    const exporter = SessionExportService();
    final messages = chatProvider.messages;
    final isMarkdown = format == _SessionExportFormat.markdown;
    final extension = isMarkdown ? 'md' : 'json';
    final content = isMarkdown
        ? exporter.markdown(session, messages)
        : exporter.json(session, messages);
    final fileName = exporter.fileName(session, extension);

    try {
      final savedPath = await FilePicker.saveFile(
        dialogTitle: isMarkdown
            ? context.l10n.sessionExportMarkdownTitle
            : context.l10n.sessionExportDebugJsonTitle,
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: [extension],
        bytes: exporter.bytes(content),
      );
      if (!mounted) {
        return;
      }
      if (savedPath == null && !kIsWeb) {
        _showChatPageMessageSnackBar(context.l10n.sessionExportCanceled);
        return;
      }
      _showChatPageMessageSnackBar(
        isMarkdown
            ? context.l10n.sessionExportMarkdownSaved
            : context.l10n.sessionExportDebugJsonSaved,
      );
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: content));
      if (!mounted) {
        return;
      }
      _showChatPageMessageSnackBar(
        isMarkdown
            ? context.l10n.sessionExportMarkdownErrorClipboard
            : context.l10n.sessionExportDebugJsonErrorClipboard,
      );
    }
  }

  Future<void> _openCurrentSessionInsightsDialog(
    ChatProvider chatProvider, {
    required bool reviewFirst,
  }) async {
    final session = chatProvider.currentSession;
    if (session == null) {
      return;
    }

    final title = _sessionDisplayTitle(chatProvider.currentSession ?? session);
    final isCompactLayout =
        context.windowSizeClass.isCompact || _isMobileRuntime;
    unawaited(
      chatProvider.loadSessionInsights(
        session.id,
        userInitiated: true,
        // Review Changes expects a session-wide view; scan recent user turns
        // so a turn that produced no file changes does not hide older diffs.
        exhaustiveDiffScan: reviewFirst,
      ),
    );

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final content = ChangeNotifierProvider<ChatProvider>.value(
          value: chatProvider,
          child: Consumer<ChatProvider>(
            builder: (context, liveChatProvider, _) {
              return _buildCurrentSessionInsightsContent(
                liveChatProvider,
                reviewFirst: reviewFirst,
              );
            },
          ),
        );
        if (isCompactLayout) {
          return Dialog.fullscreen(
            child: Scaffold(
              key: const ValueKey<String>('current_session_insights_dialog'),
              appBar: AppBar(
                title: Text(title),
                leading: IconButton(
                  icon: const Icon(Symbols.close),
                  tooltip: context.l10n.chatClose,
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ),
              body: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: content,
                ),
              ),
            ),
          );
        }

        return Dialog(
          key: const ValueKey<String>('current_session_insights_dialog'),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720, maxHeight: 680),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(dialogContext).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Symbols.close),
                        tooltip: context.l10n.chatClose,
                        onPressed: () => Navigator.of(dialogContext).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(child: SingleChildScrollView(child: content)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCurrentSessionInsightsContent(
    ChatProvider chatProvider, {
    required bool reviewFirst,
  }) {
    final children = <Widget>[
      if (chatProvider.isLoadingSessionInsights)
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: LinearProgressIndicator(minHeight: 2),
        ),
      if (chatProvider.sessionInsightsError != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            chatProvider.sessionInsightsError!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
    ];

    if (reviewFirst) {
      children.addAll(_buildCurrentSessionReviewSection(chatProvider));
      children.addAll(_buildCurrentSessionTodoSection(chatProvider));
    } else {
      children.addAll(_buildCurrentSessionTodoSection(chatProvider));
      children.addAll(_buildCurrentSessionReviewSection(chatProvider));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  List<Widget> _buildCurrentSessionTodoSection(ChatProvider chatProvider) {
    return <Widget>[
      Text(
        context.l10n.chatTasks,
        key: const ValueKey<String>('current_session_tasks_heading'),
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      if (chatProvider.currentSessionTodo.isEmpty)
        Text(
          context.l10n.chatTasksAvailableSession,
          style: Theme.of(context).textTheme.bodyMedium,
        )
      else
        SessionTodoListWidget(
          todos: chatProvider.currentSessionTodo,
          collapsed: false,
          onToggleCollapsed: () {},
          maxVisibleItems: 10,
        ),
      const SizedBox(height: 16),
    ];
  }

  List<Widget> _buildCurrentSessionReviewSection(ChatProvider chatProvider) {
    final hasLoaded = chatProvider.isCurrentSessionDiffLoaded;
    final hasError = chatProvider.currentSessionDiffError;
    final isLoading = chatProvider.isLoadingSessionInsights && !hasLoaded;
    return <Widget>[
      Text(
        context.l10n.chatReviewChanges,
        key: const ValueKey<String>('current_session_review_heading'),
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      if (chatProvider.currentSessionDiff.isNotEmpty)
        SessionDiffViewer(
          key: ValueKey<String>(
            'dialog_session_diff_${chatProvider.currentSession?.id ?? 'none'}',
          ),
          diffs: chatProvider.currentSessionDiff,
          compact: false,
          onFileTap: (path, line) =>
              unawaited(_onFilePathTap(path, line, null)),
        )
      else if (isLoading)
        Padding(
          key: const ValueKey<String>('current_session_review_loading'),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            context.l10n.sessionDiffLoading,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        )
      else if (!hasLoaded && hasError != null)
        Padding(
          key: const ValueKey<String>('current_session_review_error'),
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            hasError,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        )
      else
        Text(
          context.l10n.chatChangedFilesAvailable,
          key: const ValueKey<String>('current_session_review_empty'),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
    ];
  }

  VerticalDivider _buildPaneDivider() {
    return VerticalDivider(
      width: 1,
      thickness: 1,
      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.12),
    );
  }

  String _desktopPaneLabel(DesktopPane pane) {
    return switch (pane) {
      DesktopPane.conversations => context.l10n.chatConversations,
      DesktopPane.files => context.l10n.filesTitle,
      DesktopPane.utility => context.l10n.utilityTitle,
    };
  }

  String _displayToggleLabel(_DisplayToggleAction action) {
    return switch (action) {
      _DisplayToggleAction.thinkingBubbles =>
        context.l10n.settingsAppearanceThinkingBubbles,
      _DisplayToggleAction.toolCallBubbles =>
        context.l10n.settingsAppearanceToolCallBubbles,
      _DisplayToggleAction.taskList => context.l10n.settingsAppearanceTaskList,
      _DisplayToggleAction.reviewChanges => context.l10n.chatReviewChanges,
      _DisplayToggleAction.recentSessions => context.l10n.chatRecentSessions,
      _DisplayToggleAction.sessionTabs => context.l10n.chatSessionTabsToggle,
      _DisplayToggleAction.composerTips =>
        context.l10n.settingsAppearanceComposerTips,
      _DisplayToggleAction.replayTour =>
        context.l10n.settingsAboutReplayChatTour,
    };
  }

  Widget _buildProjectScopeLoadingOverlay() {
    final colorScheme = Theme.of(context).colorScheme;
    return AbsorbPointer(
      key: const ValueKey<String>('project_scope_loading_overlay'),
      child: ColoredBox(
        color: colorScheme.surface.withValues(alpha: 0.74),
        child: Center(
          child: Card(
            child: Padding(
              padding: AppDensitySpacing.overlayCardPadding(
                _settingsProvider?.appDensity ?? AppDensity.normal,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  ),
                  SizedBox(
                    width: AppDensitySpacing.mediumGap(
                      _settingsProvider?.appDensity ?? AppDensity.normal,
                    ),
                  ),
                  Text(
                    context.l10n.chatLoadingProjectContext,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _toolbarHeightForDensity({
    required bool isMobile,
    required AppDensity density,
  }) {
    final base = isMobile ? 46.0 : 44.0;
    return switch (density) {
      AppDensity.extraDense => base - 4,
      AppDensity.dense => base - 2,
      AppDensity.normal => base,
      AppDensity.spacious => base + 4,
      AppDensity.extraSpacious => base + 8,
    };
  }

  bool _useDenseListTiles(BuildContext context) {
    return Theme.of(context).visualDensity.vertical < 0;
  }

  AppBar _buildAppBar({
    required bool isMobile,
    required bool isLargeDesktop,
    required SettingsProvider settingsProvider,
  }) {
    const refreshlessEnabled = FeatureFlags.refreshlessRealtime;
    return AppBar(
      toolbarHeight: _toolbarHeightForDensity(
        isMobile: isMobile,
        density: settingsProvider.appDensity,
      ),
      leadingWidth: isMobile ? 42 : null,
      leading: isMobile
          ? Builder(
              builder: (leadingContext) {
                return Consumer3<ChatProvider, AppProvider, SettingsProvider>(
                  builder:
                      (
                        context,
                        chatProvider,
                        appProvider,
                        settingsProvider,
                        _,
                      ) {
                        final badgeReason = _resolveHamburgerBadgeReason(
                          chatProvider: chatProvider,
                          appProvider: appProvider,
                          settingsProvider: settingsProvider,
                        );
                        final alertColor = _hamburgerServerAlertColor(context);
                        const menuIcon = Icon(Symbols.menu);
                        final alertIcon = SizedBox(
                          width: 24,
                          height: 24,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              const Positioned.fill(child: Icon(Symbols.menu)),
                              Positioned(
                                top: -1,
                                right: -1,
                                child: Container(
                                  key: const ValueKey<String>(
                                    'appbar_drawer_alert_badge',
                                  ),
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: alertColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                        final loadingIcon = SizedBox(
                          width: 24,
                          height: 24,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              const Positioned.fill(child: Icon(Symbols.menu)),
                              Positioned(
                                top: -1,
                                right: -1,
                                child: SizedBox(
                                  key: const ValueKey<String>(
                                    'appbar_drawer_sync_loading',
                                  ),
                                  width: 9,
                                  height: 9,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.4,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                        final attentionIcon = SizedBox(
                          width: 24,
                          height: 24,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              const Positioned.fill(child: Icon(Symbols.menu)),
                              Positioned(
                                top: -1,
                                right: -1,
                                child: Container(
                                  key: const ValueKey<String>(
                                    'appbar_drawer_attention_badge',
                                  ),
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _sessionAttentionBadgeColor(
                                      context: context,
                                      kind:
                                          _sessionAttentionKindForHamburgerReason(
                                            badgeReason.kind,
                                          ),
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                        final dataSaverIcon = SizedBox(
                          width: 24,
                          height: 24,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              const Positioned.fill(child: Icon(Symbols.menu)),
                              Positioned(
                                top: -1,
                                right: -1,
                                child: Container(
                                  key: const ValueKey<String>(
                                    'appbar_drawer_data_saver_badge',
                                  ),
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.tertiary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                        final sidebarTourCopy = postOnboardingSidebarTourCopy(
                          context: context,
                          isMobile: true,
                          showConversationPane: false,
                        );
                        return _buildTourTarget(
                          showcaseKey: _drawerAccessTourKey,
                          targetKey: _drawerAccessTourTargetKey,
                          title: sidebarTourCopy.title,
                          description: sidebarTourCopy.description,
                          tooltipPosition: TooltipPosition.bottom,
                          onNext: () =>
                              unawaited(_advancePostOnboardingTourToComposer()),
                          child: IconButton(
                            key: const ValueKey<String>('appbar_drawer_button'),
                            tooltip: MaterialLocalizations.of(
                              leadingContext,
                            ).openAppDrawerTooltip,
                            onPressed: () =>
                                Scaffold.of(leadingContext).openDrawer(),
                            icon: switch (badgeReason.kind) {
                              _HamburgerBadgeReasonKind.serverAlert =>
                                alertIcon,
                              _HamburgerBadgeReasonKind.sessionError ||
                              _HamburgerBadgeReasonKind
                                  .sessionPendingInteraction ||
                              _HamburgerBadgeReasonKind
                                  .sessionUnreadCompletion => attentionIcon,
                              _HamburgerBadgeReasonKind.syncLoading =>
                                loadingIcon,
                              _HamburgerBadgeReasonKind.dataSaver =>
                                dataSaverIcon,
                              _HamburgerBadgeReasonKind.none => menuIcon,
                            },
                          ),
                        );
                      },
                );
              },
            )
          : null,
      titleSpacing: isMobile
          ? 0
          : AppDensitySpacing.appBarTitleSpacing(settingsProvider.appDensity),
      title: _timelineSearchActive
          ? _buildTimelineSearchTitle()
          : _buildProjectSelectorTitle(
              isMobile: isMobile,
              isLargeDesktop: isLargeDesktop,
            ),
      actions: _timelineSearchActive
          ? _buildTimelineSearchActions()
          : isMobile
          ? [_buildMobileAppBarActionsRow()]
          : [
              if (!isMobile)
                _buildTourTarget(
                  showcaseKey: _desktopSidebarMenuTourKey,
                  targetKey: _desktopSidebarMenuTourTargetKey,
                  title: postOnboardingSidebarTourCopy(
                    context: context,
                    isMobile: false,
                    showConversationPane: false,
                  ).title,
                  description: postOnboardingSidebarTourCopy(
                    context: context,
                    isMobile: false,
                    showConversationPane: false,
                  ).description,
                  tooltipPosition: TooltipPosition.bottom,
                  child: PopupMenuButton<DesktopPane>(
                    key: const ValueKey<String>('desktop_sidebars_menu_button'),
                    tooltip: context.l10n.chatToggleSidebars,
                    onSelected: (pane) {
                      final next = !settingsProvider.isDesktopPaneVisible(pane);
                      unawaited(
                        settingsProvider.setDesktopPaneVisible(pane, next),
                      );
                    },
                    itemBuilder: (context) {
                      return DesktopPane.values
                          .map(
                            (pane) => PopupMenuItem<DesktopPane>(
                              key: ValueKey<String>(
                                'desktop_sidebar_menu_item_${pane.name}',
                              ),
                              value: pane,
                              child: Row(
                                children: [
                                  Icon(
                                    settingsProvider.isDesktopPaneVisible(pane)
                                        ? Symbols.check_box_rounded
                                        : Symbols
                                              .check_box_outline_blank_rounded,
                                    size: 18,
                                  ),
                                  SizedBox(
                                    width: AppDensitySpacing.itemGap(
                                      settingsProvider.appDensity,
                                    ),
                                  ),
                                  Text(_desktopPaneLabel(pane)),
                                ],
                              ),
                            ),
                          )
                          .toList(growable: false);
                    },
                    icon: const Icon(Symbols.view_sidebar),
                  ),
                ),
              Consumer<ChatProvider>(
                builder: (context, chatProvider, _) {
                  return IconButton(
                    key: const ValueKey<String>('appbar_undo_button'),
                    icon: const Icon(Symbols.undo_rounded),
                    tooltip: context.l10n.chatUndoLastTurn,
                    onPressed: chatProvider.canUndoCurrentSession
                        ? () => unawaited(
                            _triggerHistoryAction(
                              chatProvider,
                              action: _HistoryToolbarAction.undo,
                            ),
                          )
                        : null,
                  );
                },
              ),
              Consumer<ChatProvider>(
                builder: (context, chatProvider, _) {
                  if (!chatProvider.canRedoCurrentSession) {
                    return const SizedBox.shrink();
                  }
                  return IconButton(
                    key: const ValueKey<String>('appbar_redo_button'),
                    icon: const Icon(Symbols.redo_rounded),
                    tooltip: context.l10n.chatRedoLastTurn,
                    onPressed: () => unawaited(
                      _triggerHistoryAction(
                        chatProvider,
                        action: _HistoryToolbarAction.redo,
                      ),
                    ),
                  );
                },
              ),
              IconButton(
                key: const ValueKey<String>('appbar_timeline_search_button'),
                icon: const Icon(Symbols.search),
                tooltip: context.l10n.chatSearchTimeline,
                onPressed: _openTimelineSearch,
              ),
              PopupMenuButton<_DisplayToggleAction>(
                key: const ValueKey<String>('appbar_display_toggles_button'),
                tooltip: context.l10n.chatDisplayToggles,
                onSelected: (action) {
                  switch (action) {
                    case _DisplayToggleAction.thinkingBubbles:
                      unawaited(
                        settingsProvider.setShowThinkingBubbles(
                          !settingsProvider.showThinkingBubbles,
                        ),
                      );
                      break;
                    case _DisplayToggleAction.toolCallBubbles:
                      unawaited(
                        settingsProvider.setShowToolCallBubbles(
                          !settingsProvider.showToolCallBubbles,
                        ),
                      );
                      break;
                    case _DisplayToggleAction.taskList:
                      unawaited(
                        settingsProvider.setShowTaskList(
                          !settingsProvider.showTaskList,
                        ),
                      );
                      break;
                    case _DisplayToggleAction.reviewChanges:
                      unawaited(
                        settingsProvider.setShowReviewChanges(
                          !settingsProvider.showReviewChanges,
                        ),
                      );
                      break;
                    case _DisplayToggleAction.recentSessions:
                      unawaited(
                        settingsProvider.setShowRecentSessions(
                          !settingsProvider.showRecentSessions,
                        ),
                      );
                      break;
                    case _DisplayToggleAction.sessionTabs:
                      unawaited(
                        settingsProvider.setShowSessionTabsOverride(
                          !settingsProvider.showSessionTabs,
                        ),
                      );
                      break;
                    case _DisplayToggleAction.composerTips:
                      unawaited(
                        settingsProvider.setShowComposerTips(
                          !settingsProvider.showComposerTips,
                        ),
                      );
                      break;
                    case _DisplayToggleAction.replayTour:
                      unawaited(_restartPostOnboardingTour());
                      break;
                  }
                },
                itemBuilder: (context) {
                  return [
                    PopupMenuItem<_DisplayToggleAction>(
                      enabled: false,
                      child: Text(
                        context.l10n.chatDisplay,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    CheckedPopupMenuItem<_DisplayToggleAction>(
                      key: const ValueKey<String>(
                        'display_toggle_item_thinking',
                      ),
                      value: _DisplayToggleAction.thinkingBubbles,
                      checked: settingsProvider.showThinkingBubbles,
                      child: Text(
                        _displayToggleLabel(
                          _DisplayToggleAction.thinkingBubbles,
                        ),
                      ),
                    ),
                    CheckedPopupMenuItem<_DisplayToggleAction>(
                      key: const ValueKey<String>(
                        'display_toggle_item_tool_calls',
                      ),
                      value: _DisplayToggleAction.toolCallBubbles,
                      checked: settingsProvider.showToolCallBubbles,
                      child: Text(
                        _displayToggleLabel(
                          _DisplayToggleAction.toolCallBubbles,
                        ),
                      ),
                    ),
                    CheckedPopupMenuItem<_DisplayToggleAction>(
                      key: const ValueKey<String>(
                        'display_toggle_item_task_list',
                      ),
                      value: _DisplayToggleAction.taskList,
                      checked: settingsProvider.showTaskList,
                      child: Text(
                        _displayToggleLabel(_DisplayToggleAction.taskList),
                      ),
                    ),
                    CheckedPopupMenuItem<_DisplayToggleAction>(
                      key: const ValueKey<String>(
                        'display_toggle_item_review_changes',
                      ),
                      value: _DisplayToggleAction.reviewChanges,
                      checked: settingsProvider.showReviewChanges,
                      child: Text(
                        _displayToggleLabel(_DisplayToggleAction.reviewChanges),
                      ),
                    ),
                    CheckedPopupMenuItem<_DisplayToggleAction>(
                      key: const ValueKey<String>(
                        'display_toggle_item_recent_sessions',
                      ),
                      value: _DisplayToggleAction.recentSessions,
                      checked: settingsProvider.showRecentSessions,
                      child: Text(
                        _displayToggleLabel(
                          _DisplayToggleAction.recentSessions,
                        ),
                      ),
                    ),
                    CheckedPopupMenuItem<_DisplayToggleAction>(
                      key: const ValueKey<String>(
                        'display_toggle_item_session_tabs',
                      ),
                      value: _DisplayToggleAction.sessionTabs,
                      checked: settingsProvider.showSessionTabs,
                      child: Text(
                        _displayToggleLabel(_DisplayToggleAction.sessionTabs),
                      ),
                    ),
                    CheckedPopupMenuItem<_DisplayToggleAction>(
                      key: const ValueKey<String>(
                        'display_toggle_item_composer_tips',
                      ),
                      value: _DisplayToggleAction.composerTips,
                      checked: settingsProvider.showComposerTips,
                      child: Text(
                        _displayToggleLabel(_DisplayToggleAction.composerTips),
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem<_DisplayToggleAction>(
                      key: const ValueKey<String>(
                        'display_toggle_item_replay_tour',
                      ),
                      value: _DisplayToggleAction.replayTour,
                      child: Text(
                        _displayToggleLabel(_DisplayToggleAction.replayTour),
                      ),
                    ),
                  ];
                },
                icon: const Icon(Symbols.bottom_panel_close),
              ),
              IconButton(
                key: const ValueKey<String>('appbar_terminal_button'),
                // Feedback stays in the button itself, so the press is
                // acknowledged where the user looked (#125).
                icon: _isOpeningTerminal
                    ? const SizedBox(
                        key: ValueKey<String>('appbar_terminal_button_loading'),
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Symbols.terminal_rounded),
                tooltip: settingsProvider.terminalPanelVisible
                    ? context.l10n.terminalHide
                    : (_terminalController.supportsRemoteTerminal
                          ? context.l10n.terminalOpen
                          : context.l10n.terminalOpenInfo),
                onPressed: _isOpeningTerminal
                    ? null
                    : () => unawaited(_toggleTerminalPanel()),
              ),
              if (refreshlessEnabled && !isMobile)
                Consumer2<ChatProvider, AppProvider>(
                  builder: (context, chatProvider, appProvider, child) {
                    final label = _syncStatusLabel(
                      context: context,
                      chatProvider: chatProvider,
                      appProvider: appProvider,
                    );
                    final color = _syncStatusColor(
                      context: context,
                      chatProvider: chatProvider,
                      appProvider: appProvider,
                    );
                    return Tooltip(
                      message: context.l10n.chatSyncLabel(label),
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: AppDensitySpacing.syncChipRightPadding(
                            settingsProvider.appDensity,
                          ),
                        ),
                        child: Container(
                          key: const ValueKey<String>('chat_sync_status_chip'),
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Icon(
                            Symbols.sync_rounded,
                            size: 14,
                            color: color,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              if (isMobile)
                IconButton(
                  key: const ValueKey<String>('appbar_quick_open_button'),
                  icon: const Icon(Symbols.account_tree),
                  tooltip: context.l10n.chatOpenFiles,
                  onPressed: () => unawaited(_openMobileFilesDialog()),
                ),
              if (!isMobile)
                _buildTourTarget(
                  showcaseKey: _newChatTourKey,
                  targetKey: _newChatTourTargetKey,
                  title: context.l10n.chatNewChatTourTitle,
                  description: context.l10n.chatNewChatTourDescription,
                  tooltipPosition: TooltipPosition.bottom,
                  includePrevious: true,
                  onNext: () =>
                      unawaited(_advancePostOnboardingTourToComposer()),
                  child: IconButton(
                    icon: const Icon(Symbols.add_comment),
                    tooltip: context.l10n.chatNewChat,
                    onPressed: _createNewSession,
                  ),
                ),
              if (!refreshlessEnabled)
                IconButton(
                  icon: const Icon(Symbols.refresh),
                  tooltip: context.l10n.chatRefresh,
                  onPressed: _refreshData,
                ),
              if (isMobile)
                _buildTourTarget(
                  showcaseKey: _newChatTourKey,
                  targetKey: _newChatTourTargetKey,
                  title: context.l10n.chatNewChatTourTitle,
                  description: context.l10n.chatNewChatTourDescription,
                  tooltipPosition: TooltipPosition.bottom,
                  includePrevious: true,
                  onNext: () =>
                      unawaited(_advancePostOnboardingTourToComposer()),
                  child: IconButton(
                    icon: const Icon(Symbols.add_comment),
                    tooltip: context.l10n.chatNewChat,
                    onPressed: _createNewSession,
                  ),
                ),
              SizedBox(
                width: AppDensitySpacing.smallGap(settingsProvider.appDensity),
              ),
            ],
    );
  }

  Widget _buildTimelineSearchTitle() {
    return TextField(
      key: const ValueKey<String>('timeline_search_field'),
      controller: _timelineSearchController,
      focusNode: _timelineSearchFocusNode,
      autofocus: true,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        border: InputBorder.none,
        hintText: context.l10n.chatSearchTimeline,
      ),
      onChanged: _onTimelineSearchChanged,
    );
  }

  List<Widget> _buildTimelineSearchActions() {
    final hasResults = _timelineSearchResult.isNotEmpty;
    final resultLabel = _timelineSearchResultLabel();
    return [
      if (resultLabel.isNotEmpty)
        Center(
          child: Padding(
            padding: AppDensitySpacing.searchResultLabelPadding(
              _settingsProvider?.appDensity ?? AppDensity.normal,
            ),
            child: Text(
              resultLabel,
              key: const ValueKey<String>('timeline_search_result_count'),
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        ),
      IconButton(
        key: const ValueKey<String>('timeline_search_previous_button'),
        icon: const Icon(Symbols.keyboard_arrow_up_rounded),
        tooltip: context.l10n.chatSearchPreviousResult,
        onPressed: hasResults
            ? () => unawaited(_goToTimelineSearchResult(-1))
            : null,
      ),
      IconButton(
        key: const ValueKey<String>('timeline_search_next_button'),
        icon: const Icon(Symbols.keyboard_arrow_down_rounded),
        tooltip: context.l10n.chatSearchNextResult,
        onPressed: hasResults
            ? () => unawaited(_goToTimelineSearchResult(1))
            : null,
      ),
      IconButton(
        key: const ValueKey<String>('timeline_search_close_button'),
        icon: const Icon(Symbols.close),
        tooltip: context.l10n.chatClose,
        onPressed: _closeTimelineSearch,
      ),
    ];
  }

  Future<void> _openMobileFilesDialog() async {
    if (!mounted) {
      return;
    }
    final projectProvider = context.read<ProjectProvider>();
    final appProvider = context.read<AppProvider>();
    final chatProvider = context.read<ChatProvider>();
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return MultiProvider(
          providers: [
            ChangeNotifierProvider<ProjectProvider>.value(
              value: projectProvider,
            ),
            ChangeNotifierProvider<AppProvider>.value(value: appProvider),
            ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
          ],
          child: Dialog.fullscreen(
            key: const ValueKey<String>('mobile_files_dialog_fullscreen'),
            child: Scaffold(
              appBar: AppBar(
                title: Text(context.l10n.filesTitle),
                leading: IconButton(
                  icon: const Icon(Symbols.close),
                  tooltip: context.l10n.chatClose,
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ),
              body: StatefulBuilder(
                builder: (statefulContext, setDialogState) {
                  return Consumer3<ProjectProvider, AppProvider, ChatProvider>(
                    builder:
                        (
                          context,
                          projectProvider,
                          appProvider,
                          chatProvider,
                          _,
                        ) {
                          final fileState = _resolveFileContextState(
                            projectProvider: projectProvider,
                            appProvider: appProvider,
                          );
                          _reconcileFileContextWithSessionDiff(
                            contextKey: projectProvider.contextKey,
                            fileState: fileState,
                            chatProvider: chatProvider,
                            projectProvider: projectProvider,
                          );
                          return SafeArea(
                            child: _buildFileExplorerPanel(
                              fileState: fileState,
                              projectProvider: projectProvider,
                              isMobileLayout: true,
                              onStateChanged: () {
                                if (!statefulContext.mounted) {
                                  return;
                                }
                                setDialogState(() {});
                              },
                            ),
                          );
                        },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Color _contextUsageColor(
    BuildContext context, {
    required int usagePercent,
    required bool enabled,
  }) {
    if (!enabled) {
      return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38);
    }
    if (usagePercent >= 85) {
      return Theme.of(context).colorScheme.error;
    }
    if (usagePercent >= 65) {
      return Colors.orange;
    }
    return Theme.of(context).colorScheme.primary;
  }

  Widget _buildContextUsageRow(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  String _formatUsd(double value) {
    if (value.isNaN || value.isInfinite) {
      return r'$0.0000';
    }
    return r'$' + value.toStringAsFixed(4);
  }

  String _formatIntWithGroup(int value) {
    final sign = value < 0 ? '-' : '';
    final digits = value.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i += 1) {
      final remaining = digits.length - i;
      buffer.write(digits[i]);
      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write(',');
      }
    }
    return '$sign$buffer';
  }

  Color _syncStatusColor({
    required BuildContext context,
    required ChatProvider chatProvider,
    required AppProvider appProvider,
  }) {
    final deferForegroundWarnings = _shouldDeferForegroundWarningUi(
      chatProvider: chatProvider,
      appProvider: appProvider,
    );
    final hasRecoverableSyncState = _isRecoverableSyncState(
      chatProvider: chatProvider,
    );
    if (hasRecoverableSyncState) {
      // Show error color immediately when the device is confirmed offline,
      // regardless of the loading indicator state.
      if (!appProvider.isConnected && !deferForegroundWarnings) {
        return Theme.of(context).colorScheme.error;
      }
      return Theme.of(context).colorScheme.primary;
    }
    if (!appProvider.isConnected && !deferForegroundWarnings) {
      return Theme.of(context).colorScheme.error;
    }
    return Colors.green;
  }

  bool _isRecoverableSyncState({required ChatProvider chatProvider}) {
    return chatProvider.syncState == ChatSyncState.reconnecting ||
        chatProvider.syncState == ChatSyncState.delayed ||
        chatProvider.isInDegradedMode;
  }

  bool _isRecoverableSyncLoading({required ChatProvider chatProvider}) {
    if (AndroidForegroundMonitorService.isRunning) {
      return false;
    }
    if (!chatProvider.isForegroundResumeSyncing) {
      return false;
    }
    return _isRecoverableSyncState(chatProvider: chatProvider);
  }

  bool _shouldShowMenuSyncLoading({required ChatProvider chatProvider}) {
    return _isRecoverableSyncLoading(chatProvider: chatProvider);
  }

  ServerHealthStatus _activeServerHealth(AppProvider appProvider) {
    final active = appProvider.activeServer;
    if (active == null) {
      return ServerHealthStatus.unknown;
    }
    return appProvider.healthFor(active.id);
  }

  Color _serverStatusColor({
    required BuildContext context,
    required AppProvider appProvider,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final health = _activeServerHealth(appProvider);
    if (health == ServerHealthStatus.unhealthy) {
      return colorScheme.error;
    }
    if (_hasDelayedServerStatus(appProvider: appProvider)) {
      return Colors.orange;
    }
    return Colors.green;
  }

  Color _sessionAttentionBadgeColor({
    required BuildContext context,
    required SessionAttentionKind kind,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return switch (kind) {
      SessionAttentionKind.error => colorScheme.error,
      SessionAttentionKind.pendingInteraction => colorScheme.tertiary,
      SessionAttentionKind.unreadCompletion => colorScheme.primary,
      SessionAttentionKind.active => colorScheme.primary,
      SessionAttentionKind.none => colorScheme.outline,
    };
  }

  // Keep the drawer notice and hamburger icon on the same reason resolver so
  // the explanation never drifts from the visible badge state.
  _HamburgerBadgeReasonState _resolveHamburgerBadgeReason({
    required ChatProvider chatProvider,
    required AppProvider appProvider,
    required SettingsProvider settingsProvider,
  }) {
    if (_hasServerStatusAlert(
      chatProvider: chatProvider,
      appProvider: appProvider,
    )) {
      return const _HamburgerBadgeReasonState(
        kind: _HamburgerBadgeReasonKind.serverAlert,
      );
    }

    final attentionReason = _resolveOutOfFocusAttentionHamburgerReason(
      chatProvider: chatProvider,
    );
    if (attentionReason.hasBadge) {
      return attentionReason;
    }

    if (_shouldShowMenuSyncLoading(chatProvider: chatProvider)) {
      return const _HamburgerBadgeReasonState(
        kind: _HamburgerBadgeReasonKind.syncLoading,
      );
    }

    if (settingsProvider.isCellularDataSaverActive) {
      return const _HamburgerBadgeReasonState(
        kind: _HamburgerBadgeReasonKind.dataSaver,
      );
    }

    return const _HamburgerBadgeReasonState.none();
  }

  _HamburgerBadgeReasonState _resolveOutOfFocusAttentionHamburgerReason({
    required ChatProvider chatProvider,
  }) {
    final currentSessionId = chatProvider.currentSession?.id;
    final aggregatedKind = chatProvider.outOfFocusAttentionKind;
    if (aggregatedKind == SessionAttentionKind.none) {
      return const _HamburgerBadgeReasonState.none();
    }

    for (final session in chatProvider.visibleSessions) {
      if (session.id == currentSessionId) {
        continue;
      }
      final attention = chatProvider.sessionAttentionFor(session.id);
      if (attention.primaryKind != aggregatedKind) {
        continue;
      }
      return _HamburgerBadgeReasonState(
        kind: _hamburgerReasonKindForSessionAttention(aggregatedKind),
        sessionId: session.id,
        sessionTitle: _sessionDisplayTitle(session),
      );
    }

    return const _HamburgerBadgeReasonState.none();
  }

  _HamburgerBadgeReasonKind _hamburgerReasonKindForSessionAttention(
    SessionAttentionKind kind,
  ) {
    return switch (kind) {
      SessionAttentionKind.error => _HamburgerBadgeReasonKind.sessionError,
      SessionAttentionKind.pendingInteraction =>
        _HamburgerBadgeReasonKind.sessionPendingInteraction,
      SessionAttentionKind.unreadCompletion =>
        _HamburgerBadgeReasonKind.sessionUnreadCompletion,
      SessionAttentionKind.active ||
      SessionAttentionKind.none => _HamburgerBadgeReasonKind.none,
    };
  }

  SessionAttentionKind _sessionAttentionKindForHamburgerReason(
    _HamburgerBadgeReasonKind kind,
  ) {
    return switch (kind) {
      _HamburgerBadgeReasonKind.sessionError => SessionAttentionKind.error,
      _HamburgerBadgeReasonKind.sessionPendingInteraction =>
        SessionAttentionKind.pendingInteraction,
      _HamburgerBadgeReasonKind.sessionUnreadCompletion =>
        SessionAttentionKind.unreadCompletion,
      _HamburgerBadgeReasonKind.none ||
      _HamburgerBadgeReasonKind.serverAlert ||
      _HamburgerBadgeReasonKind.syncLoading ||
      _HamburgerBadgeReasonKind.dataSaver => SessionAttentionKind.none,
    };
  }

  bool _hasImmediateServerStatusAlert({
    required ChatProvider chatProvider,
    required AppProvider appProvider,
  }) {
    final health = _activeServerHealth(appProvider);
    if (health == ServerHealthStatus.unhealthy) {
      return true;
    }
    // Keep the urgent red badge aligned with server-health semantics shown in
    // Settings. Connectivity blips can still surface through sync/loading UI,
    // but they should not masquerade as an unhealthy server.
    if (_isRecoverableSyncState(chatProvider: chatProvider)) {
      return chatProvider.isRecoverableSyncAlertEscalated;
    }
    return false;
  }

  void _resetServerAlertGraceState() {
    _serverAlertIssueStartedAt = null;
    _serverAlertRevealTimer?.cancel();
    _serverAlertRevealTimer = null;
  }

  bool _hasServerStatusAlert({
    required ChatProvider chatProvider,
    required AppProvider appProvider,
  }) {
    final immediateAlert = _hasImmediateServerStatusAlert(
      chatProvider: chatProvider,
      appProvider: appProvider,
    );
    if (!immediateAlert) {
      _resetServerAlertGraceState();
      return false;
    }

    final now = DateTime.now();
    _serverAlertIssueStartedAt ??= now;

    final startedAt = _serverAlertIssueStartedAt ?? now;
    final elapsed = now.difference(startedAt);
    if (elapsed >= _ChatPageState._serverAlertGracePeriod) {
      _serverAlertRevealTimer?.cancel();
      _serverAlertRevealTimer = null;
      return true;
    }

    final remaining = _ChatPageState._serverAlertGracePeriod - elapsed;
    if (!(_serverAlertRevealTimer?.isActive ?? false)) {
      _serverAlertRevealTimer = Timer(remaining, () {
        _serverAlertRevealTimer = null;
        if (!mounted) {
          return;
        }
        _setState(() {});
      });
    }
    return false;
  }

  /// Draggable resize handle that replaces VerticalDivider between panes.
  /// [paneOnLeft] means the pane being resized is to the left of the handle;
  /// when false (utility pane on the right), the drag delta is inverted.
  Widget _buildResizableHandle({
    required DesktopPane pane,
    required SettingsProvider settingsProvider,
    required bool paneOnLeft,
  }) {
    return _PaneResizeHandle(
      pane: pane,
      settingsProvider: settingsProvider,
      paneOnLeft: paneOnLeft,
    );
  }

  Widget _buildSelectorSectionHeader(BuildContext context, String title) {
    final density = _settingsProvider?.appDensity ?? AppDensity.normal;
    return Padding(
      padding: AppDensitySpacing.sectionHeaderPadding(density),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildOpenProjectTile({
    required BuildContext dialogContext,
    required Project project,
    required bool selected,
    required VoidCallback? onSwitch,
    required VoidCallback? onClose,
    required bool closeEnabled,
  }) {
    final path = _directoryLabel(project.path);
    final displayName = _projectDisplayLabel(project);

    return ListTile(
      dense: _useDenseListTiles(dialogContext),
      contentPadding: AppDensitySpacing.listTileContentPadding(
        _settingsProvider?.appDensity ?? AppDensity.normal,
      ),
      leading: ProjectIcon(project: project, size: 20, autoDiscover: true),
      title: Text(displayName, overflow: TextOverflow.ellipsis),
      subtitle: path == displayName
          ? null
          : Text(path, overflow: TextOverflow.ellipsis),
      selected: selected,
      onTap: onSwitch,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selected)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Symbols.radio_button_checked, size: 18),
            ),
          IconButton(
            icon: const Icon(Symbols.close_rounded),
            tooltip: 'Close ${_projectDisplayLabel(project)}',
            onPressed: closeEnabled ? onClose : null,
          ),
        ],
      ),
    );
  }

  Future<void> _runProjectSelectorDialogAction(
    Future<void> Function() action,
  ) async {
    if (!mounted || _isProjectSelectorActionInFlight) {
      return;
    }
    _setState(() {
      _isProjectSelectorActionInFlight = true;
    });
    try {
      await action();
    } finally {
      if (!mounted) {
        return;
      }
      _setState(() {
        _isProjectSelectorActionInFlight = false;
      });
    }
  }

  Future<void> _openCreateWorkspaceFromSelector(
    BuildContext dialogContext,
  ) async {
    await _runProjectSelectorDialogAction(() async {
      if (dialogContext.mounted) {
        Navigator.of(dialogContext).pop();
      }
      await Future<void>.delayed(Duration.zero);
      if (!mounted) {
        return;
      }
      await _createWorkspace();
    });
  }

  Future<void> _switchProjectFromSelector(
    BuildContext dialogContext,
    String projectId,
  ) async {
    await _runProjectSelectorDialogAction(() async {
      if (dialogContext.mounted) {
        Navigator.of(dialogContext).pop();
      }
      await Future<void>.delayed(Duration.zero);
      if (!mounted) {
        return;
      }
      await _switchProjectContext(projectId);
    });
  }

  Future<void> _reopenProjectFromSelector(
    BuildContext dialogContext,
    String projectId,
  ) async {
    await _runProjectSelectorDialogAction(() async {
      if (dialogContext.mounted) {
        Navigator.of(dialogContext).pop();
      }
      await Future<void>.delayed(Duration.zero);
      if (!mounted) {
        return;
      }
      await _reopenProjectContext(projectId);
    });
  }

  Future<void> _closeProjectFromSelector(String projectId) async {
    await _runProjectSelectorDialogAction(() async {
      await _closeProjectContext(projectId);
    });
  }

  Future<void> _archiveClosedProjectFromSelector(String projectId) async {
    await _runProjectSelectorDialogAction(() async {
      await _archiveClosedProjectContext(projectId);
    });
  }

  String _directoryLabel(String? directory) {
    final trimmed = directory?.trim();
    if (trimmed == null ||
        trimmed.isEmpty ||
        trimmed == '/' ||
        trimmed == '-') {
      return context.l10n.composerCannedScopeGlobal;
    }
    return trimmed;
  }

  String _directoryBasename(String directoryLabel) {
    if (directoryLabel == context.l10n.composerCannedScopeGlobal) {
      return directoryLabel;
    }
    final normalized = directoryLabel.replaceAll('\\', '/');
    final parts = normalized
        .split('/')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) {
      return directoryLabel;
    }
    return parts.last;
  }

  String _projectDisplayLabel(Project project) {
    final name = project.name.trim();
    final path = _directoryLabel(project.path);
    if (name.isEmpty || name == '/' || name == path) {
      return path;
    }
    return name;
  }

  // Close the drawer without yielding to the microtask queue. A
  // `Future.delayed(Duration.zero)` yield here would allow pending gesture
  // callbacks (e.g. DrawerController._handleDragCancel after a rapid double
  // tap) to re-open the drawer before the close animation settles.
  void _closeDrawerIfNeeded({required bool closeOnSelect}) {
    if (!closeOnSelect) {
      return;
    }
    final scaffoldState = _scaffoldKey.currentState;
    if (scaffoldState == null || !scaffoldState.isDrawerOpen) {
      return;
    }
    scaffoldState.closeDrawer();
  }

  Future<void> _openSettingsPage({
    required bool closeOnSelect,
    String initialSectionId = '',
  }) async {
    _closeDrawerIfNeeded(closeOnSelect: closeOnSelect);
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      AppPageRoute(
        builder: (_) => SettingsPage(initialSectionId: initialSectionId),
      ),
    );
  }

  Widget _headerChip(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    final density = _settingsProvider?.appDensity ?? AppDensity.normal;
    return Container(
      padding: AppDensitySpacing.headerChipPadding(density),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          SizedBox(width: AppDensitySpacing.smallGap(density) + 2),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

/// Interactive resize handle for desktop sidebar panes.
/// Provides an 8px hit area with a thin visual line that thickens on
/// hover/drag. Double-tap resets to the default width.
class _PaneResizeHandle extends StatefulWidget {
  const _PaneResizeHandle({
    required this.pane,
    required this.settingsProvider,
    required this.paneOnLeft,
  });

  final DesktopPane pane;
  final SettingsProvider settingsProvider;
  final bool paneOnLeft;

  @override
  State<_PaneResizeHandle> createState() => _PaneResizeHandleState();
}

class _PaneResizeHandleState extends State<_PaneResizeHandle> {
  bool _hovering = false;
  bool _dragging = false;
  bool _dirty = false;

  void _persistIfDirty() {
    if (!_dirty) {
      return;
    }
    _dirty = false;
    unawaited(widget.settingsProvider.persistDesktopPaneWidths());
  }

  @override
  Widget build(BuildContext context) {
    final active = _hovering || _dragging;
    final lineWidth = active ? 3.0 : 1.0;
    final color = active
        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)
        : Theme.of(context).colorScheme.outline.withValues(alpha: 0.12);

    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) => setState(() => _dragging = true),
        onHorizontalDragUpdate: (details) {
          final delta = widget.paneOnLeft
              ? details.delta.dx
              : -details.delta.dx;
          final current = widget.settingsProvider.desktopPaneWidth(widget.pane);
          final next = (current + delta).clamp(160.0, 500.0);
          // Update in memory only; persist once on drag end/cancel to avoid
          // excessive SharedPreferences writes during continuous drag.
          widget.settingsProvider.updateDesktopPaneWidthInMemory(
            widget.pane,
            next,
          );
          _dirty = true;
        },
        onHorizontalDragEnd: (_) {
          setState(() => _dragging = false);
          _persistIfDirty();
        },
        onHorizontalDragCancel: () {
          setState(() => _dragging = false);
          _persistIfDirty();
        },
        onDoubleTap: () {
          unawaited(widget.settingsProvider.resetDesktopPaneWidth(widget.pane));
        },
        child: SizedBox(
          width: 8,
          child: Center(
            child: Container(width: lineWidth, color: color),
          ),
        ),
      ),
    );
  }
}
