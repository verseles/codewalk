part of '../chat_page.dart';

extension _ChatPageStatusPresenter on _ChatPageState {
  Future<void> _compactCurrentSession(ChatProvider chatProvider) async {
    final success = await chatProvider.compactCurrentSession();
    if (!mounted) {
      return;
    }
    _showChatPageMessageSnackBar(
      success
          ? context.l10n.chatPageStatusContextCompacted
          : (chatProvider.errorMessage ??
                context.l10n.chatPageStatusFailedToCompactContext),
    );
  }

  Widget _buildSessionContextUsageButton(
    BuildContext context,
    ChatProvider chatProvider, {
    double? targetSize,
    BuildContext? menuNavigatorContext,
  }) {
    final usage = _resolveSessionContextUsage(chatProvider);
    final canCompact =
        !chatProvider.isCompactingContext &&
        !chatProvider.canAbortActiveResponse;
    final knob = _buildContextUsageControl(
      context,
      usage: usage,
      isCompacting: chatProvider.isCompactingContext,
      enabled: true,
    );

    final child = targetSize == null
        ? knob
        : SizedBox.square(
            dimension: targetSize,
            child: Center(child: knob),
          );
    if (menuNavigatorContext == null) {
      return PopupMenuButton<void>(
        key: const ValueKey<String>('appbar_context_usage_button'),
        tooltip: context.l10n.chatCompactContext,
        padding: EdgeInsets.zero,
        borderRadius: AppShapes.borderFull,
        itemBuilder: (popupContext) => _buildContextUsageMenuItems(
          popupContext,
          usage: usage,
          chatProvider: chatProvider,
          canCompact: canCompact,
        ),
        child: child,
      );
    }

    return Builder(
      builder: (anchorContext) {
        return Tooltip(
          message: context.l10n.chatCompactContext,
          child: InkWell(
            key: const ValueKey<String>('appbar_context_usage_button'),
            customBorder: const CircleBorder(),
            onTap: () => unawaited(
              _showContextUsageMenu(
                anchorContext: anchorContext,
                navigatorContext: menuNavigatorContext,
                usage: usage,
                chatProvider: chatProvider,
                canCompact: canCompact,
              ),
            ),
            child: child,
          ),
        );
      },
    );
  }

  List<PopupMenuEntry<void>> _buildContextUsageMenuItems(
    BuildContext context, {
    required _SessionContextUsageSnapshot usage,
    required ChatProvider chatProvider,
    required bool canCompact,
  }) {
    final serverId = context.read<AppProvider>().activeServer?.id;
    context.read<QuotaProvider>().ensureLoaded(serverId: serverId);
    return [
      PopupMenuItem<void>(
        enabled: false,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: _buildContextUsagePopover(
          context,
          usage: usage,
          isCompacting: chatProvider.isCompactingContext,
          canCompact: canCompact,
          onCompactNow: () => _compactCurrentSession(chatProvider),
        ),
      ),
    ];
  }

  Future<void> _showContextUsageMenu({
    required BuildContext anchorContext,
    required BuildContext navigatorContext,
    required _SessionContextUsageSnapshot usage,
    required ChatProvider chatProvider,
    required bool canCompact,
  }) async {
    if (!mounted || !navigatorContext.mounted || !_isChatScreenActive()) {
      return;
    }
    final anchor = anchorContext.findRenderObject();
    final navigator = Navigator.of(navigatorContext);
    final overlay = navigator.overlay?.context.findRenderObject();
    if (anchor is! RenderBox || overlay is! RenderBox) return;

    final topLeft = overlay.globalToLocal(anchor.localToGlobal(Offset.zero));
    final bottomRight = overlay.globalToLocal(
      anchor.localToGlobal(anchor.size.bottomRight(Offset.zero)),
    );
    await showMenu<void>(
      context: navigatorContext,
      position: RelativeRect.fromRect(
        Rect.fromPoints(topLeft, bottomRight),
        Offset.zero & overlay.size,
      ),
      items: _buildContextUsageMenuItems(
        navigatorContext,
        usage: usage,
        chatProvider: chatProvider,
        canCompact: canCompact,
      ),
    );
  }

