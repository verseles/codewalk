import 'package:flutter/material.dart';

import '../../shared/l10n/generated/v2_localizations.dart';
import '../../shared/l10n/l10n_context.dart';
import '../../shared/sessions/permission_mode.dart';
import 'session_live_controller.dart';

/// The per-session permission mode, showing only the mode the store has
/// acknowledged (ADR-059). Picking a value writes an override through the
/// lease's policy; the label never changes before that write succeeds.
class SessionPermissionModeChip extends StatelessWidget {
  const SessionPermissionModeChip({super.key, required this.live});

  final SessionLiveController live;

  @override
  Widget build(BuildContext context) {
    if (live.permissionModes == null) return const SizedBox.shrink();
    final l10n = context.v2L10n;
    return ListenableBuilder(
      listenable: live,
      builder: (context, _) {
        final narrow = MediaQuery.sizeOf(context).width < 600;
        final state = live.permissionModeState;
        final mode = state.mode;
        final enabled = live.canChangePermissionMode;
        final label = switch (mode) {
          PermissionMode.ask => l10n.livePermissionModeAsk,
          PermissionMode.allowAll => l10n.livePermissionModeAllowAll,
          null => l10n.livePermissionModeUnavailable,
        };
        final source = switch (state.source) {
          PermissionModeSource.session => l10n.livePermissionModeSession,
          PermissionModeSource.global ||
          PermissionModeSource.defaultOn => l10n.livePermissionModeDefault,
          null => null,
        };
        final semantics = [l10n.livePermissionMode, label, ?source].join(': ');
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
                  child: Text(l10n.livePermissionModeUseDefault),
                ),
            ],
            child: Chip(
              avatar: live.savingPermissionMode
                  ? const SizedBox.square(
                      dimension: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(switch (mode) {
                      PermissionMode.ask => Icons.pan_tool_outlined,
                      PermissionMode.allowAll => Icons.done_all,
                      null => Icons.error_outline,
                    }),
              // On compact widths the AppBar has no room for the full
              // label; the icon plus the tooltip and semantics carry it.
              label: narrow
                  ? const SizedBox.shrink()
                  : ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 200),
                      child: Text(label, overflow: TextOverflow.ellipsis),
                    ),
              visualDensity: VisualDensity.compact,
            ),
          ),
        );
      },
    );
  }

  static const _useDefault = Object();

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
}
