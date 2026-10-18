import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';

import '../../shared/l10n/generated/v2_localizations.dart';
import '../../shared/l10n/l10n_context.dart';
import '../../shared/sessions/session_permission_reply.dart';
import 'session_live_controller.dart';

/// Manual permission cards for the live session's resident requests. Each
/// deliberate tap is one reply through the lease; 204 never removes a card,
/// only the stream does. Never imports harness code.
class SessionPermissionCards extends StatelessWidget {
  const SessionPermissionCards({
    super.key,
    required this.live,
    this.maxHeight = 300,
  });
  final SessionLiveController live;

  /// Height the viewer budgeted for these cards; the page derives it from the
  /// body so cards and composer never overrun a short viewport between them.
  final double maxHeight;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: live,
    builder: (context, _) {
      // Only a lease without a reply port keeps the read-only contract; the
      // needs-you line still signals. A resident card stays mounted while the
      // lease is not current (actions disabled) instead of dropping the note.
      final all = [
        for (final request
            in live.state?.interactions ?? const <InteractionRequest>[])
          if (request.kind.known == InteractionKind.permission &&
              live.supportsReplies)
            request,
      ];
      // The session's own requests first, then sub-agent requests grouped by
      // child in order of first appearance.
      final children = <SessionRef>[];
      for (final request in all) {
        final child = permissionChildOf(live.session, request);
        if (child != null && !children.contains(child)) children.add(child);
      }
      final requests = [
        for (final r in all)
          if (permissionChildOf(live.session, r) == null) r,
        for (final child in children)
          for (final r in all)
            if (permissionChildOf(live.session, r) == child) r,
      ];
      if (requests.isEmpty) return const SizedBox.shrink();
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final request in requests)
                _PermissionCard(
                  key: ValueKey(
                    'live-permission-${permissionKeyOf(live.session, request)}',
                  ),
                  live: live,
                  request: request,
                ),
            ],
          ),
        ),
      );
    },
  );
}

/// The child session that owns [request] when it is a sub-agent request shown
/// in [session]; null for the session's own requests.
SessionRef? permissionChildOf(SessionRef session, InteractionRequest request) {
  final owner = request.owner;
  return owner is SessionOwner && owner.session != session
      ? owner.session
      : null;
}

/// Widget key part unique across the session and its children, whose native
/// ids live in separate scopes.
String permissionKeyOf(SessionRef session, InteractionRequest request) {
  final child = permissionChildOf(session, request);
  return child == null
      ? request.id.value
      : '${child.nativeId}/${request.id.value}';
}

/// Finite copy for a reply state; pure and unit-tested. Never raw server text.
String? permissionNoticeText(
  V2Localizations l10n,
  SessionPermissionReplyState state,
) => switch (state.phase) {
  SessionPermissionReplyPhase.ready || SessionPermissionReplyPhase.idle => null,
  SessionPermissionReplyPhase.requesting => l10n.livePermissionSending,
  SessionPermissionReplyPhase.requested => l10n.livePermissionSent,
  SessionPermissionReplyPhase.unconfirmed => l10n.livePermissionUnconfirmed,
  SessionPermissionReplyPhase.refused =>
    switch (state.receipt?.error?.rawType) {
      'UnauthorizedError' => l10n.hostsAuthRequired,
      'RateLimited' => l10n.sessionsRateLimited,
      // Native first-reply-wins: someone else answered, or it is gone.
      'NotFoundError' => l10n.livePermissionAnsweredElsewhere,
      _ => l10n.livePermissionRefused,
    },
};

ApprovalChoice? _offered(InteractionRequest request, String id) {
  for (final choice in request.choices) {
    if (choice.id == id) return choice;
  }
  return null;
}

List<String> _resources(InteractionRequest request) {
  final subject = request.subject?.value;
  if (subject is! Map<String, Object?>) return const [];
  final resources = subject['resources'];
  if (resources is! List) return const [];
  return [
    for (final r in resources)
      if (r is String) r,
  ];
}

List<String> _patterns(ApprovalChoice choice) {
  final preview = choice.scopePreview?.value;
  if (preview is! Map<String, Object?>) return const [];
  final patterns = preview['patterns'];
  if (patterns is! List) return const [];
  return [
    for (final p in patterns)
      if (p is String) p,
  ];
}

/// Mirrors the reply client's pattern bound, so the card never offers a
/// persistent grant the client would refuse as a non-native choice.
bool _boundedPattern(String value) =>
    value.length <= _pathLimit &&
    utf8.encode(value).length <= _pathLimit &&
    utf8.decode(utf8.encode(value)) == value;

const int _pathLimit = 4096;

/// A choice the reply client treats as native (`_nativeChoice`): anything else
/// makes every response for the request unsupported, so it is never offered.
bool _native(ApprovalChoice choice) => switch (choice.id) {
  'once' =>
    choice.allows &&
        !choice.acceptsNote &&
        choice.scope.known == ApprovalScope.once &&
        choice.resolutionScope.known == ResolutionScope.request,
  'always' =>
    choice.allows &&
        !choice.acceptsNote &&
        choice.scope.known == ApprovalScope.persistentProject &&
        choice.resolutionScope.known == ResolutionScope.project &&
        _savePreview(choice),
  'reject' =>
    !choice.allows &&
        choice.acceptsNote &&
        choice.scope.known == ApprovalScope.once &&
        choice.resolutionScope.known == ResolutionScope.session,
  _ => false,
};

bool _savePreview(ApprovalChoice choice) {
  final patterns = _patterns(choice);
  return patterns.isNotEmpty &&
      patterns.every((p) => p.isNotEmpty && _boundedPattern(p));
}

