part of '../chat_input_widget.dart';

const _composerClipboardChannel = MethodChannel('codewalk/composer_clipboard');
const _clipboardFilesTimeout = Duration(seconds: 2);

/// Drag and drop (#118) and clipboard files (#119) for the composer.
///
/// Both entry points end at [_appendAttachments], the same path the file
/// picker uses, so MIME rules, the model's allowed modalities, deduplication,
/// draft persistence and the "some items were ignored" message stay in one
/// place instead of being reimplemented per gesture.
extension _ChatInputExternalDropController on _ChatInputWidgetState {
  /// True where the host can hand external files to the app by dragging.
  ///
  /// Mobile keeps the picker as its flow, as the issue requires.
  bool get _supportsFileDrop {
    if (kIsWeb) {
      return true;
    }
    return defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows;
  }

  /// Whether a drop should be offered at all right now.
  ///
  /// A zone that looks receptive while the composer cannot accept files would
  /// be a lie, so the highlight never appears in those states.
  bool get _acceptsExternalFiles {
    if (!widget.enabled ||
        !widget.showAttachmentButton ||
        _mode != ChatComposerMode.normal ||
        !(ModalRoute.of(context)?.isCurrent ?? true)) {
      return false;
    }
    return widget.allowImageAttachment || widget.allowPdfAttachment;
  }

