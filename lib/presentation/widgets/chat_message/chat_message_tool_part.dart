part of '../chat_message_widget.dart';

/// Tool part rendering: status chip, details toggle, command/output sections,
/// and diff visualization.
extension _ChatMessageToolPartBuilder on _ChatMessageWidgetState {
  Color _resolveCompletedToolStatusColor(BuildContext context) {
    return AppSemanticColors.success(context);
  }

  String _toolPartIdentityToken(ToolPart part) {
    return _partIdentityToken(part);
  }

  Widget _buildToolPart(
    BuildContext context,
    ToolPart part, {
    VoidCallback? onNavigateToSubConversation,
    TaskToolChildSummary? taskChildSummary,
  }) {
    final isCompactToolStatus = MediaQuery.sizeOf(context).width < 600;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visualTokens = theme.visualStyleTokens;
    final presentation = _toolPresentation(part.tool);
    final descriptionLabel = _resolveToolDescriptionLabel(part);
    final typeLabel = _resolveToolTypeLabel(part);
    final isTaskTool = _normalizeToolName(part.tool) == 'task';
    final isQuestionTool = _normalizeToolName(part.tool) == 'question';
    final hasPendingQuestion =
        isQuestionTool && widget.pendingQuestionCallIds.contains(part.callId);
    final hasDetails = part.state.status != ToolStatus.pending;
    final toolIdentityToken = _toolPartIdentityToken(part);
    final latestTaskCommand =
        isTaskTool && part.state.status == ToolStatus.running
        ? _extractToolCommand(context, part.state)
        : null;
    final taskSecondaryLabel = isTaskTool
        ? _buildTaskToolSecondaryLabel(
            part,
            descriptionLabel: descriptionLabel,
            taskChildSummary: taskChildSummary,
            latestTaskCommand: latestTaskCommand,
          )
        : null;

    final content = Container(
      key: ValueKey<String>('tool_part_container_$toolIdentityToken'),
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: isTaskTool ? 8 : 12,
      ),
      decoration: BoxDecoration(
        color: visualTokens.isRefined
            ? visualTokens.mutedControlSurface
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: visualTokens.isRefined
            ? visualTokens.cardRadius
            : AppShapes.borderSmall,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(presentation.icon, size: 16, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      descriptionLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (!isTaskTool &&
                        typeLabel.toLowerCase() !=
                            descriptionLabel.toLowerCase()) ...[
                      const SizedBox(height: 2),
                      Text(
                        typeLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (taskSecondaryLabel != null &&
                        taskSecondaryLabel.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        taskSecondaryLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ] else if (latestTaskCommand != null &&
                        latestTaskCommand.trim().isNotEmpty &&
                        latestTaskCommand.toLowerCase() !=
                            descriptionLabel.toLowerCase()) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Symbols.terminal_rounded,
                            size: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              latestTaskCommand,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              isTaskTool
                  ? _buildTaskToolStatusIcon(context, part.state.status)
                  : _buildToolStatusChip(
                      context,
                      part.state.status,
                      showLabel: !isCompactToolStatus,
                    ),
            ],
          ),
          if (!isTaskTool) ...[
            const SizedBox(height: 8),
            _ToolPartDetailsToggle(
              key: ValueKey<String>(
                'tool_part_details_toggle_$toolIdentityToken',
              ),
              expanded: _isToolDetailsExpanded(toolIdentityToken),
              onExpandedChanged: (expanded) =>
                  _setToolDetailsExpanded(toolIdentityToken, expanded),
              partId: part.id,
              hasDetails: hasDetails,
              details: _buildToolStateDetails(context, part.state, part.tool),
              pendingQuestionAction: hasPendingQuestion &&
                      widget.onShowQuestion != null
                  ? () => widget.onShowQuestion!(part)
                  : null,
            ),
          ],
        ],
      ),
    );

