import 'package:flutter/widgets.dart';

/// Conversation display preferences for timeline and composer surfaces.
///
/// Absent in isolated widgets, where math renders and text keeps its scale.
class ChatAppearance extends InheritedWidget {
  const ChatAppearance({
    super.key,
    required this.mathRendering,
    required this.conversationTextScale,
    required super.child,
  });

  final bool mathRendering;
  final double conversationTextScale;

  static ChatAppearance? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ChatAppearance>();

  static bool mathRenderingOf(BuildContext context) =>
      maybeOf(context)?.mathRendering ?? true;

  @override
  bool updateShouldNotify(ChatAppearance oldWidget) =>
      mathRendering != oldWidget.mathRendering ||
      conversationTextScale != oldWidget.conversationTextScale;
}

/// Scales only its subtree by the conversation text size, on top of the
/// inherited (system) scaler.
class ConversationTextScale extends StatelessWidget {
  const ConversationTextScale({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final factor = ChatAppearance.maybeOf(context)?.conversationTextScale ?? 1;
    if (factor == 1) return child;
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(
        textScaler: MultipliedTextScaler(media.textScaler, factor),
      ),
      child: child,
    );
  }
}

/// Multiplies an inherited scaler, keeping platform nonlinear font scaling.
@immutable
class MultipliedTextScaler extends TextScaler {
  const MultipliedTextScaler(this.base, this.factor);

  final TextScaler base;
  final double factor;

  @override
  double scale(double fontSize) => base.scale(fontSize) * factor;

  @override
  double get textScaleFactor => scale(1);

  @override
  bool operator ==(Object other) =>
      other is MultipliedTextScaler &&
      other.base == base &&
      other.factor == factor;

  @override
  int get hashCode => Object.hash(base, factor);
}
