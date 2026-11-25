import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../shared/l10n/l10n_context.dart';
import 'project_contexts_controller.dart';

/// The header row of the session list: its title, or the inline search that
/// replaces it, the project picker, and New Chat.
///
/// The search is collapsed to an icon until used. A query kept from an
/// earlier visit opens it already expanded; only clearing it (the clear
/// button or Escape) collapses it again, so the search query never hides
/// behind the title.
class SessionDrawerHeader extends StatefulWidget {
  const SessionDrawerHeader({
    super.key,
    required this.contexts,
    required this.onCreate,
    this.onProjects,
  });

  /// The saved search query; without it there is no search control.
  final ProjectContextsController? contexts;

  /// Opens a new chat, or null while one cannot be opened.
  final VoidCallback? onCreate;

  /// Opens the project picker, or null while no project can be picked.
  final VoidCallback? onProjects;

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
            prefixIcon: const Icon(Symbols.search),
            isDense: true,
            suffixIcon: ListenableBuilder(
              listenable: _field,
              builder: (context, _) => _field.text.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      key: const ValueKey('sessions-search-clear'),
                      tooltip: l10n.settingsSearchClear,
                      onPressed: _clear,
                      icon: const Icon(Symbols.close),
                    ),
            ),
          ),
        ),
      );
    }
    final title = Text(
      l10n.chatConversations,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.titleLarge,
    );
    // v1: chat_page_scaffold.dart:242-293 (search, folder, new chat icon row).
    final controls = <Widget>[
      if (search)
        IconButton(
          key: const ValueKey('sessions-search'),
          tooltip: l10n.chatSearchConversations,
          onPressed: _expand,
          icon: const Icon(Symbols.search),
        ),
      if (widget.onProjects != null)
        IconButton(
          key: const ValueKey('sessions-projects'),
          tooltip: l10n.chatChooseDirectory,
          onPressed: widget.onProjects,
          icon: const Icon(Symbols.folder_open),
        ),
      // The create is a compact control, so the header does not push the
      // rows out of a small viewport.
      IconButton(
        key: const ValueKey('sessions-create'),
        tooltip: l10n.sessionsCreateNew,
        onPressed: widget.onCreate,
        icon: const Icon(Symbols.add_comment),
      ),
    ];
    // At large text scales the controls wrap under the title; at normal scale
    // they stay on one line beside it, as in v1.
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.25;
    return LayoutBuilder(
      builder: (context, constraints) => largeText || constraints.maxWidth < 240
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                title,
                Wrap(alignment: WrapAlignment.end, children: controls),
              ],
            )
          : Row(
              children: [
                Expanded(child: title),
                ...controls,
              ],
            ),
    );
  }
}
