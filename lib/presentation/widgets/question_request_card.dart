import '../../core/i18n/l10n_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../domain/entities/chat_realtime.dart';

class _QuestionPrimaryIntent extends Intent {
  const _QuestionPrimaryIntent();
}

class _QuestionBackIntent extends Intent {
  const _QuestionBackIntent();
}

class _QuestionRejectIntent extends Intent {
  const _QuestionRejectIntent();
}

class QuestionRequestCard extends StatefulWidget {
  const QuestionRequestCard({
    super.key,
    required this.request,
    required this.busy,
    required this.onSubmit,
    required this.onReject,
    this.originBadgeLabel,
  });

  final ChatQuestionRequest request;
  final bool busy;
  final ValueChanged<List<List<String>>> onSubmit;
  final VoidCallback onReject;
  final String? originBadgeLabel;

  @override
  State<QuestionRequestCard> createState() => _QuestionRequestCardState();
}

class _QuestionRequestCardState extends State<QuestionRequestCard> {
  int _stepIndex = 0;
  bool _showRejectedState = false;
  final Map<int, Set<String>> _selectedByQuestion = <int, Set<String>>{};
  final Map<int, TextEditingController> _customByQuestion =
      <int, TextEditingController>{};

  int get _questionCount => widget.request.questions.length;
  int get _maxStepIndex => _questionCount;
  int get _totalSteps => _questionCount + 1;
  bool get _isReviewStep => _stepIndex >= _questionCount;

