import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/logging/app_logger.dart';
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

/// Chat page
class ChatPage extends StatefulWidget {
  final String? projectId;

  const ChatPage({super.key, this.projectId});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
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
  String? _trackedSessionId;
  String? _pendingInitialScrollSessionId;
  bool _showScrollToLatestFab = false;
  bool _hasUnreadMessagesBelow = false;

  @override
  void initState() {
    super.initState();
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
      _appProvider?.addListener(_handleAppProviderChange);
    }
  }

  @override
  void dispose() {
    // Clean up scroll callback using saved reference
    _chatProvider?.setScrollToBottomCallback(null);
    _appProvider?.removeListener(_handleAppProviderChange);
    _scrollController.removeListener(_handleScrollChanged);

    _scrollController.dispose();
    _inputFocusNode.dispose();
    _sessionSearchController.dispose();
    super.dispose();
  }

  void _loadInitialData() {
    final chatProvider = context.read<ChatProvider>();

    // Set scroll to bottom callback
    chatProvider.setScrollToBottomCallback(_scrollToBottom);

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
    final currentServerId = _appProvider?.activeServerId;
    if (currentServerId == null || currentServerId == _lastServerId) {
      return;
    }
    _lastServerId = currentServerId;
    unawaited(_handleServerScopeChange());
  }

  Future<void> _handleServerScopeChange() async {
    if (!mounted) {
      return;
    }
    final projectProvider = context.read<ProjectProvider>();
    await projectProvider.onServerScopeChanged();
    await _chatProvider?.onServerScopeChanged();
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
    final controller = TextEditingController();
    final createdName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Create Workspace'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Workspace name',
              hintText: 'ex: feature-branch',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(controller.text.trim());
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    if (!mounted || createdName == null || createdName.trim().isEmpty) {
      return;
    }

    final created = await projectProvider.createWorktree(
      createdName,
      switchToCreated: true,
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
    await chatProvider.onProjectScopeChanged();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Workspace created: ${created.name}')),
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

        return Shortcuts(
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.keyN, control: true):
                _NewSessionIntent(),
            SingleActivator(LogicalKeyboardKey.keyN, meta: true):
                _NewSessionIntent(),
            SingleActivator(LogicalKeyboardKey.keyR, control: true):
                _RefreshIntent(),
            SingleActivator(LogicalKeyboardKey.keyR, meta: true):
                _RefreshIntent(),
            SingleActivator(LogicalKeyboardKey.keyL, control: true):
                _FocusInputIntent(),
            SingleActivator(LogicalKeyboardKey.keyL, meta: true):
                _FocusInputIntent(),
            SingleActivator(LogicalKeyboardKey.escape): _EscapeIntent(),
          },
          child: Actions(
            actions: <Type, Action<Intent>>{
              _NewSessionIntent: CallbackAction<_NewSessionIntent>(
                onInvoke: (_) {
                  _createNewSession();
                  return null;
                },
              ),
              _RefreshIntent: CallbackAction<_RefreshIntent>(
                onInvoke: (_) {
                  _refreshData();
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
            },
            child: Focus(
              autofocus: true,
              child: Scaffold(
                backgroundColor: Theme.of(context).colorScheme.background,
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
    return AppBar(
      titleSpacing: 0,
      actions: [
        Consumer<ProjectProvider>(
          builder: (context, projectProvider, child) {
            final currentProject = projectProvider.currentProject;
            final currentDirectoryFull = _directoryLabel(
              projectProvider.currentDirectory,
            );
            final currentDirectoryChip = isMobile
                ? _directoryBasename(currentDirectoryFull)
                : currentDirectoryFull;

            return PopupMenuButton<String>(
              tooltip: 'Choose Directory',
              onSelected: (value) async {
                if (value == '__refresh_projects__') {
                  await projectProvider.loadProjects();
                  return;
                }
                if (value == '__refresh_workspaces__') {
                  await projectProvider.loadWorktrees();
                  return;
                }
                if (value == '__create_workspace__') {
                  await _createWorkspace();
                  return;
                }
                if (value.startsWith('switch:')) {
                  await _switchProjectContext(
                    value.substring('switch:'.length),
                  );
                  return;
                }
                if (value.startsWith('close:')) {
                  await _closeProjectContext(value.substring('close:'.length));
                  return;
                }
                if (value.startsWith('reopen:')) {
                  await _reopenProjectContext(
                    value.substring('reopen:'.length),
                  );
                  return;
                }
                if (value.startsWith('switch-workspace:')) {
                  final directory = value.substring('switch-workspace:'.length);
                  final project = projectProvider.projects
                      .where((item) => item.path == directory)
                      .firstOrNull;
                  if (project != null) {
                    await _switchProjectContext(project.id);
                  }
                  return;
                }
                if (value.startsWith('reset-workspace:')) {
                  await _resetWorkspace(
                    value.substring('reset-workspace:'.length),
                  );
                  return;
                }
                if (value.startsWith('delete-workspace:')) {
                  await _deleteWorkspace(
                    value.substring('delete-workspace:'.length),
                  );
                }
              },
              itemBuilder: (context) {
                final items = <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    enabled: false,
                    child: Text(
                      currentProject == null
                          ? 'No active context'
                          : 'Current directory: $currentDirectoryFull',
                    ),
                  ),
                  const PopupMenuItem<String>(
                    enabled: false,
                    child: Text('Select a directory/workspace below'),
                  ),
                  const PopupMenuItem<String>(
                    value: '__refresh_projects__',
                    child: Text('Refresh projects'),
                  ),
                  const PopupMenuDivider(),
                ];

                for (final project in projectProvider.openProjects) {
                  items.add(
                    PopupMenuItem<String>(
                      value: 'switch:${project.id}',
                      child: _projectMenuLabel(
                        project,
                        selected: project.id == currentProject?.id,
                      ),
                    ),
                  );
                  if (project.id != currentProject?.id) {
                    items.add(
                      PopupMenuItem<String>(
                        value: 'close:${project.id}',
                        child: Text('Close ${_projectDisplayLabel(project)}'),
                      ),
                    );
                  }
                }

                if (projectProvider.closedProjects.isNotEmpty) {
                  items.add(const PopupMenuDivider());
                  for (final project in projectProvider.closedProjects) {
                    items.add(
                      PopupMenuItem<String>(
                        value: 'reopen:${project.id}',
                        child: Text('Reopen ${_projectDisplayLabel(project)}'),
                      ),
                    );
                  }
                }

                if (projectProvider.worktreeSupported ||
                    projectProvider.worktrees.isNotEmpty) {
                  items.add(const PopupMenuDivider());
                  items.add(
                    const PopupMenuItem<String>(
                      value: '__create_workspace__',
                      child: Text('Create workspace'),
                    ),
                  );
                  items.add(
                    const PopupMenuItem<String>(
                      value: '__refresh_workspaces__',
                      child: Text('Refresh workspaces'),
                    ),
                  );
                  for (final worktree in projectProvider.worktrees) {
                    items.add(
                      PopupMenuItem<String>(
                        value: 'switch-workspace:${worktree.directory}',
                        child: Text('Open ${worktree.name}'),
                      ),
                    );
                    items.add(
                      PopupMenuItem<String>(
                        value: 'reset-workspace:${worktree.id}',
                        child: Text('Reset ${worktree.name}'),
                      ),
                    );
                    items.add(
                      PopupMenuItem<String>(
                        value: 'delete-workspace:${worktree.id}',
                        child: Text('Delete ${worktree.name}'),
                      ),
                    );
                  }
                }

                return items;
              },
              child: Container(
                margin: const EdgeInsets.only(right: 4),
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 6 : 8,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: colorScheme.outline.withOpacity(0.4),
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.folder_open_outlined, size: 16),
                    SizedBox(width: isMobile ? 4 : 6),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isMobile ? 92 : 180,
                      ),
                      child: Text(
                        currentDirectoryChip,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.arrow_drop_down, size: 18),
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

  Widget _projectMenuLabel(Project project, {required bool selected}) {
    final path = _directoryLabel(project.path);
    final displayName = _projectDisplayLabel(project);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(displayName, overflow: TextOverflow.ellipsis),
              if (path != displayName)
                Text(
                  path,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        if (selected) const Icon(Icons.check, size: 16),
      ],
    );
  }

  Widget _buildSessionDrawer() {
    return Drawer(
      child: SafeArea(child: _buildSessionPanel(closeOnSelect: true)),
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
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _refreshData,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
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
                                  style: Theme.of(context).textTheme.titleSmall
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
              ChatInputWidget(
                onSendMessage: (text) async {
                  await chatProvider.sendMessage(text);
                  // Technical comment translated to English.
                  _scrollToBottom(force: true);
                },
                enabled:
                    chatProvider.currentSession != null &&
                    chatProvider.state != ChatState.sending,
                focusNode: _inputFocusNode,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModelControls(ChatProvider chatProvider) {
    final selectedProvider = chatProvider.selectedProvider;
    final selectedModel = chatProvider.selectedModel;
    final variants = chatProvider.availableVariants;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border.all(color: colorScheme.outline.withOpacity(0.14)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          PopupMenuButton<String>(
            tooltip: 'Choose provider',
            onSelected: (providerId) {
              unawaited(chatProvider.setSelectedProvider(providerId));
            },
            itemBuilder: (context) => chatProvider.providers
                .map(
                  (provider) => PopupMenuItem<String>(
                    value: provider.id,
                    child: Text(provider.name),
                  ),
                )
                .toList(),
            child: _buildModelControlChip(
              icon: Icons.hub_outlined,
              label: 'Provider: ${selectedProvider?.name ?? 'Select'}',
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Choose model',
            enabled: selectedProvider != null,
            onSelected: (modelId) {
              unawaited(chatProvider.setSelectedModel(modelId));
            },
            itemBuilder: (context) {
              final providerModels =
                  selectedProvider?.models.values.toList(growable: false) ??
                  const <Model>[];
              return providerModels
                  .map(
                    (model) => PopupMenuItem<String>(
                      value: model.id,
                      child: Text(model.name),
                    ),
                  )
                  .toList();
            },
            child: _buildModelControlChip(
              icon: Icons.smart_toy_outlined,
              label: 'Model: ${selectedModel?.name ?? 'Select'}',
            ),
          ),
          if (variants.isNotEmpty)
            ActionChip(
              avatar: const Icon(Icons.psychology_alt_outlined, size: 18),
              label: Text('Reasoning: ${chatProvider.selectedVariantLabel}'),
              onPressed: () {
                unawaited(chatProvider.cycleVariant());
              },
            ),
        ],
      ),
    );
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

  Widget _buildModelControlChip({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_drop_down, size: 18),
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

    return ListView.builder(
      key: const ValueKey<String>('chat_message_list'),
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount:
          chatProvider.messages.length +
          (chatProvider.state == ChatState.sending ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < chatProvider.messages.length) {
          final message = chatProvider.messages[index];
          return ChatMessageWidget(key: ValueKey(message.id), message: message);
        }

        // Show loading indicator
        return Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const SizedBox(width: 40), // Avatar placeholder
              const SizedBox(width: 12),
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
              Text(
                'Thinking...',
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

  Future<void> _createNewSession() async {
    final chatProvider = context.read<ChatProvider>();

    // Technical comment translated to English.
    await chatProvider.createNewSession();
  }
}