    if (!isTaskTool || onNavigateToSubConversation == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey<String>('task_tool_open_session_${part.id}'),
        onTap: onNavigateToSubConversation,
        borderRadius: visualTokens.isRefined
            ? visualTokens.cardRadius
            : AppShapes.borderSmall,
        child: content,
      ),
    );
  }

  String? _buildTaskToolSecondaryLabel(
    ToolPart part, {
    required String descriptionLabel,
    required TaskToolChildSummary? taskChildSummary,
    required String? latestTaskCommand,
  }) {
    if (part.state.status == ToolStatus.completed) {
      final toolCallCount = taskChildSummary?.toolCallCount;
      if (toolCallCount != null) {
        return toolCallCount == 1
            ? context.l10n.chatMessageToolCall
            : context.l10n.chatMessageToolCalls(toolCallCount);
      }
      return null;
    }

    final latestToolLabel = taskChildSummary?.latestToolLabel?.trim();
    if (latestToolLabel != null &&
        latestToolLabel.isNotEmpty &&
        latestToolLabel.toLowerCase() != descriptionLabel.toLowerCase()) {
      return latestToolLabel;
    }

    final fallbackCommand = latestTaskCommand?.trim();
    if (fallbackCommand != null &&
        fallbackCommand.isNotEmpty &&
        fallbackCommand.toLowerCase() != descriptionLabel.toLowerCase()) {
      return fallbackCommand;
    }

    return part.state.status == ToolStatus.running
        ? context.l10n.chatMessageRunningTask
        : null;
  }

  Widget _buildTaskToolStatusIcon(BuildContext context, ToolStatus status) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = switch (status) {
      ToolStatus.pending || ToolStatus.running => colorScheme.primary,
      ToolStatus.completed => _resolveCompletedToolStatusColor(context),
      ToolStatus.error => colorScheme.error,
    };
    final icon = switch (status) {
      ToolStatus.pending || ToolStatus.running => Symbols.hourglass_top_rounded,
      ToolStatus.completed => Symbols.check_circle_rounded,
      ToolStatus.error => Symbols.warning_amber_rounded,
    };
    return Icon(icon, size: 20, color: color);
  }

  Widget _buildToolStatusChip(
    BuildContext context,
    ToolStatus status, {
    required bool showLabel,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case ToolStatus.pending:
        color = colorScheme.secondary;
        label = context.l10n.chatMessageToolStatusQueued;
        icon = Symbols.schedule;
        break;
      case ToolStatus.running:
        color = colorScheme.primary;
        label = context.l10n.chatMessageToolStatusInProgress;
        icon = Symbols.play_arrow;
        break;
      case ToolStatus.completed:
        color = _resolveCompletedToolStatusColor(context);
        label = context.l10n.onboardingDone;
        icon = Symbols.check_circle_outline_rounded;
        break;
      case ToolStatus.error:
        color = colorScheme.error;
        label = context.l10n.chatMessageToolStatusNeedsAttention;
        icon = Symbols.warning_amber_rounded;
        break;
    }

    if (!showLabel) {
      return Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: AppShapes.borderFull,
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, size: 16, color: color),
      );
    }

    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label),
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: Theme.of(context).visualDensity,
    );
  }

  Widget _buildToolStateDetails(
    BuildContext context,
    ToolState state,
    String toolName,
  ) {
    final command = _extractToolCommand(context, state);
    switch (state.status) {
      case ToolStatus.running:
        final runningState = state as ToolStateRunning;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (command != null)
              _buildToolCommandSection(
                context,
                toolName: toolName,
                command: command,
              ),
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
        final resolvedOutput = _resolveToolOutput(
          toolName: toolName,
          state: completedState,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (command != null)
              _buildToolCommandSection(
                context,
                toolName: toolName,
                command: command,
              ),
            if (completedState.title != null)
              Text(
                completedState.title!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
              ),
            if (resolvedOutput.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: AppShapes.borderExtraSmall,
                ),
                child: _buildToolBodyContent(
                  context,
                  text: resolvedOutput,
                  toolName: toolName,
                  lineKeyPrefix: 'tool_output_diff',
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
            borderRadius: AppShapes.borderExtraSmall,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (command != null)
                _buildToolCommandSection(
                  context,
                  toolName: toolName,
                  command: command,
                  inErrorContainer: true,
                ),
              _buildToolBodyContent(
                context,
                text: errorState.error,
                toolName: toolName,
                lineKeyPrefix: 'tool_error_diff',
                textColor: Theme.of(context).colorScheme.onErrorContainer,
                toggleColor: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ],
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildToolBodyContent(
    BuildContext context, {
    required String text,
    required String toolName,
    required String lineKeyPrefix,
    Color? textColor,
    Color? toggleColor,
  }) {
    final textForRender = _truncatePreview(
      context,
      text,
      maxChars: _ChatMessageWidgetState._maxToolOutputPreviewChars,
      reason: context.l10n.chatMessageToolOutputTruncated,
    );
    return _CollapsibleToolContent(
      text: textForRender,
      collapsedMaxLines: _ChatMessageWidgetState._collapsedToolDetailMaxLines,
      toolName: toolName,
      lineKeyPrefix: lineKeyPrefix,
      textStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: textColor,
        fontFamily: 'monospace',
      ),
      toggleTextStyle: toggleColor == null
          ? null
          : Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: toggleColor),
    );
  }

  Widget _buildToolCommandSection(
    BuildContext context, {
    required String toolName,
    required String command,
    bool inErrorContainer = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final labelColor = inErrorContainer
        ? colorScheme.onErrorContainer.withValues(alpha: 0.84)
        : colorScheme.onSurfaceVariant;
    final valueColor = inErrorContainer
        ? colorScheme.onErrorContainer
        : colorScheme.onSurface;
    final backgroundColor = inErrorContainer
        ? colorScheme.onErrorContainer.withValues(alpha: 0.08)
        : colorScheme.surface;
    final isCommandTool = toolName.trim().toLowerCase() == 'bash';
    final prefix = isCommandTool
        ? context.l10n.chatMessageToolCommand
        : context.l10n.chatMessageToolInput;

    final shouldColorizeInput =
        !isCommandTool && _isDiffLikeToolInput(toolName, command);

    if (shouldColorizeInput) {
      final normalizedInput = _normalizeToolInputDiff(command);
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: AppShapes.borderExtraSmall,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$prefix:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: labelColor,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 4),
            _buildToolBodyContent(
              context,
              text: normalizedInput,
              toolName: toolName,
              lineKeyPrefix: 'tool_input_diff',
              textColor: valueColor,
              toggleColor: labelColor,
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: AppShapes.borderExtraSmall,
      ),
      child: RichText(
        key: const ValueKey<String>('tool_command_text'),
        textScaler: MediaQuery.textScalerOf(context),
        text: TextSpan(
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
          children: [
            TextSpan(
              text: '$prefix: ',
              style: TextStyle(color: labelColor, fontWeight: FontWeight.w600),
            ),
            TextSpan(
              text: command,
              style: TextStyle(color: valueColor),
            ),
          ],
        ),
      ),
    );
  }

  bool _isDiffLikeToolInput(String toolName, String command) {
    final toolLower = toolName.trim().toLowerCase();

    if (toolLower.contains('apply_patch') ||
        toolLower.contains('patch') ||
        toolLower == 'edit') {
      return command.contains('*** Begin Patch') ||
          command.contains('\n+') ||
          command.contains('\n-') ||
          command.contains('\n@@') ||
          command.contains('\ndiff --git');
    }

    return isDiffFormat(command);
  }

  String _normalizeToolInputDiff(String command) {
    const markers = <String>['*** Begin Patch', 'diff --git', '--- ', '@@'];

    for (final marker in markers) {
      final index = command.indexOf(marker);
      if (index > 0) {
        return command.substring(index).trimRight();
      }
      if (index == 0) {
        return command;
      }
    }

    return command;
  }

  String? _extractToolCommand(BuildContext context, ToolState state) {
    switch (state.status) {
      case ToolStatus.pending:
        return null;
      case ToolStatus.running:
        final runningState = state as ToolStateRunning;
        return _extractCommandFromInputMap(context, runningState.input);
      case ToolStatus.completed:
        final completedState = state as ToolStateCompleted;
        return _extractCommandFromInputMap(context, completedState.input);
      case ToolStatus.error:
        final errorState = state as ToolStateError;
        return _extractCommandFromInputMap(context, errorState.input);
    }
  }

  String? _extractCommandFromInputMap(
    BuildContext context,
    Map<String, dynamic> input,
  ) {
    if (input.isEmpty) {
      return null;
    }

    String? readString(dynamic value) {
      if (value is! String) {
        return null;
      }
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    Map<String, dynamic>? readMap(dynamic value) {
      if (value is Map<String, dynamic>) {
        return value;
      }
      if (value is Map) {
        return Map<String, dynamic>.from(value);
      }
      return null;
    }

    final command = readString(input['command']) ?? readString(input['cmd']);
    if (command != null) {
      return _truncatePreview(
        context,
        command,
        maxChars: _ChatMessageWidgetState._maxToolCommandPreviewChars,
        reason: context.l10n.chatMessageToolCommandTruncated,
      );
    }

    final nestedInput = readMap(input['input']);
    if (nestedInput != null) {
      final nestedCommand = _extractCommandFromInputMap(context, nestedInput);
      if (nestedCommand != null) {
        return nestedCommand;
      }
    }

    final fallback = input.entries
        .where((entry) => entry.value != null)
        .map((entry) => '${entry.key}: ${entry.value}')
        .join(' | ')
        .trim();
    if (fallback.isEmpty) {
      return null;
    }
    return _truncatePreview(
      context,
      fallback,
      maxChars: _ChatMessageWidgetState._maxToolCommandPreviewChars,
      reason: context.l10n.chatMessageToolInputTruncated,
    );
  }

  String _resolveToolOutput({
    required String toolName,
    required ToolStateCompleted state,
  }) {
    final output = state.output.trim();
    if (output.isNotEmpty) {
      return _truncatePreview(
        context,
        state.output,
        maxChars: _ChatMessageWidgetState._maxToolOutputPreviewChars,
        reason: context.l10n.chatMessageToolOutputTruncated,
      );
    }

    final input = state.input;
    final tool = toolName.toLowerCase();
    final directDiff = _firstInputString(input, const [
      'diff',
      'patch',
      'unified_diff',
      'unifiedDiff',
      'content',
      'text',
    ]);
    if (directDiff != null && directDiff.trim().isNotEmpty) {
      return _truncatePreview(
        context,
        directDiff,
        maxChars: _ChatMessageWidgetState._maxToolOutputPreviewChars,
        reason: context.l10n.chatMessageDiffPreviewTruncated,
      );
    }

    if (tool == 'edit' || tool.contains('edit') || tool.contains('patch')) {
      final syntheticDiff = _buildSyntheticEditDiff(input);
      if (syntheticDiff != null) {
        return syntheticDiff;
      }
    }

    return '';
  }

  String? _firstInputString(Map<String, dynamic> input, List<String> keys) {
    for (final key in keys) {
      final value = input[key];
      if (value is String && value.trim().isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  String? _buildSyntheticEditDiff(Map<String, dynamic> input) {
    final before = _firstInputString(input, const [
      'old_string',
      'oldString',
      'before',
      'old',
    ]);
    final after = _firstInputString(input, const [
      'new_string',
      'newString',
      'after',
      'new',
    ]);
    if (before == null || after == null || before == after) {
      return null;
    }

    if (before.length + after.length >
        _ChatMessageWidgetState._maxSyntheticDiffChars) {
      return context.l10n.chatMessageToolDiffOmitted;
    }

    final path =
        _firstInputString(input, const [
          'file_path',
          'path',
          'file',
          'target',
        ]) ??
        'file';

    final beforeLines = before.split('\n').map((line) => '-$line').join('\n');
    final afterLines = after.split('\n').map((line) => '+$line').join('\n');
    return '--- $path\n+++ $path\n@@\n$beforeLines\n$afterLines';
  }
}

class _ToolPartDetailsToggle extends StatelessWidget {
  const _ToolPartDetailsToggle({
    super.key,
    required this.expanded,
    required this.onExpandedChanged,
    required this.partId,
    required this.hasDetails,
    required this.details,
    this.pendingQuestionAction,
  });

  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;
  final String partId;
  final bool hasDetails;
  final Widget details;
  final VoidCallback? pendingQuestionAction;
  @override
  Widget build(BuildContext context) {
    final hasQuestionAction = pendingQuestionAction != null;
    if (!hasDetails && !hasQuestionAction) {
      return const SizedBox.shrink();
    }
    final compactLayout = MediaQuery.sizeOf(context).width < 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (expanded) details,
        Align(
          alignment: Alignment.centerRight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasQuestionAction)
                TextButton.icon(
                  key: ValueKey<String>(
                    'tool_part_question_action_$partId',
                  ),
                  onPressed: pendingQuestionAction,
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                  ),
                  icon: const Icon(Symbols.help_outline_rounded, size: 14),
                  label: Text(context.l10n.chatMessageShowQuestion),
                ),
              if (hasDetails) ...[
                const SizedBox(width: 8),
                TextButton(
                  key: ValueKey<String>('tool_part_details_button_$partId'),
                  onPressed: () => onExpandedChanged(!expanded),
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                  ),
                  child: Text(
                    expanded
                        ? context.l10n.chatMessageHide
                        : (compactLayout
                              ? context.l10n.chatMessageShow
                              : context.l10n.chatMessageDetails),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CollapsibleToolContent extends StatefulWidget {
  const _CollapsibleToolContent({
    required this.text,
    required this.collapsedMaxLines,
    required this.toolName,
    this.lineKeyPrefix = 'tool_diff_line',
    this.textStyle,
    this.toggleTextStyle,
  });

  final String text;
  final int collapsedMaxLines;
  final String toolName;
  final String lineKeyPrefix;
  final TextStyle? textStyle;
  final TextStyle? toggleTextStyle;

  @override
  State<_CollapsibleToolContent> createState() =>
      _CollapsibleToolContentState();
}

class _DiffLineVisualStyle {
  const _DiffLineVisualStyle({this.textColor, this.backgroundColor});

  final Color? textColor;
  final Color? backgroundColor;
}

class _CollapsibleToolContentState extends State<_CollapsibleToolContent> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scheduleAutoScrollToLatest(forceJump: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _CollapsibleToolContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _scheduleAutoScrollToLatest(forceJump: false);
    }
  }

  double _expandedToolViewportHeight(BuildContext context) {
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final responsiveCap = viewportHeight * 0.4;
    return math.min(300.0, responsiveCap.clamp(180.0, 300.0));
  }

  void _scheduleAutoScrollToLatest({required bool forceJump}) {
    final disableAnimations = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      final maxScrollExtent = _scrollController.position.maxScrollExtent;
      if (maxScrollExtent <= 0) {
        return;
      }
      final distanceToBottom =
          maxScrollExtent - _scrollController.position.pixels;
      if (!forceJump && distanceToBottom > 24) {
        return;
      }
      if (forceJump || disableAnimations) {
        _scrollController.jumpTo(maxScrollExtent);
        return;
      }
      unawaited(
        _scrollController
            .animateTo(
              maxScrollExtent,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
            )
            .catchError((_) {}),
      );
    });
  }

  bool get _canExpand {
    if (widget.text.trim().isEmpty) {
      return false;
    }
    if (widget.text.length > 160) {
      return true;
    }
    final lineCount = '\n'.allMatches(widget.text).length + 1;
    return lineCount > widget.collapsedMaxLines;
  }

  /// Hybrid detection: tool name + content heuristic.
  bool _isDiffContent(String toolName, String text) {
    final toolLower = toolName.toLowerCase();
    if (toolLower.contains('apply_patch') ||
        toolLower.contains('patch') ||
        toolLower == 'edit') {
      return true;
    }

    // Heuristic for bash/others (first 20 lines)
    return isDiffFormat(text);
  }

  DiffLineType _resolveDiffLineType(String line) {
    if (line.isEmpty) {
      return DiffLineType.context;
    }
    return parseDiffLines(line).first.type;
  }

  _DiffLineVisualStyle _resolveDiffVisualStyle(
    BuildContext context,
    DiffLineType lineType,
  ) {
    final brightness = Theme.of(context).brightness;
    switch (lineType) {
      case DiffLineType.add:
        return _DiffLineVisualStyle(
          textColor: AppSemanticColors.success(context),
          backgroundColor: AppSemanticColors.successContainer(context),
        );
      case DiffLineType.remove:
        return _DiffLineVisualStyle(
          textColor: brightness == Brightness.dark
              ? Colors.red.shade400
              : Colors.red.shade700,
          backgroundColor: brightness == Brightness.dark
              ? Colors.red.shade800.withValues(alpha: 0.42)
              : Colors.red.shade100,
        );
      case DiffLineType.hunk:
        return _DiffLineVisualStyle(
          textColor: brightness == Brightness.dark
              ? Colors.amber.shade300
              : Colors.orange.shade800,
          backgroundColor: brightness == Brightness.dark
              ? Colors.amber.shade800.withValues(alpha: 0.38)
              : Colors.orange.shade100,
        );
      case DiffLineType.metadata:
        return _DiffLineVisualStyle(
          textColor: Theme.of(context).colorScheme.onSurfaceVariant,
        );
      case DiffLineType.context:
        return const _DiffLineVisualStyle();
    }
  }

  Widget _buildDiffLine(
    BuildContext context, {
    required int index,
    required String line,
  }) {
    final lineType = _resolveDiffLineType(line);
    final visualStyle = _resolveDiffVisualStyle(context, lineType);

    return Container(
      key: ValueKey<String>('${widget.lineKeyPrefix}_container_$index'),
      width: double.infinity,
      color: visualStyle.backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      child: Text(
        line,
        key: ValueKey<String>('${widget.lineKeyPrefix}_text_$index'),
        style:
            widget.textStyle?.copyWith(color: visualStyle.textColor) ??
            TextStyle(color: visualStyle.textColor, fontFamily: 'monospace'),
      ),
    );
  }

  /// Per-line diff rendering to ensure visible background colors.
  Widget _buildColorizedDiffContent(BuildContext context, String text) {
    final lines = text.split('\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < lines.length; i++)
          _buildDiffLine(context, index: i, line: lines[i]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDiff = _isDiffContent(widget.toolName, widget.text);

    if (!_canExpand) {
      if (isDiff) {
        return _buildColorizedDiffContent(context, widget.text);
      }
      return Text(
        widget.text,
        key: const ValueKey<String>('tool_content_text'),
        style: widget.textStyle,
      );
    }

    final maxHeight = _expandedToolViewportHeight(context);
    final scrollKey = ValueKey<String>(
      'tool_content_scroll_${widget.lineKeyPrefix}',
    );
    final scrollbarKey = ValueKey<String>(
      'tool_content_scrollbar_${widget.lineKeyPrefix}',
    );

    if (isDiff) {
      final lines = widget.text.split('\n');
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Scrollbar(
          key: scrollbarKey,
          controller: _scrollController,
          thumbVisibility: true,
          child: ListView.builder(
            key: scrollKey,
            controller: _scrollController,
            primary: false,
            shrinkWrap: true,
            itemCount: lines.length,
            itemBuilder: (context, index) =>
                _buildDiffLine(context, index: index, line: lines[index]),
          ),
        ),
      );
    }

    final contentWidget = Text(
      widget.text,
      key: const ValueKey<String>('tool_content_text'),
      style: widget.textStyle,
    );

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Scrollbar(
        key: scrollbarKey,
        controller: _scrollController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          key: scrollKey,
          controller: _scrollController,
          primary: false,
          child: contentWidget,
        ),
      ),
    );
  }
}
