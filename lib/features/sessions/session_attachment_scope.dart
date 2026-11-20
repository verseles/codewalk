import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/widgets.dart';

/// Supplies the active session's [AttachmentFacet] to timeline tiles in both
/// live sessions and read-only history without threading extra callbacks
/// through intermediate layout widgets.
class SessionAttachmentScope extends InheritedWidget {
  const SessionAttachmentScope({
    super.key,
    required this.facet,
    required super.child,
  });

  final AttachmentFacet? facet;

  static AttachmentFacet? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<SessionAttachmentScope>()
      ?.facet;

  @override
  bool updateShouldNotify(SessionAttachmentScope oldWidget) =>
      !identical(facet, oldWidget.facet);
}