  @override
  void didUpdateWidget(covariant QuestionRequestCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.request.id != widget.request.id) {
      _resetForNewRequest();
      return;
    }
    _removeInvalidQuestionState();
    if (_stepIndex > _maxStepIndex) {
      _stepIndex = _maxStepIndex;
    }
  }

  @override
  void dispose() {
    for (final controller in _customByQuestion.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _resetForNewRequest() {
    for (final controller in _customByQuestion.values) {
      controller.dispose();
    }
    _customByQuestion.clear();
    _selectedByQuestion.clear();
    _stepIndex = 0;
    _showRejectedState = false;
  }

  void _removeInvalidQuestionState() {
    _selectedByQuestion.removeWhere((questionIndex, _) {
      return questionIndex >= _questionCount;
    });
    _customByQuestion.removeWhere((questionIndex, controller) {
      final remove = questionIndex >= _questionCount;
      if (remove) {
        controller.dispose();
      }
      return remove;
    });
  }

  TextEditingController _controllerFor(int index) {
    return _customByQuestion.putIfAbsent(index, TextEditingController.new);
  }

  List<List<String>> _buildAnswers() {
    final output = <List<String>>[];
    for (var i = 0; i < widget.request.questions.length; i++) {
      output.add(_answersForQuestion(i));
    }
    return output;
  }

  List<String> _answersForQuestion(int index) {
    final selected = <String>{...(_selectedByQuestion[index] ?? <String>{})};
    final custom = _customByQuestion[index]?.text ?? '';
    final customTokens = custom
        .split(',')
        .map((token) => token.trim())
        .where((token) => token.isNotEmpty);
    selected.addAll(customTokens);
    return selected.toList(growable: false);
  }

  void _toggleOption({
    required int questionIndex,
    required ChatQuestionInfo question,
    required String label,
  }) {
    final current = _selectedByQuestion.putIfAbsent(
      questionIndex,
      () => <String>{},
    );
    if (question.multiple) {
      if (current.contains(label)) {
        current.remove(label);
      } else {
        current.add(label);
      }
      return;
    }
    if (current.length == 1 && current.contains(label)) {
      current.clear();
      return;
    }
    current
      ..clear()
      ..add(label);
  }

  void _goToPreviousStep() {
    if (_stepIndex <= 0) {
      return;
    }
    setState(() {
      _showRejectedState = false;
      _stepIndex -= 1;
    });
  }

  void _goToNextStep() {
    if (_stepIndex >= _maxStepIndex) {
      return;
    }
    setState(() {
      _showRejectedState = false;
      _stepIndex += 1;
    });
  }

  void _showRejectState() {
    if (_showRejectedState) {
      return;
    }
    setState(() {
      _showRejectedState = true;
    });
  }

  void _reopenRejectedQuestion() {
    if (!_showRejectedState) {
      return;
    }
    setState(() {
      _showRejectedState = false;
    });
  }

  void _invokePrimaryAction() {
    if (widget.busy) {
      return;
    }
    if (_showRejectedState) {
      // In rejected mode, the primary shortcut confirms server-side reject.
      widget.onReject();
      return;
    }
    if (_isReviewStep) {
      widget.onSubmit(_buildAnswers());
      return;
    }
    _goToNextStep();
  }

  void _invokeBackAction() {
    if (widget.busy) {
      return;
    }
    if (_showRejectedState) {
      _reopenRejectedQuestion();
      return;
    }
    _goToPreviousStep();
  }

  void _invokeRejectAction() {
    if (widget.busy) {
      return;
    }
    if (_showRejectedState) {
      // Alt+R toggles reject mode, so pressing it again reopens the wizard.
      _reopenRejectedQuestion();
      return;
    }
    _showRejectState();
  }

  Widget _wrapWithKeyboardNavigation(Widget child) {
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.arrowRight, alt: true):
              _QuestionPrimaryIntent(),
          SingleActivator(LogicalKeyboardKey.enter, alt: true):
              _QuestionPrimaryIntent(),
          SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true):
              _QuestionBackIntent(),
          SingleActivator(LogicalKeyboardKey.keyR, alt: true):
              _QuestionRejectIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            _QuestionPrimaryIntent: CallbackAction<_QuestionPrimaryIntent>(
              onInvoke: (_) {
                _invokePrimaryAction();
                return null;
              },
            ),
            _QuestionBackIntent: CallbackAction<_QuestionBackIntent>(
              onInvoke: (_) {
                _invokeBackAction();
                return null;
              },
            ),
            _QuestionRejectIntent: CallbackAction<_QuestionRejectIntent>(
              onInvoke: (_) {
                _invokeRejectAction();
                return null;
              },
            ),
          },
          child: child,
        ),
      ),
    );
  }

  Widget _buildStepProgress(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentStep = (_stepIndex + 1).clamp(1, _totalSteps);
    final progress = currentStep / _totalSteps;
    final label = _isReviewStep
        ? context.l10n.questionStepOfReview(currentStep, _totalSteps)
        : context.l10n.questionStepOfQuestion(currentStep, _totalSteps);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: colorScheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionStep(BuildContext context, int questionIndex) {
    final colorScheme = Theme.of(context).colorScheme;
    final question = widget.request.questions[questionIndex];
    final selected = _selectedByQuestion[questionIndex] ?? const <String>{};

    return Column(
      key: ValueKey<int>(questionIndex),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question.header,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          question.question,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 10),
        for (
          var optionIndex = 0;
          optionIndex < question.options.length;
          optionIndex++
        )
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _QuestionOptionTile(
              autofocus: optionIndex == 0,
              label: question.options[optionIndex].label,
              description: question.options[optionIndex].description,
              selected: selected.contains(question.options[optionIndex].label),
              multiple: question.multiple,
              enabled: !widget.busy,
              onTap: () {
                setState(() {
                  _toggleOption(
                    questionIndex: questionIndex,
                    question: question,
                    label: question.options[optionIndex].label,
                  );
                });
              },
            ),
          ),
        if (question.custom) ...[
          const SizedBox(height: 2),
          TextField(
            enabled: !widget.busy,
            controller: _controllerFor(questionIndex),
            decoration: InputDecoration(
              isDense: true,
              labelText: context.l10n.questionCustomAnswer,
              hintText: context.l10n.questionCommaSeparatedValues,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildReviewStep(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_questionCount == 0) {
      return Column(
        key: const ValueKey<String>('review_empty'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.questionQuestionsProvidedSubmit,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    return Column(
      key: const ValueKey<String>('review_answers'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.questionReviewAnswersSubmitting,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 10),
        for (var index = 0; index < _questionCount; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _QuestionAnswerSummaryTile(
              header: widget.request.questions[index].header,
              question: widget.request.questions[index].question,
              answers: _answersForQuestion(index),
            ),
          ),
      ],
    );
  }

  Widget _buildStepBody(BuildContext context) {
    if (_isReviewStep) {
      return _buildReviewStep(context);
    }
    return _buildQuestionStep(context, _stepIndex);
  }

  Widget _buildCompactRejectedCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey<String>('question_rejected_compact_card'),
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Symbols.info, size: 18, color: colorScheme.onErrorContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.l10n.questionQuestionGroupMarked,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton(
                autofocus: true,
                onPressed: widget.busy ? null : _reopenRejectedQuestion,
                child: Text(context.l10n.permissionReopen),
              ),
              FilledButton(
                onPressed: widget.busy ? null : widget.onReject,
                child: Text(context.l10n.permissionConfirmReject),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    if (_showRejectedState) {
      return const SizedBox.shrink();
    }

    final primaryLabel = _isReviewStep
        ? context.l10n.questionSubmitAnswers
        : _stepIndex + 1 >= _questionCount
        ? context.l10n.questionReviewAnswers
        : context.l10n.chatActionNext;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: [
        TextButton(
          onPressed: widget.busy ? null : _showRejectState,
          child: Text(context.l10n.permissionReject),
        ),
        if (_stepIndex > 0)
          OutlinedButton(
            onPressed: widget.busy ? null : _goToPreviousStep,
            child: Text(context.l10n.permissionBack),
          ),
        FilledButton(
          onPressed: widget.busy
              ? null
              : _isReviewStep
              ? () => widget.onSubmit(_buildAnswers())
              : _goToNextStep,
          child: Text(primaryLabel),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showRejectedState) {
      return _wrapWithKeyboardNavigation(_buildCompactRejectedCard(context));
    }

    final mediaQuery = MediaQuery.of(context);
    final availableHeight =
        (mediaQuery.size.height - mediaQuery.viewInsets.bottom)
            .clamp(220.0, double.infinity)
            .toDouble();
    final isCompact = mediaQuery.size.width < 640;
    final maxCardHeight = (availableHeight * (isCompact ? 0.64 : 0.54))
        .clamp(220.0, 560.0)
        .toDouble();
    final colorScheme = Theme.of(context).colorScheme;
    final normalizedOriginLabel = widget.originBadgeLabel?.trim();
    final originLabel =
        normalizedOriginLabel == null || normalizedOriginLabel.isEmpty
        ? null
        : normalizedOriginLabel;

    final card = Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.25)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxCardHeight),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Symbols.help_outline, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.l10n.questionQuestionRequest,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (originLabel != null)
                  Container(
                    key: ValueKey<String>(
                      'question_request_origin_badge_${widget.request.id}',
                    ),
                    constraints: const BoxConstraints(maxWidth: 160),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer.withValues(
                        alpha: 0.7,
                      ),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.55,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Symbols.support_agent_rounded,
                          size: 12,
                          color: colorScheme.onSecondaryContainer,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            originLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: colorScheme.onSecondaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _buildStepProgress(context),
            const SizedBox(height: 10),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(right: 2),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: _buildStepBody(context),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _buildActionButtons(),
          ],
        ),
      ),
    );
    return _wrapWithKeyboardNavigation(card);
  }
}

