import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../../domain/entities/chat_message.dart';

/// Chat message widget
class ChatMessageWidget extends StatelessWidget {
  static const int _collapsedToolDetailMaxLines = 2;

  const ChatMessageWidget({
    super.key,
    required this.message,
    this.onBackgroundLongPress,
    this.onBackgroundLongPressEnd,
  });

  final ChatMessage message;
  final VoidCallback? onBackgroundLongPress;
  final VoidCallback? onBackgroundLongPressEnd;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;
    final colorScheme = Theme.of(context).colorScheme;
    final bubbleBorderRadius = BorderRadius.circular(18).copyWith(
      bottomRight: isUser ? const Radius.circular(6) : null,
      bottomLeft: !isUser ? const Radius.circular(6) : null,
    );

    // Check if message has valid content
    final hasValidContent = message.parts.any((part) {
      if (part is TextPart) {
        return part.text.trim().isNotEmpty;
      }
      return true; // Non-text parts are considered valid by default
    });

    // Don't display message if no valid content
    if (!hasValidContent) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: _BubbleTouchHoldLayer(
            borderRadius: bubbleBorderRadius,
            flashColor: colorScheme.primary.withValues(alpha: 0.16),
            onLongPress: onBackgroundLongPress,
            onLongPressRelease: onBackgroundLongPressEnd,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              decoration: BoxDecoration(
                color: isUser
                    ? colorScheme.primaryContainer.withValues(alpha: 0.45)
                    : colorScheme.surfaceContainerHigh,
                borderRadius: bubbleBorderRadius,
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.45),
                ),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onDoubleTap: () {
                        final copyText = _composeMessageCopyText(message);
                        if (copyText.isNotEmpty) {
                          _copyTextToClipboard(context, copyText);
                        }
                      },
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            isUser ? 'You' : 'Assistant',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: isUser
                                      ? colorScheme.primary
                                      : colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatTime(message.time),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                          ),
                          const Spacer(),
                          if (!isUser && message is AssistantMessage)
                            _buildAssistantInfo(
                              context,
                              message as AssistantMessage,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (isUser)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ...message.parts.map(
                              (part) => _buildMessagePart(context, part),
                            ),
                          ],
                        )
                      else
                        SelectionArea(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ...message.parts.map(
                                (part) => _buildMessagePart(context, part),
                              ),
                            ],
                          ),
                        ),
                      if (message is AssistantMessage &&
                          (message as AssistantMessage).error != null)
                        _buildErrorInfo(
                          context,
                          (message as AssistantMessage).error!,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAssistantInfo(BuildContext context, AssistantMessage message) {
    final stepStarts = message.parts.whereType<StepStartPart>().toList();
    final stepFinishes = message.parts.whereType<StepFinishPart>().toList();

    return PopupMenuButton<String>(
      icon: Icon(
        Icons.info_outline,
        size: 16,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      tooltip: 'Message Info',
      itemBuilder: (context) {
        final items = <PopupMenuEntry<String>>[
          if (message.modelId != null)
            PopupMenuItem(
              enabled: false,
              child: Text('Model: ${message.modelId}'),
            ),
          if (message.providerId != null)
            PopupMenuItem(
              enabled: false,
              child: Text('Provider: ${message.providerId}'),
            ),
          if (message.tokens != null)
            PopupMenuItem(
              enabled: false,
              child: Text('Tokens: ${message.tokens!.total}'),
            ),
          if (message.cost != null)
            PopupMenuItem(
              enabled: false,
              child: Text('Cost: \$${message.cost!.toStringAsFixed(6)}'),
            ),
        ];

        final hasStepMetadata =
            stepStarts.isNotEmpty || stepFinishes.isNotEmpty;
        if (items.isNotEmpty && hasStepMetadata) {
          items.add(const PopupMenuDivider());
        }

        for (var index = 0; index < stepStarts.length; index += 1) {
          final stepStart = stepStarts[index];
          final snapshot = stepStart.snapshot?.trim();
          final details = snapshot == null || snapshot.isEmpty
              ? 'Step started #${index + 1}'
              : 'Step started #${index + 1}: $snapshot';
          items.add(PopupMenuItem(enabled: false, child: Text(details)));
        }

        for (var index = 0; index < stepFinishes.length; index += 1) {
          final stepFinish = stepFinishes[index];
          final details =
              'Step finished #${index + 1}: ${stepFinish.reason} • tokens ${stepFinish.tokens.total} • \$${stepFinish.cost.toStringAsFixed(6)}';
          items.add(PopupMenuItem(enabled: false, child: Text(details)));
        }

        if (items.isEmpty) {
          items.add(
            const PopupMenuItem(
              enabled: false,
              child: Text('No metadata available'),
            ),
          );
        }

        return items;
      },
    );
  }

  Widget _buildMessagePart(BuildContext context, MessagePart part) {
    switch (part.type) {
      case PartType.text:
        return _buildTextPart(context, part as TextPart);
      case PartType.file:
        return _buildFilePart(context, part as FilePart);
      case PartType.tool:
        return _buildToolPart(context, part as ToolPart);
      case PartType.agent:
        return _buildAgentPart(context, part as AgentPart);
      case PartType.reasoning:
        return _buildReasoningPart(context, part as ReasoningPart);
      case PartType.stepStart:
        return const SizedBox.shrink();
      case PartType.stepFinish:
        return const SizedBox.shrink();
      case PartType.snapshot:
        return _buildSnapshotPart(context, part as SnapshotPart);
      case PartType.patch:
        return _buildPatchPart(context, part as PatchPart);
      case PartType.subtask:
        return _buildSubtaskPart(context, part as SubtaskPart);
      case PartType.retry:
        return _buildRetryPart(context, part as RetryPart);
      case PartType.compaction:
        return _buildCompactionPart(context, part as CompactionPart);
    }
  }

  Widget _buildTextPart(BuildContext context, TextPart part) {
    // Don't display if text is empty or only whitespace
    if (part.text.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Render text using Markdown
          MarkdownBody(
            data: part.text,
            styleSheet: MarkdownStyleSheet(
              p: Theme.of(context).textTheme.bodyMedium,
              code: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
              ),
              codeblockDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onTapLink: (text, href, title) {
              if (href != null) {
                // TODO: Implement link navigation
              }
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  String _composeMessageCopyText(ChatMessage message) {
    final parts = message.parts
        .whereType<TextPart>()
        .map((part) => part.text.trim())
        .where((text) => text.isNotEmpty)
        .toList(growable: false);
    return parts.join('\n\n');
  }

  void _copyTextToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    final platform = Theme.of(context).platform;
    if (platform == TargetPlatform.android) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
  }

  Widget _buildFilePart(BuildContext context, FilePart part) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Icon(
            _getFileIcon(part.mime),
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  part.filename ?? 'File',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
                if (part.source?.path != null)
                  Text(
                    part.source!.path,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              // TODO: Implement file download or view
            },
            icon: const Icon(Icons.download),
            tooltip: 'Download File',
          ),
        ],
      ),
    );
  }

  Widget _buildToolPart(BuildContext context, ToolPart part) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.build,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Tool Call: ${part.tool}',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              _buildToolStatusChip(context, part.state.status),
            ],
          ),
          const SizedBox(height: 8),

          // Tool status details
          _buildToolStateDetails(context, part.state),
        ],
      ),
    );
  }

  Widget _buildReasoningPart(BuildContext context, ReasoningPart part) {
    // Don't display if reasoning text is empty or only whitespace
    if (part.text.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final lineCount = '\n'.allMatches(part.text).length + 1;
    final isLongReasoning = part.text.length > 600 || lineCount > 12;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.psychology,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Thinking Process',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (isLongReasoning)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: SingleChildScrollView(
                child: Text(
                  part.text,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
                ),
              ),
            )
          else
            Text(
              part.text,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
            ),
        ],
      ),
    );
  }

  Widget _buildAgentPart(BuildContext context, AgentPart part) {
    return _buildInfoContainer(
      context,
      icon: Icons.support_agent,
      title: 'Agent',
      subtitle: part.name,
    );
  }

  Widget _buildSnapshotPart(BuildContext context, SnapshotPart part) {
    return _buildInfoContainer(
      context,
      icon: Icons.camera_alt_outlined,
      title: 'Snapshot',
      subtitle: part.snapshot,
    );
  }

  Widget _buildPatchPart(BuildContext context, PatchPart part) {
    final files = part.files.take(4).join(', ');
    final suffix = part.files.length > 4
        ? ' (+${part.files.length - 4} more)'
        : '';
    return _buildInfoContainer(
      context,
      icon: Icons.compare_arrows_outlined,
      title: 'Patch',
      subtitle: files.isEmpty ? part.hash : '$files$suffix',
    );
  }

  Widget _buildSubtaskPart(BuildContext context, SubtaskPart part) {
    final model = part.model == null
        ? ''
        : ' • ${part.model!.providerId}/${part.model!.modelId}';
    return _buildInfoContainer(
      context,
      icon: Icons.task_outlined,
      title: 'Subtask (${part.agent})',
      subtitle: '${part.description}$model',
    );
  }

  Widget _buildRetryPart(BuildContext context, RetryPart part) {
    return _buildInfoContainer(
      context,
      icon: Icons.refresh_outlined,
      title: 'Retry #${part.attempt}',
      subtitle: part.error.message,
    );
  }

  Widget _buildCompactionPart(BuildContext context, CompactionPart part) {
    return _buildInfoContainer(
      context,
      icon: Icons.compress_outlined,
      title: 'Compaction',
      subtitle: part.auto ? 'automatic' : 'manual',
    );
  }

  Widget _buildInfoContainer(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolStatusChip(BuildContext context, ToolStatus status) {
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case ToolStatus.pending:
        color = Colors.grey;
        label = 'Waiting';
        icon = Icons.schedule;
        break;
      case ToolStatus.running:
        color = Colors.blue;
        label = 'Running';
        icon = Icons.play_arrow;
        break;
      case ToolStatus.completed:
        color = Colors.green;
        label = 'Completed';
        icon = Icons.check;
        break;
      case ToolStatus.error:
        color = Colors.red;
        label = 'Error';
        icon = Icons.error;
        break;
    }

    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label),
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildToolStateDetails(BuildContext context, ToolState state) {
    switch (state.status) {
      case ToolStatus.running:
        final runningState = state as ToolStateRunning;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (runningState.title != null)
              Text(
                runningState.title!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const LinearProgressIndicator(),
          ],
        );
      case ToolStatus.completed:
        final completedState = state as ToolStateCompleted;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (completedState.title != null)
              Text(
                completedState.title!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
              ),
            if (completedState.output.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: _CollapsibleToolContent(
                  text: completedState.output,
                  collapsedMaxLines: _collapsedToolDetailMaxLines,
                  textStyle: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                ),
              ),
          ],
        );
      case ToolStatus.error:
        final errorState = state as ToolStateError;
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(4),
          ),
          child: _CollapsibleToolContent(
            text: errorState.error,
            collapsedMaxLines: _collapsedToolDetailMaxLines,
            textStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            toggleTextStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildErrorInfo(BuildContext context, MessageError error) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.error,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  error.name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
                Text(
                  error.message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String mime) {
    if (mime.startsWith('image/')) {
      return Icons.image;
    } else if (mime.startsWith('video/')) {
      return Icons.video_file;
    } else if (mime.startsWith('audio/')) {
      return Icons.audio_file;
    } else if (mime.contains('pdf')) {
      return Icons.picture_as_pdf;
    } else if (mime.contains('text/')) {
      return Icons.text_snippet;
    } else {
      return Icons.insert_drive_file;
    }
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
    } else {
      return '${time.month}/${time.day} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
  }
}

