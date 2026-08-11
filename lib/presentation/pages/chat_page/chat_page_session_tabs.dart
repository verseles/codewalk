part of '../chat_page.dart';

extension _ChatPageSessionTabs on _ChatPageState {
  Widget _buildIntegratedWindowTitleBar(BuildContext context) {
    return _buildSessionTabStrip(
      isCompact: false,
      settingsProvider: context.read<SettingsProvider>(),
      fillWidth: false,
      transparentBackground: true,
      menuNavigatorContext: this.context,
    );
  }

  /// True when the tab strip lives in the window title bar instead of the body.
  bool _usesIntegratedWindowChrome(SettingsProvider settingsProvider) {
    return _isDesktopRuntime &&
        settingsProvider.desktopWindowChrome ==
            DesktopWindowChrome.integratedTabs;
  }

  Widget _buildSessionTabStrip({
    required bool isCompact,
    required SettingsProvider settingsProvider,
    bool fillWidth = true,
    bool transparentBackground = false,
    BuildContext? menuNavigatorContext,
  }) {
    if (!settingsProvider.showSessionTabs) {
      return const SizedBox.shrink();
    }
    return Consumer2<ChatProvider, ProjectProvider>(
      builder: (context, chatProvider, projectProvider, _) {
        final tabs = chatProvider.sessionTabs;
        if (tabs.isEmpty) {
          return const SizedBox.shrink();
        }
        return SessionTabStrip(
          tabs: tabs,
          projects: projectProvider.projects,
          openProjectIds: projectProvider.openProjectIds.toSet(),
          isCompact: isCompact,
          fillWidth: fillWidth,
          transparentBackground: transparentBackground,
          onActivate: (tab) => unawaited(_activateSessionTab(tab)),
          onClose: (tab) => unawaited(_closeSessionTab(tab)),
          onContextMenu: _openSessionTabContextMenu,
          trailingBuilder: (context, tab) {
            if (!tab.isSelected) return null;
            return _buildSessionContextUsageButton(
              context,
              chatProvider,
              targetSize: isCompact ? 40 : 32,
              menuNavigatorContext: menuNavigatorContext,
            );
          },
        );
      },
    );
  }

  Future<void> _openSessionTabContextMenu(
    SessionTabRecord tab,
    Offset globalPosition, {
    required bool haptic,
  }) async {
    if (!tab.isSelected && !await _activateSessionTab(tab)) {
      return;
    }
    if (!mounted || !_isChatScreenActive()) return;
    await _showCurrentSessionActionsMenu(
      globalPosition: globalPosition,
      haptic: haptic,
      tabIdentity: tab.identity,
    );
  }

  void _syncSessionTabsGestureHint(ChatProvider chatProvider) {
    final currentIdentities = chatProvider.sessionTabs
        .map((tab) => tab.identity)
        .toSet();
    final settingsProvider = _settingsProvider;
    if (settingsProvider == null || !settingsProvider.initialized) return;
    if (!settingsProvider.showSessionTabs ||
        settingsProvider.sessionTabsGestureHintDismissed) {
      _knownSessionTabIdentities = currentIdentities;
      _pendingSessionTabHintIdentities.clear();
      return;
    }

    final added = currentIdentities.difference(_knownSessionTabIdentities);
    _knownSessionTabIdentities = currentIdentities;
    _pendingSessionTabHintIdentities.addAll(added);
    if (_sessionTabHintShowing || _pendingSessionTabHintIdentities.isEmpty) {
      return;
    }
    _scheduleSessionTabsGestureHint();
  }