class _PermissionCard extends StatefulWidget {
  const _PermissionCard({super.key, required this.live, required this.request});
  final SessionLiveController live;
  final InteractionRequest request;

  @override
  State<_PermissionCard> createState() => _PermissionCardState();
}

class _PermissionCardState extends State<_PermissionCard> {
  final _note = TextEditingController();
  bool _showNote = false;

  SessionRef? get _child =>
      permissionChildOf(widget.live.session, widget.request);

  @override
  void initState() {
    super.initState();
    // The controller keeps the draft for this request, so a lease that lost its
    // state (retry/re-open) still shows the note the user already typed.
    _note.text = widget.live.permissionNote(
      widget.request.id,
      owner: _child,
    );
    _showNote = _note.text.isNotEmpty;
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _reply(ApprovalResponse response) => widget.live
      .replyToPermission(request: widget.request, response: response);

  String? _notice(V2Localizations l10n, SessionPermissionReplyState state) =>
      permissionNoticeText(l10n, state);

  @override
  Widget build(BuildContext context) {
    final live = widget.live;
    final request = widget.request;
    final l10n = context.v2L10n;
    final child = permissionChildOf(live.session, request);
    final keyId = permissionKeyOf(live.session, request);
    final state = live.replyState(request.id, owner: child);
    final busy = state.busy;
    final enabled = live.canReply(request) && !busy;
    final once = _offered(request, 'once');
    final always = _offered(request, 'always');
    final reject = _offered(request, 'reject');
    // The reply client refuses every response for a request carrying any
    // non-native choice (`unsupportedChoice`), so such a request is not
    // answerable: only its information is shown, never a doomed action.
    final answerable = request.choices.every(_native);
    final onceUsable = answerable && once != null;
    final alwaysUsable = answerable && always != null;
    final notes = answerable && reject != null;
    final alwaysPatterns = alwaysUsable ? _patterns(always) : const <String>[];
    final resources = _resources(request);
    final notice = _notice(l10n, state);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (child != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(bottom: 4),
                child: Row(
                  key: ValueKey('live-permission-child-$keyId'),
                  children: [
                    Icon(
                      Icons.subdirectory_arrow_right,
                      size: 16,
                      color: scheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        l10n.livePermissionChildBadge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: scheme.onSecondaryContainer),
                      ),
                    ),
                  ],
                ),
              ),
            Text(request.title, style: Theme.of(context).textTheme.titleSmall),
            if (resources.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final r in resources.take(5))
                      Chip(
                        label: Text(
                          r,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    if (resources.length > 5)
                      Text(
                        '+${resources.length - 5}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                  ],
                ),
              ),
            if (alwaysPatterns.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  alwaysPatterns.join(', '),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (alwaysPatterns.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l10n.livePermissionProjectHint,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                child == null
                    ? l10n.livePermissionBatchScope
                    : l10n.livePermissionChildBatchScope,
                key: ValueKey('live-permission-batch-$keyId'),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (onceUsable)
                  FilledButton(
                    key: ValueKey('live-permission-allow-$keyId'),
                    onPressed: enabled
                        ? () => _reply(ApprovalResponse('once'))
                        : null,
                    child: Text(l10n.livePermissionAllowOnce),
                  ),
                if (alwaysPatterns.isNotEmpty)
                  OutlinedButton(
                    key: ValueKey('live-permission-always-$keyId'),
                    onPressed: enabled
                        ? () => _reply(ApprovalResponse('always'))
                        : null,
                    child: Text(l10n.livePermissionAlwaysProject),
                  ),
                if (notes)
                  OutlinedButton(
                    key: ValueKey('live-permission-reject-note-$keyId'),
                    onPressed: enabled
                        ? () => setState(() => _showNote = !_showNote)
                        : null,
                    child: Text(l10n.livePermissionRejectNote),
                  ),
                if (notes)
                  TextButton(
                    key: ValueKey('live-permission-reject-stop-$keyId'),
                    onPressed: enabled
                        ? () => _reply(ApprovalResponse('reject'))
                        : null,
                    style: TextButton.styleFrom(foregroundColor: scheme.error),
                    child: Text(l10n.livePermissionRejectStop),
                  ),
              ],
            ),
            if (_showNote && notes) ...[
              const SizedBox(height: 8),
              TextField(
                key: ValueKey('live-permission-note-$keyId'),
                controller: _note,
                maxLines: 3,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: l10n.livePermissionNoteHint,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (value) {
                  widget.live.setPermissionNote(
                    request.id,
                    value,
                    owner: child,
                  );
                  setState(() {});
                },
              ),
              const SizedBox(height: 8),
              // Wrap, not Row: the confirm/cancel labels are long and the card
              // is narrow on phones (and in RTL/large text), where a Row
              // overflows horizontally.
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: () => setState(() {
                      _showNote = false;
                      _note.clear();
                      widget.live.setPermissionNote(
                        request.id,
                        '',
                        owner: child,
                      );
                    }),
                    child: Text(
                      MaterialLocalizations.of(context).cancelButtonLabel,
                    ),
                  ),
                  FilledButton(
                    key: ValueKey('live-permission-note-send-$keyId'),
                    onPressed: enabled && _note.text.isNotEmpty
                        ? () => _reply(
                            ApprovalResponse('reject', note: _note.text),
                          )
                        : null,
                    child: Text(l10n.livePermissionRejectSend),
                  ),
                ],
              ),
            ],
            if (busy)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(),
              ),
            if (notice != null)
              Semantics(
                liveRegion: true,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    notice,
                    key: ValueKey('live-permission-notice-$keyId'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
