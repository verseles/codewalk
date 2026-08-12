import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/di/injection_container.dart' as di;
import '../../core/i18n/l10n_context.dart';
import '../../core/logging/app_logger.dart';
import '../../domain/entities/chat_message.dart';
import '../../presentation/pages/settings_page.dart';
import '../../presentation/providers/settings_provider.dart';
import '../../presentation/services/read_aloud_service.dart';
import '../../presentation/services/tts/read_aloud_text_extractor.dart';
import '../services/file_part_action_service.dart' as file_part_action;
import '../services/message_image_export_service.dart';
import '../theme/app_animations.dart';
import '../theme/app_semantic_colors.dart';
import '../theme/app_shapes.dart';
import '../theme/app_visual_style_tokens.dart';
import '../theme/opencode_highlight_theme.dart';
import '../theme/opencode_theme_presets.dart';
import '../utils/app_page_route.dart';
import '../utils/chat_abort_message.dart';
import '../utils/diff_parser.dart';
import '../utils/file_path_detector.dart';
import '../utils/file_path_markdown.dart';
import '../utils/math_markdown.dart';
import '../utils/reasoning_status_parser.dart';
import '../utils/tool_presentation.dart';
import 'mermaid_diagram_widget.dart';
import 'message_entrance_animation.dart';

part 'chat_message/chat_message_content.dart';
part 'chat_message/chat_message_part_dispatch.dart';
part 'chat_message/chat_message_text_part.dart';
part 'chat_message/chat_message_file_part.dart';
part 'chat_message/chat_message_tool_helpers.dart';
part 'chat_message/chat_message_tool_part.dart';
part 'chat_message/chat_message_info_parts.dart';

class TaskToolChildSummary {
  const TaskToolChildSummary({this.latestToolLabel, this.toolCallCount});

  final String? latestToolLabel;
  final int? toolCallCount;
}

/// Chat message widget.
///
/// Uses a StatefulWidget so that completed messages can skip expensive
/// rebuilds when only transient props (like [isSessionActivelyResponding])
/// change during streaming — those props don't affect completed bubbles.
class ChatMessageWidget extends StatefulWidget {
  const ChatMessageWidget({
    super.key,
    required this.message,
    this.activeReasoningPartKey,
    this.showThinkingBubbles = true,
    this.showToolCallBubbles = true,
    this.showInlineUndoAction = false,
    this.isSessionActivelyResponding = false,
    this.onInlineUndo,
    this.onInlineRevertToHere,
    this.onBackgroundLongPress,
    this.onBackgroundLongPressEnd,
    this.onSubtaskNavigate,
    this.onTaskToolNavigate,
    this.onFileTap,
    this.onForwardMessage,
    this.taskToolChildSummariesByPartId =
        const <String, TaskToolChildSummary>{},
    this.searchHighlightQuery,
  });

  final ChatMessage message;
  final String? activeReasoningPartKey;
  final bool showThinkingBubbles;
  final bool showToolCallBubbles;
  final bool showInlineUndoAction;
  final bool isSessionActivelyResponding;
  final VoidCallback? onInlineUndo;
  final VoidCallback? onInlineRevertToHere;
  final VoidCallback? onBackgroundLongPress;
  final VoidCallback? onBackgroundLongPressEnd;
  final ValueChanged<SubtaskPart>? onSubtaskNavigate;
  final ValueChanged<ToolPart>? onTaskToolNavigate;
  final VoidCallback? onForwardMessage;

  /// Callback when a file path is tapped in assistant text.
  /// Receives (filePath, lineNumber?, columnNumber?).
  final void Function(String path, int? line, int? col)? onFileTap;
  final Map<String, TaskToolChildSummary> taskToolChildSummariesByPartId;
  final String? searchHighlightQuery;

  @override
  State<ChatMessageWidget> createState() => _ChatMessageWidgetState();
}

