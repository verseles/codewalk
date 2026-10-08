import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../shared/shortcuts/shortcut_action.dart';
import '../shared/shortcuts/shortcut_binding_codec.dart';
import 'app_preferences_controller.dart';

class AppShortcutIntent extends Intent {
  const AppShortcutIntent(this.action);
  final ShortcutAction action;
}

/// Features register only actions they can actually perform in this subtree.
class KeyboardActionScope extends StatelessWidget {
  const KeyboardActionScope({
    super.key,
    required this.handlers,
    required this.child,
  });

  final Map<ShortcutAction, VoidCallback> handlers;
  final Widget child;

  static bool isAvailable(BuildContext context, ShortcutAction action) =>
      context
          .dependOnInheritedWidgetOfExactType<_KeyboardHandlers>()
          ?.handlers
          .containsKey(action) ??
      false;

  @override
  Widget build(BuildContext context) {
    final inherited = context
        .dependOnInheritedWidgetOfExactType<_KeyboardHandlers>();
    final combined = Map<ShortcutAction, VoidCallback>.unmodifiable({
      ...?inherited?.handlers,
      ...handlers,
    });
    return _KeyboardHandlers(
      handlers: combined,
      child: Actions(
        actions: {AppShortcutIntent: _RoutingAction(combined)},
        child: child,
      ),
    );
  }
}

class _KeyboardHandlers extends InheritedWidget {
  const _KeyboardHandlers({required this.handlers, required super.child});
  final Map<ShortcutAction, VoidCallback> handlers;

  @override
  bool updateShouldNotify(_KeyboardHandlers oldWidget) =>
      !identical(handlers, oldWidget.handlers);
}

class _RoutingAction extends ContextAction<AppShortcutIntent> {
  _RoutingAction(this.handlers);
  final Map<ShortcutAction, VoidCallback> handlers;

  @override
  bool isEnabled(AppShortcutIntent intent, [BuildContext? context]) {
    if (!handlers.containsKey(intent.action) || context == null) return false;
    final route = ModalRoute.of(context);
    if (route is PopupRoute || (route != null && !route.isCurrent)) {
      return false;
    }
    final editor = context.findAncestorStateOfType<EditableTextState>();
    if (editor != null) {
      final composing = editor.widget.controller.value.composing;
      if (composing.isValid && !composing.isCollapsed) return false;
      final keyboard = HardwareKeyboard.instance;
      // Preserve ordinary typing, AltGraph and editor-local shortcuts.
      if ((!keyboard.isControlPressed && !keyboard.isMetaPressed) ||
          (keyboard.isControlPressed &&
              keyboard.isAltPressed &&
              !keyboard.isMetaPressed)) {
        return false;
      }
    }
    return true;
  }

  @override
  Object? invoke(AppShortcutIntent intent, [BuildContext? context]) {
    if (isEnabled(intent, context)) handlers[intent.action]!();
    return null;
  }
}

/// One key manager; scoped Actions supply handlers without global invokers.
class AppKeyboardShortcuts extends StatefulWidget {
  const AppKeyboardShortcuts({
    super.key,
    required this.preferences,
    required this.openSettings,
    required this.child,
  });

  final AppPreferencesController preferences;
  final VoidCallback openSettings;
  final Widget child;

  @override
  State<AppKeyboardShortcuts> createState() => _AppKeyboardShortcutsState();
}

class _AppKeyboardShortcutsState extends State<AppKeyboardShortcuts> {
  final _focus = FocusNode(debugLabel: 'v2 keyboard fallback');
  final _manager = _AppShortcutManager();

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_observeKeyboard);
  }

  bool _observeKeyboard(KeyEvent event) {
    if (event is KeyDownEvent && !event.synthesized) {
      widget.preferences.observePhysicalKeyboard();
    }
    return false;
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_observeKeyboard);
    _manager.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.preferences;
    final bindings = <ShortcutActivator, Intent>{};
    for (final action in ShortcutAction.values) {
      final binding = p.shortcutBindingFor(action);
      final activator = ShortcutBindingCodec.parse(binding);
      if (activator != null && p.shortcutConflict(action, binding) == null) {
        bindings[activator] = AppShortcutIntent(action);
      }
    }
    _manager.shortcuts = bindings;
    return KeyboardActionScope(
      handlers: {ShortcutAction.openSettings: widget.openSettings},
      child: Shortcuts.manager(
        manager: _manager,
        child: Focus(
          focusNode: _focus,
          autofocus: true,
          skipTraversal: true,
          child: widget.child,
        ),
      ),
    );
  }
}

class _AppShortcutManager extends ShortcutManager {
  @override
  KeyEventResult handleKeypress(BuildContext context, KeyEvent event) =>
      event is KeyDownEvent && !event.synthesized
      ? super.handleKeypress(context, event)
      : KeyEventResult.ignored;
}