class _CollapsibleToolContent extends StatefulWidget {
  const _CollapsibleToolContent({
    required this.text,
    required this.collapsedMaxLines,
    this.textStyle,
    this.toggleTextStyle,
  });

  final String text;
  final int collapsedMaxLines;
  final TextStyle? textStyle;
  final TextStyle? toggleTextStyle;

  @override
  State<_CollapsibleToolContent> createState() =>
      _CollapsibleToolContentState();
}

class _CollapsibleToolContentState extends State<_CollapsibleToolContent> {
  bool _expanded = false;

  bool get _canExpand {
    if (widget.text.trim().isEmpty) {
      return false;
    }
    final lineCount = '\n'.allMatches(widget.text).length + 1;
    return lineCount > widget.collapsedMaxLines || widget.text.length > 160;
  }

  @override
  Widget build(BuildContext context) {
    final contentWidget = Text(
      widget.text,
      key: const ValueKey<String>('tool_content_text'),
      maxLines: _expanded ? null : widget.collapsedMaxLines,
      overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
      style: widget.textStyle,
    );

    if (!_canExpand) {
      return contentWidget;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        contentWidget,
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            key: const ValueKey<String>('tool_content_toggle_button'),
            onPressed: () {
              setState(() {
                _expanded = !_expanded;
              });
            },
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            ),
            child: Text(
              _expanded ? 'Show less' : 'Show more',
              style: widget.toggleTextStyle,
            ),
          ),
        ),
      ],
    );
  }
}

