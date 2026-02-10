import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart' hide Provider;
import '../../core/config/feature_flags.dart';
import '../../core/logging/app_logger.dart';
import '../../core/network/dio_client.dart';
import '../../core/di/injection_container.dart' as di;
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_realtime.dart';
import '../../domain/entities/project.dart';
import '../../domain/entities/provider.dart';
import '../providers/app_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/project_provider.dart';

import '../widgets/chat_message_widget.dart';
import '../widgets/chat_input_widget.dart';
import '../widgets/chat_session_list.dart';
import '../widgets/permission_request_card.dart';
import '../widgets/question_request_card.dart';
import 'logs_page.dart';
import 'server_settings_page.dart';

class _NewSessionIntent extends Intent {
  const _NewSessionIntent();
}

class _RefreshIntent extends Intent {
  const _RefreshIntent();
}

class _FocusInputIntent extends Intent {
  const _FocusInputIntent();
}

class _EscapeIntent extends Intent {
  const _EscapeIntent();
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
  static const double _desktopSessionPaneWidth = 300;
  static const double _largeDesktopSessionPaneWidth = 320;
  static const double _largeDesktopUtilityPaneWidth = 280;
  static const double _nearBottomThreshold = 200;

  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode(debugLabel: 'chat_input');
  final TextEditingController _sessionSearchController =
      TextEditingController();
  ChatProvider? _chatProvider;
  AppProvider? _appProvider;
  String? _lastServerId;
  bool? _lastServerConnectionState;
  String? _trackedSessionId;
  String? _pendingInitialScrollSessionId;
  bool _showScrollToLatestFab = false;
  bool _hasUnreadMessagesBelow = false;
  bool _isAppInForeground = true;

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
  }

  @override
  void dispose() {
    // Clean up scroll callback using saved reference
    _chatProvider?.setScrollToBottomCallback(null);
    unawaited(_chatProvider?.setForegroundActive(false));
    _appProvider?.removeListener(_handleAppProviderChange);
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
    try {
      await context.read<AppProvider>().initialize();
      final projectProvider = context.read<ProjectProvider>();
      await projectProvider.initializeProject();
      await context.read<AppProvider>().checkConnection(
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
        final sessionPaneWidth = isLargeDesktop
            ? _largeDesktopSessionPaneWidth
            : _desktopSessionPaneWidth;
        final mainContentWidth = isLargeDesktop ? 960.0 : double.infinity;
        final refreshlessEnabled = FeatureFlags.refreshlessRealtime;
        final shortcutMap = <ShortcutActivator, Intent>{
          const SingleActivator(LogicalKeyboardKey.keyN, control: true):
              const _NewSessionIntent(),
          const SingleActivator(LogicalKeyboardKey.keyN, meta: true):
              const _NewSessionIntent(),
          const SingleActivator(LogicalKeyboardKey.keyL, control: true):
              const _FocusInputIntent(),
          const SingleActivator(LogicalKeyboardKey.keyL, meta: true):
              const _FocusInputIntent(),
          const SingleActivator(LogicalKeyboardKey.escape):
              const _EscapeIntent(),
        };
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
          _EscapeIntent: CallbackAction<_EscapeIntent>(
            onInvoke: (_) {
              _handleEscape();
              return null;
            },
          ),
        };
        if (!refreshlessEnabled) {
          shortcutMap[const SingleActivator(
                LogicalKeyboardKey.keyR,
                control: true,
              )] =
              const _RefreshIntent();
          shortcutMap[const SingleActivator(
                LogicalKeyboardKey.keyR,
                meta: true,
              )] =
              const _RefreshIntent();
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
                backgroundColor: Theme.of(context).colorScheme.background,
                resizeToAvoidBottomInset: false,
                appBar: _buildAppBar(),
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

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: sessionPaneWidth,
                          child: _buildSessionPanel(closeOnSelect: false),
                        ),
                        VerticalDivider(
                          width: 1,
                          thickness: 1,
                          color: Theme.of(
                            context,
                          ).colorScheme.outline.withOpacity(0.12),
                        ),
                        Expanded(
                          child: _buildChatContent(
                            chatProvider: chatProvider,
                            maxContentWidth: mainContentWidth,
                            horizontalPadding: 12,
                            verticalPadding: 8,
                          ),
                        ),
                        if (isLargeDesktop) ...[
                          VerticalDivider(
                            width: 1,
                            thickness: 1,
                            color: Theme.of(
                              context,
                            ).colorScheme.outline.withOpacity(0.12),
                          ),
                          SizedBox(
                            width: _largeDesktopUtilityPaneWidth,
                            child: _buildDesktopUtilityPane(chatProvider),
                          ),
                        ],
                      ],
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

  AppBar _buildAppBar() {
    final colorScheme = Theme.of(context).colorScheme;
    final isMobile = MediaQuery.sizeOf(context).width < _mobileBreakpoint;
    final refreshlessEnabled = FeatureFlags.refreshlessRealtime;
    return AppBar(
      titleSpacing: isMobile ? 0 : 8,
      title: _buildProjectSelectorTitle(isMobile: isMobile),
      actions: [
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
                    color: color.withOpacity(0.14),
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
                if (value == '__manage__') {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ServerSettingsPage(),
                    ),
                  );
                  return;
                }

                final ok = await appProvider.setActiveServer(value);
                if (!ok && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
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
                    color: colorScheme.outline.withOpacity(0.4),
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
        if (!isMobile)
          IconButton(
            icon: const Icon(Icons.edit_note),
            tooltip: 'Focus Input',
            onPressed: _focusInput,
          ),
        const SizedBox(width: 4),
      ],
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
                    ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      leading: const Icon(Icons.folder_off_outlined, size: 20),
                      title: Text(
                        _projectDisplayLabel(project),
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        _directoryLabel(project.path),
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.undo_rounded),
                        tooltip: 'Reopen ${_projectDisplayLabel(project)}',
                        onPressed: () =>
                            unawaited(_reopenProjectContext(project.id)),
                      ),
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
    ).push(MaterialPageRoute(builder: (_) => const ServerSettingsPage()));
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

  Widget _buildSessionPanel({required bool closeOnSelect}) {
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

  Widget _buildDesktopUtilityPane(ChatProvider chatProvider) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
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
                          child: Text(
                            chatProvider.currentSession!.title ?? 'New Chat',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
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

  Widget _buildShortcutHint(String shortcut, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
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
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: Padding(
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
                  Container(
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
                                  child: Text(
                                    chatProvider.currentSession!.title ??
                                        'New Chat',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSecondaryContainer,
                                          fontWeight: FontWeight.w700,
                                        ),
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
                                      borderRadius: BorderRadius.circular(999),
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
                      onMentionQuery: _queryMentionSuggestions,
                      onSlashQuery: _querySlashSuggestions,
                      onBuiltinSlashCommand: (commandName) =>
                          _handleBuiltinSlashCommand(
                            commandName: commandName,
                            chatProvider: chatProvider,
                          ),
                      enabled:
                          chatProvider.currentSession != null &&
                          chatProvider.state != ChatState.sending,
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
      ),
    );
  }

  Widget _buildModelControls(ChatProvider chatProvider) {
    final selectedModel = chatProvider.selectedModel;
    final variants = chatProvider.availableVariants;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Tooltip(
            message: 'Choose model',
            child: ActionChip(
              key: const ValueKey<String>('model_selector_button'),
              avatar: const Icon(Icons.smart_toy_outlined, size: 18),
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
                                          if (!mounted) {
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
                                            if (!mounted) {
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
          return ChatMessageWidget(key: ValueKey(message.id), message: message);
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
    final dio = di.sl<DioClient>().dio;

    try {
      final responses = await Future.wait([
        dio.get(
          '/find/file',
          queryParameters: <String, String>{
            'query': normalizedQuery,
            if ((projectProvider.currentDirectory ?? '').isNotEmpty)
              'directory': projectProvider.currentDirectory!,
            'limit': '12',
          },
        ),
        dio.get('/agent'),
      ]);

      final fileData = responses[0].data as List<dynamic>? ?? const <dynamic>[];
      final agentData =
          responses[1].data as List<dynamic>? ?? const <dynamic>[];
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

      for (final raw in agentData) {
        if (raw is! Map) {
          continue;
        }
        final name = raw['name'] as String?;
        final hidden = raw['hidden'] == true;
        if (name == null || name.trim().isEmpty || hidden) {
          continue;
        }
        final normalizedName = name.trim().toLowerCase();
        if (normalizedQuery.isNotEmpty &&
            !normalizedName.contains(normalizedQuery)) {
          continue;
        }
        suggestions.add(
          ChatComposerMentionSuggestion(
            value: name.trim(),
            type: ChatComposerSuggestionType.agent,
            subtitle: raw['mode'] as String? ?? 'agent',
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
        description: 'Agent quick action',
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
        if (!mounted) {
          return true;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Agent picker will be expanded in Feature 020'),
          ),
        );
        return true;
      case 'open':
        if (!mounted) {
          return true;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File-open dialog is planned in Feature 019'),
          ),
        );
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
                ).colorScheme.surfaceContainerHighest.withOpacity(0.45),
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
