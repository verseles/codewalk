import 'dart:async';
import 'dart:math' as math;

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/app_keyboard_shortcuts.dart';
import '../../app/workspace_actions.dart';
import '../../platform/sessions/session_tabs_store.dart';
import '../../platform/sessions/workspace_draft_store.dart';
import '../../shared/l10n/l10n_context.dart';
import '../../shared/shortcuts/shortcut_action.dart';
import '../../shared/widgets/app_snack_bar.dart';
import 'project_contexts_controller.dart';
import 'session_tab_chip.dart';
import 'session_tab_menu.dart';
import 'session_tab_projection.dart';
import 'session_tabs_controller.dart';
import 'sessions_controller.dart';
import 'workspace_draft_controller.dart';

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
  final SessionRef? current;

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
  bool _openingDraft = false;
  final _closing = <SessionRef>{};
  WorkspaceActions? _workspaceActions;

  bool _closeShown() {
    final tab = _tab;
    if (tab == null) return false;
    unawaited(_close(tab));
    return true;
  }

  HostId? get _host {
    final profile = context.read<SessionsController?>()?.selectedProfile;
    return widget.current?.host ??
        (profile == null ? null : HostId(profile.id));
  }

  SessionTab? get _tab =>
      widget.tabs.tabs.where((tab) => tab.ref == widget.current).firstOrNull;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _workspaceActions = context.read<WorkspaceActions?>()
      ?..claimTab(_closeShown);
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
    _workspaceActions?.releaseTab(_closeShown);
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
    if (!_closing.add(tab.ref)) return;
    final tabs = widget.tabs;
    final index = tabs.tabs.indexOf(tab);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = context.v2L10n;
    final title = _title(context, tab);
    final drafts = context.read<WorkspaceDraftController?>();
    late final ({bool removed, SessionRef? next, bool unpinned}) result;
    try {
      result = await tabs.close(tab.ref);
    } finally {
      _closing.remove(tab.ref);
    }
    final (:removed, :next, :unpinned) = result;
    if (!removed) {
      if (tabs.tabs.any((t) => t.ref == tab.ref) &&
          (messenger?.mounted ?? false)) {
        showAppSnackBar(messenger, l10n.sessionsActionFailed);
      }
      return;
    }
    String location() =>
        router.routerDelegate.currentConfiguration.uri.toString();
    // Whatever the route shows now decides: navigating away meanwhile wins
    // over the neighbour, and a tab shown since (the neighbour of another
    // close, say) is left as well.
    if (location() == sessionTabLocation(tab.ref)) {
      final target = tabs.tabs.any((other) => other.ref == next) ? next : null;
      if (target != null) {
        router.go(sessionTabLocation(target));
      } else {
        await drafts?.openDraft(directory: tab.project?.canonicalDirectory);
        if (location() == sessionTabLocation(tab.ref)) {
          router.go('/sessions');
          drafts?.focusComposer();
        }
      }
    }
    if (!(messenger?.mounted ?? false)) return;
    messenger?.clearSnackBars();
    showAppSnackBar(
      messenger,
      l10n.sessionTabClosedMessage(title),
      maxLines: 1,
      duration: const Duration(seconds: 3),
      action: SnackBarAction(
        label: l10n.sessionTabUndo,
        onPressed: () async {
          // Undo restores only local state, without taking navigation.
          if (!await tabs.reopen(
            tab,
            index: index,
            select: false,
            pin: unpinned,
          )) {
            if (messenger?.mounted ?? false) {
              showAppSnackBar(messenger, l10n.sessionTabRestoreFailed);
            }
          }
        },
      ),
    );
  }

  Future<void> _draft(ProjectRef project) async {
    final drafts = context.read<WorkspaceDraftController?>();
    final contexts = context.read<ProjectContextsController?>();
    if (_openingDraft || drafts == null || contexts == null) return;
    final directory = project.canonicalDirectory;
    if (widget.current == null &&
        drafts.isDraftActive &&
        drafts.currentKey?.canonicalDirectory == directory) {
      drafts.focusComposer();
      return;
    }
    _openingDraft = true;
    final router = GoRouter.of(context);
    final routes = router.routeInformationProvider;
    // Any navigation while the project opens wins, even one that comes back
    // to the same place.
    var moved = false;
    void navigated() => moved = true;
    routes.addListener(navigated);
    try {
      final opened = await contexts.openContext(directory);
      routes.removeListener(navigated);
      if (!opened) {
        if (mounted) {
          showAppSnackBar(
            ScaffoldMessenger.maybeOf(context),
            context.v2L10n.projectsUnavailable,
          );
        }
        return;
      }
      if (!mounted || moved || _host != project.host) return;
      router.go('/sessions');
      await drafts.openDraft(directory: directory);
      if (router.routeInformationProvider.value.uri.path == '/sessions' &&
          drafts.currentKey?.profileId == project.host.value &&
          drafts.currentKey?.canonicalDirectory == directory) {
        drafts.focusComposer();
      }
    } finally {
      routes.removeListener(navigated);
      _openingDraft = false;
    }
  }

  void _cycle({required bool reverse}) {
    final open = _switcher;
    if (open != null) {
      setState(() {
        _highlight = (_highlight + (reverse ? -1 : 1)) % open.length;
      });
      return;
    }
    final host = _host;
    if (host == null) return;
    final recent = widget.tabs.recent(host);
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
    final host = _host;
    if (host == null) return;
    final recent = widget.tabs.recent(host);
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
                leading: SessionTabGlyph(tab: tab, tabs: widget.tabs),
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
    final catalog = context.watch<SessionsController?>();
    final drafts = context.watch<WorkspaceDraftController?>();
    return ListenableBuilder(
      listenable: Listenable.merge([widget.tabs, ...widget.tabs.warmViews]),
      builder: (context, _) {
        final profile = catalog?.selectedProfile;
        final host =
            widget.current?.host ??
            (profile == null ? null : HostId(profile.id));
        if (host == null) return widget.child;
        final tab = _tab;
        final projection = widget.tabs.projection(host);
        final drafting =
            widget.current == null && drafts?.isDraftActive == true;
        final directory = drafts?.currentKey?.canonicalDirectory;
        final draftProject = directory == null
            ? widget.project
            : ProjectRef(host, directory);
        final shown = projection.ordered.isNotEmpty || drafting;
        final switcher = _switcher;
        return KeyboardActionScope(
          handlers: {
            ShortcutAction.cycleTabsForward: () => _cycle(reverse: false),
            ShortcutAction.cycleTabsBackward: () => _cycle(reverse: true),
            if (tab != null)
              ShortcutAction.closeApp: () => unawaited(_close(tab)),
          },
          child: Focus(
            autofocus: true,
            skipTraversal: true,
            child: Column(
              children: [
                if (shown)
                  _Strip(
                    tabs: widget.tabs,
                    projection: projection,
                    current: widget.current,
                    drafting: drafting,
                    draftProject: draftProject,
                    draftFailed: drafts?.status == WorkspaceDraftStatus.failed,
                    onActivate: _activate,
                    onClose: (tab) => unawaited(_close(tab)),
                    onDraft: (project) => unawaited(_draft(project)),
                    onRecent: _showRecent,
                    onInteract: () => _finishSwitcher(commit: false),
                  ),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(child: widget.child),
                      if (switcher != null)
                        _Switcher(
                          tabs: switcher,
                          highlight: _highlight,
                          icons: widget.tabs,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

String _title(BuildContext context, SessionTab tab) =>
    tab.title.trim().isEmpty ? context.v2L10n.sessionExportUntitled : tab.title;

/// Pinned tabs scroll separately; ordinary groups keep a usable viewport.
class _Strip extends StatefulWidget {
  const _Strip({
    required this.tabs,
    required this.projection,
    required this.current,
    required this.drafting,
    required this.draftProject,
    required this.draftFailed,
    required this.onActivate,
    required this.onClose,
    required this.onDraft,
    required this.onRecent,
    required this.onInteract,
  });
  final SessionTabsController tabs;
  final SessionTabProjection projection;
  final SessionRef? current;
  final bool drafting;
  final ProjectRef? draftProject;
  final bool draftFailed;
  final ValueChanged<SessionRef> onActivate;
  final ValueChanged<SessionTab> onClose;
  final ValueChanged<ProjectRef> onDraft;
  final VoidCallback onRecent;
  final VoidCallback onInteract;
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
    // Insertion, regrouping, pinning and changed titles can move the current
    // tab even when its identity did not change.
    if (oldWidget.current != widget.current ||
        oldWidget.drafting != widget.drafting ||
        !listEquals(
          oldWidget.projection.ordered.map((t) => (t.ref, t.title)).toList(),
          widget.projection.ordered.map((t) => (t.ref, t.title)).toList(),
        ) ||
        !listEquals(
          oldWidget.projection.pinned.map((t) => t.ref).toList(),
          widget.projection.pinned.map((t) => t.ref).toList(),
        )) {
      _reveal();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reveal();
  }

  void _reveal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _shown.currentContext;
      if (mounted && target != null) Scrollable.ensureVisible(target);
    });
  }

  Widget _tab(SessionTab tab, double maxWidth, {required bool pinned}) =>
      KeyedSubtree(
        key: tab.ref == widget.current
            ? _shown
            : ValueKey(('session-tab-slot', tab.ref)),
        child: SessionTabMenu(
          tabs: widget.tabs,
          tab: tab,
          child: SessionTabChip(
            tabs: widget.tabs,
            tab: tab,
            selected: tab.ref == widget.current,
            pinned: pinned,
            maxWidth: maxWidth,
            onTap: () => widget.onActivate(tab.ref),
            onClose: () => widget.onClose(tab),
            onPointerIntent: widget.onInteract,
          ),
        ),
      );

  Widget _draft(double maxWidth) => ConstrainedBox(
    key: _shown,
    constraints: BoxConstraints(maxWidth: math.max(1, maxWidth)),
    child: Semantics(
      selected: true,
      button: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(end: 2, top: 3),
        child: Material(
          key: const ValueKey('session-tab-draft'),
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              height: 48,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.draftFailed ? Icons.error_outline : Icons.add,
                    size: 19,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      context.v2L10n.chatNewChat,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _scroll(List<Widget> children, {Key? key}) => ScrollConfiguration(
    behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
    child: SingleChildScrollView(
      key: key,
      scrollDirection: Axis.horizontal,
      child: Row(children: children),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final projection = widget.projection;
    final hasRegular = projection.groups.isNotEmpty || widget.drafting;
    return Material(
      key: const ValueKey('session-tabs'),
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Semantics(
        label: context.v2L10n.chatSessionTabsToggle,
        container: true,
        child: LayoutBuilder(
          builder: (context, box) {
            final usable = math.max(1.0, box.maxWidth - 48);
            final compact = MediaQuery.sizeOf(context).width < 600;
            final selectedPin = projection.pinned.any(
              (t) => t.ref == widget.current,
            );
            final wanted =
                projection.pinned.length * 38.0 + (selectedPin ? 124 : 0);
            final cap = hasRegular
                ? math.max(
                    0.0,
                    usable - math.min(compact ? 100.0 : 120.0, usable / 2),
                  )
                : usable;
            final pinnedWidth = math.min(
              wanted,
              math.min(
                cap,
                selectedPin
                    ? math.max(usable * .5, math.min(180.0, cap))
                    : usable * .45,
              ),
            );
            final regular = <Widget>[];
            var draftAdded = false;
            for (final entry in projection.groups.entries) {
              if (regular.isNotEmpty) regular.add(const SizedBox(width: 8));
              for (final tab in entry.value) {
                regular.add(
                  _tab(tab, math.max(1.0, usable - pinnedWidth), pinned: false),
                );
              }
              final project = entry.key;
              if (widget.drafting && project == widget.draftProject) {
                regular.add(_draft(usable));
                draftAdded = true;
              } else if (project != null) {
                regular.add(
                  IconButton(
                    key: ValueKey('session-tab-add-${project.storageKey}'),
                    tooltip: context.v2L10n.chatNewChat,
                    icon: const Icon(Icons.add),
                    onPressed: () => widget.onDraft(project),
                  ),
                );
              }
            }
            if (widget.drafting && !draftAdded) regular.add(_draft(usable));
            return Row(
              children: [
                if (projection.pinned.isNotEmpty && pinnedWidth > 0)
                  SizedBox(
                    width: pinnedWidth,
                    child: _scroll([
                      for (final tab in projection.pinned)
                        _tab(tab, pinnedWidth, pinned: true),
                    ], key: const ValueKey('session-tabs-pinned')),
                  ),
                Expanded(
                  child: _scroll(
                    regular,
                    key: const ValueKey('session-tabs-regular'),
                  ),
                ),
                IconButton(
                  key: const ValueKey('session-tabs-recent-button'),
                  tooltip: context.v2L10n.sessionTabSwitcherTitle,
                  icon: const Icon(Icons.swap_horiz),
                  onPressed: widget.onRecent,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The recent tabs while Ctrl is held; the highlighted one opens on release.
class _Switcher extends StatefulWidget {
  const _Switcher({
    required this.tabs,
    required this.highlight,
    required this.icons,
  });

  final List<SessionTab> tabs;
  final int highlight;
  final SessionTabsController icons;

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
                          leading: SessionTabGlyph(
                            tab: tab,
                            tabs: widget.icons,
                          ),
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
      final notice = _notice = showAppSnackBar(
        messenger,
        context.v2L10n.sessionTabsRemoved,
      );
      notice?.closed.whenComplete(() {
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
