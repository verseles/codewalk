import 'dart:async';

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../platform/sessions/attachment_staging_store.dart';
import '../../shared/l10n/l10n_context.dart';
import '../../shared/media/attachment_picker.dart';
import '../../shared/media/attachment_sniff.dart';
import '../../shared/media/location_fix_source.dart';
import '../../shared/sessions/session_attachments.dart';
import '../../shared/widgets/app_indeterminate_progress.dart';
import '../../shared/widgets/app_snack_bar.dart';
import 'composer_attachments_controller.dart';
import 'composer_input.dart';
import 'location_picker_dialog.dart';

enum _AttachChoice { image, file, audio, location }

/// The composer's dedicated `+` attach button (#473). Opens a compact menu for
/// image, file, audio, and geographic location attachments, streaming selected
/// files into [AttachmentBlobRepository] via [ComposerAttachmentsController].
class ComposerAttachButton extends StatelessWidget {
  const ComposerAttachButton({
    super.key,
    required this.attachments,
    this.enabled = true,
    this.supportsAudio = true,
  });

  final ComposerAttachmentsController attachments;
  final bool enabled;
  final bool supportsAudio;

  void _showFailure(BuildContext context, AttachmentStageFailure failure) {
    final l10n = context.v2L10n;
    final message = switch (failure) {
      AttachmentStageFailure.tooMany => l10n.composerAttachTooMany(
        maxComposerAttachments,
      ),
      AttachmentStageFailure.tooLarge => l10n.composerAttachTooLarge,
      AttachmentStageFailure.emptyFile => l10n.composerAttachEmpty,
      AttachmentStageFailure.readFailed ||
      AttachmentStageFailure.storageFailed => l10n.composerAttachReadFailed,
    };
    showAppSnackBar(ScaffoldMessenger.maybeOf(context), message);
  }

  Future<void> _handleChoice(BuildContext context, _AttachChoice choice) async {
    final staging = context.read<AttachmentStagingStore?>();
    if (choice == _AttachChoice.location) {
      final locationSource = context.read<LocationFixSource?>();
      final point = await showLocationPickerDialog(
        context,
        locationSource: locationSource,
      );
      if (point == null || !context.mounted) return;
      final failure = await attachments.addLocation(
        point,
        storeOverride: staging,
      );
      if (failure != null && context.mounted) {
        _showFailure(context, failure);
      }
      return;
    }

    final picker = context.read<AttachmentPickerPort?>();
    final blobs = context.read<AttachmentBlobRepository?>();
    if (picker == null || blobs == null) {
      if (context.mounted) {
        _showFailure(context, AttachmentStageFailure.readFailed);
      }
      return;
    }
    final category = switch (choice) {
      _AttachChoice.image => AttachmentPickCategory.image,
      _AttachChoice.file => AttachmentPickCategory.file,
      _AttachChoice.audio => AttachmentPickCategory.audio,
      _AttachChoice.location => AttachmentPickCategory.file,
    };
    List<PickedAttachmentFile> picked;
    try {
      picked = await picker.pick(category, maxBytes: maxAttachmentFileBytes);
    } on Object {
      if (context.mounted) {
        _showFailure(context, AttachmentStageFailure.readFailed);
      }
      return;
    }
    if (picked.isEmpty || !context.mounted) return;
    final failure = await attachments.stagePickedFiles(
      picked,
      blobs,
      storeOverride: staging,
    );
    if (failure != null && context.mounted) {
      _showFailure(context, failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.v2L10n;
    return ListenableBuilder(
      listenable: attachments,
      builder: (context, _) {
        final active = enabled && !attachments.picking;
        return SizedBox.square(
          key: const ValueKey('composer-attach'),
          dimension: composerActionSize,
          child: PopupMenuButton<_AttachChoice>(
            tooltip: l10n.composerAttach,
            enabled: active,
            padding: EdgeInsets.zero,
            icon: attachments.picking
                ? const AppIndeterminateRing(size: 18, strokeWidth: 2)
                : const Icon(Symbols.add, size: 22),
            onSelected: (choice) => unawaited(_handleChoice(context, choice)),
            itemBuilder: (context) => [
              PopupMenuItem<_AttachChoice>(
                key: const ValueKey('composer-attach-image'),
                value: _AttachChoice.image,
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Symbols.image),
                  title: Text(l10n.composerAttachImage),
                ),
              ),
              PopupMenuItem<_AttachChoice>(
                key: const ValueKey('composer-attach-file'),
                value: _AttachChoice.file,
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Symbols.description),
                  title: Text(l10n.composerAttachFile),
                ),
              ),
              if (supportsAudio)
                PopupMenuItem<_AttachChoice>(
                  key: const ValueKey('composer-attach-audio'),
                  value: _AttachChoice.audio,
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Symbols.audio_file),
                    title: Text(l10n.composerAttachAudio),
                  ),
                ),
              PopupMenuItem<_AttachChoice>(
                key: const ValueKey('composer-attach-location'),
                value: _AttachChoice.location,
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Symbols.location_on),
                  title: Text(l10n.composerAttachLocation),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
