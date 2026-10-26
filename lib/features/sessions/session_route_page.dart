import 'dart:async';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/workspace_chrome.dart';
import '../../platform/sessions/session_draft_store.dart';
import '../../shared/l10n/l10n_context.dart';
import '../../shared/sessions/permission_mode.dart';
import '../../shared/sessions/session_catalog_source.dart';
import '../../shared/sessions/session_live_source.dart';
import '../hosts/endpoint_health_controller.dart';
import 'project_contexts_controller.dart';
import 'session_live_controller.dart';
import 'session_live_page.dart';
import 'session_tab_strip.dart';
import 'session_tabs_controller.dart';
import 'sessions_controller.dart';
import 'workspace_draft_controller.dart';
import 'workspace_first_prompt.dart';

/// The open session of the workspace, named by `/s/<server>/<session>`.
///
/// A row tap and an external link land here alike. The server is the saved
/// profile with that id; the session is the loaded row with the same
/// identity, or else one direct read of that server. A link never invents a
/// session the server did not return.
class SessionRoutePage extends StatefulWidget {
  const SessionRoutePage({
    super.key,
    required this.host,
    required this.session,
  });

  final String host;
  final String session;

  @override
  State<SessionRoutePage> createState() => _SessionRoutePageState();
}

enum _Read { idle, reading, notFound, login, failed }

class _SessionRoutePageState extends State<SessionRoutePage> {
  SessionSummary? _summary;
  SessionReadTask? _task;
  EndpointProfile? _binding;

  /// The live view of the open session, made once. Its tab keeps it open
  /// while other tabs are shown; without tabs its page disposes it.
  SessionLiveController? _live;

  /// The session whose tab this page opened, so it is opened once.
  SessionRef? _opened;

  /// The session last reported as the view of its project.
  SessionRef? _viewed;

  /// The tab of this session was seen saved; its later absence means it
  /// was dropped or closed.
  bool _tabbed = false;
  _Read _read = _Read.idle;
  bool _selecting = false;

  /// The list has shown the server of this session; a later change of
  /// server in the list leaves the session.
  bool _followed = false;
  bool _leaving = false;