class _BubbleTouchHoldLayer extends StatefulWidget {
  const _BubbleTouchHoldLayer({
    required this.child,
    required this.borderRadius,
    required this.flashColor,
    this.onLongPress,
    this.onLongPressRelease,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final Color flashColor;
  final VoidCallback? onLongPress;
  final VoidCallback? onLongPressRelease;

  @override
  State<_BubbleTouchHoldLayer> createState() => _BubbleTouchHoldLayerState();
}

class _BubbleTouchHoldLayerState extends State<_BubbleTouchHoldLayer> {
  static const Duration _holdDelay = Duration(milliseconds: 260);
  static const Duration _flashDuration = Duration(milliseconds: 170);
  static const double _moveTolerance = 14;

  Timer? _holdTimer;
  Timer? _flashTimer;
  int? _activePointer;
  Offset? _pointerDownPosition;
  bool _longPressTriggered = false;
  bool _isFlashing = false;

  @override
  void dispose() {
    _holdTimer?.cancel();
    _flashTimer?.cancel();
    super.dispose();
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (widget.onLongPress == null) {
      return;
    }
    _holdTimer?.cancel();
    _activePointer = event.pointer;
    _pointerDownPosition = event.localPosition;
    _longPressTriggered = false;
    _holdTimer = Timer(_holdDelay, _triggerLongPress);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointer || _pointerDownPosition == null) {
      return;
    }
    final movedDistance =
        (event.localPosition - _pointerDownPosition!).distance;
    if (!_longPressTriggered && movedDistance > _moveTolerance) {
      _cancelHold();
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (event.pointer == _activePointer) {
      final shouldDispatchLongPressRelease = _longPressTriggered;
      _cancelHold();
      if (shouldDispatchLongPressRelease) {
        widget.onLongPressRelease?.call();
      }
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (event.pointer == _activePointer) {
      _cancelHold();
    }
  }

  void _triggerLongPress() {
    _holdTimer?.cancel();
    _holdTimer = null;
    if (!mounted || widget.onLongPress == null) {
      return;
    }
    _longPressTriggered = true;
    widget.onLongPress!();
    _triggerFlash();
  }

  void _cancelHold() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _activePointer = null;
    _pointerDownPosition = null;
    _longPressTriggered = false;
  }

  void _triggerFlash() {
    if (!mounted) {
      return;
    }
    _flashTimer?.cancel();
    setState(() {
      _isFlashing = true;
    });
    _flashTimer = Timer(_flashDuration, () {
      if (!mounted) {
        return;
      }
      setState(() {
        _isFlashing = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _handlePointerDown,
          onPointerMove: _handlePointerMove,
          onPointerUp: _handlePointerUp,
          onPointerCancel: _handlePointerCancel,
          child: AbsorbPointer(
            absorbing: _longPressTriggered,
            child: widget.child,
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: _isFlashing ? 1 : 0,
              duration: const Duration(milliseconds: 120),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: widget.flashColor,
                  borderRadius: widget.borderRadius,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
