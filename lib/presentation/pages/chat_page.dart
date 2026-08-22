import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart'
    show PointerScrollEvent, PointerSignalEvent;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderBox, ScrollDirection;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart' hide Provider;
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/all.dart';
import 'package:re_highlight/re_highlight.dart' show Mode;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:simple_icons/simple_icons.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/config/feature_flags.dart';
import '../../core/di/injection_container.dart' as di;
import '../../core/i18n/l10n_bridge.dart';
import '../../core/i18n/l10n_context.dart';
import '../../core/logging/app_logger.dart';
import '../../core/network/dio_client.dart';
import '../../core/utils/path_utils.dart';
import '../../core/utils/timeline_search_service.dart';
import '../../data/datasources/terminal_remote_datasource.dart';
import '../../data/session_attention/session_attention_snapshot_store.dart';
import '../../domain/entities/agent.dart';
import '../../domain/entities/canned_answer.dart';
import '../../domain/entities/chat_composer_draft.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_realtime.dart';
import '../../domain/entities/chat_session.dart';
import '../../domain/entities/experience_settings.dart';
import '../../domain/entities/file_node.dart';
import '../../domain/entities/project.dart';
import '../../domain/entities/provider.dart';
import '../../domain/entities/session_attention_overlay/session_attention_models.dart';
import '../../l10n/generated/app_localizations.dart';
import '../providers/app_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/project_provider.dart';
import '../providers/quota_provider.dart';
import '../providers/settings_provider.dart';
import '../services/android_background_alert_logic.dart';
import '../services/android_background_alert_worker.dart';
import '../services/android_foreground_monitor_service.dart';
import '../services/cellular_data_saver_service.dart';
import '../services/codewalk_terminal_controller.dart';
import '../services/forward_message_service.dart';
import '../services/notification_service.dart';
import '../services/permission_auto_approve_runtime.dart';
import '../services/read_aloud_service.dart';
import '../services/session_attention/session_attention_completion_resolver.dart';
import '../services/session_export_service.dart';
import '../services/tts/tts_executor.dart';
import '../services/workspace_file_operations_service.dart';
import '../theme/app_animations.dart';
import '../theme/app_shapes.dart';
import '../theme/app_theme.dart';
import '../theme/app_visual_style_tokens.dart';
import '../theme/opencode_highlight_theme.dart';
import '../theme/opencode_theme_presets.dart';
import '../utils/app_page_route.dart';
import '../utils/chat_abort_message.dart';
import '../utils/chat_server_error_formatter.dart';
import '../utils/duplicate_file_name.dart';
import '../utils/file_highlight_language.dart';
import '../utils/file_explorer_logic.dart';
import '../utils/reasoning_status_parser.dart';
import '../utils/session_title_formatter.dart';
import '../utils/shortcut_binding_codec.dart';
import '../utils/tool_presentation.dart';
import '../utils/window_size_class.dart';
import '../widgets/chat_input_widget.dart';
import '../widgets/chat_message_widget.dart';
import '../widgets/chat_session_list.dart';
import '../widgets/chat_skeleton_shimmer.dart';
import '../widgets/chat_tour_showcase.dart';
import '../widgets/codewalk_terminal_panel.dart';
import '../widgets/desktop_window_title_bar.dart';
import '../widgets/file_tree_context_menu.dart';
import '../widgets/forward_message_dialog.dart';
import '../widgets/message_entrance_animation.dart';
import '../widgets/modal_primary_action_shortcuts.dart';
import '../widgets/permission_request_card.dart';
import '../widgets/project_icon.dart';
import '../widgets/question_request_card.dart';
import '../widgets/quota/quota_popup_section.dart';
import '../widgets/session_attention_overlay/session_attention_overlay.dart';
import '../widgets/session_attention_overlay/session_attention_overlay_controller.dart';
import '../widgets/session_context_menu.dart';
import '../widgets/session_diff_viewer.dart';
import '../widgets/session_tab_icon_picker.dart';
import '../widgets/session_tab_strip.dart';
import '../widgets/session_title_inline_editor.dart';
import '../widgets/session_todo_list_widget.dart';
import '../widgets/sidebar_selection_indicator.dart';
import 'onboarding_wizard_page.dart';
import 'settings_page.dart';

part 'chat_page_types_part.dart';
part 'chat_page_local_models_part.dart';
part 'chat_page/chat_page_lifecycle.dart';
part 'chat_page/chat_page_scroll_coordinator.dart';
part 'chat_page/chat_page_workspace_controller.dart';
part 'chat_page/chat_page_session_tabs.dart';
part 'chat_page/chat_page_shortcuts.dart';
part 'chat_page/chat_page_status_presenter.dart';
part 'chat_page/chat_page_selector_flow.dart';
part 'chat_page/chat_page_scaffold.dart';
part 'chat_page/chat_page_file_explorer_controller.dart';
part 'chat_page/chat_page_file_viewer.dart';
part 'chat_page/chat_page_timeline_builder.dart';
part 'chat_page/chat_page_timeline_viewport.dart';
part 'chat_page/chat_page_timeline_entries.dart';
part 'chat_page/chat_page_composer_status.dart';
part 'chat_page/chat_page_command_query.dart';
part 'chat_page/chat_page_runtime_support.dart';
part 'chat_page/chat_page_chrome.dart';
part 'chat_page/chat_page_file_runtime.dart';
part 'chat_page/chat_page_composer_widgets.dart';
part 'chat_page/chat_page_model_selector_runtime.dart';
part 'chat_page/chat_page_timeline_runtime.dart';
part 'chat_page/chat_page_terminal_runtime.dart';
part 'chat_page/chat_page_search.dart';
part 'chat_page/chat_page_mobile_overflow.dart';
part 'chat_page/chat_page_forward_runtime.dart';
part 'chat_page/chat_page_widgets.dart';

@visibleForTesting
List<String> buildComposerReceivingTips(AppLocalizations l10n) => <String>[
  l10n.chatTipMentionFiles,
  l10n.chatTipRenameConversation,
  l10n.chatTipShellCommands,
  l10n.chatTipSlashCommands,
  l10n.chatTipLongPressSend,
  l10n.chatTipContextKnob,
  l10n.chatTipBeSpecific,
  l10n.chatTipStepByStep,
  l10n.chatTipProvideContext,
  l10n.chatTipBreakTasks,
  l10n.chatTipStartWithGoal,
  l10n.chatTipNameRelevantFiles,
  l10n.chatTipStateConstraints,
  l10n.chatTipAskForPlan,
  l10n.chatTipDefineVerification,
  l10n.chatTipShareAttempts,
  l10n.chatTipCompareOptions,
  l10n.chatTipRequestDocs,
  l10n.chatTipAcceptanceCriteria,
  l10n.chatTipUseFocusedAgents,
];

@visibleForTesting
int pickComposerReceivingTipIndex(
  AppLocalizations l10n,
  int Function(int max) nextInt,
) {
  final tips = buildComposerReceivingTips(l10n);
  return nextInt(tips.length);
}

