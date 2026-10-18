/// Bounded budget for rich message rendering in v2 timeline.
///
/// Mirrors the legacy `_maxMarkdownCharsForRichRender` guard without
/// importing legacy code. Rich parsing is capped to keep 2,000-item
/// histories and streaming bursts within frame budgets.
class RenderDecision {
  const RenderDecision._(this.kind, this.truncatedChars);
  final RenderDecisionKind kind;
  final int truncatedChars;
}

enum RenderDecisionKind { rich, plainTruncated, empty }

/// Pure budget constants for canonical rich rendering (V2-071A).
class MessageRenderBudget {
  MessageRenderBudget._();

  /// Maximum source runes eligible for rich Markdown parsing.
  /// Above this, callers fall back to plain truncated text.
  static const int richRenderMaxChars = 64000;

  /// Maximum chars for syntax-highlighted fenced blocks.
  /// Larger blocks render as plain monospace to protect frame times.
  static const int codeHighlightMaxChars = 8000;

  /// Maximum lines for plain fallback bodies.
  static const int plainFallbackMaxLines = 16;

  /// Maximum height for bounded code containers.
  static const double maxCodeBlockHeight = 480;

  /// Codepoint-safe decision for [source].
  static RenderDecision decide(String source) {
    if (source.trim().isEmpty) {
      return const RenderDecision._(RenderDecisionKind.empty, 0);
    }
    final runeCount = source.runes.length;
    if (runeCount > richRenderMaxChars) {
      return RenderDecision._(
        RenderDecisionKind.plainTruncated,
        runeCount - richRenderMaxChars,
      );
    }
    return const RenderDecision._(RenderDecisionKind.rich, 0);
  }
}