class _ChatMessageWidgetState extends State<ChatMessageWidget> {
  static const int _collapsedToolDetailMaxLines = 2;
  static const int _collapsedReasoningMaxLines = 4;
  static const int _expandedReasoningMaxLines = 12;
  static const int _maxMarkdownCharsForRichRender = 64000;
  static const int _maxToolOutputPreviewChars = 50000;
  static const int _maxToolCommandPreviewChars = 6000;
  static const int _maxSyntheticDiffChars = 20000;
  // Snapshot of the last build inputs to skip redundant rebuilds.
  // Completed messages can skip rebuild when no visible prop changed.
  int _lastPartCount = -1;
  int _lastMessageHash = 0;
  String? _lastPartId;
  String? _lastReasoningKey;
  String? _lastSearchHighlightQuery;
  bool _lastShowThinking = true;
  bool _lastShowToolCalls = true;
  bool _lastShowInlineUndoAction = false;
  bool _lastResponding = false;
  int _lastLocalUiStateVersion = 0;
  int _lastTaskToolSummaryHash = 0;
  VoidCallback? _lastInlineRevertToHere;
  ValueChanged<SubtaskPart>? _lastSubtaskNavigate;
  ValueChanged<ToolPart>? _lastTaskToolNavigate;
  double _lastVisualDensityVertical = 0;
  double _lastVisualDensityHorizontal = 0;
  String? _lastThemeKey;
  final Set<String> _seenPartIds = <String>{};
  final Set<String> _newlyArrivedPartIds = <String>{};
  final Map<String, Timer> _partAnimationTimers = <String, Timer>{};
  final Map<String, String> _stableIdentityByPartKey = <String, String>{};
  final Map<String, String> _stableIdentityByCallKey = <String, String>{};
  final Map<String, String> _stableIdentityByHashKey = <String, String>{};
  final Map<String, bool> _toolChainExpandedById = <String, bool>{};
  final Map<String, bool> _toolDetailsExpandedById = <String, bool>{};
  int _stableIdentitySequence = 0;
  int _localUiStateVersion = 0;

  // GlobalKey for the RepaintBoundary that wraps the message bubble,
  // used by MessageImageExportService to capture the bubble as a PNG.
  final GlobalKey _shareImageKey = GlobalKey();
  bool _hideShareImageButtonForCapture = false;
  int? _lastReadAloudErrorSequence;

  void _setShareImageCaptureHidden(bool hidden) {
    setState(() {
      _hideShareImageButtonForCapture = hidden;
      _localUiStateVersion += 1;
    });
  }

