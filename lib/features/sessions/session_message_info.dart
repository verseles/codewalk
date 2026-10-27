import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../shared/l10n/l10n_context.dart';
import '../../shared/theme/app_shapes.dart';
import '../../shared/theme/app_visual_style_tokens.dart';

/// Whether [items] at [index] is the first part of its harness message.
bool opensMessage(List<TimelineItem> items, int index) {
  final message = items[index].meta.message?.message;
  return message != null &&
      (index == 0 || items[index - 1].meta.message?.message != message);
}

/// Compact time from the message's creation to its completion, both as the
/// harness reported them. Null while it runs or when the times disagree.
String? formatMessageElapsed(MessageContext context) {
  final created = context.created;
  final completed = context.completed;
  if (created == null || completed == null) return null;
  final elapsed = completed.difference(created);
  if (elapsed.isNegative) return null;
  if (elapsed.inMilliseconds < 1000) return '${elapsed.inMilliseconds}ms';
  if (elapsed.inSeconds < 60) return '${elapsed.inSeconds}s';
  if (elapsed.inMinutes < 60) {
    final seconds = elapsed.inSeconds % 60;
    return seconds == 0
        ? '${elapsed.inMinutes}m'
        : '${elapsed.inMinutes}m ${seconds}s';
  }
  final minutes = elapsed.inMinutes % 60;
  return minutes == 0
      ? '${elapsed.inHours}h'
      : '${elapsed.inHours}h ${minutes}m';
}

/// The reported token count, only when input and output are both known.
int? _tokenTotal(TokenBreakdown? tokens) {
  if (tokens == null || tokens.input == null || tokens.output == null) {
    return null;
  }
  final total = [
    tokens.input,
    tokens.output,
    tokens.reasoning,
    tokens.cacheRead,
    tokens.cacheWrite,
  ].whereType<num>().fold<double>(0, (sum, value) => sum + value.toDouble());
  // Summed as doubles: integer parts would wrap on native platforms, and
  // finite parts can still add up past what a count can show.
  return total.isFinite && total <= 9007199254740991 ? total.round() : null;
}

/// The elapsed time of a message's response; it opens the message details.
class MessageElapsedChip extends StatelessWidget {
  const MessageElapsedChip({super.key, required this.message});

  final MessageContext message;

  @override
  Widget build(BuildContext context) {
    final l10n = context.v2L10n;
    final label = formatMessageElapsed(message) ?? '…';
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: l10n.msgInfoMessageInfo,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('message-elapsed-${message.message.value}'),
          onTap: () => showMessageInfoDialog(context, message),
          borderRadius: BorderRadius.circular(12),
          child: Semantics(
            button: true,
            label: '${l10n.msgInfoMessageInfo}: $label',
            excludeSemantics: true,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Symbols.schedule,
                        size: 14,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// What the harness reported about a message, in a bounded dialog that
/// scrolls and closes with its button, the barrier or Escape.
Future<void> showMessageInfoDialog(
  BuildContext context,
  MessageContext message,
) => showDialog<void>(
  context: context,
  builder: (dialogContext) {
    final l10n = dialogContext.v2L10n;
    final tokens = Theme.of(dialogContext).visualStyleTokens;
    return Dialog(
      key: ValueKey('message-info-${message.message.value}'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: tokens.isRefined
            ? tokens.dialogRadius
            : AppShapes.borderLarge,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.msgInfoMessageInfo,
                      style: Theme.of(dialogContext).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('message-info-close'),
                    icon: const Icon(Symbols.close),
                    tooltip: l10n.chatClose,
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _MessageInfoRows(message: message),
              ),
            ),
          ],
        ),
      ),
    );
  },
);

class _MessageInfoRows extends StatelessWidget {
  const _MessageInfoRows({required this.message});

  final MessageContext message;

  @override
  Widget build(BuildContext context) {
    final l10n = context.v2L10n;
    final elapsed = formatMessageElapsed(message);
    final total = _tokenTotal(message.tokens);
    final cost = message.cost?.amount?.toStringAsFixed(6);
    final rows = [
      if (elapsed != null) _row(context, Symbols.schedule, elapsed),
      if (message.modelId case final model?)
        _row(
          context,
          Symbols.psychology,
          l10n.chatMessageModelMessageModelId(model),
        ),
      if (message.modelProviderId case final provider?)
        _row(
          context,
          Symbols.cloud,
          l10n.chatMessageProviderMessageProviderId(provider),
        ),
      if (total != null)
        _row(context, Symbols.token, l10n.msgInfoTokens(total)),
      if (cost != null) _row(context, Symbols.payments, l10n.msgInfoCost(cost)),
    ];
    // A v2 message is one model step: it starts, then ends with a reason.
    final steps = [
      if (message.created != null)
        _row(context, Symbols.play_arrow, l10n.chatMessageStepStarted(1)),
      if (message.finish case final finish? when total != null && cost != null)
        _row(
          context,
          Symbols.check_circle_outline_rounded,
          l10n.chatMessageStepFinished(cost, finish, 1, total),
        ),
    ];
    if (rows.isNotEmpty && steps.isNotEmpty) {
      rows.add(const Divider(height: 16));
    }
    rows.addAll(steps);
    if (rows.isEmpty) {
      rows.add(_row(context, Symbols.info, l10n.chatMessageMetadataAvailable));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: rows,
    );
  }

  Widget _row(BuildContext context, IconData icon, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: SelectableText(
            text,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    ),
  );
}
