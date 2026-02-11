import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SessionTitleInlineEditor extends StatefulWidget {
  const SessionTitleInlineEditor({
    super.key,
    required this.title,
    required this.editingValue,
    required this.onRename,
    this.textStyle,
    this.enabled = true,
  });

  final String title;
  final String editingValue;
  final Future<bool> Function(String title) onRename;
  final TextStyle? textStyle;
  final bool enabled;

  @override
  State<SessionTitleInlineEditor> createState() =>
      _SessionTitleInlineEditorState();
}

class _SessionTitleInlineEditorState extends State<SessionTitleInlineEditor> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode(debugLabel: 'session_title_editor');

  bool _editing = false;
  bool _saving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.editingValue;
  }

  @override
  void didUpdateWidget(covariant SessionTitleInlineEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_editing || _saving) {
      return;
    }
    if (oldWidget.editingValue != widget.editingValue) {
      _controller.text = widget.editingValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startEditing() {
    if (!widget.enabled || _saving) {
      return;
    }
    setState(() {
      _editing = true;
      _errorText = null;
      _controller.text = widget.editingValue;
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  void _cancelEditing() {
    if (_saving) {
      return;
    }
    setState(() {
      _editing = false;
      _errorText = null;
      _controller.text = widget.editingValue;
    });
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    final nextTitle = _controller.text.trim();
    if (nextTitle.isEmpty) {
      setState(() {
        _errorText = 'Title cannot be empty';
      });
      return;
    }

    setState(() {
      _saving = true;
      _errorText = null;
    });
    final ok = await widget.onRename(nextTitle);
    if (!mounted) {
      return;
    }
    if (!ok) {
      setState(() {
        _saving = false;
        _errorText = 'Failed to rename conversation';
      });
      return;
    }
    setState(() {
      _saving = false;
      _editing = false;
      _errorText = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_editing) {
      return Row(
        children: [
          Expanded(
            child: GestureDetector(
              onDoubleTap: widget.enabled ? _startEditing : null,
              child: Tooltip(
                message: widget.title,
                child: Text(
                  widget.title,
                  key: const ValueKey<String>('session_title_display'),
                  style: widget.textStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          IconButton(
            key: const ValueKey<String>('session_title_edit_button'),
            tooltip: 'Rename conversation',
            onPressed: widget.enabled ? _startEditing : null,
            icon: const Icon(Icons.edit_outlined, size: 18),
            visualDensity: VisualDensity.compact,
          ),
        ],
      );
    }

    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              _cancelEditing();
              return null;
            },
          ),
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey<String>('session_title_editor_field'),
                    controller: _controller,
                    focusNode: _focusNode,
                    autofocus: true,
                    enabled: !_saving,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _save(),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Conversation title',
                      errorText: _errorText,
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey<String>('session_title_save_button'),
                  tooltip: 'Save title',
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check, size: 18),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  key: const ValueKey<String>('session_title_cancel_button'),
                  tooltip: 'Cancel rename',
                  onPressed: _saving ? null : _cancelEditing,
                  icon: const Icon(Icons.close, size: 18),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