  _SessionContextUsageSnapshot _resolveSessionContextUsage(
    ChatProvider chatProvider,
  ) {
    // Cache: skip O(N) scan when messages, provider, and model haven't changed.
    final messages = chatProvider.messages;
    final lastId = messages.isNotEmpty ? messages.last.id : null;
    final pid = chatProvider.selectedProviderId;
    final mid = chatProvider.selectedModelId;
    if (_cachedContextUsage != null &&
        messages.length == _cachedContextUsageMsgCount &&
        lastId == _cachedContextUsageLastMsgId &&
        pid == _cachedContextUsageProviderId &&
        mid == _cachedContextUsageModelId) {
      return _cachedContextUsage!;
    }

    AssistantMessage? latestAssistantWithTokens;
    var totalCost = 0.0;

    for (final message in chatProvider.messages) {
      if (message is! AssistantMessage) {
        continue;
      }
      totalCost += message.cost ?? 0;
    }

    for (final message in chatProvider.messages.reversed) {
      if (message is! AssistantMessage) {
        continue;
      }
      final tokens = message.tokens;
      if (tokens == null) {
        continue;
      }
      final total =
          tokens.input +
          tokens.output +
          tokens.reasoning +
          tokens.cacheRead +
          tokens.cacheWrite;
      if (total <= 0) {
        continue;
      }
      latestAssistantWithTokens = message;
      break;
    }

    final totalTokens = latestAssistantWithTokens == null
        ? 0
        : (latestAssistantWithTokens.tokens!.input +
              latestAssistantWithTokens.tokens!.output +
              latestAssistantWithTokens.tokens!.reasoning +
              latestAssistantWithTokens.tokens!.cacheRead +
              latestAssistantWithTokens.tokens!.cacheWrite);

    final providerId =
        latestAssistantWithTokens?.providerId ??
        chatProvider.selectedProviderId;
    final modelId =
        latestAssistantWithTokens?.modelId ?? chatProvider.selectedModelId;

    Model? model;
    if (providerId != null && modelId != null) {
      for (final provider in chatProvider.providers) {
        if (provider.id != providerId) {
          continue;
        }
        model = provider.models[modelId];
        break;
      }
    }
    model ??= chatProvider.selectedModel;

    final limit = model?.limit.context;
    final rawUsagePercent = (limit != null && limit > 0)
        ? ((totalTokens / limit) * 100).round()
        : 0;

    final snapshot = _SessionContextUsageSnapshot(
      usagePercent: rawUsagePercent.clamp(0, 999).toInt(),
      totalTokens: totalTokens,
      totalCost: totalCost,
      modelLimit: limit,
    );
    _cachedContextUsageMsgCount = messages.length;
    _cachedContextUsageLastMsgId = lastId;
    _cachedContextUsageProviderId = pid;
    _cachedContextUsageModelId = mid;
    _cachedContextUsage = snapshot;
    return snapshot;
  }

  Widget _buildContextUsageControl(
    BuildContext context, {
    required _SessionContextUsageSnapshot usage,
    required bool isCompacting,
    required bool enabled,
  }) {
    final usagePercent = usage.usagePercent;
    final color = _contextUsageColor(
      context,
      usagePercent: usagePercent,
      enabled: enabled,
    );
    final progress = (usagePercent / 100).clamp(0.0, 1.0);
    final knobTextColor = enabled
        ? Theme.of(context).colorScheme.onSurface
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38);

