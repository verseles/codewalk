import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../platform/sessions/project_workspace_store.dart';
import '../../shared/l10n/generated/v2_localizations.dart';
import '../../shared/l10n/l10n_context.dart';
import '../../shared/sessions/session_actions.dart';
import 'project_contexts_controller.dart';
import 'sessions_controller.dart';

/// The header row of the session list: its title, or the inline search that
/// replaces it, one menu for the filter and the sort, and New Chat.
///
/// The search is collapsed to an icon until used. A query kept from an
/// earlier visit opens it already expanded; only clearing it (the clear
/// button or Escape) collapses it again, so the filter never hides behind
/// the title.
class SessionDrawerHeader extends StatefulWidget {
  const SessionDrawerHeader({
    super.key,
    required this.catalog,
    required this.contexts,
    required this.onCreate,
  });

  final SessionsController catalog;

  /// The saved query, filter and sort; without it the menu sets the filter
  /// for this run only and there is no search.
  final ProjectContextsController? contexts;

  /// Opens a new chat, or null while one cannot be opened.
  final VoidCallback? onCreate;

  @override
  State<SessionDrawerHeader> createState() => _SessionDrawerHeaderState();
}

class _SessionDrawerHeaderState extends State<SessionDrawerHeader> {
  final _field = TextEditingController();
  final _focus = FocusNode(debugLabel: 'session-search');
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void didUpdateWidget(SessionDrawerHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    _restore();
  }

  /// Shows a kept query expanded, as the list is already filtered by it;
  /// the field follows a query changed elsewhere unless the user is typing.
  void _restore() {
    final query = widget.contexts?.query ?? '';
    if (_field.text != query && !_focus.hasFocus) _field.text = query;
    if (query.isNotEmpty) _expanded = true;
  }

  void _expand() {
    setState(() => _expanded = true);
    _focus.requestFocus();
  }

  void _clear() {
    _field.clear();
    widget.contexts?.setQuery('');
    _focus.unfocus();
    setState(() => _expanded = false);
  }

  @override
  void dispose() {
    _field.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.v2L10n;
    final theme = Theme.of(context);
    final contexts = widget.contexts;
    final query = contexts?.query ?? '';
    final search = contexts != null && contexts.available;
    if (_expanded && search) {
      return CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): _clear},
        child: TextField(
          key: const ValueKey('sessions-search-field'),
          controller: _field,
          focusNode: _focus,
          autofocus: query.isEmpty,
          textInputAction: TextInputAction.search,
          onChanged: contexts.setQuery,
          // The keyboard leaves; the query and the field stay.
          onSubmitted: (_) => _focus.unfocus(),
          onTapOutside: (_) => _focus.unfocus(),
          decoration: InputDecoration(
            hintText: l10n.chatSearchConversations,
            prefixIcon: const Icon(Icons.search),
            isDense: true,
            suffixIcon: ListenableBuilder(
              listenable: _field,
              builder: (context, _) => _field.text.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      key: const ValueKey('sessions-search-clear'),
                      tooltip: l10n.settingsSearchClear,
                      onPressed: _clear,
                      icon: const Icon(Icons.close),
                    ),
            ),
          ),
        ),
      );
    }
    return Row(
      children: [
        Expanded(
          child: Text(
            l10n.chatConversations,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge,
          ),
        ),
        if (search)
          IconButton(
            key: const ValueKey('sessions-search'),
            tooltip: l10n.chatSearchConversations,
            onPressed: _expand,
            icon: const Icon(Icons.search),
          ),
        _ListMenu(catalog: widget.catalog, contexts: contexts),
        // The create is a compact control, so the header does not push the
        // rows out of a small viewport.
        IconButton.filled(
          key: const ValueKey('sessions-create'),
          tooltip: l10n.sessionsCreateNew,
          onPressed: widget.onCreate,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}

/// The filter and sort of the list in one menu, with a badge that names
/// both by their initials; the tooltip and the menu spell them out.
class _ListMenu extends StatelessWidget {
  const _ListMenu({required this.catalog, required this.contexts});

  final SessionsController catalog;
  final ProjectContextsController? contexts;

  @override
  Widget build(BuildContext context) {
    final l10n = context.v2L10n;
    final filter = catalog.filter;
    final contexts = this.contexts;
    final sorting = contexts != null && contexts.available;
    final sort = sorting ? contexts.preferences.sort : SessionListSort.recent;
    String initial(String label) =>
        label.characters.isEmpty ? '' : label.characters.first.toUpperCase();
    final badge = sorting
        ? '${initial(filterLabel(l10n, filter))}/'
              '${initial(sortLabel(l10n, sort))}'
        : initial(filterLabel(l10n, filter));
    return PopupMenuButton<Object>(
      key: const ValueKey('sessions-filter'),
      tooltip: l10n.sessionsListState(
        filterLabel(l10n, filter),
        sortLabel(l10n, sort),
      ),
      onSelected: (choice) {
        switch (choice) {
          case final SessionActionFilter next:
            if (contexts != null && contexts.available) {
              contexts.setFilter(next);
            } else {
              catalog.setFilter(next);
            }
          case final SessionListSort next:
            contexts?.setSort(next);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<Object>(
          enabled: false,
          child: Text(l10n.chatFilterSessions),
        ),
        for (final value in SessionActionFilter.values)
          CheckedPopupMenuItem<Object>(
            key: ValueKey('sessions-filter-${value.name}'),
            value: value,
            checked: value == filter,
            child: Text(filterLabel(l10n, value)),
          ),
        if (sorting) ...[
          const PopupMenuDivider(),
          PopupMenuItem<Object>(
            enabled: false,
            child: Text(l10n.chatSortSessions),
          ),
          for (final value in SessionListSort.values)
            CheckedPopupMenuItem<Object>(
              key: ValueKey('sessions-sort-${value.name}'),
              value: value,
              checked: value == sort,
              child: Text(sortLabel(l10n, value)),
            ),
        ],
      ],
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 8,
          vertical: 12,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.filter_list, size: 20),
            const SizedBox(width: 4),
            Text(
              badge,
              key: const ValueKey('sessions-filter-badge'),
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
      ),
    );
  }
}

/// The label of the filter that shows which sessions the list holds.
String filterLabel(V2Localizations l10n, SessionActionFilter filter) =>
    switch (filter) {
      SessionActionFilter.active => l10n.sessionsFilterActive,
      SessionActionFilter.hidden => l10n.sessionsFilterHidden,
      SessionActionFilter.all => l10n.sessionsFilterAll,
    };

/// The label of the order of the list.
String sortLabel(V2Localizations l10n, SessionListSort sort) => switch (sort) {
  SessionListSort.recent => l10n.chatSortRecent,
  SessionListSort.oldest => l10n.chatSortOldest,
  SessionListSort.title => l10n.chatSortTitle,
};