/// Chat page
class ChatPage extends StatefulWidget {
  const ChatPage({super.key, this.projectId});
  final String? projectId;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage>
    with WidgetsBindingObserver, WindowListener {
  static const int _maxHydratedTimelineCacheEntries = 20;
  // File pane shown when expanded and width exceeds this threshold
  static const double _filePaneBreakpoint = 1100;
  static const double _mediumSessionPaneWidth = 260;
  static const double _nearBottomThreshold = 200;
  static const double _olderMessagesTopLoadThreshold = 72;
  static const double _olderMessagesTopLoadArmThreshold = 220;
  static const double _jumpToFirstFabThreshold = 360;
  static const double _scrollToBottomEpsilon = 1;
  static const int _maxScrollToBottomPasses = 3;
  static const Duration _scrollToBottomFirstPassDuration = Duration.zero;
  static const Duration _scrollToBottomNextPassDuration = Duration.zero;
  static const String _rootTreeCacheKey = '__root__';
  static const Duration _serverAlertGracePeriod = Duration(seconds: 10);
  static const Duration _unhealthySnackbarDebounce = Duration(seconds: 5);
  static const Duration _foregroundWarningConfirmationDelay = Duration(
    seconds: 2,
  );
  static const Duration _initialDataRecoveryDebounce = Duration(
    milliseconds: 600,
  );
  static const Duration _composerStatusShowDelay = Duration(seconds: 2);
  static const Duration _composerStatusHideDelay = Duration(seconds: 1);
  static const Duration _composerStopHintDuration = Duration(seconds: 1);
  static const Duration _mobileBackgroundRealtimeHoldDuration = Duration(
    minutes: 3,
  );
  static const Duration _doubleEscapeStopThreshold = Duration(
    milliseconds: 500,
  );
  static const int _notificationTapMaxAttempts = 12;
  static const int _notificationTapReloadAttempts = 3;
  static const Duration _notificationTapRetryInterval = Duration(
    milliseconds: 180,
  );
  static const Duration _postOnboardingTourRetryDelay = Duration(
    milliseconds: 150,
  );
  static const Duration _postOnboardingTourStartDelay = Duration(
    milliseconds: 350,
  );
  static const int _postOnboardingTourMaxAttempts = 20;
  static const double _composerStatusReservedHeight = 26;
  static const Duration _finalAssistantRevealDuration = Duration(
    milliseconds: 220,
  );
  static const double _finalAssistantRevealAlignment = 0.4;
  static const int _maxFinalAssistantRevealAttempts = 8;
  static const double _returnLatestRevealAlignment = 0.0;
  static const int _maxReturnLatestRevealAttempts = 8;
  static const Duration _userScrollIntentHoldDuration = Duration(
    milliseconds: 900,
  );
  static const Duration _projectScopeLoadingOverlayDelay = Duration(
    milliseconds: 150,
  );
  static const String _traceFinalPrefix = 'CW_TRACE_FINAL';

  List<String> get _receivingTips => buildComposerReceivingTips(context.l10n);

  final ScrollController _scrollController = ScrollController();
  final TimelineSearchService _timelineSearchService =
      const TimelineSearchService();
  final TextEditingController _timelineSearchController =
      TextEditingController();
  final FocusNode _timelineSearchFocusNode = FocusNode(
    debugLabel: 'timeline_search',
  );
  final Map<String, GlobalKey> _timelineSearchMessageKeysByMessageId =
      <String, GlobalKey>{};
  // Scroll controller for the file viewer's vertical content area.
  // Used to scroll to a specific line when a file path is tapped in chat.
  final ScrollController _fileViewerScrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode(debugLabel: 'chat_input');
  final ChatInputController _chatInputController = ChatInputController();
  final CodewalkTerminalController _terminalController =
      CodewalkTerminalController(
        remoteDataSource: di.sl.isRegistered<TerminalRemoteDataSource>()
            ? di.sl<TerminalRemoteDataSource>()
            : null,
      );
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey _agentSelectorChipKey = GlobalKey(
    debugLabel: 'agent_selector_chip',
  );
  final GlobalKey _drawerAccessTourKey = GlobalKey(
    debugLabel: 'tour_drawer_access',
  );
  final GlobalKey _drawerAccessTourTargetKey = GlobalKey(
    debugLabel: 'tour_drawer_access_target',
  );
  final GlobalKey _projectContextTourKey = GlobalKey(
    debugLabel: 'tour_project_context',
  );
  final GlobalKey _projectContextTourTargetKey = GlobalKey(
    debugLabel: 'tour_project_context_target',
  );
  final GlobalKey _desktopSidebarMenuTourKey = GlobalKey(
    debugLabel: 'tour_desktop_sidebar_menu',
  );
  final GlobalKey _desktopSidebarMenuTourTargetKey = GlobalKey(
    debugLabel: 'tour_desktop_sidebar_menu_target',
  );
  final GlobalKey _newChatTourKey = GlobalKey(debugLabel: 'tour_new_chat');
  final GlobalKey _newChatTourTargetKey = GlobalKey(
    debugLabel: 'tour_new_chat_target',
  );
  final GlobalKey _composerTourKey = GlobalKey(debugLabel: 'tour_composer');
  final GlobalKey _composerTourTargetKey = GlobalKey(
    debugLabel: 'tour_composer_target',
  );
  final GlobalKey _sendButtonTourKey = GlobalKey(debugLabel: 'tour_send');
  final GlobalKey _sendButtonTourTargetKey = GlobalKey(
    debugLabel: 'tour_send_target',
  );
  final GlobalKey<ShowCaseWidgetState> _showcaseWidgetKey =
      GlobalKey<ShowCaseWidgetState>();
  final TextEditingController _sessionSearchController =
      TextEditingController();
  final FocusNode _sessionSearchFocusNode = FocusNode();
  bool _isSessionSearchExpanded = false;
  NotificationService? _notificationService;
  StreamSubscription<NotificationTapPayload>? _notificationTapSubscription;
  NotificationTapPayload? _pendingNotificationTap;
  int _pendingNotificationTapGeneration = 0;
  Future<void>? _notificationTapTask;
  SessionAttentionOverlayController? _sessionAttentionOverlayController;
  String? _sessionAttentionOverlayRefreshKey;
  bool _sessionAttentionOverlayRefreshScheduled = false;
  Timer? _sessionAttentionOverlayRefreshTimer;
  ChatProvider? _chatProvider;
  AppProvider? _appProvider;
  ProjectProvider? _projectProvider;
  SettingsProvider? _settingsProvider;
  DesktopWindowChromeController? _desktopWindowChromeController;
  bool _autoApprovePermissionDrainScheduled = false;
  bool _autoApprovePermissionDrainRunning = false;
  bool _autoApprovePermissionDrainQueued = false;
  final Set<String> _autoApprovePermissionCooldownIds = <String>{};
  String? _backgroundPermissionAutoApproveContextSignature;
  Future<void> _backgroundPermissionContextMutationQueue = Future<void>.value();
  int _backgroundPermissionContextGeneration = 0;
  int _backgroundPermissionContextMutationGeneration = 0;
  int? _backgroundPermissionContextClearPendingGeneration;
  bool _backgroundPermissionAutoApproveContextMayBeEnabled = true;
  String? _lastServerId;
  bool? _lastServerConnectionState;
  ServerHealthStatus _lastActiveServerHealthStatus = ServerHealthStatus.unknown;
  String? _trackedSessionId;
  String? _pendingInitialScrollSessionId;
  _ScrollFollowMode _scrollFollowMode = _ScrollFollowMode.following;
  bool get _showScrollToLatestFab =>
      (_hasUnreadMessagesBelow ||
          _scrollFollowMode == _ScrollFollowMode.pausedByUser) &&
      (_scrollFollowMode == _ScrollFollowMode.pausedByUser ||
          !_isLatestAssistantMessageVisibleInViewport());
  String? _lastRevealedAssistantMessageId;
  bool _hasUnreadMessagesBelow = false;
  bool _showScrollToFirstFab = false;
  bool _isProjectScopeTransitioning = false;
  bool _showProjectScopeLoadingOverlay = false;
  int _projectScopeTransitionGeneration = 0;
  Timer? _projectScopeLoadingOverlayTimer;

  /// True while the terminal is being opened.
  ///
  /// Opening persists a setting and then starts a shell, so it is not
  /// instantaneous. Without this the button gave no sign it had been pressed
  /// and repeated taps could start more than one shell (#125).
  bool _isOpeningTerminal = false;
  Future<void>? _projectScopeTransitionTask;
  SessionTabIdentity? _activatingSessionTabIdentity;
  Future<bool>? _sessionTabActivationTask;
  int _sessionTabActivationGeneration = 0;
  bool _sessionTabActivationCloseGuard = false;
  Set<SessionTabIdentity> _knownSessionTabIdentities = <SessionTabIdentity>{};
  final Set<SessionTabIdentity> _pendingSessionTabHintIdentities =
      <SessionTabIdentity>{};
  bool _sessionTabHintScheduled = false;
  bool _sessionTabHintShowing = false;
  int _sessionTabHintGeneration = 0;
  Timer? _sessionTabSnackBarExpirationTimer;
  bool _isProjectSelectorActionInFlight = false;
  // Per-session collapse state cache (up to 20 sessions, LRU-evicted).
  // Stores the last expanded history group ID for each session ID.
  final Map<String, String?> _sessionCollapseHistoryCache = {};
  final Map<String, bool> _projectGroupExpandedById = <String, bool>{};
  bool _isAppInForeground = true;
  bool _wasChatRouteCurrent = false;
  bool _isProgrammaticScrollInFlight = false;
  bool _isReturnRevealInFlight = false;
  bool _olderMessagesLoadTriggerArmed = true;
  bool _olderMessagesAnchorRestoreInFlight = false;
  _ScrollOwner _currentScrollOwner = _ScrollOwner.none;
  DateTime? _lastUserScrollIntentAt;
  _CachedViewportRestoreTarget _pendingCachedViewportRestoreTarget =
      _CachedViewportRestoreTarget.none;
  int _scrollToBottomRequestToken = 0;
  int _returnRevealGeneration = 0;
  int _responseSettleFramesRemaining = 0;
  bool _wasCurrentSessionActivelyResponding = false;
  bool _deferAssistantWorkCollapse = false;
  bool _shouldRevealFinalAssistantOnCompletion = false;
  String? _pendingFinalAssistantRevealMessageId;
  String? _settledLatestAssistantWorkGroupId;
  int _debugActiveTurnPassiveScrollRequests = 0;
  String? _debugActiveTurnPassiveScrollSessionId;
  String? _lastProviderMessageTrackingSessionId;
  String? _lastProviderMessageTrackingLastId;
  int _lastProviderMessageTrackingCount = 0;
  int _lastProviderMessageTrackingVersion = -1;

  void _setScrollOwner(_ScrollOwner owner) {
    final previousOwner = _currentScrollOwner;
    _currentScrollOwner = owner;
    _isProgrammaticScrollInFlight =
        owner != _ScrollOwner.none && owner != _ScrollOwner.userDrag;
    _isReturnRevealInFlight = owner == _ScrollOwner.returnReveal;
    _olderMessagesAnchorRestoreInFlight =
        owner == _ScrollOwner.paginationRestore;
    if (previousOwner != owner) {
      AppLogger.debug(
        'Chat viewport owner: ${previousOwner.name} -> ${owner.name} '
        'session=${_chatProvider?.currentSession?.id ?? "-"} '
        'followMode=${_scrollFollowMode.name} '
        'requestToken=$_scrollToBottomRequestToken',
      );
    }
  }

  void _requestPassiveScrollToBottom({required String reason}) {
    if (!mounted) {
      return;
    }
    if (_resumeRefreshViewportRestorePending) {
      _traceFinalUi(
        'passive-scroll-suppressed-resume-refresh-pending',
        details: 'reason=$reason',
      );
      _markUnreadMessagesBelow();
      return;
    }
    if (_hasUserScrollPriority()) {
      _traceFinalUi(
        'passive-scroll-suppressed-user-scroll-priority',
        details: 'reason=$reason',
      );
      _markUnreadMessagesBelow();
      return;
    }
    if (_scrollFollowMode != _ScrollFollowMode.following) {
      if (_isReadingLatestSettledAssistantResponse()) {
        _traceFinalUi(
          'passive-scroll-suppressed-reading-latest',
          details: 'reason=$reason mode=${_scrollFollowMode.name}',
        );
        return;
      }
      _traceFinalUi(
        'passive-scroll-suppressed-not-following',
        details: 'reason=$reason mode=${_scrollFollowMode.name}',
      );
      _markUnreadMessagesBelow();
      return;
    }
    if (_currentScrollOwner != _ScrollOwner.none ||
        _isReturnRevealInFlight ||
        _olderMessagesAnchorRestoreInFlight) {
      _traceFinalUi(
        'passive-scroll-suppressed-owner-active',
        details: 'reason=$reason owner=${_currentScrollOwner.name}',
      );
      return;
    }
    if (_chatProvider?.isCurrentSessionActivelyResponding == true) {
      final currentSessionId = _chatProvider?.currentSession?.id;
      if (currentSessionId != null) {
        _debugRecordActiveTurnPassiveScrollRequest(
          sessionId: currentSessionId,
          reason: reason,
        );
      }
      _traceFinalUi(
        'passive-scroll-suppressed-active-response',
        details: 'reason=$reason',
      );
      return;
    }
    if (_chatProvider != null &&
        _pendingInitialScrollSessionId == _chatProvider!.currentSession?.id &&
        _pendingCachedViewportRestoreTarget ==
            _CachedViewportRestoreTarget.latestResponse) {
      _traceFinalUi(
        'passive-scroll-promote-cached-latest-restore',
        details: 'reason=$reason',
      );
      _consumeQueuedCachedViewportRestore(
        _chatProvider!,
        reason: 'passive:$reason',
      );
      return;
    }
    _traceFinalUi('passive-scroll-request', details: 'reason=$reason');
    _scrollToBottom(force: false);
  }

  void _traceFinalUi(String event, {String? details}) {
    final provider = _chatProvider;
    final sessionId = provider?.currentSession?.id ?? '-';
    final messages = provider?.messages ?? const <ChatMessage>[];
    final lastMessageId = messages.isEmpty ? '-' : messages.last.id;
    final suffix = details == null || details.trim().isEmpty
        ? ''
        : ' details=${details.trim()}';
    AppLogger.info(
      '$_traceFinalPrefix ui event=$event session=$sessionId responding=${provider?.isCurrentSessionActivelyResponding ?? false} state=${provider?.state.name ?? "-"} messages=${messages.length} last=$lastMessageId pendingFinal=${_pendingFinalAssistantRevealMessageId ?? "-"} settledFinal=${_finalAssistantRevealSettledMessageId ?? "-"} settledWorkGroup=${_settledLatestAssistantWorkGroupId ?? "-"} deferCollapse=$_deferAssistantWorkCollapse followMode=${_scrollFollowMode.name}$suffix',
    );
  }

  void _debugStartActiveTurnPassiveScrollTracking(String sessionId) {
    assert(() {
      final normalizedSessionId = sessionId.trim();
      if (normalizedSessionId.isEmpty) {
        return true;
      }
      if (_debugActiveTurnPassiveScrollSessionId == normalizedSessionId) {
        return true;
      }
      if (_debugActiveTurnPassiveScrollSessionId != null &&
          _debugActiveTurnPassiveScrollRequests > 0) {
        AppLogger.debug(
          'CW_TRACE_ACTIVE_TURN_PASSIVE_SCROLL event=abandon '
          'session=${_debugActiveTurnPassiveScrollSessionId ?? "-"} '
          'count=$_debugActiveTurnPassiveScrollRequests',
        );
      }
      _debugActiveTurnPassiveScrollSessionId = normalizedSessionId;
      _debugActiveTurnPassiveScrollRequests = 0;
      return true;
    }());
  }

  void _debugRecordActiveTurnPassiveScrollRequest({
    required String sessionId,
    required String reason,
  }) {
    assert(() {
      final normalizedSessionId = sessionId.trim();
      if (normalizedSessionId.isEmpty) {
        return true;
      }
      if (_debugActiveTurnPassiveScrollSessionId != normalizedSessionId) {
        _debugStartActiveTurnPassiveScrollTracking(normalizedSessionId);
      }
      _debugActiveTurnPassiveScrollRequests += 1;
      AppLogger.debug(
        'CW_TRACE_ACTIVE_TURN_PASSIVE_SCROLL event=request '
        'session=$normalizedSessionId '
        'count=$_debugActiveTurnPassiveScrollRequests '
        'reason=$reason',
      );
      return true;
    }());
  }

  void _debugFinishActiveTurnPassiveScrollTracking({
    required String sessionId,
    required String reason,
  }) {
    assert(() {
      final normalizedSessionId = sessionId.trim();
      if (normalizedSessionId.isEmpty ||
          _debugActiveTurnPassiveScrollSessionId != normalizedSessionId) {
        return true;
      }
      if (_debugActiveTurnPassiveScrollRequests > 0) {
        AppLogger.debug(
          'CW_TRACE_ACTIVE_TURN_PASSIVE_SCROLL event=summary '
          'session=$normalizedSessionId '
          'count=$_debugActiveTurnPassiveScrollRequests '
          'reason=$reason',
        );
      }
      _debugActiveTurnPassiveScrollSessionId = null;
      _debugActiveTurnPassiveScrollRequests = 0;
      return true;
    }());
  }

  String? _finalAssistantRevealSettledMessageId;
  bool _finalAssistantRevealScheduled = false;
  int _pendingFinalAssistantRevealAttempts = 0;
  final Map<String, GlobalKey> _messageRevealAnchorKeysByMessageId =
      <String, GlobalKey>{};
  final Map<String, GlobalKey> _messageRevealMeasurementKeysByMessageId =
      <String, GlobalKey>{};
  String? _lastForegroundPolicySettingsSignature;
  bool? _lastEditorAutosaveEnabled;
  String? _lastFileEditorAutosaveContextKey;
  String? _terminalSessionSignature;
  ChatComposerDraft? _composerPrefilledDraft;
  int _composerPrefilledDraftVersion = 0;

  /// Track the most recently targeted message for the forward keyboard
  /// shortcut (Ctrl/Cmd+Shift+F). Reset by the forward runtime; read by
  /// the shortcut resolver in `chat_page_shortcuts.dart`.
  String? _lastForwardedMessageId;
  ChatMessage? _lastForwardedMessage;
  final Map<String, _FileExplorerContextState> _fileContextStates =
      <String, _FileExplorerContextState>{};
  final Map<String, String> _fileDiffSignaturesByContext = <String, String>{};
  final List<FileInputPart> _fileContextItems = <FileInputPart>[];
  DateTime? _serverAlertIssueStartedAt;
  Timer? _serverAlertRevealTimer;
  DateTime? _foregroundWarningGraceEndsAt;
  Timer? _foregroundWarningUiRefreshTimer;
  Timer? _foregroundWarningSnackbarTimer;
  Timer? _unhealthySnackbarDebounceTimer;
  Timer? _initialDataRecoveryTimer;
  Timer? _composerDraftPersistTimer;
  String? _composerDraftStagedSessionId;
  ChatComposerDraft? _composerDraftStagedDraft;
  Timer? _composerStatusShowTimer;
  Timer? _composerStatusHideTimer;
  Timer? _composerStopHintTimer;
  Timer? _backgroundRealtimeHoldTimer;
  Timer? _tipRotationTimer;
  Timer? _timelineSearchDebounceTimer;
  TimelineSearchResult _timelineSearchResult = TimelineSearchResult.empty;
  bool _timelineSearchActive = false;
  int _timelineSearchCurrentIndex = 0;
  int _timelineSearchScrollOpId = 0;
  int _timelineSearchLastMessagesVersion = -1;
  String? _timelineSearchLastSessionId;
  List<String> _pinnedMobileAppBarActionIds = <String>[];
  DateTime? _lastResumeRefreshAt;
  DateTime? _lastReturnToChatAt;
  String? _lastReturnToChatSignature;
  String? _lastConsumedCachedViewportRestoreSignature;
  DateTime? _lastConsumedCachedViewportRestoreAt;
  bool _resumeRefreshViewportRestorePending = false;
  bool _needsInitialDataRecovery = false;
  bool _initialDataRecoveryInFlight = false;
  int _initialDataRecoveryAttemptCount = 0;
  bool _didSeedComposerTipIndex = false;
  int _currentTipIndex = 0;
  DateTime? _lastGlobalEscapeAt;
  _ComposerStatusPresentation? _visibleComposerStatus;
  _ComposerStatusPresentation? _priorityComposerStatus;
  _ComposerStatusPresentation? _pendingComposerStatus;
  _ComposerStatusPresentation? _queuedComposerStatusTarget;
  _ComposerStatusPresentation? _lastComposerStatusTarget;
  bool _composerStatusTargetInitialized = false;
  String? _expandedCollapsedHistoryGroupId;
  String? _expandedAssistantWorkGroupId;
  String? _frozenCompactionBoundaryId;
  bool _wasCompactingContext = false;
  String? _nextFrozenCompactionBoundaryId;
  bool _nextWasCompactingContext = false;
  bool _compactionStateSyncScheduled = false;
  bool _tourStartScheduled = false;
  bool _tourAdvancingToComposerPhase = false;
  bool _tourExplicitSkipRequested = false;
  _PostOnboardingTourPhase _tourPhase = _PostOnboardingTourPhase.idle;
  int _postOnboardingTourRunToken = 0;
  bool _queuedPendingPostOnboardingTourAutoStart = false;
  bool _lastPendingPostOnboardingChatTour = false;

  // Per-session hydrated timeline cache so reopening a cached session can
  // reuse its grouped presentation instead of rebuilding the whole timeline.
  final Map<String, _SessionTimelineEntriesCacheEntry>
  _sessionTimelineEntriesCache = <String, _SessionTimelineEntriesCacheEntry>{};

  // Cache for _resolveSessionContextUsage (O(N) double-scan of messages).
  int _cachedContextUsageMsgCount = -1;
  String? _cachedContextUsageLastMsgId;
  String? _cachedContextUsageProviderId;
  String? _cachedContextUsageModelId;
  _SessionContextUsageSnapshot? _cachedContextUsage;

  // Cache for _resolveLatestReasoningPartKey (O(N*M) backward scan).
  int _cachedReasoningKeyMessagesVersion = -1;
  String? _cachedReasoningKeyResult;
  bool _cachedReasoningKeyComputed = false;

  // Cache for _resolveAssistantProgressStage (O(N) scan for streaming parts).
  int _cachedProgressStageMsgCount = -1;
  String? _cachedProgressStageLastMsgId;
  bool _cachedProgressStageResponding = false;
  _AssistantProgressStage? _cachedProgressStageResult;
  bool _cachedProgressStageComputed = false;

  // Cache for _collectSentMessageHistory (O(N) filter of user messages).
  int _cachedSentHistoryMsgCount = -1;
  String? _cachedSentHistoryLastMsgId;
  List<String>? _cachedSentHistory;

  // Cache for locked sub-conversation model/variant labels.
  String? _cachedLockedSubConversationSessionId;
  int _cachedLockedSubConversationMessagesVersion = -1;
  int _cachedLockedSubConversationProviderCatalogSignature = -1;
  _LockedSubConversationSelection? _cachedLockedSubConversationSelection;

  // Cached highlight theme to avoid re-creating the Map<String, TextStyle>
  // spread on every _resolveHighlightTheme() call, which forces code surfaces
  // to re-parse when they detect a "changed" theme reference.
  Map<String, TextStyle>? _cachedHighlightTheme;
  Brightness? _cachedHighlightBrightness;
  String? _cachedHighlightThemeKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_handleGlobalShortcutKeyEvent);
    _scrollController.addListener(_handleScrollChanged);
    if (_isDesktopRuntime) {
      windowManager.addListener(this);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
      unawaited(_loadPinnedMobileActionsFromPrefs());
      unawaited(_refreshBackgroundPermissionAutoApproveContextState());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didSeedComposerTipIndex) {
      _didSeedComposerTipIndex = true;
      _currentTipIndex = pickComposerReceivingTipIndex(
        context.l10n,
        Random().nextInt,
      );
    }
    // Invalidate highlight theme cache on dependency change (theme switch).
    _cachedHighlightTheme = null;
    // Safely get ChatProvider reference here
    final nextChatProvider = context.read<ChatProvider>();
    if (!identical(_chatProvider, nextChatProvider)) {
      _chatProvider?.removeListener(_handleChatProviderChanged);
      _chatProvider = nextChatProvider;
      _chatProvider?.addListener(_handleChatProviderChanged);
      _autoApprovePermissionCooldownIds.clear();
      _handleChatProviderChanged();
    }
    _chatProvider?.setAppInForeground(_isAppInForeground);
    final nextAppProvider = context.read<AppProvider>();
    if (!identical(_appProvider, nextAppProvider)) {
      _appProvider?.removeListener(_handleAppProviderChange);
      _appProvider = nextAppProvider;
      _lastServerId = nextAppProvider.activeServerId;
      _lastServerConnectionState = nextAppProvider.isConnected;
      final initialActiveServer = nextAppProvider.activeServer;
      _lastActiveServerHealthStatus = initialActiveServer == null
          ? ServerHealthStatus.unknown
          : nextAppProvider.healthFor(initialActiveServer.id);
      _appProvider?.addListener(_handleAppProviderChange);
    }
    final nextProjectProvider = context.read<ProjectProvider>();
    if (!identical(_projectProvider, nextProjectProvider)) {
      _projectProvider?.removeListener(_handleProjectProviderChange);
      _projectProvider = nextProjectProvider;
      _projectProvider?.addListener(_handleProjectProviderChange);
      _lastFileEditorAutosaveContextKey = nextProjectProvider.contextKey;
    }
    if (di.sl.isRegistered<NotificationService>()) {
      final nextNotificationService = di.sl<NotificationService>();
      if (!identical(_notificationService, nextNotificationService)) {
        _notificationTapSubscription?.cancel();
        _notificationService = nextNotificationService;
        _notificationTapSubscription = nextNotificationService
            .onNotificationTapped
            .listen(_scheduleNotificationTap);
        final pendingPayload = nextNotificationService.consumePendingTap();
        if (pendingPayload != null) {
          _scheduleNotificationTap(pendingPayload);
        }
        unawaited(nextNotificationService.initialize());
      }
    }
    final nextSettingsProvider = context.read<SettingsProvider>();
    if (!identical(_settingsProvider, nextSettingsProvider)) {
      _settingsProvider?.removeListener(_handleSettingsChanged);
      _settingsProvider = nextSettingsProvider;
      _settingsProvider?.addListener(_handleSettingsChanged);
      _lastPendingPostOnboardingChatTour =
          nextSettingsProvider.pendingPostOnboardingChatTour;
      _queuedPendingPostOnboardingTourAutoStart =
          nextSettingsProvider.pendingPostOnboardingChatTour;
      unawaited(_applyForegroundPolicy(reason: 'settings-provider-attached'));
      _lastForegroundPolicySettingsSignature =
          _foregroundPolicySettingsSignature(nextSettingsProvider.settings);
      _lastEditorAutosaveEnabled = nextSettingsProvider.editorAutosaveEnabled;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        final chatProvider = _chatProvider;
        if (chatProvider != null) {
          _syncSessionTabsGestureHint(chatProvider);
        }
        _flushPendingPostOnboardingTourAutoStart();
      });
    }
    final nextDesktopWindowChromeController = context
        .read<DesktopWindowChromeController?>();
    if (!identical(
      _desktopWindowChromeController,
      nextDesktopWindowChromeController,
    )) {
      _desktopWindowChromeController?.detach(this);
      _desktopWindowChromeController = nextDesktopWindowChromeController;
      final controller = nextDesktopWindowChromeController;
      if (_isDesktopRuntime && controller != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              identical(_desktopWindowChromeController, controller)) {
            controller.attach(this, _buildIntegratedWindowTitleBar);
          }
        });
      }
    }
    _ensureSessionAttentionOverlayController();
  }

  void _ensureSessionAttentionOverlayController() {
    if (defaultTargetPlatform != TargetPlatform.iOS ||
        _sessionAttentionOverlayController != null ||
        !di.sl.isRegistered<SessionAttentionSnapshotStore>() ||
        !di.sl.isRegistered<ReadAloudService>()) {
      return;
    }
    final controller = SessionAttentionOverlayController(
      snapshotStore: di.sl<SessionAttentionSnapshotStore>(),
      readAloudService: di.sl<ReadAloudService>(),
      settings: () =>
          _settingsProvider?.settings ?? ExperienceSettings.defaults(),
      noteExplicitUserAction: (reason) {
        if (di.sl.isRegistered<CellularDataSaverService>()) {
          di.sl<CellularDataSaverService>().noteExplicitUserAction(
            reason: reason,
          );
        }
      },
    )..addListener(_handleSessionAttentionOverlayChanged);
    _sessionAttentionOverlayController = controller;
  }

  void _handleSessionAttentionOverlayChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _flushActiveFileEditorDrafts();
    // Clean up scroll callback using saved reference
    _chatProvider?.setScrollToBottomCallback(null);
    _chatProvider?.setChatRouteActive(false);
    unawaited(_chatProvider?.setForegroundActive(false));
    _chatProvider?.removeListener(_handleChatProviderChanged);
    _scrollToBottomRequestToken += 1;
    _appProvider?.removeListener(_handleAppProviderChange);
    _projectProvider?.removeListener(_handleProjectProviderChange);
    _notificationTapSubscription?.cancel();
    _settingsProvider?.removeListener(_handleSettingsChanged);
    _projectScopeTransitionGeneration += 1;
    _projectScopeLoadingOverlayTimer?.cancel();
    _sessionTabHintGeneration += 1;
    _sessionTabSnackBarExpirationTimer?.cancel();
    _desktopWindowChromeController?.detach(this);
    _sessionAttentionOverlayController
      ?..removeListener(_handleSessionAttentionOverlayChanged)
      ..dispose();
    _sessionAttentionOverlayRefreshTimer?.cancel();
    _clearBackgroundPermissionAutoApproveContextBestEffort(
      reason: 'chat-page-dispose',
    );
    _serverAlertRevealTimer?.cancel();
    _foregroundWarningUiRefreshTimer?.cancel();
    _foregroundWarningSnackbarTimer?.cancel();
    _unhealthySnackbarDebounceTimer?.cancel();
    _initialDataRecoveryTimer?.cancel();
    _flushPendingComposerDraftPersistence();
    _composerStatusShowTimer?.cancel();
    _composerStatusHideTimer?.cancel();
    _composerStopHintTimer?.cancel();
    _backgroundRealtimeHoldTimer?.cancel();
    _tipRotationTimer?.cancel();
    _timelineSearchDebounceTimer?.cancel();
    _timelineSearchController.dispose();
    _timelineSearchFocusNode.dispose();
    _scrollController.removeListener(_handleScrollChanged);
    HardwareKeyboard.instance.removeHandler(_handleGlobalShortcutKeyEvent);
    if (_isDesktopRuntime) {
      windowManager.removeListener(this);
    }
    WidgetsBinding.instance.removeObserver(this);

    _scrollController.dispose();
    _fileViewerScrollController.dispose();
    _inputFocusNode.dispose();
    _sessionSearchController.dispose();
    _sessionSearchFocusNode.dispose();
    _terminalController.dispose();
    for (final fileState in _fileContextStates.values) {
      fileState.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppInForeground = state == AppLifecycleState.resumed;
    if (!_isAppInForeground) {
      _flushActiveFileEditorDrafts();
      // Persist pending session-tab state before the process can be killed in
      // the background; the debounced write may otherwise never run.
      unawaited(_chatProvider?.flushAllSessionTabsPersistence());
      _flushPendingComposerDraftPersistence();
    }
    final provider = _chatProvider;
    if (provider != null) {
      provider.setAppInForeground(
        _isAppInForeground,
        isVisibleForSessionAttention:
            state == AppLifecycleState.resumed ||
            state == AppLifecycleState.inactive,
      );
      final foregroundPolicyTask = _applyForegroundPolicy(
        reason: 'app-lifecycle-${state.name}',
        forceResume: _isAndroidRuntime && _isAppInForeground,
      );
      unawaited(
        _syncBackgroundPermissionAutoApproveContext(
          reason: 'app-lifecycle-${state.name}',
        ),
      );
      if (_isAppInForeground) {
        _startForegroundWarningGrace();
        if (_isChatScreenActive()) {
          _lastResumeRefreshAt = DateTime.now();
          _resumeRefreshViewportRestorePending = true;
          _returnRevealGeneration += 1;
          unawaited(
            foregroundPolicyTask.then<void>(
              (_) {
                _resumeRefreshViewportRestorePending = false;
                if (!mounted || !_isAppInForeground || !_isChatScreenActive()) {
                  return;
                }
                _handleReturnToChat(
                  provider,
                  reason: 'app-resumed-refresh-complete',
                );
              },
              onError: (Object error, StackTrace stackTrace) {
                _resumeRefreshViewportRestorePending = false;
                AppLogger.warn(
                  'Foreground resume policy failed',
                  error: error,
                  stackTrace: stackTrace,
                );
              },
            ),
          );
        } else {
          unawaited(foregroundPolicyTask);
        }
        _handleReturnToChat(provider, reason: 'app-resumed');
      } else {
        unawaited(foregroundPolicyTask);
      }
    }
    if (_isAppInForeground &&
        defaultTargetPlatform == TargetPlatform.iOS &&
        _sessionAttentionOverlayController != null) {
      unawaited(
        _sessionAttentionOverlayController!.refresh(
          activeServerId: _appProvider?.activeServerId,
        ),
      );
    }
  }

  // Desktop window visibility: suppress rebuilds when minimized,
  // resume when restored/focused. Blur (losing focus while visible) is a no-op
  // because the window content is still on-screen.
  @override
  void onWindowMinimize() {
    _isAppInForeground = false;
    _flushActiveFileEditorDrafts();
    _chatProvider?.setAppInForeground(false);
    unawaited(_applyForegroundPolicy(reason: 'window-minimize'));
  }

  @override
  void onWindowRestore() {
    _isAppInForeground = true;
    _chatProvider?.setAppInForeground(true);
    _returnRevealGeneration += 1;
    unawaited(_applyForegroundPolicy(reason: 'window-restore'));
    _startForegroundWarningGrace();
    final provider = _chatProvider;
    if (provider != null) {
      _handleReturnToChat(provider, reason: 'window-restore');
      _scheduleQueuedDesktopViewportRestore(provider, reason: 'window-restore');
    }
  }

  @override
  void onWindowFocus() {
    if (!_isAppInForeground) {
      _isAppInForeground = true;
      _chatProvider?.setAppInForeground(true);
      _returnRevealGeneration += 1;
      unawaited(_applyForegroundPolicy(reason: 'window-focus'));
      _startForegroundWarningGrace();
      final provider = _chatProvider;
      if (provider != null) {
        _handleReturnToChat(provider, reason: 'window-focus');
        _scheduleQueuedDesktopViewportRestore(provider, reason: 'window-focus');
      }
    }
  }

  bool get _isDesktopRuntime {
    if (kIsWeb) {
      return false;
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.linux ||
      TargetPlatform.macOS ||
      TargetPlatform.windows => true,
      _ => false,
    };
  }

  bool get _isMobileRuntime {
    if (kIsWeb) {
      return false;
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS => true,
      _ => false,
    };
  }

  bool get _isAndroidRuntime {
    if (kIsWeb) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.android;
  }

  void _setState(VoidCallback fn) {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(fn);
        }
      });
    } else {
      setState(fn);
    }
  }

  void _loadInitialData() {
    final chatProvider = context.read<ChatProvider>();

    // Set scroll to bottom callback
    chatProvider.setScrollToBottomCallback(_requestPassiveScrollToBottom);
    unawaited(_applyForegroundPolicy(reason: 'chat-load-initial-data'));

    // Technical comment translated to English.
    _initializeChatProvider(chatProvider);
  }

  Future<void> _initializeChatProvider(ChatProvider chatProvider) async {
    final appProvider = context.read<AppProvider>();
    final projectProvider = context.read<ProjectProvider>();
    try {
      await appProvider.initialize();
      await projectProvider.initializeProject();
      if (appProvider.activeServer == null) {
        _clearInitialDataRecoveryState();
        chatProvider.clearError();
        return;
      }
      await appProvider.checkConnection(
        directory: projectProvider.currentDirectory,
      );
      chatProvider.warmupProvidersRefresh(reason: 'chat-startup');

      // Technical comment translated to English.
      await chatProvider.loadSessions();
      if (!appProvider.isConnected) {
        // Offline startup can still restore cached data, but it needs a full
        // recovery pass once the backend is reachable again.
        _markInitialDataRecoveryNeeded();
        return;
      }
      _clearInitialDataRecoveryState();
    } catch (e) {
      if (appProvider.activeServer != null && !appProvider.isConnected) {
        _markInitialDataRecoveryNeeded();
      } else {
        _clearInitialDataRecoveryState();
      }
      // Technical comment translated to English.
      chatProvider.clearError();
      AppLogger.error('Chat initialization failed', error: e);
    }
  }

  void _handleAppProviderChange() {
    final appProvider = _appProvider;
    if (appProvider == null) {
      return;
    }
    final previousServerId = _lastServerId;
    final currentServerId = appProvider.activeServerId;
    final currentConnected = appProvider.isConnected;
    final activeServer = appProvider.activeServer;
    final currentHealth = activeServer == null
        ? ServerHealthStatus.unknown
        : appProvider.healthFor(activeServer.id);
    final serverChanged = currentServerId != _lastServerId;

    if (serverChanged) {
      _syncEditorAutosaveForActiveContext(enabled: false);
      _lastServerId = currentServerId;
      _lastServerConnectionState = currentConnected;
      _lastActiveServerHealthStatus = currentHealth;
      _terminalSessionSignature = null;
      if (_settingsProvider?.terminalPanelVisible == true) {
        unawaited(_startTerminalForCurrentProject(force: true));
      } else {
        unawaited(_terminalController.stop());
      }
      if (currentServerId != null) {
        unawaited(_handleServerScopeChange(previousServerId: previousServerId));
      } else if (previousServerId != null &&
          previousServerId.trim().isNotEmpty) {
        _clearBackgroundPermissionAutoApproveContextBestEffort(
          reason: 'server-changed',
          serverId: previousServerId,
        );
      }
      return;
    }

    final previousHealth = _lastActiveServerHealthStatus;
    _lastActiveServerHealthStatus = currentHealth;
    if (previousHealth == ServerHealthStatus.healthy &&
        currentHealth == ServerHealthStatus.unhealthy) {
      _showServerUnhealthyNoticeWithConfirmation();
    } else if (previousHealth == ServerHealthStatus.unhealthy &&
        currentHealth != ServerHealthStatus.unhealthy) {
      _cancelPendingServerUnhealthyNotice();
    }

    final wasConnected = _lastServerConnectionState;
    _lastServerConnectionState = currentConnected;
    if (_needsInitialDataRecovery &&
        !currentConnected &&
        currentHealth != ServerHealthStatus.healthy) {
      _cancelPendingInitialDataRecovery();
    }
    final shouldScheduleInitialDataRecovery =
        _needsInitialDataRecovery &&
        ((wasConnected == false && currentConnected) ||
            (previousHealth != ServerHealthStatus.healthy &&
                currentHealth == ServerHealthStatus.healthy));
    if (shouldScheduleInitialDataRecovery) {
      _scheduleInitialDataRecovery(
        delay: _initialDataRecoveryDebounce,
        reason: currentConnected
            ? 'app-provider-connected'
            : 'server-health-healthy',
      );
      return;
    }
    if (wasConnected == false && currentConnected) {
      unawaited(_handleServerReconnected());
    }
  }

  void _handleProjectProviderChange() {
    final contextKey = _projectProvider?.contextKey;
    if (contextKey != null && contextKey != _lastFileEditorAutosaveContextKey) {
      final previousContextKey = _lastFileEditorAutosaveContextKey;
      if (previousContextKey != null &&
          _settingsProvider?.editorAutosaveEnabled == true) {
        _flushFileEditorContext(
          contextKey: previousContextKey,
          allowInactiveContext: true,
        );
      }
      _lastFileEditorAutosaveContextKey = contextKey;
      _syncEditorAutosaveForActiveContext(
        enabled: _settingsProvider?.editorAutosaveEnabled == true,
      );
    }
    if (_settingsProvider?.terminalPanelVisible != true) {
      return;
    }
    unawaited(_startTerminalForCurrentProject());
  }

  void _markInitialDataRecoveryNeeded() {
    _needsInitialDataRecovery = true;
    _initialDataRecoveryAttemptCount = 0;
  }

  void _clearInitialDataRecoveryState() {
    _needsInitialDataRecovery = false;
    _initialDataRecoveryAttemptCount = 0;
    _cancelPendingInitialDataRecovery();
  }

  void _cancelPendingInitialDataRecovery() {
    _initialDataRecoveryTimer?.cancel();
    _initialDataRecoveryTimer = null;
  }

  Duration _initialDataRecoveryRetryDelay(int attemptCount) {
    if (attemptCount <= 1) {
      return const Duration(seconds: 1);
    }
    if (attemptCount == 2) {
      return const Duration(seconds: 2);
    }
    return const Duration(seconds: 4);
  }

  void _scheduleInitialDataRecovery({
    required Duration delay,
    required String reason,
  }) {
    if (!_needsInitialDataRecovery || !mounted) {
      return;
    }
    _initialDataRecoveryTimer?.cancel();
    AppLogger.info(
      'initial_data_recovery_scheduled reason=$reason delayMs=${delay.inMilliseconds} attempts=$_initialDataRecoveryAttemptCount',
    );
    _initialDataRecoveryTimer = Timer(delay, () {
      _initialDataRecoveryTimer = null;
      unawaited(_runInitialDataRecovery(reason: reason));
    });
  }

  void _retryInitialDataRecovery({required String reason}) {
    if (!_needsInitialDataRecovery || !mounted) {
      return;
    }
    _initialDataRecoveryAttemptCount += 1;
    _scheduleInitialDataRecovery(
      delay: _initialDataRecoveryRetryDelay(_initialDataRecoveryAttemptCount),
      reason: reason,
    );
  }

  Future<void> _runInitialDataRecovery({required String reason}) async {
    if (!mounted ||
        !_needsInitialDataRecovery ||
        _initialDataRecoveryInFlight) {
      return;
    }
    if (!_isChatScreenActive()) {
      return;
    }

    final appProvider = _appProvider ?? context.read<AppProvider>();
    final projectProvider = context.read<ProjectProvider>();
    final chatProvider = _chatProvider ?? context.read<ChatProvider>();
    final expectedServerId = appProvider.activeServerId;
    if (expectedServerId == null) {
      return;
    }

    _initialDataRecoveryInFlight = true;
    AppLogger.info(
      'initial_data_recovery_start reason=$reason attempts=$_initialDataRecoveryAttemptCount server=$expectedServerId',
    );

    try {
      await appProvider.checkConnection(
        directory: projectProvider.currentDirectory,
      );
      if (!mounted || appProvider.activeServerId != expectedServerId) {
        return;
      }
      if (!appProvider.isConnected) {
        AppLogger.info(
          'initial_data_recovery_waiting_for_backend reason=$reason server=$expectedServerId',
        );
        _retryInitialDataRecovery(reason: 'connection-not-ready');
        return;
      }

      final previousContextKey = projectProvider.contextKey;
      await projectProvider.initializeProject(forceReload: true);
      if (!mounted || appProvider.activeServerId != expectedServerId) {
        return;
      }
      if (projectProvider.status == ProjectStatus.error ||
          projectProvider.currentProject == null) {
        AppLogger.warn(
          'Initial data recovery could not restore project context yet',
        );
        _retryInitialDataRecovery(reason: 'project-context-not-ready');
        return;
      }

      final contextChanged = projectProvider.contextKey != previousContextKey;
      if (contextChanged) {
        await chatProvider.onProjectScopeChanged();
      } else {
        await chatProvider.loadSessions(
          preserveVisibleState: chatProvider.sessions.isNotEmpty,
        );
      }
      if (!mounted || appProvider.activeServerId != expectedServerId) {
        return;
      }
      if (chatProvider.state == ChatState.error) {
        AppLogger.warn('Initial data recovery session reload failed; retrying');
        _retryInitialDataRecovery(reason: 'session-reload-failed');
        return;
      }

      chatProvider.warmupProvidersRefresh(reason: 'offline-start-recovery');
      if (chatProvider.currentSession != null) {
        await chatProvider.refreshActiveSessionView(
          reason: 'offline-start-recovery',
        );
      }

      _clearInitialDataRecoveryState();
      _scheduleAutoApprovePermissionDrain(reason: 'offline-start-recovery');
      AppLogger.info(
        'initial_data_recovery_complete server=$expectedServerId context=${projectProvider.contextKey}',
      );
    } catch (e, stackTrace) {
      AppLogger.warn(
        'Initial data recovery failed unexpectedly',
        error: e,
        stackTrace: stackTrace,
      );
      _retryInitialDataRecovery(reason: 'unexpected-recovery-error');
    } finally {
      _initialDataRecoveryInFlight = false;
    }
  }

  SnackBar _buildChatPageSnackBar({
    required Widget content,
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 4),
    SnackBarBehavior behavior = SnackBarBehavior.floating,
    bool? showCloseIcon,
    bool? persist,
  }) {
    final dismissOnTap = action == null;
    return SnackBar(
      behavior: behavior,
      duration: duration,
      action: action,
      showCloseIcon: showCloseIcon,
      persist: persist,
      padding: dismissOnTap ? EdgeInsets.zero : null,
      content: dismissOnTap
          ? GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () =>
                  ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar(),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: SizedBox(width: double.infinity, child: content),
              ),
            )
          : content,
    );
  }

  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>?
  _showChatPageSnackBar({
    required Widget content,
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 4),
    bool hideCurrent = true,
    SnackBarBehavior behavior = SnackBarBehavior.floating,
    bool? showCloseIcon,
    bool? persist,
  }) {
    if (!mounted) {
      return null;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return null;
    }
    if (hideCurrent) {
      messenger.hideCurrentSnackBar();
    }
    return messenger.showSnackBar(
      _buildChatPageSnackBar(
        content: content,
        action: action,
        duration: duration,
        behavior: behavior,
        showCloseIcon: showCloseIcon,
        persist: persist,
      ),
    );
  }

  void _showChatPageMessageSnackBar(
    String message, {
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 4),
    bool hideCurrent = true,
    SnackBarBehavior behavior = SnackBarBehavior.floating,
    bool? showCloseIcon,
    bool? persist,
  }) {
    _showChatPageSnackBar(
      content: Text(message),
      action: action,
      duration: duration,
      hideCurrent: hideCurrent,
      behavior: behavior,
      showCloseIcon: showCloseIcon,
      persist: persist,
    );
  }

  void _scheduleComposerDraftPersistence({
    required String? sessionId,
    required ChatComposerDraft? draft,
  }) {
    final normalizedSessionId = sessionId?.trim();
    if (normalizedSessionId == null || normalizedSessionId.isEmpty) {
      return;
    }
    _composerDraftPersistTimer?.cancel();
    _composerDraftStagedSessionId = normalizedSessionId;
    _composerDraftStagedDraft = draft;
    if (draft == null || !draft.hasContent) {
      unawaited(
        (_chatProvider ?? context.read<ChatProvider>())
            .persistComposerDraftForSession(
              sessionId: normalizedSessionId,
              draft: null,
            ),
      );
      return;
    }
    _composerDraftPersistTimer = Timer(const Duration(milliseconds: 250), () {
      _composerDraftPersistTimer = null;
      unawaited(
        (_chatProvider ?? context.read<ChatProvider>())
            .persistComposerDraftForSession(
              sessionId: normalizedSessionId,
              draft: draft,
            ),
      );
    });
  }

  /// Writes a still-debounced composer draft immediately. Called when the app
  /// backgrounds or the page disposes before the debounce timer fires;
  /// without this a process death in that window loses the last keystrokes.
  void _flushPendingComposerDraftPersistence() {
    final timer = _composerDraftPersistTimer;
    final stagedSessionId = _composerDraftStagedSessionId;
    final stagedDraft = _composerDraftStagedDraft;
    timer?.cancel();
    _composerDraftPersistTimer = null;
    _composerDraftStagedSessionId = null;
    _composerDraftStagedDraft = null;
    if (timer == null ||
        stagedSessionId == null ||
        stagedSessionId.isEmpty ||
        stagedDraft == null) {
      return;
    }
    final provider = _chatProvider;
    if (provider == null) {
      return;
    }
    unawaited(
      provider.persistComposerDraftForSession(
        sessionId: stagedSessionId,
        draft: stagedDraft,
      ),
    );
  }

  void _cancelPendingServerUnhealthyNotice() {
    _foregroundWarningSnackbarTimer?.cancel();
    _foregroundWarningSnackbarTimer = null;
    _unhealthySnackbarDebounceTimer?.cancel();
    _unhealthySnackbarDebounceTimer = null;
  }

  void _showServerUnhealthyNotice() {
    _showChatPageSnackBar(
      content: Text(context.l10n.chatActiveServerUnhealthy),
    );
  }

  // Resume-time health and connectivity probes can briefly report stale failure
  // states while sockets and reachability settle, so warning-only UI waits for
  // a short confirmation window before escalating.
  void _startForegroundWarningGrace() {
    _foregroundWarningGraceEndsAt = DateTime.now().add(
      _foregroundWarningConfirmationDelay,
    );
    _foregroundWarningUiRefreshTimer?.cancel();
    _foregroundWarningSnackbarTimer?.cancel();
    _foregroundWarningUiRefreshTimer = Timer(
      _foregroundWarningConfirmationDelay,
      () {
        _foregroundWarningUiRefreshTimer = null;
        if (!mounted) {
          return;
        }
        _setState(() {});
      },
    );
  }

  bool _isForegroundWarningGraceActive() {
    final endsAt = _foregroundWarningGraceEndsAt;
    return _isAppInForeground &&
        endsAt != null &&
        DateTime.now().isBefore(endsAt);
  }

  bool _shouldDeferForegroundWarningUi({
    required ChatProvider chatProvider,
    required AppProvider appProvider,
  }) {
    if (!_isForegroundWarningGraceActive()) {
      return false;
    }
    final health = _activeServerHealth(appProvider);
    return !appProvider.isConnected ||
        health == ServerHealthStatus.unhealthy ||
        _isRecoverableSyncState(chatProvider: chatProvider);
  }

  void _showServerUnhealthyNoticeWithConfirmation() {
    _cancelPendingServerUnhealthyNotice();
    _unhealthySnackbarDebounceTimer = Timer(_unhealthySnackbarDebounce, () {
      _unhealthySnackbarDebounceTimer = null;
      if (!mounted) {
        return;
      }
      _showServerUnhealthyNoticeAfterForegroundGrace();
    });
  }

  void _showServerUnhealthyNoticeAfterForegroundGrace() {
    final chatProvider = _chatProvider;
    final appProvider = _appProvider;
    if (chatProvider == null || appProvider == null) {
      _showServerUnhealthyNotice();
      return;
    }
    if (!_shouldDeferForegroundWarningUi(
      chatProvider: chatProvider,
      appProvider: appProvider,
    )) {
      _showServerUnhealthyNotice();
      return;
    }
    final endsAt = _foregroundWarningGraceEndsAt;
    if (endsAt == null) {
      return;
    }
    final remaining = endsAt.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      _showServerUnhealthyNotice();
      return;
    }
    _foregroundWarningSnackbarTimer?.cancel();
    _foregroundWarningSnackbarTimer = Timer(remaining, () {
      _foregroundWarningSnackbarTimer = null;
      if (!mounted) {
        return;
      }
      final currentChatProvider = _chatProvider;
      final currentAppProvider = _appProvider;
      if (currentChatProvider == null || currentAppProvider == null) {
        return;
      }
      if (_shouldDeferForegroundWarningUi(
        chatProvider: currentChatProvider,
        appProvider: currentAppProvider,
      )) {
        return;
      }
      if (_activeServerHealth(currentAppProvider) ==
          ServerHealthStatus.unhealthy) {
        _showServerUnhealthyNotice();
      }
    });
  }

  Future<void> _handleServerReconnected() async {
    if (!mounted || !_isChatScreenActive()) {
      return;
    }
    final lastResumeRefreshAt = _lastResumeRefreshAt;
    if (lastResumeRefreshAt != null &&
        DateTime.now().difference(lastResumeRefreshAt) <
            const Duration(seconds: 2)) {
      return;
    }
    final chatProvider = _chatProvider ?? context.read<ChatProvider>();
    await chatProvider.refreshActiveSessionView(
      reason: 'app-provider-reconnected',
    );
    _scheduleAutoApprovePermissionDrain(reason: 'server-reconnected');
  }

  Future<void> _handleMobileBackPress() async {
    if (!_isMobileRuntime || !mounted) {
      return;
    }
    if (_restoreMaximizedTerminalIfNeeded()) {
      return;
    }
    final chatProvider = _chatProvider ?? context.read<ChatProvider>();
    if (_isSubConversationSession(chatProvider.currentSession)) {
      await _returnToParentConversation(chatProvider);
      return;
    }
    final scaffoldState = _scaffoldKey.currentState;
    if (!(scaffoldState?.isDrawerOpen ?? false)) {
      scaffoldState?.openDrawer();
      return;
    }
    if (!kIsWeb) {
      await SystemNavigator.pop();
    }
  }

  void _scheduleNotificationTap(NotificationTapPayload payload) {
    AppLogger.runTask(
      'notification_tap_schedule',
      (_) {
        _pendingNotificationTap = payload;
        _pendingNotificationTapGeneration += 1;
        _notificationTapTask ??= _drainNotificationTapQueue();
      },
      tags: const <String>{'notification:tap'},
      context: <String, Object?>{
        'category': payload.category,
        if (payload.sessionId != null)
          'sessionId': AppLogger.safeContextId(payload.sessionId),
        if (payload.directory != null)
          'directoryHash': AppLogger.safeContextId(payload.directory),
      },
    );
  }

  Future<void> _drainNotificationTapQueue() async {
    try {
      while (mounted) {
        final payload = _pendingNotificationTap;
        final generation = _pendingNotificationTapGeneration;
        if (payload == null) {
          break;
        }
        _pendingNotificationTap = null;
        await _handleNotificationTap(payload, generation);
      }
    } finally {
      _notificationTapTask = null;
      if (mounted && _pendingNotificationTap != null) {
        _notificationTapTask = _drainNotificationTapQueue();
      }
    }
  }

  Future<void> _handleNotificationTap(
    NotificationTapPayload payload,
    int generation,
  ) async {
    if (!mounted) {
      return;
    }
    final action = payload.action?.trim() ?? 'open';
    if (action == 'stop') {
      await context.read<SettingsProvider>().setSessionAttentionPresentation(
        SessionAttentionPresentation.off,
      );
      return;
    }
    if (action == 'expand' || action == 'collapse') {
      await context.read<SettingsProvider>().setSessionAttentionPresentation(
        action == 'expand'
            ? SessionAttentionPresentation.panel
            : SessionAttentionPresentation.bubble,
      );
      return;
    }
    final snapshotId = payload.snapshotId?.trim();
    if (action == 'dismiss') {
      if (snapshotId != null &&
          snapshotId.isNotEmpty &&
          di.sl.isRegistered<SessionAttentionCompletionResolver>()) {
        if (di.sl.isRegistered<ReadAloudService>()) {
          await di.sl<ReadAloudService>().stopIfReading(snapshotId);
        }
        final resolver = di.sl<SessionAttentionCompletionResolver>();
        final durable = await resolver.itemBySnapshotId(snapshotId);
        if (durable != null) {
          await resolver.dismissSnapshot(snapshotId);
        } else {
          final serverId = payload.serverId?.trim() ?? '';
          final directory = payload.directory?.trim() ?? '';
          final sessionId = payload.sessionId?.trim() ?? '';
          final identity = SessionAttentionIdentity(
            serverId: serverId,
            directory: directory,
            rootSessionId: sessionId,
          ).normalized();
          final prefix = '${identity.key}::';
          if (identity.isValid && snapshotId.startsWith(prefix)) {
            await resolver.suppressLiveIdentity(
              identity: identity,
              contentDigest: snapshotId.substring(prefix.length),
            );
          }
        }
      }
      return;
    }
    if (action == 'read') {
      if (snapshotId == null ||
          snapshotId.isEmpty ||
          !di.sl.isRegistered<SessionAttentionCompletionResolver>() ||
          !di.sl.isRegistered<ReadAloudService>()) {
        return;
      }
      final item = await di
          .sl<SessionAttentionCompletionResolver>()
          .itemBySnapshotId(snapshotId);
      if (item == null ||
          item.speechText.isEmpty ||
          item.transportCapability ==
              SessionAttentionTransportCapability.reopenRequired) {
        return;
      }
      final readAloudService = di.sl<ReadAloudService>();
      if (readAloudService.activeMessageId == snapshotId) {
        await readAloudService.stopIfReading(snapshotId);
        await di.sl<SessionAttentionCompletionResolver>().publishCurrent();
        return;
      }
      if (di.sl.isRegistered<CellularDataSaverService>()) {
        di.sl<CellularDataSaverService>().noteExplicitUserAction(
          reason: 'session-attention-read',
        );
      }
      final configuration = TtsConfiguration.fromSettings(
        context.read<SettingsProvider>().settings,
      );
      await readAloudService.speak(
        messageId: item.snapshotId,
        text: item.speechText,
        provider: configuration.provider,
        rate: configuration.rate,
        pitch: configuration.pitch,
        voiceId: configuration.voiceId,
        voiceLocale: configuration.voiceLocale,
        model: configuration.model,
        baseUrl: configuration.baseUrl,
        responseFormat: configuration.responseFormat,
      );
      await di.sl<SessionAttentionCompletionResolver>().publishCurrent();
      return;
    }
    final sessionId = payload.sessionId?.trim();
    if (sessionId == null || sessionId.isEmpty) {
      return;
    }

    final targetServerId = payload.serverId?.trim();
    if (targetServerId != null && targetServerId.isNotEmpty) {
      final appProvider = context.read<AppProvider>();
      if (appProvider.serverProfiles.every(
        (profile) => profile.id != targetServerId,
      )) {
        return;
      }
      if (appProvider.activeServerId != targetServerId) {
        final activated = await appProvider.setActiveServer(
          targetServerId,
          blockUnhealthy: false,
        );
        if (!mounted ||
            generation != _pendingNotificationTapGeneration ||
            !activated) {
          return;
        }
        final scopedChatProvider =
            _chatProvider ?? context.read<ChatProvider>();
        await scopedChatProvider.onServerScopeChanged();
        if (!mounted || generation != _pendingNotificationTapGeneration) {
          return;
        }
      }
    }

    final targetDirectory = payload.directory?.trim();
    if (targetDirectory != null && targetDirectory.isNotEmpty) {
      final currentDirectory = context.read<ProjectProvider>().currentDirectory;
      if (currentDirectory != targetDirectory) {
        await _switchDirectoryContext(targetDirectory);
        if (!mounted || generation != _pendingNotificationTapGeneration) {
          return;
        }
      }
    }

    final chatProvider = _chatProvider ?? context.read<ChatProvider>();
    var reloadAttempts = 0;

    for (var attempt = 0; attempt < _notificationTapMaxAttempts; attempt += 1) {
      final targetSession = chatProvider.sessions
          .where((item) => item.id == sessionId)
          .firstOrNull;
      if (targetSession != null) {
        await chatProvider.selectSession(targetSession);
        if (!mounted || generation != _pendingNotificationTapGeneration) {
          return;
        }
        if (snapshotId != null &&
            snapshotId.isNotEmpty &&
            di.sl.isRegistered<SessionAttentionCompletionResolver>()) {
          await di.sl<SessionAttentionCompletionResolver>().consumeSnapshot(
            snapshotId,
          );
        }
        if (di.sl.isRegistered<ReadAloudService>()) {
          await di.sl<ReadAloudService>().stop();
        }
        if (defaultTargetPlatform == TargetPlatform.iOS &&
            _sessionAttentionOverlayController != null) {
          await _sessionAttentionOverlayController!.refresh(
            activeServerId: targetServerId,
          );
        }
        return;
      }

      if (chatProvider.state != ChatState.loading &&
          reloadAttempts < _notificationTapReloadAttempts) {
        reloadAttempts += 1;
        await chatProvider.loadSessions(userInitiated: true);
        if (!mounted || generation != _pendingNotificationTapGeneration) {
          return;
        }
        continue;
      }

      if (attempt + 1 >= _notificationTapMaxAttempts) {
        return;
      }

      await Future<void>.delayed(_notificationTapRetryInterval);
      if (!mounted || generation != _pendingNotificationTapGeneration) {
        return;
      }
    }
  }

  double _lastKnownMaxScrollExtent = 0;

  ({bool isMobile, bool showConversationPane}) _currentTourLayout(
    SettingsProvider settingsProvider,
  ) {
    final width = MediaQuery.sizeOf(context).width;
    final sizeClass = WindowSizeClass.fromWidth(width);
    final compactLayout = sizeClass == WindowSizeClass.compact;
    final mediumLayout = sizeClass == WindowSizeClass.medium;
    final conversationsPaneEnabled = settingsProvider.isDesktopPaneVisible(
      DesktopPane.conversations,
    );
    final showConversationPane =
        !compactLayout &&
        (mediumLayout ? conversationsPaneEnabled : true) &&
        conversationsPaneEnabled;
    return (
      isMobile: compactLayout || (mediumLayout && !showConversationPane),
      showConversationPane: showConversationPane,
    );
  }

  GlobalKey _sidebarAccessTourKey({
    required bool isMobile,
    required bool showConversationPane,
  }) {
    if (isMobile) {
      return _drawerAccessTourKey;
    }
    return showConversationPane
        ? _projectContextTourKey
        : _desktopSidebarMenuTourKey;
  }

  GlobalKey _sidebarAccessTourTargetKey({
    required bool isMobile,
    required bool showConversationPane,
  }) {
    if (isMobile) {
      return _drawerAccessTourTargetKey;
    }
    return showConversationPane
        ? _projectContextTourTargetKey
        : _desktopSidebarMenuTourTargetKey;
  }

  Widget _buildTourTarget({
    required GlobalKey showcaseKey,
    required GlobalKey targetKey,
    required Widget child,
    required String title,
    required String description,
    required TooltipPosition tooltipPosition,
    bool includePrevious = false,
    String? primaryActionLabel,
    VoidCallback? onNext,
  }) {
    return ChatTourShowcase(
      showcaseKey: showcaseKey,
      targetKey: targetKey,
      title: title,
      description: description,
      tooltipPosition: tooltipPosition,
      includePrevious: includePrevious,
      primaryActionLabel: primaryActionLabel ?? context.l10n.chatActionNext,
      onPrimaryAction: onNext,
      onSkipAction: _handlePostOnboardingTourSkip,
      targetBorderRadius: AppShapes.borderLarge,
      child: child,
    );
  }

  bool _isTourTargetReady(GlobalKey key) {
    final targetContext = key.currentContext;
    if (targetContext == null) {
      return false;
    }
    final renderObject = targetContext.findRenderObject();
    if (renderObject is! RenderBox) {
      return false;
    }
    return renderObject.attached && renderObject.hasSize;
  }

  void _resetPostOnboardingTourTransientState() {
    _postOnboardingTourRunToken += 1;
    _tourPhase = _PostOnboardingTourPhase.idle;
    _tourStartScheduled = false;
    _tourAdvancingToComposerPhase = false;
    _tourExplicitSkipRequested = false;
  }

  void _handlePostOnboardingTourSkip() {
    _tourExplicitSkipRequested = true;
    ShowcaseView.get().dismiss();
  }

  int _startPostOnboardingTourRun() {
    _postOnboardingTourRunToken += 1;
    _tourStartScheduled = true;
    return _postOnboardingTourRunToken;
  }

  bool _isPostOnboardingTourRunActive(int token) {
    return mounted && token == _postOnboardingTourRunToken;
  }

  void _flushPendingPostOnboardingTourAutoStart() {
    final settingsProvider = _settingsProvider;
    if (settingsProvider == null ||
        !_queuedPendingPostOnboardingTourAutoStart ||
        !settingsProvider.pendingPostOnboardingChatTour ||
        _tourStartScheduled ||
        !_isChatScreenActive()) {
      return;
    }
    final runToken = _startPostOnboardingTourRun();
    Future<void>.delayed(_postOnboardingTourStartDelay, () {
      if (!_isPostOnboardingTourRunActive(runToken)) {
        return;
      }
      // Delayed startup may fire while idle; request a frame so the
      // post-frame callback is not left waiting for unrelated UI work.
      WidgetsBinding.instance.scheduleFrame();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isPostOnboardingTourRunActive(runToken)) {
          return;
        }
        _startIntroPostOnboardingTour(attempt: 0, runToken: runToken);
      });
    });
  }

  bool _startShowcaseIfReady(
    List<({GlobalKey showcase, GlobalKey target})> targets, {
    Duration delay = _postOnboardingTourStartDelay,
  }) {
    final allMounted = targets.every(
      (target) => _isTourTargetReady(target.target),
    );
    final showcaseState = _showcaseWidgetKey.currentState;
    if (showcaseState == null || !allMounted) {
      return false;
    }
    showcaseState.startShowCase(
      targets.map((target) => target.showcase).toList(growable: false),
      delay: delay,
    );
    return true;
  }

  void _startIntroPostOnboardingTour({
    required int attempt,
    required int runToken,
  }) {
    if (!_isPostOnboardingTourRunActive(runToken)) {
      return;
    }
    final settingsProvider =
        _settingsProvider ?? context.read<SettingsProvider>();
    final layout = _currentTourLayout(settingsProvider);
    if (layout.isMobile) {
      _closeDrawerIfNeeded(closeOnSelect: true);
    }
    final targets = <({GlobalKey showcase, GlobalKey target})>[
      (
        showcase: _sidebarAccessTourKey(
          isMobile: layout.isMobile,
          showConversationPane: layout.showConversationPane,
        ),
        target: _sidebarAccessTourTargetKey(
          isMobile: layout.isMobile,
          showConversationPane: layout.showConversationPane,
        ),
      ),
      if (!layout.isMobile)
        (showcase: _newChatTourKey, target: _newChatTourTargetKey),
    ];
    if (!_startShowcaseIfReady(targets)) {
      if (attempt >= _postOnboardingTourMaxAttempts) {
        _resetPostOnboardingTourTransientState();
        return;
      }
      Future<void>.delayed(_postOnboardingTourRetryDelay, () {
        if (!mounted) {
          return;
        }
        // The retry callback can fire while the tree is otherwise idle. Ensure
        // a frame exists so the post-frame retry is not left waiting forever.
        WidgetsBinding.instance.scheduleFrame();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_isPostOnboardingTourRunActive(runToken)) {
            return;
          }
          _startIntroPostOnboardingTour(
            attempt: attempt + 1,
            runToken: runToken,
          );
        });
      });
      return;
    }
    _queuedPendingPostOnboardingTourAutoStart = false;
    _tourPhase = _PostOnboardingTourPhase.intro;
  }

  Future<void> _advancePostOnboardingTourToComposer() async {
    if (_tourAdvancingToComposerPhase) {
      return;
    }
    final runToken = _postOnboardingTourRunToken;
    _tourAdvancingToComposerPhase = true;
    _tourPhase = _PostOnboardingTourPhase.composer;
    ShowcaseView.get().dismiss();

    final scaffoldState = _scaffoldKey.currentState;
    if (scaffoldState?.isDrawerOpen ?? false) {
      scaffoldState?.closeDrawer();
      await Future<void>.delayed(_postOnboardingTourRetryDelay);
      if (!mounted) {
        return;
      }
    }

    final chatProvider = context.read<ChatProvider>();
    if (chatProvider.currentSession != null ||
        !chatProvider.isDraftingNewChat) {
      await chatProvider.beginNewChatDraft();
    }
    if (!_isPostOnboardingTourRunActive(runToken)) {
      return;
    }
    Future<void>.delayed(_postOnboardingTourStartDelay, () {
      if (!_isPostOnboardingTourRunActive(runToken)) {
        return;
      }
      // Delayed startup may fire while idle; request a frame so the
      // post-frame callback is not left waiting for unrelated UI work.
      WidgetsBinding.instance.scheduleFrame();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isPostOnboardingTourRunActive(runToken)) {
          return;
        }
        _startComposerPostOnboardingTour(attempt: 0, runToken: runToken);
      });
    });
  }

  void _startComposerPostOnboardingTour({
    required int attempt,
    required int runToken,
  }) {
    if (!_isPostOnboardingTourRunActive(runToken)) {
      return;
    }
    final targets = <({GlobalKey showcase, GlobalKey target})>[
      (showcase: _composerTourKey, target: _composerTourTargetKey),
      (showcase: _sendButtonTourKey, target: _sendButtonTourTargetKey),
    ];
    if (!_startShowcaseIfReady(targets)) {
      if (attempt >= _postOnboardingTourMaxAttempts) {
        _tourAdvancingToComposerPhase = false;
        _tourStartScheduled = false;
        return;
      }
      Future<void>.delayed(_postOnboardingTourRetryDelay, () {
        if (!mounted) {
          return;
        }
        // The retry callback can fire while the tree is otherwise idle. Ensure
        // a frame exists so the post-frame retry is not left waiting forever.
        WidgetsBinding.instance.scheduleFrame();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_isPostOnboardingTourRunActive(runToken)) {
            return;
          }
          _startComposerPostOnboardingTour(
            attempt: attempt + 1,
            runToken: runToken,
          );
        });
      });
      return;
    }
    // Keep the persisted handoff armed until the user finishes or dismisses the
    // replayed composer steps, even if the composer takes longer than one frame.
    _tourAdvancingToComposerPhase = false;
  }

  Future<void> _restartPostOnboardingTour() async {
    _resetPostOnboardingTourTransientState();
    ShowcaseView.get().dismiss();
    final settingsProvider =
        _settingsProvider ?? context.read<SettingsProvider>();
    if (settingsProvider.pendingPostOnboardingChatTour) {
      await settingsProvider.setPendingPostOnboardingChatTour(false);
    }
    await settingsProvider.setPendingPostOnboardingChatTour(true);
  }

  Future<void> _clearPendingPostOnboardingTour() async {
    _resetPostOnboardingTourTransientState();
    _queuedPendingPostOnboardingTourAutoStart = false;
    _lastPendingPostOnboardingChatTour = false;
    final settingsProvider =
        _settingsProvider ?? context.read<SettingsProvider>();
    await settingsProvider.setPendingPostOnboardingChatTour(false);
  }

  void _handlePostOnboardingTourDismiss(GlobalKey? _) {
    if (_tourAdvancingToComposerPhase ||
        _tourPhase == _PostOnboardingTourPhase.idle) {
      return;
    }
    if (_tourExplicitSkipRequested) {
      unawaited(_clearPendingPostOnboardingTour());
      return;
    }
    // Passive dismiss should stop the current run without consuming the
    // first-use handoff. The next eligible return to chat can re-open it.
    _resetPostOnboardingTourTransientState();
    final settingsProvider =
        _settingsProvider ?? context.read<SettingsProvider>();
    if (settingsProvider.pendingPostOnboardingChatTour) {
      _queuedPendingPostOnboardingTourAutoStart = true;
    }
  }

  void _handlePostOnboardingTourFinish() {
    if (_tourAdvancingToComposerPhase ||
        _tourPhase != _PostOnboardingTourPhase.composer) {
      return;
    }
    unawaited(_clearPendingPostOnboardingTour());
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final sizeClass = WindowSizeClass.fromWidth(width);
        final isMobile = sizeClass.isCompact;
        final isMedium = sizeClass == WindowSizeClass.medium;
        final isLargeDesktop = sizeClass.isAtLeastLarge;
        final keyboardOpen =
            MediaQuery.viewInsetsOf(context).bottom > 0 ||
            View.of(context).viewInsets.bottom > 0;
        final settingsProvider = context.watch<SettingsProvider>();
        final attentionController = _sessionAttentionOverlayController;
        final attentionPresentation =
            settingsProvider.settings.sessionAttentionPresentation;
        final showInAppAttention =
            defaultTargetPlatform == TargetPlatform.iOS &&
            attentionController != null &&
            attentionPresentation != SessionAttentionPresentation.off;
        if (showInAppAttention) {
          final refreshKey =
              '${_appProvider?.activeServerId}:${attentionPresentation.name}';
          if (_sessionAttentionOverlayRefreshKey != refreshKey &&
              !_sessionAttentionOverlayRefreshScheduled) {
            _sessionAttentionOverlayRefreshKey = refreshKey;
            _sessionAttentionOverlayRefreshScheduled = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _sessionAttentionOverlayRefreshScheduled = false;
              if (mounted) {
                unawaited(
                  attentionController.refresh(
                    activeServerId: _appProvider?.activeServerId,
                  ),
                );
              }
            });
          }
        }
        final conversationsPaneEnabled = settingsProvider.isDesktopPaneVisible(
          DesktopPane.conversations,
        );
        // Medium: narrow conversation pane; expanded+: full pane
        final showConversationPane =
            !isMobile &&
            (isMedium ? conversationsPaneEnabled : true) &&
            conversationsPaneEnabled;
        final showDesktopFilePane =
            !isMobile &&
            !isMedium &&
            width >= _filePaneBreakpoint &&
            settingsProvider.isDesktopPaneVisible(DesktopPane.files);
        final showDesktopUtilityPane =
            isLargeDesktop &&
            settingsProvider.isDesktopPaneVisible(DesktopPane.utility);
        final showFullscreenTerminalPanel =
            settingsProvider.terminalPanelVisible &&
            settingsProvider.terminalPanelMaximized;
        // Medium breakpoint stays fixed (compact layout); expanded+ uses
        // the persisted/resizable width from settings.
        final sessionPaneWidth = isMedium
            ? _mediumSessionPaneWidth
            : settingsProvider.desktopPaneWidth(DesktopPane.conversations);
        final mainContentWidth = isLargeDesktop ? 960.0 : double.infinity;
        const refreshlessEnabled = FeatureFlags.refreshlessRealtime;
        final availableShortcutActions = shortcutActionsForRuntime(
          isWeb: kIsWeb,
          targetPlatform: defaultTargetPlatform,
          refreshlessRealtimeEnabled: refreshlessEnabled,
        );
        final shortcutMap = <ShortcutActivator, Intent>{};
        void addShortcut(ShortcutAction action, Intent intent) {
          final binding = settingsProvider.bindingFor(action);
          final activator = ShortcutBindingCodec.parse(binding);
          if (activator != null) {
            shortcutMap[activator] = intent;
          }
        }

        final actionMap = <Type, Action<Intent>>{
          _NewSessionIntent: CallbackAction<_NewSessionIntent>(
            onInvoke: (_) {
              _createNewSession(closeDrawerOnCreate: true);
              return null;
            },
          ),
          _FocusInputIntent: CallbackAction<_FocusInputIntent>(
            onInvoke: (_) {
              _focusInput();
              return null;
            },
          ),
          _ToggleVoiceInputIntent: CallbackAction<_ToggleVoiceInputIntent>(
            onInvoke: (_) {
              unawaited(_toggleVoiceInputShortcut());
              return null;
            },
          ),
          _QuickOpenIntent: CallbackAction<_QuickOpenIntent>(
            onInvoke: (_) {
              _invokeShortcutAction(ShortcutAction.quickOpen);
              return null;
            },
          ),
          _OpenSettingsIntent: CallbackAction<_OpenSettingsIntent>(
            onInvoke: (_) {
              _invokeShortcutAction(ShortcutAction.openSettings);
              return null;
            },
          ),
          _CycleRecentModelsIntent: CallbackAction<_CycleRecentModelsIntent>(
            onInvoke: (_) {
              _invokeShortcutAction(ShortcutAction.cycleRecentModels);
              return null;
            },
          ),
          _CycleVariantIntent: CallbackAction<_CycleVariantIntent>(
            onInvoke: (_) {
              _invokeShortcutAction(ShortcutAction.cycleVariant);
              return null;
            },
          ),
          _EscapeIntent: CallbackAction<_EscapeIntent>(
            onInvoke: (_) {
              _handleEscape();
              return null;
            },
          ),
          _QuitAppIntent: CallbackAction<_QuitAppIntent>(
            onInvoke: (_) {
              unawaited(_quitAppShortcut());
              return null;
            },
          ),
        };
        for (final action in availableShortcutActions) {
          switch (action) {
            case ShortcutAction.newChat:
              addShortcut(action, const _NewSessionIntent());
              break;
            case ShortcutAction.refresh:
              actionMap[_RefreshIntent] = CallbackAction<_RefreshIntent>(
                onInvoke: (_) {
                  _refreshData();
                  return null;
                },
              );
              addShortcut(action, const _RefreshIntent());
              break;
            case ShortcutAction.focusInput:
              addShortcut(action, const _FocusInputIntent());
              break;
            case ShortcutAction.toggleVoiceInput:
              addShortcut(action, const _ToggleVoiceInputIntent());
              break;
            case ShortcutAction.quickOpen:
              addShortcut(action, const _QuickOpenIntent());
              break;
            case ShortcutAction.openSettings:
              addShortcut(action, const _OpenSettingsIntent());
              break;
            case ShortcutAction.cycleRecentModels:
              addShortcut(action, const _CycleRecentModelsIntent());
              break;
            case ShortcutAction.cycleVariant:
              addShortcut(action, const _CycleVariantIntent());
              break;
            case ShortcutAction.escape:
              addShortcut(action, const _EscapeIntent());
              break;
            case ShortcutAction.cycleAgentForward:
            case ShortcutAction.cycleAgentBackward:
              // Handled by the global key-event loop to keep direction-specific
              // behavior centralized with the other chat actions.
              break;
            case ShortcutAction.closeApp:
              // Global-only because the action is contextual and one physical
              // key event must never close both a tab and the app.
              break;
            case ShortcutAction.quitApp:
              addShortcut(action, const _QuitAppIntent());
              break;
          }
        }

        return ShowCaseWidget(
          key: _showcaseWidgetKey,
          onDismiss: _handlePostOnboardingTourDismiss,
          onFinish: _handlePostOnboardingTourFinish,
          enableAutoScroll: false,
          builder: (context) => Shortcuts(
            shortcuts: shortcutMap,
            child: Actions(
              actions: actionMap,
              child: Focus(
                autofocus: true,
                child: PopScope<void>(
                  canPop: !_isMobileRuntime,
                  onPopInvokedWithResult: (didPop, _) {
                    if (didPop || !_isMobileRuntime) {
                      return;
                    }
                    unawaited(_handleMobileBackPress());
                  },
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Scaffold(
                          key: _scaffoldKey,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surface,
                          resizeToAvoidBottomInset: true,
                          appBar: _buildAppBar(
                            isMobile:
                                isMobile || (isMedium && !showConversationPane),
                            isLargeDesktop: isLargeDesktop,
                            settingsProvider: settingsProvider,
                          ),
                          drawer:
                              (isMobile || (isMedium && !showConversationPane))
                              ? _buildSessionDrawer()
                              : null,
                          body: Builder(
                            builder: (context) {
                              late final Widget content;
                              if (isMobile) {
                                content = _buildChatContentSelector(
                                  isKeyboardOpen: keyboardOpen,
                                  maxContentWidth: double.infinity,
                                  horizontalPadding: 0,
                                  verticalPadding: 0,
                                );
                              } else {
                                final filePaneWidth = settingsProvider
                                    .desktopPaneWidth(DesktopPane.files);
                                final utilityPaneWidth = settingsProvider
                                    .desktopPaneWidth(DesktopPane.utility);
                                final rowChildren = <Widget>[
                                  if (showConversationPane) ...[
                                    SizedBox(
                                      width: sessionPaneWidth,
                                      child: _buildSessionPanel(
                                        closeOnSelect: false,
                                        isMobileLayout: false,
                                        onCollapseRequested: () {
                                          unawaited(
                                            settingsProvider
                                                .setDesktopPaneVisible(
                                                  DesktopPane.conversations,
                                                  false,
                                                ),
                                          );
                                        },
                                      ),
                                    ),
                                    if (isMedium)
                                      _buildPaneDivider()
                                    else
                                      _buildResizableHandle(
                                        pane: DesktopPane.conversations,
                                        settingsProvider: settingsProvider,
                                        paneOnLeft: true,
                                      ),
                                  ],
                                  if (showDesktopFilePane) ...[
                                    SizedBox(
                                      width: filePaneWidth,
                                      child: _buildDesktopFilePane(
                                        onCollapseRequested: () {
                                          unawaited(
                                            settingsProvider
                                                .setDesktopPaneVisible(
                                                  DesktopPane.files,
                                                  false,
                                                ),
                                          );
                                        },
                                      ),
                                    ),
                                    _buildResizableHandle(
                                      pane: DesktopPane.files,
                                      settingsProvider: settingsProvider,
                                      paneOnLeft: true,
                                    ),
                                  ],
                                  Expanded(
                                    child: _buildChatContentSelector(
                                      isKeyboardOpen: keyboardOpen,
                                      maxContentWidth: mainContentWidth,
                                      horizontalPadding: 12,
                                      verticalPadding: 2,
                                    ),
                                  ),
                                  if (showDesktopUtilityPane) ...[
                                    _buildResizableHandle(
                                      pane: DesktopPane.utility,
                                      settingsProvider: settingsProvider,
                                      paneOnLeft: false,
                                    ),
                                    SizedBox(
                                      width: utilityPaneWidth,
                                      child: _buildDesktopUtilityPane(
                                        onCollapseRequested: () {
                                          unawaited(
                                            settingsProvider
                                                .setDesktopPaneVisible(
                                                  DesktopPane.utility,
                                                  false,
                                                ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ];
                                content = Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: rowChildren,
                                );
                              }

                              final bodyContent = Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // In the integrated chrome the strip is drawn
                                  // in the window title bar instead.
                                  if (!_usesIntegratedWindowChrome(
                                    settingsProvider,
                                  ))
                                    _buildSessionTabStrip(
                                      isCompact: isMobile,
                                      settingsProvider: settingsProvider,
                                    ),
                                  Expanded(
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        content,
                                        if (_isProjectScopeTransitioning)
                                          const AbsorbPointer(
                                            key: ValueKey<String>(
                                              'project_scope_transition_blocker',
                                            ),
                                            child: SizedBox.expand(),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              );

                              return Stack(
                                fit: StackFit.expand,
                                children: [
                                  bodyContent,
                                  if (_showProjectScopeLoadingOverlay)
                                    _buildProjectScopeLoadingOverlay(),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                      if (showFullscreenTerminalPanel)
                        Positioned.fill(
                          child: _buildFullscreenTerminalOverlay(
                            settingsProvider,
                          ),
                        ),
                      if (showInAppAttention &&
                          attentionController.items.isNotEmpty)
                        PositionedDirectional(
                          end: 16,
                          bottom: 16 + MediaQuery.paddingOf(context).bottom,
                          child: SessionAttentionOverlay(
                            items: attentionController.items,
                            expanded:
                                attentionPresentation ==
                                SessionAttentionPresentation.panel,
                            semanticLabel:
                                context.l10n.settingsSessionAttentionTitle,
                            openLabel: context.l10n.notificationActionOpen,
                            expandLabel: context.l10n.chatExpandGroup,
                            collapseLabel: context.l10n.chatCollapseGroup,
                            readLabel: context.l10n.msgReadAloud,
                            stopReadingLabel: context.l10n.msgStopReadAloud,
                            dismissLabel: context.l10n.settingsAboutDismiss,
                            stopOverlayLabel:
                                context.l10n.settingsSessionAttentionStop,
                            activeSpeechSnapshotId:
                                attentionController.activeSpeechSnapshotId,
                            onOpen: (item) {
                              _scheduleNotificationTap(
                                NotificationTapPayload(
                                  category: 'session_attention',
                                  action: 'open',
                                  serverId: item.identity.serverId,
                                  directory: item.identity.directory,
                                  sessionId: item.identity.rootSessionId,
                                  snapshotId: item.snapshotId,
                                ),
                              );
                            },
                            onRead: (item) =>
                                unawaited(attentionController.readOrStop(item)),
                            onDismiss: (item) =>
                                unawaited(attentionController.dismiss(item)),
                            onToggleExpanded: () => unawaited(
                              settingsProvider.setSessionAttentionPresentation(
                                attentionPresentation ==
                                        SessionAttentionPresentation.panel
                                    ? SessionAttentionPresentation.bubble
                                    : SessionAttentionPresentation.panel,
                              ),
                            ),
                            onStopOverlay: () => unawaited(
                              settingsProvider.setSessionAttentionPresentation(
                                SessionAttentionPresentation.off,
                              ),
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
    );
  }

  List<({String shortcut, String description})> _keyboardShortcutHints(
    SettingsProvider settingsProvider,
  ) {
    final entries = <({ShortcutAction action, String description})>[
      for (final action in shortcutActionsForRuntime(
        isWeb: kIsWeb,
        targetPlatform: defaultTargetPlatform,
        refreshlessRealtimeEnabled: FeatureFlags.refreshlessRealtime,
      ))
        switch (action) {
          ShortcutAction.newChat => (
            action: action,
            description: context.l10n.chatShortcutsNewConversation,
          ),
          ShortcutAction.refresh => (
            action: action,
            description: context.l10n.chatShortcutsRefreshChat,
          ),
          ShortcutAction.focusInput => (
            action: action,
            description: context.l10n.chatShortcutsFocusInput,
          ),
          ShortcutAction.toggleVoiceInput => (
            action: action,
            description: context.l10n.chatShortcutsStartStopVoice,
          ),
          ShortcutAction.quickOpen => (
            action: action,
            description: context.l10n.chatShortcutsQuickOpen,
          ),
          ShortcutAction.openSettings => (
            action: action,
            description: context.l10n.chatShortcutsOpenSettings,
          ),
          ShortcutAction.cycleRecentModels => (
            action: action,
            description: context.l10n.chatShortcutsCycleModels,
          ),
          ShortcutAction.cycleVariant => (
            action: action,
            description: context.l10n.chatShortcutsCycleVariant,
          ),
          ShortcutAction.escape => (
            action: action,
            description:
                '${context.l10n.terminalRestoreSize} / '
                '${context.l10n.chatShortcutsFocusInputCloseDrawer}',
          ),
          ShortcutAction.cycleAgentForward => (
            action: action,
            description: context.l10n.chatShortcutsNextAgent,
          ),
          ShortcutAction.cycleAgentBackward => (
            action: action,
            description: context.l10n.chatShortcutsPreviousAgent,
          ),
          ShortcutAction.closeApp => (
            action: action,
            description: context.l10n.shortcutCloseAppDesc,
          ),
          ShortcutAction.quitApp => (
            action: action,
            description: context.l10n.chatShortcutsForceExit,
          ),
        },
    ];

    final hints = entries
        .map(
          (entry) => (
            shortcut: ShortcutBindingCodec.formatForDisplay(
              settingsProvider.bindingFor(entry.action),
            ),
            description: entry.description,
          ),
        )
        .toList();

    final escapeShortcut = ShortcutBindingCodec.formatForDisplay(
      settingsProvider.bindingFor(ShortcutAction.escape),
    );
    hints.add((
      shortcut: '$escapeShortcut, $escapeShortcut',
      description: context.l10n.chatShortcutsStopResponse,
    ));
    return hints;
  }

  bool get _isMobileViewport {
    if (!mounted) {
      return false;
    }
    // Medium (tablet) still uses single-column layout where long-press
    // to reuse prompt and similar mobile gestures must work.
    return !context.windowSizeClass.isAtLeastExpanded;
  }

  ({String compactionId, String compactionLabel})? _resolveCompactionBoundary(
    ChatMessage message,
  ) {
    final compactionPart = _findCompactionPart(message);
    if (compactionPart != null) {
      return (
        compactionId: compactionPart.id,
        compactionLabel: compactionPart.auto ? 'automatic' : 'manual',
      );
    }
    if (_isCompactionSummaryMessage(message)) {
      return (
        compactionId: 'summary_${message.id}',
        compactionLabel: 'context',
      );
    }
    return null;
  }
}
