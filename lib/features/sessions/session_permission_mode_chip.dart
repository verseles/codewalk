import 'package:flutter/material.dart';

import '../../shared/l10n/generated/v2_localizations.dart';
import '../../shared/l10n/l10n_context.dart';
import '../../shared/sessions/permission_mode.dart';
import '../../shared/sessions/session_unrestricted.dart';
import 'session_live_controller.dart';
import 'session_unrestricted_dialog.dart';

/// The per-session permission mode, showing only the mode the store has
/// acknowledged (ADR-059). Picking a value writes an override through the
/// lease's policy; the label never changes before that write succeeds. When
/// the session's own rules end with the allow-everything rule, the chip shows
/// Unrestricted instead, whoever added it, because that rule is what applies.
class SessionPermissionModeChip extends StatelessWidget {
  const SessionPermissionModeChip({
    super.key,
    required this.live,
    this.compact,
  });

  final SessionLiveController live;

  /// Icon-only; by default below 600 dp of window width.
  final bool? compact;

  @override
  Widget build(BuildContext context) {
    if (live.permissionModes == null) return const SizedBox.shrink();
    final l10n = context.v2L10n;
    return ListenableBuilder(
      listenable: live,
      builder: (context, _) {
        final narrow = compact ?? MediaQuery.sizeOf(context).width < 600;
        final state = live.permissionModeState;
        final mode = state.mode;
        final unrestricted = live.supportsUnrestricted
            ? live.unrestrictedState
            : const SessionUnrestrictedState();
        final inEffect = unrestricted.inEffect;
        final rulesActions =
            live.supportsUnrestricted &&
            (live.canEnableUnrestricted ||
                live.canDisableUnrestricted ||
                live.canRefreshUnrestricted);
        final enabled = live.canChangePermissionMode || rulesActions;
        final label = inEffect
            ? l10n.livePermissionModeUnrestricted
            : switch (mode) {
                PermissionMode.ask => l10n.livePermissionModeAsk,
                PermissionMode.allowAll => l10n.livePermissionModeAllowAll,
                null => l10n.livePermissionModeUnavailable,
              };
        final external =
            unrestricted.phase == SessionUnrestrictedPhase.elsewhere ||
            unrestricted.phase == SessionUnrestrictedPhase.conflict;
        // A rule still in effect after a failed read has no known owner.
        final source = inEffect
            ? switch (unrestricted.phase) {
                SessionUnrestrictedPhase.on => l10n.livePermissionModeSession,
                _ when external => l10n.livePermissionModeUnrestrictedExternal,
                _ => null,
              }
            : switch (state.source) {
                PermissionModeSource.session => l10n.livePermissionModeSession,
                PermissionModeSource.global || PermissionModeSource.defaultOn =>
                  l10n.livePermissionModeDefault,
                null => null,
              };
        final semantics = [l10n.livePermissionMode, label, ?source].join(': ');
        final busy = live.savingPermissionMode || unrestricted.busy;
        final scheme = Theme.of(context).colorScheme;
        return Semantics(
          button: true,
          enabled: enabled,
          label: semantics,
          child: PopupMenuButton<Object?>(
            key: const ValueKey('live-permission-mode'),
            enabled: enabled,
            tooltip: semantics,
            onSelected: (value) => _select(context, value),
            itemBuilder: (context) => [
              _item(context, state, PermissionMode.ask, l10n),
              _item(context, state, PermissionMode.allowAll, l10n),
              if (state.source == PermissionModeSource.session)
                PopupMenuItem<Object?>(
                  value: _useDefault,
                  enabled: live.canChangePermissionMode,
                  child: Text(l10n.livePermissionModeUseDefault),
                ),
              if (live.supportsUnrestricted) ...[
                const PopupMenuDivider(),
                if (unrestricted.phase == SessionUnrestrictedPhase.on)
                  PopupMenuItem<Object?>(
                    key: const ValueKey('live-unrestricted-off'),
                    value: _turnOff,
                    enabled: live.canDisableUnrestricted,
                    child: Text(l10n.livePermissionModeUnrestrictedTurnOff),
                  )
                else if (external)
                  PopupMenuItem<Object?>(
                    enabled: false,
                    child: Text(l10n.livePermissionModeUnrestrictedExternal),
                  )
                else if (!unrestricted.inEffect)
                  PopupMenuItem<Object?>(
                    key: const ValueKey('live-unrestricted-on'),
                    value: _turnOn,
                    enabled: live.canEnableUnrestricted,
                    child: Text(l10n.livePermissionModeUnrestrictedTurnOn),
                  ),
                PopupMenuItem<Object?>(
                  key: const ValueKey('live-unrestricted-refresh'),
                  value: _refresh,
                  enabled: live.canRefreshUnrestricted,
                  child: Text(l10n.livePermissionModeRulesRefresh),
                ),
              ],
            ],
            child: Chip(
              avatar: busy
                  ? const SizedBox.square(
                      dimension: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      inEffect
                          ? Icons.lock_open
                          : switch (mode) {
                              PermissionMode.ask => Icons.pan_tool_outlined,
                              PermissionMode.allowAll => Icons.done_all,
                              null => Icons.error_outline,
                            },
                      color: inEffect ? scheme.onErrorContainer : null,
                    ),
              backgroundColor: inEffect ? scheme.errorContainer : null,
              // On compact widths the AppBar has no room for the full
              // label; the icon plus the tooltip and semantics carry it.
              label: narrow
                  ? const SizedBox.shrink()
                  : ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 200),
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: inEffect
                            ? TextStyle(color: scheme.onErrorContainer)
                            : null,
                      ),
                    ),
              visualDensity: VisualDensity.compact,
            ),
          ),
        );
      },
    );
  }

  static const _useDefault = Object();
  static const _turnOn = #turnOnUnrestricted;
  static const _turnOff = #turnOffUnrestricted;
  static const _refresh = #refreshRules;

  PopupMenuItem<Object?> _item(
    BuildContext context,
    SessionPermissionModeState state,
    PermissionMode mode,
    V2Localizations l10n,
  ) {
    final selected = state.mode == mode;
    final label = mode == PermissionMode.ask
        ? l10n.livePermissionModeAsk
        : l10n.livePermissionModeAllowAll;
    return PopupMenuItem<Object?>(
      value: mode,
      enabled: live.canChangePermissionMode,
      child: Row(
        children: [
          Icon(selected ? Icons.check : null, size: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  Future<void> _select(BuildContext context, Object? value) async {
    if (value == _turnOn || value == _turnOff || value == _refresh) {
      return _changeRules(context, value);
    }
    final applied = value == _useDefault
        ? await live.useDefaultPermissionMode()
        : value is PermissionMode
        ? await live.setPermissionMode(value)
        : true;
    if (applied || !context.mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(context.v2L10n.livePermissionModeFailed)),
    );
  }

  Future<void> _changeRules(BuildContext context, Object? value) async {
    if (value == _turnOn) {
      if (!await confirmSessionUnrestricted(context)) return;
      await live.enableUnrestricted();
    } else if (value == _turnOff) {
      await live.disableUnrestricted();
    } else {
      await live.refreshUnrestricted();
    }
    if (!context.mounted) return;
    final l10n = context.v2L10n;
    final state = live.unrestrictedState;
    final message = switch (state.notice) {
      SessionUnrestrictedNotice.refused => l10n.liveUnrestrictedRefused,
      SessionUnrestrictedNotice.unconfirmed => l10n.liveUnrestrictedUnconfirmed,
      SessionUnrestrictedNotice.changedElsewhere =>
        l10n.liveUnrestrictedChangedElsewhere,
      SessionUnrestrictedNotice.none
          when state.phase == SessionUnrestrictedPhase.unavailable =>
        l10n.liveUnrestrictedUnavailable,
      SessionUnrestrictedNotice.none
          when value == _turnOff &&
              state.phase == SessionUnrestrictedPhase.off =>
        l10n.liveUnrestrictedTurnedOff,
      SessionUnrestrictedNotice.none => null,
    };
    if (message == null) return;
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(message)));
  }
}
