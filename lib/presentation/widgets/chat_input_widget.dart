import 'package:flutter/material.dart';

/// Chat input widget
class ChatInputWidget extends StatefulWidget {
  const ChatInputWidget({
    super.key,
    required this.onSendMessage,
    this.enabled = true,
    this.focusNode,
  });

  final Function(String message) onSendMessage;
  final bool enabled;
  final FocusNode? focusNode;

  @override
  State<ChatInputWidget> createState() => _ChatInputWidgetState();
}

class _ChatInputWidgetState extends State<ChatInputWidget> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _internalFocusNode = FocusNode();
  bool _isComposing = false;

  FocusNode get _effectiveFocusNode => widget.focusNode ?? _internalFocusNode;

  @override
  void initState() {
    super.initState();
    _effectiveFocusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant ChatInputWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _internalFocusNode).removeListener(
        _handleFocusChange,
      );
      _effectiveFocusNode.addListener(_handleFocusChange);
    }
  }

  @override
  void dispose() {
    _effectiveFocusNode.removeListener(_handleFocusChange);
    _controller.dispose();
    _internalFocusNode.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleSendMessage() {
    final text = _controller.text.trim();
    if (text.isNotEmpty && widget.enabled) {
      widget.onSendMessage(text);
      _controller.clear();
      setState(() {
        _isComposing = false;
      });
    }
  }

  void _handleTextChanged(String text) {
    setState(() {
      _isComposing = text.trim().isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).colorScheme.surface.withOpacity(0.8),
            Theme.of(context).colorScheme.surface,
          ],
        ),
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Attachment button - modern design
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: widget.enabled ? _showAttachmentOptions : null,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Icon(
                        Icons.add_rounded,
                        color: widget.enabled
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant.withOpacity(0.5),
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Input field - modern design
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: 44,
                    maxHeight: 120,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(
                          context,
                        ).colorScheme.surfaceVariant.withOpacity(0.3),
                        Theme.of(
                          context,
                        ).colorScheme.surfaceVariant.withOpacity(0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: _effectiveFocusNode.hasFocus
                          ? Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.5)
                          : Theme.of(
                              context,
                            ).colorScheme.outline.withOpacity(0.2),
                      width: 1.5,
                    ),
                    boxShadow: _effectiveFocusNode.hasFocus
                        ? [
                            BoxShadow(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: TextField(
                    controller: _controller,
                    focusNode: _effectiveFocusNode,
                    enabled: widget.enabled,
                    maxLines: null,
                    textInputAction: TextInputAction.newline,
                    keyboardType: TextInputType.multiline,
                    onChanged: _handleTextChanged,
                    onSubmitted: (_) => _handleSendMessage(),
                    style: Theme.of(context).textTheme.bodyMedium,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant.withOpacity(0.6),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Send button - modern design
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  gradient: (_isComposing && widget.enabled)
                      ? LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(context).colorScheme.tertiary,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: (!_isComposing || !widget.enabled)
                      ? Theme.of(
                          context,
                        ).colorScheme.surfaceVariant.withOpacity(0.5)
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (_isComposing && widget.enabled)
                        ? Colors.transparent
                        : Theme.of(
                            context,
                          ).colorScheme.outline.withOpacity(0.2),
                  ),
                  boxShadow: (_isComposing && widget.enabled)
                      ? [
                          BoxShadow(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: (_isComposing && widget.enabled)
                        ? _handleSendMessage
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          _isComposing ? Icons.send_rounded : Icons.mic_rounded,
                          key: ValueKey(_isComposing),
                          color: (_isComposing && widget.enabled)
                              ? Colors.white
                              : Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant.withOpacity(0.5),
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Select Image'),
              onTap: () {
                Navigator.of(context).pop();
                _pickImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file),
              title: const Text('Select File'),
              onTap: () {
                Navigator.of(context).pop();
                _pickFile();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.of(context).pop();
                _takePhoto();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _pickImage() {
    // TODO: Implement image selection functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Image selection feature coming soon')),
    );
  }

  void _pickFile() {
    // TODO: Implement file selection functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('File selection feature coming soon')),
    );
  }

  void _takePhoto() {
    // TODO: Implement camera functionality
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Camera feature coming soon')));
  }
}
