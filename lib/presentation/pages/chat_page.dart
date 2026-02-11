import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart' hide Provider;
import 'package:simple_icons/simple_icons.dart';
import '../../core/config/feature_flags.dart';
import '../../core/logging/app_logger.dart';
import '../../core/network/dio_client.dart';
import '../../core/di/injection_container.dart' as di;
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_realtime.dart';
import '../../domain/entities/chat_session.dart';
import '../../domain/entities/file_node.dart';
import '../../domain/entities/project.dart';
import '../../domain/entities/provider.dart';
import '../../domain/entities/experience_settings.dart';
import '../providers/app_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/project_provider.dart';
import '../providers/settings_provider.dart';
import '../services/notification_service.dart';
import '../utils/session_title_formatter.dart';
import '../utils/file_explorer_logic.dart';
import '../utils/shortcut_binding_codec.dart';

import '../widgets/chat_message_widget.dart';
import '../widgets/chat_input_widget.dart';
import '../widgets/chat_session_list.dart';
import '../widgets/permission_request_card.dart';
import '../widgets/question_request_card.dart';
import '../widgets/session_title_inline_editor.dart';
import 'logs_page.dart';
import 'settings_page.dart';

class _NewSessionIntent extends Intent {
  const _NewSessionIntent();
}

class _RefreshIntent extends Intent {
  const _RefreshIntent();
}

class _FocusInputIntent extends Intent {
  const _FocusInputIntent();
}

class _QuickOpenIntent extends Intent {
  const _QuickOpenIntent();
}

class _EscapeIntent extends Intent {
  const _EscapeIntent();
}

class _CycleAgentIntent extends Intent {
  const _CycleAgentIntent({this.reverse = false});

  final bool reverse;
}

class _ModelSelectorEntry {
  const _ModelSelectorEntry({
    required this.providerId,
    required this.providerName,
    required this.modelId,
    required this.modelName,
  });

  final String providerId;
  final String providerName;
  final String modelId;
  final String modelName;
}

/// Chat page
class ChatPage extends StatefulWidget {
  final String? projectId;

  const ChatPage({super.key, this.projectId});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver {
  static const double _mobileBreakpoint = 840;
  static const double _largeDesktopBreakpoint = 1200;
  static const double _filePaneBreakpoint = 1100;
  static const double _desktopSessionPaneWidth = 300;
  static const double _largeDesktopSessionPaneWidth = 320;
  static const double _desktopFilePaneWidth = 280;
  static const double _largeDesktopUtilityPaneWidth = 280;
  static const double _nearBottomThreshold = 200;
  static const String _rootTreeCacheKey = '__root__';

  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode(debugLabel: 'chat_input');
  final GlobalKey _agentSelectorChipKey = GlobalKey(
    debugLabel: 'agent_selector_chip',
  );
  final TextEditingController _sessionSearchController =
      TextEditingController();
  NotificationService? _notificationService;
  StreamSubscription<NotificationTapPayload>? _notificationTapSubscription;
  ChatProvider? _chatProvider;
  AppProvider? _appProvider;
  String? _lastServerId;
  bool? _lastServerConnectionState;
  String? _trackedSessionId;
  String? _pendingInitialScrollSessionId;
  bool _showScrollToLatestFab = false;
  bool _hasUnreadMessagesBelow = false;
  bool _isAppInForeground = true;
  String? _composerPrefilledText;
  int _composerPrefilledTextVersion = 0;
  final Map<String, _FileExplorerContextState> _fileContextStates =
      <String, _FileExplorerContextState>{};
  final Map<String, String> _fileDiffSignaturesByContext = <String, String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_handleScrollChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Safely get ChatProvider reference here
    _chatProvider ??= context.read<ChatProvider>();
    final nextAppProvider = context.read<AppProvider>();
    if (!identical(_appProvider, nextAppProvider)) {
      _appProvider?.removeListener(_handleAppProviderChange);
      _appProvider = nextAppProvider;
      _lastServerId = nextAppProvider.activeServerId;
      _lastServerConnectionState = nextAppProvider.isConnected;
      _appProvider?.addListener(_handleAppProviderChange);
    }
    if (di.sl.isRegistered<NotificationService>()) {
      final nextNotificationService = di.sl<NotificationService>();
      if (!identical(_notificationService, nextNotificationService)) {
        _notificationTapSubscription?.cancel();
        _notificationService = nextNotificationService;
        _notificationTapSubscription = nextNotificationService
            .onNotificationTapped
            .listen((payload) {
              unawaited(_handleNotificationTap(payload));
            });
        final pendingPayload = nextNotificationService.consumePendingTap();
        if (pendingPayload != null) {
          unawaited(_handleNotificationTap(pendingPayload));
        }
      }
    }
  }

  @override
  void dispose() {
    // Clean up scroll callback using saved reference
    _chatProvider?.setScrollToBottomCallback(null);
    unawaited(_chatProvider?.setForegroundActive(false));
    _appProvider?.removeListener(_handleAppProviderChange);
    _notificationTapSubscription?.cancel();
    _scrollController.removeListener(_handleScrollChanged);
    WidgetsBinding.instance.removeObserver(this);

    _scrollController.dispose();
    _inputFocusNode.dispose();
    _sessionSearchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppInForeground = state == AppLifecycleState.resumed;
    final provider = _chatProvider;
    if (provider != null) {
      unawaited(provider.setForegroundActive(_isAppInForeground));
    }
  }

  void _loadInitialData() {
    final chatProvider = context.read<ChatProvider>();

    // Set scroll to bottom callback
    chatProvider.setScrollToBottomCallback(_scrollToBottom);
    unawaited(chatProvider.setForegroundActive(_isAppInForeground));

    // Technical comment translated to English.
    _initializeChatProvider(chatProvider);
  }

  Future<void> _initializeChatProvider(ChatProvider chatProvider) async {
    final appProvider = context.read<AppProvider>();
    final projectProvider = context.read<ProjectProvider>();
    try {
      await appProvider.initialize();
      await projectProvider.initializeProject();
      await appProvider.checkConnection(
        directory: projectProvider.currentDirectory,
      );
      // Technical comment translated to English.
      await chatProvider.initializeProviders();

      // Technical comment translated to English.
      await chatProvider.loadSessions();
    } catch (e) {
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
    final currentServerId = appProvider.activeServerId;
    final currentConnected = appProvider.isConnected;
    final serverChanged = currentServerId != _lastServerId;

    if (serverChanged) {
      _lastServerId = currentServerId;
      _lastServerConnectionState = currentConnected;
      if (currentServerId != null) {
        unawaited(_handleServerScopeChange());
      }
      return;
    }

    final wasConnected = _lastServerConnectionState;
    _lastServerConnectionState = currentConnected;
    if (wasConnected == false && currentConnected) {
      unawaited(_handleServerReconnected());
    }
  }

  Future<void> _handleServerScopeChange() async {
    if (!mounted) {
      return;
    }
    final projectProvider = context.read<ProjectProvider>();
    await projectProvider.onServerScopeChanged();
    await _chatProvider?.onServerScopeChanged();
  }

  Future<void> _handleServerReconnected() async {
    if (!mounted || !_isChatScreenActive()) {
      return;
    }
    final chatProvider = _chatProvider ?? context.read<ChatProvider>();
    await chatProvider.refreshActiveSessionView(
      reason: 'app-provider-reconnected',
    );
  }

  Future<void> _handleNotificationTap(NotificationTapPayload payload) async {
    if (!mounted) {
      return;
    }
    final sessionId = payload.sessionId;
    if (sessionId == null || sessionId.isEmpty) {
      return;
    }

    final chatProvider = _chatProvider ?? context.read<ChatProvider>();
    var targetSession = chatProvider.sessions
        .where((item) => item.id == sessionId)
        .firstOrNull;
    if (targetSession == null) {
      await chatProvider.loadSessions();
      if (!mounted) {
        return;
      }
      targetSession = chatProvider.sessions
          .where((item) => item.id == sessionId)
          .firstOrNull;
    }
    if (targetSession == null) {
      return;
    }
    await chatProvider.selectSession(targetSession);
  }

  bool _isChatScreenActive() {
    if (!mounted || !_isAppInForeground) {
      return false;
    }
    final route = ModalRoute.of(context);
    if (route == null) {
      return true;
    }
    return route.isCurrent;
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) {
      return true;
    }
    final position = _scrollController.position;
    return (position.maxScrollExtent - position.pixels) <= _nearBottomThreshold;
  }

  void _handleScrollChanged() {
    if (!_scrollController.hasClients) {
      return;
    }

    final awayFromBottom = !_isNearBottom();
    if (!awayFromBottom) {
      if (_showScrollToLatestFab || _hasUnreadMessagesBelow) {
        setState(() {
          _showScrollToLatestFab = false;
          _hasUnreadMessagesBelow = false;
        });
      }
      return;
    }

    if (!_showScrollToLatestFab) {
      setState(() {
        _showScrollToLatestFab = true;
      });
    }
  }

