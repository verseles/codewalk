import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/chat_session.dart';

/// Chat input widget
class ChatInputWidget extends StatefulWidget {
  const ChatInputWidget({
    super.key,
    required this.onSendMessage,
    this.enabled = true,
    this.focusNode,
    this.showAttachmentButton = false,
  });

  final FutureOr<void> Function(String message, List<FileInputPart> attachments)
  onSendMessage;
  final bool enabled;
  final FocusNode? focusNode;
  final bool showAttachmentButton;

  @override
  State<ChatInputWidget> createState() => _ChatInputWidgetState();
}

class _ChatInputWidgetState extends State<ChatInputWidget> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _internalFocusNode = FocusNode();
  final List<FileInputPart> _attachments = <FileInputPart>[];
  bool _isComposing = false;
  bool _isSending = false;

  FocusNode get _effectiveFocusNode => widget.focusNode ?? _internalFocusNode;

  @override
  void dispose() {
    _controller.dispose();
    _internalFocusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ChatInputWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.showAttachmentButton && _attachments.isNotEmpty) {
      setState(() {
        _attachments.clear();
      });
    }
  }

  Future<void> _handleSendMessage() async {
    final text = _controller.text.trim();
    if (!widget.enabled || _isSending) {
      return;
    }
    if (text.isEmpty && _attachments.isEmpty) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      await widget.onSendMessage(
        text,
        List<FileInputPart>.unmodifiable(_attachments),
      );
      if (!mounted) {
        return;
      }
      _controller.clear();
      setState(() {
        _isComposing = false;
        _attachments.clear();
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to attach files: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _handleTextChanged(String text) {
    setState(() {
      _isComposing = text.trim().isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final canSend =
        (_isComposing || _attachments.isNotEmpty) &&
        widget.enabled &&
        !_isSending;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_attachments.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List<Widget>.generate(_attachments.length, (index) {
                    final attachment = _attachments[index];
                    return InputChip(
                      avatar: Icon(
                        attachment.mime.startsWith('image/')
                            ? Icons.image_outlined
                            : Icons.picture_as_pdf_outlined,
                        size: 18,
                      ),
                      label: Text(attachment.filename ?? 'attachment'),
                      onDeleted: widget.enabled
                          ? () {
                              setState(() {
                                _attachments.removeAt(index);
                              });
                            }
                          : null,
                    );
                  }),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Row(
                children: [
                  if (widget.showAttachmentButton) ...[
                    IconButton.filledTonal(
                      onPressed: widget.enabled ? _showAttachmentOptions : null,
                      tooltip: 'Add attachment',
                      icon: const Icon(Icons.attach_file_rounded),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _effectiveFocusNode,
                      enabled: widget.enabled,
                      maxLines: null,
                      textInputAction: TextInputAction.newline,
                      keyboardType: TextInputType.multiline,
                      onChanged: _handleTextChanged,
                      onSubmitted: (_) => unawaited(_handleSendMessage()),
                      style: Theme.of(context).textTheme.bodyMedium,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(26),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(26),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: canSend
                        ? () => unawaited(_handleSendMessage())
                        : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(52, 52),
                      padding: EdgeInsets.zero,
                    ),
                    child: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Select Images'),
              onTap: () {
                Navigator.of(context).pop();
                unawaited(_pickImages());
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('Select PDF'),
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

  Future<void> _pickImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty || !mounted) {
      return;
    }
    _appendAttachments(result.files, forcePdf: false);
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['pdf'],
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty || !mounted) {
      return;
    }
    _appendAttachments(result.files, forcePdf: true);
  }

  void _appendAttachments(List<PlatformFile> files, {required bool forcePdf}) {
    final nextAttachments = <FileInputPart>[];
    for (final file in files) {
      final url = _resolveAttachmentUrl(file, forcePdf: forcePdf);
      if (url == null) {
        continue;
      }
      final mime = forcePdf ? 'application/pdf' : _resolveImageMime(file);
      nextAttachments.add(
        FileInputPart(
          mime: mime,
          url: url,
          filename: file.name.isEmpty ? null : file.name,
        ),
      );
    }

    if (nextAttachments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No valid files were selected')),
      );
      return;
    }

    setState(() {
      final dedupe = <String>{
        for (final existing in _attachments)
          '${existing.mime}|${existing.url}|${existing.filename ?? ""}',
      };
      for (final attachment in nextAttachments) {
        final key =
            '${attachment.mime}|${attachment.url}|'
            '${attachment.filename ?? ""}';
        if (dedupe.add(key)) {
          _attachments.add(attachment);
        }
      }
    });
  }

  String? _resolveAttachmentUrl(PlatformFile file, {required bool forcePdf}) {
    final mime = forcePdf ? 'application/pdf' : _resolveImageMime(file);
    if (file.bytes case final bytes?) {
      if (bytes.isEmpty) {
        return null;
      }
      return 'data:$mime;base64,${base64Encode(bytes)}';
    }

    final path = file.path;
    if (path == null || path.isEmpty) {
      return null;
    }
    return Uri.file(path).toString();
  }

  String _resolveImageMime(PlatformFile file) {
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
        return 'image/png';
    }
  }
}
