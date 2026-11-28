import 'dart:async';

import 'package:codewalk_core/codewalk_core.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../shared/l10n/generated/v2_localizations.dart';
import '../../shared/l10n/l10n_context.dart';
import '../../shared/voice/read_aloud.dart';
import '../../shared/widgets/app_indeterminate_progress.dart';
import '../../shared/widgets/app_snack_bar.dart';
import '../sessions/message_action_bar.dart';
import 'read_aloud_controller.dart';
import 'read_aloud_text.dart';

/// The reading key of [item] in [session].
String readAloudKey(SessionRef session, ItemId item) =>
    '${readAloudSessionPrefix(session)}${item.value}';

/// The start every reading key of [session] shares.
String readAloudSessionPrefix(SessionRef session) => '${session.storageKey}|';

/// Stops a reading of [session], as when a prompt is sent there or it closes.
void stopReadingIn(BuildContext context, SessionRef session) {
  final controller = Provider.of<ReadAloudController?>(context, listen: false);
  final prefix = readAloudSessionPrefix(session);
  unawaited(controller?.stopWhere((key) => key.startsWith(prefix)));
}

/// Stops [controller]'s reading of [session] once the widget tree is free
/// again, as when a page that shows the session goes away (#541).
void stopReadingAfter(ReadAloudController? controller, SessionRef session) {
  if (controller == null) return;
  final prefix = readAloudSessionPrefix(session);
  scheduleMicrotask(
    () => unawaited(controller.stopWhere((key) => key.startsWith(prefix))),
  );
}

/// Read aloud for [item] in its bar (#541): a whole message with words to
/// speak, while the setting is on; Stop reading on the message being read.
MessageAction? readAloudAction(
  BuildContext context,
  SessionRef session,
  TimelineItem item,
) {
  final controller = Provider.of<ReadAloudController?>(context);
  if (controller == null || !controller.offered) return null;
  final text = switch (item) {
    UserInput(:final text, :final confirmed) when confirmed => text,
    AssistantText(:final text, :final complete, :final prefixMissing)
        when complete && !prefixMissing =>
      text,
    _ => null,
  };
  if (text == null || text.trim().isEmpty) return null;
  final key = readAloudKey(session, item.id);
  final l10n = context.v2L10n;
  final reading = controller.phaseOf(key) != ReadAloudPhase.idle;
  return MessageAction(
    id: MessageActionId.readAloud,
    label: reading ? l10n.readAloudStop : l10n.readAloudAction,
    icon: reading ? Symbols.stop_circle : Symbols.volume_up,
    onSelected: (context) {
      if (reading) {
        unawaited(controller.stop());
        return;
      }
      unawaited(_read(context, controller, key, text));
    },
  );
}

Future<void> _read(
  BuildContext context,
  ReadAloudController controller,
  String key,
  String text,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final l10n = context.v2L10n;
  final router = GoRouter.maybeOf(context);
  final failure = await controller.read(key, text);
  if (failure == null) return;
  showReadAloudFailure(messenger, l10n, failure, router);
}

/// Says why a reading failed, with the way to its settings.
void showReadAloudFailure(
  ScaffoldMessengerState? messenger,
  V2Localizations l10n,
  SpeechFailure failure,
  GoRouter? router,
) {
  messenger?.hideCurrentSnackBar();
  showAppSnackBar(
    messenger,
    readAloudFailureText(l10n, failure),
    action: router == null
        ? null
        : SnackBarAction(
            label: l10n.readAloudSettings,
            onPressed: () => router.push('/settings?section=readAloud'),
          ),
  );
}

/// The controls of the message being read in [session]: a spinner while
/// the audio is prepared, then Pause or Resume, and Stop (#541).
class ReadAloudPill extends StatelessWidget {
  const ReadAloudPill({super.key, required this.session});

  final SessionRef session;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ReadAloudController?>();
    final active = controller?.active;
    if (controller == null ||
        active == null ||
        !active.startsWith(readAloudSessionPrefix(session))) {
      return const SizedBox.shrink();
    }
    final l10n = context.v2L10n;
    final scheme = Theme.of(context).colorScheme;
    final phase = controller.phase;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final router = GoRouter.maybeOf(context);
    return Semantics(
      container: true,
      liveRegion: true,
      label: phase == ReadAloudPhase.preparing
          ? l10n.readAloudPreparing
          : l10n.readAloudAction,
      child: Material(
        key: const ValueKey('read-aloud-pill'),
        elevation: 3,
        color: scheme.surfaceContainerHigh,
        shape: StadiumBorder(side: BorderSide(color: scheme.outlineVariant)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (phase == ReadAloudPhase.preparing)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: AppIndeterminateRing(size: 20),
                )
              else if (phase == ReadAloudPhase.playing)
                IconButton(
                  key: const ValueKey('read-aloud-pause'),
                  tooltip: l10n.readAloudPause,
                  icon: const Icon(Symbols.pause),
                  onPressed: () => unawaited(controller.pause()),
                )
              else
                IconButton(
                  key: const ValueKey('read-aloud-resume'),
                  tooltip: l10n.readAloudResume,
                  icon: const Icon(Symbols.play_arrow),
                  onPressed: () async {
                    final failure = await controller.resume();
                    if (failure != null) {
                      showReadAloudFailure(messenger, l10n, failure, router);
                    }
                  },
                ),
              IconButton(
                key: const ValueKey('read-aloud-stop'),
                tooltip: l10n.readAloudStop,
                icon: const Icon(Symbols.stop),
                onPressed: () => unawaited(controller.stop()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