  void _syncSessionScrollState(ChatProvider chatProvider) {
    final sessionId = chatProvider.currentSession?.id;
    if (sessionId != _trackedSessionId) {
      _trackedSessionId = sessionId;
      _pendingInitialScrollSessionId = sessionId;
      if (_showScrollToLatestFab || _hasUnreadMessagesBelow) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          setState(() {
            _showScrollToLatestFab = false;
            _hasUnreadMessagesBelow = false;
          });
        });
      }
    }

    if (sessionId == null) {
      _pendingInitialScrollSessionId = null;
      return;
    }

    if (_pendingInitialScrollSessionId == sessionId &&
        chatProvider.messages.isNotEmpty &&
        chatProvider.state != ChatState.loading) {
      _pendingInitialScrollSessionId = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _trackedSessionId != sessionId) {
          return;
        }
        _scrollToBottom(force: true);
      });
    }
  }

  void _markUnreadMessagesBelow() {
    if (_showScrollToLatestFab && _hasUnreadMessagesBelow) {
      return;
    }
    setState(() {
      _showScrollToLatestFab = true;
      _hasUnreadMessagesBelow = true;
    });
  }

  void _scrollToBottom({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }

      final shouldScroll = force || _isNearBottom();
      if (!shouldScroll) {
        _markUnreadMessagesBelow();
        return;
      }

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );

      if (_showScrollToLatestFab || _hasUnreadMessagesBelow) {
        setState(() {
          _showScrollToLatestFab = false;
          _hasUnreadMessagesBelow = false;
        });
      }
    });
  }

  Future<void> _refreshData() async {
    final chatProvider = context.read<ChatProvider>();
    await chatProvider.loadSessions();
    await chatProvider.refresh();
  }

  Future<void> _switchProjectContext(String projectId) async {
    final projectProvider = context.read<ProjectProvider>();
    final chatProvider = context.read<ChatProvider>();
    final changed = await projectProvider.switchProject(projectId);
    if (!changed) {
      return;
    }
    await chatProvider.onProjectScopeChanged();
  }

  Future<void> _closeProjectContext(String projectId) async {
    final projectProvider = context.read<ProjectProvider>();
    final chatProvider = context.read<ChatProvider>();
    final changed = await projectProvider.closeProject(projectId);
    if (!changed) {
      return;
    }
    await chatProvider.onProjectScopeChanged();
  }

  Future<void> _reopenProjectContext(String projectId) async {
    final projectProvider = context.read<ProjectProvider>();
    final chatProvider = context.read<ChatProvider>();
    final changed = await projectProvider.reopenProject(
      projectId,
      makeActive: true,
    );
    if (!changed) {
      return;
    }
    await chatProvider.onProjectScopeChanged();
  }

  Future<void> _archiveClosedProjectContext(String projectId) async {
    final projectProvider = context.read<ProjectProvider>();
    final ok = await projectProvider.archiveClosedProject(projectId);
    if (!mounted) {
      return;
    }
    if (!ok) {
      final error = projectProvider.error;
      if (error != null && error.trim().isNotEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
      }
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Project archived from closed list')),
    );
  }

  Future<void> _createWorkspace() async {
    final projectProvider = context.read<ProjectProvider>();
    final chatProvider = context.read<ChatProvider>();
    final appProvider = context.read<AppProvider>();
    final defaultDirectory =
        projectProvider.currentDirectory ??
        appProvider.appInfo?.path.data ??
        '/';
    final nameController = TextEditingController();
    final baseDirectoryController = TextEditingController(
      text: defaultDirectory,
    );
    final createdInput = await showDialog<(String, String?)>(
      context: context,
      builder: (dialogContext) {
        var validatingDirectory = false;
        String? validationMessage;
        bool? gitDirectory;

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Create Workspace'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      key: const ValueKey<String>('workspace_name_input'),
                      controller: nameController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Workspace name',
                        hintText: 'ex: feature-branch',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const ValueKey<String>(
                        'workspace_base_directory_input',
                      ),
                      controller: baseDirectoryController,
                      decoration: InputDecoration(
                        labelText: 'Base directory',
                        hintText: '/repo/my-project',
                        helperText:
                            'Browse folders to pick where the workspace is created',
                        suffixIcon: IconButton(
                          key: const ValueKey<String>(
                            'workspace_open_directory_picker_button',
                          ),
                          tooltip: 'Browse directories',
                          onPressed: () async {
                            final picked = await _openDirectoryPicker(
                              initialDirectory:
                                  baseDirectoryController.text.trim().isEmpty
                                  ? defaultDirectory
                                  : baseDirectoryController.text.trim(),
                            );
                            if (!dialogContext.mounted || picked == null) {
                              return;
                            }
                            baseDirectoryController.text = picked;
                            setDialogState(() {
                              validationMessage = null;
                              gitDirectory = null;
                            });
                          },
                          icon: const Icon(Icons.folder_open_outlined),
                        ),
                      ),
                    ),
                    if (validationMessage != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            gitDirectory == true
                                ? Icons.check_circle_outline
                                : Icons.warning_amber_rounded,
                            size: 16,
                            color: gitDirectory == true
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              validationMessage!,
                              key: const ValueKey<String>(
                                'workspace_directory_validation_message',
                              ),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: gitDirectory == true
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).colorScheme.error,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: validatingDirectory
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty) {
                            setDialogState(() {
                              validationMessage =
                                  'Workspace name cannot be empty.';
                              gitDirectory = false;
                            });
                            return;
                          }

                          final baseDirectory = baseDirectoryController.text
                              .trim();
                          if (baseDirectory.isNotEmpty) {
                            setDialogState(() {
                              validatingDirectory = true;
                              validationMessage = null;
                              gitDirectory = null;
                            });
                            final isGit = await projectProvider.isGitDirectory(
                              baseDirectory,
                            );
                            if (!dialogContext.mounted) {
                              return;
                            }
                            if (isGit == null) {
                              setDialogState(() {
                                validatingDirectory = false;
                                validationMessage =
                                    projectProvider.error ??
                                    'Failed to validate directory.';
                                gitDirectory = false;
                              });
                              return;
                            }
                            if (!isGit) {
                              setDialogState(() {
                                validatingDirectory = false;
                                validationMessage =
                                    'Selected directory is not a Git repository.';
                                gitDirectory = false;
                              });
                              return;
                            }
                            setDialogState(() {
                              validatingDirectory = false;
                              validationMessage = 'Git repository detected.';
                              gitDirectory = true;
                            });
                          }

                          if (!dialogContext.mounted) {
                            return;
                          }
                          Navigator.of(dialogContext).pop((
                            name,
                            baseDirectory.isEmpty ? null : baseDirectory,
                          ));
                        },
                  child: validatingDirectory
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
    if (!mounted || createdInput == null || createdInput.$1.trim().isEmpty) {
      return;
    }

    final created = await projectProvider.createWorktree(
      createdInput.$1,
      switchToCreated: true,
      directory: createdInput.$2,
    );
    if (!mounted) {
      return;
    }
    if (created == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(projectProvider.error ?? 'Failed to create workspace'),
        ),
      );
      return;
    }
    await projectProvider.switchToDirectoryContext(created.directory);
    await chatProvider.onProjectScopeChanged();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          createdInput.$2 == null
              ? 'Workspace created: ${created.name}'
              : 'Workspace created in ${createdInput.$2}: ${created.name}',
        ),
      ),
    );
  }

  Future<String?> _openDirectoryPicker({
    required String initialDirectory,
  }) async {
    final appProvider = context.read<AppProvider>();
    final startDirectory = initialDirectory.trim().isNotEmpty
        ? initialDirectory.trim()
        : (appProvider.appInfo?.path.data.trim().isNotEmpty ?? false)
        ? appProvider.appInfo!.path.data.trim()
        : '/';

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _DirectoryPickerSheet(initialDirectory: startDirectory),
    );
  }

  Future<void> _resetWorkspace(String worktreeId) async {
    final projectProvider = context.read<ProjectProvider>();
    final ok = await projectProvider.resetWorktree(worktreeId);
    if (!mounted) {
      return;
    }
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(projectProvider.error ?? 'Failed to reset workspace'),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Workspace reset')));
  }

  Future<void> _deleteWorkspace(String worktreeId) async {
    final projectProvider = context.read<ProjectProvider>();
    final chatProvider = context.read<ChatProvider>();
    final ok = await projectProvider.deleteWorktree(worktreeId);
    if (!mounted) {
      return;
    }
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(projectProvider.error ?? 'Failed to delete workspace'),
        ),
      );
      return;
    }
    await chatProvider.onProjectScopeChanged();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Workspace deleted')));
  }

  void _focusInput() {
    if (!_inputFocusNode.hasFocus) {
      _inputFocusNode.requestFocus();
    }
  }

  void _handleEscape() {
    final scaffoldState = Scaffold.maybeOf(context);
    if (scaffoldState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
  }

  bool _supportsInputModality(Model? model, String modality) {
    if (model == null || !model.attachment) {
      return false;
    }
    final normalizedModality = modality.toLowerCase();
    final modalities = model.modalities;
    final input = modalities?['input'];
    if (input is List) {
      final normalized = input
          .whereType<Object>()
          .map((item) => item.toString().toLowerCase())
          .toSet();
      return normalized.contains(normalizedModality);
    }
    if (input is Map) {
      return input[normalizedModality] == true;
    }
    // Backward compatibility for servers that only expose `attachment=true`.
    return true;
  }

  bool _supportsImageAttachments(Model? model) {
    return _supportsInputModality(model, 'image');
  }

  bool _supportsPdfAttachments(Model? model) {
    return _supportsInputModality(model, 'pdf');
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isMobile = width < _mobileBreakpoint;
        final isLargeDesktop = width >= _largeDesktopBreakpoint;
        final settingsProvider = context.watch<SettingsProvider>();
        final showConversationPane =
            !isMobile &&
            settingsProvider.isDesktopPaneVisible(DesktopPane.conversations);
        final showDesktopFilePane =
            !isMobile &&
            width >= _filePaneBreakpoint &&
            settingsProvider.isDesktopPaneVisible(DesktopPane.files);
        final showDesktopUtilityPane =
            isLargeDesktop &&
            settingsProvider.isDesktopPaneVisible(DesktopPane.utility);
        final sessionPaneWidth = isLargeDesktop
            ? _largeDesktopSessionPaneWidth
            : _desktopSessionPaneWidth;
        final mainContentWidth = isLargeDesktop ? 960.0 : double.infinity;
        final refreshlessEnabled = FeatureFlags.refreshlessRealtime;
        final shortcutMap = <ShortcutActivator, Intent>{};
        void addShortcut(ShortcutAction action, Intent intent) {
          final binding = settingsProvider.bindingFor(action);
          final activator = ShortcutBindingCodec.parse(binding);
          if (activator != null) {
            shortcutMap[activator] = intent;
          }
        }

        addShortcut(ShortcutAction.newChat, const _NewSessionIntent());
        addShortcut(ShortcutAction.focusInput, const _FocusInputIntent());
        addShortcut(ShortcutAction.quickOpen, const _QuickOpenIntent());
        addShortcut(ShortcutAction.escape, const _EscapeIntent());
        addShortcut(
          ShortcutAction.cycleAgentForward,
          const _CycleAgentIntent(),
        );
        addShortcut(
          ShortcutAction.cycleAgentBackward,
          const _CycleAgentIntent(reverse: true),
        );
        final actionMap = <Type, Action<Intent>>{
          _NewSessionIntent: CallbackAction<_NewSessionIntent>(
            onInvoke: (_) {
              _createNewSession();
              return null;
            },
          ),
          _FocusInputIntent: CallbackAction<_FocusInputIntent>(
            onInvoke: (_) {
              _focusInput();
              return null;
            },
          ),
          _QuickOpenIntent: CallbackAction<_QuickOpenIntent>(
            onInvoke: (_) {
              _openQuickFileDialogFromCurrentContext();
              return null;
            },
          ),
          _EscapeIntent: CallbackAction<_EscapeIntent>(
            onInvoke: (_) {
              _handleEscape();
              return null;
            },
          ),
          _CycleAgentIntent: CallbackAction<_CycleAgentIntent>(
            onInvoke: (intent) {
              final chatProvider = context.read<ChatProvider>();
              unawaited(chatProvider.cycleAgent(reverse: intent.reverse));
              return null;
            },
          ),
        };
        if (!refreshlessEnabled) {
          addShortcut(ShortcutAction.refresh, const _RefreshIntent());
          actionMap[_RefreshIntent] = CallbackAction<_RefreshIntent>(
            onInvoke: (_) {
              _refreshData();
              return null;
            },
          );
        }

        return Shortcuts(
          shortcuts: shortcutMap,
          child: Actions(
            actions: actionMap,
            child: Focus(
              autofocus: true,
              child: Scaffold(
                backgroundColor: Theme.of(context).colorScheme.surface,
                resizeToAvoidBottomInset: true,
                appBar: _buildAppBar(
                  isMobile: isMobile,
                  settingsProvider: settingsProvider,
                ),
                drawer: isMobile ? _buildSessionDrawer() : null,
                body: Consumer<ChatProvider>(
                  builder: (context, chatProvider, child) {
                    _syncSessionScrollState(chatProvider);
                    if (isMobile) {
                      return _buildChatContent(
                        chatProvider: chatProvider,
                        maxContentWidth: double.infinity,
                        horizontalPadding: 0,
                        verticalPadding: 0,
                      );
                    }

                    final rowChildren = <Widget>[
                      if (showConversationPane) ...[
                        SizedBox(
                          width: sessionPaneWidth,
                          child: _buildSessionPanel(
                            closeOnSelect: false,
                            onCollapseRequested: () {
                              unawaited(
                                settingsProvider.setDesktopPaneVisible(
                                  DesktopPane.conversations,
                                  false,
                                ),
                              );
                            },
                          ),
                        ),
                        _buildPaneDivider(),
                      ],
                      if (showDesktopFilePane) ...[
                        SizedBox(
                          width: _desktopFilePaneWidth,
                          child: _buildDesktopFilePane(
                            chatProvider,
                            onCollapseRequested: () {
                              unawaited(
                                settingsProvider.setDesktopPaneVisible(
                                  DesktopPane.files,
                                  false,
                                ),
                              );
                            },
                          ),
                        ),
                        _buildPaneDivider(),
                      ],
                      Expanded(
                        child: _buildChatContent(
                          chatProvider: chatProvider,
                          maxContentWidth: mainContentWidth,
                          horizontalPadding: 12,
                          verticalPadding: 8,
                        ),
                      ),
                      if (showDesktopUtilityPane) ...[
                        _buildPaneDivider(),
                        SizedBox(
                          width: _largeDesktopUtilityPaneWidth,
                          child: _buildDesktopUtilityPane(
                            chatProvider,
                            onCollapseRequested: () {
                              unawaited(
                                settingsProvider.setDesktopPaneVisible(
                                  DesktopPane.utility,
                                  false,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ];
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: rowChildren,
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
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
      DesktopPane.conversations => 'Conversations',
      DesktopPane.files => 'Files',
      DesktopPane.utility => 'Utility',
    };
  }

  AppBar _buildAppBar({
    required bool isMobile,
    required SettingsProvider settingsProvider,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final refreshlessEnabled = FeatureFlags.refreshlessRealtime;
    return AppBar(
      titleSpacing: isMobile ? 0 : 8,
      title: _buildProjectSelectorTitle(isMobile: isMobile),
      actions: [
        if (!isMobile)
          PopupMenuButton<DesktopPane>(
            key: const ValueKey<String>('desktop_sidebars_menu_button'),
            tooltip: 'Toggle sidebars',
            onSelected: (pane) {
              final next = !settingsProvider.isDesktopPaneVisible(pane);
              unawaited(settingsProvider.setDesktopPaneVisible(pane, next));
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
                                ? Icons.check_box_rounded
                                : Icons.check_box_outline_blank_rounded,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(_desktopPaneLabel(pane)),
                        ],
                      ),
                    ),
                  )
                  .toList(growable: false);
            },
            icon: const Icon(Icons.view_sidebar_outlined),
          ),
        if (refreshlessEnabled && !isMobile)
          Consumer2<ChatProvider, AppProvider>(
            builder: (context, chatProvider, appProvider, child) {
              final label = _syncStatusLabel(
                chatProvider: chatProvider,
                appProvider: appProvider,
              );
              final color = _syncStatusColor(
                context: context,
                chatProvider: chatProvider,
                appProvider: appProvider,
              );
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Container(
                  key: const ValueKey<String>('chat_sync_status_chip'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        Consumer<AppProvider>(
          builder: (context, appProvider, child) {
            final active = appProvider.activeServer;
            final status = active == null
                ? ServerHealthStatus.unknown
                : appProvider.healthFor(active.id);
            final statusColor = switch (status) {
              ServerHealthStatus.healthy => Colors.green,
              ServerHealthStatus.unhealthy => Colors.red,
              ServerHealthStatus.unknown => colorScheme.outline,
            };
            return PopupMenuButton<String>(
              tooltip: 'Switch Server',
              onSelected: (value) async {
                final messenger = ScaffoldMessenger.of(context);
                if (value == '__manage__') {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          const SettingsPage(initialSectionId: 'servers'),
                    ),
                  );
                  return;
                }

                final ok = await appProvider.setActiveServer(value);
                if (!ok) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(appProvider.errorMessage)),
                  );
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
                                ServerHealthStatus.unknown => Colors.grey,
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
                            const Icon(Icons.check, size: 16),
                        ],
                      ),
                    ),
                  );
                }
                items.add(const PopupMenuDivider());
                items.add(
                  const PopupMenuItem<String>(
                    value: '__manage__',
                    child: Text('Manage Servers'),
                  ),
                );
                return items;
              },
              child: Container(
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: colorScheme.outline.withValues(alpha: 0.4),
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isMobile) ...[
                      const Icon(Icons.cloud_outlined, size: 16),
                      const SizedBox(width: 6),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ] else ...[
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 120),
                        child: Text(
                          active?.displayName ?? 'Server',
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.arrow_drop_down, size: 18),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
        if (isMobile)
          IconButton(
            key: const ValueKey<String>('appbar_quick_open_button'),
            icon: const Icon(Icons.folder_open_outlined),
            tooltip: 'Open Files',
            onPressed: () => unawaited(_openMobileFilesDialog()),
          ),
        if (!isMobile)
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'New Chat',
            onPressed: _createNewSession,
          ),
        if (!refreshlessEnabled)
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _refreshData,
          ),
        if (isMobile)
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'New Chat',
            onPressed: _createNewSession,
          ),
        const SizedBox(width: 4),
      ],
    );
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
                title: const Text('Files'),
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ),
              body: StatefulBuilder(
                builder: (context, setDialogState) {
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
                              onStateChanged: () => setDialogState(() {}),
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

  String _syncStatusLabel({
    required ChatProvider chatProvider,
    required AppProvider appProvider,
  }) {
    if (!appProvider.isConnected ||
        chatProvider.syncState == ChatSyncState.reconnecting) {
      return 'Reconnecting';
    }
    if (chatProvider.syncState == ChatSyncState.delayed ||
        chatProvider.isInDegradedMode) {
      return 'Sync delayed';
    }
    return 'Connected';
  }

  Color _syncStatusColor({
    required BuildContext context,
    required ChatProvider chatProvider,
    required AppProvider appProvider,
  }) {
    if (!appProvider.isConnected ||
        chatProvider.syncState == ChatSyncState.reconnecting) {
      return Theme.of(context).colorScheme.error;
    }
    if (chatProvider.syncState == ChatSyncState.delayed ||
        chatProvider.isInDegradedMode) {
      return Colors.orange;
    }
    return Colors.green;
  }

  Widget _buildProjectSelectorTitle({required bool isMobile}) {
    return Consumer<ProjectProvider>(
      builder: (context, projectProvider, child) {
        final currentDirectoryFull = _directoryLabel(
          projectProvider.currentDirectory,
        );
        final currentDirectoryChip = isMobile
            ? _directoryBasename(currentDirectoryFull)
            : currentDirectoryFull;

        return Align(
          alignment: Alignment.centerLeft,
          child: Tooltip(
            message: 'Choose Directory',
            child: InkWell(
              onTap: () => unawaited(_openProjectSelectorDialog()),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                key: const ValueKey<String>('project_selector_button'),
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 2 : 6,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.folder_open_outlined, size: 16),
                    SizedBox(width: isMobile ? 4 : 6),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isMobile ? 100 : 280,
                      ),
                      child: Text(
                        currentDirectoryChip,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.arrow_drop_down, size: 18),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openProjectSelectorDialog() async {
    if (!mounted) {
      return;
    }
    final view = View.of(context);
    final screenWidth = MediaQueryData.fromView(view).size.width;
    final isSmallScreen = screenWidth < _mobileBreakpoint;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Consumer<ProjectProvider>(
          builder: (context, projectProvider, child) {
            final content = _buildProjectSelectorDialogContent(
              dialogContext: dialogContext,
              projectProvider: projectProvider,
              isSmallScreen: isSmallScreen,
            );
            if (isSmallScreen) {
              return Dialog.fullscreen(
                key: const ValueKey<String>(
                  'project_selector_dialog_fullscreen',
                ),
                child: content,
              );
            }
            return Dialog(
              key: const ValueKey<String>('project_selector_dialog_centered'),
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                width: 760,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 720),
                  child: content,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProjectSelectorDialogContent({
    required BuildContext dialogContext,
    required ProjectProvider projectProvider,
    required bool isSmallScreen,
  }) {
    final colorScheme = Theme.of(dialogContext).colorScheme;
    final currentProject = projectProvider.currentProject;
    final currentDirectoryFull = _directoryLabel(
      projectProvider.currentDirectory,
    );
    final worktreeEnabled =
        projectProvider.worktreeSupported ||
        projectProvider.worktrees.isNotEmpty;

    return Material(
      key: const ValueKey<String>('project_selector_dialog_content'),
      color: colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              isSmallScreen ? 16 : 20,
              isSmallScreen ? 12 : 16,
              isSmallScreen ? 8 : 12,
              8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Project context',
                    style: Theme.of(dialogContext).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(isSmallScreen ? 16 : 20, 0, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentProject == null
                      ? 'No active context'
                      : 'Current directory: $currentDirectoryFull',
                ),
                const SizedBox(height: 2),
                Text(
                  'Select a directory/workspace below',
                  style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(isSmallScreen ? 16 : 20, 4, 20, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => unawaited(
                    _openCreateWorkspaceFromSelector(dialogContext),
                  ),
                  icon: const Icon(Icons.add_box_outlined),
                  label: const Text('Create workspace in directory...'),
                ),
                if (!FeatureFlags.refreshlessRealtime)
                  FilledButton.tonalIcon(
                    onPressed: () => unawaited(projectProvider.loadProjects()),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Refresh projects'),
                  ),
                if (worktreeEnabled && !FeatureFlags.refreshlessRealtime)
                  FilledButton.tonalIcon(
                    onPressed: () => unawaited(projectProvider.loadWorktrees()),
                    icon: const Icon(Icons.sync_rounded),
                    label: const Text('Refresh workspaces'),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
              children: [
                _buildSelectorSectionHeader(dialogContext, 'Open projects'),
                for (final project in projectProvider.openProjects)
                  _buildOpenProjectTile(
                    dialogContext: dialogContext,
                    project: project,
                    selected: project.id == currentProject?.id,
                    onSwitch: () => unawaited(
                      _switchProjectFromSelector(dialogContext, project.id),
                    ),
                    onClose: () => unawaited(_closeProjectContext(project.id)),
                    closeEnabled:
                        projectProvider.openProjects.length > 1 ||
                        project.id != currentProject?.id,
                  ),
                if (projectProvider.closedProjects.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildSelectorSectionHeader(dialogContext, 'Closed projects'),
                  for (final project in projectProvider.closedProjects)
                    Builder(
                      builder: (_) {
                        final displayName = _projectDisplayLabel(project);
                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
                          leading: const Icon(
                            Icons.folder_off_outlined,
                            size: 20,
                          ),
                          title: Text(
                            displayName,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            _directoryLabel(project.path),
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Wrap(
                            spacing: 2,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.undo_rounded),
                                tooltip: 'Reopen $displayName',
                                onPressed: () => unawaited(
                                  _reopenProjectContext(project.id),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded),
                                tooltip: 'Archive closed project $displayName',
                                onPressed: () => unawaited(
                                  _archiveClosedProjectContext(project.id),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
                if (worktreeEnabled) ...[
                  const SizedBox(height: 8),
                  _buildSelectorSectionHeader(dialogContext, 'Workspaces'),
                  for (final worktree in projectProvider.worktrees)
                    ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      leading: Icon(
                        worktree.active
                            ? Icons.folder_special_outlined
                            : Icons.folder_copy_outlined,
                        size: 20,
                      ),
                      title: Text(
                        worktree.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        _directoryLabel(worktree.directory),
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => unawaited(
                        _switchWorkspaceFromSelector(
                          dialogContext,
                          worktree.directory,
                        ),
                      ),
                      trailing: Wrap(
                        spacing: 2,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.restart_alt_rounded),
                            tooltip: 'Reset ${worktree.name}',
                            onPressed: () =>
                                unawaited(_resetWorkspace(worktree.id)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded),
                            tooltip: 'Delete ${worktree.name}',
                            onPressed: () =>
                                unawaited(_deleteWorkspace(worktree.id)),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectorSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
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
    required VoidCallback onSwitch,
    required VoidCallback onClose,
    required bool closeEnabled,
  }) {
    final path = _directoryLabel(project.path);
    final displayName = _projectDisplayLabel(project);

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.folder_open_outlined,
        size: 20,
      ),
      title: Text(displayName, overflow: TextOverflow.ellipsis),
      subtitle: path == displayName
          ? null
          : Text(path, overflow: TextOverflow.ellipsis),
      selected: selected,
      onTap: onSwitch,
      trailing: IconButton(
        icon: const Icon(Icons.close_rounded),
        tooltip: 'Close ${_projectDisplayLabel(project)}',
        onPressed: closeEnabled ? onClose : null,
      ),
    );
  }

  Future<void> _openCreateWorkspaceFromSelector(
    BuildContext dialogContext,
  ) async {
    if (dialogContext.mounted) {
      Navigator.of(dialogContext).pop();
    }
    await Future<void>.delayed(Duration.zero);
    if (!mounted) {
      return;
    }
    await _createWorkspace();
  }

  Future<void> _switchProjectFromSelector(
    BuildContext dialogContext,
    String projectId,
  ) async {
    await _switchProjectContext(projectId);
    if (dialogContext.mounted) {
      Navigator.of(dialogContext).pop();
    }
  }

  Future<void> _switchWorkspaceFromSelector(
    BuildContext dialogContext,
    String directory,
  ) async {
    final projectProvider = context.read<ProjectProvider>();
    final chatProvider = context.read<ChatProvider>();
    final switched = await projectProvider.switchToDirectoryContext(directory);
    if (!switched) {
      return;
    }
    await chatProvider.onProjectScopeChanged();
    if (dialogContext.mounted) {
      Navigator.of(dialogContext).pop();
    }
  }

  String _directoryLabel(String? directory) {
    final trimmed = directory?.trim();
    if (trimmed == null ||
        trimmed.isEmpty ||
        trimmed == '/' ||
        trimmed == '-') {
      return 'Global';
    }
    return trimmed;
  }

  String _directoryBasename(String directoryLabel) {
    if (directoryLabel == 'Global') {
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

  Widget _buildSessionDrawer() {
    return Drawer(
      child: SafeArea(child: _buildSessionPanel(closeOnSelect: true)),
    );
  }

  Future<void> _closeDrawerIfNeeded({required bool closeOnSelect}) async {
    if (!closeOnSelect) {
      return;
    }
    final scaffoldState = Scaffold.maybeOf(context);
    if (!(scaffoldState?.isDrawerOpen ?? false)) {
      return;
    }
    Navigator.of(context).pop();
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> _openLogsPage({required bool closeOnSelect}) async {
    await _closeDrawerIfNeeded(closeOnSelect: closeOnSelect);
    if (!mounted) {
      return;
    }
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const LogsPage()));
  }

  Future<void> _openSettingsPage({required bool closeOnSelect}) async {
    await _closeDrawerIfNeeded(closeOnSelect: closeOnSelect);
    if (!mounted) {
      return;
    }
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SettingsPage()));
  }

  Widget _buildSidebarNavigation({required bool closeOnSelect}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Card(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => unawaited(
                        _openLogsPage(closeOnSelect: closeOnSelect),
                      ),
                      icon: const Icon(Icons.receipt_long_rounded),
                      label: const Text('Logs'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => unawaited(
                        _openSettingsPage(closeOnSelect: closeOnSelect),
                      ),
                      icon: const Icon(Icons.tune_rounded),
                      label: const Text('Settings'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionPanel({
    required bool closeOnSelect,
    VoidCallback? onCollapseRequested,
  }) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        if (_sessionSearchController.text != chatProvider.sessionSearchQuery) {
          _sessionSearchController.value = TextEditingValue(
            text: chatProvider.sessionSearchQuery,
            selection: TextSelection.collapsed(
              offset: chatProvider.sessionSearchQuery.length,
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSidebarNavigation(closeOnSelect: closeOnSelect),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Conversations',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: _createNewSession,
                            tooltip: 'New Chat',
                          ),
                          if (!FeatureFlags.refreshlessRealtime)
                            IconButton(
                              icon: const Icon(Icons.refresh),
                              onPressed: _refreshData,
                              tooltip: 'Refresh',
                            ),
                          if (onCollapseRequested != null)
                            IconButton(
                              key: const ValueKey<String>(
                                'hide_conversations_sidebar_button',
                              ),
                              icon: const Icon(Icons.visibility_off_outlined),
                              onPressed: onCollapseRequested,
                              tooltip: 'Hide Conversations sidebar',
                            ),
                        ],
                      ),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          PopupMenuButton<SessionListFilter>(
                            tooltip: 'Filter sessions',
                            onSelected: chatProvider.setSessionListFilter,
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: SessionListFilter.active,
                                child: Text('Active'),
                              ),
                              PopupMenuItem(
                                value: SessionListFilter.archived,
                                child: Text('Archived'),
                              ),
                              PopupMenuItem(
                                value: SessionListFilter.all,
                                child: Text('All'),
                              ),
                            ],
                            child: _headerChip(
                              context,
                              icon: Icons.filter_list,
                              label: switch (chatProvider.sessionListFilter) {
                                SessionListFilter.active => 'Active',
                                SessionListFilter.archived => 'Archived',
                                SessionListFilter.all => 'All',
                              },
                            ),
                          ),
                          PopupMenuButton<SessionListSort>(
                            tooltip: 'Sort sessions',
                            onSelected: chatProvider.setSessionListSort,
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: SessionListSort.recent,
                                child: Text('Most Recent'),
                              ),
                              PopupMenuItem(
                                value: SessionListSort.oldest,
                                child: Text('Oldest'),
                              ),
                              PopupMenuItem(
                                value: SessionListSort.title,
                                child: Text('Title'),
                              ),
                            ],
                            child: _headerChip(
                              context,
                              icon: Icons.sort,
                              label: switch (chatProvider.sessionListSort) {
                                SessionListSort.recent => 'Recent',
                                SessionListSort.oldest => 'Oldest',
                                SessionListSort.title => 'Title',
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _sessionSearchController,
                        onChanged: chatProvider.setSessionSearchQuery,
                        decoration: InputDecoration(
                          hintText: 'Search conversations',
                          prefixIcon: const Icon(Icons.search),
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: ChatSessionList(
                      sessions: chatProvider.visibleSessions,
                      currentSession: chatProvider.currentSession,
                      onSessionSelected: (session) async {
                        await chatProvider.selectSession(session);
                        if (closeOnSelect && context.mounted) {
                          Navigator.of(context).pop();
                        }
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
                      onSessionForked: (session) async {
                        final created = await chatProvider.forkSession(session);
                        if (!context.mounted) {
                          return;
                        }
                        if (created == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Failed to fork conversation'),
                            ),
                          );
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Conversation forked')),
                        );
                        if (closeOnSelect) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                  ),
                  if (chatProvider.canLoadMoreSessions)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: OutlinedButton.icon(
                        onPressed: chatProvider.loadMoreSessions,
                        icon: const Icon(Icons.expand_more),
                        label: const Text('Load more'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _headerChip(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }

  Widget _buildDesktopUtilityPane(
    ChatProvider chatProvider, {
    VoidCallback? onCollapseRequested,
  }) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (onCollapseRequested != null)
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                key: const ValueKey<String>('hide_utility_sidebar_button'),
                tooltip: 'Hide Utility sidebar',
                onPressed: onCollapseRequested,
                icon: const Icon(Icons.visibility_off_outlined),
              ),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Keyboard shortcuts',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildShortcutHint('Ctrl/Cmd + N', 'New conversation'),
                  if (!FeatureFlags.refreshlessRealtime)
                    _buildShortcutHint('Ctrl/Cmd + R', 'Refresh chat data'),
                  _buildShortcutHint('Ctrl/Cmd + L', 'Focus message input'),
                  _buildShortcutHint(
                    'Ctrl/Cmd + J',
                    'Cycle selected agent (Shift reverses)',
                  ),
                  _buildShortcutHint('Esc', 'Close drawer or unfocus input'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _createNewSession,
            icon: const Icon(Icons.add_comment_outlined),
            label: const Text('New Chat'),
          ),
          if (!FeatureFlags.refreshlessRealtime) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _refreshData,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
          const SizedBox(height: 12),
          if (chatProvider.currentSession != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
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
                                  chatProvider.loadSessionInsights(session.id),
                                );
                              }
                            },
                            icon: const Icon(Icons.sync, size: 18),
                            tooltip: 'Refresh session details',
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
                      'Children: ${chatProvider.currentSessionChildren.length}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      'Todos: ${chatProvider.currentSessionTodo.length}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      'Diff files: ${chatProvider.currentSessionDiff.length}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
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
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDesktopFilePane(
    ChatProvider chatProvider, {
    VoidCallback? onCollapseRequested,
  }) {
    return Consumer2<ProjectProvider, AppProvider>(
      builder: (context, projectProvider, appProvider, child) {
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
            isMobileLayout: false,
            onCollapseRequested: onCollapseRequested,
          ),
        );
      },
    );
  }

  String _normalizeFilePath(String value) {
    var normalized = value.trim().replaceAll('\\', '/');
    if (normalized.length > 1) {
      normalized = normalized.replaceAll(RegExp(r'/+$'), '');
    }
    return normalized;
  }

  String _fileBasename(String path) {
    final normalized = _normalizeFilePath(path);
    if (normalized.isEmpty || normalized == '/') {
      return normalized.isEmpty ? 'file' : '/';
    }
    final separator = normalized.lastIndexOf('/');
    if (separator < 0 || separator == normalized.length - 1) {
      return normalized;
    }
    return normalized.substring(separator + 1);
  }

  String _resolveFileRootDirectory({
    required ProjectProvider projectProvider,
    required AppProvider appProvider,
  }) {
    final directory = projectProvider.currentDirectory;
    if (directory != null && directory.trim().isNotEmpty) {
      return _normalizeFilePath(directory);
    }
    final appPath = appProvider.appInfo?.path.data;
    if (appPath != null && appPath.trim().isNotEmpty) {
      return _normalizeFilePath(appPath);
    }
    return '/';
  }

  _FileExplorerContextState _resolveFileContextState({
    required ProjectProvider projectProvider,
    required AppProvider appProvider,
  }) {
    final contextKey = projectProvider.contextKey;
    final rootDirectory = _resolveFileRootDirectory(
      projectProvider: projectProvider,
      appProvider: appProvider,
    );
    final state = _fileContextStates.putIfAbsent(
      contextKey,
      () => _FileExplorerContextState(rootDirectory: rootDirectory),
    );
    if (state.rootDirectory != rootDirectory) {
      state.resetForRoot(rootDirectory);
    }
    _ensureFileRootLoaded(state: state, projectProvider: projectProvider);
    return state;
  }

  void _ensureFileRootLoaded({
    required _FileExplorerContextState state,
    required ProjectProvider projectProvider,
  }) {
    if (state.rootLoadScheduled) {
      return;
    }
    if (state.loadingDirectories.contains(_rootTreeCacheKey)) {
      return;
    }
    if (state.directoryChildren.containsKey(_rootTreeCacheKey)) {
      return;
    }
    state.rootLoadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      state.rootLoadScheduled = false;
      if (!mounted) {
        return;
      }
      if (state.loadingDirectories.contains(_rootTreeCacheKey)) {
        return;
      }
      if (state.directoryChildren.containsKey(_rootTreeCacheKey)) {
        return;
      }
      unawaited(
        _loadRootDirectoryNodes(state: state, projectProvider: projectProvider),
      );
    });
  }

  void _reconcileFileContextWithSessionDiff({
    required String contextKey,
    required _FileExplorerContextState fileState,
    required ChatProvider chatProvider,
    required ProjectProvider projectProvider,
  }) {
    final diffFiles =
        chatProvider.currentSessionDiff
            .map((item) => item.file.trim())
            .where((item) => item.isNotEmpty)
            .toSet()
            .toList(growable: false)
          ..sort();
    final signature = diffFiles.join('|');
    if (_fileDiffSignaturesByContext[contextKey] == signature) {
      return;
    }
    _fileDiffSignaturesByContext[contextKey] = signature;
    if (signature.isEmpty) {
      return;
    }

    final staleDirectoryKeys = fileState.directoryChildren.keys
        .where((key) {
          if (key == _rootTreeCacheKey) {
            return false;
          }
          final normalizedDirectory = _normalizeFilePath(key);
          return diffFiles.any((diffFile) {
            final absoluteDiff = _resolveDiffAbsolutePath(
              diffFile: diffFile,
              rootDirectory: projectProvider.currentDirectory,
            );
            if (absoluteDiff == null) {
              return false;
            }
            return absoluteDiff == normalizedDirectory ||
                absoluteDiff.startsWith('$normalizedDirectory/');
          });
        })
        .toList(growable: false);
    for (final key in staleDirectoryKeys) {
      fileState.directoryChildren.remove(key);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      for (final tabPath in fileState.tabSelection.openPaths) {
        if (_diffMatchesPath(
          tabPath: tabPath,
          diffFiles: diffFiles,
          rootDirectory: projectProvider.currentDirectory,
        )) {
          unawaited(
            _reloadFileTab(
              fileState: fileState,
              projectProvider: projectProvider,
              path: tabPath,
              silent: true,
            ),
          );
        }
      }

      unawaited(
        _loadRootDirectoryNodes(
          state: fileState,
          projectProvider: projectProvider,
          force: true,
          showLoader: false,
        ),
      );
    });
  }

  bool _diffMatchesPath({
    required String tabPath,
    required List<String> diffFiles,
    required String? rootDirectory,
  }) {
    final normalizedTabPath = _normalizeFilePath(tabPath);
    for (final diffFile in diffFiles) {
      final normalizedDiff = _normalizeFilePath(diffFile);
      if (normalizedDiff.isEmpty) {
        continue;
      }
      if (normalizedTabPath == normalizedDiff ||
          normalizedTabPath.endsWith('/$normalizedDiff')) {
        return true;
      }
      final absoluteDiff = _resolveDiffAbsolutePath(
        diffFile: diffFile,
        rootDirectory: rootDirectory,
      );
      if (absoluteDiff != null && normalizedTabPath == absoluteDiff) {
        return true;
      }
    }
    return false;
  }

  String? _resolveDiffAbsolutePath({
    required String diffFile,
    required String? rootDirectory,
  }) {
    final normalizedDiff = _normalizeFilePath(diffFile);
    if (normalizedDiff.isEmpty) {
      return null;
    }
    if (normalizedDiff.startsWith('/')) {
      return normalizedDiff;
    }
    final normalizedRoot = _normalizeFilePath(rootDirectory ?? '');
    if (normalizedRoot.isEmpty || normalizedRoot == '/') {
      return _normalizeFilePath('/$normalizedDiff');
    }
    return _normalizeFilePath('$normalizedRoot/$normalizedDiff');
  }

  Future<void> _loadRootDirectoryNodes({
    required _FileExplorerContextState state,
    required ProjectProvider projectProvider,
    bool force = false,
    bool showLoader = true,
  }) async {
    final contextDirectory = projectProvider.currentDirectory?.trim();
    final requestPath =
        (contextDirectory != null && contextDirectory.isNotEmpty)
        ? '.'
        : state.rootDirectory;
    await _loadDirectoryNodes(
      state: state,
      projectProvider: projectProvider,
      cacheKey: _rootTreeCacheKey,
      requestPath: requestPath,
      force: force,
      showLoader: showLoader,
    );
  }

  Future<void> _loadDirectoryNodes({
    required _FileExplorerContextState state,
    required ProjectProvider projectProvider,
    required String cacheKey,
    required String requestPath,
    bool force = false,
    bool showLoader = true,
  }) async {
    if (state.loadingDirectories.contains(cacheKey)) {
      return;
    }
    if (!force && state.directoryChildren.containsKey(cacheKey)) {
      return;
    }

    if (mounted) {
      setState(() {
        state.loadingDirectories.add(cacheKey);
      });
    }

    final listed = await _listFilesWithFallback(
      projectProvider: projectProvider,
      requestPath: requestPath,
    );
    if (!mounted) {
      return;
    }

    setState(() {
      state.loadingDirectories.remove(cacheKey);
      if (listed == null) {
        if (cacheKey == _rootTreeCacheKey) {
          state.treeError = projectProvider.error ?? 'Failed to load files';
        }
        return;
      }
      state.directoryChildren[cacheKey] = listed;
      if (cacheKey == _rootTreeCacheKey) {
        state.treeError = null;
      }
      if (showLoader) {
        state.lastLoadedAt = DateTime.now();
      }
    });
  }

  Future<List<FileNode>?> _listFilesWithFallback({
    required ProjectProvider projectProvider,
    required String requestPath,
  }) async {
    final candidates = _listPathCandidates(
      requestPath: requestPath,
      contextDirectory: projectProvider.currentDirectory,
    );
    List<FileNode>? emptyFallback;
    for (final candidate in candidates) {
      final listed = await projectProvider.listFiles(path: candidate);
      if (listed != null) {
        if (listed.isNotEmpty) {
          return listed;
        }
        emptyFallback ??= listed;
      }
    }
    return emptyFallback;
  }

  List<String> _listPathCandidates({
    required String requestPath,
    required String? contextDirectory,
  }) {
    final normalizedPath = _normalizeFilePath(requestPath);
    final normalizedContext = contextDirectory == null
        ? ''
        : _normalizeFilePath(contextDirectory);
    final candidates = <String>{};

    if (normalizedPath.isEmpty || normalizedPath == '.') {
      candidates.add('.');
    } else {
      candidates.add(normalizedPath);
    }

    if (normalizedContext.isNotEmpty && normalizedPath.isNotEmpty) {
      if (normalizedPath == normalizedContext) {
        candidates.add('.');
      }
      final contextPrefix = '$normalizedContext/';
      if (normalizedPath.startsWith(contextPrefix)) {
        final relative = normalizedPath.substring(contextPrefix.length);
        if (relative.isNotEmpty) {
          candidates.add(relative);
          candidates.add('./$relative');
        }
      }
    }

    return candidates.toList(growable: false);
  }

  List<String> _contentPathCandidates({
    required String path,
    required String? contextDirectory,
  }) {
    final normalizedPath = _normalizeFilePath(path);
    final normalizedContext = contextDirectory == null
        ? ''
        : _normalizeFilePath(contextDirectory);
    final candidates = <String>{normalizedPath};
    if (normalizedContext.isNotEmpty) {
      final contextPrefix = '$normalizedContext/';
      if (normalizedPath.startsWith(contextPrefix)) {
        final relative = normalizedPath.substring(contextPrefix.length);
        if (relative.isNotEmpty) {
          candidates.add(relative);
          candidates.add('./$relative');
        }
      }
    }
    return candidates.toList(growable: false);
  }

  Future<FileContent?> _readFileContentWithFallback({
    required ProjectProvider projectProvider,
    required String path,
  }) async {
    final candidates = _contentPathCandidates(
      path: path,
      contextDirectory: projectProvider.currentDirectory,
    );
    FileContent? emptyFallback;
    for (final candidate in candidates) {
      final content = await projectProvider.readFileContent(path: candidate);
      if (content != null) {
        if (content.isBinary || content.content.isNotEmpty) {
          return content;
        }
        emptyFallback ??= content;
      }
    }
    return emptyFallback;
  }

  Future<void> _openQuickFileDialogFromCurrentContext() async {
    if (!mounted) {
      return;
    }
    final projectProvider = context.read<ProjectProvider>();
    final appProvider = context.read<AppProvider>();
    final fileState = _resolveFileContextState(
      projectProvider: projectProvider,
      appProvider: appProvider,
    );
    await _openQuickFileDialog(
      fileState: fileState,
      projectProvider: projectProvider,
      openInDialogAfterSelect: true,
      dialogFullscreen: MediaQuery.sizeOf(context).width < _mobileBreakpoint,
    );
  }

  Future<void> _openQuickFileDialog({
    required _FileExplorerContextState fileState,
    required ProjectProvider projectProvider,
    VoidCallback? onFileOpened,
    required bool openInDialogAfterSelect,
    required bool dialogFullscreen,
  }) async {
    final queryController = TextEditingController();
    var loading = false;
    var errorMessage = '';
    var resultNodes = <FileNode>[];
    var searchRequestId = 0;
    var dialogActive = true;

    resultNodes = fileState.tabSelection.openPaths
        .map(
          (path) => FileNode(
            path: path,
            name: _fileBasename(path),
            type: FileNodeType.file,
          ),
        )
        .toList(growable: false);

    Future<void> runSearch(StateSetter setModalState, String query) async {
      final normalized = query.trim();
      final requestId = ++searchRequestId;

      if (normalized.isEmpty) {
        final recent = fileState.tabSelection.openPaths
            .map(
              (path) => FileNode(
                path: path,
                name: _fileBasename(path),
                type: FileNodeType.file,
              ),
            )
            .toList(growable: false);
        if (!dialogActive) {
          return;
        }
        setModalState(() {
          loading = false;
          errorMessage = '';
          resultNodes = recent;
        });
        return;
      }

      if (!dialogActive) {
        return;
      }
      setModalState(() {
        loading = true;
        errorMessage = '';
      });

      final found = await projectProvider.findFiles(
        query: normalized,
        limit: 120,
      );
      if (!mounted || requestId != searchRequestId || !dialogActive) {
        return;
      }
      if (found == null) {
        setModalState(() {
          loading = false;
          resultNodes = <FileNode>[];
          errorMessage = projectProvider.error ?? 'Failed to search files';
        });
        return;
      }

      final byPath = <String, FileNode>{
        for (final node in found)
          if (node.path.trim().isNotEmpty) _normalizeFilePath(node.path): node,
      };
      final rankedPaths = rankQuickOpenPaths(
        byPath.keys,
        normalized,
        limit: 40,
      );
      setModalState(() {
        loading = false;
        errorMessage = '';
        resultNodes = rankedPaths
            .map((path) {
              final node = byPath[path];
              if (node != null) {
                return node;
              }
              return FileNode(
                path: path,
                name: _fileBasename(path),
                type: FileNodeType.file,
              );
            })
            .where((node) => !node.isDirectory)
            .toList(growable: false);
      });
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setModalState) {
            return AlertDialog(
              title: const Text('Quick Open File'),
              content: SizedBox(
                width: 520,
                height: 420,
                child: Column(
                  children: [
                    TextField(
                      key: const ValueKey<String>('quick_open_input'),
                      controller: queryController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Search files by name or path',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) {
                        unawaited(runSearch(setModalState, value));
                      },
                      onSubmitted: (value) async {
                        if (resultNodes.isEmpty) {
                          return;
                        }
                        final selected = resultNodes.first;
                        dialogActive = false;
                        Navigator.of(dialogContext).pop();
                        await _openFileInTab(
                          fileState: fileState,
                          projectProvider: projectProvider,
                          path: selected.path,
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: loading
                          ? const Center(child: CircularProgressIndicator())
                          : errorMessage.isNotEmpty
                          ? Center(
                              child: Text(
                                errorMessage,
                                textAlign: TextAlign.center,
                              ),
                            )
                          : resultNodes.isEmpty
                          ? Center(
                              child: Text(
                                queryController.text.trim().isEmpty
                                    ? 'No open files yet. Type to search.'
                                    : 'No files found',
                              ),
                            )
                          : ListView.builder(
                              itemCount: resultNodes.length,
                              itemBuilder: (context, index) {
                                final node = resultNodes[index];
                                final normalizedPath = _normalizeFilePath(
                                  node.path,
                                );
                                return ListTile(
                                  key: ValueKey<String>(
                                    'quick_open_result_$normalizedPath',
                                  ),
                                  dense: true,
                                  leading: Icon(
                                    _fileIconForNode(node),
                                    size: 18,
                                  ),
                                  title: Text(
                                    node.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    normalizedPath,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onTap: () async {
                                    dialogActive = false;
                                    Navigator.of(dialogContext).pop();
                                    if (openInDialogAfterSelect) {
                                      await _openFileAndFocusDialog(
                                        fileState: fileState,
                                        projectProvider: projectProvider,
                                        path: normalizedPath,
                                        dialogFullscreen: dialogFullscreen,
                                        onUpdated: onFileOpened,
                                      );
                                    } else {
                                      await _openFileInTab(
                                        fileState: fileState,
                                        projectProvider: projectProvider,
                                        path: normalizedPath,
                                        onUpdated: onFileOpened,
                                      );
                                      onFileOpened?.call();
                                    }
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    dialogActive = false;
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
    dialogActive = false;
  }

  Future<void> _openFileInTab({
    required _FileExplorerContextState fileState,
    required ProjectProvider projectProvider,
    required String path,
    VoidCallback? onUpdated,
  }) async {
    final normalizedPath = _normalizeFilePath(path);
    if (normalizedPath.isEmpty) {
      return;
    }
    if (mounted) {
      setState(() {
        fileState.tabSelection = openFileTab(
          fileState.tabSelection,
          normalizedPath,
        );
      });
      onUpdated?.call();
    }

    final cached = fileState.tabsByPath[normalizedPath];
    if (cached != null &&
        cached.status != _FileTabLoadStatus.error &&
        cached.status != _FileTabLoadStatus.loading) {
      onUpdated?.call();
      return;
    }

    await _reloadFileTab(
      fileState: fileState,
      projectProvider: projectProvider,
      path: normalizedPath,
      onUpdated: onUpdated,
    );
  }

  Future<void> _openFileAndFocusDialog({
    required _FileExplorerContextState fileState,
    required ProjectProvider projectProvider,
    required String path,
    required bool dialogFullscreen,
    VoidCallback? onUpdated,
  }) async {
    await _openFileInTab(
      fileState: fileState,
      projectProvider: projectProvider,
      path: path,
      onUpdated: onUpdated,
    );
    if (!mounted) {
      return;
    }
    await _openOpenFilesDialog(
      fileState: fileState,
      projectProvider: projectProvider,
      fullscreen: dialogFullscreen,
    );
  }

  void _activateFileTab({
    required _FileExplorerContextState fileState,
    required String path,
    VoidCallback? onUpdated,
  }) {
    setState(() {
      fileState.tabSelection = activateFileTab(fileState.tabSelection, path);
    });
    onUpdated?.call();
  }

  void _closeFileTab({
    required _FileExplorerContextState fileState,
    required String path,
    VoidCallback? onUpdated,
  }) {
    setState(() {
      fileState.tabSelection = closeFileTab(fileState.tabSelection, path);
    });
    onUpdated?.call();
  }

  Future<void> _reloadFileTab({
    required _FileExplorerContextState fileState,
    required ProjectProvider projectProvider,
    required String path,
    bool silent = false,
    VoidCallback? onUpdated,
  }) async {
    final normalizedPath = _normalizeFilePath(path);
    if (!silent && mounted) {
      setState(() {
        fileState.tabsByPath[normalizedPath] = const _FileTabViewState(
          status: _FileTabLoadStatus.loading,
          content: '',
        );
      });
      onUpdated?.call();
    }

    final content = await _readFileContentWithFallback(
      projectProvider: projectProvider,
      path: normalizedPath,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      if (content == null) {
        fileState.tabsByPath[normalizedPath] = _FileTabViewState(
          status: _FileTabLoadStatus.error,
          content: '',
          errorMessage: projectProvider.error ?? 'Failed to load file content',
        );
        return;
      }
      if (content.isBinary) {
        fileState.tabsByPath[normalizedPath] = _FileTabViewState(
          status: _FileTabLoadStatus.binary,
          content: '',
          mimeType: content.mimeType,
        );
        return;
      }
      final text = content.content;
      if (text.isEmpty) {
        fileState.tabsByPath[normalizedPath] = _FileTabViewState(
          status: _FileTabLoadStatus.empty,
          content: '',
          mimeType: content.mimeType,
        );
        return;
      }
      fileState.tabsByPath[normalizedPath] = _FileTabViewState(
        status: _FileTabLoadStatus.ready,
        content: text,
        mimeType: content.mimeType,
      );
    });
    onUpdated?.call();
  }

  Future<void> _openOpenFilesDialog({
    required _FileExplorerContextState fileState,
    required ProjectProvider projectProvider,
    required bool fullscreen,
  }) async {
    if (!fileState.tabSelection.hasOpenTabs || !mounted) {
      return;
    }
    final mediaQuery = MediaQuery.of(context);
    final dialogWidth = (mediaQuery.size.width * 0.7).clamp(560.0, 1200.0);
    final dialogHeight = (mediaQuery.size.height * 0.7).clamp(420.0, 900.0);

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            if (fullscreen) {
              return Dialog.fullscreen(
                key: const ValueKey<String>('open_files_dialog_fullscreen'),
                child: Scaffold(
                  appBar: AppBar(
                    title: Text(
                      'Open files (${fileState.tabSelection.openPaths.length})',
                    ),
                    leading: IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(dialogContext).pop(),
                    ),
                  ),
                  body: _buildFileViewerPanel(
                    fileState: fileState,
                    projectProvider: projectProvider,
                    height: double.infinity,
                    margin: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                    onStateChanged: () => setDialogState(() {}),
                  ),
                ),
              );
            }
            return Dialog(
              key: const ValueKey<String>('open_files_dialog_centered'),
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                width: dialogWidth.toDouble(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: 300,
                    maxHeight: dialogHeight.toDouble(),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Open files (${fileState.tabSelection.openPaths.length})',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Close',
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: _buildFileViewerPanel(
                          fileState: fileState,
                          projectProvider: projectProvider,
                          height: double.infinity,
                          margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                          onStateChanged: () => setDialogState(() {}),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFileExplorerPanel({
    required _FileExplorerContextState fileState,
    required ProjectProvider projectProvider,
    required bool isMobileLayout,
    VoidCallback? onStateChanged,
    VoidCallback? onCollapseRequested,
  }) {
    final rootNodes = fileState.directoryChildren[_rootTreeCacheKey];
    final rootLoading = fileState.loadingDirectories.contains(
      _rootTreeCacheKey,
    );
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Files',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (fileState.tabSelection.hasOpenTabs)
                    Flexible(
                      child: TextButton(
                        key: const ValueKey<String>(
                          'file_tree_open_files_button',
                        ),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () {
                          unawaited(
                            _openOpenFilesDialog(
                              fileState: fileState,
                              projectProvider: projectProvider,
                              fullscreen: isMobileLayout,
                            ),
                          );
                        },
                        child: Text(
                          '${fileState.tabSelection.openPaths.length} open file${fileState.tabSelection.openPaths.length == 1 ? '' : 's'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  IconButton(
                    key: const ValueKey<String>('file_tree_quick_open_button'),
                    tooltip: 'Quick Open',
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    onPressed: () {
                      unawaited(
                        _openQuickFileDialog(
                          fileState: fileState,
                          projectProvider: projectProvider,
                          onFileOpened: onStateChanged,
                          openInDialogAfterSelect: true,
                          dialogFullscreen: isMobileLayout,
                        ),
                      );
                    },
                    icon: const Icon(Icons.search),
                  ),
                  IconButton(
                    key: const ValueKey<String>('file_tree_refresh_button'),
                    tooltip: 'Refresh files',
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    onPressed: () {
                      unawaited(
                        _loadRootDirectoryNodes(
                          state: fileState,
                          projectProvider: projectProvider,
                          force: true,
                        ),
                      );
                    },
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                  if (onCollapseRequested != null)
                    IconButton(
                      key: const ValueKey<String>('hide_files_sidebar_button'),
                      tooltip: 'Hide Files sidebar',
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      onPressed: onCollapseRequested,
                      icon: const Icon(Icons.visibility_off_outlined),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text(
                _directoryLabel(projectProvider.currentDirectory),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Builder(
                builder: (_) {
                  if (rootLoading && (rootNodes == null || rootNodes.isEmpty)) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (fileState.treeError != null &&
                      (rootNodes == null || rootNodes.isEmpty)) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              fileState.treeError!,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: () {
                                unawaited(
                                  _loadRootDirectoryNodes(
                                    state: fileState,
                                    projectProvider: projectProvider,
                                    force: true,
                                  ),
                                );
                              },
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  if (rootNodes == null || rootNodes.isEmpty) {
                    return const Center(child: Text('No files found'));
                  }
                  return ListView(
                    key: const ValueKey<String>('file_tree_list'),
                    children: _buildFileTreeChildren(
                      fileState: fileState,
                      projectProvider: projectProvider,
                      dialogFullscreen: isMobileLayout,
                      onStateChanged: onStateChanged,
                      parentCacheKey: _rootTreeCacheKey,
                      depth: 0,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFileTreeChildren({
    required _FileExplorerContextState fileState,
    required ProjectProvider projectProvider,
    required bool dialogFullscreen,
    VoidCallback? onStateChanged,
    required String parentCacheKey,
    required int depth,
  }) {
    final nodes =
        fileState.directoryChildren[parentCacheKey] ?? const <FileNode>[];
    final rows = <Widget>[];
    for (final node in nodes) {
      final isExpanded = fileState.expandedDirectories.contains(node.path);
      final isLoading = fileState.loadingDirectories.contains(node.path);
      final isActiveFile = fileState.tabSelection.activePath == node.path;
      rows.add(
        InkWell(
          key: ValueKey<String>(
            'file_tree_item_${_normalizeFilePath(node.path)}',
          ),
          onTap: () {
            if (node.isDirectory) {
              if (isExpanded) {
                setState(() {
                  fileState.expandedDirectories.remove(node.path);
                });
                return;
              }
              setState(() {
                fileState.expandedDirectories.add(node.path);
              });
              unawaited(
                _loadDirectoryNodes(
                  state: fileState,
                  projectProvider: projectProvider,
                  cacheKey: node.path,
                  requestPath: node.path,
                ),
              );
              return;
            }
            unawaited(
              _openFileAndFocusDialog(
                fileState: fileState,
                projectProvider: projectProvider,
                path: node.path,
                dialogFullscreen: dialogFullscreen,
                onUpdated: onStateChanged,
              ),
            );
          },
          child: Container(
            color: isActiveFile
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
                : null,
            padding: EdgeInsets.fromLTRB(8 + (depth * 14), 6, 8, 6),
            child: Row(
              children: [
                if (node.isDirectory)
                  Icon(
                    isExpanded ? Icons.expand_more : Icons.chevron_right,
                    size: 16,
                  )
                else
                  const SizedBox(width: 16),
                const SizedBox(width: 2),
                Icon(
                  _fileIconForNode(node),
                  size: 16,
                  color: node.isDirectory
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    node.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                if (isLoading)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.6),
                  ),
              ],
            ),
          ),
        ),
      );
      if (node.isDirectory && isExpanded) {
        rows.addAll(
          _buildFileTreeChildren(
            fileState: fileState,
            projectProvider: projectProvider,
            dialogFullscreen: dialogFullscreen,
            onStateChanged: onStateChanged,
            parentCacheKey: node.path,
            depth: depth + 1,
          ),
        );
      }
    }
    return rows;
  }

  IconData _fileIconForNode(FileNode node) {
    if (node.isDirectory) {
      return _directoryIconForPath(node.path);
    }
    return _fileIconForPath(node.path);
  }

  IconData _directoryIconForPath(String path) {
    final normalizedPath = _normalizeFilePath(path).toLowerCase();
    if (normalizedPath.endsWith('/.github/workflows')) {
      return SimpleIcons.githubactions;
    }
    final folderName = _fileNameFromPath(normalizedPath);
    switch (folderName) {
      case '.github':
        return SimpleIcons.github;
      case '.vscode':
        return SimpleIcons.vscodium;
      case '.idea':
        return SimpleIcons.jetbrains;
      case '.dart_tool':
        return SimpleIcons.dart;
      case '.vite':
        return SimpleIcons.vite;
      case '.husky':
        return SimpleIcons.git;
      case 'android':
        return SimpleIcons.android;
      case 'ios':
        return SimpleIcons.ios;
      case 'macos':
        return SimpleIcons.macos;
      case 'linux':
        return SimpleIcons.linux;
      case '.git':
        return SimpleIcons.git;
      case '.gradle':
        return SimpleIcons.gradle;
      case '.firebase':
        return SimpleIcons.firebase;
      case 'node_modules':
        return SimpleIcons.nodedotjs;
      case 'docker':
        return SimpleIcons.docker;
      case 'scripts':
        return SimpleIcons.iterm2;
      case 'k8s':
      case 'kubernetes':
        return SimpleIcons.kubernetes;
      case 'infra':
      case 'infrastructure':
      case 'terraform':
      case '.terraform':
        return SimpleIcons.terraform;
      case '.next':
        return SimpleIcons.nextdotjs;
      case 'venv':
      case '.venv':
        return SimpleIcons.python;
      default:
        return Icons.folder_outlined;
    }
  }

  IconData _fileIconForPath(String path) {
    final normalizedPath = path.trim().replaceAll('\\', '/').toLowerCase();
    final fileName = _fileNameFromPath(normalizedPath);
    final extension = _fileExtension(fileName);

    // Prefer filename-based mappings for canonical config/build files.
    switch (fileName) {
      case 'package.json':
      case 'package-lock.json':
      case 'npm-shrinkwrap.json':
      case '.npmrc':
        return SimpleIcons.npm;
      case 'pnpm-lock.yaml':
      case 'pnpm-lock.yml':
      case '.pnpmfile.cjs':
        return SimpleIcons.pnpm;
      case 'yarn.lock':
      case '.yarnrc':
      case '.yarnrc.yml':
        return SimpleIcons.yarn;
      case 'bun.lockb':
      case 'bunfig.toml':
        return SimpleIcons.bun;
      case 'dockerfile':
      case '.dockerignore':
      case 'docker-compose.yml':
      case 'docker-compose.yaml':
      case 'compose.yml':
      case 'compose.yaml':
        return SimpleIcons.docker;
      case '.gitignore':
      case '.gitattributes':
      case '.gitmodules':
        return SimpleIcons.git;
      case 'readme.md':
      case 'changelog.md':
      case 'contributing.md':
      case 'license':
      case 'license.md':
        return SimpleIcons.markdown;
      case 'pubspec.yaml':
      case 'pubspec.lock':
      case 'analysis_options.yaml':
        return SimpleIcons.flutter;
      case 'tsconfig.json':
      case 'tsconfig.base.json':
        return SimpleIcons.typescript;
      case 'vite.config.ts':
      case 'vite.config.js':
      case 'vite.config.mjs':
      case 'vite.config.cjs':
      case 'vite.config.mts':
      case 'vite.config.cts':
      case 'vite-env.d.ts':
      case 'vite.svg':
      case 'vitest.config.ts':
      case 'vitest.config.js':
      case 'vitest.config.mjs':
      case 'vitest.config.cjs':
      case 'vitest.config.mts':
      case 'vitest.config.cts':
        return SimpleIcons.vite;
      case 'next.config.ts':
      case 'next.config.js':
      case 'next.config.mjs':
      case 'next.config.cjs':
        return SimpleIcons.nextdotjs;
      case 'webpack.config.ts':
      case 'webpack.config.js':
      case 'webpack.config.mjs':
      case 'webpack.config.cjs':
        return SimpleIcons.webpack;
      case 'rollup.config.ts':
      case 'rollup.config.js':
      case 'rollup.config.mjs':
      case 'rollup.config.cjs':
        return SimpleIcons.rollupdotjs;
      case '.eslintrc':
      case '.eslintrc.js':
      case '.eslintrc.cjs':
      case '.eslintrc.json':
      case '.eslintrc.yml':
      case '.eslintrc.yaml':
      case 'eslint.config.js':
      case 'eslint.config.mjs':
      case 'eslint.config.cjs':
      case 'eslint.config.ts':
        return SimpleIcons.eslint;
      case '.prettierrc':
      case '.prettierrc.js':
      case '.prettierrc.cjs':
      case '.prettierrc.json':
      case '.prettierrc.yml':
      case '.prettierrc.yaml':
      case 'prettier.config.js':
      case 'prettier.config.mjs':
      case 'prettier.config.cjs':
      case 'prettier.config.ts':
        return SimpleIcons.prettier;
      case 'tailwind.config.js':
      case 'tailwind.config.mjs':
      case 'tailwind.config.cjs':
      case 'tailwind.config.ts':
        return SimpleIcons.tailwindcss;
      case 'firebase.json':
      case '.firebaserc':
        return SimpleIcons.firebase;
      case 'go.mod':
      case 'go.sum':
        return SimpleIcons.go;
      case 'cargo.toml':
      case 'cargo.lock':
        return SimpleIcons.rust;
      case 'composer.json':
      case 'composer.lock':
        return SimpleIcons.php;
      case 'requirements.txt':
      case 'pyproject.toml':
        return SimpleIcons.python;
      case 'gemfile':
      case 'gemfile.lock':
        return SimpleIcons.ruby;
      case '.nvmrc':
      case 'nodemon.json':
        return SimpleIcons.nodedotjs;
      case 'jenkinsfile':
      case 'jenkins.yaml':
      case 'jenkins.yml':
        return SimpleIcons.jenkins;
      case 'makefile':
        return Icons.build_outlined;
      case '.bashrc':
      case '.bash_profile':
      case '.bash_aliases':
      case '.zshrc':
      case '.zprofile':
      case '.zshenv':
      case '.profile':
        return SimpleIcons.iterm2;
      case 'id_rsa':
      case 'id_rsa.pub':
      case 'id_dsa':
      case 'id_dsa.pub':
      case 'id_ecdsa':
      case 'id_ecdsa.pub':
      case 'id_ed25519':
      case 'id_ed25519.pub':
        return SimpleIcons.passbolt;
      case '.env':
      case '.env.local':
      case '.env.development':
      case '.env.production':
        return SimpleIcons.dotenv;
    }

    // Then apply extension-based mappings.
    switch (extension) {
      case 'dart':
        return SimpleIcons.dart;
      case 'ts':
      case 'mts':
      case 'cts':
        return SimpleIcons.typescript;
      case 'tsx':
      case 'jsx':
        return SimpleIcons.react;
      case 'js':
      case 'mjs':
      case 'cjs':
        return SimpleIcons.javascript;
      case 'vue':
        return SimpleIcons.vuedotjs;
      case 'html':
      case 'htm':
        return SimpleIcons.html5;
      case 'css':
        return SimpleIcons.css;
      case 'scss':
      case 'sass':
        return SimpleIcons.sass;
      case 'less':
        return SimpleIcons.less;
      case 'styl':
      case 'stylus':
        return SimpleIcons.stylus;
      case 'md':
      case 'mdx':
      case 'rst':
        return SimpleIcons.markdown;
      case 'txt':
        return Icons.article;
      case 'json':
        return SimpleIcons.json;
      case 'yaml':
      case 'yml':
        return SimpleIcons.yaml;
      case 'toml':
        return SimpleIcons.toml;
      case 'py':
        return SimpleIcons.python;
      case 'go':
        return SimpleIcons.go;
      case 'rs':
        return SimpleIcons.rust;
      case 'java':
        return SimpleIcons.openjdk;
      case 'kt':
      case 'kts':
        return SimpleIcons.kotlin;
      case 'swift':
        return SimpleIcons.swift;
      case 'php':
        return SimpleIcons.php;
      case 'rb':
        return SimpleIcons.ruby;
      case 'lua':
        return SimpleIcons.lua;
      case 'sh':
      case 'ash':
      case 'bash':
      case 'zsh':
        return SimpleIcons.iterm2;
      case 'csv':
        return Icons.table_chart;
      case 'tsv':
        return Icons.table_rows;
      case 'sql':
        return SimpleIcons.postgresql;
      case 'pem':
      case 'key':
      case 'crt':
      case 'cer':
      case 'p12':
      case 'pfx':
        return SimpleIcons.passbolt;
      case 'sqlite':
      case 'db':
        return SimpleIcons.sqlite;
      case 'mysql':
        return SimpleIcons.mysql;
      case 'redis':
        return SimpleIcons.redis;
      case 'xml':
      case 'ini':
      case 'cfg':
      case 'conf':
      case 'properties':
        return Icons.data_object_rounded;
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
      case 'webp':
      case 'bmp':
      case 'tif':
      case 'tiff':
      case 'avif':
      case 'ico':
        return SimpleIcons.googlephotos;
      case 'svg':
        return SimpleIcons.svg;
      case 'svgz':
        return SimpleIcons.inkscape;
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  String _fileNameFromPath(String normalizedPath) {
    if (normalizedPath.isEmpty) {
      return normalizedPath;
    }
    final separator = normalizedPath.lastIndexOf('/');
    if (separator < 0 || separator == normalizedPath.length - 1) {
      return normalizedPath;
    }
    return normalizedPath.substring(separator + 1);
  }

  String _fileExtension(String fileName) {
    final separator = fileName.lastIndexOf('.');
    if (separator <= 0 || separator == fileName.length - 1) {
      return '';
    }
    return fileName.substring(separator + 1);
  }

  Widget _buildFileViewerPanel({
    required _FileExplorerContextState fileState,
    required ProjectProvider projectProvider,
    double height = 250,
    EdgeInsetsGeometry margin = const EdgeInsets.fromLTRB(8, 0, 8, 8),
    VoidCallback? onStateChanged,
  }) {
    if (!fileState.tabSelection.hasOpenTabs) {
      return const SizedBox.shrink();
    }

    final activePath =
        fileState.tabSelection.activePath ??
        fileState.tabSelection.openPaths.first;
    final active =
        fileState.tabsByPath[activePath] ??
        const _FileTabViewState(
          status: _FileTabLoadStatus.loading,
          content: '',
        );

    return Container(
      key: const ValueKey<String>('file_viewer_panel'),
      height: height,
      margin: margin,
      child: Card(
        child: Column(
          children: [
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                children: [
                  for (final path in fileState.tabSelection.openPaths)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Container(
                        key: ValueKey<String>(
                          'file_viewer_tab_${_normalizeFilePath(path)}',
                        ),
                        decoration: BoxDecoration(
                          color: path == activePath
                              ? Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.14)
                              : Theme.of(context).colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () {
                                _activateFileTab(
                                  fileState: fileState,
                                  path: path,
                                  onUpdated: onStateChanged,
                                );
                              },
                              borderRadius: BorderRadius.circular(999),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(_fileIconForPath(path), size: 14),
                                    const SizedBox(width: 6),
                                    Text(
                                      _fileBasename(path),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelSmall,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            IconButton(
                              key: ValueKey<String>(
                                'file_viewer_tab_close_${_normalizeFilePath(path)}',
                              ),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 22,
                                minHeight: 22,
                              ),
                              icon: const Icon(Icons.close, size: 14),
                              onPressed: () {
                                _closeFileTab(
                                  fileState: fileState,
                                  path: path,
                                  onUpdated: onStateChanged,
                                );
                              },
                            ),
                            const SizedBox(width: 4),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Builder(
                builder: (_) {
                  switch (active.status) {
                    case _FileTabLoadStatus.loading:
                      return const Center(child: CircularProgressIndicator());
                    case _FileTabLoadStatus.error:
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                active.errorMessage ?? 'Failed to load file',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton(
                                key: const ValueKey<String>(
                                  'file_viewer_retry_button',
                                ),
                                onPressed: () {
                                  unawaited(
                                    _reloadFileTab(
                                      fileState: fileState,
                                      projectProvider: projectProvider,
                                      path: activePath,
                                      onUpdated: onStateChanged,
                                    ),
                                  );
                                },
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      );
                    case _FileTabLoadStatus.binary:
                      return const Center(
                        child: Text('Binary file preview is not available.'),
                      );
                    case _FileTabLoadStatus.empty:
                      return const Center(child: Text('File is empty.'));
                    case _FileTabLoadStatus.ready:
                      return SelectionArea(
                        child: SingleChildScrollView(
                          key: ValueKey<String>(
                            'file_viewer_scroll_${_normalizeFilePath(activePath)}',
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            active.content,
                            key: const ValueKey<String>(
                              'file_viewer_content_text',
                            ),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  fontFamily: 'monospace',
                                  height: 1.4,
                                ),
                          ),
                        ),
                      );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShortcutHint(String shortcut, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              shortcut,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              description,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatContent({
    required ChatProvider chatProvider,
    required double maxContentWidth,
    required double horizontalPadding,
    required double verticalPadding,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: Column(
            children: [
              // Current session info - modern design
              if (chatProvider.currentSession != null)
                Builder(
                  builder: (context) {
                    final currentSession = chatProvider.currentSession!;
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.all(8),
                      child: Card(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.chat_bubble_outline,
                                    size: 18,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSecondaryContainer,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: SessionTitleInlineEditor(
                                      key: ValueKey<String>(
                                        'chat_header_session_title_editor_${currentSession.id}',
                                      ),
                                      title: _sessionDisplayTitle(
                                        currentSession,
                                      ),
                                      editingValue: _sessionEditingValue(
                                        currentSession,
                                      ),
                                      textStyle: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSecondaryContainer,
                                            fontWeight: FontWeight.w700,
                                          ),
                                      onRename: (title) => chatProvider
                                          .renameSession(currentSession, title),
                                    ),
                                  ),
                                  if (chatProvider.currentSessionStatus != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        _sessionStatusLabel(
                                          chatProvider.currentSessionStatus!,
                                        ),
                                        style: Theme.of(
                                          context,
                                        ).textTheme.labelSmall,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _metaChip(
                                    context,
                                    icon: Icons.call_split,
                                    label:
                                        'Children: ${chatProvider.currentSessionChildren.length}',
                                  ),
                                  _metaChip(
                                    context,
                                    icon: Icons.checklist,
                                    label:
                                        'Todos: ${chatProvider.currentSessionTodo.length}',
                                  ),
                                  _metaChip(
                                    context,
                                    icon: Icons.compare_arrows,
                                    label:
                                        'Diff: ${chatProvider.currentSessionDiff.length}',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              // Message list
              Expanded(child: _buildMessageViewport(chatProvider)),

              _buildInteractionPrompts(chatProvider),

              _buildModelControls(chatProvider),

              // Input field
              Builder(
                builder: (context) {
                  final selectedModel = chatProvider.selectedModel;
                  final supportsImages = _supportsImageAttachments(
                    selectedModel,
                  );
                  final supportsPdf = _supportsPdfAttachments(selectedModel);
                  final sentMessageHistory = _collectSentMessageHistory(
                    chatProvider.messages,
                  );
                  return ChatInputWidget(
                    onSendMessage: (submission) async {
                      await chatProvider.sendMessage(
                        submission.text,
                        attachments: submission.attachments,
                        shellMode: submission.mode == ChatComposerMode.shell,
                      );
                      // Technical comment translated to English.
                      _scrollToBottom(force: true);
                    },
                    onStopRequested: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final stopped = await chatProvider.abortActiveResponse();
                      if (stopped || !context.mounted) {
                        return;
                      }
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            chatProvider.errorMessage ??
                                'Failed to stop current response',
                          ),
                        ),
                      );
                    },
                    onMentionQuery: _queryMentionSuggestions,
                    onSlashQuery: _querySlashSuggestions,
                    onBuiltinSlashCommand: (commandName) =>
                        _handleBuiltinSlashCommand(
                          commandName: commandName,
                          chatProvider: chatProvider,
                        ),
                    sentMessageHistory: sentMessageHistory,
                    prefilledText: _composerPrefilledText,
                    prefilledTextVersion: _composerPrefilledTextVersion,
                    enabled: chatProvider.currentSession != null,
                    isResponding: chatProvider.canAbortActiveResponse,
                    focusNode: _inputFocusNode,
                    showAttachmentButton: supportsImages || supportsPdf,
                    allowImageAttachment: supportsImages,
                    allowPdfAttachment: supportsPdf,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModelControls(ChatProvider chatProvider) {
    final selectedModel = chatProvider.selectedModel;
    final selectedProvider = chatProvider.selectedProvider;
    final selectedAgent = chatProvider.selectedAgentName;
    final selectableAgents = chatProvider.selectableAgents;
    final variants = chatProvider.availableVariants;
    final selectedModelIcon = _providerBrandIcon(
      providerId: chatProvider.selectedProviderId,
      providerName: selectedProvider?.name,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Tooltip(
            message: 'Choose agent',
            child: Builder(
              key: _agentSelectorChipKey,
              builder: (chipContext) => ActionChip(
                key: const ValueKey<String>('agent_selector_button'),
                avatar: const Icon(Icons.support_agent_outlined, size: 18),
                label: Text(
                  selectedAgent == null
                      ? 'Select agent'
                      : _formatAgentLabel(selectedAgent),
                ),
                onPressed: selectableAgents.isEmpty
                    ? null
                    : () => unawaited(
                        _openAgentQuickSelector(
                          chatProvider,
                          anchorContext: chipContext,
                        ),
                      ),
              ),
            ),
          ),
          Tooltip(
            message: 'Choose model',
            child: ActionChip(
              key: const ValueKey<String>('model_selector_button'),
              avatar: Icon(selectedModelIcon, size: 18),
              label: Text(selectedModel?.name ?? 'Select model'),
              onPressed: chatProvider.providers.isEmpty
                  ? null
                  : () => unawaited(_openModelSelector(chatProvider)),
            ),
          ),
          if (variants.isNotEmpty)
            Builder(
              builder: (chipContext) => ActionChip(
                key: const ValueKey<String>('variant_selector_button'),
                avatar: const Icon(Icons.psychology_alt_outlined, size: 18),
                label: Text(chatProvider.selectedVariantLabel),
                onPressed: () => unawaited(
                  _openVariantQuickSelector(
                    chatProvider,
                    anchorContext: chipContext,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatAgentLabel(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return value;
    }
    return '${trimmed[0].toUpperCase()}${trimmed.substring(1)}';
  }

  IconData _providerBrandIcon({
    required String? providerId,
    required String? providerName,
  }) {
    final normalizedProvider = '${providerId ?? ''} ${providerName ?? ''}'
        .trim()
        .toLowerCase();

    if (_containsAnyBrandToken(normalizedProvider, const ['anthropic'])) {
      return SimpleIcons.anthropic;
    }
    if (_containsAnyBrandToken(normalizedProvider, const ['google'])) {
      return SimpleIcons.google;
    }
    if (_containsAnyBrandToken(normalizedProvider, const ['openrouter'])) {
      return SimpleIcons.openrouter;
    }
    if (_containsAnyBrandToken(normalizedProvider, const ['minimax'])) {
      return SimpleIcons.minimax;
    }
    if (_containsAnyBrandToken(normalizedProvider, const ['mistral'])) {
      return SimpleIcons.mistralai;
    }
    if (_containsAnyBrandToken(normalizedProvider, const ['xai'])) {
      return SimpleIcons.spacex;
    }
    if (_containsAnyBrandToken(normalizedProvider, const ['github'])) {
      return SimpleIcons.github;
    }
    if (_containsAnyBrandToken(normalizedProvider, const ['gitlab'])) {
      return SimpleIcons.gitlab;
    }
    if (_containsAnyBrandToken(normalizedProvider, const ['cloudflare'])) {
      return SimpleIcons.cloudflare;
    }
    if (_containsAnyBrandToken(normalizedProvider, const ['ollama'])) {
      return SimpleIcons.ollama;
    }
    if (_containsAnyBrandToken(normalizedProvider, const ['huggingface'])) {
      return SimpleIcons.huggingface;
    }
    if (_containsAnyBrandToken(normalizedProvider, const ['vercel'])) {
      return SimpleIcons.vercel;
    }
    if (_containsAnyBrandToken(normalizedProvider, const ['perplexity'])) {
      return SimpleIcons.perplexity;
    }
    if (_containsAnyBrandToken(normalizedProvider, const ['nvidia'])) {
      return SimpleIcons.nvidia;
    }
    if (_containsAnyBrandToken(normalizedProvider, const ['alibaba'])) {
      return SimpleIcons.alibabacloud;
    }
    if (_containsAnyBrandToken(normalizedProvider, const ['poe'])) {
      return SimpleIcons.poe;
    }
    if (_containsAnyBrandToken(normalizedProvider, const ['scaleway'])) {
      return SimpleIcons.scaleway;
    }
    if (_containsAnyBrandToken(normalizedProvider, const ['sap'])) {
      return SimpleIcons.sap;
    }
    if (_containsAnyBrandToken(normalizedProvider, const ['v0'])) {
      return SimpleIcons.v0;
    }

    return Icons.smart_toy_outlined;
  }

  IconData _modelSelectorListIcon({
    required String? providerId,
    required String? providerName,
    required String? modelId,
    required String? modelName,
  }) {
    final normalizedModel = '${modelId ?? ''} ${modelName ?? ''}'
        .trim()
        .toLowerCase();
    final normalizedProvider = '${providerId ?? ''} ${providerName ?? ''}'
        .trim()
        .toLowerCase();

    // Model-aware matching first to avoid ambiguous provider IDs.
    if (_containsAnyBrandToken(normalizedModel, const [
      'claude',
      'anthropic',
    ])) {
      return SimpleIcons.claude;
    }
    if (_containsAnyBrandToken(normalizedModel, const ['gemini', 'google'])) {
      return SimpleIcons.googlegemini;
    }

    final providerIcon = _providerBrandIcon(
      providerId: providerId,
      providerName: providerName,
    );
    return providerIcon;
  }

  bool _containsAnyBrandToken(String source, List<String> tokens) {
    for (final token in tokens) {
      if (source.contains(token)) {
        return true;
      }
    }
    return false;
  }

  List<String> _collectSentMessageHistory(List<ChatMessage> messages) {
    final history = <String>[];
    for (final message in messages) {
      if (message.role != MessageRole.user) {
        continue;
      }
      final text = message.parts
          .whereType<TextPart>()
          .map((part) => part.text)
          .join('\n')
          .trim();
      if (text.isEmpty) {
        continue;
      }
      history.add(text);
    }
    return List<String>.unmodifiable(history);
  }

  String _extractUserMessageText(ChatMessage message) {
    return message.parts
        .whereType<TextPart>()
        .map((part) => part.text)
        .join('\n')
        .trim();
  }

  bool get _isMobileViewport {
    if (!mounted) {
      return false;
    }
    return MediaQuery.sizeOf(context).width < _mobileBreakpoint;
  }

  void _handleMessageBackgroundLongPress(ChatMessage message) {
    if (!_isMobileViewport || message.role != MessageRole.user) {
      return;
    }
    final text = _extractUserMessageText(message);
    if (text.isEmpty) {
      return;
    }
    setState(() {
      _composerPrefilledText = text;
      _composerPrefilledTextVersion += 1;
    });
    unawaited(HapticFeedback.selectionClick());
  }

  void _handleMessageBackgroundLongPressEnd(ChatMessage message) {
    if (!_isMobileViewport || message.role != MessageRole.user) {
      return;
    }
    final text = _extractUserMessageText(message);
    if (text.isEmpty) {
      return;
    }
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 16), () {
        if (!mounted) {
          return;
        }
        _inputFocusNode.requestFocus();
      }),
    );
  }

  String _agentKey(String name) {
    return name.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  }

  Future<void> _openAgentQuickSelector(
    ChatProvider chatProvider, {
    required BuildContext anchorContext,
  }) async {
    final entries = chatProvider.selectableAgents;
    if (entries.isEmpty) {
      return;
    }
    final buttonBox = anchorContext.findRenderObject() as RenderBox?;
    final overlayBox =
        Overlay.of(anchorContext).context.findRenderObject() as RenderBox?;
    if (buttonBox == null || overlayBox == null) {
      return;
    }
    final buttonTopLeft = buttonBox.localToGlobal(
      Offset.zero,
      ancestor: overlayBox,
    );
    final buttonRect = buttonTopLeft & buttonBox.size;
    const margin = 8.0;
    const menuWidth = 260.0;
    final left = (buttonRect.center.dx - (menuWidth / 2))
        .clamp(margin, overlayBox.size.width - menuWidth - margin)
        .toDouble();
    final top = (buttonRect.top - 4).clamp(margin, overlayBox.size.height - 48);

    final selected = await showMenu<String>(
      context: context,
      constraints: const BoxConstraints(
        minWidth: menuWidth,
        maxWidth: menuWidth,
      ),
      position: RelativeRect.fromLTRB(
        left,
        top.toDouble(),
        overlayBox.size.width - left - menuWidth,
        overlayBox.size.height - top.toDouble(),
      ),
      items: [
        for (final entry in entries)
          PopupMenuItem<String>(
            key: ValueKey<String>(
              'agent_selector_item_${_agentKey(entry.name)}',
            ),
            value: entry.name,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _formatAgentLabel(entry.name),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (chatProvider.selectedAgentName == entry.name)
                  const Icon(Icons.check_rounded, size: 18),
              ],
            ),
          ),
      ],
    );
    if (selected == null) {
      return;
    }
    await chatProvider.setSelectedAgent(selected);
  }

  List<_ModelSelectorEntry> _buildModelSelectorEntries(
    ChatProvider chatProvider,
  ) {
    final entries = <_ModelSelectorEntry>[];
    final providers = _sortedProviders(chatProvider);
    for (final provider in providers) {
      final models = provider.models.values.toList(growable: false)
        ..sort((a, b) {
          final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          if (byName != 0) {
            return byName;
          }
          return a.id.compareTo(b.id);
        });
      for (final model in models) {
        entries.add(
          _ModelSelectorEntry(
            providerId: provider.id,
            providerName: provider.name,
            modelId: model.id,
            modelName: model.name,
          ),
        );
      }
    }
    return entries;
  }

  List<Provider> _sortedProviders(ChatProvider chatProvider) {
    final providers = List.of(chatProvider.providers);
    providers.sort((a, b) {
      final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      if (byName != 0) {
        return byName;
      }
      return a.id.compareTo(b.id);
    });
    return providers;
  }

  String _selectorEntryKey(String providerId, String modelId) {
    return '$providerId/$modelId';
  }

  String? _providerIdFromSelectorKey(String modelKey) {
    final separatorIndex = modelKey.indexOf('/');
    if (separatorIndex <= 0) {
      return null;
    }
    return modelKey.substring(0, separatorIndex);
  }

  String? _modelIdFromSelectorKey(String modelKey) {
    final separatorIndex = modelKey.indexOf('/');
    if (separatorIndex <= 0 || separatorIndex == modelKey.length - 1) {
      return null;
    }
    return modelKey.substring(separatorIndex + 1);
  }

  List<_ModelSelectorEntry> _buildRecentModelEntries(
    ChatProvider chatProvider,
    List<_ModelSelectorEntry> allEntries,
  ) {
    final byKey = <String, _ModelSelectorEntry>{
      for (final entry in allEntries)
        _selectorEntryKey(entry.providerId, entry.modelId): entry,
    };
    final recent = <_ModelSelectorEntry>[];
    final seen = <String>{};

    for (final recentModelKey in chatProvider.recentModelKeys) {
      final providerId = _providerIdFromSelectorKey(recentModelKey);
      final modelId = _modelIdFromSelectorKey(recentModelKey);
      if (providerId == null || modelId == null) {
        continue;
      }
      final key = _selectorEntryKey(providerId, modelId);
      if (!seen.add(key)) {
        continue;
      }
      final entry = byKey[key];
      if (entry == null) {
        continue;
      }
      recent.add(entry);
      if (recent.length >= 3) {
        break;
      }
    }
    return recent;
  }

  Future<void> _openModelSelector(ChatProvider chatProvider) async {
    final entries = _buildModelSelectorEntries(chatProvider);
    final sortedProviders = _sortedProviders(chatProvider);
    var query = '';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (bottomSheetContext, setModalState) {
            final normalizedQuery = query.trim().toLowerCase();
            final matchingEntries = entries
                .where((entry) {
                  if (normalizedQuery.isEmpty) {
                    return true;
                  }
                  return entry.modelName.toLowerCase().contains(
                        normalizedQuery,
                      ) ||
                      entry.modelId.toLowerCase().contains(normalizedQuery) ||
                      entry.providerName.toLowerCase().contains(
                        normalizedQuery,
                      ) ||
                      entry.providerId.toLowerCase().contains(normalizedQuery);
                })
                .toList(growable: false);

            final recentEntries = normalizedQuery.isEmpty
                ? _buildRecentModelEntries(chatProvider, entries)
                : const <_ModelSelectorEntry>[];
            final recentKeys = recentEntries
                .map(
                  (entry) => _selectorEntryKey(entry.providerId, entry.modelId),
                )
                .toSet();
            final groupedSourceEntries =
                normalizedQuery.isEmpty && recentKeys.isNotEmpty
                ? matchingEntries
                      .where(
                        (entry) => !recentKeys.contains(
                          _selectorEntryKey(entry.providerId, entry.modelId),
                        ),
                      )
                      .toList(growable: false)
                : matchingEntries;

            final groupedEntries = <String, List<_ModelSelectorEntry>>{};
            for (final entry in groupedSourceEntries) {
              groupedEntries
                  .putIfAbsent(entry.providerId, () => <_ModelSelectorEntry>[])
                  .add(entry);
            }
            final hasVisibleEntries =
                recentEntries.isNotEmpty || groupedEntries.isNotEmpty;

            final selectedProviderId = chatProvider.selectedProviderId;
            final selectedModelId = chatProvider.selectedModelId;
            final selectedKey =
                selectedProviderId == null || selectedModelId == null
                ? null
                : '$selectedProviderId/$selectedModelId';

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(bottomSheetContext).bottom,
                ),
                child: SizedBox(
                  height: MediaQuery.sizeOf(bottomSheetContext).height * 0.72,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                        child: TextField(
                          autofocus: true,
                          onChanged: (value) {
                            setModalState(() {
                              query = value;
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Search model or provider',
                            prefixIcon: const Icon(Icons.search),
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: !hasVisibleEntries
                            ? Center(
                                child: Text(
                                  'No models found',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              )
                            : ListView(
                                children: [
                                  if (recentEntries.isNotEmpty) ...[
                                    Padding(
                                      key: const ValueKey<String>(
                                        'model_selector_recent_header',
                                      ),
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        12,
                                        16,
                                        4,
                                      ),
                                      child: Text(
                                        'Recent',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                    for (final entry in recentEntries)
                                      ListTile(
                                        key: ValueKey<String>(
                                          'model_selector_recent_${entry.providerId}_${entry.modelId}',
                                        ),
                                        leading: Icon(
                                          _modelSelectorListIcon(
                                            providerId: entry.providerId,
                                            providerName: entry.providerName,
                                            modelId: entry.modelId,
                                            modelName: entry.modelName,
                                          ),
                                          size: 18,
                                        ),
                                        title: Text(entry.modelName),
                                        subtitle: Text(entry.providerName),
                                        trailing:
                                            selectedKey ==
                                                _selectorEntryKey(
                                                  entry.providerId,
                                                  entry.modelId,
                                                )
                                            ? const Icon(Icons.check_rounded)
                                            : null,
                                        onTap: () async {
                                          await chatProvider
                                              .setSelectedModelByProvider(
                                                providerId: entry.providerId,
                                                modelId: entry.modelId,
                                              );
                                          if (!bottomSheetContext.mounted) {
                                            return;
                                          }
                                          Navigator.of(
                                            bottomSheetContext,
                                          ).pop();
                                        },
                                      ),
                                  ],
                                  for (final provider in sortedProviders)
                                    if (groupedEntries.containsKey(
                                      provider.id,
                                    )) ...[
                                      Padding(
                                        key: ValueKey<String>(
                                          'model_selector_provider_header_${provider.id}',
                                        ),
                                        padding: const EdgeInsets.fromLTRB(
                                          16,
                                          12,
                                          16,
                                          4,
                                        ),
                                        child: Text(
                                          provider.name,
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ),
                                      for (final entry
                                          in groupedEntries[provider.id]!)
                                        ListTile(
                                          key: ValueKey<String>(
                                            'model_selector_item_${entry.providerId}_${entry.modelId}',
                                          ),
                                          leading: Icon(
                                            _modelSelectorListIcon(
                                              providerId: entry.providerId,
                                              providerName: entry.providerName,
                                              modelId: entry.modelId,
                                              modelName: entry.modelName,
                                            ),
                                            size: 18,
                                          ),
                                          title: Text(entry.modelName),
                                          subtitle:
                                              entry.modelName == entry.modelId
                                              ? null
                                              : Text(entry.modelId),
                                          trailing:
                                              selectedKey ==
                                                  _selectorEntryKey(
                                                    entry.providerId,
                                                    entry.modelId,
                                                  )
                                              ? const Icon(Icons.check_rounded)
                                              : null,
                                          onTap: () async {
                                            await chatProvider
                                                .setSelectedModelByProvider(
                                                  providerId: entry.providerId,
                                                  modelId: entry.modelId,
                                                );
                                            if (!bottomSheetContext.mounted) {
                                              return;
                                            }
                                            Navigator.of(
                                              bottomSheetContext,
                                            ).pop();
                                          },
                                        ),
                                    ],
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openVariantQuickSelector(
    ChatProvider chatProvider, {
    required BuildContext anchorContext,
  }) async {
    final variants = chatProvider.availableVariants;
    if (variants.isEmpty) {
      return;
    }

    final buttonBox = anchorContext.findRenderObject() as RenderBox?;
    final overlayBox =
        Overlay.of(anchorContext).context.findRenderObject() as RenderBox?;
    if (buttonBox == null || overlayBox == null) {
      return;
    }
    final buttonTopLeft = buttonBox.localToGlobal(
      Offset.zero,
      ancestor: overlayBox,
    );
    final buttonRect = buttonTopLeft & buttonBox.size;
    const margin = 8.0;
    const menuWidth = 220.0;
    final left = (buttonRect.center.dx - (menuWidth / 2))
        .clamp(margin, overlayBox.size.width - menuWidth - margin)
        .toDouble();
    final top = (buttonRect.top - 4).clamp(margin, overlayBox.size.height - 48);

    final selected = await showMenu<String?>(
      context: context,
      constraints: const BoxConstraints(
        minWidth: menuWidth,
        maxWidth: menuWidth,
      ),
      position: RelativeRect.fromLTRB(
        left,
        top.toDouble(),
        overlayBox.size.width - left - menuWidth,
        overlayBox.size.height - top.toDouble(),
      ),
      items: [
        PopupMenuItem<String?>(
          key: const ValueKey<String>('variant_selector_option_auto'),
          value: null,
          child: Row(
            children: [
              const Expanded(child: Text('Auto')),
              if (chatProvider.selectedVariantId == null)
                const Icon(Icons.check_rounded, size: 18),
            ],
          ),
        ),
        for (final variant in variants)
          PopupMenuItem<String?>(
            key: ValueKey<String>('variant_selector_option_${variant.id}'),
            value: variant.id,
            child: Row(
              children: [
                Expanded(
                  child: Text(variant.name, overflow: TextOverflow.ellipsis),
                ),
                if (chatProvider.selectedVariantId == variant.id)
                  const Icon(Icons.check_rounded, size: 18),
              ],
            ),
          ),
      ],
    );
    if (selected == null && chatProvider.selectedVariantId == null) {
      return;
    }
    await chatProvider.setSelectedVariant(selected);
  }

  Widget _buildInteractionPrompts(ChatProvider chatProvider) {
    final permissionRequest = chatProvider.currentPermissionRequest;
    final questionRequest = chatProvider.currentQuestionRequest;
    if (permissionRequest == null && questionRequest == null) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        if (permissionRequest != null)
          PermissionRequestCard(
            request: permissionRequest,
            busy: chatProvider.isRespondingInteraction,
            onDecide: (reply) {
              unawaited(
                chatProvider.respondPermissionRequest(
                  requestId: permissionRequest.id,
                  reply: reply,
                ),
              );
            },
          ),
        if (questionRequest != null)
          QuestionRequestCard(
            request: questionRequest,
            busy: chatProvider.isRespondingInteraction,
            onSubmit: (answers) {
              unawaited(
                chatProvider.submitQuestionAnswers(
                  requestId: questionRequest.id,
                  answers: answers,
                ),
              );
            },
            onReject: () {
              unawaited(
                chatProvider.rejectQuestionRequest(
                  requestId: questionRequest.id,
                ),
              );
            },
          ),
      ],
    );
  }

  String _sessionStatusLabel(SessionStatusInfo status) {
    switch (status.type) {
      case SessionStatusType.busy:
        return 'Status: Busy';
      case SessionStatusType.retry:
        final attempt = status.attempt ?? 0;
        if (attempt > 0) {
          return 'Status: Retry #$attempt';
        }
        return 'Status: Retry';
      case SessionStatusType.idle:
        return 'Status: Idle';
    }
  }

  Widget _metaChip(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }

  String _sessionDisplayTitle(ChatSession session) {
    return SessionTitleFormatter.displayTitle(
      time: session.time,
      title: session.title,
    );
  }

  String _sessionEditingValue(ChatSession session) {
    final raw = session.title?.trim();
    if (raw != null && raw.isNotEmpty) {
      return raw;
    }
    return SessionTitleFormatter.fallbackTitle(time: session.time);
  }

  Widget _buildMessageViewport(ChatProvider chatProvider) {
    final showFab =
        _showScrollToLatestFab &&
        chatProvider.currentSession != null &&
        chatProvider.messages.isNotEmpty;
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Positioned.fill(child: _buildMessageList(chatProvider)),
        Positioned(
          right: 16,
          bottom: 16,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: showFab
                ? FloatingActionButton.small(
                    key: const ValueKey<String>('jump_to_latest_fab'),
                    heroTag: 'jump_to_latest_fab',
                    tooltip: 'Go to latest message',
                    onPressed: () => _scrollToBottom(force: true),
                    backgroundColor: _hasUnreadMessagesBelow
                        ? colorScheme.primary
                        : colorScheme.surfaceContainerHigh,
                    foregroundColor: _hasUnreadMessagesBelow
                        ? colorScheme.onPrimary
                        : colorScheme.onSurfaceVariant,
                    child: Icon(
                      _hasUnreadMessagesBelow
                          ? Icons.mark_chat_unread_outlined
                          : Icons.arrow_downward_rounded,
                    ),
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
    if (chatProvider.state == ChatState.loading &&
        chatProvider.messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (chatProvider.state == ChatState.error) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              chatProvider.errorMessage ?? 'An error occurred',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                chatProvider.clearError();
                chatProvider.refresh();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (chatProvider.currentSession == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Select or create a conversation to start chatting',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _createNewSession,
              icon: const Icon(Icons.add),
              label: const Text('New Chat'),
            ),
          ],
        ),
      );
    }

    if (chatProvider.messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.waving_hand,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Hello! I am your AI assistant',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'How can I help you?',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final progressStage = _resolveAssistantProgressStage(chatProvider);

    return ListView.builder(
      key: const ValueKey<String>('chat_message_list'),
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: chatProvider.messages.length + (progressStage == null ? 0 : 1),
      itemBuilder: (context, index) {
        if (index < chatProvider.messages.length) {
          final message = chatProvider.messages[index];
          return ChatMessageWidget(
            key: ValueKey(message.id),
            message: message,
            onBackgroundLongPress: () =>
                _handleMessageBackgroundLongPress(message),
            onBackgroundLongPressEnd: () =>
                _handleMessageBackgroundLongPressEnd(message),
          );
        }

        final indicator = switch (progressStage) {
          _AssistantProgressStage.receiving => (
            text: 'Receiving response...',
            icon: Icons.auto_awesome,
            showSpinner: false,
          ),
          _AssistantProgressStage.retrying => (
            text: 'Retrying model request...',
            icon: Icons.refresh_rounded,
            showSpinner: true,
          ),
          _AssistantProgressStage.thinking || null => (
            text: 'Thinking...',
            icon: Icons.hourglass_top_rounded,
            showSpinner: true,
          ),
        };

        return Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const SizedBox(width: 40), // Avatar placeholder
              const SizedBox(width: 12),
              if (indicator.showSpinner)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  indicator.icon,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
              const SizedBox(width: 8),
              Text(
                indicator.text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  _AssistantProgressStage? _resolveAssistantProgressStage(
    ChatProvider chatProvider,
  ) {
    final statusType = chatProvider.currentSessionStatus?.type;
    final hasInProgressAssistant = chatProvider.messages
        .whereType<AssistantMessage>()
        .any((message) => !message.isCompleted);
    final hasStreamingAssistantParts = chatProvider.messages
        .whereType<AssistantMessage>()
        .any((message) => !message.isCompleted && message.parts.isNotEmpty);
    final hasBusyOrRetryStatus =
        statusType == SessionStatusType.busy ||
        statusType == SessionStatusType.retry;

    final shouldShowIndicator =
        chatProvider.state == ChatState.sending ||
        hasBusyOrRetryStatus ||
        hasInProgressAssistant;
    if (!shouldShowIndicator) {
      return null;
    }

    if (statusType == SessionStatusType.retry) {
      return _AssistantProgressStage.retrying;
    }
    if (hasStreamingAssistantParts) {
      return _AssistantProgressStage.receiving;
    }
    return _AssistantProgressStage.thinking;
  }

  Future<void> _createNewSession() async {
    final chatProvider = context.read<ChatProvider>();

    // Technical comment translated to English.
    await chatProvider.createNewSession();
  }

  Future<List<ChatComposerMentionSuggestion>> _queryMentionSuggestions(
    String query,
  ) async {
    final normalizedQuery = query.trim().toLowerCase();
    final projectProvider = context.read<ProjectProvider>();
    final chatProvider = context.read<ChatProvider>();
    final dio = di.sl<DioClient>().dio;

    try {
      final response = await dio.get(
        '/find/file',
        queryParameters: <String, String>{
          'query': normalizedQuery,
          if ((projectProvider.currentDirectory ?? '').isNotEmpty)
            'directory': projectProvider.currentDirectory!,
          'limit': '12',
        },
      );

      final fileData = response.data as List<dynamic>? ?? const <dynamic>[];
      final suggestions = <ChatComposerMentionSuggestion>[];

      for (final raw in fileData) {
        String? path;
        if (raw is String) {
          path = raw;
        } else if (raw is Map) {
          path =
              raw['path'] as String? ??
              raw['name'] as String? ??
              raw['file'] as String?;
        }
        if (path == null || path.trim().isEmpty) {
          continue;
        }
        suggestions.add(
          ChatComposerMentionSuggestion(
            value: path.trim(),
            type: ChatComposerSuggestionType.file,
            subtitle: 'file',
          ),
        );
      }

      for (final agent in chatProvider.agents) {
        final name = agent.name.trim();
        if (name.isEmpty || agent.hidden) {
          continue;
        }
        final normalizedName = name.toLowerCase();
        if (normalizedQuery.isNotEmpty &&
            !normalizedName.contains(normalizedQuery)) {
          continue;
        }
        suggestions.add(
          ChatComposerMentionSuggestion(
            value: name,
            type: ChatComposerSuggestionType.agent,
            subtitle: agent.mode.isEmpty ? 'agent' : agent.mode,
          ),
        );
      }

      return suggestions.take(20).toList(growable: false);
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Composer mention query failed',
        error: error,
        stackTrace: stackTrace,
      );
      return const <ChatComposerMentionSuggestion>[];
    }
  }

  List<ChatComposerSlashCommandSuggestion> _builtinSlashCommands() {
    return const <ChatComposerSlashCommandSuggestion>[
      ChatComposerSlashCommandSuggestion(
        name: 'new',
        source: 'builtin',
        description: 'Create a new chat session',
        isBuiltin: true,
      ),
      ChatComposerSlashCommandSuggestion(
        name: 'model',
        source: 'builtin',
        description: 'Open model selector',
        isBuiltin: true,
      ),
      ChatComposerSlashCommandSuggestion(
        name: 'agent',
        source: 'builtin',
        description: 'Open agent selector',
        isBuiltin: true,
      ),
      ChatComposerSlashCommandSuggestion(
        name: 'open',
        source: 'builtin',
        description: 'File open quick action',
        isBuiltin: true,
      ),
      ChatComposerSlashCommandSuggestion(
        name: 'help',
        source: 'builtin',
        description: 'Show command help',
        isBuiltin: true,
      ),
    ];
  }

  Future<List<ChatComposerSlashCommandSuggestion>> _querySlashSuggestions(
    String query,
  ) async {
    final normalizedQuery = query.trim().toLowerCase();
    final commands = <ChatComposerSlashCommandSuggestion>[
      ..._builtinSlashCommands(),
    ];
    final dio = di.sl<DioClient>().dio;

    try {
      final response = await dio.get('/command');
      final remoteData = response.data as List<dynamic>? ?? const <dynamic>[];
      for (final raw in remoteData) {
        if (raw is! Map) {
          continue;
        }
        final name = raw['name'] as String?;
        if (name == null || name.trim().isEmpty) {
          continue;
        }
        commands.add(
          ChatComposerSlashCommandSuggestion(
            name: name.trim(),
            source: raw['source'] as String? ?? 'command',
            description: raw['description'] as String?,
          ),
        );
      }
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Composer slash query failed',
        error: error,
        stackTrace: stackTrace,
      );
    }

    final deduped = <String, ChatComposerSlashCommandSuggestion>{};
    for (final command in commands) {
      deduped.putIfAbsent(command.name.toLowerCase(), () => command);
    }

    final filtered =
        deduped.values
            .where((command) {
              if (normalizedQuery.isEmpty) {
                return true;
              }
              final byName = command.name.toLowerCase().contains(
                normalizedQuery,
              );
              final bySource = command.source.toLowerCase().contains(
                normalizedQuery,
              );
              final byDescription = (command.description ?? '')
                  .toLowerCase()
                  .contains(normalizedQuery);
              return byName || bySource || byDescription;
            })
            .toList(growable: false)
          ..sort((a, b) {
            if (a.isBuiltin != b.isBuiltin) {
              return a.isBuiltin ? -1 : 1;
            }
            return a.name.compareTo(b.name);
          });

    return filtered.take(24).toList(growable: false);
  }

  Future<bool> _handleBuiltinSlashCommand({
    required String commandName,
    required ChatProvider chatProvider,
  }) async {
    final command = commandName.trim().toLowerCase();
    switch (command) {
      case 'new':
        await _createNewSession();
        return true;
      case 'model':
        if (chatProvider.providers.isEmpty) {
          return true;
        }
        await _openModelSelector(chatProvider);
        return true;
      case 'agent':
        if (!mounted || chatProvider.selectableAgents.isEmpty) {
          return true;
        }
        final anchorContext = _agentSelectorChipKey.currentContext;
        if (anchorContext != null) {
          await _openAgentQuickSelector(
            chatProvider,
            anchorContext: anchorContext,
          );
        }
        return true;
      case 'open':
        if (!mounted) {
          return true;
        }
        await _openQuickFileDialogFromCurrentContext();
        return true;
      case 'help':
        if (!mounted) {
          return true;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Use @ for mentions, ! for shell, / for commands'),
          ),
        );
        return true;
      default:
        return false;
    }
  }
}

class _FileExplorerContextState {
  _FileExplorerContextState({required this.rootDirectory});

  String rootDirectory;
  DateTime? lastLoadedAt;
  final Map<String, List<FileNode>> directoryChildren =
      <String, List<FileNode>>{};
  final Set<String> expandedDirectories = <String>{};
  final Set<String> loadingDirectories = <String>{};
  final Map<String, _FileTabViewState> tabsByPath =
      <String, _FileTabViewState>{};
  FileTabSelectionState tabSelection = const FileTabSelectionState();
  bool rootLoadScheduled = false;
  String? treeError;

  void resetForRoot(String nextRootDirectory) {
    rootDirectory = nextRootDirectory;
    lastLoadedAt = null;
    directoryChildren.clear();
    expandedDirectories.clear();
    loadingDirectories.clear();
    rootLoadScheduled = false;
    treeError = null;
  }
}

enum _FileTabLoadStatus { loading, ready, binary, empty, error }

class _FileTabViewState {
  const _FileTabViewState({
    required this.status,
    required this.content,
    this.errorMessage,
    this.mimeType,
  });

  final _FileTabLoadStatus status;
  final String content;
  final String? errorMessage;
  final String? mimeType;
}

enum _AssistantProgressStage { thinking, receiving, retrying }

class _DirectoryPickerSheet extends StatefulWidget {
  const _DirectoryPickerSheet({required this.initialDirectory});

  final String initialDirectory;

  @override
  State<_DirectoryPickerSheet> createState() => _DirectoryPickerSheetState();
}

class _DirectoryPickerSheetState extends State<_DirectoryPickerSheet> {
  late String _currentDirectory;
  final TextEditingController _filterController = TextEditingController();
  List<String> _directories = const <String>[];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _currentDirectory = _normalizeDirectory(widget.initialDirectory);
    _loadDirectory(_currentDirectory);
    _filterController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  Future<void> _loadDirectory(String directory) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final provider = context.read<ProjectProvider>();
    final listed = await provider.listDirectories(directory);

    if (!mounted) {
      return;
    }

    if (listed == null) {
      setState(() {
        _loading = false;
        _error = provider.error ?? 'Failed to load directories';
      });
      return;
    }

    setState(() {
      _currentDirectory = _normalizeDirectory(directory);
      _directories = listed;
      _loading = false;
      _error = null;
    });
  }

  String _normalizeDirectory(String input) {
    var value = input.trim();
    if (value.isEmpty) {
      return '/';
    }
    if (value.length > 1 && value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  String _basename(String path) {
    final normalized = _normalizeDirectory(path).replaceAll('\\', '/');
    if (normalized == '/') {
      return '/';
    }
    final parts = normalized
        .split('/')
        .where((item) => item.trim().isNotEmpty)
        .toList(growable: false);
    return parts.isEmpty ? normalized : parts.last;
  }

  String? _parentDirectory(String path) {
    final normalized = _normalizeDirectory(path).replaceAll('\\', '/');
    if (normalized == '/') {
      return null;
    }
    final index = normalized.lastIndexOf('/');
    if (index <= 0) {
      return '/';
    }
    return normalized.substring(0, index);
  }

  @override
  Widget build(BuildContext context) {
    final query = _filterController.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? _directories
        : _directories
              .where((item) {
                final base = _basename(item).toLowerCase();
                return base.contains(query) ||
                    item.toLowerCase().contains(query);
              })
              .toList(growable: false);
    final parent = _parentDirectory(_currentDirectory);

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.82,
      child: Column(
        key: const ValueKey<String>('directory_picker_sheet'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Select directory',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  key: const ValueKey<String>('directory_picker_use_current'),
                  onPressed: _loading
                      ? null
                      : () => Navigator.of(context).pop(_currentDirectory),
                  child: const Text('Use current'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _currentDirectory,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Workspace creation requires a Git repository directory.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              key: const ValueKey<String>('directory_picker_filter'),
              controller: _filterController,
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search),
                hintText: 'Filter directories',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 8),
                          FilledButton.tonal(
                            onPressed: () => _loadDirectory(_currentDirectory),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView(
                    children: [
                      if (parent != null)
                        ListTile(
                          key: const ValueKey<String>(
                            'directory_picker_parent',
                          ),
                          leading: const Icon(Icons.arrow_upward_rounded),
                          title: const Text('..'),
                          subtitle: Text(parent),
                          onTap: () => _loadDirectory(parent),
                        ),
                      for (final directory in filtered)
                        ListTile(
                          key: ValueKey<String>(
                            'directory_picker_item_$directory',
                          ),
                          leading: const Icon(Icons.folder_outlined),
                          title: Text(_basename(directory)),
                          subtitle: Text(
                            directory,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _loadDirectory(directory),
                          onLongPress: () => Navigator.of(
                            context,
                          ).pop(_normalizeDirectory(directory)),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