    return SizedBox(
      width: 20,
      height: 20,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: 1,
            strokeWidth: 1.5,
            valueColor: AlwaysStoppedAnimation<Color>(
              color.withValues(alpha: 0.22),
            ),
          ),
          CircularProgressIndicator(
            value: isCompacting ? null : progress,
            strokeWidth: 1.5,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
          Text(
            context.l10n.chatPageStatusUsagePercent(usagePercent),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: usagePercent >= 100 ? 8.5 : 9.5,
              fontWeight: FontWeight.w700,
              color: knobTextColor,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContextUsagePopover(
    BuildContext context, {
    required _SessionContextUsageSnapshot usage,
    required bool isCompacting,
    required bool canCompact,
    required Future<void> Function() onCompactNow,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final serverId = context.read<AppProvider>().activeServer?.id;

    return SizedBox(
      key: const ValueKey<String>('context_usage_popover'),
      width: 280,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.l10n.chatPageStatusContextUsage,
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          _buildContextUsageGrid(context, usage: usage),
          const SizedBox(height: 10),
          Text(
            isCompacting
                ? context.l10n.chatPageStatusCompactingContextNow
                : context.l10n.chatPageStatusAutomaticCompactionExplanation,
            style: textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Divider(
            color: Theme.of(context).colorScheme.outlineVariant,
            height: 1,
          ),
          const SizedBox(height: 10),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: canCompact
                ? () {
                    Navigator.of(context).pop();
                    unawaited(onCompactNow());
                  }
                : null,
            child: SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Icon(
                      Symbols.compress,
                      size: 16,
                      color: canCompact
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isCompacting
                          ? context.l10n.chatPageStatusCompacting
                          : context.l10n.chatPageStatusCompactNow,
                      style: textTheme.labelLarge?.copyWith(
                        color: canCompact
                            ? Theme.of(context).colorScheme.onSurface
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          QuotaPopupSection(serverId: serverId),
        ],
      ),
    );
  }

  Widget _buildContextUsageGrid(
    BuildContext context, {
    required _SessionContextUsageSnapshot usage,
  }) {
    final limit = usage.modelLimit;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildContextUsageMetricCell(
                context,
                label: context.l10n.chatPageStatusUsage,
                value: '${usage.usagePercent}%',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildContextUsageMetricCell(
                context,
                label: context.l10n.chatPageStatusTokens,
                value: _formatIntWithGroup(usage.totalTokens),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _buildContextUsageMetricCell(
                context,
                label: context.l10n.chatPageStatusCost,
                value: _formatUsd(usage.totalCost),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: limit == null
                  ? const SizedBox.shrink()
                  : _buildContextUsageMetricCell(
                      context,
                      label: context.l10n.chatPageStatusLimit,
                      value: _formatIntWithGroup(limit),
                    ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildContextUsageMetricCell(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  String _syncStatusLabel({
    required BuildContext context,
    required ChatProvider chatProvider,
    required AppProvider appProvider,
  }) {
    if (!appProvider.isConnected ||
        chatProvider.syncState == ChatSyncState.reconnecting) {
      return context.l10n.statusReconnecting;
    }
    if (chatProvider.syncState == ChatSyncState.delayed ||
        chatProvider.isInDegradedMode) {
      return context.l10n.statusSyncDelayed;
    }
    return context.l10n.statusConnected;
  }

  bool _hasDelayedServerStatus({required AppProvider appProvider}) {
    final health = _activeServerHealth(appProvider);
    return health == ServerHealthStatus.unknown;
  }

  String _serverStatusLabel({
    required BuildContext context,
    required AppProvider appProvider,
  }) {
    final health = _activeServerHealth(appProvider);
    if (health == ServerHealthStatus.unhealthy) {
      return context.l10n.statusOffline;
    }
    if (_hasDelayedServerStatus(appProvider: appProvider)) {
      return context.l10n.statusDelayed;
    }
    return context.l10n.statusOnline;
  }

  Widget _buildServerStatusControl({required bool closeOnSelect}) {
    return Consumer2<AppProvider, SettingsProvider>(
      builder: (context, appProvider, settingsProvider, _) {
        final active = appProvider.activeServer;
        final statusColor = _serverStatusColor(
          context: context,
          appProvider: appProvider,
        );
        final statusLabel = _serverStatusLabel(
          context: context,
          appProvider: appProvider,
        );
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final visualTokens = theme.visualStyleTokens;

        return PopupMenuButton<String>(
          key: const ValueKey<String>('sidebar_server_switch_button'),
          tooltip: context.l10n.chatPageStatusSwitchServer,
          onSelected: (value) async {
            if (value == '__manage__') {
              await _openSettingsPage(
                closeOnSelect: closeOnSelect,
                initialSectionId: 'servers',
              );
              return;
            }

            final ok = await appProvider.setActiveServer(value);
            if (!ok && mounted) {
              _showChatPageMessageSnackBar(appProvider.errorMessage);
            }
          },
          itemBuilder: (context) {
            final items = <PopupMenuEntry<String>>[];
            for (final server in appProvider.serverProfiles) {
              final serverHealth = appProvider.healthFor(server.id);
              final disabled = serverHealth == ServerHealthStatus.unhealthy;
              items.add(
                PopupMenuItem<String>(
                  value: server.id,
                  enabled: !disabled,
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: switch (serverHealth) {
                            ServerHealthStatus.healthy => Colors.green,
                            ServerHealthStatus.unhealthy => Colors.red,
                            ServerHealthStatus.unknown => Colors.orange,
                          },
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          server.displayName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (server.id == appProvider.activeServerId)
                        const Icon(Symbols.check, size: 16),
                    ],
                  ),
                ),
              );
            }
            items.add(const PopupMenuDivider());
            items.add(
              PopupMenuItem<String>(
                value: '__manage__',
                child: Text(context.l10n.chatPageStatusManageServers),
              ),
            );
            return items;
          },
          child: Container(
            key: const ValueKey<String>('sidebar_server_status_control'),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            decoration: BoxDecoration(
              color: visualTokens.isRefined
                  ? visualTokens.mutedControlSurface
                  : colorScheme.surfaceContainerHighest.withValues(alpha: 0.26),
              borderRadius: visualTokens.isRefined
                  ? visualTokens.controlRadius
                  : AppShapes.borderLarge,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Symbols.cloud,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          active?.displayName ??
                              context.l10n.chatPageStatusServer,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          statusLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                        ),
                      ),
                      if (settingsProvider.isCellularDataSaverActive) ...[
                        const SizedBox(width: 6),
                        Container(
                          key: const ValueKey<String>(
                            'sidebar_server_status_data_saver_chip',
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            settingsProvider.isAggressiveDataSaverActive
                                ? context.l10n.behaviorDataSaverAggressive
                                : context.l10n.chatPageStatusSaver,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: colorScheme.onTertiaryContainer,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Symbols.arrow_drop_down,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
