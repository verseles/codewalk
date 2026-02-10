import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/entities/chat_session.dart';

/// Chat session list widget
class ChatSessionList extends StatelessWidget {
  const ChatSessionList({
    super.key,
    required this.sessions,
    this.currentSession,
    this.onSessionSelected,
    this.onSessionDeleted,
    this.onSessionRenamed,
    this.onSessionShareToggled,
    this.onSessionArchiveToggled,
    this.onSessionForked,
  });

  final List<ChatSession> sessions;
  final ChatSession? currentSession;
  final Future<void> Function(ChatSession session)? onSessionSelected;
  final Future<void> Function(ChatSession session)? onSessionDeleted;
  final Future<bool> Function(ChatSession session, String title)? onSessionRenamed;
  final Future<bool> Function(ChatSession session)? onSessionShareToggled;
  final Future<bool> Function(ChatSession session, bool archived)?
  onSessionArchiveToggled;
  final Future<void> Function(ChatSession session)? onSessionForked;

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
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
              'No conversations',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a new conversation to start chatting',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final session = sessions[index];
        final isSelected = currentSession?.id == session.id;
        final colorScheme = Theme.of(context).colorScheme;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Material(
            color: isSelected
                ? colorScheme.secondaryContainer
                : colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(18),
            child: ListTile(
              mouseCursor: SystemMouseCursors.click,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              leading: CircleAvatar(
                backgroundColor: isSelected
                    ? colorScheme.primary
                    : colorScheme.surfaceContainerHighest,
                child: Icon(
                  session.archived ? Icons.archive_outlined : Icons.chat,
                  color: isSelected
                      ? colorScheme.onPrimary
                      : colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ),
              title: Text(
                session.title ?? _generateFallbackTitle(session.time),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? colorScheme.onSecondaryContainer : null,
                  decoration: session.archived
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (session.summary != null && session.summary!.isNotEmpty)
                    Text(
                      session.summary!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isSelected
                            ? colorScheme.onSecondaryContainer.withOpacity(0.8)
                            : colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        _formatTime(session.time),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isSelected
                              ? colorScheme.onSecondaryContainer.withOpacity(
                                  0.7,
                                )
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (session.shared)
                        Icon(
                          Icons.share,
                          size: 12,
                          color: isSelected
                              ? colorScheme.onSecondaryContainer.withOpacity(
                                  0.7,
                                )
                              : colorScheme.onSurfaceVariant,
                        ),
                      if (session.archived)
                        Icon(
                          Icons.archive,
                          size: 12,
                          color: isSelected
                              ? colorScheme.onSecondaryContainer.withOpacity(
                                  0.7,
                                )
                              : colorScheme.onSurfaceVariant,
                        ),
                    ],
                  ),
                ],
              ),
              trailing: PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  color: isSelected
                      ? colorScheme.onSecondaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
                onSelected: (value) {
                  switch (value) {
                    case 'rename':
                      _showRenameDialog(context, session);
                      break;
                    case 'share':
                      _toggleShare(context, session);
                      break;
                    case 'copy-link':
                      _copyShareLink(context, session);
                      break;
                    case 'archive':
                      _toggleArchive(context, session);
                      break;
                    case 'fork':
                      _forkSession(context, session);
                      break;
                    case 'delete':
                      _showDeleteDialog(context, session);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'rename',
                    child: Row(
                      children: [
                        Icon(Icons.edit),
                        SizedBox(width: 8),
                        Text('Rename'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'share',
                    child: Row(
                      children: [
                        Icon(session.shared ? Icons.link_off : Icons.link),
                        const SizedBox(width: 8),
                        Text(session.shared ? 'Unshare' : 'Share'),
                      ],
                    ),
                  ),
                  if (session.shareUrl != null && session.shareUrl!.isNotEmpty)
                    const PopupMenuItem(
                      value: 'copy-link',
                      child: Row(
                        children: [
                          Icon(Icons.copy),
                          SizedBox(width: 8),
                          Text('Copy Link'),
                        ],
                      ),
                    ),
                  PopupMenuItem(
                    value: 'archive',
                    child: Row(
                      children: [
                        Icon(
                          session.archived ? Icons.unarchive_outlined : Icons.archive_outlined,
                        ),
                        const SizedBox(width: 8),
                        Text(session.archived ? 'Unarchive' : 'Archive'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'fork',
                    child: Row(
                      children: [
                        Icon(Icons.call_split),
                        SizedBox(width: 8),
                        Text('Fork'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
              onTap: () {
                final callback = onSessionSelected;
                if (callback != null) {
                  callback(session);
                }
              },
            ),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}w ago';
    } else {
      return '${time.month}/${time.day}';
    }
  }

  /// Generate fallback session title
  String _generateFallbackTitle(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sessionDate = DateTime(time.year, time.month, time.day);

    if (sessionDate == today) {
      return 'Today ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else {
      final difference = today.difference(sessionDate).inDays;
      if (difference == 1) {
        return 'Yesterday ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      } else if (difference < 7) {
        final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final weekday = weekdays[time.weekday - 1];
        return '$weekday ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      } else {
        return '${time.month}/${time.day} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      }
    }
  }

  void _showRenameDialog(BuildContext context, ChatSession session) {
    final callback = onSessionRenamed;
    if (callback == null) {
      return;
    }

    final controller = TextEditingController(text: session.title);

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Conversation'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter new conversation name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final newTitle = controller.text.trim();
              if (newTitle.isEmpty) {
                return;
              }
              Navigator.of(context).pop();
              final ok = await callback(session, newTitle);
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to rename conversation')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleShare(BuildContext context, ChatSession session) async {
    final callback = onSessionShareToggled;
    if (callback == null) {
      return;
    }

    final ok = await callback(session);
    if (!context.mounted) {
      return;
    }
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update sharing state')),
      );
      return;
    }

    final nextAction = session.shared ? 'unshared' : 'shared';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Conversation $nextAction')),
    );
  }

  Future<void> _copyShareLink(BuildContext context, ChatSession session) async {
    final link = session.shareUrl;
    if (link == null || link.isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: link));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share link copied')),
    );
  }

  Future<void> _toggleArchive(BuildContext context, ChatSession session) async {
    final callback = onSessionArchiveToggled;
    if (callback == null) {
      return;
    }

    final archive = !session.archived;
    final ok = await callback(session, archive);
    if (!context.mounted) {
      return;
    }
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update archive state')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          archive ? 'Conversation archived' : 'Conversation unarchived',
        ),
      ),
    );
  }

  Future<void> _forkSession(BuildContext context, ChatSession session) async {
    final callback = onSessionForked;
    if (callback == null) {
      return;
    }
    await callback(session);
  }

  void _showDeleteDialog(BuildContext context, ChatSession session) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Conversation'),
        content: Text(
          'Are you sure you want to delete the conversation "${session.title ?? _generateFallbackTitle(session.time)}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              final callback = onSessionDeleted;
              if (callback != null) {
                callback(session);
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
