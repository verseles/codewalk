part of '../chat_input_widget.dart';

extension _ChatInputAttachmentController on _ChatInputWidgetState {
  void _showAttachmentOptions() {
    if (!widget.allowImageAttachment && !widget.allowPdfAttachment) {
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            if (widget.allowImageAttachment && widget.allowPdfAttachment)
              ListTile(
                leading: const Icon(Symbols.attach_file_rounded),
                title: Text(context.l10n.composerAttachFiles),
                onTap: () {
                  Navigator.of(context).pop();
                  unawaited(_pickSupportedAttachments());
                },
              ),
            if (widget.allowImageAttachment)
              ListTile(
                leading: const Icon(Symbols.photo_library),
                title: Text(context.l10n.composerSelectImages),
                onTap: () {
                  Navigator.of(context).pop();
                  unawaited(_pickImages());
                },
              ),
            if (widget.allowPdfAttachment)
              ListTile(
                leading: const Icon(Symbols.picture_as_pdf),
                title: Text(context.l10n.composerSelectPdf),
                onTap: () {
                  Navigator.of(context).pop();
                  unawaited(_pickPdf());
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickSupportedAttachments() async {
    final result = await _pickAttachmentFiles(
      type: FileType.custom,
      allowedExtensions: const <String>[
        'jpg',
        'jpeg',
        'png',
        'gif',
        'webp',
        'bmp',
        'heic',
        'heif',
        'pdf',
      ],
    );
    if (result == null || result.isEmpty || !mounted) {
      return;
    }
    await _appendAttachments(result, allowImageMimeFallback: false);
  }

  Future<void> _pickImages() async {
    final result = await _pickAttachmentFiles(type: FileType.image);
    if (result == null || result.isEmpty || !mounted) {
      return;
    }
    await _appendAttachments(result);
  }

  Future<void> _pickPdf() async {
    final result = await _pickAttachmentFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['pdf'],
    );
    if (result == null || result.isEmpty || !mounted) {
      return;
    }
    await _appendAttachments(result, forceMime: 'application/pdf');
  }

  Future<List<PlatformFile>?> _pickAttachmentFiles({
    required FileType type,
    List<String>? allowedExtensions,
  }) async {
    try {
      // file_picker v12 returns the picked files directly (empty on
      // cancel, multiple allowed by default); bytes are read on demand
      // via readAsBytes().
      return await FilePicker.pickFiles(
        type: type,
        allowedExtensions: allowedExtensions,
      );
    } on PlatformException {
      if (mounted) {
        _showAttachmentSnack(context.l10n.msgNoValidFilesSelected);
      }
    } on MissingPluginException {
      if (mounted) {
        _showAttachmentSnack(context.l10n.msgNoValidFilesSelected);
      }
    } on UnsupportedError {
      if (mounted) {
        _showAttachmentSnack(context.l10n.msgNoValidFilesSelected);
      }
    }
    return null;
  }

  Future<void> _appendAttachments(
    List<PlatformFile> files, {
    String? forceMime,
    bool allowImageMimeFallback = true,
  }) async {
    final nextAttachments = <FileInputPart>[];
    var skippedCount = 0;
    for (final file in files) {
      final mime =
          forceMime ??
          _resolveAttachmentMime(
            file,
            allowImageFallback: allowImageMimeFallback,
          );
      if (mime == null) {
        skippedCount += 1;
        continue;
      }
      final url = await _resolveAttachmentUrl(file, mime: mime);
      if (url == null) {
        skippedCount += 1;
        continue;
      }
      if (!_isMimeAllowed(mime)) {
        skippedCount += 1;
        continue;
      }
      nextAttachments.add(
        FileInputPart(
          mime: mime,
          url: url,
          filename: file.name.isEmpty ? null : file.name,
        ),
      );
    }

    if (nextAttachments.isEmpty) {
      if (!mounted) {
        return;
      }
      _showAttachmentSnack(context.l10n.msgNoValidFilesSelected);
      return;
    }

    var addedCount = 0;
    // The per-file byte reads above await platform I/O; the composer may
    // have been disposed while waiting (unawaited sheet fire-and-forget).
    if (!mounted) {
      return;
    }
    _setState(() {
      final dedupe = <(String, String, String?)>{
        for (final existing in _attachments)
          (existing.mime, existing.url, existing.filename),
      };
      for (final attachment in nextAttachments) {
        final key = (attachment.mime, attachment.url, attachment.filename);
        if (dedupe.add(key)) {
          _attachments.add(attachment);
          addedCount += 1;
        }
      }
    });
    if (addedCount > 0) {
      _notifyDraftChanged();
    }
    if (skippedCount > 0 && mounted) {
      _showAttachmentSnack(context.l10n.msgSomeSelectedFilesNotAttached);
    }
  }

  bool _isMimeAllowed(String mime) {
    if (mime.startsWith('image/')) {
      return widget.allowImageAttachment;
    }
    if (mime == 'application/pdf') {
      return widget.allowPdfAttachment;
    }
    return false;
  }

  Future<String?> _resolveAttachmentUrl(
    PlatformFile file, {
    required String mime,
  }) async {
    // Client-local paths are meaningless (and potentially unsafe) on a
    // remote OpenCode server. Server-side paths enter as FileInputPart values
    // elsewhere; composer picks, drops and pastes must always carry bytes.
    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        return null;
      }
      return 'data:$mime;base64,${base64Encode(bytes)}';
    } on Exception {
      return null;
    }
  }

  String? _resolveAttachmentMime(
    PlatformFile file, {
    required bool allowImageFallback,
  }) {
    if (_isPdf(file)) {
      return 'application/pdf';
    }
    return _resolveImageMime(file) ?? (allowImageFallback ? 'image/png' : null);
  }

  bool _isPdf(PlatformFile file) {
    return (file.extension ?? '').trim().toLowerCase() == 'pdf';
  }

  String? _resolveImageMime(PlatformFile file) {
    final ext = (file.extension ?? '').trim().toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'bmp':
        return 'image/bmp';
      case 'heic':
        return 'image/heic';
      case 'heif':
        return 'image/heif';
      default:
        return null;
    }
  }

  void _showAttachmentSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
