// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get aboutGitHub => 'GitHub';

  @override
  String get appProviderCannotActivateUnhealthy =>
      'Cannot activate an unhealthy server';

  @override
  String get appProviderDesktopOnly =>
      'Managed local server is available only on desktop.';

  @override
  String get appProviderDetectingCommand => 'Detecting OpenCode command...';

  @override
  String get appProviderErrorCannotActivateUnhealthy =>
      'Cannot activate an unhealthy server';

  @override
  String get appProviderErrorCloudflareOAuthNotSupported =>
      'Cloudflare Access OAuth is not supported on this platform';

  @override
  String get appProviderErrorInstallationFailed =>
      'OpenCode installation failed.';

  @override
  String get appProviderErrorInvalidServerUrl => 'Invalid server URL';

  @override
  String get appProviderErrorLocalServerHealthCheckFailed =>
      'Local server started but health check did not pass.';

  @override
  String get appProviderErrorManagedDesktopOnly =>
      'Managed local server is available only on desktop.';

  @override
  String get appProviderErrorServerAlreadyExists =>
      'A server with this URL already exists';

  @override
  String get appProviderErrorServerProfileNotFound =>
      'Server profile not found';

  @override
  String get appProviderErrorServerUrlRequired => 'Server URL is required';

  @override
  String get appProviderErrorTailscaleNotSupported =>
      'Tailscale is not supported on this platform';

  @override
  String appProviderExitedWithCode(int code) {
    return 'Local server exited with code $code.';
  }

  @override
  String get appProviderFailedToStart =>
      'Failed to start local OpenCode server.';

  @override
  String get appProviderInstallBinary => 'Install Binary';

  @override
  String get appProviderInstallBunOpenCode => 'Install Bun + OpenCode';

  @override
  String get appProviderInstallSucceeded => 'Installation succeeded.';

  @override
  String appProviderInstallSucceededWithPath(String path) {
    return 'Installation succeeded. OpenCode command available at $path.';
  }

  @override
  String get appProviderInstallViaBun => 'Install via Bun';

  @override
  String get appProviderInstallViaNpm => 'Install via npm';

  @override
  String get appProviderInstallationFailed => 'OpenCode installation failed.';

  @override
  String get appProviderInstalledSuccessfully =>
      'OpenCode requirements installed successfully.';

  @override
  String get appProviderInstallingRequirements =>
      'Installing OpenCode requirements...';

  @override
  String get appProviderInvalidServerUrl => 'Invalid server URL';

  @override
  String get appProviderLabelLocalOpenCodeManaged => 'Local OpenCode (Managed)';

  @override
  String get appProviderLabelPrimaryServer => 'Primary server';

  @override
  String get appProviderLocalManaged => 'Local OpenCode (Managed)';

  @override
  String get appProviderLocalServerStopped => 'Local server is stopped.';

  @override
  String get appProviderNotDetectedInstall =>
      'OpenCode command was not detected. Run installation from the wizard.';

  @override
  String appProviderNotDetectedRefresh(String appName) {
    return 'OpenCode command was not detected. If you installed it moments ago, refresh checks or reopen $appName to reload PATH.';
  }

  @override
  String get appProviderOAuthNotSupported =>
      'Cloudflare Access OAuth is not supported on this platform';

  @override
  String get appProviderOpenCodeDetected => 'OpenCode detected';

  @override
  String get appProviderOpenCodeNotDetected => 'OpenCode not detected';

  @override
  String get appProviderPrimaryServer => 'Primary server';

  @override
  String get appProviderProfileNotFound => 'Server profile not found';

  @override
  String get appProviderRunDiagnostics =>
      'Run diagnostics to verify local OpenCode requirements.';

  @override
  String appProviderRunningAt(String url) {
    return 'Running at $url';
  }

  @override
  String get appProviderSetupDetectingOpenCode =>
      'Detecting OpenCode command...';

  @override
  String get appProviderSetupInstallationSucceeded => 'Installation succeeded.';

  @override
  String appProviderSetupInstallationSucceededWithPath(String path) {
    return 'Installation succeeded. OpenCode command available at $path.';
  }

  @override
  String get appProviderSetupInstallingRequirements =>
      'Installing OpenCode requirements...';

  @override
  String get appProviderSetupOpenCodeDetected => 'OpenCode detected';

  @override
  String get appProviderSetupOpenCodeNotDetected => 'OpenCode not detected';

  @override
  String get appProviderSetupOpenCodeNotDetectedInstall =>
      'OpenCode command was not detected. Run installation from the wizard.';

  @override
  String get appProviderSetupOpenCodeNotDetectedRefresh =>
      'OpenCode command was not detected. If you installed it moments ago, refresh checks or reopen CodeWalk to reload PATH.';

  @override
  String get appProviderSetupRequirementsInstalled =>
      'OpenCode requirements installed successfully.';

  @override
  String appProviderSetupUsingOpenCodeAt(String path) {
    return 'Using OpenCode command at $path';
  }

  @override
  String get appProviderStartingLocalServer => 'Starting local server...';

  @override
  String appProviderStatusLocalServerExitedWithCode(int code) {
    return 'Local server exited with code $code.';
  }

  @override
  String get appProviderStatusLocalServerStopped => 'Local server is stopped.';

  @override
  String appProviderStatusRunningAt(String url) {
    return 'Running at $url';
  }

  @override
  String get appProviderStatusStartingLocalServer => 'Starting local server...';

  @override
  String get appProviderStatusStoppingLocalServer => 'Stopping local server...';

  @override
  String get appProviderStoppingLocalServer => 'Stopping local server...';

  @override
  String get appProviderTailscaleNotSupported =>
      'Tailscale is not supported on this platform';

  @override
  String appProviderUsingCommandAt(String path) {
    return 'Using OpenCode command at $path';
  }

  @override
  String get appShellDownloadingUpdate => 'Downloading update…';

  @override
  String get appShellInstall => 'Install';

  @override
  String get appShellInstallFailed => 'Install failed';

  @override
  String get appShellInstallingUpdate => 'Installing update...';

  @override
  String get appShellRestart => 'Restart';

  @override
  String appShellUpdateAvailableResult(String latestVersion) {
    return 'Update available: v$latestVersion';
  }

  @override
  String get appShellUpdateInstalledRestartApp =>
      'Update installed. Restart the app to apply.';

  @override
  String get appShellUpdateInstalledRestartRequired =>
      'Update installed. Restart is required to apply the new version.';

  @override
  String get attachmentCouldNotDecode =>
      'Attachment data could not be decoded.';

  @override
  String get attachmentCouldNotDownload =>
      'Attachment could not be downloaded.';

  @override
  String get attachmentCouldNotSave =>
      'Attachment could not be saved on this device.';

  @override
  String get attachmentDownloadStarted => 'Attachment download started.';

  @override
  String get attachmentLocalNotFound =>
      'Local attachment was not found on this device.';

  @override
  String get attachmentNoValidLocation =>
      'Attachment does not provide a valid location.';

  @override
  String get attachmentNotAvailableOnPlatform =>
      'Attachment actions are not available on this platform.';

  @override
  String get attachmentPathEmpty => 'Attachment path is empty.';

  @override
  String get attachmentPayloadEmpty => 'Attachment payload is empty.';

  @override
  String get attachmentSaveCanceled => 'Save canceled.';

  @override
  String attachmentSavedAndOpened(String path) {
    return 'Attachment saved to $path and opened.';
  }

  @override
  String attachmentSavedPath(String path) {
    return 'Attachment saved to $path.';
  }

  @override
  String attachmentSavedTo(String path) {
    return 'Attachment saved to $path.';
  }

  @override
  String get attachmentUnableToOpenLink =>
      'Unable to open the attachment link.';

  @override
  String get attachmentUnableToOpenLocal =>
      'Unable to open the local attachment.';

  @override
  String get behaviorAdvancedPermissionRule =>
      'Advanced permission rule editing stays out of Settings for now and is deferred to later parity work.';

  @override
  String get behaviorAutomatic => 'Automatic';

  @override
  String get behaviorAutomaticFallback => 'Automatic fallback';

  @override
  String get behaviorCellularDataSaver => 'Cellular data saver';

  @override
  String get behaviorCellularDataSaverActive =>
      'Cellular data saver is active.';

  @override
  String get behaviorChatLevelShare =>
      'Use the chat-level share action to publish one session now. This setting only changes OpenCode’s default sharing policy.';

  @override
  String get behaviorCodeWalkReleaseChecks =>
      'Use About for CodeWalk release checks. This setting only mirrors the official OpenCode `autoupdate` config.';

  @override
  String get behaviorControlsOfficialGlobal =>
      'Controls the official global `share` config, not the share button for an individual chat.';

  @override
  String get behaviorControlsUpstreamOpenCode =>
      'Controls upstream OpenCode runtime updates, not CodeWalk app update checks.';

  @override
  String get behaviorCustomDisplayName =>
      'Custom display name shown in conversations instead of the system username.';

  @override
  String behaviorCutsAutomaticMobile(int inSeconds) {
    return 'Cuts automatic mobile-data usage by stopping background downloads and throttling automatic foreground refreshes to one burst every $inSeconds seconds.';
  }

  @override
  String get behaviorDataSaverActive => 'Active now on mobile data.';

  @override
  String get behaviorDataSaverAggressive => 'Aggressive';

  @override
  String get behaviorDataSaverAggressiveDescription =>
      'Low-bandwidth mode: only the visible workspace stream stays live, global updates are paused, and automatic refreshes are stretched.';

  @override
  String get behaviorDataSaverCellularOnly =>
      'Only applies when the connection is cellular/mobile.';

  @override
  String get behaviorDataSaverOff => 'Off';

  @override
  String get behaviorDataSaverOffHint =>
      'Full realtime and automatic refreshes are enabled.';

  @override
  String get behaviorDataSaverStandard => 'Standard';

  @override
  String get behaviorDataSaverWaiting =>
      'Waiting for the next mobile-data sync window.';

  @override
  String get behaviorDisabled => 'Disabled';

  @override
  String get behaviorLightweightTasksLike =>
      'Used for lightweight tasks like title generation.';

  @override
  String get behaviorManual => 'Manual';

  @override
  String get behaviorNotify => 'Notify only';

  @override
  String get behaviorOfficialOpenCodePermission =>
      'Official OpenCode permission policy is configured in `opencode.json` with allow/ask/deny rules per tool. CodeWalk keeps the official permission-request cards and adds one approved ADR-023 exception: the composer auto-approve toggle replies with `Always` and `remember: true` unconditionally to create durable session-scoped grants, and keeps the same thread-scoped continuity path active in the Android background worker.';

  @override
  String get behaviorOpenCodeBackedDefaults => 'OpenCode-backed defaults';

  @override
  String get behaviorPermissionHandlingProvenance =>
      'Permission handling provenance';

  @override
  String get behaviorPermissionsVariantReasoning =>
      'Permissions and variant/reasoning parity stay separate until their UI can preserve advanced config safely.';

  @override
  String get behaviorPrimaryAgentAgent =>
      'Primary agent used when no agent is explicitly chosen.';

  @override
  String get behaviorRefreshDefaults => 'Refresh defaults';

  @override
  String get behaviorSharedAcrossOpenCode =>
      'Shared across OpenCode clients through config.';

  @override
  String get behaviorTheseValuesWrite =>
      'These values write to `/config` on the active server and match official OpenCode shared config.';

  @override
  String get cannedAddTitle => 'Add canned answer';

  @override
  String get cannedAppendAtCursor => 'Append at cursor';

  @override
  String get cannedAppendAtCursorSubtitle =>
      'Off means replace current composer text';

  @override
  String get cannedAttachFiles => 'Attach files';

  @override
  String get cannedEditTitle => 'Edit canned answer';

  @override
  String get cannedNewQuickReply => 'New quick reply';

  @override
  String get cannedNoSuggestions => 'No suggestions';

  @override
  String get cannedOffMeansReplace => 'Off means replace current composer text';

  @override
  String get cannedQuickReply => 'New quick reply';

  @override
  String get cannedReplace => 'Replace';

  @override
  String get cannedScopeGlobalSubtitle => 'Disable for project-only item';

  @override
  String get cannedScopeGlobalUnavailableSubtitle =>
      'Project-only unavailable in current context';

  @override
  String get cannedSendAutomaticallySubtitle =>
      'Send immediately after inserting this quick reply';

  @override
  String get cannedSendImmediatelyInserting =>
      'Send immediately after inserting this quick reply';

  @override
  String get cannedTextLabel => 'Text';

  @override
  String get chatActionNext => 'Next';

  @override
  String get chatActiveServerUnhealthy =>
      'Active server is unhealthy. Sends will try once and fail fast until recovery.';

  @override
  String get chatActiveServerUnhealthyLabel => 'Active server is unhealthy';

  @override
  String get chatAddServerToStart => 'Add a server to start chatting.';

  @override
  String get chatAppBarMoreActions => 'More actions';

  @override
  String get chatAppBarPinAction => 'Pin to app bar';

  @override
  String get chatAppBarPinDescription =>
      'This action will stay visible outside the menu.';

  @override
  String get chatAppBarUnpinAction => 'Unpin from app bar';

  @override
  String get chatAppBarUnpinDescription =>
      'This action will move back into the menu.';

  @override
  String chatBadgeConversationError(String title) {
    return '\"$title\" has an error.';
  }

  @override
  String chatBadgeConversationNeedsInput(String title) {
    return '\"$title\" needs your input.';
  }

  @override
  String chatBadgeConversationNewReply(String title) {
    return '\"$title\" has a new reply.';
  }

  @override
  String get chatBadgeDataSaverActive => 'Cellular data saver is active.';

  @override
  String get chatBadgeServerNeedsAttention =>
      'Server connection needs attention.';

  @override
  String get chatBadgeSyncing => 'Syncing conversations...';

  @override
  String get chatBlockResponsePendingDescription =>
      'The answer will appear as a single block when this turn finishes.';

  @override
  String get chatBlockResponsePendingTitle => 'Generating response';

  @override
  String get chatCachedConversationsYet => 'No cached conversations yet';

  @override
  String get chatChangedFilesAvailable =>
      'No changed files are available for this session.';

  @override
  String chatChildrenChatProviderCurrentSessionChildren(int length) {
    return 'Children: $length';
  }

  @override
  String get chatChooseAgent => 'Select agent';

  @override
  String get chatChooseDirectory => 'Choose Directory';

  @override
  String get chatChooseEffort => 'Choose effort';

  @override
  String get chatChooseFolderOpen =>
      'Choose a folder to open as project context.';

  @override
  String get chatChooseModel => 'Choose model';

  @override
  String get chatClose => 'Close';

  @override
  String chatCloseProject(String project) {
    return 'Close $project';
  }

  @override
  String get chatCollapseGroup => 'Collapse group';

  @override
  String get chatCommandDescriptionProject => 'Project command';

  @override
  String get chatCommandSourceGeneric => 'command';

  @override
  String get chatCommandSourceProject => 'project';

  @override
  String get chatCompactContext => 'Compact Context';

  @override
  String get chatComposerHintShell => 'Shell command (Esc to exit)';

  @override
  String get chatComposerPlaceholder => 'Type your needs...';

  @override
  String get chatConversation => 'Conversation';

  @override
  String get chatConversations => 'Conversations';

  @override
  String get chatConversationsPane => 'Conversations';

  @override
  String chatCostLabel(double cost) {
    return 'Cost: \$$cost';
  }

  @override
  String get chatCouldNotRefreshSession =>
      'Could not refresh this conversation';

  @override
  String get chatCurrent => 'Use current';

  @override
  String chatDescriptionChildren(int count) {
    return 'Children: $count';
  }

  @override
  String get chatDescriptionCloseApp =>
      'Close app using platform close behavior';

  @override
  String get chatDescriptionCycleModels => 'Cycle recent models';

  @override
  String get chatDescriptionCycleVariant => 'Cycle model variant';

  @override
  String get chatDescriptionDiffFilesZero => 'Diff files: 0';

  @override
  String get chatDescriptionFocusInput => 'Focus message input';

  @override
  String get chatDescriptionFocusOrCloseDrawer =>
      'Focus input (or close drawer when open)';

  @override
  String get chatDescriptionForceExit => 'Force-exit the app';

  @override
  String get chatDescriptionNewConversation => 'New conversation';

  @override
  String get chatDescriptionNextAgent => 'Next agent';

  @override
  String get chatDescriptionOpenProjects =>
      'Use this button to open your projects and conversations.';

  @override
  String get chatDescriptionOpenSettings => 'Open settings';

  @override
  String get chatDescriptionPreviousAgent => 'Previous agent';

  @override
  String get chatDescriptionProjectCommand => 'Project command';

  @override
  String get chatDescriptionQuickOpen => 'Quick open files';

  @override
  String get chatDescriptionRefreshData => 'Refresh chat data';

  @override
  String get chatDescriptionStopResponse =>
      'Stop active response (while responding)';

  @override
  String get chatDescriptionSwitchProject =>
      'Use this button to switch project folders and context.';

  @override
  String get chatDescriptionVoiceInput => 'Start or stop voice input';

  @override
  String get chatDiffFiles => 'Diff files: 0';

  @override
  String get chatDisplay => 'Display';

  @override
  String get chatDisplayToggles => 'Display toggles';

  @override
  String get chatDoubleESCStop => 'Double ESC to stop';

  @override
  String get chatEffortLockedSubConversation =>
      'Effort locked in sub-conversation';

  @override
  String get chatExpandGroup => 'Expand group';

  @override
  String get chatExportCanceled => 'Session export canceled';

  @override
  String get chatFailedToLoadDirectories => 'Failed to load directories';

  @override
  String get chatFailedToLoadFile => 'Failed to load file';

  @override
  String get chatFailedToRefreshProviders =>
      'Failed to refresh providers and models';

  @override
  String get chatFailedToRefreshSubConversations =>
      'Failed to refresh sub-conversations. Please try again.';

  @override
  String get chatFailedToStopResponse => 'Failed to stop current response';

  @override
  String get chatFileExplorerContents => 'Contents';

  @override
  String get chatFileExplorerNames => 'Names';

  @override
  String get chatFilterActive => 'Active';

  @override
  String get chatFilterAll => 'All';

  @override
  String get chatFilterArchived => 'Archived';

  @override
  String get chatFilterDirectories => 'Filter directories';

  @override
  String get chatFilterSessions => 'Filter sessions';

  @override
  String get chatForkFailed => 'Failed to fork conversation';

  @override
  String get chatForked => 'Conversation forked';

  @override
  String get chatGoToFirst => 'Go to first message';

  @override
  String get chatGoToLatest => 'Go to latest message';

  @override
  String chatGroupMessageCountMessages(
    String compactionLabel,
    String messageCount,
  ) {
    return '$messageCount messages hidden before $compactionLabel compaction';
  }

  @override
  String get chatHelloAssistant => 'Hello! I am your AI assistant';

  @override
  String get chatHelp => 'How can I help you?';

  @override
  String get chatHelpMessage =>
      'Use @ for mentions, ! for shell, / for commands';

  @override
  String get chatHideConversationsSidebar => 'Hide Conversations sidebar';

  @override
  String get chatHideUtilitySidebar => 'Hide Utility sidebar';

  @override
  String get chatHistoryCollapsed => 'Previous history is collapsed';

  @override
  String get chatHistoryHideEarlier => 'Hide earlier messages';

  @override
  String chatHistoryMessagesHidden(int count, String label) {
    return '$count messages hidden before $label compaction';
  }

  @override
  String get chatHistoryShowEarlier => 'Show earlier messages';

  @override
  String get chatKeepWorking => 'Keep working';

  @override
  String get chatLargeContentSkipped =>
      'Large or malformed content was skipped for stability.';

  @override
  String get chatLatestToolActivity =>
      'Latest tool activity stays inside this bounded panel to keep the chat viewport stable.';

  @override
  String get chatLoadMore => 'Load more';

  @override
  String get chatLoadingProjectContext => 'Loading project context...';

  @override
  String get chatMainConversationUnavailable =>
      'Main conversation is not available yet.';

  @override
  String get chatParentConversationUnavailable =>
      'Parent conversation is not available yet.';

  @override
  String get chatMentionAgentSubtitle => 'agent';

  @override
  String get chatMentionFileSubtitle => 'file';

  @override
  String get chatMentionSymbolSubtitle => 'symbol';

  @override
  String get chatMessageAttachedFile => 'Attached file';

  @override
  String get chatMessageDetails => 'Details';

  @override
  String get chatMessageHide => 'Hide';

  @override
  String get chatMessageLess => 'Less';

  @override
  String get chatMessageMessagePartUnavailable => 'Message part unavailable';

  @override
  String get chatMessageMetadataAvailable => 'No metadata available';

  @override
  String chatMessageModelMessageModelId(String modelId) {
    return 'Model: $modelId';
  }

  @override
  String get chatMessageMore => 'More';

  @override
  String get chatMessageOpenFile => 'Open file';

  @override
  String chatMessageProviderMessageProviderId(String providerId) {
    return 'Provider: $providerId';
  }

  @override
  String get chatMessageRewindEdit => 'Rewind and edit from here';

  @override
  String get chatMessageRunningTask => 'Running task';

  @override
  String get chatMessageSaveFile => 'Save file';

  @override
  String get chatMessageShow => 'Show';

  @override
  String get chatMessageShowLess => 'Show less';

  @override
  String get chatMessageShowLessCompact => 'Less';

  @override
  String get chatMessageShowMore => 'Show more';

  @override
  String get chatMessageShowMoreCompact => 'More';

  @override
  String get chatMessageThinking => 'Thinking';

  @override
  String get chatMessageThinkingProcess => 'Thinking Process';

  @override
  String get chatMessageToolCall => '1 tool call';

  @override
  String chatMessageToolCalls(int count) {
    return '$count tool calls';
  }

  @override
  String get chatMessageToolCommand => 'Command';

  @override
  String get chatMessageToolCommandTruncated =>
      'Command preview truncated for stability.';

  @override
  String get chatMessageToolDiffOmitted =>
      'Diff preview omitted: edit payload is too large to render safely on mobile.';

  @override
  String get chatMessageToolInput => 'Input';

  @override
  String get chatMessageToolInputTruncated =>
      'Input preview truncated for stability.';

  @override
  String get chatMessageToolOutputTruncated =>
      'Large tool output preview truncated for app stability.';

  @override
  String chatMessageToolQueuedCount(int count) {
    return '$count queued';
  }

  @override
  String chatMessageToolRunningCount(int count) {
    return '$count running';
  }

  @override
  String get chatMessageToolStatusInProgress => 'In progress';

  @override
  String get chatMessageToolStatusNeedsAttention => 'Needs attention';

  @override
  String get chatMessageToolStatusQueued => 'Queued';

  @override
  String get chatMessageYou => 'You';

  @override
  String get chatModelLockedSubConversation =>
      'Model locked in sub-conversation';

  @override
  String get chatNewChat => 'New Chat';

  @override
  String get chatNewChatTourDescription => 'Start a new conversation here.';

  @override
  String get chatNewChatTourTitle => 'New chat';

  @override
  String get chatNoConversationsInProject =>
      'No conversations in this project.';

  @override
  String get chatNoServerYet => 'No server configured yet';

  @override
  String get chatNoSessionSelected =>
      'Select or create a conversation to start chatting';

  @override
  String get chatNoSubConversationFound =>
      'No sub-conversation found for this task.';

  @override
  String get chatOpenFiles => 'Open Files';

  @override
  String get chatOpenProject => 'Open project';

  @override
  String get chatOpenProjectFolder => 'Open project folder...';

  @override
  String get chatOpenProjectToLoad => 'Open project to load conversations.';

  @override
  String get chatOpenSidebar => 'Open sidebar';

  @override
  String get chatPageStatusAutomaticCompactionExplanation =>
      'Automatic compaction happens as context usage grows.';

  @override
  String get chatPageStatusCompactNow => 'Compact now';

  @override
  String get chatPageStatusCompacting => 'Compacting...';

  @override
  String get chatPageStatusCompactingContextNow => 'Compacting context now...';

  @override
  String get chatPageStatusContextCompacted => 'Context compacted';

  @override
  String get chatPageStatusContextUsage => 'Context usage';

  @override
  String get chatPageStatusCost => 'Cost';

  @override
  String get chatPageStatusFailedToCompactContext =>
      'Failed to compact context';

  @override
  String get chatPageStatusLimit => 'Limit';

  @override
  String get chatPageStatusManageServers => 'Manage Servers';

  @override
  String get chatPageStatusSaver => 'Saver';

  @override
  String get chatPageStatusServer => 'Server';

  @override
  String get chatPageStatusSwitchServer => 'Switch Server';

  @override
  String get chatPageStatusTokens => 'Tokens';

  @override
  String get chatPageStatusUsage => 'Usage';

  @override
  String chatPageStatusUsagePercent(int usagePercent) {
    return '$usagePercent';
  }

  @override
  String get chatPermissionAutoApproveOff => 'Permission auto-approve is off';

  @override
  String get chatPermissionAutoApproveOn => 'Permission auto-approve is on';

  @override
  String get chatProjectContext => 'Project Context';

  @override
  String get chatProjectContext2 => 'Project context';

  @override
  String get chatRealtimeGlobalEvent => 'global event';

  @override
  String chatRealtimeGlobalEventReason(String reason) {
    return 'global event ($reason)';
  }

  @override
  String get chatRealtimeGlobalEventStale => 'global event (stale generation)';

  @override
  String chatRealtimeMessageStreamReason(String reason) {
    return 'message stream ($reason)';
  }

  @override
  String get chatRealtimeRealtimeEvent => 'realtime event';

  @override
  String chatRealtimeRealtimeEventReason(String reason) {
    return 'realtime event ($reason)';
  }

  @override
  String get chatRealtimeRealtimeEventStale =>
      'realtime event (stale generation)';

  @override
  String get chatRealtimeReconnectingServerTry =>
      'Reconnecting to the server. Try again in a moment.';

  @override
  String get chatReasoning => 'Reasoning...';

  @override
  String get chatRecentSessions => 'Recent sessions';

  @override
  String get chatRecentSessionsToggle => 'Recent sessions';

  @override
  String get chatRedoLastTurn => 'Redo last undone turn';

  @override
  String get chatRedoNothing => 'Nothing to redo in this session';

  @override
  String get chatRefresh => 'Refresh';

  @override
  String get chatRefreshConversation => 'Could not refresh this conversation';

  @override
  String get chatRefreshProjects => 'Refresh projects';

  @override
  String get chatRefreshSessionDetails => 'Refresh session details';

  @override
  String chatRemoveDisplayNameHistory(String displayName) {
    return 'Remove $displayName from history';
  }

  @override
  String get chatRetry => 'Retry';

  @override
  String get chatRetry2 => 'Retry';

  @override
  String get chatRetryRefresh => 'Retry refresh';

  @override
  String get chatRetryingModelRequest => 'Retrying model request...';

  @override
  String get chatReturnToMainConversation => 'Return to main conversation';

  @override
  String get chatReturnToParentConversation => 'Return to parent conversation';

  @override
  String get chatReviewChanges => 'Review changes';

  @override
  String get chatSearchConversations => 'Search conversations';

  @override
  String get chatSearchNextResult => 'Next result';

  @override
  String get chatSearchNoResults => 'No results';

  @override
  String get chatSearchPreviousResult => 'Previous result';

  @override
  String chatSearchResultCount(int current, int total) {
    return 'Message $current of $total';
  }

  @override
  String get chatSearchTimeline => 'Search timeline';

  @override
  String get chatSelectDirectory => 'Select directory';

  @override
  String get chatSelectOrCreate =>
      'Select or create a conversation to start chatting';

  @override
  String get chatSelectProjectBelow => 'Select a project below.';

  @override
  String get chatServerSelectedModel => 'Server-selected model';

  @override
  String get chatSessionActions => 'Session actions';

  @override
  String chatSessionChatSessionSession(String title) {
    return 'Chat session: $title';
  }

  @override
  String chatSessionConversationNextAction(String nextAction) {
    return 'Conversation $nextAction';
  }

  @override
  String get chatSessionConversations => 'No conversations';

  @override
  String get chatSessionCreateConversationStart =>
      'Create a new conversation to start chatting';

  @override
  String get chatSessionTabsToggle => 'Session tabs';

  @override
  String chatSessionsLength(int length) {
    return '$length';
  }

  @override
  String get chatSetUpServer => 'Set up server';

  @override
  String get chatSettings => 'Settings';

  @override
  String get chatShortcutsCloseApp => 'Close app using platform close behavior';

  @override
  String get chatShortcutsCycleModels => 'Cycle recent models';

  @override
  String get chatShortcutsCycleVariant => 'Cycle model variant';

  @override
  String get chatShortcutsFocusInput => 'Focus message input';

  @override
  String get chatShortcutsFocusInputCloseDrawer =>
      'Focus input (or close drawer when open)';

  @override
  String get chatShortcutsForceExit => 'Force-exit the app';

  @override
  String get chatShortcutsNewConversation => 'New conversation';

  @override
  String get chatShortcutsNextAgent => 'Next agent';

  @override
  String get chatShortcutsOpenSettings => 'Open settings';

  @override
  String get chatShortcutsPreviousAgent => 'Previous agent';

  @override
  String get chatShortcutsQuickOpen => 'Quick open files';

  @override
  String get chatShortcutsRefreshChat => 'Refresh chat data';

  @override
  String get chatShortcutsStartStopVoice => 'Start or stop voice input';

  @override
  String get chatShortcutsStopResponse =>
      'Stop active response (while responding)';

  @override
  String get chatSidebarAccess => 'Sidebar access';

  @override
  String get chatSortMostRecent => 'Most Recent';

  @override
  String get chatSortOldest => 'Oldest';

  @override
  String get chatSortRecent => 'Recent';

  @override
  String get chatSortSessions => 'Sort sessions';

  @override
  String get chatSortTitle => 'Title';

  @override
  String get chatStartVoiceInput => 'Start voice input';

  @override
  String get chatStartingVoiceInput => 'Starting voice input';

  @override
  String get chatStatusBusy => 'Status: Busy';

  @override
  String get chatStatusPatching => 'Patching';

  @override
  String chatStatusPatchingMultipleFiles(int count) {
    return 'Patching $count files';
  }

  @override
  String get chatStatusPatchingOneFile => 'Patching 1 file';

  @override
  String get chatStatusRetry => 'Status: Retry';

  @override
  String chatStatusRetryCount(int count) {
    return 'Status: Retry #$count';
  }

  @override
  String get chatStatusSubsession => 'Subsession';

  @override
  String get chatStatusThinking => 'Thinking...';

  @override
  String get chatStopVoiceInput => 'Stop voice input';

  @override
  String chatSyncLabel(String label) {
    return 'Sync: $label';
  }

  @override
  String get chatTasks => 'Tasks';

  @override
  String get chatTasksAvailableSession =>
      'No tasks are available for this session.';

  @override
  String get chatTipAcceptanceCriteria =>
      'Tip: Add acceptance criteria for larger changes';

  @override
  String get chatTipAskForPlan => 'Tip: Ask for a plan first on large tasks';

  @override
  String get chatTipBeSpecific =>
      'Tip: Be specific — shorter prompts get faster answers';

  @override
  String get chatTipBreakTasks => 'Tip: Break large tasks into smaller prompts';

  @override
  String get chatTipCompareOptions =>
      'Tip: Ask for alternatives when tradeoffs are unclear';

  @override
  String get chatTipContextKnob =>
      'Tip: Tap the context knob to see usage details';

  @override
  String get chatTipDefineVerification =>
      'Tip: Say which tests or checks should pass';

  @override
  String get chatTipLongPressSend => 'Tip: Long-press Send to insert a newline';

  @override
  String get chatTipMentionFiles =>
      'Tip: Use @ to mention files in your prompt';

  @override
  String get chatTipNameRelevantFiles =>
      'Tip: Name relevant files, screens, or commands';

  @override
  String get chatTipProvideContext =>
      'Tip: Provide context — paste error messages and logs';

  @override
  String get chatTipRenameConversation =>
      'Tip: Tap the title to rename a conversation';

  @override
  String get chatTipRequestDocs =>
      'Tip: Ask for docs updates when behavior changes';

  @override
  String get chatTipShareAttempts =>
      'Tip: Share what you tried and the exact error';

  @override
  String get chatTipShellCommands =>
      'Tip: Use ! at the start to run shell commands';

  @override
  String get chatTipSlashCommands => 'Tip: Use / to access slash commands';

  @override
  String get chatTipStartWithGoal => 'Tip: Start with the end goal';

  @override
  String get chatTipStateConstraints =>
      'Tip: State constraints the agent must preserve';

  @override
  String get chatTipStepByStep =>
      'Tip: Ask for step-by-step when debugging complex issues';

  @override
  String get chatTipUseFocusedAgents =>
      'Tip: Pick a focused agent for plan, review, or build';

  @override
  String get chatToggleSidebars => 'Toggle sidebars';

  @override
  String chatTokensLabel(int total) {
    return 'Tokens: $total';
  }

  @override
  String get chatTourProjectsConversations =>
      'Use this button to open your projects and conversations.';

  @override
  String get chatTourSidebarProjectTools =>
      'Use this menu to show the conversations sidebar and project tools.';

  @override
  String get chatTourSwitchFolders =>
      'Use this button to switch project folders and context.';

  @override
  String get chatUndoLastTurn => 'Undo last turn';

  @override
  String get chatUndoNothing => 'Nothing to undo in this session';

  @override
  String get chatUseCurrent => 'Use current';

  @override
  String get chatWaitingForNetworkConnection =>
      'Waiting for network connection...';

  @override
  String get chatWelcomeMessage => 'Hello! I am your AI assistant.';

  @override
  String get chatWelcomeSubmessage => 'How can I help you today?';

  @override
  String get chatWorkBoundedPanelExplanation =>
      'Latest tool activity stays inside this bounded panel to keep the chat viewport stable.';

  @override
  String get chatWorkExpand => 'Expand';

  @override
  String get chatWorkHide => 'Hide';

  @override
  String get chatWorkMessageOne => '1 work message';

  @override
  String chatWorkMessagesMultiple(int count) {
    return '$count work messages';
  }

  @override
  String get chatWorkShow => 'Show';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonCopiedToClipboard => 'Copied to clipboard';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonFile => 'File';

  @override
  String get commonReset => 'Reset';

  @override
  String get commonSave => 'Save';

  @override
  String get compactionAutomatic => 'automatic';

  @override
  String get compactionManual => 'manual';

  @override
  String get composerAddAttachment => 'Add attachment';

  @override
  String get composerAttachFiles => 'Attach files';

  @override
  String get composerCannedAppendAtCursor => 'Append at cursor';

  @override
  String get composerCannedLabel => 'Label (optional)';

  @override
  String get composerCannedNoReplies => 'No quick replies yet.';

  @override
  String get composerCannedReplace => 'Replace';

  @override
  String get composerCannedSave => 'Save';

  @override
  String get composerCannedScopeGlobal => 'Global';

  @override
  String get composerCannedScopeProject => 'Project-only';

  @override
  String get composerCannedSendAutomatically => 'Send automatically';

  @override
  String get composerCannedText => 'Text';

  @override
  String get composerChatInput => 'Chat input';

  @override
  String get composerDeleteAction => 'Delete';

  @override
  String get composerDropHint => 'Drop images or PDFs to attach';

  @override
  String get composerPastedImageName => 'Pasted image';

  @override
  String get composerEdit => 'Edit';

  @override
  String get composerExtras => 'Extras';

  @override
  String get composerExtrasHide => 'Hide extras';

  @override
  String get composerNewQuickReply => 'New quick reply';

  @override
  String get composerSelectImages => 'Select Images';

  @override
  String get composerSelectPdf => 'Select PDF';

  @override
  String get composerSend => 'Send';

  @override
  String get composerShellMode => 'Shell mode';

  @override
  String get desktopWindowClose => 'Close';

  @override
  String get desktopWindowMaximize => 'Maximize';

  @override
  String get desktopWindowMinimize => 'Minimize';

  @override
  String get desktopWindowRestore => 'Restore';

  @override
  String get dialogDownload => 'Download';

  @override
  String get dialogLanguage => 'Language';

  @override
  String get dialogMoonshineModelSize => 'Model size';

  @override
  String get dialogMoonshineVoiceSetup => 'Moonshine Voice Setup';

  @override
  String get dialogParakeetModel => 'Parakeet model';

  @override
  String get dialogParakeetVoiceSetup => 'Parakeet Voice Setup';

  @override
  String get dialogSenseVoiceModel => 'SenseVoice model';

  @override
  String get dialogSenseVoiceSetup => 'SenseVoice Setup';

  @override
  String get dialogVoiceInputSetup => 'Voice Input Setup';

  @override
  String get errorAnErrorOccurred => 'An error occurred';

  @override
  String get errorAuthRequired => 'Authentication required';

  @override
  String get errorAuthRequiredDesc =>
      'Authentication failed. Reconnect the provider and try again.';

  @override
  String get errorConnectionFailed => 'Connection failed';

  @override
  String get errorConnectionFailedDesc =>
      'Unable to reach the server. Check connection and server status.';

  @override
  String get errorFormatAuthenticationFailedReconnect =>
      'Authentication failed. Reconnect the provider and try again.';

  @override
  String get errorFormatProviderTemporarilyUnavailable =>
      'Provider temporarily unavailable. Try again shortly.';

  @override
  String get errorFormatQuotaExceededCheck =>
      'Quota exceeded. Check your provider plan or billing.';

  @override
  String get errorFormatRateLimitExceeded =>
      'Rate limit exceeded. Wait a moment and try again.';

  @override
  String get errorFormatServerErrorPlease => 'Server error. Please try again.';

  @override
  String get errorFormatServiceTemporarilyUnavailable =>
      'Service temporarily unavailable. The server may be starting up — please try again shortly.';

  @override
  String get errorFormatUnableReachServer =>
      'Unable to reach the server. Check connection and server status.';

  @override
  String get errorProviderUnavailable => 'Provider unavailable';

  @override
  String get errorProviderUnavailableDesc =>
      'Provider temporarily unavailable. Try again shortly.';

  @override
  String get errorQuotaExceeded => 'Quota exceeded';

  @override
  String get errorQuotaExceededDesc =>
      'Quota exceeded. Check your provider plan or billing.';

  @override
  String get errorRateLimitExceeded => 'Rate limit exceeded';

  @override
  String get errorRateLimitExceededDesc =>
      'Rate limit exceeded. Wait a moment and try again.';

  @override
  String get errorServerError => 'Server error';

  @override
  String get errorServerErrorDesc => 'Server error. Please try again.';

  @override
  String get errorServiceUnavailable => 'Service unavailable';

  @override
  String get errorServiceUnavailableDesc =>
      'Service temporarily unavailable. The server may be starting up — please try again shortly.';

  @override
  String get fileActionAttachmentDataDecoded =>
      'Attachment data could not be decoded.';

  @override
  String get fileActionAttachmentPathEmpty => 'Attachment path is empty.';

  @override
  String get fileActionAttachmentPayloadEmpty => 'Attachment payload is empty.';

  @override
  String get fileActionAttachmentProvideValid =>
      'Attachment does not provide a valid location.';

  @override
  String get fileActionAttachmentSavedDevice =>
      'Attachment could not be saved on this device.';

  @override
  String fileActionAttachmentSavedOutputFile(String path) {
    return 'Attachment saved to $path and opened.';
  }

  @override
  String fileActionAttachmentSavedOutputFile2(String path) {
    return 'Attachment saved to $path.';
  }

  @override
  String fileActionAttachmentSavedSavedPath(String savedPath) {
    return 'Attachment saved to $savedPath.';
  }

  @override
  String get fileActionLocalAttachmentFound =>
      'Local attachment was not found on this device.';

  @override
  String get fileActionSaveCanceled => 'Save canceled.';

  @override
  String get fileActionUnableOpenLocal =>
      'Unable to open the local attachment.';

  @override
  String get filesAddChat => 'Add to chat';

  @override
  String get filesAutosave => 'Autosave';

  @override
  String get filesAutosaveOn => 'Autosave on';

  @override
  String get filesAutosaveOff => 'Autosave off';

  @override
  String get filesRedo => 'Redo';

  @override
  String get filesUndo => 'Undo';

  @override
  String get filesBinaryFilePreview => 'Binary file preview is not available.';

  @override
  String get filesClear => 'Clear';

  @override
  String get filesContents => 'Contents';

  @override
  String get filesDuplicate => 'Duplicate';

  @override
  String get filesDuplicated => 'File duplicated';

  @override
  String get filesFileEmpty => 'File is empty.';

  @override
  String get filesAlreadyExists =>
      'A file or folder with that name already exists.';

  @override
  String get filesCopyPath => 'Copy path';

  @override
  String get filesCreateFileTitle => 'Create file';

  @override
  String get filesCreateFolderTitle => 'Create folder';

  @override
  String get filesDelete => 'Delete';

  @override
  String filesDeleteConfirm(String name) {
    return 'Delete $name? This cannot be undone. Folders and their contents will be deleted.';
  }

  @override
  String filesDeleteTitle(String name) {
    return 'Delete $name';
  }

  @override
  String get filesFilesFound => 'No files found';

  @override
  String get filesFileCreated => 'File created.';

  @override
  String get filesFolderCreated => 'Folder created.';

  @override
  String get filesHideSidebar => 'Hide Files sidebar';

  @override
  String get filesInvalidName => 'Enter a valid name without path separators.';

  @override
  String get filesNameHint => 'Name';

  @override
  String get filesNew => 'New';

  @override
  String get filesNewFile => 'New file';

  @override
  String get filesNewFolder => 'New folder';

  @override
  String get filesNames => 'Names';

  @override
  String filesOpenFilesFileState(int length) {
    return 'Open files ($length)';
  }

  @override
  String get filesQuickOpen => 'Quick Open';

  @override
  String get filesQuickOpenFile => 'Quick Open File';

  @override
  String get filesOperationFailed => 'File operation failed.';

  @override
  String get filesOperationUnavailable =>
      'File operations are not available for this server.';

  @override
  String get filesOutsideRoot => 'The path is outside the project root.';

  @override
  String get filesPathCopied => 'Path copied.';

  @override
  String get filesPathMissing => 'Path does not exist.';

  @override
  String get filesPermissionDenied => 'Permission denied.';

  @override
  String get filesRefresh => 'Refresh files';

  @override
  String get filesRename => 'Rename';

  @override
  String filesRenameTitle(String name) {
    return 'Rename $name';
  }

  @override
  String get filesRenamed => 'Renamed.';

  @override
  String get filesRootDeleteBlocked => 'The project root cannot be deleted.';

  @override
  String get filesSearchHint => 'Search files by name or path';

  @override
  String get filesDeleted => 'Deleted.';

  @override
  String get filesTitle => 'Files';

  @override
  String get forwardAction => 'Forward';

  @override
  String get forwardAllFailed => 'Could not forward to any session';

  @override
  String get forwardCancel => 'Cancel';

  @override
  String get forwardDialogSubtitle => 'Select one or more conversations';

  @override
  String get forwardDialogTitle => 'Forward to…';

  @override
  String get forwardLoading => 'Loading sessions…';

  @override
  String get forwardNoOpenProjects => 'No open projects with sessions';

  @override
  String get forwardNoProviderModel =>
      'Select a provider and model before forwarding';

  @override
  String get forwardNoSessions => 'No recent sessions';

  @override
  String forwardPartial(int success, int total) {
    return 'Forwarded to $success of $total';
  }

  @override
  String forwardProvenanceLabel(String origin) {
    return 'Forwarded from: $origin';
  }

  @override
  String get forwardRetry => 'Retry';

  @override
  String get forwardSearchHint => 'Search';

  @override
  String forwardSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get forwardSend => 'Forward';

  @override
  String get forwardServerOffline => 'Server offline';

  @override
  String get forwardShortcutHint => 'Ctrl+Shift+F';

  @override
  String forwardSuccess(int count) {
    return 'Forwarded to $count sessions';
  }

  @override
  String get forwardUndo => 'Undo';

  @override
  String get forwardUndoFailed => 'Could not undo the forward';

  @override
  String get logsAppLogs => 'App Logs';

  @override
  String get logsClear => 'Clear logs';

  @override
  String get logsCloseSearch => 'Close search';

  @override
  String get logsCopyFiltered => 'Copy filtered logs';

  @override
  String get logsEnableLogging => 'Enable app logging';

  @override
  String get logsEnableLoggingAction => 'Enable logging';

  @override
  String get logsEnableLoggingDescription =>
      'Collect in-memory diagnostic logs. Keep this off unless you are troubleshooting.';

  @override
  String get logsEntryContext => 'Context';

  @override
  String get logsEntryTags => 'Tags';

  @override
  String get logsFilterAll => 'All';

  @override
  String get logsFilterByTag => 'Tag';

  @override
  String get logsLevel => 'Level';

  @override
  String get logsLoggingDisabledDescription =>
      'CodeWalk is not collecting detailed app logs. Enable logging only when you need diagnostics.';

  @override
  String get logsLoggingDisabledTitle => 'Logging is disabled';

  @override
  String get logsMeasurePerformance => 'Measure performance';

  @override
  String get logsMeasurePerformanceDescription =>
      'Capture timing logs for expensive app operations. Leave off unless you are diagnosing lag.';

  @override
  String get logsNoLogsYet => 'No logs captured yet.';

  @override
  String get logsNoMatchingLogs => 'No logs match the current filters.';

  @override
  String get logsNoPerformanceData =>
      'No performance logs match the current filters.';

  @override
  String get logsNoTaskData => 'No tasks match the current filters.';

  @override
  String logsPerformanceDuration(int elapsedMs) {
    return '$elapsedMs ms';
  }

  @override
  String get logsPerformanceFilter => 'Performance';

  @override
  String logsPerformanceTileTitle(
    int elapsedMs,
    String operation,
    String status,
  ) {
    return 'PERFORMANCE $operation | $elapsedMs ms | $status';
  }

  @override
  String get logsSearch => 'Search logs';

  @override
  String logsShowingOrderedLength(int length, int length2) {
    return 'Showing $length of $length2 entries';
  }

  @override
  String get logsSlowestPerformance => 'Slowest performance logs';

  @override
  String get logsSlowestTasks => 'Slowest tasks';

  @override
  String get logsTagCustomHint => 'Tag name (for example: task:select_session)';

  @override
  String get logsTagCustomAction => 'Custom...';

  @override
  String logsTaskDuration(int elapsedMs, String operation) {
    return '$operation — $elapsedMs ms';
  }

  @override
  String get logsTaskStatusCanceled => 'canceled';

  @override
  String get logsTaskStatusError => 'error';

  @override
  String get logsTaskStatusOk => 'ok';

  @override
  String get logsTimeRange => 'Time range';

  @override
  String get mathExpressionLabel => 'Math';

  @override
  String get mermaidCopySourceTooltip => 'Copy source';

  @override
  String get mermaidDiagramLabel => 'Mermaid Diagram';

  @override
  String get modelAuto => 'Auto';

  @override
  String get modelChooseAgent => 'Choose agent';

  @override
  String get modelFavorites => 'Favorites';

  @override
  String get modelFree => 'Free';

  @override
  String get modelLabelBaseEnglish => 'Base (English)';

  @override
  String get modelLabelParakeet => 'Parakeet V3 (25 European languages)';

  @override
  String get modelLabelSenseVoice => 'SenseVoice (zh/en/ja/ko/yue)';

  @override
  String get modelLabelTinyEnglish => 'Tiny (English)';

  @override
  String get modelLoadingModels => 'Loading models';

  @override
  String get modelModelsFound => 'No models found';

  @override
  String get modelRetryModels => 'Retry models';

  @override
  String get modelSearchHint => 'Search model or provider';

  @override
  String get msgBatterySettingsFailed =>
      'Could not open Android battery optimization settings.';

  @override
  String get msgBatterySettingsOpened =>
      'Android battery settings opened. Allow unrestricted battery for CodeWalk.';

  @override
  String get msgClearUsernameNeedsConfigEdit =>
      'Clearing the OpenCode conversation username still requires editing config outside the app.';

  @override
  String get msgCommandCopied => 'Command copied';

  @override
  String get msgCopiedToClipboard => 'Copied to clipboard';

  @override
  String get msgEnterUsernameToSave =>
      'Enter a username to save a custom OpenCode conversation name.';

  @override
  String get msgFailedToSendMessage =>
      'Failed to send message. Draft kept for retry.';

  @override
  String get msgFailedToStartVoiceInput => 'Failed to start voice input';

  @override
  String msgFilePathNotFound(String path) {
    return 'File not found: $path';
  }

  @override
  String get msgFilteredLogsCopied => 'Filtered logs copied to clipboard';

  @override
  String get msgInfoAgent => 'Agent';

  @override
  String get msgInfoCompaction => 'Compaction';

  @override
  String msgInfoCost(String cost) {
    return 'Cost: \$$cost';
  }

  @override
  String get msgInfoMessageInfo => 'Message Info';

  @override
  String msgInfoModel(String modelId) {
    return 'Model: $modelId';
  }

  @override
  String get msgInfoNoMetadata => 'No metadata available';

  @override
  String msgInfoPartDescriptionModel(String description, String model) {
    return '$description$model';
  }

  @override
  String get msgInfoPatch => 'Patch';

  @override
  String msgInfoProvider(String providerId) {
    return 'Provider: $providerId';
  }

  @override
  String get msgInfoRetry => 'Retry';

  @override
  String get msgInfoSnapshot => 'Snapshot';

  @override
  String msgInfoSubtaskPartAgent(String agent) {
    return 'Subtask ($agent)';
  }

  @override
  String msgInfoTokens(int total) {
    return 'Tokens: $total';
  }

  @override
  String get msgInfoUndoThisTurn => 'Undo this turn';

  @override
  String get msgInfoView => 'View';

  @override
  String get msgNoSystemSoundsFound =>
      'No system sound was found on this device.';

  @override
  String get msgNoValidFilesSelected => 'No valid files were selected';

  @override
  String get msgSomeSelectedFilesNotAttached =>
      'Some selected files could not be attached.';

  @override
  String get msgReadAloud => 'Read aloud';

  @override
  String get msgReadAloudNotAvailable =>
      'Text-to-speech is not available on this device.';

  @override
  String get msgSetupDebugCopied => 'OpenCode setup debug copied to clipboard';

  @override
  String get msgShareAsImage => 'Share as image';

  @override
  String get msgShareAsImageFailed => 'Could not share message as image.';

  @override
  String get msgShareAsImageSubject => 'CodeWalk message';

  @override
  String get msgShareAsImageTooTall =>
      'Message is too long to share as an image.';

  @override
  String get msgStopReadAloud => 'Stop reading';

  @override
  String get msgSystemSoundPickerUnavailable =>
      'System sound picker is not available on this platform.';

  @override
  String get msgUpdatedButRefreshFailed =>
      'Updated the server setting, but could not refresh chat providers.';

  @override
  String get msgVoiceInputUnavailable =>
      'Voice input is unavailable on this device';

  @override
  String get notifAndroidBatteryOptimization => 'Android battery optimization';

  @override
  String get notifConversationUpdates => 'Conversation updates';

  @override
  String get notifNotificationsArriveReopening =>
      'If notifications only arrive when reopening the app, allow CodeWalk to run without optimization on this device.';

  @override
  String get notifResponseRunningKeep =>
      'When a response is running, keep realtime active briefly after you leave the app.';

  @override
  String notifSelectedSoundLabel(String soundLabel) {
    return 'Selected: $soundLabel';
  }

  @override
  String get notificationAgentFinished =>
      'Agent finished the current response.';

  @override
  String get notificationConversationUpdates => 'Conversation updates';

  @override
  String get notificationOpenToClear =>
      'Open this conversation to clear related notifications.';

  @override
  String get notificationSession => 'Session';

  @override
  String get notificationSoundLoadFailed =>
      'Failed to load Android system sounds';

  @override
  String get onboardingAIGeneratedTitles => 'AI generated titles';

  @override
  String get onboardingAddServerLater =>
      'You can add a server later in Settings > Servers.';

  @override
  String get onboardingAddedButHealthCheckFailed =>
      'Server added but health check failed. It may still be starting up.';

  @override
  String get onboardingAlmostInstallOpenCode =>
      'You are almost there. Install OpenCode first, then connect CodeWalk to the server URL.';

  @override
  String onboardingAppProviderLocalSetupLogsLength(int length, int length2) {
    return '$length setup log lines and $length2 setup events are available in the separate setup debug screen.';
  }

  @override
  String get onboardingAuthenticate => 'Authenticate';

  @override
  String get onboardingAvailable => 'available';

  @override
  String get onboardingAvailableOnlyDesktop =>
      'Available only on desktop (Linux/macOS/Windows).';

  @override
  String get onboardingBasicAuthTip =>
      'Enable Basic Auth only if your OpenCode server is password-protected.';

  @override
  String get onboardingChooseAnotherPath => 'Choose another path';

  @override
  String get onboardingChooseHowToSetup => 'Choose how to set up your server';

  @override
  String get onboardingClear => 'Clear';

  @override
  String get onboardingCloudflareAuthFailed =>
      'Cloudflare Access authentication failed.';

  @override
  String get onboardingCodeWalkAppOpenCode =>
      'CodeWalk is the app. OpenCode is the engine it connects to.';

  @override
  String get onboardingConnectRunningServer => 'Connect to a running server';

  @override
  String get onboardingConnectionIssue => 'Connection issue';

  @override
  String get onboardingConnectionSaved =>
      'Server connection saved successfully.';

  @override
  String get onboardingConnectionTips => 'Connection tips';

  @override
  String get onboardingConnectionUpdated =>
      'Server connection updated successfully.';

  @override
  String get onboardingContinue => 'Continue';

  @override
  String get onboardingContinueServerURL => 'Continue to server URL';

  @override
  String get onboardingCopyLoginURL => 'Copy login URL';

  @override
  String get onboardingCouldNotVerify =>
      'Could not verify the server connection.';

  @override
  String get onboardingDefaultURLEmulator =>
      'Default URL, emulator loopback, auth, and debug help.';

  @override
  String onboardingDesktopOnlyDiagnose(String appName) {
    return 'Desktop only: $appName can diagnose, install, and run OpenCode for you.';
  }

  @override
  String get onboardingDetailedSetupEvents =>
      'Detailed setup events were captured for troubleshooting.';

  @override
  String get onboardingDonShowAgain => 'Don\'t show again';

  @override
  String get onboardingDone => 'Done';

  @override
  String get onboardingEditServer => 'Edit server';

  @override
  String get onboardingEditServerConnection => 'Edit server connection';

  @override
  String get onboardingEmulatorRemap =>
      'On Android emulator, localhost and 127.0.0.1 are remapped to 10.0.2.2 automatically.';

  @override
  String get onboardingEnterServerUrl => 'Enter a server URL';

  @override
  String get onboardingExisting => 'Use Existing';

  @override
  String get onboardingExplainInstallOpenCode =>
      'Explain how to install OpenCode, start the server, and then connect from CodeWalk.';

  @override
  String get onboardingFailed => 'Failed';

  @override
  String get onboardingGoodOptionDesktop => 'Good first option on desktop';

  @override
  String get onboardingHealthCheckFailedMayBeStarting =>
      'Server health check failed. It may still be starting up.';

  @override
  String get onboardingInstallBinary => 'Install Binary';

  @override
  String get onboardingInstallBun => 'Install via Bun';

  @override
  String get onboardingInstallBunOpenCode => 'Install Bun + OpenCode';

  @override
  String get onboardingInstallNpm => 'Install via npm';

  @override
  String get onboardingInstallRunOpenCode =>
      'Install and run OpenCode directly from CodeWalk on desktop.';

  @override
  String get onboardingInvalidUrl => 'Invalid URL';

  @override
  String get onboardingLabel => 'Label (optional)';

  @override
  String get onboardingLabelHint => 'My server';

  @override
  String onboardingLatestOutputAppProvider(String localServerLastOutput) {
    return 'Latest output: $localServerLastOutput';
  }

  @override
  String get onboardingLetCodeWalkSet => 'Let CodeWalk set it up locally';

  @override
  String get onboardingLocalServerSetup => 'Local server setup';

  @override
  String get onboardingManagedLocalServer => 'Managed local server';

  @override
  String get onboardingManagedLocalServer2 =>
      'Managed local server mode is available only on desktop builds (Linux/macOS/Windows).';

  @override
  String onboardingNeedsOpenCodeServer(String appName) {
    return '$appName needs an OpenCode server before it can help with your code.';
  }

  @override
  String get onboardingNotAvailable => 'not available';

  @override
  String get onboardingNotWritable => 'not writable';

  @override
  String get onboardingOpenCode => 'What is OpenCode?';

  @override
  String get onboardingOpenCodeRunningDevice =>
      'I already have OpenCode running on this device or somewhere on my network.';

  @override
  String get onboardingOpenCodeRunsLocally =>
      'OpenCode runs locally or on a server and powers the AI coding features inside CodeWalk. If OpenCode is already running, connect to it. If not, pick one of the guided setup paths below.';

  @override
  String get onboardingOpenTailscaleLogin =>
      'Could not open Tailscale login URL.';

  @override
  String get onboardingPassword => 'Password';

  @override
  String get onboardingPasswordRequired => 'Enter password';

  @override
  String get onboardingPickSetupPath =>
      'Pick the setup path that matches your current OpenCode setup.';

  @override
  String get onboardingPreconditionDirectoryNotWritable =>
      'Install directory is not writable. Check user permissions.';

  @override
  String get onboardingPreconditionInstallViaBunRecommendation =>
      'Install via Bun is recommended by OpenCode maintainers.';

  @override
  String get onboardingPreconditionNetworkFailed =>
      'Network access failed. Check connectivity before installing OpenCode.';

  @override
  String get onboardingPreconditionNoRuntimeDetected =>
      'No runtime detected. Install OpenCode binary directly or bootstrap Bun first.';

  @override
  String get onboardingPreconditionNodeNpmAvailable =>
      'Node + npm are available. Install OpenCode via npm or install Bun for the recommended flow.';

  @override
  String get onboardingPreconditionOpenCodeAlreadyAvailable =>
      'OpenCode is already available. You can use the detected command immediately.';

  @override
  String get onboardingPreconditionWindowsPathLagHint =>
      ' On Windows, refresh checks after install because PATH updates may lag in already-open apps.';

  @override
  String get onboardingPreconditionWindowsWslRecommendation =>
      'Windows build detected. WSL is recommended by OpenCode docs, but npm install can be used as fallback.';

  @override
  String get onboardingReachable => 'reachable';

  @override
  String get onboardingReady => 'Ready';

  @override
  String get onboardingRecommendedOrderTry =>
      'Recommended order: try Install Bun + OpenCode if you want CodeWalk to bootstrap everything for you. Use Existing if OpenCode is already installed.';

  @override
  String get onboardingRefreshChecks => 'Refresh Checks';

  @override
  String get onboardingRunDiagnosticsToVerify =>
      'Run diagnostics to verify local OpenCode requirements.';

  @override
  String get onboardingSaveAndTest => 'Save and test';

  @override
  String get onboardingServerConnectedReady =>
      'Your server is connected and ready to use.';

  @override
  String get onboardingServerConnection => 'Server connection';

  @override
  String get onboardingServerSettingsSaved =>
      'Your server settings were saved and health checks were refreshed.';

  @override
  String get onboardingServerSetup => 'Server setup';

  @override
  String get onboardingServerUpdated => 'Server updated';

  @override
  String get onboardingServerUrl => 'Server URL';

  @override
  String get onboardingSetup => 'Setup';

  @override
  String get onboardingSetupWizard => 'Setup wizard';

  @override
  String get onboardingShowSetupSteps => 'Show me the setup steps';

  @override
  String get onboardingShowSetupSteps2 => 'Show setup steps';

  @override
  String get onboardingSkip => 'Skip for now';

  @override
  String get onboardingSkipSetup => 'Skip setup?';

  @override
  String get onboardingStart => 'Start';

  @override
  String onboardingStartUsing(String appName) {
    return 'Start using $appName';
  }

  @override
  String get onboardingStarting => 'Starting';

  @override
  String get onboardingStop => 'Stop';

  @override
  String get onboardingStopped => 'Stopped';

  @override
  String get onboardingStopping => 'Stopping';

  @override
  String onboardingSuggestedUrl(String url) {
    return 'Suggested local OpenCode server URL: $url';
  }

  @override
  String get onboardingTailscaleAdminApproval =>
      'Tailscale admin approval required';

  @override
  String get onboardingTailscaleAuthAfterSave =>
      'Tailscale will authenticate after saving';

  @override
  String onboardingTailscaleAuthAfterSaveTest(String appName) {
    return 'After you save and test this server, $appName will open Tailscale login if this device is not authenticated yet.';
  }

  @override
  String get onboardingTailscaleConnected => 'Tailscale connected';

  @override
  String get onboardingTailscaleConnecting => 'Tailscale connecting';

  @override
  String get onboardingTailscaleConnectionFailed =>
      'Tailscale connection failed';

  @override
  String get onboardingTailscaleLoginRequired => 'Tailscale login required';

  @override
  String get onboardingTailscaleOpenLoginUrl =>
      'Open the login URL to add this device to your tailnet. If the browser did not open, copy the URL below.';

  @override
  String get onboardingTailscaleUnsupported => 'Tailscale unsupported';

  @override
  String get onboardingTestConnection => 'Test connection';

  @override
  String get onboardingTesting => 'Testing...';

  @override
  String get onboardingUnreachable => 'unreachable';

  @override
  String get onboardingUseBasicAuth => 'Use Basic Auth';

  @override
  String get onboardingUsername => 'Username';

  @override
  String get onboardingUsernameRequired => 'Enter username';

  @override
  String get onboardingUsesServerTitle =>
      'Uses your server\'s title agent to name conversations';

  @override
  String get onboardingUsingDetectedCommand =>
      'Using detected OpenCode command.';

  @override
  String get onboardingViewSetupDebug => 'View setup debug';

  @override
  String onboardingWelcomeTo(String appName) {
    return 'Welcome to $appName';
  }

  @override
  String get onboardingWindowsTipInstalling =>
      'Windows tip: after installing, click Refresh Checks. If detection still fails, reopen CodeWalk to reload PATH changes.';

  @override
  String get onboardingWritable => 'writable';

  @override
  String get onboardingYoureAllSet => 'You\'re all set!';

  @override
  String get permissionAllowOnce => 'Allow Once';

  @override
  String get permissionAlways => 'Always';

  @override
  String get permissionBack => 'Back';

  @override
  String get permissionConfirmReject => 'Confirm Reject';

  @override
  String get permissionReject => 'Reject';

  @override
  String get permissionReopen => 'Reopen';

  @override
  String get questionAnswerSelected => 'No answer selected.';

  @override
  String get questionCommaSeparatedValues => 'Comma-separated values';

  @override
  String get questionQuestionGroupMarked =>
      'Question group marked as rejected. You can keep chatting and reopen this group anytime before confirming.';

  @override
  String get questionQuestionRequest => 'Question request';

  @override
  String get questionQuestionsProvidedSubmit =>
      'No questions provided. You can submit an empty response.';

  @override
  String get questionReviewAnswersSubmitting =>
      'Review your answers before submitting.';

  @override
  String get quotaAuthCookie => 'Auth cookie';

  @override
  String get quotaConnect => 'Connect';

  @override
  String get quotaForget => 'Forget';

  @override
  String get quotaOpenCodeGoConnectDescription =>
      'Connect the usage dashboard to show rolling, weekly, and monthly limits.';

  @override
  String get quotaOpenCodeGoDetected => 'OpenCode Go detected';

  @override
  String get quotaOpenCodeGoNeedsReconnect => 'OpenCode Go needs reconnect';

  @override
  String get quotaOpenCodeGoReconnectDescription =>
      'Refresh the dashboard credentials to restore usage bars.';

  @override
  String get quotaOpenCodeGoUsage => 'OpenCode Go usage';

  @override
  String get quotaOpenDashboard => 'Open OpenCode dashboard';

  @override
  String get quotaPaceExplanation =>
      'Pace predicts total usage by the end of the current limit window based on the current rate.';

  @override
  String quotaPacePercent(String percent) {
    return 'Pace $percent%';
  }

  @override
  String get quotaRateLimits => 'Rate limits';

  @override
  String get quotaReconnect => 'Reconnect';

  @override
  String get quotaRefreshing => 'Refreshing...';

  @override
  String quotaResetsIn(String time) {
    return 'Resets in $time';
  }

  @override
  String get quotaSaving => 'Saving...';

  @override
  String get quotaWorkspaceId => 'Workspace ID';

  @override
  String get serverClearOAuth => 'Clear OAuth';

  @override
  String get serverConnectionAttention => 'Server connection needs attention.';

  @override
  String get serverHealthHealthy => 'Healthy';

  @override
  String get serverHealthUnhealthy => 'Unhealthy';

  @override
  String get serverHealthUnknown => 'Unknown';

  @override
  String get serverOAuthAuthFailed => 'OAuth authentication failed';

  @override
  String get serverOAuthChip => 'OAuth';

  @override
  String get serverOAuthNotSupported =>
      'Cloudflare Access OAuth is not supported on this platform';

  @override
  String get serverReauthenticate => 'Re-authenticate';

  @override
  String get serverTailscaleChip => 'Tailscale';

  @override
  String get serversActive => 'Active';

  @override
  String get serversActiveServer => 'Active Server';

  @override
  String get serversAddLeastOpenCode =>
      'Add at least one OpenCode server to start using the app.';

  @override
  String get serversAddServer => 'Add Server';

  @override
  String get serversCancel => 'Cancel';

  @override
  String get serversCannotActivateUnhealthy =>
      'Cannot activate an unhealthy server';

  @override
  String get serversCheckHealth => 'Check Health';

  @override
  String get serversClearDefault => 'Clear Default';

  @override
  String serversCommandAppProviderLocalServerCommandPath(
    String localServerCommandPath,
  ) {
    return 'Command: $localServerCommandPath';
  }

  @override
  String get serversCopy => 'Copy';

  @override
  String get serversDefault => 'Default';

  @override
  String get serversDelete => 'Delete';

  @override
  String get serversDeleteServer => 'Delete server';

  @override
  String get serversDesktopModeExplanation =>
      'Desktop mode can launch and manage `opencode serve` directly from CodeWalk.';

  @override
  String get serversEdit => 'Edit';

  @override
  String get serversLocalOpenCodeServer => 'Local OpenCode Server';

  @override
  String get serversManagedModeAvailable =>
      'This managed mode is available only on desktop builds (Linux/macOS/Windows).';

  @override
  String get serversNoServersFound => 'No servers found';

  @override
  String get serversRefreshHealth => 'Refresh Health';

  @override
  String serversRemoveProfileDisplayName(String displayName) {
    return 'Remove \"$displayName\"?';
  }

  @override
  String get serversSearchActiveHint => 'Search active server';

  @override
  String get serversServersConfigured => 'No servers configured';

  @override
  String get serversSetActive => 'Set Active';

  @override
  String get serversSetDefault => 'Set Default';

  @override
  String get serversSetupDebug => 'Setup Debug';

  @override
  String get serversSetupWizard => 'Setup Wizard';

  @override
  String get serversTailscaleAdminApprovalRequired =>
      'Tailscale admin approval required';

  @override
  String get serversTailscaleAuthRequired =>
      'Tailscale authentication required';

  @override
  String get serversTailscaleConnectExplanation =>
      'Tailscale will connect when this active profile is used.';

  @override
  String get serversTailscaleConnected => 'Tailscale connected';

  @override
  String get serversTailscaleConnecting => 'Tailscale connecting';

  @override
  String get serversTailscaleConnectionFailed => 'Tailscale connection failed';

  @override
  String get serversTailscaleDisconnected => 'Tailscale disconnected';

  @override
  String get serversTailscaleLoginExplanation =>
      'Open the Tailscale login URL to add this device to your tailnet.';

  @override
  String get serversTailscaleTrafficExplanation =>
      'OpenCode traffic for this active profile is routed through Tailscale.';

  @override
  String get serversTailscaleUnsupported => 'Tailscale unsupported';

  @override
  String get serversUnhealthyActivateError =>
      'This server is unhealthy. Use check health or edit settings before activating.';

  @override
  String get sessionActionArchived => 'archived';

  @override
  String get sessionActionDeleted => 'deleted';

  @override
  String get sessionActionForked => 'forked';

  @override
  String get sessionActionPinned => 'pinned';

  @override
  String get sessionActionUnarchived => 'unarchived';

  @override
  String get sessionActionUnpinned => 'unpinned';

  @override
  String get sessionArchive => 'Archive';

  @override
  String get sessionCancelRename => 'Cancel rename';

  @override
  String sessionChildrenCount(int count) {
    return 'Children: $count';
  }

  @override
  String get sessionCompactContext => 'Compact context';

  @override
  String get sessionCopyLink => 'Copy Link';

  @override
  String get sessionDelete => 'Delete';

  @override
  String sessionDeleteConfirm(String title) {
    return 'Are you sure you want to delete the conversation \"$title\"? This action cannot be undone.';
  }

  @override
  String get sessionDeleteTitle => 'Delete Conversation';

  @override
  String get sessionDiffChangedFile => 'Changed file';

  @override
  String get sessionDiffContentNotCaptured =>
      'File content not captured by the server';

  @override
  String sessionDiffFilesChanged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files changed',
      one: '1 file changed',
    );
    return '$_temp0';
  }

  @override
  String sessionDiffFilesCount(int count) {
    return 'Diff files: $count';
  }

  @override
  String sessionDiffLinesAddedRemoved(int added, int removed) {
    return '+$added lines added -$removed lines removed';
  }

  @override
  String sessionDiffLinesCollapsed(int count) {
    return '$count lines collapsed — tap to expand';
  }

  @override
  String get sessionDiffLoading => 'Loading changed files…';

  @override
  String get sessionDiffReview => 'Review changes';

  @override
  String get sessionDiffSplit => 'Split';

  @override
  String get sessionDiffSummary => 'Summary';

  @override
  String get sessionDiffUnified => 'Unified';

  @override
  String get sessionExportAssistant => 'Assistant';

  @override
  String get sessionExportCanceled => 'Session export canceled';

  @override
  String get sessionExportDebugJson => 'Export debug JSON';

  @override
  String get sessionExportDebugJsonErrorClipboard =>
      'Could not save file; debug JSON copied to clipboard';

  @override
  String get sessionExportDebugJsonSaved => 'Debug JSON export saved';

  @override
  String get sessionExportDebugJsonTitle => 'Export session as debug JSON';

  @override
  String get sessionExportError => 'Error:';

  @override
  String get sessionExportInput => 'Input:';

  @override
  String get sessionExportMarkdown => 'Export Markdown';

  @override
  String get sessionExportMarkdownErrorClipboard =>
      'Could not save file; Markdown copied to clipboard';

  @override
  String get sessionExportMarkdownSaved => 'Markdown export saved';

  @override
  String get sessionExportMarkdownTitle => 'Export session as Markdown';

  @override
  String get sessionExportOutput => 'Output:';

  @override
  String get sessionExportUntitled => 'Untitled session';

  @override
  String get sessionExportUser => 'User';

  @override
  String get sessionFailedRename => 'Failed to rename conversation';

  @override
  String get sessionFailedUpdateArchive => 'Failed to update archive state';

  @override
  String get sessionFailedUpdateSharing => 'Failed to update sharing state';

  @override
  String get sessionFork => 'Fork';

  @override
  String get sessionForkFailed => 'Failed to fork conversation';

  @override
  String get sessionForked => 'Conversation forked';

  @override
  String sessionHasError(String title) {
    return '\"$title\" has an error.';
  }

  @override
  String sessionHasNewReply(String title) {
    return '\"$title\" has a new reply.';
  }

  @override
  String get sessionKeyboardShortcuts => 'Keyboard shortcuts';

  @override
  String sessionNeedsInput(String title) {
    return '\"$title\" needs your input.';
  }

  @override
  String get sessionNoCachedConversations => 'No cached conversations yet';

  @override
  String get sessionNoConversationsInProject =>
      'No conversations in this project.';

  @override
  String get sessionNotAvailable =>
      'Conversation is not available for this project yet';

  @override
  String get sessionOpenProjectToLoad => 'Open project to load conversations.';

  @override
  String get sessionPin => 'Pin';

  @override
  String get sessionRename => 'Rename';

  @override
  String get sessionRenameHint => 'Enter new conversation name';

  @override
  String get sessionRenameTitle => 'Rename Conversation';

  @override
  String get sessionSaveTitle => 'Save title';

  @override
  String get sessionShare => 'Share session';

  @override
  String get sessionShareAction => 'Share';

  @override
  String get sessionShareLinkCopied => 'Share link copied';

  @override
  String get sessionShareLinkUnavailable =>
      'Share link unavailable for this session';

  @override
  String get sessionShared => 'Conversation shared';

  @override
  String get sessionSyncing => 'Syncing conversations...';

  @override
  String get sessionTitleHint => 'Conversation title';

  @override
  String get sessionUnarchive => 'Unarchive';

  @override
  String get sessionUnpin => 'Unpin';

  @override
  String get sessionUnshare => 'Unshare session';

  @override
  String get sessionUnshareAction => 'Unshare';

  @override
  String get sessionUnshared => 'Conversation unshared';

  @override
  String get sessionViewTasks => 'View tasks';

  @override
  String get settingsAboutCheckForUpdates => 'Check for updates';

  @override
  String get settingsAboutCheckOnOpen => 'Check for updates on open';

  @override
  String get settingsAboutCheckOnOpenDescription =>
      'Automatically check when the app starts';

  @override
  String get settingsAboutChecking => 'Checking...';

  @override
  String get settingsAboutDescription => 'Version, updates, help, and app data';

  @override
  String get settingsAboutDismiss => 'Dismiss';

  @override
  String settingsAboutDownloading(String percent) {
    return 'Downloading... $percent%';
  }

  @override
  String get settingsAboutEraseAllData => 'Erase all data and restart';

  @override
  String get settingsAboutInstallUpdate => 'Install update';

  @override
  String get settingsAboutInstalling => 'Installing...';

  @override
  String settingsAboutLatestVersion(String version) {
    return 'v$version is the latest version';
  }

  @override
  String get settingsAboutLoading => 'Loading...';

  @override
  String get settingsAboutReplayChatTour => 'Replay chat tour';

  @override
  String get settingsAboutReplayChatTourDescription =>
      'Close settings and show the guided chat walkthrough';

  @override
  String get settingsAboutResetApp => 'Reset app';

  @override
  String get settingsAboutResetAppQuestion => 'Reset app?';

  @override
  String get settingsAboutResetAppWarning =>
      'This will erase all servers, settings, and cached data. This action cannot be undone.';

  @override
  String get settingsAboutRetryInstall => 'Retry install';

  @override
  String get settingsAboutTapToCheck => 'Tap to check for new versions';

  @override
  String get settingsAboutTitle => 'About';

  @override
  String get settingsAboutUpToDate => 'You\'re up to date';

  @override
  String settingsAboutUpdateAvailable(String version) {
    return 'Update available: v$version';
  }

  @override
  String get settingsAboutUpdateInstalled =>
      'Update installed. Restart the app to apply.';

  @override
  String settingsAboutUpdateVersionSummary(
    String installedVersion,
    String latestVersion,
  ) {
    return 'Current: $installedVersion; available: v$latestVersion';
  }

  @override
  String get settingsAboutVersion => 'Version';

  @override
  String settingsAboutVersionBuild(String buildNumber, String version) {
    return '$version (build $buildNumber)';
  }

  @override
  String get settingsAppearanceAmoledDark => 'AMOLED dark mode';

  @override
  String get settingsAppearanceAmoledDarkActive =>
      'Use pure black surfaces while dark mode is active.';

  @override
  String get settingsAppearanceAmoledDarkInactive =>
      'Switch to dark mode to enable AMOLED surfaces.';

  @override
  String get settingsAppearanceBrandColor => 'Brand color';

  @override
  String get settingsAppearanceBrandColorDynamicBlocked =>
      'Disable wallpaper colors to pick a brand color.';

  @override
  String get settingsAppearanceBrandColorNormal =>
      'Pick a seed color for the app palette.';

  @override
  String get settingsAppearanceBrandColorPresetBlocked =>
      'Switch to CodeWalk Classic to pick a brand color.';

  @override
  String get settingsAppearanceChatFontScale => 'Conversation text size';

  @override
  String get settingsAppearanceChatFontScaleDescription =>
      'Scale the chat message and composer text on top of the system text size.';

  @override
  String get settingsAppearanceCodeWalkClassic => 'CodeWalk Classic';

  @override
  String get settingsAppearanceComposerTips => 'Composer tips';

  @override
  String get settingsAppearanceComposerTipsDescription =>
      'Show or hide rotating tips while the assistant is reasoning.';

  @override
  String get settingsAppearanceContrast => 'Contrast';

  @override
  String get settingsAppearanceContrastDynamicBlocked =>
      'Disable wallpaper colors to adjust contrast.';

  @override
  String get settingsAppearanceContrastHigh => 'High';

  @override
  String get settingsAppearanceContrastNormal =>
      'Adjust the contrast level of the color scheme.';

  @override
  String get settingsAppearanceContrastPresetBlocked =>
      'Switch to CodeWalk Classic to adjust contrast.';

  @override
  String get settingsAppearanceContrastReduced => 'Reduced';

  @override
  String get settingsAppearanceDark => 'Dark';

  @override
  String get settingsAppearanceDensity => 'Density';

  @override
  String get settingsAppearanceDensityDense => 'Dense';

  @override
  String get settingsAppearanceDensityDescription =>
      'Apply spacing and component density across the app.';

  @override
  String get settingsAppearanceDensityExtraDense => 'Extra Dense';

  @override
  String get settingsAppearanceDensityExtraSpacious => 'Extra Spacious';

  @override
  String get settingsAppearanceDensityNormal => 'Normal';

  @override
  String get settingsAppearanceDensitySpacious => 'Spacious';

  @override
  String get settingsAppearanceDescription =>
      'Choose themes, colors, text size, and chat display';

  @override
  String get settingsAppearanceFontSize => 'Text size';

  @override
  String get settingsAppearanceFontSizeDescription =>
      'Adjust the size of system text, conversation text, and terminal text.';

  @override
  String get settingsAppearanceLight => 'Light';

  @override
  String get settingsAppearanceMathRendering => 'Math rendering';

  @override
  String get settingsAppearanceMathRenderingDescription =>
      'Render LaTeX math expressions (\$…\$ and \$\$…\$\$) as typeset equations in chat messages.';

  @override
  String get settingsAppearanceNoPresets => 'No preset palettes found';

  @override
  String get settingsAppearanceOpenCodePresets => 'OpenCode Presets';

  @override
  String get settingsAppearancePresetHelper =>
      'Mirrors the official OpenCode Web built-in theme list.';

  @override
  String get settingsAppearancePresetNote =>
      'Theme colors now follow the official OpenCode Web registry and drive markdown/code surfaces too.';

  @override
  String get settingsAppearancePresetPalette => 'Preset palette';

  @override
  String get settingsAppearanceSearchPreset => 'Search preset palette';

  @override
  String get settingsAppearanceSectionDescription =>
      'Tune visual density and message surfaces for your workflow.';

  @override
  String get settingsAppearanceSectionTitle => 'Appearance';

  @override
  String get settingsAppearanceSystem => 'System';

  @override
  String get settingsAppearanceSystemFontScale => 'System text size';

  @override
  String get settingsAppearanceSystemFontScaleDescription =>
      'Scale all text in the app shell, including menus, dialogs, and sidebars.';

  @override
  String get settingsAppearanceTaskList => 'Task list';

  @override
  String get settingsAppearanceTaskListDescription =>
      'Show or hide the session task list widget.';

  @override
  String get settingsAppearanceTerminalFontSize => 'Terminal text size';

  @override
  String get settingsAppearanceTerminalFontSizeDescription =>
      'Resize the embedded terminal font. Applies immediately to running sessions.';

  @override
  String get settingsAppearanceTheme => 'Theme';

  @override
  String get settingsAppearanceThemeDescription =>
      'Choose light, dark, or system mode, then keep the CodeWalk classic palette or switch to an OpenCode preset.';

  @override
  String get settingsAppearanceVisualStyle => 'Visual style';

  @override
  String get settingsAppearanceVisualStyleDescription =>
      'Choose Classic or softer Refined surfaces.';

  @override
  String get settingsAppearanceVisualStyleClassic => 'Classic';

  @override
  String get settingsAppearanceVisualStyleRefined => 'Refined';

  @override
  String get settingsAppearanceThinkingBubbles => 'Thinking bubbles';

  @override
  String get settingsAppearanceThinkingBubblesDescription =>
      'Show or hide reasoning blocks in assistant messages.';

  @override
  String get settingsAppearanceTitle => 'Appearance';

  @override
  String get settingsAppearanceToolCallBubbles => 'Tool call bubbles';

  @override
  String get settingsAppearanceToolCallBubblesDescription =>
      'Show or hide tool execution cards in assistant messages.';

  @override
  String get settingsAppearanceWallpaperColors => 'Use wallpaper colors';

  @override
  String get settingsAppearanceWallpaperNormal =>
      'Extract color scheme from your device wallpaper.';

  @override
  String get settingsAppearanceWallpaperPresetBlocked =>
      'Switch to CodeWalk Classic to use wallpaper colors.';

  @override
  String get settingsAppearanceWindowChrome => 'Window tabs';

  @override
  String get settingsAppearanceWindowChromeDescription =>
      'Choose how session tabs and the window title bar are combined on desktop.';

  @override
  String get settingsAppearanceWindowChromeIntegrated => 'Integrated tabs';

  @override
  String get settingsAppearanceWindowChromeIntegratedDescription =>
      'Tabs sit at the top of the window and the system title bar is hidden.';

  @override
  String get settingsAppearanceWindowChromeSystem => 'System decoration';

  @override
  String get settingsAppearanceWindowChromeSystemDescription =>
      'Keep the native title bar and show tabs below the app bar.';

  @override
  String get settingsBack => 'Back';

  @override
  String get settingsBehaviorAutoupdateCaveat =>
      'Use About for CodeWalk release checks. This setting only mirrors the official OpenCode `autoupdate` config.';

  @override
  String get settingsBehaviorAutoupdateHelp =>
      'Controls upstream OpenCode runtime updates, not CodeWalk app update checks.';

  @override
  String get settingsBehaviorCellularDataSaver => 'Cellular data saver';

  @override
  String get settingsBehaviorChatRenderMode => 'Chat render mode';

  @override
  String get settingsBehaviorChatRenderModeBlock => 'Block';

  @override
  String get settingsBehaviorChatRenderModeBlockDescription =>
      'Hide live assistant text, reasoning, and tool cards until the current turn can be shown as one block.';

  @override
  String get settingsBehaviorChatRenderModeDescription =>
      'Choose whether assistant responses appear as they stream or reveal after the current turn settles.';

  @override
  String get settingsBehaviorChatRenderModeLive => 'Live';

  @override
  String get settingsBehaviorChatRenderModeLiveDescription =>
      'Show assistant text, reasoning, and tool activity as OpenCode streams events.';

  @override
  String get settingsBehaviorComposerSpellCheck => 'Composer spell check';

  @override
  String get settingsBehaviorComposerSpellCheckDescription =>
      'Use native platform spell check, suggestions, and autocorrect in the chat composer.';

  @override
  String get settingsBehaviorConfigDeferred =>
      'CodeWalk will apply this OpenCode setting after the current response finishes.';

  @override
  String settingsBehaviorConfigUpdateFailed(String field) {
    return 'Could not update the OpenCode $field.';
  }

  @override
  String get settingsBehaviorConversationUsername => 'Conversation username';

  @override
  String get settingsBehaviorConversationUsernameHelp =>
      'Custom display name shown in conversations instead of the system username.';

  @override
  String get settingsBehaviorDataSaverActive => 'Active now on mobile data.';

  @override
  String get settingsBehaviorDataSaverCellularOnly =>
      'Only applies when the connection is cellular/mobile.';

  @override
  String get settingsBehaviorDataSaverDescription =>
      'Cuts automatic mobile-data usage by stopping background downloads and throttling automatic foreground refreshes.';

  @override
  String get settingsBehaviorDataSaverWaiting =>
      'Waiting for the next mobile-data sync window.';

  @override
  String get settingsBehaviorDefaultAgent => 'Default agent';

  @override
  String get settingsBehaviorDefaultAgentHelp =>
      'Primary agent used when no agent is explicitly chosen.';

  @override
  String get settingsBehaviorDefaultModel => 'Default model';

  @override
  String get settingsBehaviorDefaultModelHelp =>
      'Shared across OpenCode clients through config.';

  @override
  String get settingsBehaviorDescription =>
      'Control language, chat behavior, data use, and OpenCode defaults';

  @override
  String get settingsBehaviorEnableDataSaver => 'Enable cellular data saver';

  @override
  String get settingsBehaviorMultiDeviceSync =>
      'Enable experimental multi-device sync';

  @override
  String get settingsBehaviorMultiDeviceSyncDescription =>
      'Sync composer selection (agent/model/variant) with the active server config.';

  @override
  String get settingsBehaviorMultiDeviceSyncWarning =>
      'Can abort ongoing sessions when working in more than one session at the same time.';

  @override
  String get settingsBehaviorNoAgents => 'No agents found';

  @override
  String get settingsBehaviorNoModels => 'No models found';

  @override
  String get settingsBehaviorOpenCodeAutoupdate => 'OpenCode auto-update';

  @override
  String get settingsBehaviorOpenCodeDefaults => 'OpenCode-backed defaults';

  @override
  String get settingsBehaviorOpenCodeDefaultsDescription =>
      'These values write to `/config` on the active server and match official OpenCode shared config.';

  @override
  String get settingsBehaviorOpenCodeSnapshots => 'OpenCode snapshots';

  @override
  String get settingsBehaviorOpenCodeSnapshotsDescription =>
      'Keep upstream git-backed snapshots enabled for undo/redo and recovery history.';

  @override
  String get settingsBehaviorPermissionDeferred =>
      'Advanced permission rule editing stays out of Settings for now and is deferred to later parity work.';

  @override
  String get settingsBehaviorPermissionProvenance =>
      'Permission handling provenance';

  @override
  String get settingsBehaviorPermissionProvenanceDescription =>
      'Official OpenCode permission policy is configured in `opencode.json` with allow/ask/deny rules per tool. CodeWalk keeps the official permission-request cards and adds one approved ADR-023 exception: the composer auto-approve toggle replies with `Always` and `remember: true` unconditionally to create durable session-scoped grants, and keeps the same thread-scoped continuity path active in the Android background worker.';

  @override
  String get settingsBehaviorRefreshDefaults => 'Refresh defaults';

  @override
  String get settingsBehaviorSaveUsername => 'Save username';

  @override
  String get settingsBehaviorSearchAutoupdate => 'Search auto-update mode';

  @override
  String get settingsBehaviorSearchDefaultAgent => 'Search default agent';

  @override
  String get settingsBehaviorSearchDefaultModel => 'Search default model';

  @override
  String get settingsBehaviorSearchShareMode => 'Search sharing mode';

  @override
  String get settingsBehaviorSearchSmallModel => 'Search small model';

  @override
  String get settingsBehaviorShareMode => 'OpenCode sharing default';

  @override
  String get settingsBehaviorShareModeCaveat =>
      'Use the chat-level share action to publish one session now. This setting only changes OpenCode\'s default sharing policy.';

  @override
  String get settingsBehaviorShareModeHelp =>
      'Controls the official global `share` config, not the share button for an individual chat.';

  @override
  String get settingsBehaviorSmallModel => 'Small model';

  @override
  String get settingsBehaviorSmallModelAutoFallback => 'Automatic fallback';

  @override
  String get settingsBehaviorSmallModelFallbackActive =>
      'OpenCode automatic fallback is active because `small_model` is unset.';

  @override
  String get settingsBehaviorSmallModelHelp =>
      'Used for lightweight tasks like title generation.';

  @override
  String get settingsBehaviorSmallModelResetCaveat =>
      'Resetting `small_model` back to automatic fallback still requires editing config outside the app because `/config` patch updates cannot remove keys.';

  @override
  String get settingsBehaviorSnapshotCaveat =>
      'This controls OpenCode snapshot storage and undo/redo support, not CodeWalk local cache snapshots.';

  @override
  String get settingsBehaviorTitle => 'Behavior';

  @override
  String get settingsBehaviorUsernameFallback =>
      'OpenCode uses the system username because `username` is unset.';

  @override
  String get settingsBehaviorUsernamePatchCaveat =>
      'Resetting `username` back to the system default still requires editing config outside the app because `/config` patch updates cannot remove keys.';

  @override
  String get settingsConfigRefreshFailed =>
      'Updated the server setting, but could not refresh chat providers.';

  @override
  String get settingsConfigUpdateDeferred =>
      'CodeWalk will apply this OpenCode setting after the current response finishes.';

  @override
  String get settingsConversationUsername => 'Conversation username';

  @override
  String get settingsDefaultAgent => 'Default agent';

  @override
  String get settingsDefaultModel => 'Default model';

  @override
  String get settingsLanguageDescription =>
      'Choose the language used by CodeWalk. System default follows your device language.';

  @override
  String get settingsLanguageEmptyText => 'No languages found';

  @override
  String get settingsLanguageFieldHelper =>
      'Applies immediately and persists across restarts.';

  @override
  String get settingsLanguageFieldLabel => 'App language';

  @override
  String get settingsLanguageSearchHint => 'Search languages';

  @override
  String get settingsLanguageSystemDefault => 'System default';

  @override
  String get settingsLanguageTitle => 'Language';

  @override
  String get settingsLogsDescription =>
      'Review app diagnostics and troubleshooting details';

  @override
  String get settingsLogsTitle => 'Logs';

  @override
  String get settingsNoAgentsFound => 'No agents found';

  @override
  String get settingsNotificationsAgentSubtitle => 'When a response finishes';

  @override
  String get settingsNotificationsAgentUpdates => 'Agent updates';

  @override
  String get settingsNotificationsAnotherConversation => 'Another conversation';

  @override
  String get settingsNotificationsAppInBackground => 'App in background';

  @override
  String get settingsNotificationsBackgroundAlerts =>
      'Android background alerts';

  @override
  String get settingsNotificationsBackgroundBehavior => 'Background behavior';

  @override
  String get settingsNotificationsBackgroundBehaviorDescription =>
      'Choose how CodeWalk behaves after the app leaves the foreground.';

  @override
  String get settingsNotificationsBackgroundDescription =>
      'Use low-data background monitoring for response completions, permission requests, questions, and errors while the app is not on screen.';

  @override
  String get settingsNotificationsBackgroundToggle =>
      'Background alerts on Android';

  @override
  String get settingsNotificationsBackgroundToggleDescription =>
      'Turn off all Android background checks and hide the persistent monitor notification.';

  @override
  String get settingsNotificationsBatteryDescription =>
      'If notifications only arrive when reopening the app, allow CodeWalk to run without optimization on this device.';

  @override
  String get settingsNotificationsBatteryDisabled =>
      'Battery optimization is disabled for CodeWalk.';

  @override
  String get settingsNotificationsBatteryEnabled =>
      'Battery optimization is enabled. Some devices may delay background alerts.';

  @override
  String get settingsNotificationsBatteryOptimization =>
      'Android battery optimization';

  @override
  String get settingsNotificationsBatteryUnknown =>
      'Could not read battery optimization status yet.';

  @override
  String get settingsNotificationsChooseAudioFile => 'Choose audio file';

  @override
  String get settingsNotificationsChooseSystemSound => 'Choose system sound';

  @override
  String get settingsNotificationsCloseToTray => 'Close to tray';

  @override
  String get settingsNotificationsCloseToTrayDescription =>
      'Hide window and keep running in system tray.';

  @override
  String get settingsNotificationsDescription =>
      'Choose which events alert you and how';

  @override
  String get settingsNotificationsDisableOptimization => 'Disable optimization';

  @override
  String get settingsNotificationsErrors => 'Errors';

  @override
  String get settingsNotificationsErrorsSubtitle =>
      'When a session reports a failure';

  @override
  String get settingsNotificationsJustClose => 'Just close';

  @override
  String get settingsNotificationsJustCloseDescription =>
      'Exit the application completely.';

  @override
  String get settingsNotificationsKeepLive => 'Keep alerts live for 3 min';

  @override
  String get settingsNotificationsKeepLiveDescription =>
      'When a response is already running, keep realtime active briefly after leaving the app.';

  @override
  String get settingsNotificationsLocal => 'Local';

  @override
  String get settingsNotificationsMinimizeWhenClose => 'Minimize when close';

  @override
  String get settingsNotificationsMinimizeWhenCloseDescription =>
      'Minimize to taskbar/dock and keep running.';

  @override
  String get settingsNotificationsNoCondition =>
      'If no condition is selected, alerts are allowed in any context.';

  @override
  String get settingsNotificationsNotify => 'Notify';

  @override
  String get settingsNotificationsNotifyOnlyWhen => 'Notify only when';

  @override
  String get settingsNotificationsOpenBatterySettings =>
      'Open battery settings';

  @override
  String get settingsNotificationsPermissions => 'Permissions and questions';

  @override
  String get settingsNotificationsPermissionsSubtitle =>
      'When tools request your input';

  @override
  String get settingsNotificationsPreview => 'Preview';

  @override
  String get settingsNotificationsRefreshStatus => 'Refresh status';

  @override
  String get settingsNotificationsSearchSoundType => 'Search sound type';

  @override
  String get settingsNotificationsSectionDescription =>
      'Control when alerts appear and when they can play sound.';

  @override
  String get settingsNotificationsSectionTitle => 'Notifications';

  @override
  String settingsNotificationsSelectedSound(String label) {
    return 'Selected: $label';
  }

  @override
  String get settingsNotificationsServer => 'Server';

  @override
  String get settingsNotificationsSound => 'Sound';

  @override
  String get settingsNotificationsSoundBuiltInAlert => 'Built-in alert';

  @override
  String get settingsNotificationsSoundBuiltInClick => 'Built-in click';

  @override
  String get settingsNotificationsSoundOff => 'Off';

  @override
  String get settingsNotificationsSoundOnlyWhen => 'Sound only when';

  @override
  String get settingsNotificationsSoundPickAudioFile => 'Pick audio file';

  @override
  String get settingsNotificationsSoundPickFromSystem => 'Pick from system';

  @override
  String get settingsNotificationsSoundSystemDefault => 'System default';

  @override
  String get settingsNotificationsSoundType => 'Sound type';

  @override
  String get settingsNotificationsSyncInfo =>
      'Some category on/off toggles are synced from /config on the active server.';

  @override
  String get settingsNotificationsSyncInfoLocal =>
      'Current server does not expose notification toggles in /config; local values are active.';

  @override
  String get settingsNotificationsSystemSoundPickerTitle =>
      'Choose system sound';

  @override
  String get settingsNotificationsTitle => 'Notifications';

  @override
  String get settingsNotificationsWhenClosing => 'When closing the window';

  @override
  String get settingsOpenCodeAutoUpdate => 'OpenCode auto-update';

  @override
  String get settingsOpenCodeSharingDefault => 'OpenCode sharing default';

  @override
  String get settingsReadAloudEnabled => 'Read aloud';

  @override
  String get settingsReadAloudEnabledDescription =>
      'Show a read-aloud button on assistant messages.';

  @override
  String get settingsReadAloudPitch => 'Pitch';

  @override
  String get settingsReadAloudPitchDescription => 'Adjust the voice pitch.';

  @override
  String get settingsReadAloudSectionDescription =>
      'Read assistant responses aloud. Configure speed, pitch, and voice.';

  @override
  String get settingsReadAloudSectionTitle => 'Text to speech';

  @override
  String get settingsReadAloudSpeed => 'Speed';

  @override
  String get settingsReadAloudSpeedDescription => 'Adjust the speaking rate.';

  @override
  String get settingsReadAloudVoice => 'Voice';

  @override
  String get settingsReadAloudVoiceHint => 'Select a voice for read-aloud.';

  @override
  String get settingsSearchAutoUpdateMode => 'Search auto-update mode';

  @override
  String get settingsSearchDefaultAgent => 'Search default agent';

  @override
  String get settingsSearchDefaultModel => 'Search default model';

  @override
  String get settingsSearchSharingMode => 'Search sharing mode';

  @override
  String get settingsSearchSmallModel => 'Search small model';

  @override
  String get settingsServersActive => 'Active';

  @override
  String get settingsServersChooseActive => 'Choose active server';

  @override
  String get settingsServersDefault => 'Default';

  @override
  String get settingsServersDescription =>
      'Connect to OpenCode and manage your servers';

  @override
  String get settingsServersTitle => 'Servers';

  @override
  String get settingsSessionAttentionSize => 'Bubble size';

  @override
  String get settingsSessionAttentionSizeExtraLarge => 'Extra large';

  @override
  String get settingsSessionAttentionSizeExtraSmall => 'Extra small';

  @override
  String get settingsSessionAttentionSizeLarge => 'Large';

  @override
  String get settingsSessionAttentionSizeSmall => 'Small';

  @override
  String get settingsSessionAttentionSizeStandard => 'Standard';

  @override
  String get settingsSetupWizard => 'Setup Wizard';

  @override
  String get settingsShortcutsDescription =>
      'Find and customize keyboard shortcuts';

  @override
  String get settingsShortcutsEdit => 'Edit shortcut';

  @override
  String get settingsShortcutsKeyboard => 'Keyboard shortcuts';

  @override
  String get settingsShortcutsReset => 'Reset shortcut';

  @override
  String get settingsShortcutsSearch => 'Search shortcuts';

  @override
  String get settingsShortcutsTitle => 'Shortcuts';

  @override
  String get settingsSmallModel => 'Small model';

  @override
  String get settingsSmallModelResetExplanation =>
      'Resetting `small_model` back to automatic fallback still requires editing config outside the app because `/config` patch updates cannot remove keys.';

  @override
  String get settingsSmallModelUnsetExplanation =>
      'OpenCode automatic fallback is active because `small_model` is unset.';

  @override
  String get settingsSoundPickerNotAvailable =>
      'System sound picker is not available on this platform.';

  @override
  String get settingsSpeechDescription =>
      'Set up voice input, offline models, and read aloud';

  @override
  String get settingsSpeechRefreshStatus => 'Refresh status';

  @override
  String settingsSpeechSilenceTimeout(String value) {
    return 'Silence timeout: ${value}s';
  }

  @override
  String get settingsSpeechTitle => 'Speech to text';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsGroupAlertTypes => 'Alert types';

  @override
  String get settingsGroupBackgroundBehavior => 'Background behavior';

  @override
  String get settingsGroupChatDisplay => 'Chat display';

  @override
  String get settingsGroupCurrentConnection => 'Current connection';

  @override
  String get settingsGroupDataAndSync => 'Data and sync';

  @override
  String get settingsGroupDataReset => 'Data and reset';

  @override
  String get settingsGroupDelivery => 'Delivery';

  @override
  String get settingsGroupHelp => 'Help';

  @override
  String get settingsGroupLanguageAndChat => 'Language and chat';

  @override
  String get settingsGroupLayoutAndText => 'Layout and text';

  @override
  String get settingsGroupOfflineModels => 'Offline models';

  @override
  String get settingsGroupOpenCodeDefaults => 'OpenCode defaults';

  @override
  String get settingsGroupReadAloud => 'Read aloud';

  @override
  String get settingsGroupSavedServers => 'Saved servers';

  @override
  String get settingsGroupThemeAndColor => 'Theme and color';

  @override
  String get settingsGroupThisDevice => 'This device';

  @override
  String get settingsGroupVersionUpdates => 'Version and updates';

  @override
  String get settingsGroupVoiceInput => 'Voice input';

  @override
  String get settingsNavigationGroupExperience => 'Experience';

  @override
  String get settingsNavigationGroupInput => 'Input';

  @override
  String get settingsNavigationGroupSetup => 'Setup';

  @override
  String get settingsNavigationGroupSupport => 'Help and diagnostics';

  @override
  String get settingsNavigationNoResults => 'No settings found';

  @override
  String get settingsNavigationSearchHint => 'Search settings';

  @override
  String get settingsUsernameClearHint =>
      'Clearing the OpenCode conversation username still requires editing config outside the app.';

  @override
  String get settingsUsernameEnterHint =>
      'Enter a username to save a custom OpenCode conversation name.';

  @override
  String get settingsUsernameResetExplanation =>
      'Resetting `username` back to the system default still requires editing config outside the app because `/config` patch updates cannot remove keys.';

  @override
  String get settingsUsernameUnsetExplanation =>
      'OpenCode uses the system username because `username` is unset.';

  @override
  String get setupDebugBun => 'Bun';

  @override
  String get setupDebugBun2 => 'Bun';

  @override
  String get setupDebugCapturedSetupDetails => 'No captured setup details yet';

  @override
  String get setupDebugCapturedSetupLogs => 'Captured setup logs';

  @override
  String get setupDebugClear => 'Clear setup debug';

  @override
  String get setupDebugClearSetupDebug => 'Clear setup debug';

  @override
  String get setupDebugCodeWalkCaptureEnough =>
      'If CodeWalk did not capture enough context, check the official OpenCode logs and health endpoints directly:';

  @override
  String get setupDebugCommandPath => 'Command path';

  @override
  String get setupDebugCommandPath2 => 'Command path';

  @override
  String get setupDebugCopy => 'Copy setup debug';

  @override
  String get setupDebugCopySetupDebug => 'Copy setup debug';

  @override
  String get setupDebugCurrentStatus => 'Current status';

  @override
  String get setupDebugDiagnosticsLoading => 'Diagnostics are still loading.';

  @override
  String get setupDebugEnvironment => 'Environment diagnostics';

  @override
  String get setupDebugEnvironmentDiagnostics => 'Environment diagnostics';

  @override
  String get setupDebugFocusedOpenCodeSetup => 'Focused on OpenCode setup';

  @override
  String get setupDebugInstallDir => 'Install directory';

  @override
  String get setupDebugInstallDirectory => 'Install directory';

  @override
  String get setupDebugLatestLocalServer => 'Latest local server output';

  @override
  String get setupDebugLogs => 'Captured setup logs';

  @override
  String get setupDebugManual => 'Manual troubleshooting';

  @override
  String get setupDebugManualTroubleshooting => 'Manual troubleshooting';

  @override
  String get setupDebugNetwork => 'Network';

  @override
  String get setupDebugNetwork2 => 'Network';

  @override
  String get setupDebugNoDetails => 'No captured setup details yet';

  @override
  String get setupDebugNode => 'Node.js';

  @override
  String get setupDebugNodeJs => 'Node.js';

  @override
  String get setupDebugNpm => 'npm';

  @override
  String get setupDebugNpm2 => 'npm';

  @override
  String get setupDebugOpenCode => 'OpenCode';

  @override
  String get setupDebugOpenCode2 => 'OpenCode';

  @override
  String get setupDebugOpenCodeSetupDebug => 'OpenCode Setup Debug';

  @override
  String get setupDebugPlatform => 'Platform';

  @override
  String get setupDebugPlatform2 => 'Platform';

  @override
  String get setupDebugRunDiagnosticsTry =>
      'Run diagnostics, try an installation method, or attempt a setup flow to capture OpenCode-specific troubleshooting details here.';

  @override
  String get setupDebugScreenCoversOpenCode =>
      'This screen only covers OpenCode installation, diagnostics, and local setup troubleshooting. Use App Logs for general CodeWalk runtime issues.';

  @override
  String get setupDebugServerOutput => 'Latest local server output';

  @override
  String get setupDebugStatus => 'Current status';

  @override
  String setupDebugTimeEntrySource(String source, String time) {
    return '$time - $source';
  }

  @override
  String get setupDebugTimeline => 'Timeline';

  @override
  String get setupDebugTimeline2 => 'Timeline';

  @override
  String get setupDebugTitle => 'Focused on OpenCode setup';

  @override
  String get setupDebugWSL => 'WSL';

  @override
  String get setupDebugWsl => 'WSL';

  @override
  String get shortcutCloseApp => 'Close tab/application';

  @override
  String get shortcutCloseAppDesc =>
      'Close the current session tab when available, otherwise close the app using platform behavior';

  @override
  String get shortcutFocusCloseDrawer => 'Focus/close drawer';

  @override
  String get shortcutFocusCloseDrawerDesc =>
      'Focus composer by default, or close drawer when open';

  @override
  String get shortcutFocusInput => 'Focus input';

  @override
  String get shortcutFocusInputDesc => 'Move focus to the prompt input';

  @override
  String get shortcutGroupApplication => 'Application';

  @override
  String get shortcutGroupGeneral => 'General';

  @override
  String get shortcutGroupModelAndAgent => 'Model and agent';

  @override
  String get shortcutGroupNavigation => 'Navigation';

  @override
  String get shortcutGroupPrompt => 'Prompt';

  @override
  String get shortcutGroupSession => 'Session';

  @override
  String get shortcutNewConversation => 'New conversation';

  @override
  String get shortcutNewConversationDesc => 'Create a new chat session';

  @override
  String get shortcutNextAgent => 'Next agent';

  @override
  String get shortcutNextAgentDesc => 'Cycle to next available agent';

  @override
  String get shortcutNextRecentModel => 'Next recent model';

  @override
  String get shortcutNextRecentModelDesc =>
      'Cycle through recently used models';

  @override
  String get shortcutNextVariant => 'Next variant';

  @override
  String get shortcutNextVariantDesc =>
      'Cycle through available model variants';

  @override
  String get shortcutOpenSettings => 'Open settings';

  @override
  String get shortcutOpenSettingsDesc => 'Open settings page';

  @override
  String get shortcutPreviousAgent => 'Previous agent';

  @override
  String get shortcutPreviousAgentDesc => 'Cycle to previous available agent';

  @override
  String get shortcutQuickOpenFiles => 'Quick open files';

  @override
  String get shortcutQuickOpenFilesDesc => 'Open file quick search';

  @override
  String get shortcutQuitApp => 'Quit application';

  @override
  String get shortcutQuitAppDesc => 'Force-exit the app';

  @override
  String get shortcutRefreshData => 'Refresh data';

  @override
  String get shortcutRefreshDataDesc => 'Refresh current chat data';

  @override
  String get shortcutStopResponse => 'Stop active response';

  @override
  String get shortcutStopResponseDesc =>
      'Stop active response (while responding)';

  @override
  String get shortcutToggleVoiceInput => 'Toggle voice input';

  @override
  String get shortcutToggleVoiceInputDesc =>
      'Start or stop speech-to-text in the composer';

  @override
  String get shortcutsApply => 'Apply';

  @override
  String shortcutsConflictConflict(String conflict) {
    return 'Conflict with $conflict';
  }

  @override
  String get shortcutsKeyboardShortcuts => 'Keyboard shortcuts';

  @override
  String get shortcutsReset => 'Reset all';

  @override
  String get shortcutsSearchEditBindings =>
      'Search, edit bindings, and resolve conflicts before saving.';

  @override
  String shortcutsSetShortcutWidget(String label) {
    return 'Set shortcut: $label';
  }

  @override
  String get shortcutsTheseBindingsStored =>
      'These bindings are stored in CodeWalk for the current app runtime and do not edit OpenCode `tui.json` keybinds.';

  @override
  String get speechAutoStopSilence => 'Auto-stop silence timeout';

  @override
  String get speechChooseRecognitionEngine =>
      'Choose the recognition engine, silence timeout, and model options.';

  @override
  String speechDesktopOnly(String service) {
    return '$service is available on desktop only.';
  }

  @override
  String get speechDownload => 'Download';

  @override
  String get speechEngine => 'Engine';

  @override
  String get speechInstalledLanguages => 'Installed languages';

  @override
  String get speechListeningStopsAutomatically =>
      'Listening stops automatically after this many seconds of silence.';

  @override
  String get speechMicPermissionDisabled =>
      'Microphone permission is disabled.';

  @override
  String speechModelFilesIncomplete(String service) {
    return '$service model files are incomplete.';
  }

  @override
  String get speechMoonshine => 'Moonshine';

  @override
  String get speechMoonshineModelsDesktop => 'Moonshine models (desktop)';

  @override
  String get speechMoonshineStaysDownloadable =>
      'Moonshine stays downloadable and out of the app bundle. Pick one model for this desktop device and remove it later if you want the space back.';

  @override
  String get speechNative => 'Native';

  @override
  String get speechNativeSTTDisabled =>
      'Native STT is disabled on Linux in this app. Parakeet is the default engine for new installs.';

  @override
  String get speechNativeSTTWorks =>
      'On Windows, CodeWalk uses local on-device speech recognition through its WASAPI microphone backend. Native Windows speech recognition is disabled for stability.';

  @override
  String get speechNativeStartsFaster =>
      'Native starts faster. Sherpa runs fully on-device with heavier setup and deeper model control.';

  @override
  String get speechOpenMicrophoneSettings => 'Open microphone settings';

  @override
  String get speechOpenSpeechPrivacy => 'Open speech privacy';

  @override
  String get speechOpenSpeechSettings => 'Open speech settings';

  @override
  String get speechParakeet => 'Parakeet';

  @override
  String get speechParakeetModelsDesktop => 'Parakeet models (desktop)';

  @override
  String get speechParakeetStaysDownloadable =>
      'Parakeet stays downloadable and out of the app bundle. It currently exposes one multilingual model optimized for 25 European languages.';

  @override
  String get speechPickLanguagePacks =>
      'Pick language packs and download/remove models for on-device recognition.';

  @override
  String get speechRemove => 'Remove';

  @override
  String speechRuntimeFailed(String service) {
    return '$service runtime failed to initialize.';
  }

  @override
  String get speechSelectSherpaAbove =>
      'Select Sherpa above to manage language packs and download models.';

  @override
  String get speechSenseVoice => 'SenseVoice';

  @override
  String get speechSenseVoiceModelsDesktop => 'SenseVoice models (desktop)';

  @override
  String get speechSenseVoiceStaysDownloadable =>
      'SenseVoice stays downloadable and out of the app bundle. It is the strongest desktop option here for Chinese, Cantonese, Japanese, Korean, and English.';

  @override
  String get speechSherpa => 'Sherpa';

  @override
  String get speechSherpaExperimentalFail =>
      'Sherpa is experimental and can fail on some devices. Prefer Native if you want the most stable behavior.';

  @override
  String get speechSherpaModelsLinux => 'Sherpa models (Linux)';

  @override
  String get speechSpeechText => 'Speech to text';

  @override
  String speechUnavailableOnPlatform(String service) {
    return '$service speech is unavailable on this platform.';
  }

  @override
  String get speechWindowsSetupHint =>
      'Windows voice input uses CodeWalk WASAPI capture with on-device models. Keep microphone access for desktop apps enabled; the buttons below open Windows settings for troubleshooting.';

  @override
  String get statusConnected => 'Connected';

  @override
  String get statusDelayed => 'Delayed';

  @override
  String get statusFailed => 'Failed';

  @override
  String get statusOffline => 'Offline';

  @override
  String get statusOnline => 'Online';

  @override
  String get statusReconnecting => 'Reconnecting';

  @override
  String get statusStarting => 'Starting';

  @override
  String get statusStopped => 'Stopped';

  @override
  String get statusStopping => 'Stopping';

  @override
  String get statusSyncDelayed => 'Sync delayed';

  @override
  String get tailscaleNoPeers => 'No peers found';

  @override
  String get tailscaleNotSupportedOnPlatform =>
      'Tailscale is not supported on this platform.';

  @override
  String get tailscaleNotSupportedOnWindows =>
      'Tailscale is not supported on Windows.';

  @override
  String get tailscalePeerOffline => 'offline';

  @override
  String get tailscaleSelectPeer => 'Select a Tailscale peer';

  @override
  String get tailscaleWaitingAdminApproval =>
      'This Tailscale node is waiting for admin approval.';

  @override
  String get terminalClose => 'Close terminal';

  @override
  String terminalConnectingTo(String serverName) {
    return 'Connecting to $serverName terminal...';
  }

  @override
  String terminalConnectionFailed(String error) {
    return 'Terminal connection failed: $error';
  }

  @override
  String get terminalDisconnected => 'Terminal disconnected.';

  @override
  String terminalEmbeddedUnavailable(String serverName) {
    return 'Embedded terminal is not available on this runtime yet. Keep using composer shell mode for one-shot commands or open the terminal from a supported CodeWalk app runtime for $serverName.';
  }

  @override
  String get terminalExtraKeyAlt => 'Alt key';

  @override
  String get terminalExtraKeyArrowDown => 'Down arrow';

  @override
  String get terminalExtraKeyArrowLeft => 'Left arrow';

  @override
  String get terminalExtraKeyArrowRight => 'Right arrow';

  @override
  String get terminalExtraKeyArrowUp => 'Up arrow';

  @override
  String get terminalExtraKeyControl => 'Control key';

  @override
  String get terminalExtraKeyEscape => 'Escape key';

  @override
  String get terminalExtraKeyTab => 'Tab key';

  @override
  String get terminalExtraKeys => 'Terminal extra keys';

  @override
  String get terminalHide => 'Hide terminal';

  @override
  String get terminalMaximize => 'Maximize';

  @override
  String get terminalMinimize => 'Minimize terminal';

  @override
  String get terminalNotAvailableYet =>
      'Embedded terminal is not available on this runtime yet.';

  @override
  String get terminalOpen => 'Open terminal';

  @override
  String get terminalOpenInfo => 'Open terminal info';

  @override
  String get terminalOpenProjectFirst =>
      'Open a project folder before starting the server terminal.';

  @override
  String get terminalOpenToConnect =>
      'Open Terminal to connect to the server project terminal.';

  @override
  String get terminalReconnect => 'Reconnect terminal';

  @override
  String get terminalRestoreSize => 'Restore size';

  @override
  String get terminalSelectServer =>
      'Select an active server before opening Terminal.';

  @override
  String get terminalSessionClosed => 'Terminal session closed.';

  @override
  String get terminalTerminal => 'Terminal';

  @override
  String get terminalTitle => 'Terminal';

  @override
  String get terminalTryAgain => 'Try again';

  @override
  String get toolAwaitingInput => 'Awaiting input';

  @override
  String get toolEditing => 'Editing';

  @override
  String get toolEditingFiles => 'Editing files';

  @override
  String get toolFinding => 'Finding';

  @override
  String get toolFindingFiles => 'Finding files';

  @override
  String get toolPresentationAwaitingInput => 'Awaiting input';

  @override
  String get toolPresentationEditing => 'Editing';

  @override
  String get toolPresentationEditingFiles => 'Editing files';

  @override
  String get toolPresentationFinding => 'Finding';

  @override
  String get toolPresentationFindingFiles => 'Finding files';

  @override
  String get toolPresentationReading => 'Reading';

  @override
  String get toolPresentationReadingFile => 'Reading file';

  @override
  String get toolPresentationRunning => 'Running';

  @override
  String get toolPresentationRunningCommand => 'Running command';

  @override
  String toolPresentationRunningTool(String toolName) {
    return 'Running $toolName';
  }

  @override
  String get toolPresentationSearching => 'Searching';

  @override
  String get toolPresentationSearchingCode => 'Searching code';

  @override
  String get toolPresentationSearchingWeb => 'Searching the web';

  @override
  String get toolPresentationTool => 'Tool';

  @override
  String get toolPresentationUpdatingTaskList => 'Updating task list';

  @override
  String get toolPresentationUpdatingTasks => 'Updating tasks';

  @override
  String get toolPresentationWaitingInput => 'Waiting for your input';

  @override
  String get toolPresentationWriting => 'Writing';

  @override
  String get toolPresentationWritingFile => 'Writing file';

  @override
  String get toolReading => 'Reading';

  @override
  String get toolReadingFile => 'Reading file';

  @override
  String get toolRunning => 'Running';

  @override
  String get toolRunningCommand => 'Running command';

  @override
  String get toolRunningTask => 'Running task';

  @override
  String get toolSearching => 'Searching';

  @override
  String get toolSearchingCode => 'Searching code';

  @override
  String get toolSearchingWeb => 'Searching the web';

  @override
  String get toolUpdatingTaskList => 'Updating task list';

  @override
  String get toolUpdatingTasks => 'Updating tasks';

  @override
  String get toolWaitingForInput => 'Waiting for your input';

  @override
  String get toolWriting => 'Writing';

  @override
  String get toolWritingFile => 'Writing file';

  @override
  String get tourBack => 'Back';

  @override
  String get tourSkip => 'Skip';

  @override
  String get trayQuit => 'Quit';

  @override
  String get trayShow => 'Show';

  @override
  String get useOAuthCloudflareAccess => 'Use OAuth (Cloudflare Access)';

  @override
  String get useOAuthCloudflareAccessSubtitle =>
      'Opens a browser for Cloudflare Access Managed OAuth.';

  @override
  String get useOAuthCloudflareAccessUnsupported =>
      'Cloudflare Access OAuth is not available on this platform. Use Basic Auth instead.';

  @override
  String get useTailscale => 'Use Tailscale';

  @override
  String get useTailscaleSubtitle =>
      'Routes traffic through the Tailscale network without a system VPN.';

  @override
  String get useTailscaleUnsupported =>
      'Tailscale is not supported on this platform.';

  @override
  String get utilityTitle => 'Utility';

  @override
  String get workspaceBrowseDirs => 'Browse directories';

  @override
  String get workspaceChooseFolderOpen =>
      'Choose any folder to open as project context.';

  @override
  String workspaceCloseProject(String project) {
    return 'Close $project';
  }

  @override
  String get workspaceClosedProjects => 'Closed projects';

  @override
  String workspaceCurrentDirectory(String path) {
    return 'Current directory: $path';
  }

  @override
  String get workspaceFilterDirs => 'Filter directories';

  @override
  String get workspaceOpenFolder => 'Open folder';

  @override
  String get workspaceOpenProjectFolder => 'Open project folder';

  @override
  String get workspaceOpenProjects => 'Open projects';

  @override
  String get workspaceProjectDirectory => 'Project directory';

  @override
  String get workspaceProjectHint => '/repo/my-project';

  @override
  String workspaceRemoveFromHistory(String name) {
    return 'Remove $name from history';
  }

  @override
  String get settingsSessionAttentionTitle => 'Session attention';

  @override
  String get settingsSessionAttentionDescription =>
      'Show root-session status in an opt-in bubble or panel.';

  @override
  String get settingsSessionAttentionOff => 'Off';

  @override
  String get settingsSessionAttentionBubble => 'Bubble';

  @override
  String get settingsSessionAttentionPanel => 'Panel';

  @override
  String get settingsSessionAttentionPrivacy =>
      'On Android, enabling this starts a persistent foreground service. Response text is stored encrypted; cloud TTS sends text only after you press Read.';

  @override
  String get settingsSessionAttentionUnavailable =>
      'Session attention is unavailable on this platform.';

  @override
  String get settingsSessionAttentionOpenSettings => 'Open display settings';

  @override
  String get settingsSessionAttentionStop => 'Stop session attention';

  @override
  String get settingsSessionAttentionThirdPartyTtsWarning =>
      'When you press Read, response text may be sent to the configured third-party TTS provider.';

  @override
  String get workspaceSuggestions => 'Suggestions';

  @override
  String get sessionTabsGestureHintTitle => 'Session tabs have new controls';

  @override
  String get sessionTabsGestureHintBody =>
      'Double-click or double-tap a tab to close it. Right-click or touch and hold to open session actions. You can disable tabs in Display Toggles.';

  @override
  String get sessionTabsGestureHintAcknowledge => 'Got it';

  @override
  String get sessionTabsGestureHintDisableTabs => 'Disable tabs';

  @override
  String get sessionTabRenameAction => 'Rename session';

  @override
  String sessionTabClosedMessage(String title) {
    return 'Tab \"$title\" closed';
  }

  @override
  String get sessionTabUndo => 'Undo';

  @override
  String get sessionTabRestoreFailed => 'Tab could not be restored.';

  @override
  String get sessionTabChangeIconAction => 'Change icon';

  @override
  String get sessionTabIconPickerTitle => 'Choose tab icon';

  @override
  String get sessionTabIconUseProjectIcon => 'Use project icon';

  @override
  String get sessionTabIconApplied => 'Tab icon updated.';

  @override
  String get sessionTabIconSaveFailed => 'Tab icon could not be saved.';

  @override
  String get sessionTabIconPresetCode => 'Code';

  @override
  String get sessionTabIconPresetTerminal => 'Terminal';

  @override
  String get sessionTabIconPresetBug => 'Bug';

  @override
  String get sessionTabIconPresetTasks => 'Tasks';

  @override
  String get sessionTabIconPresetLaunch => 'Launch';

  @override
  String get sessionTabIconPresetIdea => 'Idea';

  @override
  String get sessionTabIconPresetResearch => 'Research';

  @override
  String get sessionTabIconPresetDesign => 'Design';

  @override
  String get sessionTabIconPresetData => 'Data';

  @override
  String get sessionTabIconPresetCloud => 'Cloud';

  @override
  String get sessionTabIconPresetSecurity => 'Security';

  @override
  String get sessionTabIconPresetTools => 'Tools';

  @override
  String get workspaceNoActiveContext => 'No active context';

  @override
  String get settingsAppearanceContrastLow => 'Low';

  @override
  String get settingsAppearanceContrastStandard => 'Standard';

  @override
  String get settingsAppearanceContrastMedium => 'Medium';

  @override
  String get settingsAppearanceContrastMediumHigh => 'Medium High';

  @override
  String get settingsNotificationsSystemSoundsWebUnavailable =>
      'Not available on web.';

  @override
  String get settingsNotificationsSystemSoundsAndroid =>
      'Android notification sounds from the system.';

  @override
  String get settingsNotificationsSystemSoundsFreedesktop =>
      'Freedesktop sounds from /usr/share/sounds/freedesktop/stereo.';

  @override
  String get settingsNotificationsSystemSoundsPlatform =>
      'Supported where the operating system exposes system sounds.';

  @override
  String get serversQuickGuideTitle => 'Quick setup';

  @override
  String get serversQuickGuideIntro =>
      'CodeWalk is the app. OpenCode is the engine that needs to be running before this connection can work.';

  @override
  String get serversQuickGuideStepInstallCli => '1. Install OpenCode CLI.';

  @override
  String get serversQuickGuideRunPowerShell => '2. Run in PowerShell:';

  @override
  String get serversQuickGuideRunTerminal => '2. Run in your terminal:';

  @override
  String get serversQuickGuideProtectPassword => 'Protect access with password';

  @override
  String get serversQuickGuideServerPassword => 'Server password';

  @override
  String get serversQuickGuideInstallOptions =>
      'Other official install options: install script, npm, bun, pnpm, Homebrew, or a binary from GitHub Releases.';

  @override
  String get serversQuickGuideVerifyHint =>
      'After starting the server, confirm /global/health or /doc responds before pasting the URL into CodeWalk.';

  @override
  String get shortcutsPressKeyCombination => 'Press the key combination now';

  @override
  String get settingsProvenanceOpenCodeBacked => 'OpenCode-backed';

  @override
  String get settingsProvenanceCodeWalkLocal => 'CodeWalk-local';

  @override
  String get settingsProvenanceCodeWalkException => 'CodeWalk exception';

  @override
  String get shortcutsErrorInvalid => 'Invalid shortcut';

  @override
  String get shortcutsErrorUnsupportedKey => 'Unsupported shortcut key';

  @override
  String shortcutsErrorConflict(String conflict) {
    return 'Conflicts with \"$conflict\"';
  }

  @override
  String get settingsSessionAttentionStopSaveFailed =>
      'Session attention was stopped but the setting could not be saved.';

  @override
  String get settingsSessionAttentionEnableFailed =>
      'Session attention could not be enabled.';

  @override
  String get settingsSessionAttentionSaveFailedStopped =>
      'Session attention could not be saved and was stopped.';

  @override
  String get settingsSessionAttentionStillRunning =>
      'Session attention is still running. Try stopping it again.';

  @override
  String get settingsSessionAttentionStopFailed =>
      'Session attention could not be stopped. Try again.';

  @override
  String get settingsSessionAttentionCapabilityUnavailable =>
      'Session attention host capability is unavailable.';

  @override
  String get settingsServerFallbackProviderName => 'Configured on server';

  @override
  String get composerStopResponse => 'Stop response';

  @override
  String get composerSendMessageWhileResponding =>
      'Send message while response is running';

  @override
  String get composerSendMessage => 'Send message';

  @override
  String get chatTourComposerDescription => 'Type your request here.';

  @override
  String get chatTourSendDescription => 'Send your message here.';

  @override
  String get composerAttachmentFallbackName => 'Attachment';

  @override
  String get composerContextFallbackName => 'Context';

  @override
  String get searchableDropdownSearchHint => 'Search';

  @override
  String get searchableDropdownEmptyText => 'No matches found';

  @override
  String get speechApiKeyStorageUnavailable =>
      'Secure TTS API key storage is unavailable.';

  @override
  String get speechApiKeyRemoved => 'API key removed.';

  @override
  String get speechApiKeySaved => 'API key saved securely on this device.';

  @override
  String get speechReadAloudTestText =>
      'This is a CodeWalk text-to-speech test.';

  @override
  String get speechNativeDisabledWindows =>
      'Disabled on Windows for stability. Use Parakeet or another on-device engine through CodeWalk WASAPI capture.';

  @override
  String get speechNativeUnavailableLinux =>
      'Unavailable on Linux. Use Parakeet for speech input.';

  @override
  String get speechNotAvailableOnPlatform => 'Not available on this platform.';

  @override
  String get speechSherpaUnavailableAndroid =>
      'Unavailable on Android builds optimized for small APK size.';

  @override
  String get speechMoonshineDesktopOnlyHint =>
      'Available on desktop only. Android stays native-only.';

  @override
  String get speechParakeetDesktopOnlyHint =>
      'Available on desktop only. Uses offline multilingual recognition.';

  @override
  String get speechSenseVoiceDesktopOnlyHint =>
      'Available on desktop only. Strongest for Chinese, Cantonese, Japanese, Korean, and English.';

  @override
  String get speechNativeSubtitle => 'Simpler and faster startup.';

  @override
  String get speechSherpaSubtitle =>
      'Heavier, experimental, and bug-prone. Often more precise with downloaded models.';

  @override
  String get speechMoonshineSubtitle =>
      'Desktop-only experimental path using sherpa_onnx offline recognition and downloadable models.';

  @override
  String get speechParakeetSubtitle =>
      'Desktop-only offline NeMo transducer path with one multilingual downloadable model.';

  @override
  String get speechSenseVoiceSubtitle =>
      'Desktop-only offline path tuned for Chinese, Cantonese, Japanese, Korean, and English.';

  @override
  String get speechMoonshineModel => 'Moonshine model';

  @override
  String get speechSherpaLanguage => 'Sherpa language';

  @override
  String get speechSearchSherpaLanguage => 'Search Sherpa language';

  @override
  String get speechNoLanguagePacksFound => 'No language packs found';

  @override
  String get speechTextToSpeechProvider => 'Text-to-speech provider';

  @override
  String get speechProviderSystemNative => 'System / Native';

  @override
  String get speechProviderEdgeExperimental =>
      'Microsoft Edge Speech (experimental)';

  @override
  String get speechProviderOpenAiCompatible => 'OpenAI-compatible';

  @override
  String get speechEdgeExperimentalTitle =>
      'Microsoft Edge Speech is experimental';

  @override
  String get speechEdgeExperimentalDescription =>
      'Uses the unofficial Edge Read Aloud service directly from this device. Message text is sent to Microsoft when you use read aloud, and the service may break if Microsoft changes the private protocol.';

  @override
  String get speechEdgeVoice => 'Edge voice';

  @override
  String get speechEdgeVoiceListUnavailable =>
      'Using the default Edge voice. Voice list could not be loaded right now.';

  @override
  String get speechEdgeVoicesLoaded =>
      'Loaded from Microsoft Edge Speech voices.';

  @override
  String get speechCloudTtsPrivacy => 'Cloud TTS privacy';

  @override
  String get speechCloudTtsPrivacyDescription =>
      'Cloud TTS sends the selected assistant message text to the configured provider. API keys are stored in secure storage on this device.';

  @override
  String get speechBaseUrl => 'Base URL';

  @override
  String get speechApiKey => 'API key';

  @override
  String get speechApiKeySavedHelper =>
      'A key is saved. Enter a new value to replace it, or save an empty value to remove it.';

  @override
  String get speechNoApiKeySaved => 'No API key saved.';

  @override
  String get speechSaveApiKey => 'Save API key';

  @override
  String get speechModel => 'Model';

  @override
  String get speechPitchNotSupported =>
      'Pitch is not supported by OpenAI-compatible TTS and is hidden for this provider.';

  @override
  String get speechTestVoice => 'Test voice';

  @override
  String get dialogMoonshineVoiceSetupDescription =>
      'Moonshine runs on-device through sherpa_onnx. Pick a model once and download it only for this desktop device.';

  @override
  String get dialogParakeetVoiceSetupDescription =>
      'Parakeet runs on-device through sherpa_onnx offline recognition. Download it once for this desktop device to enable multilingual STT.';

  @override
  String get dialogSenseVoiceSetupDescription =>
      'SenseVoice runs on-device through sherpa_onnx offline recognition. It is strongest for Chinese, Cantonese, Japanese, Korean, and English.';

  @override
  String get dialogSherpaVoiceSetupDescription =>
      'Sherpa voice input requires an on-device speech model. Select your language and download it once (~147 MB).';

  @override
  String speechSilenceSeconds(String value) {
    return '$value seconds';
  }

  @override
  String speechModelInstalled(String modelId) {
    return 'Model installed ($modelId)';
  }

  @override
  String speechModelMissing(String modelId) {
    return 'Model missing ($modelId)';
  }

  @override
  String speechModelSizeMb(String sizeMb) {
    return '~$sizeMb MB';
  }

  @override
  String speechSystemDefaultLanguage(String language) {
    return 'System default ($language)';
  }

  @override
  String speechModelListLoadFailed(String error, String service) {
    return 'Failed to load $service model list: $error';
  }

  @override
  String speechDownloadFailed(String error) {
    return 'Download failed: $error';
  }

  @override
  String speechFailedToRemoveModel(String error) {
    return 'Failed to remove model: $error';
  }

  @override
  String speechBaseUrlExample(String url) {
    return 'Example: $url';
  }

  @override
  String speechModelDefaultHelper(String model) {
    return 'Default: $model';
  }

  @override
  String get notificationPermissionOrQuestionNeedsInput =>
      'A tool permission or question needs your input.';

  @override
  String get notificationPermissionNeedsInput =>
      'A tool permission needs your input.';

  @override
  String get notificationQuestionNeedsInput =>
      'A tool question needs your input.';

  @override
  String get notificationSessionError => 'A session reported an error.';

  @override
  String get notificationChannelErrors => 'CodeWalk errors';

  @override
  String get notificationChannelErrorsDescription => 'CodeWalk error alerts';

  @override
  String get notificationChannelPermissions => 'CodeWalk permissions';

  @override
  String get notificationChannelPermissionsDescription =>
      'CodeWalk action required alerts';

  @override
  String get notificationChannelAgent => 'CodeWalk agent';

  @override
  String get notificationChannelAgentDescription =>
      'CodeWalk agent completion alerts';

  @override
  String get notificationActionOpen => 'Open';

  @override
  String get foregroundMonitorNotificationBody =>
      'Reliable background alerts are active';

  @override
  String get foregroundMonitorNotificationTitle =>
      'Background monitoring active';

  @override
  String get foregroundMonitorNotificationOneSession =>
      'Monitoring one session';

  @override
  String foregroundMonitorNotificationSessionCount(int count) {
    return 'Monitoring $count sessions';
  }

  @override
  String sessionAttentionSemanticLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sessions need attention',
      one: '1 session needs attention',
    );
    return '$_temp0';
  }

  @override
  String get sessionAttentionOverlayPermissionRequired =>
      'Display-over-other-apps permission is required.';

  @override
  String get sessionAttentionIosInAppOnly =>
      'Session attention is available only inside CodeWalk.';

  @override
  String get sessionAttentionOverlayPermissionGrantPrompt =>
      'Grant display-over-other-apps permission, then try again.';

  @override
  String get sessionAttentionAndroidStartFailed =>
      'The Android session attention service could not start.';

  @override
  String chatMessageTruncatedChars(int count, String reason) {
    return '[truncated $count chars] $reason';
  }

  @override
  String get chatMessageJustNow => 'Just now';

  @override
  String chatMessageMinutesAgo(int count) {
    return '${count}m ago';
  }

  @override
  String chatMessageHoursAgo(int count) {
    return '${count}h ago';
  }

  @override
  String chatMessageDaysAgo(int count) {
    return '${count}d ago';
  }

  @override
  String chatMessageDateTime(int day, int hour, int minute, int month) {
    return '$month/$day $hour:$minute';
  }

  @override
  String get chatMessageYourMessage => 'Your message';

  @override
  String get chatMessageAssistantMessage => 'Assistant message';

  @override
  String chatMessageStepStarted(int step) {
    return 'Step started #$step';
  }

  @override
  String chatMessageStepStartedWithSnapshot(String snapshot, int step) {
    return 'Step started #$step: $snapshot';
  }

  @override
  String chatMessageStepFinished(
    String cost,
    String reason,
    int step,
    int tokens,
  ) {
    return 'Step finished #$step: $reason • tokens $tokens • \$$cost';
  }

  @override
  String chatMessagePatchCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count patches',
      one: '1 patch',
    );
    return '$_temp0';
  }

  @override
  String get chatMessageToolRun => 'Tool run';

  @override
  String get chatMessageToolExecution => 'Tool execution';

  @override
  String chatMessageToolChainMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count more',
      one: '+1 more',
    );
    return '$_temp0';
  }

  @override
  String chatMessageToolChainExtraTypes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count types',
      one: '+1 type',
    );
    return '$_temp0';
  }

  @override
  String chatMessageToolAttentionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count need attention',
      one: '1 needs attention',
    );
    return '$_temp0';
  }

  @override
  String chatMessageToolDoneCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count done',
      one: '1 done',
    );
    return '$_temp0';
  }

  @override
  String get chatMessageToolCallsTitle => 'Tool calls';

  @override
  String get chatMessageDiffPreviewTruncated =>
      'Diff preview truncated for app stability.';

  @override
  String get chatMessageLargeMessageTruncated =>
      'Large message preview truncated for app stability.';

  @override
  String get chatMessageInvalidLinkFormat => 'Invalid link format';

  @override
  String get chatMessageUnableToOpenLink => 'Unable to open link';

  @override
  String sessionTodoInProgressCompact(int current, int total) {
    return '$current/$total in progress';
  }

  @override
  String sessionTodoTaskProgress(String content, int index, int total) {
    return 'Task $index/$total $content';
  }

  @override
  String sessionTodoDoneCompact(int count, int total) {
    return '$count/$total done';
  }

  @override
  String sessionTodoCompletedCount(int count, int total) {
    return 'Tasks $count/$total completed';
  }

  @override
  String sessionTodoTasksCount(int count) {
    return 'Tasks ($count)';
  }

  @override
  String questionStepOfReview(int current, int total) {
    return 'Step $current of $total - Review';
  }

  @override
  String questionStepOfQuestion(int current, int total) {
    return 'Step $current of $total - Question';
  }

  @override
  String get questionCustomAnswer => 'Custom answer';

  @override
  String get questionSubmitAnswers => 'Submit Answers';

  @override
  String get questionReviewAnswers => 'Review Answers';

  @override
  String permissionRequestTitle(String permission) {
    return 'Permission request: $permission';
  }

  @override
  String get sessionTitleCannotBeEmpty => 'Title cannot be empty';

  @override
  String get filesFailedToLoad => 'Failed to load files';

  @override
  String get filesFailedToSearch => 'Failed to search files';

  @override
  String get filesNoOpenFilesHint => 'No open files yet. Type to search.';

  @override
  String get filesNoContentMatches => 'No content matches found';

  @override
  String filesOpenFilesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count open files',
      one: '1 open file',
    );
    return '$_temp0';
  }

  @override
  String filesLinesSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lines selected',
      one: '1 line selected',
    );
    return '$_temp0';
  }

  @override
  String get filesDraftTooLargeToSave =>
      'Draft is too large to save from the editor.';

  @override
  String get filesSaveChangesBeforeClose =>
      'Save changes before closing this file.';

  @override
  String get filesSaveChangesBeforePathChange =>
      'Save changes before changing this path.';

  @override
  String get filesWaitForSaveBeforePathChange =>
      'Wait for the file save to finish before changing this path.';

  @override
  String get filesWaitForFileOperation =>
      'Wait for the file operation to finish.';

  @override
  String get filesLargeFileReadOnly =>
      'Large files open read-only to keep editing responsive.';

  @override
  String get filesCheckingWriteSupport => 'Checking file write support...';

  @override
  String get filesActiveProjectRequired =>
      'File operations require an active project directory.';

  @override
  String get filesReloadSkippedUnsavedChanges =>
      'Unsaved changes; reload skipped.';

  @override
  String get filesFailedToLoadContent => 'Failed to load file content';

  @override
  String get filesFileSaved => 'File saved.';

  @override
  String get filesParentNotDirectory => 'Parent is not a directory.';

  @override
  String get filesMalformedResponse =>
      'File operation returned an invalid response.';

  @override
  String get filesShellCommandDidNotComplete =>
      'File operation shell command did not complete.';

  @override
  String get filesShellCommandNoResult =>
      'File operation shell command returned no result.';

  @override
  String get filesShellCommandTruncated =>
      'File operation shell command was truncated by the server.';

  @override
  String get filesShellCommandSyntaxError =>
      'File operation shell command failed with a syntax error.';

  @override
  String get filesShellUtilityNotFound =>
      'A required shell utility was not found.';

  @override
  String get filesShellCommandFailed =>
      'File operation shell command failed before returning a result.';

  @override
  String get attachmentSaveTitle => 'Save attachment';

  @override
  String get attachmentBrowserSandboxLocalFile =>
      'Browser sandbox prevents opening local file:// attachments directly.';

  @override
  String get attachmentLocalPathBrowserBlocked =>
      'This attachment points to a local path that cannot be opened from the browser.';

  @override
  String terminalConnectedTo(String directory, String serverName) {
    return 'Connected to $serverName in $directory';
  }

  @override
  String get terminalTransportUnavailable =>
      'Terminal transport is unavailable.';

  @override
  String get chatSlashCommandNew => 'Create a new chat session';

  @override
  String get chatSlashCommandModels => 'Open model selector';

  @override
  String get chatSlashCommandSessions => 'Open conversations list';

  @override
  String get chatSlashCommandAgent => 'Open agent selector';

  @override
  String get chatSlashCommandOpen => 'File open quick action';

  @override
  String get chatSlashCommandHelp => 'Show command help';

  @override
  String get chatSlashCommandCompact => 'Compact current session context';

  @override
  String get chatSlashCommandThinking => 'Toggle thinking bubbles';

  @override
  String get chatSlashCommandUndo => 'Undo the last visible user turn';

  @override
  String get chatSlashCommandRedo => 'Redo the last undone turn';

  @override
  String chatSessionSubConversationCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sub-conversations',
      one: '1 sub-conversation',
    );
    return '$_temp0';
  }

  @override
  String chatMessageWeeksAgo(int count) {
    return '${count}w ago';
  }

  @override
  String chatMessageShortDate(int day, int month) {
    return '$month/$day';
  }

  @override
  String get chatProviderErrorLoadSessionStatus =>
      'Failed to load session status';

  @override
  String get chatProviderErrorLoadSessionDetails =>
      'Some session details could not be loaded';

  @override
  String chatProviderErrorLoadSessionList(String error) {
    return 'Failed to load session list: $error';
  }

  @override
  String get chatProviderErrorCreateSession => 'Failed to create session';

  @override
  String get chatProviderErrorSelectProviderModelBeforeSend =>
      'Select a connected provider or free OpenCode model before sending';

  @override
  String get chatProviderErrorStartMessageSend =>
      'Failed to start message send';

  @override
  String get chatProviderErrorStopUnavailable =>
      'Stop is unavailable for the current session';

  @override
  String get chatProviderErrorWaitForResponseFinish =>
      'Wait for the current response to finish before compacting';

  @override
  String get chatProviderErrorCompactUnavailable =>
      'Compact context is unavailable for the current session';

  @override
  String get chatProviderErrorSelectModelBeforeCompact =>
      'Select a model before compacting context';

  @override
  String get chatProviderErrorCompactSessionContext =>
      'Failed to compact session context';

  @override
  String get chatProviderErrorNetwork =>
      'Network connection failed. Please check network settings';

  @override
  String get chatProviderErrorServer => 'Server error. Please try again later';

  @override
  String get chatProviderErrorNotFound => 'Resource not found';

  @override
  String get chatProviderErrorInvalidInput => 'Invalid input parameters';

  @override
  String get chatProviderErrorUnknown =>
      'Unknown error. Please try again later';

  @override
  String get chatProviderErrorSessionFallback => 'Session error';

  @override
  String get projectProviderErrorNoProjectContext =>
      'No project context available from server';

  @override
  String projectProviderErrorInitializeFailed(String error) {
    return 'Failed to initialize project context: $error';
  }

  @override
  String get projectProviderErrorSwitchProjectNotFound =>
      'Failed to switch project: project not found';

  @override
  String get projectProviderErrorSwitchDirectoryEmpty =>
      'Failed to switch project: directory is empty';

  @override
  String get projectProviderErrorAtLeastOneContext =>
      'At least one context must remain open';

  @override
  String get projectProviderErrorReopenProjectNotFound =>
      'Failed to reopen project: project not found';

  @override
  String get projectProviderErrorOnlyClosedArchivable =>
      'Only closed projects can be archived';

  @override
  String get projectProviderErrorArchiveProjectNotFound =>
      'Failed to archive project: project not found';

  @override
  String get projectProviderErrorArchiveProjectPathInvalid =>
      'Failed to archive project: project path is invalid';

  @override
  String projectProviderErrorLoadWorkspaces(String error) {
    return 'Failed to load workspaces: $error';
  }

  @override
  String get projectProviderErrorWorkspaceNameEmpty =>
      'Workspace name cannot be empty';

  @override
  String projectProviderErrorCreateWorkspace(String error) {
    return 'Failed to create workspace: $error';
  }

  @override
  String projectProviderErrorResetWorkspace(String error) {
    return 'Failed to reset workspace: $error';
  }

  @override
  String projectProviderErrorDeleteWorkspace(String error) {
    return 'Failed to delete workspace: $error';
  }

  @override
  String get projectProviderErrorDirectoryEmpty => 'Directory cannot be empty';

  @override
  String projectProviderErrorListDirectories(String error) {
    return 'Failed to list directories: $error';
  }

  @override
  String projectProviderErrorValidateDirectory(String error) {
    return 'Failed to validate directory: $error';
  }

  @override
  String get projectProviderErrorPathEmpty => 'Path cannot be empty';

  @override
  String projectProviderErrorListFiles(String error) {
    return 'Failed to list files: $error';
  }

  @override
  String projectProviderErrorSearchFiles(String error) {
    return 'Failed to search files: $error';
  }

  @override
  String projectProviderErrorContentSearchUnavailable(String error) {
    return 'Content search not available: $error';
  }

  @override
  String projectProviderErrorSearchSymbols(String error) {
    return 'Failed to search symbols: $error';
  }

  @override
  String projectProviderErrorReadFile(String error) {
    return 'Failed to read file: $error';
  }

  @override
  String projectProviderErrorLoadProjectList(String error) {
    return 'Failed to load project list: $error';
  }

  @override
  String get workspaceProjectRemovedFromHistory =>
      'Project removed from history';

  @override
  String workspaceProjectContextOpened(String directory) {
    return 'Project context opened: $directory';
  }

  @override
  String workspaceFailedToOpenProjectContext(String directory) {
    return 'Failed to open project context: $directory';
  }

  @override
  String get chatAbortNotice => 'What you want to do different?';

  @override
  String sessionTitleToday(String date, String time) {
    return 'Today $time ($date)';
  }

  @override
  String sessionTitleYesterday(String date, String time) {
    return 'Yesterday $time ($date)';
  }

  @override
  String sessionTitleWeekday(String date, String time, String weekday) {
    return '$weekday $time ($date)';
  }

  @override
  String sessionTitleDateAndTime(String date, String time) {
    return '$date $time';
  }

  @override
  String get sessionWeekdayMon => 'Mon';

  @override
  String get sessionWeekdayTue => 'Tue';

  @override
  String get sessionWeekdayWed => 'Wed';

  @override
  String get sessionWeekdayThu => 'Thu';

  @override
  String get sessionWeekdayFri => 'Fri';

  @override
  String get sessionWeekdaySat => 'Sat';

  @override
  String get sessionWeekdaySun => 'Sun';

  @override
  String get forwardTimeNow => 'now';

  @override
  String forwardTimeMinutes(int count) {
    return '${count}m';
  }

  @override
  String forwardTimeHours(int count) {
    return '${count}h';
  }

  @override
  String forwardTimeDays(int count) {
    return '${count}d';
  }

  @override
  String forwardTimeWeeks(int count) {
    return '${count}w';
  }

  @override
  String get settingsBehaviorConfigFieldDefaultModel => 'default model';

  @override
  String get settingsBehaviorConfigFieldDefaultAgent => 'default agent';

  @override
  String get settingsBehaviorConfigFieldSmallModel => 'small model';

  @override
  String get settingsBehaviorConfigFieldAutoUpdateMode => 'auto-update mode';

  @override
  String get settingsBehaviorConfigFieldSnapshotSetting => 'snapshot setting';

  @override
  String get settingsBehaviorConfigFieldConversationUsername =>
      'conversation username';

  @override
  String get settingsBehaviorConfigFieldSharingDefault => 'sharing default';

  @override
  String get speechMicNoInputDevice =>
      'No microphone input device is available.';

  @override
  String get speechMicDeviceBusy =>
      'The default microphone is currently in use by another app.';

  @override
  String get speechMicUnsupportedFormat =>
      'The default microphone format is not supported.';

  @override
  String get speechMicSpeechPrivacy =>
      'Windows speech services may be disabled (speech privacy, online speech recognition, or language packs).';

  @override
  String get speechMicBackendUnavailable =>
      'The Windows microphone backend is not available in this build.';

  @override
  String speechEngineFallbackNotice(String fallback, String reason) {
    return 'Selected STT engine unavailable ($reason). Using $fallback instead.';
  }

  @override
  String get oauthFlowSecureStorageUnavailable =>
      'Secure credential storage is unavailable for OAuth.';

  @override
  String get oauthFlowUnexpectedError =>
      'OAuth flow failed unexpectedly. Please try again.';

  @override
  String get oauthFlowNoEndpointsDiscovered =>
      'No OAuth endpoints discovered. Enable Managed OAuth in Cloudflare Dashboard → Access → Applications → [this app].';

  @override
  String get oauthFlowTokenResponseMissingAccessToken =>
      'OAuth token response did not include an access token.';

  @override
  String get oauthFlowProfileChanged =>
      'The server profile changed before OAuth could finish.';

  @override
  String get oauthFlowMetadataMissingEndpoints =>
      'OAuth metadata is missing authorization/token endpoints.';

  @override
  String get oauthFlowCallbackNotCompleted =>
      'Authorization callback was not completed';

  @override
  String get oauthFlowProviderDeclined =>
      'The authorization server declined the OAuth request. Please try again.';

  @override
  String get oauthFlowCallbackValidationFailed =>
      'OAuth callback validation failed. Please try again.';

  @override
  String get oauthFlowCallbackServerStartFailed =>
      'Local OAuth callback server failed to start.';

  @override
  String get oauthFlowSignInCanceled => 'OAuth sign-in was canceled.';

  @override
  String get oauthFlowBrowserOpenFailed =>
      'Could not open the system browser for OAuth sign-in.';

  @override
  String get oauthFlowCallbackTimeout =>
      'No authorization callback reached the app within 5 minutes. The browser was expected to redirect to the local callback address after consent. If the browser showed a connection error instead, this device or network blocks loopback redirects.';

  @override
  String oauthFlowTokenExchangeTransientFailure(int maxAttempts) {
    return 'Token exchange failed after $maxAttempts attempts because of a temporary network problem. Please try again.';
  }

  @override
  String oauthFlowTokenExchangeHttpFailure(int statusCode) {
    return 'Token exchange failed (HTTP $statusCode). Please try again.';
  }

  @override
  String get oauthFlowTokenExchangeUnexpectedFailure =>
      'Token exchange failed unexpectedly. Please try again.';

  @override
  String get oauthFlowTokenExchangeIncomplete =>
      'Token exchange did not complete after the authorization code was sent. Please start OAuth sign-in again.';

  @override
  String get speechReadAloudFailed => 'Text-to-speech failed.';

  @override
  String get speechReadAloudNoText => 'There is no text to read aloud.';

  @override
  String get speechEdgeTextTooLong =>
      'Microsoft Edge Speech can read up to 4096 bytes at a time.';

  @override
  String get speechEdgeMalformedAudio =>
      'Microsoft Edge Speech returned malformed audio data.';

  @override
  String get speechEdgeUnsupportedAudio =>
      'Microsoft Edge Speech returned unsupported audio data.';

  @override
  String get speechEdgeUnsupportedFrame =>
      'Microsoft Edge Speech returned an unsupported websocket frame.';

  @override
  String get speechEdgeSynthesisInterrupted =>
      'Microsoft Edge Speech ended before synthesis completed.';

  @override
  String get speechEdgeEmptyAudio =>
      'Microsoft Edge Speech returned an empty audio response.';

  @override
  String get speechEdgeTimedOut => 'Microsoft Edge Speech timed out.';

  @override
  String get speechEdgeUnreachable =>
      'Microsoft Edge Speech could not be reached.';

  @override
  String get speechApiKeyMissing =>
      'Add an API key in Settings > Speech to use this TTS provider.';

  @override
  String get speechProviderEmptyAudio =>
      'The TTS provider returned an empty audio response.';

  @override
  String get speechProviderRequestRejected =>
      'The TTS provider rejected the speech request.';

  @override
  String get speechApiKeyRejected =>
      'The TTS API key was rejected by the provider.';

  @override
  String get speechProviderQuotaRateLimit =>
      'The TTS provider reported a quota or rate limit.';

  @override
  String get speechProviderTemporarilyUnavailable =>
      'The TTS provider is temporarily unavailable.';

  @override
  String get speechProviderUnreachable =>
      'The TTS provider could not be reached.';

  @override
  String appProviderErrorFailedToStartProcess(String tool) {
    return 'Failed to start $tool process.';
  }

  @override
  String appProviderErrorToolNotAvailable(String runtime, String tool) {
    return '$tool is not available. Install $runtime first.';
  }

  @override
  String appProviderErrorToolInstallFailed(int exitCode, String tool) {
    return '$tool install failed with exit code $exitCode.';
  }

  @override
  String appProviderErrorBunBootstrapFailed(int exitCode) {
    return 'Bun bootstrap failed with exit code $exitCode.';
  }

  @override
  String get appProviderErrorInstalledButNotFoundInPath =>
      'OpenCode installation finished but command was not found in PATH.';

  @override
  String get appProviderErrorInstalledButPathNotResolved =>
      'OpenCode installation finished but command path could not be resolved.';

  @override
  String appProviderErrorConfiguredCommandNotFound(String tool) {
    return 'Configured command was not found and $tool is not in PATH.';
  }

  @override
  String get appProviderErrorConfiguredCommandPathMissing =>
      'Configured command path does not exist.';

  @override
  String get appProviderErrorConfiguredCommandVersionCheckFailed =>
      'Configured command exists but version check failed.';

  @override
  String get appProviderErrorConfiguredCommandExecutionFailed =>
      'Configured command could not be executed.';

  @override
  String get appProviderWslCheckWindowsOnly =>
      'WSL check only applies to Windows.';

  @override
  String get appProviderDesktopBuildRequired =>
      'Use a desktop build to configure a managed local server.';

  @override
  String get appProviderKnownInstallationDirectoryDetected =>
      'Detected from a known installation directory.';

  @override
  String appProviderKnownInstallationPathRefreshHint(String appName) {
    return 'Detected from a known installation directory. PATH may need refresh; reopen $appName if a recent install is not detected yet.';
  }

  @override
  String get appProviderErrorReleaseMetadataFetchFailed =>
      'Failed to fetch latest release metadata from GitHub.';

  @override
  String get appProviderErrorReleaseAssetListMissing =>
      'Latest release metadata did not include asset list.';

  @override
  String get appProviderErrorNoCompatibleAsset =>
      'No compatible OpenCode binary asset was found.';

  @override
  String get appProviderErrorDownloadAssetFailed =>
      'Failed to download selected OpenCode asset.';

  @override
  String get appProviderErrorChecksumVerificationFailed =>
      'Checksum verification failed for downloaded asset.';

  @override
  String get appProviderErrorExtractArchiveFailed =>
      'Failed to extract OpenCode binary archive.';

  @override
  String appProviderErrorExecutableNotFound(String tool) {
    return 'Could not find $tool executable in extracted files.';
  }

  @override
  String get chatNoResponseFromServer =>
      'No response from server. Please try again.';

  @override
  String get chatNoResponseFromModel =>
      'No response from model. Please try again.';

  @override
  String get speechJobCancelled => 'Speech job was cancelled.';

  @override
  String get speechEdgeCancelled => 'Microsoft Edge Speech was cancelled.';

  @override
  String get sessionAttentionKindActive => 'Active';

  @override
  String get sessionAttentionKindReceiving => 'Receiving';

  @override
  String get sessionAttentionKindDelayed => 'Delayed';

  @override
  String get sessionAttentionKindCompleted => 'Completed';

  @override
  String get sessionAttentionKindPendingInteraction => 'Pending interaction';

  @override
  String get sessionAttentionKindError => 'Error';

  @override
  String get sessionAttentionPauseCellularDataSaver =>
      'Cellular data saver is active';

  @override
  String get sessionAttentionPauseOauthReopenRequired =>
      'OAuth sign-in required';

  @override
  String get sessionAttentionPauseTailscaleReopenRequired =>
      'Tailscale connection required';

  @override
  String get sessionAttentionPauseOffline => 'Offline';

  @override
  String get sessionAttentionPausePermissionRevoked => 'Permission revoked';

  @override
  String get sessionAttentionPauseServiceStopped => 'Service stopped';

  @override
  String get sessionAttentionPauseHostUnavailable => 'Host unavailable';

  @override
  String get errorRequestCancelled => 'Request cancelled';

  @override
  String errorUnknownNetworkError(String error) {
    return 'Unknown network error: $error';
  }

  @override
  String get errorCertificateError => 'Certificate error';

  @override
  String get errorSessionBusy => 'Session is busy processing another request.';

  @override
  String get errorRunShellCommandFailed => 'Failed to run shell command';

  @override
  String get errorRunSlashCommandFailed => 'Failed to run slash command';

  @override
  String get settingsBehaviorOpenCodeDefaultsLoadError =>
      'Could not load OpenCode-backed defaults from the active server.';

  @override
  String get sessionTabIconRemoveFailed =>
      'Failed to remove local session tab icon data';

  @override
  String get forwardUntitled => 'Untitled';

  @override
  String setupDebugLinuxLogsPath(String path) {
    return 'Linux logs: $path';
  }

  @override
  String setupDebugRunOpenCodeCommand(String command) {
    return 'Run OpenCode with: $command';
  }

  @override
  String setupDebugServerHealthEndpoint(String endpoint) {
    return 'Server health: $endpoint';
  }

  @override
  String setupDebugServerDocsEndpoint(String endpoint) {
    return 'Server docs: $endpoint';
  }

  @override
  String get logsEntryError => 'Error';

  @override
  String get logsEntryStack => 'Stack';

  @override
  String get setupDebugSourceDiagnostics => 'Diagnostics';

  @override
  String get setupDebugSourceUseExisting => 'Use Existing';

  @override
  String get setupDebugSourceLocalServer => 'Local Server';

  @override
  String get setupDebugSourceOnboarding => 'Onboarding';

  @override
  String get setupDebugSourceManualConnection => 'Manual connection';

  @override
  String setupDebugMessageDiagnosticsResult(
    String availability,
    String platform,
    String recommendation,
  ) {
    return '$availability on $platform. $recommendation';
  }

  @override
  String get setupDebugMessageDetectAttempt =>
      'Trying to detect an existing OpenCode command from the current environment.';

  @override
  String get setupDebugMessageInstallStarted =>
      'Started OpenCode installation from CodeWalk.';

  @override
  String setupDebugMessageStartLocalServer(String url) {
    return 'Starting managed OpenCode server at $url.';
  }

  @override
  String setupDebugMessageHealthyRunning(String url) {
    return 'Managed OpenCode server is healthy and running at $url.';
  }

  @override
  String get setupDebugMessageStoppingLocalServer =>
      'Stopping managed OpenCode server.';

  @override
  String get setupDebugMessageStoppedCleanly =>
      'Managed OpenCode server stopped cleanly.';

  @override
  String get setupDebugMessageExitedAfterRequestedStop =>
      'Managed OpenCode server exited after a requested stop.';

  @override
  String get setupDebugMessageOnboardingConnectExisting =>
      'User chose to connect to an existing OpenCode server.';

  @override
  String get setupDebugMessageOnboardingGuidedPath =>
      'User opened the guided OpenCode setup path.';

  @override
  String get setupDebugMessageOnboardingManagedLocal =>
      'User opened managed local OpenCode setup.';

  @override
  String get setupDebugMessageOnboardingOpenedServerSettings =>
      'User opened server settings after a failed health check.';

  @override
  String get setupDebugMessageOnboardingAddAnotherServer =>
      'User chose to add another server after a failed health check.';

  @override
  String setupDebugMessageTestingServerUrl(String url) {
    return 'Testing OpenCode server URL $url from onboarding.';
  }

  @override
  String get chatProviderErrorSessionNotFound => 'Session not found';

  @override
  String get chatProviderErrorInvalidMessageFormat => 'Invalid message format';

  @override
  String get chatProviderErrorNetworkShort => 'Network connection failed';

  @override
  String get chatProviderErrorUnknownShort => 'Unknown error';

  @override
  String get terminalCreateFailed => 'Failed to create terminal session';

  @override
  String get terminalEndpointUnavailable =>
      'Terminal endpoint is not available';

  @override
  String get terminalInvalidDirectory => 'Invalid terminal directory';

  @override
  String get terminalWebsocketUnavailable =>
      'Terminal websocket is not available here.';

  @override
  String chatMessageToolChainCallsCompact(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count calls',
      one: '1 call',
    );
    return '$_temp0';
  }

  @override
  String get errorConnectionTimeout => 'Connection timeout';

  @override
  String get errorClientError => 'Client error';

  @override
  String get chatProviderErrorSendMessage => 'Failed to send message';

  @override
  String get speechApiEngine => 'API';

  @override
  String get speechApiEngineSubtitle =>
      'OpenAI, Groq, or a custom OpenAI-compatible endpoint.';

  @override
  String get speechApiProvider => 'Speech-to-text provider';

  @override
  String get speechCloudSttPrivacy => 'Cloud speech-to-text privacy';

  @override
  String get speechCloudSttPrivacyDescription =>
      'Recorded microphone audio is sent to the configured provider. API keys stay in secure storage on this device.';

  @override
  String get speechApiKeyOptional => 'Optional for custom endpoints.';

  @override
  String speechApiBatchHint(String provider) {
    return '$provider uses batch transcription. Tap the microphone again to stop and transcribe.';
  }

  @override
  String get speechApiWebUnavailable =>
      'API speech-to-text is unavailable on the web build.';

  @override
  String get speechApiConfigInvalid =>
      'Check the speech API endpoint and model. Remote endpoints must use HTTPS.';

  @override
  String get speechApiRequestInvalid =>
      'The speech endpoint or model was rejected.';

  @override
  String get speechApiRateLimited =>
      'The speech provider reported a quota or rate limit.';

  @override
  String get speechApiUnavailable =>
      'The speech provider is temporarily unavailable.';

  @override
  String get speechApiNetwork => 'The speech provider could not be reached.';

  @override
  String get speechApiInvalidResponse =>
      'The speech provider returned an invalid response.';

  @override
  String get speechApiEmptyAudio => 'No microphone audio was captured.';

  @override
  String get speechApiEmptyTranscript =>
      'The speech provider returned no transcription.';

  @override
  String get speechApiCustomProvider => 'Custom OpenAI-compatible';

  @override
  String get speechApiMaxDuration =>
      'API recordings stop automatically after 2 minutes.';

  @override
  String get speechApiLanguageHint =>
      'The active app language is sent as a transcription hint.';

  @override
  String get speechSttApiKeyStorageUnavailable =>
      'Secure speech API key storage is unavailable.';

  @override
  String get speechSttApiKeyMissing =>
      'Add a speech API key in Settings > Speech.';

  @override
  String get speechSttApiKeyRejected => 'The speech API key was rejected.';

  @override
  String get carMessagingReply => 'Reply';

  @override
  String get carMessagingMarkRead => 'Mark as read';

  @override
  String get carMessagingDeliveryFailedTitle => 'Couldn\'t send reply';

  @override
  String get carMessagingDeliveryFailedBody =>
      'Your voice reply could not be delivered. Open CodeWalk to retry.';
}