  /// Wraps the composer in a drop zone where the host supports file drags.
  Widget _wrapComposerWithExternalFiles(Widget composer) {
    if (!_supportsFileDrop) {
      return composer;
    }

    final Widget result = DropTarget(
      key: const ValueKey<String>('composer_drop_target'),
      enable: _acceptsExternalFiles,
      onDragEntered: (_) => _setDropHighlight(true),
      onDragExited: (_) => _setDropHighlight(false),
      onDragDone: (details) {
        _setDropHighlight(false);
        unawaited(_handleExternalDrop(details));
      },
      child: composer,
    );

    final colorScheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        result,
        if (_isDropHighlighted)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                key: const ValueKey<String>('composer_drop_highlight'),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.75),
                  border: Border.all(color: colorScheme.primary, width: 2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    context.l10n.composerDropHint,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _setDropHighlight(bool highlighted) {
    if (!mounted || _isDropHighlighted == highlighted) {
      return;
    }
    _setState(() => _isDropHighlighted = highlighted);
  }

  Future<void> _handleExternalDrop(DropDoneDetails details) async {
    if (!_acceptsExternalFiles) {
      return;
    }
    final fallbackName = context.l10n.composerPastedImageName;
    final files = <PlatformFile>[];
    var skipped = 0;
    for (final dropped in details.files) {
      final file = await _readDroppedFile(dropped, fallbackName: fallbackName);
      if (file == null) {
        skipped += 1;
        continue;
      }
      files.add(file);
    }
    if (!mounted || !_acceptsExternalFiles) {
      return;
    }
    if (files.isEmpty) {
      _showAttachmentSnack(context.l10n.msgNoValidFilesSelected);
      return;
    }
    await _appendAttachments(files, allowImageMimeFallback: false);
    if (skipped > 0 && mounted) {
      _showAttachmentSnack(context.l10n.msgSomeSelectedFilesNotAttached);
    }
  }

  Future<PlatformFile?> _readDroppedFile(
    DropItem dropped, {
    required String fallbackName,
  }) async {
    var scopedAccessStarted = false;
    final bookmark = dropped.extraAppleBookmark;
    try {
      if (!composerAttachmentNameOrMimeSupported(
        dropped.name,
        dropped.mimeType,
      )) {
        return null;
      }
      if (!kIsWeb &&
          defaultTargetPlatform == TargetPlatform.macOS &&
          bookmark != null &&
          bookmark.isNotEmpty) {
        scopedAccessStarted = await DesktopDrop.instance
            .startAccessingSecurityScopedResource(bookmark: bookmark);
      }
      final bytes = await dropped.readAsBytes();
      return composerFileFromBytes(
        bytes,
        name: dropped.name,
        fallbackName: fallbackName,
        mimeType: dropped.mimeType,
      );
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Failed to read a dropped or pasted file',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    } finally {
      if (scopedAccessStarted && bookmark != null) {
        try {
          await DesktopDrop.instance.stopAccessingSecurityScopedResource(
            bookmark: bookmark,
          );
        } catch (error, stackTrace) {
          AppLogger.warn(
            'Failed to release dropped file access',
            error: error,
            stackTrace: stackTrace,
          );
        }
      }
    }
  }

  Future<PlatformFile?> _readAndroidClipboardUri(
    String uri, {
    required String fallbackName,
  }) async {
    try {
      final payload = await _composerClipboardChannel
          .invokeMapMethod<String, dynamic>('readContentUri', <String, String>{
            'uri': uri,
          })
          .timeout(_clipboardFilesTimeout);
      final rawBytes = payload?['bytes'];
      if (rawBytes == null) {
        return null;
      }
      final bytes = rawBytes is Uint8List
          ? rawBytes
          : Uint8List.fromList(List<int>.from(rawBytes as List));
      return composerFileFromBytes(
        bytes,
        name: payload?['name']?.toString() ?? '',
        fallbackName: fallbackName,
        mimeType: payload?['mimeType']?.toString(),
      );
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Failed to read an Android clipboard URI',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<PlatformFile?> _readClipboardPath(
    String rawPath, {
    required String fallbackName,
  }) async {
    final path = rawPath.trim();
    if (path.isEmpty) {
      return null;
    }
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        path.toLowerCase().startsWith('content://')) {
      return _readAndroidClipboardUri(path, fallbackName: fallbackName);
    }
    var readablePath = path;
    if (path.toLowerCase().startsWith('file://')) {
      try {
        readablePath = Uri.parse(
          path,
        ).toFilePath(windows: defaultTargetPlatform == TargetPlatform.windows);
      } on FormatException {
        return null;
      } on UnsupportedError {
        return null;
      }
    }
    final name = composerFileName(readablePath, fallback: fallbackName);
    return _readDroppedFile(
      DropItemFile(readablePath, name: name),
      fallbackName: fallbackName,
    );
  }

  /// Attaches file clipboard data alongside the platform's normal text paste.
  Future<void> _attachClipboardFiles() async {
    if (!_acceptsExternalFiles) {
      return;
    }
    final fallbackName = context.l10n.composerPastedImageName;
    final collected = <PlatformFile>[];
    var fileCandidates = 0;
    var skipped = 0;

    try {
      final paths = await Pasteboard.files().timeout(_clipboardFilesTimeout);
      fileCandidates = paths.length;
      for (final path in paths) {
        final file = await _readClipboardPath(path, fallbackName: fallbackName);
        if (file != null) {
          collected.add(file);
        } else {
          skipped += 1;
        }
      }
    } catch (error, stackTrace) {
      // A clipboard that cannot report files must not cost us the image.
      AppLogger.warn(
        'Failed to read files from the clipboard',
        error: error,
        stackTrace: stackTrace,
      );
    }

    if (collected.isEmpty) {
      try {
        final image = await Pasteboard.image;
        if (image != null) {
          final file = composerFileFromImageBytes(
            image,
            baseName: fallbackName,
          );
          if (file != null) {
            collected.add(file);
          }
        }
      } catch (error, stackTrace) {
        AppLogger.warn(
          'Failed to read an image from the clipboard',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    if (!mounted || !_acceptsExternalFiles) {
      return;
    }
    if (collected.isEmpty) {
      if (fileCandidates > 0) {
        _showAttachmentSnack(context.l10n.msgNoValidFilesSelected);
      }
      return;
    }
    await _appendAttachments(collected, allowImageMimeFallback: false);
    if (skipped > 0 && mounted) {
      _showAttachmentSnack(context.l10n.msgSomeSelectedFilesNotAttached);
    }
  }
}