  void _scheduleSessionTabsGestureHint() {
    if (_sessionTabHintScheduled || _sessionTabHintShowing) return;
    _sessionTabHintScheduled = true;
    final generation = _sessionTabHintGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sessionTabHintScheduled = false;
      if (!mounted || generation != _sessionTabHintGeneration) return;
      final settingsProvider = _settingsProvider;
      if (settingsProvider == null ||
          !settingsProvider.initialized ||
          !settingsProvider.showSessionTabs ||
          settingsProvider.sessionTabsGestureHintDismissed ||
          _pendingSessionTabHintIdentities.isEmpty ||
          !_isChatScreenActive()) {
        return;
      }
      unawaited(_showSessionTabsGestureHint(settingsProvider));
    });
  }

  Future<void> _showSessionTabsGestureHint(
    SettingsProvider settingsProvider,
  ) async {
    if (_sessionTabHintShowing || !mounted) return;
    _sessionTabHintShowing = true;
    _pendingSessionTabHintIdentities.clear();
    var dontShowAgain = false;
    var disableTabs = false;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            return ModalPrimaryActionShortcuts(
              onPrimaryAction: () => Navigator.of(dialogContext).pop(),
              child: AlertDialog(
                key: const ValueKey<String>('session_tabs_gesture_hint_dialog'),
                title: Text(context.l10n.sessionTabsGestureHintTitle),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.sessionTabsGestureHintBody),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      key: const ValueKey<String>(
                        'session_tabs_gesture_hint_dont_show',
                      ),
                      value: dontShowAgain,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(context.l10n.onboardingDonShowAgain),
                      onChanged: (value) =>
                          setDialogState(() => dontShowAgain = value ?? false),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    key: const ValueKey<String>(
                      'session_tabs_gesture_hint_disable_tabs',
                    ),
                    onPressed: () {
                      disableTabs = true;
                      Navigator.of(dialogContext).pop();
                    },
                    child: Text(context.l10n.sessionTabsGestureHintDisableTabs),
                  ),
                  FilledButton(
                    key: const ValueKey<String>(
                      'session_tabs_gesture_hint_acknowledge',
                    ),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text(context.l10n.sessionTabsGestureHintAcknowledge),
                  ),
                ],
              ),
            );
          },
        ),
      );
      if (dontShowAgain && mounted) {
        await settingsProvider.setSessionTabsGestureHintDismissed(true);
      }
      if (disableTabs && mounted) {
        await settingsProvider.setShowSessionTabsOverride(false);
      }
    } finally {
      _sessionTabHintShowing = false;
      _pendingSessionTabHintIdentities.clear();
    }
  }

  Future<bool> _activateSessionTab(SessionTabRecord tab) async {
    if (!_isChatScreenActive()) {
      return false;
    }
    final inFlight = _sessionTabActivationTask;
    if (inFlight != null) {
      if (_activatingSessionTabIdentity == tab.identity) {
        return inFlight;
      }
      await inFlight;
      if (!mounted || !_isChatScreenActive()) {
        return false;
      }
    }

    final task = _performSessionTabActivation(tab);
    _activatingSessionTabIdentity = tab.identity;
    _sessionTabActivationTask = task;
    try {
      return await task;
    } finally {
      if (identical(_sessionTabActivationTask, task)) {
        _sessionTabActivationTask = null;
        _activatingSessionTabIdentity = null;
      }
    }
  }

  Future<bool> _performSessionTabActivation(SessionTabRecord tab) async {
    final projectProvider = context.read<ProjectProvider>();
    final chatProvider = context.read<ChatProvider>();
    final priorProject = projectProvider.currentProject;
    final priorSession = chatProvider.currentSession;
    final priorWasNewChatDraft = priorSession == null;

    try {
      if (tab.identity.serverId != chatProvider.activeServerId) {
        _showSessionTabNavigationError();
        return false;
      }

      await _switchToSessionTabContext(tab);
      if (!mounted || !_isChatScreenActive()) {
        await _restoreSessionTabNavigation(
          project: priorProject,
          session: priorSession,
          wasNewChatDraft: priorWasNewChatDraft,
        );
        return false;
      }
      if (!_isSessionTabContextActive(tab)) {
        await _restoreSessionTabNavigation(
          project: priorProject,
          session: priorSession,
          wasNewChatDraft: priorWasNewChatDraft,
        );
        _showSessionTabNavigationError();
        return false;
      }

      final target = await _waitForSessionTabTarget(tab);
      if (target == null) {
        if (!mounted || !_isChatScreenActive()) {
          await _restoreSessionTabNavigation(
            project: priorProject,
            session: priorSession,
            wasNewChatDraft: priorWasNewChatDraft,
          );
          return false;
        }
        await _restoreSessionTabNavigation(
          project: priorProject,
          session: priorSession,
          wasNewChatDraft: priorWasNewChatDraft,
        );
        _showSessionTabNavigationError();
        return false;
      }

      if (!_isChatScreenActive()) {
        await _restoreSessionTabNavigation(
          project: priorProject,
          session: priorSession,
          wasNewChatDraft: priorWasNewChatDraft,
        );
        return false;
      }
      await _handleSessionSwitch(target);
      final activated =
          mounted &&
          _isChatScreenActive() &&
          _isSessionTabContextActive(tab) &&
          context.read<ChatProvider>().currentSession?.id ==
              tab.identity.sessionId;
      if (activated) {
        return true;
      }

      await _restoreSessionTabNavigation(
        project: priorProject,
        session: priorSession,
        wasNewChatDraft: priorWasNewChatDraft,
      );
      _showSessionTabNavigationError();
      return false;
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Failed to activate session tab',
        error: error,
        stackTrace: stackTrace,
      );
      await _restoreSessionTabNavigation(
        project: priorProject,
        session: priorSession,
        wasNewChatDraft: priorWasNewChatDraft,
      );
      _showSessionTabNavigationError();
      return false;
    }
  }

  Future<void> _switchToSessionTabContext(SessionTabRecord tab) async {
    if (_isSessionTabContextActive(tab)) {
      return;
    }
    final projectProvider = context.read<ProjectProvider>();
    final project = _projectForSessionTab(projectProvider, tab);
    if (project == null) {
      await _switchDirectoryContext(tab.identity.directory);
      return;
    }
    if (projectProvider.openProjectIds.contains(project.id)) {
      await _switchProjectContext(project.id);
      return;
    }
    await _reopenProjectContext(project.id);
  }

  Project? _projectForSessionTab(
    ProjectProvider projectProvider,
    SessionTabRecord tab,
  ) {
    for (final project in projectProvider.projects) {
      if (areEquivalentFilePaths(project.path, tab.identity.directory)) {
        return project;
      }
    }
    final projectId = tab.projectId?.trim();
    if (projectId == null || projectId.isEmpty) {
      return null;
    }
    return projectProvider.projects
        .where((project) => project.id == projectId)
        .firstOrNull;
  }

  bool _isSessionTabContextActive(SessionTabRecord tab) {
    final projectProvider = context.read<ProjectProvider>();
    final currentPath = projectProvider.currentProject?.path;
    return currentPath != null &&
        areEquivalentFilePaths(currentPath, tab.identity.directory);
  }

  Future<ChatSession?> _waitForSessionTabTarget(SessionTabRecord tab) async {
    final chatProvider = context.read<ChatProvider>();
    final deadline = DateTime.now().add(const Duration(seconds: 8));
    while (true) {
      if (!_isChatScreenActive() ||
          chatProvider.activeServerId != tab.identity.serverId ||
          !_isSessionTabContextActive(tab)) {
        return null;
      }
      final target = chatProvider.sessions.where((session) {
        if (session.id != tab.identity.sessionId) {
          return false;
        }
        final directory = normalizeOptionalFilePath(
          session.directory ?? session.path?.workspace ?? session.path?.root,
        );
        return directory == null || directory == tab.identity.directory;
      }).firstOrNull;
      if (target != null) {
        return target;
      }
      if (chatProvider.hasLoadedSessionsAuthoritatively) {
        return null;
      }
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        return null;
      }
      const pollInterval = Duration(milliseconds: 80);
      await Future<void>.delayed(
        remaining.compareTo(pollInterval) < 0 ? remaining : pollInterval,
      );
      if (!mounted) {
        return null;
      }
    }
  }

  Future<void> _restoreSessionTabNavigation({
    required Project? project,
    required ChatSession? session,
    required bool wasNewChatDraft,
  }) async {
    if (!mounted) {
      return;
    }
    try {
      final projectProvider = context.read<ProjectProvider>();
      if (project != null && projectProvider.currentProject?.id != project.id) {
        if (projectProvider.openProjectIds.contains(project.id)) {
          await _switchProjectContext(project.id);
        } else {
          await _reopenProjectContext(project.id);
        }
      }
      if (!mounted) {
        return;
      }

      final chatProvider = context.read<ChatProvider>();
      if (wasNewChatDraft) {
        await chatProvider.beginNewChatDraft();
        return;
      }
      if (session == null) {
        return;
      }
      final restoredSession = chatProvider.sessions
          .where((candidate) => candidate.id == session.id)
          .firstOrNull;
      await _handleSessionSwitch(restoredSession ?? session);
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Failed to restore session tab navigation',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _showSessionTabNavigationError() {
    if (!mounted) {
      return;
    }
    _showChatPageMessageSnackBar(
      context.l10n.sessionNotAvailable,
      hideCurrent: false,
    );
  }

  Future<void> _closeSessionTab(SessionTabRecord tab) async {
    if (!_isChatScreenActive()) {
      return;
    }
    final chatProvider = context.read<ChatProvider>();
    final tabs = chatProvider.sessionTabs;
    final current = tabs
        .where((candidate) => candidate.identity == tab.identity)
        .firstOrNull;
    if (current == null) {
      return;
    }
    final closedIndex = tabs.indexWhere(
      (candidate) => candidate.identity == current.identity,
    );
    final wasActive =
        current.isSelected ||
        (chatProvider.currentSession?.id == current.identity.sessionId &&
            _isSessionTabContextActive(current));
    final fallback = wasActive
        ? sessionTabCloseFallback(tabs, current.identity)
        : null;

    chatProvider.closeSessionTab(current.identity);
    if (mounted) {
      _showClosedSessionTabSnackBar(current, index: closedIndex);
    }
    if (!wasActive) {
      return;
    }
    if (fallback != null) {
      await _activateSessionTab(fallback);
      return;
    }
    await _createNewSession();
  }

  void _showClosedSessionTabSnackBar(
    SessionTabRecord tab, {
    required int index,
  }) {
    final title = tab.title.trim().isEmpty
        ? context.l10n.sessionExportUntitled
        : tab.title.trim();
    ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
    final controller = _showChatPageSnackBar(
      content: Text(
        context.l10n.sessionTabClosedMessage(title),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      hideCurrent: false,
      duration: const Duration(seconds: 3),
      persist: false,
      action: SnackBarAction(
        label: context.l10n.sessionTabUndo,
        onPressed: () => unawaited(_undoClosedSessionTab(tab, index: index)),
      ),
    );
    if (controller == null) return;
    _sessionTabSnackBarExpirationTimer?.cancel();
    // Flutter only starts its timeout when the owning route is current.
    // Close through the controller as well so three seconds is deterministic.
    final expirationTimer = Timer(const Duration(seconds: 3), controller.close);
    _sessionTabSnackBarExpirationTimer = expirationTimer;
    unawaited(
      controller.closed.whenComplete(() {
        expirationTimer.cancel();
        if (identical(_sessionTabSnackBarExpirationTimer, expirationTimer)) {
          _sessionTabSnackBarExpirationTimer = null;
        }
      }),
    );
  }

  Future<void> _undoClosedSessionTab(
    SessionTabRecord tab, {
    required int index,
  }) async {
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    final restored = context.read<ChatProvider>().restoreClosedSessionTab(
      tab,
      index: index,
    );
    if (!restored) {
      _showChatPageMessageSnackBar(context.l10n.sessionTabRestoreFailed);
    }
  }
}
