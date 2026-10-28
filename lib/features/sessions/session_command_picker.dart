import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../shared/l10n/generated/v2_localizations.dart';
import '../../shared/l10n/l10n_context.dart';
import 'session_builtin_commands.dart';

/// The `/` picker of one composer field (#137): open while the field holds
/// only `/` and a word, over the commands that match it. Up and Down move
/// the highlight, Enter or Tab runs it, and Escape closes the picker until
/// the text changes, giving the field its own keys back.
class SessionCommandMenu extends ChangeNotifier {
  SessionCommandMenu(this.text) {
    text.addListener(_changed);
    _changed();
  }

  final TextEditingController text;
  String? _query;
  String? _closedFor;
  int _active = 0;

  /// The text after the `/` while the picker is open, else null.
  String? get query => _query;

  /// The highlighted command's place among the matches.
  int get active => _active;

  void _changed() {
    if (_closedFor != null && _closedFor != text.text) _closedFor = null;
    final query = _closedFor == null ? sessionCommandQuery(text.value) : null;
    if (query == _query) return;
    _query = query;
    _active = 0;
    notifyListeners();
  }

  /// The matches the open picker shows, else none.
  List<SessionBuiltinCommand> commands(V2Localizations l10n) {
    final query = _query;
    return query == null ? const [] : sessionCommandSuggestions(query, l10n);
  }

  /// Closes the picker until the text changes.
  void close() {
    if (_query == null) return;
    _closedFor = text.text;
    _query = null;
    notifyListeners();
  }

  /// Handles [event] while the picker shows matches; [run] receives the
  /// command Enter or Tab picks. Other keys, and keys with a modifier other
  /// than none, stay the field's.
  KeyEventResult handleKey(
    KeyEvent event,
    V2Localizations l10n,
    ValueChanged<SessionBuiltinCommand> run,
  ) {
    final commands = this.commands(l10n);
    final keyboard = HardwareKeyboard.instance;
    if (commands.isEmpty ||
        event is KeyUpEvent ||
        keyboard.isControlPressed ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed ||
        keyboard.isShiftPressed) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowUp) {
      final step = key == LogicalKeyboardKey.arrowDown ? 1 : -1;
      _active = (min(_active, commands.length - 1) + step) % commands.length;
      notifyListeners();
      return KeyEventResult.handled;
    }
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.tab) {
      run(commands[min(_active, commands.length - 1)]);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      close();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    text.removeListener(_changed);
    super.dispose();
  }
}

/// The open [menu]'s matches above the field, in a list of bounded height
/// that scrolls, so an open keyboard never pushes the field away (#278).
/// A tap runs a command as Enter does.
class SessionCommandPicker extends StatefulWidget {
  const SessionCommandPicker({
    super.key,
    required this.menu,
    required this.onRun,
    this.maxHeight = double.infinity,
  });

  final SessionCommandMenu menu;
  final ValueChanged<SessionBuiltinCommand> onRun;

  /// The room the composer leaves above its field; a keyboard-reduced
  /// composer clips anything taller, highlighted command included.
  final double maxHeight;

  @override
  State<SessionCommandPicker> createState() => _SessionCommandPickerState();
}

class _SessionCommandPickerState extends State<SessionCommandPicker> {
  final _scroll = ScrollController();
  final _tiles = {
    for (final command in SessionBuiltinCommand.values) command: GlobalKey(),
  };

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Scrolls the list just enough to show [command], leaving the page and
  /// the composer where they are.
  void _reveal(SessionBuiltinCommand command) {
    final box = _tiles[command]!.currentContext?.findRenderObject();
    if (box == null || !_scroll.hasClients) return;
    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport == null) return;
    final position = _scroll.position;
    final top = viewport.getOffsetToReveal(box, 0).offset;
    final bottom = viewport.getOffsetToReveal(box, 1).offset;
    final target = position.pixels
        .clamp(min(bottom, top), max(bottom, top))
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if (target != position.pixels) _scroll.jumpTo(target);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.menu,
    builder: (context, _) {
      final l10n = context.v2L10n;
      final commands = widget.menu.commands(l10n);
      if (commands.isEmpty) return const SizedBox.shrink();
      final active = commands[min(widget.menu.active, commands.length - 1)];
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _reveal(active);
      });
      final scheme = Theme.of(context).colorScheme;
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Semantics(
          container: true,
          label: l10n.commandsTitle,
          child: Material(
            key: const ValueKey('live-command-picker'),
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: max(
                  0,
                  min(
                    min(240, MediaQuery.sizeOf(context).height * 0.3),
                    widget.maxHeight,
                  ),
                ),
              ),
              child: ListView(
                controller: _scroll,
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  for (final command in commands)
                    KeyedSubtree(
                      key: _tiles[command],
                      child: SessionCommandTile(
                        key: ValueKey('live-command-${command.name}'),
                        command: command,
                        selected: command == active,
                        onTap: () => widget.onRun(command),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Reports its child's height after each layout that changed it, so the
/// picker above a composer field leaves that field whole (#278).
class SessionFieldHeightReporter extends SingleChildRenderObjectWidget {
  const SessionFieldHeightReporter({
    super.key,
    required this.onHeight,
    super.child,
  });

  final ValueChanged<double> onHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _HeightReporterBox(onHeight);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) =>
      (renderObject as _HeightReporterBox).onHeight = onHeight;
}

class _HeightReporterBox extends RenderProxyBox {
  _HeightReporterBox(this.onHeight);

  ValueChanged<double> onHeight;
  double? _reported;

  @override
  void performLayout() {
    super.performLayout();
    final height = size.height;
    if (height == _reported) return;
    _reported = height;
    // A layout cannot rebuild its ancestors; the next frame takes it.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (attached) onHeight(height);
    });
  }
}
