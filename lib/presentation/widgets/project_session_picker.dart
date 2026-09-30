import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/i18n/l10n_context.dart';
import '../providers/chat_provider.dart' show SessionTabIdentity;
import 'session_context_menu.dart';

/// Lists the full cached root-session set without changing sidebar visibility.
class ProjectSessionPicker extends StatefulWidget {
  const ProjectSessionPicker({
    super.key,
    required this.projectLabel,
    required this.updates,
    required this.sessions,
    required this.isValid,
    this.dismissSignal,
  });

  final String projectLabel;
  final Listenable updates;
  final List<SessionMenuSession> Function() sessions;
  final bool Function() isValid;
  final ValueListenable<int>? dismissSignal;

  @override
  State<ProjectSessionPicker> createState() => _ProjectSessionPickerState();
}

class _ProjectSessionPickerState extends State<ProjectSessionPicker> {
  final _searchController = TextEditingController();
  ModalRoute<SessionTabIdentity>? _route;

  @override
  void initState() {
    super.initState();
    widget.updates.addListener(_handleUpdate);
    widget.dismissSignal?.addListener(_dismiss);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of<SessionTabIdentity>(context);
  }

  void _handleUpdate() {
    if (!widget.isValid()) {
      _dismiss();
      return;
    }
    setState(() {});
  }

  void _dismiss() {
    // Invalidation and title-bar navigation remove only this owned route.
    final route = _route;
    if (route != null && route.isActive) {
      route.navigator?.removeRoute(route);
    }
  }

  @override
  void dispose() {
    widget.updates.removeListener(_handleUpdate);
    widget.dismissSignal?.removeListener(_dismiss);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final compact = media.size.width < 600;
    final query = _searchController.text.trim().toLowerCase();
    final sessions = widget.isValid()
        ? widget
              .sessions()
              .where((session) => session.title.toLowerCase().contains(query))
              .toList(growable: false)
        : const <SessionMenuSession>[];
    final content = SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 4, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.projectLabel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Symbols.close),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              key: const ValueKey<String>('project_session_picker_search'),
              controller: _searchController,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: context.l10n.chatSearchConversations,
                prefixIcon: const Icon(Symbols.search),
              ),
            ),
          ),
          Expanded(
            child: sessions.isEmpty
                ? Center(child: Text(context.l10n.chatSearchNoResults))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      return SessionMenuSessionTile(
                        key: ValueKey<String>(
                          'project_session_picker_${session.identity.sessionId}',
                        ),
                        session: session,
                        onPressed: () =>
                            Navigator.of(context).pop(session.identity),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
    if (compact) {
      return Dialog.fullscreen(
        key: const ValueKey<String>('project_session_picker'),
        child: content,
      );
    }
    return Dialog(
      key: const ValueKey<String>('project_session_picker'),
      child: SizedBox(
        width: 560,
        height: (media.size.height * .75).clamp(0, 640),
        child: content,
      ),
    );
  }
}
