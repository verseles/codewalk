import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/i18n/l10n_context.dart';
import '../../core/logging/app_logger.dart';
import '../../domain/entities/project.dart';

class ProjectContextMenuRegion extends StatelessWidget {
  const ProjectContextMenuRegion({
    super.key,
    required this.project,
    required this.displayName,
    required this.onCloseProject,
    required this.child,
  });

  final Project project;
  final String displayName;
  final Future<void> Function() onCloseProject;
  final Widget child;

  Future<void> _showMenu(BuildContext context, Offset globalPosition, {bool haptic = false}) async {
    if (haptic) {
      unawaited(HapticFeedback.mediumImpact());
    }
    AppLogger.debug('project_context_menu_open surface=project-row id=${project.id}');
    final overlay = Overlay.of(context).context.findRenderObject();
    if (overlay is! RenderBox) return;
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem<String>(
          value: 'close',
          child: Row(
            children: [
              Icon(Symbols.close, color: Theme.of(context).colorScheme.error, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  context.l10n.workspaceCloseProject(displayName),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
    if (selected == 'close') {
      await onCloseProject();
    }
  }

  Offset _center(BuildContext context) {
    final ro = context.findRenderObject();
    if (ro is RenderBox) {
      return ro.localToGlobal(ro.size.center(Offset.zero));
    }
    return Offset.zero;
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (innerContext) {
        return CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.contextMenu): () => unawaited(_showMenu(innerContext, _center(innerContext))),
            const SingleActivator(LogicalKeyboardKey.f10, shift: true): () => unawaited(_showMenu(innerContext, _center(innerContext))),
          },
          child: Semantics(
            customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
              CustomSemanticsAction(label: innerContext.l10n.workspaceCloseProject(displayName)): () =>
                  unawaited(_showMenu(innerContext, _center(innerContext))),
            },
            onLongPress: () => unawaited(_showMenu(innerContext, _center(innerContext), haptic: true)),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onSecondaryTapUp: (details) => unawaited(_showMenu(innerContext, details.globalPosition)),
              onLongPressStart: (details) => unawaited(_showMenu(innerContext, details.globalPosition, haptic: true)),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
