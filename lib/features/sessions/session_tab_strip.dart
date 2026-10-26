import 'dart:async';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_keyboard_shortcuts.dart';
import '../../platform/sessions/session_tabs_store.dart';
import '../../shared/l10n/l10n_context.dart';
import '../../shared/shortcuts/shortcut_action.dart';
import 'session_tabs_controller.dart';
import 'sessions_controller.dart';

/// The route of the session of [ref].
String sessionTabLocation(SessionRef ref) =>
    Uri(pathSegments: ['', 's', ref.host.value, ref.nativeId]).toString();

/// The open session with its tabs above it: the tabs of its project, a way
/// to the recent tabs of its server, and the keys that switch and close
/// them.
class SessionTabsFrame extends StatefulWidget {
  const SessionTabsFrame({
    super.key,
    required this.tabs,
    required this.current,
    required this.project,
    required this.child,
  });

  final SessionTabsController tabs;

  /// The session of the route.
  final SessionRef current;

  /// The project whose tabs show when the route's session has no tab.
  final ProjectRef? project;
  final Widget child;

  @override
  State<SessionTabsFrame> createState() => _SessionTabsFrameState();
}

class _SessionTabsFrameState extends State<SessionTabsFrame>
    with WidgetsBindingObserver {
  /// The candidates of an open switcher, frozen while it is open.
  List<SessionTab>? _switcher;
  int _highlight = 0;

  SessionTab? get _tab =>
      widget.tabs.tabs.where((tab) => tab.ref == widget.current).firstOrNull;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(SessionTabsFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Another session is shown: a switcher opened over the last one ends.
    if (oldWidget.current != widget.current) _finishSwitcher(commit: false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A window left while Ctrl is held may never see its release.
    if (state != AppLifecycleState.resumed) _finishSwitcher(commit: false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_switcherKeys);
    super.dispose();
  }

  void _activate(SessionRef ref) {
    // A tab chosen another way ends the switcher, so its release opens
    // nothing else.
    _finishSwitcher(commit: false);
    if (ref == widget.current) return;
    context.go(sessionTabLocation(ref));
  }

  Future<void> _close(SessionTab tab) async {
    final tabs = widget.tabs;
    final index = tabs.tabs.indexOf(tab);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = context.v2L10n;
    final title = _title(context, tab);
    final (:removed, :next, :unpinned) = await tabs.close(tab.ref);
    // Another close, or the server dropping it, got there first.
    if (!removed) return;
    String location() =>
        router.routerDelegate.currentConfiguration.uri.toString();
    // Whatever the route shows now decides: navigating away meanwhile wins
    // over the neighbour, and a tab shown since (the neighbour of another
    // close, say) is left as well.
    String? left;
    if (location() == sessionTabLocation(tab.ref)) {
      final target = tabs.tabs.any((other) => other.ref == next) ? next : null;
      left = target == null ? '/sessions' : sessionTabLocation(target);
      router.go(left);
    }
    messenger
      ?..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            l10n.sessionTabClosedMessage(title),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: l10n.sessionTabUndo,
            onPressed: () async {
              // The tab comes back in place, and is shown again only while
              // the reader is still where its close took them, once it is
              // saved: a move meanwhile wins. Showing it selects it. A tab
              // the close unpinned is pinned again first.
              if (!await tabs.reopen(
                tab,
                index: index,
                select: false,
                pin: unpinned,
              )) {
                return;
              }
              if (left != null && location() == left) {
                router.go(sessionTabLocation(tab.ref));
              }
            },
          ),
        ),
      );
  }

  void _cycle({required bool reverse}) {
    final open = _switcher;
    if (open != null) {
      setState(() {
        _highlight = (_highlight + (reverse ? -1 : 1)) % open.length;
      });
      return;
    }
    final recent = widget.tabs.recent(widget.current.host);
    if (recent.length < 2) return;
    final start = reverse ? recent.length - 1 : 1;
    // A binding without Ctrl has no release to wait for: it switches at once.
    if (!HardwareKeyboard.instance.isControlPressed) {
      _activate(recent[start].ref);
      return;
    }
    HardwareKeyboard.instance.addHandler(_switcherKeys);
    setState(() {
      _switcher = recent;
      _highlight = start;
    });
  }

  /// Releasing Ctrl switches; Escape cancels; Tab held down keeps cycling.
  bool _switcherKeys(KeyEvent event) {
    if (_switcher == null) return false;
    final key = event.logicalKey;
    if (event is KeyRepeatEvent && key == LogicalKeyboardKey.tab) {
      _cycle(reverse: HardwareKeyboard.instance.isShiftPressed);
      return true;
    }
    if (event is KeyUpEvent &&
        (key == LogicalKeyboardKey.controlLeft ||
            key == LogicalKeyboardKey.controlRight) &&
        !HardwareKeyboard.instance.isControlPressed) {
      _finishSwitcher(commit: true);
      return true;
    }
    if (event is KeyDownEvent) {
      if (key == LogicalKeyboardKey.escape) {
        _finishSwitcher(commit: false);
        return true;
      }
    }
    return false;
  }

  void _finishSwitcher({required bool commit}) {
    final open = _switcher;
    HardwareKeyboard.instance.removeHandler(_switcherKeys);
    if (open == null || !mounted) return;
    final chosen = open[_highlight].ref;
    setState(() => _switcher = null);
    if (commit && widget.tabs.tabs.any((tab) => tab.ref == chosen)) {
      _activate(chosen);
    }
  }

  Future<void> _showRecent() async {
    // The sheet replaces a switcher open over it.
    _finishSwitcher(commit: false);
    final recent = widget.tabs.recent(widget.current.host);
    final chosen = await showModalBottomSheet<SessionRef>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          key: const ValueKey('session-tabs-recent'),
          shrinkWrap: true,
          children: [
            ListTile(title: Text(context.v2L10n.sessionTabSwitcherTitle)),
            for (final tab in recent)
              ListTile(
                key: ValueKey('session-tabs-recent-${tab.ref.storageKey}'),
                selected: tab.ref == widget.current,
                title: Text(
                  _title(context, tab),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => Navigator.of(context).pop(tab.ref),
              ),
          ],
        ),
      ),
    );
    if (chosen != null && mounted) _activate(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final tab = _tab;
    final project = tab == null ? widget.project : tab.project;
    final visible = widget.tabs.visible(widget.current.host, project);
    final switcher = _switcher;
    return KeyboardActionScope(
      handlers: {
        ShortcutAction.cycleTabsForward: () => _cycle(reverse: false),
        ShortcutAction.cycleTabsBackward: () => _cycle(reverse: true),
        if (tab != null) ShortcutAction.closeApp: () => unawaited(_close(tab)),
      },
      // Keeps the keyboard inside the session when nothing in it has the
      // focus, so the tab keys reach this scope.
      child: Focus(
        autofocus: true,
        skipTraversal: true,
        child: Column(
          children: [
            if (visible.isNotEmpty)
              SafeArea(
                bottom: false,
                child: _Strip(
                  tabs: visible,
                  current: widget.current,
                  onActivate: _activate,
                  onClose: (tab) => unawaited(_close(tab)),
                  onRecent: _showRecent,
                ),
              ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    // The strip already keeps clear of the status bar.
                    child: MediaQuery.removePadding(
                      context: context,
                      removeTop: visible.isNotEmpty,
                      child: widget.child,
                    ),
                  ),
                  if (switcher != null)
                    _Switcher(tabs: switcher, highlight: _highlight),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _title(BuildContext context, SessionTab tab) =>
    tab.title.trim().isEmpty ? context.v2L10n.sessionExportUntitled : tab.title;

/// One row of tabs, scrolled sideways, with the recent tabs at its end.
class _Strip extends StatefulWidget {
  const _Strip({
    required this.tabs,
    required this.current,
    required this.onActivate,
    required this.onClose,
    required this.onRecent,
  });

  final List<SessionTab> tabs;
  final SessionRef current;
  final ValueChanged<SessionRef> onActivate;
  final ValueChanged<SessionTab> onClose;
  final VoidCallback onRecent;

  @override
  State<_Strip> createState() => _StripState();
}

class _StripState extends State<_Strip> {
  final _shown = GlobalKey();

  @override
  void initState() {
    super.initState();
    _reveal();
  }

  @override
  void didUpdateWidget(_Strip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.current != widget.current) _reveal();
  }

  /// Scrolls the shown tab into view, after a switch from the keys or the
  /// sheet say.
  void _reveal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _shown.currentContext;
      if (mounted && target != null) Scrollable.ensureVisible(target);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.v2L10n;
    final scheme = Theme.of(context).colorScheme;
    final widget = this.widget;
    return Material(
      key: const ValueKey('session-tabs'),
      color: scheme.surfaceContainer,
      child: Semantics(
        label: l10n.chatSessionTabsToggle,
        container: true,
        child: Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsetsDirectional.only(start: 4),
                child: Row(
                  children: [
                    for (final tab in widget.tabs)
                      _Tab(
                        key: tab.ref == widget.current ? _shown : null,
                        tab: tab,
                        selected: tab.ref == widget.current,
                        onTap: () => widget.onActivate(tab.ref),
                        onClose: () => widget.onClose(tab),
                      ),
                  ],
                ),
              ),
            ),
            IconButton(
              key: const ValueKey('session-tabs-recent-button'),
              tooltip: l10n.sessionTabSwitcherTitle,
              icon: const Icon(Icons.swap_horiz),
              onPressed: widget.onRecent,
            ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    super.key,
    required this.tab,
    required this.selected,
    required this.onTap,
    required this.onClose,
  });

  final SessionTab tab;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = _title(context, tab);
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 4, top: 4, bottom: 4),
      child: Material(
        key: ValueKey('session-tab-${tab.ref.storageKey}'),
        color: selected ? scheme.secondaryContainer : Colors.transparent,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Semantics(
            selected: selected,
            button: true,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220, minHeight: 48),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(start: 12),
                      child: Tooltip(
                        message: title,
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selected
                                ? scheme.onSecondaryContainer
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    key: ValueKey('session-tab-close-${tab.ref.storageKey}'),
                    tooltip: context.v2L10n.chatClose,
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: onClose,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The recent tabs while Ctrl is held; the highlighted one opens on release.
class _Switcher extends StatefulWidget {
  const _Switcher({required this.tabs, required this.highlight});

  final List<SessionTab> tabs;
  final int highlight;

  @override
  State<_Switcher> createState() => _SwitcherState();
}

class _SwitcherState extends State<_Switcher> {
  final _highlighted = GlobalKey();

  @override
  void initState() {
    super.initState();
    _reveal();
  }

  @override
  void didUpdateWidget(_Switcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.highlight != widget.highlight) _reveal();
  }

  /// Keeps the highlighted tab in view, so a release opens a visible one.
  void _reveal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _highlighted.currentContext;
      if (mounted && target != null) {
        Scrollable.ensureVisible(target, alignment: 0.5);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.v2L10n;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360, maxHeight: 420),
        child: Card(
          key: const ValueKey('session-tab-switcher'),
          elevation: 8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(l10n.sessionTabSwitcherTitle),
                subtitle: Text(l10n.sessionTabSwitcherHint),
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final (i, tab) in widget.tabs.indexed)
                        ListTile(
                          key: i == widget.highlight ? _highlighted : null,
                          selected: i == widget.highlight,
                          title: Text(
                            _title(context, tab),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
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

/// The workspace's tab events outside an open session: the notice of the
/// tabs whose sessions no longer exist, and, when the app opens on the list,
/// the return to the tab used last.
class SessionTabsWatcher extends StatefulWidget {
  const SessionTabsWatcher({
    super.key,
    required this.tabs,
    required this.catalog,
    required this.home,
    required this.child,
  });

  final SessionTabsController tabs;
  final SessionsController? catalog;

  /// Whether the workspace shows the list, not a session.
  final bool home;
  final Widget child;

  @override
  State<SessionTabsWatcher> createState() => _SessionTabsWatcherState();
}

class _SessionTabsWatcherState extends State<SessionTabsWatcher> {
  @override
  void initState() {
    super.initState();
    widget.tabs.addListener(_changed);
    widget.catalog?.hosts.addListener(_changed);
    // Usually read before the first frame already; the read is shared.
    unawaited(widget.tabs.initialize());
    WidgetsBinding.instance.addPostFrameCallback((_) => _changed());
  }

  @override
  void didUpdateWidget(SessionTabsWatcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tabs != widget.tabs) {
      oldWidget.tabs.removeListener(_changed);
      widget.tabs.addListener(_changed);
    }
    if (oldWidget.catalog != widget.catalog) {
      oldWidget.catalog?.hosts.removeListener(_changed);
      widget.catalog?.hosts.addListener(_changed);
    }
    // A link to a session opened the app: the launch tab is spent.
    if (!widget.home) widget.tabs.takeLaunchTab();
  }

  @override
  void dispose() {
    widget.tabs.removeListener(_changed);
    widget.catalog?.hosts.removeListener(_changed);
    // Leaving the workspace before the launch tab opened spends it, so a
    // later return to the list stays there.
    widget.tabs.takeLaunchTab();
    super.dispose();
  }

  /// The notice on screen; tabs dropped while it shows join it.
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _notice;

  void _changed() {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    // Tabs dropped while a notice shows wait for it to close.
    if (messenger != null &&
        _notice == null &&
        widget.tabs.takeRemoved().isNotEmpty) {
      final notice = _notice = messenger.showSnackBar(
        SnackBar(content: Text(context.v2L10n.sessionTabsRemoved)),
      );
      notice.closed.whenComplete(() {
        if (!identical(_notice, notice)) return;
        _notice = null;
        _changed();
      });
    }
    _launch();
  }

  void _launch() {
    if (!widget.home) {
      widget.tabs.takeLaunchTab();
      return;
    }
    final hosts = widget.catalog?.hosts;
    // Waits for the saved tabs and servers, so a removed server's tab is
    // pruned before it could be shown.
    if (!widget.tabs.loaded || hosts == null || !hosts.loaded) return;
    if (hosts.loading) return;
    final tab = widget.tabs.takeLaunchTab();
    if (tab != null && hosts.profiles.any((p) => p.id == tab.host.value)) {
      context.go(sessionTabLocation(tab));
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
