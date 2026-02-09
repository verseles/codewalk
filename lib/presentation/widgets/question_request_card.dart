import 'package:flutter/material.dart';

import '../../domain/entities/chat_realtime.dart';

class QuestionRequestCard extends StatefulWidget {
  const QuestionRequestCard({
    super.key,
    required this.request,
    required this.busy,
    required this.onSubmit,
    required this.onReject,
  });

  final ChatQuestionRequest request;
  final bool busy;
  final ValueChanged<List<List<String>>> onSubmit;
  final VoidCallback onReject;

  @override
  State<QuestionRequestCard> createState() => _QuestionRequestCardState();
}

class _QuestionRequestCardState extends State<QuestionRequestCard> {
  final Map<int, Set<String>> _selectedByQuestion = <int, Set<String>>{};
  final Map<int, TextEditingController> _customByQuestion =
      <int, TextEditingController>{};

  @override
  void dispose() {
    for (final controller in _customByQuestion.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(int index) {
    return _customByQuestion.putIfAbsent(index, TextEditingController.new);
  }

  List<List<String>> _buildAnswers() {
    final output = <List<String>>[];
    for (var i = 0; i < widget.request.questions.length; i++) {
      final selected = <String>{...(_selectedByQuestion[i] ?? <String>{})};
      final custom = _customByQuestion[i]?.text ?? '';
      final customTokens = custom
          .split(',')
          .map((token) => token.trim())
          .where((token) => token.isNotEmpty);
      selected.addAll(customTokens);
      output.add(selected.toList(growable: false));
    }
    return output;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withOpacity(0.22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.primary.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.help_outline, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Question request',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...List<Widget>.generate(widget.request.questions.length, (index) {
            final question = widget.request.questions[index];
            final selected = _selectedByQuestion[index] ?? <String>{};
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${question.header}: ${question.question}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: question.options
                        .map((option) {
                          return FilterChip(
                            label: Text(option.label),
                            selected: selected.contains(option.label),
                            onSelected: widget.busy
                                ? null
                                : (enabled) {
                                    setState(() {
                                      final current = _selectedByQuestion
                                          .putIfAbsent(index, () => <String>{});
                                      if (question.multiple) {
                                        if (enabled) {
                                          current.add(option.label);
                                        } else {
                                          current.remove(option.label);
                                        }
                                      } else {
                                        current.clear();
                                        if (enabled) {
                                          current.add(option.label);
                                        }
                                      }
                                    });
                                  },
                          );
                        })
                        .toList(growable: false),
                  ),
                  if (question.custom) ...[
                    const SizedBox(height: 8),
                    TextField(
                      enabled: !widget.busy,
                      controller: _controllerFor(index),
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: 'Custom answer (comma separated)',
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: widget.busy ? null : widget.onReject,
                child: const Text('Reject'),
              ),
              FilledButton(
                onPressed: widget.busy
                    ? null
                    : () => widget.onSubmit(_buildAnswers()),
                child: const Text('Submit Answers'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