  void _syncReadAloudErrorSnackBar(
    BuildContext context,
    ReadAloudService service,
    String messageId,
  ) {
    final message = service.lastErrorMessage;
    final sequence = service.lastErrorSequence;
    if (message == null ||
        message.isEmpty ||
        service.lastErrorMessageId != messageId) {
      _lastReadAloudErrorSequence = null;
      return;
    }
    if (_lastReadAloudErrorSequence == sequence) {
      return;
    }
    _lastReadAloudErrorSequence = sequence;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      if (!service.consumeLastErrorForMessage(
        messageId: messageId,
        message: message,
        sequence: sequence,
      )) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 4)),
      );
    });
  }

  String _nextStableIdentity(String prefix) {
    _stableIdentitySequence += 1;
    return '$prefix:$_stableIdentitySequence';
  }

  int _computeTaskToolSummaryHash() {
    if (widget.taskToolChildSummariesByPartId.isEmpty) {
      return 0;
    }
    final keys = widget.taskToolChildSummariesByPartId.keys.toList(
      growable: false,
    )..sort();
    var hash = 0;
    for (final key in keys) {
      final summary = widget.taskToolChildSummariesByPartId[key];
      hash = Object.hash(
        hash,
        key,
        summary?.latestToolLabel,
        summary?.toolCallCount,
      );
    }
    return hash;
  }

  String _stableToolIdentity({required String partId, required String callId}) {
    final partKey = 'tool:part:$partId';
    final normalizedCallId = callId.trim();

    if (normalizedCallId.isNotEmpty) {
      final callKey = 'tool:call:$normalizedCallId';
      final existing =
          _stableIdentityByCallKey[callKey] ??
          _stableIdentityByPartKey[partKey];
      if (existing != null) {
        _stableIdentityByPartKey[partKey] = existing;
        _stableIdentityByCallKey[callKey] = existing;
        return existing;
      }

      final created = _nextStableIdentity('tool');
      _stableIdentityByPartKey[partKey] = created;
      _stableIdentityByCallKey[callKey] = created;
      return created;
    }

    return _stableIdentityByPartKey.putIfAbsent(
      partKey,
      () => _nextStableIdentity('tool'),
    );
  }

  String _stablePatchIdentity({required String partId, required String hash}) {
    final partKey = 'patch:part:$partId';
    final normalizedHash = hash.trim();

    if (normalizedHash.isNotEmpty) {
      final hashKey = 'patch:hash:$normalizedHash';
      final existing =
          _stableIdentityByHashKey[hashKey] ??
          _stableIdentityByPartKey[partKey];
      if (existing != null) {
        _stableIdentityByPartKey[partKey] = existing;
        _stableIdentityByHashKey[hashKey] = existing;
        return existing;
      }

      final created = _nextStableIdentity('patch');
      _stableIdentityByPartKey[partKey] = created;
      _stableIdentityByHashKey[hashKey] = created;
      return created;
    }

    return _stableIdentityByPartKey.putIfAbsent(
      partKey,
      () => _nextStableIdentity('patch'),
    );
  }

  String _partIdentityToken(MessagePart part) {
    if (part case ToolPart(:final callId, :final id)) {
      return _stableToolIdentity(partId: id, callId: callId);
    }
    if (part case PatchPart(:final hash, :final id)) {
      return _stablePatchIdentity(partId: id, hash: hash);
    }
    return '${part.type.name}:${part.id}';
  }

  @override
  void initState() {
    super.initState();
    _seedPartAnimationBaseline(widget.message);
  }

  @override
  void didUpdateWidget(covariant ChatMessageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _refreshPartAnimationState(oldWidget.message, widget.message);
  }

  @override
  void dispose() {
    for (final timer in _partAnimationTimers.values) {
      timer.cancel();
    }
    _partAnimationTimers.clear();
    super.dispose();
  }

  /// Whether the current rebuild can be skipped (inputs unchanged).
  bool _canSkipRebuild() {
    final msg = widget.message;
    final isStableMessage =
        msg is UserMessage || (msg is AssistantMessage && msg.isCompleted);
    if (!isStableMessage) return false;
    if (widget.showInlineUndoAction) return false;

    final partCount = msg.parts.length;
    final lastPartId = msg.parts.isNotEmpty ? msg.parts.last.id : null;
    final density = Theme.of(context).visualDensity;
    final themeTokens = _resolveThemeTokens(context);
    final taskToolSummaryHash = _computeTaskToolSummaryHash();
    return msg.hashCode == _lastMessageHash &&
        partCount == _lastPartCount &&
        lastPartId == _lastPartId &&
        widget.activeReasoningPartKey == _lastReasoningKey &&
        widget.searchHighlightQuery == _lastSearchHighlightQuery &&
        widget.showThinkingBubbles == _lastShowThinking &&
        widget.showToolCallBubbles == _lastShowToolCalls &&
        widget.showInlineUndoAction == _lastShowInlineUndoAction &&
        identical(widget.onInlineRevertToHere, _lastInlineRevertToHere) &&
        widget.isSessionActivelyResponding == _lastResponding &&
        _localUiStateVersion == _lastLocalUiStateVersion &&
        taskToolSummaryHash == _lastTaskToolSummaryHash &&
        identical(widget.onSubtaskNavigate, _lastSubtaskNavigate) &&
        identical(widget.onTaskToolNavigate, _lastTaskToolNavigate) &&
        density.vertical == _lastVisualDensityVertical &&
        density.horizontal == _lastVisualDensityHorizontal &&
        themeTokens.themeId == _lastThemeKey;
  }

  void _updateBuildSnapshot(BuildContext context) {
    final msg = widget.message;
    final density = Theme.of(context).visualDensity;
    final themeTokens = _resolveThemeTokens(context);
    final taskToolSummaryHash = _computeTaskToolSummaryHash();
    _lastMessageHash = msg.hashCode;
    _lastPartCount = msg.parts.length;
    _lastPartId = msg.parts.isNotEmpty ? msg.parts.last.id : null;
    _lastReasoningKey = widget.activeReasoningPartKey;
    _lastSearchHighlightQuery = widget.searchHighlightQuery;
    _lastShowThinking = widget.showThinkingBubbles;
    _lastShowToolCalls = widget.showToolCallBubbles;
    _lastShowInlineUndoAction = widget.showInlineUndoAction;
    _lastInlineRevertToHere = widget.onInlineRevertToHere;
    _lastResponding = widget.isSessionActivelyResponding;
    _lastLocalUiStateVersion = _localUiStateVersion;
    _lastTaskToolSummaryHash = taskToolSummaryHash;
    _lastSubtaskNavigate = widget.onSubtaskNavigate;
    _lastTaskToolNavigate = widget.onTaskToolNavigate;
    _lastVisualDensityVertical = density.vertical;
    _lastVisualDensityHorizontal = density.horizontal;
    _lastThemeKey = themeTokens.themeId;
  }

  // Cached build result to return when rebuild is skipped.
  Widget? _cachedBuild;

  // Cached MarkdownStyleSheet and builders to avoid re-creating objects on
  // every build, which would force flutter_markdown_plus to re-parse.
  MarkdownStyleSheet? _cachedMarkdownStyleSheet;
  Brightness? _cachedMarkdownBrightness;
  String? _cachedMarkdownThemeKey;

  OpenCodeThemeTokens _resolveThemeTokens(BuildContext context) {
    return Theme.of(context).extension<OpenCodeThemeTokens>() ??
        classicThemeTokensFrom(Theme.of(context).colorScheme);
  }

  MarkdownStyleSheet _resolveMarkdownStyleSheet(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final themeTokens = _resolveThemeTokens(context);
    if (_cachedMarkdownStyleSheet != null &&
        _cachedMarkdownBrightness == brightness &&
        _cachedMarkdownThemeKey == themeTokens.themeId) {
      return _cachedMarkdownStyleSheet!;
    }
    final sheet = MarkdownStyleSheet(
      p: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: themeTokens.textBase),
      h1: Theme.of(
        context,
      ).textTheme.headlineMedium?.copyWith(color: themeTokens.markdownHeading),
      h2: Theme.of(
        context,
      ).textTheme.headlineSmall?.copyWith(color: themeTokens.markdownHeading),
      h3: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(color: themeTokens.markdownHeading),
      h4: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(color: themeTokens.markdownHeading),
      h5: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(color: themeTokens.markdownHeading),
      h6: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(color: themeTokens.markdownHeading),
      a: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: themeTokens.markdownLink),
      code: Theme.of(context).textTheme.bodyMedium?.copyWith(
        fontFamily: 'monospace',
        color: themeTokens.markdownInlineCode,
        backgroundColor: themeTokens.inlineCodeBackground,
      ),
      blockquote: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: themeTokens.textBase),
      blockquotePadding: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 8.0,
      ),
      blockquoteDecoration: BoxDecoration(
        color: themeTokens.surfaceRaised,
        borderRadius: AppShapes.borderExtraSmall,
        border: Border(
          left: BorderSide(color: themeTokens.markdownBlockQuote, width: 4.0),
        ),
      ),
      em: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: themeTokens.markdownEmphasis),
      strong: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: themeTokens.markdownStrong),
      listBullet: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: themeTokens.markdownListItem),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: themeTokens.markdownHorizontalRule),
        ),
      ),
      codeblockDecoration: BoxDecoration(
        color: themeTokens.codeBlockBackground,
        border: Border.all(color: themeTokens.border.withValues(alpha: 0.7)),
        borderRadius: AppShapes.borderSmall,
      ),
    );
    _cachedMarkdownBrightness = brightness;
    _cachedMarkdownThemeKey = themeTokens.themeId;
    _cachedMarkdownStyleSheet = sheet;
    return sheet;
  }

  @override
  Widget build(BuildContext context) {
    if (_cachedBuild != null && _canSkipRebuild()) {
      return _cachedBuild!;
    }
    _updateBuildSnapshot(context);
    final result = _buildContent(context);
    _cachedBuild = result;
    return result;
  }

  // -- Accessors to shorten migration from StatelessWidget to StatefulWidget --
  ChatMessage get message => widget.message;
  String? get activeReasoningPartKey => widget.activeReasoningPartKey;
  String? get searchHighlightQuery => widget.searchHighlightQuery;
  bool get showThinkingBubbles => widget.showThinkingBubbles;
  bool get showToolCallBubbles => widget.showToolCallBubbles;
  bool get showInlineUndoAction => widget.showInlineUndoAction;
  bool get isSessionActivelyResponding => widget.isSessionActivelyResponding;
  VoidCallback? get onInlineUndo => widget.onInlineUndo;
  VoidCallback? get onInlineRevertToHere => widget.onInlineRevertToHere;
  VoidCallback? get onBackgroundLongPress => widget.onBackgroundLongPress;
  VoidCallback? get onBackgroundLongPressEnd => widget.onBackgroundLongPressEnd;
  ValueChanged<SubtaskPart>? get onSubtaskNavigate => widget.onSubtaskNavigate;
  ValueChanged<ToolPart>? get onTaskToolNavigate => widget.onTaskToolNavigate;
  VoidCallback? get onForwardMessage => widget.onForwardMessage;
  TaskToolChildSummary? taskToolChildSummaryForPart(String partId) {
    return widget.taskToolChildSummariesByPartId[partId];
  }

  bool shouldSuppressLiveReasoningPart(ReasoningPart _) {
    // Status-only reasoning markers are filtered in the part builder; real
    // reasoning text should stay visible in both main and subagent timelines.
    return false;
  }

  void _seedPartAnimationBaseline(ChatMessage currentMessage) {
    for (final timer in _partAnimationTimers.values) {
      timer.cancel();
    }
    _partAnimationTimers.clear();
    _stableIdentityByPartKey.clear();
    _stableIdentityByCallKey.clear();
    _stableIdentityByHashKey.clear();
    _toolChainExpandedById.clear();
    _toolDetailsExpandedById.clear();
    _stableIdentitySequence = 0;
    _localUiStateVersion = 0;
    _seenPartIds
      ..clear()
      ..addAll(currentMessage.parts.map(_partIdentityToken));
    _newlyArrivedPartIds.clear();
  }

  void _refreshPartAnimationState(
    ChatMessage previousMessage,
    ChatMessage currentMessage,
  ) {
    if (previousMessage.id != currentMessage.id) {
      _seedPartAnimationBaseline(currentMessage);
      return;
    }

    final currentPartIds = currentMessage.parts.map(_partIdentityToken).toSet();
    for (final partId in currentPartIds.where(
      (partId) => !_seenPartIds.contains(partId),
    )) {
      _markPartForEntranceAnimation(partId);
    }
    for (final partId
        in _newlyArrivedPartIds
            .where((partId) => !currentPartIds.contains(partId))
            .toList(growable: false)) {
      _partAnimationTimers.remove(partId)?.cancel();
      _newlyArrivedPartIds.remove(partId);
    }
    _seenPartIds
      ..clear()
      ..addAll(currentPartIds);
  }

  void _markPartForEntranceAnimation(String partId) {
    if (_newlyArrivedPartIds.contains(partId)) {
      return;
    }
    _newlyArrivedPartIds.add(partId);
    _partAnimationTimers[partId]?.cancel();
    _partAnimationTimers[partId] = Timer(
      AppAnimations.messagePart + AppAnimations.fast,
      () {
        _partAnimationTimers.remove(partId);
        if (!mounted) {
          return;
        }
        if (_newlyArrivedPartIds.remove(partId)) {
          setState(() {});
        }
      },
    );
  }

  bool _shouldAnimatePartArrival(MessagePart part) {
    return _newlyArrivedPartIds.contains(_partIdentityToken(part));
  }

  bool _isToolDetailsExpanded(String toolIdentityToken) {
    return _toolDetailsExpandedById[toolIdentityToken] ?? false;
  }

  void _setToolDetailsExpanded(String toolIdentityToken, bool expanded) {
    final previous = _toolDetailsExpandedById[toolIdentityToken];
    if (previous == expanded) {
      return;
    }
    setState(() {
      _toolDetailsExpandedById[toolIdentityToken] = expanded;
      _localUiStateVersion += 1;
    });
  }

  bool _resolveToolChainExpanded(
    String chainIdentityToken,
    List<MessagePart> parts,
  ) {
    final explicit = _toolChainExpandedById[chainIdentityToken];
    if (explicit != null) {
      return explicit;
    }
    for (final toolPart in parts.whereType<ToolPart>()) {
      if (_isToolDetailsExpanded(_partIdentityToken(toolPart))) {
        return true;
      }
    }
    return false;
  }

  void _setToolChainExpanded(String chainIdentityToken, bool expanded) {
    final previous = _toolChainExpandedById[chainIdentityToken];
    if (previous == expanded) {
      return;
    }
    setState(() {
      _toolChainExpandedById[chainIdentityToken] = expanded;
      _localUiStateVersion += 1;
    });
  }

  // -- Shared utilities used by 3+ part clusters --

  String _truncatePreview(
    BuildContext context,
    String text, {
    required int maxChars,
    required String reason,
  }) {
    if (text.length <= maxChars) {
      return text;
    }
    final head = text.substring(0, maxChars);
    final remaining = text.length - maxChars;
    return '$head\n\n${context.l10n.chatMessageTruncatedChars(remaining, reason)}';
  }

  Widget _buildInfoContainer(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
  }) {
    final theme = Theme.of(context);
    final visualTokens = theme.visualStyleTokens;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: visualTokens.isRefined
            ? visualTokens.mutedControlSurface
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: visualTokens.isRefined
            ? visualTokens.cardRadius
            : AppShapes.borderSmall,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
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

  String _formatTime(BuildContext context, DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return context.l10n.chatMessageJustNow;
    } else if (difference.inHours < 1) {
      return context.l10n.chatMessageMinutesAgo(difference.inMinutes);
    } else if (difference.inDays < 1) {
      return context.l10n.chatMessageHoursAgo(difference.inHours);
    } else if (difference.inDays < 7) {
      return context.l10n.chatMessageDaysAgo(difference.inDays);
    } else {
      return context.l10n.chatMessageDateTime(
        time.day,
        time.hour,
        time.minute,
        time.month,
      );
    }
  }

  Widget _buildErrorInfo(BuildContext context, MessageError error) {
    final isInlineAbortError = isAbortLikeError(
      name: error.name,
      message: error.message,
    );
    final displayMessage = normalizeAbortMessageForDisplay(
      error.message,
      name: error.name,
    );
    final title = isInlineAbortError ? null : error.name;
    final theme = Theme.of(context);
    final visualTokens = theme.visualStyleTokens;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: visualTokens.isRefined
            ? visualTokens.cardRadius
            : AppShapes.borderSmall,
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.3),
          width: visualTokens.isRefined ? visualTokens.enabledBorderWidth : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Symbols.error_outline,
            color: Theme.of(context).colorScheme.error,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                Text(
                  displayMessage,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: isInlineAbortError
                        ? FontWeight.w600
                        : FontWeight.normal,
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
}
