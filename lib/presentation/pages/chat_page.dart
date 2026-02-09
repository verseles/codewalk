import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/logging/app_logger.dart';
import '../providers/app_provider.dart';
import '../providers/chat_provider.dart';

import '../widgets/chat_message_widget.dart';
import '../widgets/chat_input_widget.dart';
import '../widgets/chat_session_list.dart';
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

  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode(debugLabel: 'chat_input');
  ChatProvider? _chatProvider;
  AppProvider? _appProvider;
  String? _lastServerId;

  @override
  void initState() {
    super.initState();
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

    _scrollController.dispose();
    _inputFocusNode.dispose();
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
    unawaited(_chatProvider?.onServerScopeChanged());
  }

  void _scrollToBottom({bool force = false}) {
    if (!_scrollController.hasClients) return;

    // Technical comment translated to English.
    if (force) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
      return;
    }

    // Smart scroll: only auto-scroll when user is near bottom
    final position = _scrollController.position;
    final threshold =
        200.0; // Consider within 200 pixels from bottom as near bottom

    if (position.maxScrollExtent - position.pixels <= threshold) {
      // Delay one frame to ensure message is rendered
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _refreshData() async {
    final chatProvider = context.read<ChatProvider>();
    await chatProvider.loadSessions();
    await chatProvider.refresh();
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
    return AppBar(
      titleSpacing: 12,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CodeWalk',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            'Conversational workspace',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [
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
        IconButton(
          icon: const Icon(Icons.edit_note),
          tooltip: 'Focus Input',
          onPressed: _focusInput,
        ),
        const SizedBox(width: 4),
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                  child: Row(
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
                ),
              ),
            ),
            Expanded(
              child: ChatSessionList(
                sessions: chatProvider.sessions,
                currentSession: chatProvider.currentSession,
                onSessionSelected: (session) {
                  chatProvider.selectSession(session);
                  if (closeOnSelect) {
                    Navigator.of(context).pop();
                  }
                },
                onSessionDeleted: (session) {
                  chatProvider.deleteSession(session.id);
                },
              ),
            ),
          ],
        );
      },
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
                child: Text(
                  'Current session:\n${chatProvider.currentSession!.title ?? 'New Chat'}',
                  style: Theme.of(context).textTheme.bodySmall,
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
                      child: Row(
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
                              chatProvider.currentSession!.title ?? 'New Chat',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSecondaryContainer,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Message list
              Expanded(child: _buildMessageList(chatProvider)),

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
