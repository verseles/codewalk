part of '../chat_page.dart';

extension _ChatPageTimelineViewport on _ChatPageState {
  Widget _buildMessageViewport(ChatProvider chatProvider) {
    final showFab =
        _showScrollToLatestFab &&
        chatProvider.currentSession != null &&
        chatProvider.messages.isNotEmpty;
    final showJumpToFirstFab = showFab && _showScrollToFirstFab;
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Positioned.fill(child: _buildMessageList(chatProvider)),
        Positioned(
          right: 16,
          bottom: 16,
          child: AnimatedSwitcher(
            duration: AppAnimations.fabScale,
            switchInCurve: AppAnimations.fabCurve,
            switchOutCurve: AppAnimations.accelerateCurve,
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: animation,
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: showFab
                ? Column(
                    key: const ValueKey<String>('message_jump_fabs_visible'),
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      AnimatedSwitcher(
                        duration: AppAnimations.fabScale,
                        switchInCurve: AppAnimations.fabCurve,
                        switchOutCurve: AppAnimations.accelerateCurve,
                        transitionBuilder: (child, animation) =>
                            ScaleTransition(
                              scale: animation,
                              child: FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                            ),
                        child: showJumpToFirstFab
                            ? Padding(
                                key: const ValueKey<String>(
                                  'jump_to_first_fab',
                                ),
                                padding: const EdgeInsets.only(bottom: 8),
                                child: FloatingActionButton.small(
                                  heroTag: 'jump_to_first_fab',
                                  tooltip: context.l10n.chatGoToFirst,
                                  onPressed: _scrollToFirstMessage,
                                  backgroundColor:
                                      colorScheme.surfaceContainerHigh,
                                  foregroundColor: colorScheme.onSurfaceVariant,
                                  child: const Icon(
                                    Symbols.arrow_upward_rounded,
                                  ),
                                ),
                              )
                            : const SizedBox(
                                key: ValueKey<String>(
                                  'jump_to_first_fab_hidden',
                                ),
                              ),
                      ),
                      FloatingActionButton.small(
                        key: const ValueKey<String>('jump_to_latest_fab'),
                        heroTag: 'jump_to_latest_fab',
                        tooltip: context.l10n.chatGoToLatest,
                        onPressed: _jumpToLatestAndResumeAutoFollow,
                        backgroundColor: _hasUnreadMessagesBelow
                            ? colorScheme.primary
                            : colorScheme.surfaceContainerHigh,
                        foregroundColor: _hasUnreadMessagesBelow
                            ? colorScheme.onPrimary
                            : colorScheme.onSurfaceVariant,
                        child: Icon(
                          _hasUnreadMessagesBelow
                              ? Symbols.mark_chat_unread
                              : Symbols.arrow_downward_rounded,
                        ),
                      ),
                    ],
                  )
                : const SizedBox(
                    key: ValueKey<String>('jump_to_latest_fab_hidden'),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessageList(ChatProvider chatProvider) {
    final settingsProvider = context.watch<SettingsProvider>();
    final appProvider = context.watch<AppProvider>();
    if (chatProvider.state == ChatState.loading &&
        chatProvider.messages.isEmpty &&
        chatProvider.currentSession == null) {
      return const ChatSkeletonShimmer();
    }

    if (chatProvider.state == ChatState.error &&
        chatProvider.currentSession == null &&
        chatProvider.messages.isEmpty) {
      final rawErrorMessage =
          chatProvider.errorMessage ?? context.l10n.errorAnErrorOccurred;
      if (!_shouldInlineOfflineComposerBlock(
        chatProvider: chatProvider,
        appProvider: appProvider,
        rawErrorMessage: rawErrorMessage,
      )) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Symbols.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                normalizeAbortMessageForDisplay(rawErrorMessage),
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  chatProvider.clearError();
                  chatProvider.refresh();
                },
                child: Text(context.l10n.chatRetry),
              ),
            ],
          ),
        );
      }
    }

    if (chatProvider.state == ChatState.error &&
        chatProvider.messages.isEmpty &&
        chatProvider.currentSession != null) {
      final rawErrorMessage =
          chatProvider.errorMessage ?? context.l10n.errorAnErrorOccurred;
      if (!_shouldInlineOfflineComposerBlock(
        chatProvider: chatProvider,
        appProvider: appProvider,
        rawErrorMessage: rawErrorMessage,
      )) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Symbols.sync_problem,
                      size: 36,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.l10n.chatRefreshConversation,
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      normalizeAbortMessageForDisplay(rawErrorMessage),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        OutlinedButton(
                          onPressed: chatProvider.clearError,
                          child: Text(context.l10n.chatKeepWorking),
                        ),
                        FilledButton(
                          onPressed: () {
                            chatProvider.clearError();
                            chatProvider.refresh();
                          },
                          child: Text(context.l10n.chatRetryRefresh),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    }

    // Without a server there is nothing to draft into, so the setup call to
    // action outranks the automatic draft introduced for empty projects
    // (#134). With a server configured, an active draft owns the view and this
    // whole empty-state block is skipped.
    final hasConfiguredServerForEmptyState =
        context.watch<AppProvider>().activeServer != null;
    if (chatProvider.currentSession == null &&
        (!chatProvider.isDraftingNewChat ||
            !hasConfiguredServerForEmptyState)) {
      final appProvider = context.watch<AppProvider>();
      final hasConfiguredServer = appProvider.activeServer != null;
      if (!hasConfiguredServer) {
        return MessageEntranceAnimation(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Symbols.dns_rounded,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.l10n.chatNoServerYet,
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.chatAddServerToStart,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    key: const ValueKey<String>('no_server_setup_button'),
                    onPressed: () {
                      unawaited(
                        Navigator.of(context).push(
                          AppPageRoute(
                            builder: (_) => OnboardingWizardPage(
                              showSkipAction: false,
                              initialFlow: SetupWizardInitialFlow.connectServer,
                              onComplete: () {
                                Navigator.of(context).pop();
                              },
                            ),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Symbols.add),
                    label: Text(context.l10n.chatSetUpServer),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      return MessageEntranceAnimation(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Symbols.chat_bubble_outline,
                size: 64,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.chatSelectOrCreate,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _createNewSession,
                icon: const Icon(Symbols.add),
                label: Text(context.l10n.chatNewChat),
              ),
            ],
          ),
        ),
      );
    }

    if (chatProvider.messages.isEmpty &&
        chatProvider.isCurrentSessionHydrating) {
      return const Center(
        child: SizedBox.square(
          key: ValueKey<String>('session_hydration_loading_indicator'),
          dimension: 28,
          child: CircularProgressIndicator.adaptive(strokeWidth: 2.5),
        ),
      );
    }

    if (chatProvider.messages.isEmpty) {
      return MessageEntranceAnimation(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Symbols.waving_hand,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.chatHelloAssistant,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.chatWelcomeSubmessage,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final progressStage = _resolveAssistantProgressStage(chatProvider);
    final latestReasoningPartKey = _resolveLatestReasoningPartKey(chatProvider);
    final showMessageProgressIndicator =
        progressStage == _AssistantProgressStage.retrying;
    final interactionPermissions = chatProvider.currentThreadPermissionRequests;
    final currentSessionId = chatProvider.currentSession?.id;
    final timelineEntries = _buildMessageTimelineEntries(
      sessionId: currentSessionId,
      messages: chatProvider.messages,
      messagesVersion: chatProvider.messagesVersion,
      showRetryIndicator: showMessageProgressIndicator,
      isSessionActivelyResponding:
          chatProvider.isCurrentSessionActivelyResponding,
      isCompactingContext: chatProvider.isCompactingContext,
      interactionPermissions: interactionPermissions,
    );
    final finalAssistantRevealMessageId =
        _resolveLatestRevealableAssistantMessageId(chatProvider.messages);
    final latestRevertibleMessageId = chatProvider.latestRevertibleMessageId;
    _pruneMessageRevealAnchorKeys(chatProvider.messages);
    _pruneTimelineSearchMessageKeys(chatProvider.messages);

    return Listener(
      onPointerSignal: _handlePointerSignal,
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: _handleScrollMetricsChanged,
        child: CustomScrollView(
          key: const ValueKey<String>('chat_message_list'),
          controller: _scrollController,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 8),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final entry = timelineEntries[index];
                    Widget child;
                    if (entry is _TimelineMessageEntry) {
                      final message = entry.message;
                      final messageWidget = _buildTimelineMessageWidget(
                        message: message,
                        chatProvider: chatProvider,
                        settingsProvider: settingsProvider,
                        latestReasoningPartKey: latestReasoningPartKey,
                        latestRevertibleMessageId: latestRevertibleMessageId,
                        finalAssistantRevealMessageId:
                            finalAssistantRevealMessageId,
                      );
                      child = KeyedSubtree(
                        key: ValueKey<String>(entry.key),
                        child: SizedBox(
                          key: _timelineSearchMessageKey(message.id),
                          child: messageWidget,
                        ),
                      );
                    } else if (entry is _TimelineCollapsedHistoryEntry) {
                      child = _buildCollapsedHistoryEntry(entry);
                    } else if (entry is _TimelineCollapsedAssistantWorkEntry) {
                      child = _buildCollapsedAssistantWorkEntry(
                        entry,
                        buildPreviewMessage: (message) =>
                            _buildTimelineMessageWidget(
                              message: message,
                              chatProvider: chatProvider,
                              settingsProvider: settingsProvider,
                              latestReasoningPartKey: latestReasoningPartKey,
                              latestRevertibleMessageId:
                                  latestRevertibleMessageId,
                              finalAssistantRevealMessageId:
                                  finalAssistantRevealMessageId,
                              wrapRevealAnchor: false,
                              keyPrefix: 'assistant_work_preview',
                            ),
                      );
                    } else if (entry is _TimelinePendingAssistantEntry) {
                      child = _buildPendingAssistantEntry(entry);
                    } else if (entry is _TimelinePermissionPromptEntry) {
                      child = _buildInlinePermissionPromptEntry(
                        entry,
                        chatProvider,
                      );
                    } else {
                      child = _buildRetryingMessageIndicator();
                    }

                    return child;
                  },
                  childCount: timelineEntries.length,
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries: true,
                  addSemanticIndexes: false,
                  findChildIndexCallback: (key) =>
                      _findTimelineEntryIndexByKey(key, timelineEntries),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _resolveComposerBlockReason({
    required BuildContext context,
    required ChatProvider chatProvider,
    required AppProvider appProvider,
  }) {
    if (appProvider.activeServer == null ||
        _shouldDeferForegroundWarningUi(
          chatProvider: chatProvider,
          appProvider: appProvider,
        )) {
      return null;
    }

    if (_hasConfirmedOfflineComposerBlock(
      chatProvider: chatProvider,
      appProvider: appProvider,
    )) {
      return context.l10n.chatWaitingForNetworkConnection;
    }

    if (_hasConfirmedUnhealthyServerBlock(
      chatProvider: chatProvider,
      appProvider: appProvider,
    )) {
      return context.l10n.chatActiveServerUnhealthyLabel;
    }

    return null;
  }

  bool _shouldInlineOfflineComposerBlock({
    required ChatProvider chatProvider,
    required AppProvider appProvider,
    required String? rawErrorMessage,
  }) {
    if (_hasConfirmedUnhealthyServerBlock(
      chatProvider: chatProvider,
      appProvider: appProvider,
    )) {
      return true;
    }

    return _hasConfirmedOfflineComposerBlock(
          chatProvider: chatProvider,
          appProvider: appProvider,
        ) &&
        isServerConnectionFailure(rawMessage: rawErrorMessage);
  }

  bool _hasConfirmedOfflineComposerBlock({
    required ChatProvider chatProvider,
    required AppProvider appProvider,
  }) {
    return chatProvider.state == ChatState.error &&
        !appProvider.isConnected &&
        isServerConnectionFailure(rawMessage: chatProvider.errorMessage);
  }

  bool _hasConfirmedUnhealthyServerBlock({
    required ChatProvider chatProvider,
    required AppProvider appProvider,
  }) {
    return chatProvider.state == ChatState.error &&
        appProvider.isConnected &&
        chatProvider.messages.isEmpty &&
        !isServerConnectionFailure(rawMessage: chatProvider.errorMessage) &&
        _activeServerHealth(appProvider) == ServerHealthStatus.unhealthy;
  }
}
