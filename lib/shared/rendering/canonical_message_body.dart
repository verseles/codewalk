import 'package:flutter/material.dart';

import '../l10n/l10n_context.dart';
import 'markdown_content.dart';
import 'message_render_budget.dart';
import 'render_stream_throttle.dart';

/// Canonical-bound rich body for v2 timeline items (V2-071A).
///
/// Binds only to plain source strings from canonical `TimelineItem`s:
/// - `UserInput` → rich without basic HTML (raw tags stay literal)
/// - `AssistantText`/`Reasoning` → rich with basic HTML
/// - Over-budget (>64k runes) → plain truncated text + localized notice
/// - Empty → `SizedBox.shrink()`
/// The `prefixMissing` ellipsis (`…`) is rendered outside the parsed source,
/// never fed to the parser. Tool/shell/notice/outcome/unknown markers stay
/// minimized in the tile and never use this widget.
class CanonicalMessageBody extends StatelessWidget {
  const CanonicalMessageBody({
    super.key,
    required this.source,
    required this.complete,
    this.prefixMissing = false,
    this.allowBasicHtml = true,
    this.onTapLink,
    this.onTapFilePath,
    this.onCopyCode,
  });

  final String source;
  final bool complete;
  final bool prefixMissing;
  final bool allowBasicHtml;
  final void Function(String text, String href, String? title)? onTapLink;
  final void Function(String path, int? line, int? col)? onTapFilePath;
  final ValueChanged<String>? onCopyCode;

  Widget _rich(BuildContext context, String verbatimSource) {
    return MarkdownContent(
      source: verbatimSource,
      allowBasicHtml: allowBasicHtml,
      enableMath: true,
      enableMermaid: true,
      enableCodeHighlight: true,
      onLink: onTapLink != null
          ? (text, href, title) => onTapLink!(text, href, title)
          : null,
      onFile: onTapFilePath != null
          ? (match) => onTapFilePath!(
              match.path,
              match.lineNumber,
              match.columnNumber,
            )
          : null,
      onCopyCode: onCopyCode,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.v2L10n;
    final decision = MessageRenderBudget.decide(source);
    switch (decision.kind) {
      case RenderDecisionKind.empty:
        return const SizedBox.shrink();
      case RenderDecisionKind.plainTruncated:
        final truncated = String.fromCharCodes(
          source.runes.take(MessageRenderBudget.richRenderMaxChars),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${prefixMissing ? '…' : ''}$truncated',
              maxLines: MessageRenderBudget.plainFallbackMaxLines,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.chatMessageLargeMessageTruncated,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              l10n.chatMessageTruncatedChars(
                decision.truncatedChars,
                '',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
      case RenderDecisionKind.rich:
        final platform = Theme.of(context).platform;
        final isDesktop =
            platform != TargetPlatform.android &&
            platform != TargetPlatform.iOS;
        Widget body;
        if (!complete) {
          body = RenderStreamThrottle(
            text: source,
            complete: complete,
            isDesktop: isDesktop,
            builder: (rendered) => _rich(context, rendered),
          );
        } else {
          body = _rich(context, source);
        }
        if (!prefixMissing) return body;
        // Ellipsis outside the parser so line-leading block constructs
        // (#, -, >, |, ```, $$) still parse.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('…', maxLines: 1, overflow: TextOverflow.clip),
            body,
          ],
        );
    }
  }
}