  /// The saved servers have been read once; before that no server is
  /// unknown yet.
  bool _ready = false;
  SessionsController? _catalog;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final catalog = context.watch<SessionsController?>();
    if (identical(catalog, _catalog)) return;
    _catalog = catalog;
    _ready = false;
    if (catalog == null) return;
    // A compact window may open here without ever building the list.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(catalog, _catalog)) return;
      catalog.initialize().whenComplete(() {
        if (mounted && identical(catalog, _catalog)) {
          setState(() => _ready = true);
        }
      });
    });
  }

  SessionRef get _ref => SessionRef(
    HostId(widget.host),
    HarnessInstanceId(widget.host),
    widget.session,
  );

  @override
  void didUpdateWidget(SessionRoutePage old) {
    super.didUpdateWidget(old);
    if (old.host != widget.host || old.session != widget.session) {
      _task?.cancel();
      _task = null;
      _summary = null;
      _binding = null;
      _live = null;
      _opened = null;
      _tabbed = false;
      _read = _Read.idle;
      _selecting = false;
      _followed = false;
      _leaving = false;
    }
  }

  @override
  void dispose() {
    _task?.cancel();
    super.dispose();
  }

  /// Reads the session once from its server. A late answer for another
  /// session or a disposed page is dropped.
  void _start(SessionsController catalog) {
    final binding = catalog.selectedProfile;
    if (binding == null) {
      _read = _Read.failed;
      return;
    }
    final task = catalog.read(_ref);
    if (task == null) {
      _read = _Read.failed;
      return;
    }
    _task = task;
    _read = _Read.reading;
    final ref = _ref;
    bool current() {
      if (!mounted || !identical(_task, task)) return false;
      final hosts = catalog.hosts;
      if (hosts.loading ||
          hosts.storageError ||
          hosts.pendingBindingChange == binding.id ||
          !hosts.isCurrentProfile(binding)) {
        setState(() {
          _task = null;
          _read = _Read.idle;
        });
        return false;
      }
      return true;
    }

    task.result.then(
      (summary) {
        if (!current()) return;
        setState(() {
          _task = null;
          // An answer for another session is never opened in its place.
          if (summary.info.ref == ref) {
            _summary = summary;
          } else {
            _read = _Read.failed;
          }
        });
      },
      onError: (Object error) {
        if (!current()) return;
        setState(() {
          _task = null;
          _read = switch (error) {
            SessionCatalogException(failure: SessionCatalogFailure.notFound) =>
              _Read.notFound,
            SessionCatalogException(
              failure: SessionCatalogFailure.authenticationRequired,
            ) =>
              _Read.login,
            _ => _Read.failed,
          };
        });
      },
    );
  }

  /// Selects the server of this session in the list. A selection the list
  /// refused, as it does while the saved servers reload, is tried again on
  /// the next build.
  void _select(SessionsController catalog) {
    catalog.selectProfile(widget.host).whenComplete(() {
      if (mounted && catalog.selectedProfile?.id != widget.host) {
        setState(() => _selecting = false);
      }
    }).ignore();
  }

  void _retry() => setState(() {
    _task?.cancel();
    _task = null;
    _read = _Read.idle;
  });

  /// A fixed login replaced the server's source, so the list reads again
  /// before the session does.
  void _retryLogin() {
    final catalog = _catalog;
    if (catalog == null) return;
    setState(() => _read = _Read.reading);
    catalog.refresh().whenComplete(() {
      if (mounted && _read == _Read.reading && _task == null) _retry();
    });
  }

  /// Opens the list drawer of a compact window, the only window whose
  /// workspace has one.
  Widget? _leading(BuildContext context) {
    final shell = Scaffold.maybeOf(context);
    if (shell == null || !shell.hasDrawer) return null;
    return WorkspaceMenuButton(openDrawer: shell.openDrawer);
  }

  Future<void> _open(SessionTabsController tabs, SessionSummary summary) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final full = context.v2L10n.sessionTabsFull;
    if (await tabs.open(summary) == SessionTabOpen.full) {
      messenger?.showSnackBar(SnackBar(content: Text(full)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = _resolve(context, _leading(context));
    // A live page that leaves the tree disposes its controller, so a later
    // return makes a new one.
    if (page is! SessionLivePage) _live = null;
    final tabs = context.read<SessionTabsController?>();
    final live = _live;
    if (live == null || page is! SessionLivePage) return page;
    final delivery = _withFirstPrompt(context, live, page);
    if (tabs == null) return delivery;
    return SessionTabsFrame(
      tabs: tabs,
      current: _ref,
      project: live.summary.info.project,
      child: delivery,
    );
  }

  Widget _resolve(BuildContext context, Widget? leading) {
    final l10n = context.v2L10n;
    final catalog = context.watch<SessionsController?>();
    final directory = context.read<SessionLiveDirectory?>();
    if (catalog == null || directory == null) {
      return _Notice(message: l10n.chatAddServerToStart, leading: leading);
    }
    final hosts = catalog.hosts;
    final selected = catalog.selectedProfile;
    final tabs = context.watch<SessionTabsController?>();
    final profile = hosts.profiles
        .where((profile) => profile.id == widget.host)
        .firstOrNull;
    if (hosts.loaded && !hosts.loading && !hosts.storageError) {
      if (_binding != null &&
          (profile == null || !_binding!.sameBinding(profile))) {
        _task?.cancel();
        _task = null;
        _summary = null;
        _live = null;
        _read = _Read.idle;
      }
      _binding = profile;
    }
    if (tabs != null) {
      final open = tabs.tabs.any((tab) => tab.ref == _ref);
      if (open) {
        _tabbed = true;
      } else if (_tabbed) {
        _tabbed = false;
        // The view the tab kept is released, so it is never shown again.
        _live = null;
        // Only its server saying the session no longer exists makes it not
        // found; a tab closed or expired here leaves the session shown.
        if (tabs.deleted(_ref)) {
          _summary = null;
          _read = _Read.notFound;
        }
      }
    }
    if (_live?.disposed ?? false) _live = null;
    final live = _live;
    final row = catalog.findSession(_ref);
    // A kept view shows the newest row, a rename say, even while it stays
    // on screen.
    if (live != null && row != null && !identical(live.summary, row)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) live.updateSummary(row);
      });
    }
    // An open session outlasts a reload of the saved servers; it closes
    // only when its server is removed or another one is chosen.
    if (live != null &&
        (hosts.loading || profile?.sameBinding(live.profile) == true) &&
        (selected == null || selected.id == widget.host)) {
      // The list holds this server again, so a later reload may reselect.
      if (selected != null) _selecting = false;
      if (selected == null &&
          !hosts.loading &&
          !hosts.storageError &&
          !_selecting) {
        // The list lost its choice in the reload; it follows the session.
        _selecting = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _select(catalog);
        });
      }
      return SessionLivePage(
        key: ObjectKey(live),
        controller: live,
        leading: leading,
        workspaceChrome: true,
        ownsController: context.read<SessionTabsController?>() == null,
      );
    }
    if (!_ready || hosts.loading) return _Notice(leading: leading);
    if (hosts.storageError) {
      return _Notice(
        message: l10n.hostsProfileStorageError,
        leading: leading,
        onRetry: hosts.load,
      );
    }
    if (profile == null) {
      return _Notice(message: l10n.sessionLinkUnknownServer, leading: leading);
    }
    if (selected?.id != profile.id) {
      if (_followed && selected != null) {
        // The user chose another server in the list: its sessions replace
        // this one.
        if (!_leaving) {
          _leaving = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.go('/sessions');
          });
        }
        return _Notice(leading: leading);
      }
      // The list follows the server of the open session.
      if (!_selecting) {
        _selecting = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _select(catalog);
        });
      }
      return _Notice(leading: leading);
    }
    _followed = true;
    // A reload that clears the choice selects this server again.
    _selecting = false;
    final ref = _ref;
    // Once found, the session stays open whatever the list later shows.
    if (_read == _Read.notFound) {
      return _Notice(message: l10n.sessionLinkNotFound, leading: leading);
    }
    final summary = _summary ??=
        context
            .read<WorkspaceDraftController?>()
            ?.firstPromptFor(ref)
            ?.summary ??
        row;
    if (summary != null) {
      SessionLiveController create() => SessionLiveController(
        hosts: hosts,
        profile: profile,
        summary: summary,
        directory: directory,
        health: context.read<EndpointHealthController?>(),
        permissionModes: _permissionPolicy(context),
        drafts: context.read<SessionDraftStore?>(),
      );
      final live = _live ??= tabs == null ? create() : tabs.live(ref, create);
      if (row != null && !identical(live.summary, row)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) live.updateSummary(row);
        });
      }
      if (_viewed != ref) {
        // The shown session is the view of its project, which becomes the
        // project the list shows.
        _viewed = ref;
        final contexts = context.read<ProjectContextsController?>();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) contexts?.recordView(summary);
        });
      }
      if (tabs != null && _opened != ref) {
        // Opening the session adds its tab or focuses it.
        _opened = ref;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_open(tabs, summary));
        });
      }
      return SessionLivePage(
        key: ObjectKey(live),
        controller: live,
        leading: leading,
        ownsController: tabs == null,
        workspaceChrome: true,
      );
    }
    if (catalog.failure == SessionCatalogFailure.authenticationRequired) {
      return _Notice(
        message: l10n.hostsAuthRequired,
        leading: leading,
        onRetry: _retryLogin,
      );
    }
    // Waits for the first list, which may already hold the session. A list
    // cleared by a change of the server can be read again from here.
    if (!catalog.loaded && catalog.failure == null) {
      return _Notice(
        leading: leading,
        onRetry: catalog.loading ? null : catalog.refresh,
      );
    }
    if (_read == _Read.idle) _start(catalog);
    return switch (_read) {
      _Read.notFound => _Notice(
        message: l10n.sessionLinkNotFound,
        leading: leading,
      ),
      // A fixed login reads again from the retry.
      _Read.login => _Notice(
        message: l10n.hostsAuthRequired,
        leading: leading,
        onRetry: _retryLogin,
      ),
      _Read.failed => _Notice(
        message: l10n.sessionLinkUnreadable,
        leading: leading,
        onRetry: _retry,
      ),
      _Read.idle || _Read.reading => _Notice(leading: leading),
    };
  }

  Widget _withFirstPrompt(
    BuildContext context,
    SessionLiveController live,
    Widget page,
  ) {
    final workspace = context.read<WorkspaceDraftController?>();
    return workspace == null
        ? page
        : WorkspaceFirstPromptDelivery(
            key: ObjectKey(live),
            workspace: workspace,
            live: live,
            child: page,
          );
  }

  EditablePermissionModePolicy? _permissionPolicy(BuildContext context) {
    try {
      return context.read<EditablePermissionModePolicy>();
    } on ProviderNotFoundException {
      return null;
    }
  }
}

/// A session that is not open yet: progress without [message], otherwise
/// why it cannot open.
class _Notice extends StatelessWidget {
  const _Notice({this.message, this.leading, this.onRetry});

  final String? message;
  final Widget? leading;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: leading,
      title: Text(context.v2L10n.chatConversation),
    ),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message == null)
              const CircularProgressIndicator(key: ValueKey('session-opening'))
            else
              Text(
                message!,
                key: const ValueKey('session-notice'),
                textAlign: TextAlign.center,
              ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                key: const ValueKey('session-retry'),
                onPressed: onRetry,
                child: Text(context.v2L10n.chatRetry),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