class _QuestionOptionTile extends StatefulWidget {
  const _QuestionOptionTile({
    required this.autofocus,
    required this.label,
    required this.description,
    required this.selected,
    required this.multiple,
    required this.enabled,
    required this.onTap,
  });

  final bool autofocus;
  final String label;
  final String description;
  final bool selected;
  final bool multiple;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_QuestionOptionTile> createState() => _QuestionOptionTileState();
}

class _QuestionOptionTileState extends State<_QuestionOptionTile> {
  bool _isFocusHighlighted = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final normalizedDescription = widget.description.trim();
    final hasDescription = normalizedDescription.isNotEmpty;
    final icon = widget.multiple
        ? (widget.selected
              ? Symbols.check_box_rounded
              : Symbols.check_box_outline_blank_rounded)
        : (widget.selected
              ? Symbols.radio_button_checked
              : Symbols.radio_button_unchecked);
    final borderColor = _isFocusHighlighted
        ? colorScheme.primary
        : widget.selected
        ? colorScheme.primary.withValues(alpha: 0.45)
        : colorScheme.outlineVariant.withValues(alpha: 0.55);

    return FocusableActionDetector(
      autofocus: widget.autofocus,
      enabled: widget.enabled,
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.arrowDown): NextFocusIntent(),
        SingleActivator(LogicalKeyboardKey.arrowUp): PreviousFocusIntent(),
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap();
            return null;
          },
        ),
        NextFocusIntent: CallbackAction<NextFocusIntent>(
          onInvoke: (_) {
            FocusScope.of(context).nextFocus();
            return null;
          },
        ),
        PreviousFocusIntent: CallbackAction<PreviousFocusIntent>(
          onInvoke: (_) {
            FocusScope.of(context).previousFocus();
            return null;
          },
        ),
      },
      onShowFocusHighlight: (value) {
        if (_isFocusHighlighted == value) {
          return;
        }
        setState(() {
          _isFocusHighlighted = value;
        });
      },
      mouseCursor: widget.enabled
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: widget.selected
              ? colorScheme.secondaryContainer.withValues(alpha: 0.6)
              : colorScheme.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor,
            width: _isFocusHighlighted ? 1.8 : 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            canRequestFocus: false,
            onTap: widget.enabled ? widget.onTap : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      icon,
                      size: 20,
                      color: widget.selected
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.label,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (hasDescription) ...[
                          const SizedBox(height: 2),
                          Text(
                            normalizedDescription,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuestionAnswerSummaryTile extends StatelessWidget {
  const _QuestionAnswerSummaryTile({
    required this.header,
    required this.question,
    required this.answers,
  });

  final String header;
  final String question;
  final List<String> answers;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            header,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            question,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          if (answers.isEmpty)
            Text(
              context.l10n.questionAnswerSelected,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: answers
                  .map(
                    (answer) => Chip(
                      visualDensity: Theme.of(context).visualDensity,
                      label: Text(answer),
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }
}
