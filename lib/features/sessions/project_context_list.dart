import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../../shared/l10n/l10n_context.dart';
import '../../shared/sessions/server_path.dart';

/// The width of the accent that marks the selected project or session.
const _accentWidth = 3.0;

/// A row of the session list's continuous surface: no card or row-wide
/// fill, only a thin accent along the start edge while [selected].
class AccentedRow extends StatelessWidget {
  const AccentedRow({super.key, required this.selected, required this.child});

  final bool selected;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: BorderDirectional(
        start: BorderSide(
          width: _accentWidth,
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
        ),
      ),
    ),
    child: child,
  );
}

/// A server path on one line that keeps its trailing folders: a path too
/// long for the row loses its start behind an ellipsis. Paths are always
/// left to right, so their separators do not reorder in a right-to-left
/// locale; a screen reader reads the whole path.
class StartEllipsisPath extends StatelessWidget {
  const StartEllipsisPath(this.path, {super.key, this.style});

  final String path;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.merge(this.style);
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        bool fits(String text) {
          final painter = TextPainter(
            text: TextSpan(text: text, style: style),
            textDirection: TextDirection.ltr,
            textScaler: scaler,
            maxLines: 1,
          )..layout();
          final fit = painter.width <= width;
          painter.dispose();
          return fit;
        }

        var shown = path;
        if (width.isFinite && !fits(path)) {
          final characters = path.characters.toList();
          // The fewest leading characters to drop for the rest to fit.
          var low = 1;
          var high = characters.length;
          while (low < high) {
            final middle = (low + high) ~/ 2;
            if (fits('…${characters.sublist(middle).join()}')) {
              high = middle;
            } else {
              low = middle + 1;
            }
          }
          shown = '…${characters.sublist(low).join()}';
        }
        return Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            shown,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.clip,
            textDirection: TextDirection.ltr,
            style: style,
            semanticsLabel: path,
          ),
        );
      },
    );
  }
}

/// One open project of the server: its name, its path, how many
/// conversations it holds and the menu that closes it.
///
/// A tap shows the project. The menu, its trailing button, a long press, a
/// secondary click, the Menu key, Shift+F10 or the semantic action only
/// open the menu; they never switch to the project.
class ProjectContextRow extends StatefulWidget {
  const ProjectContextRow({
    super.key,
    required this.directory,
    required this.active,
    required this.count,
    required this.complete,
    required this.compact,
    required this.onTap,
    required this.onClose,
  });

  final String directory;
  final bool active;

  /// The conversations last read for the project, or null before a read.
  final int? count;

  /// Whether [count] is all of them, not only the first page.
  final bool complete;

  /// Touch spacing for a compact window, denser rows beside the chat.
  final bool compact;
  final VoidCallback? onTap;
  final VoidCallback? onClose;

  @override
  State<ProjectContextRow> createState() => _ProjectContextRowState();
}

class _ProjectContextRowState extends State<ProjectContextRow> {
  final _menu = GlobalKey<PopupMenuButtonState<int>>();

  void _openMenu() => _menu.currentState?.showButtonMenu();

  @override
  Widget build(BuildContext context) {
    final l10n = context.v2L10n;
    final theme = Theme.of(context);
    final directory = widget.directory;
    final name = serverPathName(directory);
    final count = widget.count;
    final menuSize = widget.compact ? 40.0 : 32.0;
    return AccentedRow(
      selected: widget.active,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onSecondaryTapUp: (_) => _openMenu(),
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.contextMenu): _openMenu,
            const SingleActivator(LogicalKeyboardKey.f10, shift: true):
                _openMenu,
          },
          child: Semantics(
            selected: widget.active,
            // The menu holds one entry, so the action does what it says.
            customSemanticsActions: {
              CustomSemanticsAction(label: l10n.chatCloseProject(name)):
                  ?widget.onClose,
            },
            child: InkWell(
              key: ValueKey('project-context-$directory'),
              onTap: widget.onTap,
              onLongPress: _openMenu,
              child: Padding(
                padding: EdgeInsetsDirectional.fromSTEB(
                  12,
                  widget.compact ? 10 : 6,
                  4,
                  widget.compact ? 10 : 6,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: widget.active
                                  ? theme.colorScheme.primary
                                  : null,
                              fontWeight: widget.active
                                  ? FontWeight.w600
                                  : null,
                            ),
                          ),
                          StartEllipsisPath(
                            directory,
                            key: ValueKey('project-path-$directory'),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (count != null)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(start: 8),
                        child: Text(
                          widget.complete ? '$count' : '$count+',
                          key: ValueKey('project-count-$directory'),
                          semanticsLabel: widget.complete
                              ? l10n.projectsSessionCount(count)
                              : l10n.projectsSessionCountAtLeast(count),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    PopupMenuButton<int>(
                      key: _menu,
                      tooltip: l10n.chatCloseProject(name),
                      padding: EdgeInsets.zero,
                      style: IconButton.styleFrom(
                        fixedSize: Size.square(menuSize),
                        minimumSize: Size.square(menuSize),
                        padding: EdgeInsets.zero,
                      ),
                      iconSize: widget.compact ? 22 : 18,
                      icon: const Icon(Icons.more_vert),
                      onSelected: (_) => widget.onClose?.call(),
                      itemBuilder: (context) => [
                        PopupMenuItem<int>(
                          key: ValueKey('project-close-$directory'),
                          value: 0,
                          enabled: widget.onClose != null,
                          child: Text(
                            l10n.chatCloseProject(name),
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One quick-access row of Recent: the session title on one line and a
/// chip with its project, a running mark while it works and the accent
/// when it is the session shown.
class RecentSessionRow extends StatelessWidget {
  const RecentSessionRow({
    super.key,
    required this.row,
    required this.current,
    required this.running,
    required this.emphasized,
    required this.onTap,
  });

  final SessionSummary row;
  final bool current;
  final bool running;

  /// A completed reply not seen yet, within its hour of emphasis.
  final bool emphasized;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.v2L10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final directory = row.info.project?.canonicalDirectory;
    final title = row.info.title.trim().isEmpty
        ? l10n.sessionExportUntitled
        : row.info.title;
    return AccentedRow(
      selected: current,
      child: InkWell(
        key: ValueKey('recent-${row.info.ref.storageKey}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 8, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: current || emphasized ? scheme.primary : null,
                    fontWeight: current || emphasized ? FontWeight.w600 : null,
                  ),
                ),
              ),
              if (running)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 6),
                  child: Icon(
                    Icons.sync,
                    key: ValueKey('recent-running-${row.info.ref.storageKey}'),
                    size: 14,
                    color: scheme.secondary,
                    semanticLabel: l10n.liveRunning,
                  ),
                ),
              if (directory != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 6),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 96),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: scheme.outlineVariant),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        child: Text(
                          serverPathName(directory),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
