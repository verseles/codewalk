import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

import 'file_path_detector.dart';

/// Detects paths in ordinary Markdown prose, outside fenced and inline code.
class FilePathSyntax extends md.InlineSyntax {
  FilePathSyntax()
    : super(
        r'(?<![/\w.:])(?:(?:\.{1,2}/|~/)?(?:[\w.\-]+/)+[\w.\-]+\.(?:'
        '${FilePathDetector.extensionPattern}'
        r'))(?::(\d+))?(?::(\d+))?(?![/\w])',
      );

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final detected = FilePathDetector().detect(match[0]!);
    if (detected.length != 1 || detected.single.fullText != match[0]) {
      return false;
    }
    final file = detected.single;
    parser.addNode(
      md.Element('filepath', <md.Node>[md.Text(file.fullText)])
        ..attributes['path'] = file.path
        ..attributes['line'] = file.lineNumber?.toString() ?? ''
        ..attributes['col'] = file.columnNumber?.toString() ?? '',
    );
    return true;
  }
}

/// Builds clickable file spans without retaining gesture resources itself.
class FilePathBuilder extends MarkdownElementBuilder {
  FilePathBuilder({required this.onFile});

  final ValueChanged<FilePathMatch> onFile;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final path = element.attributes['path'];
    if (path == null || path.isEmpty) return null;
    return FilePathLink(
      file: FilePathMatch(
        fullText: element.textContent,
        path: path,
        lineNumber: int.tryParse(element.attributes['line'] ?? ''),
        columnNumber: int.tryParse(element.attributes['col'] ?? ''),
      ),
      onFile: onFile,
      style: element.attributes['inlineCode'] == 'true'
          ? MarkdownStyleSheet.fromTheme(Theme.of(context)).code
          : parentStyle ?? preferredStyle,
    );
  }
}

/// Extends the parser's inline-code syntax so fenced code is never linkified.
class InlineFilePathSyntax extends md.CodeSyntax {
  @override
  bool onMatch(md.InlineParser parser, Match match) {
    var text = match[2]!.replaceAll('\n', ' ');
    if (text.trim().isNotEmpty && text.startsWith(' ') && text.endsWith(' ')) {
      text = text.substring(1, text.length - 1);
    }
    final files = FilePathDetector().detect(text);
    if (files.length != 1 || files.single.fullText != text) {
      return super.onMatch(parser, match);
    }
    final file = files.single;
    parser.addNode(
      md.Element('filepath', <md.Node>[md.Text(file.fullText)])
        ..attributes['path'] = file.path
        ..attributes['line'] = file.lineNumber?.toString() ?? ''
        ..attributes['col'] = file.columnNumber?.toString() ?? ''
        ..attributes['inlineCode'] = 'true',
    );
    return true;
  }
}

/// Owns its text recognizer for exactly the lifetime of this file span.
class FilePathLink extends StatefulWidget {
  const FilePathLink({
    super.key,
    required this.file,
    required this.onFile,
    this.style,
  });

  final FilePathMatch file;
  final ValueChanged<FilePathMatch> onFile;
  final TextStyle? style;

  @override
  State<FilePathLink> createState() => _FilePathLinkState();
}

class _FilePathLinkState extends State<FilePathLink> {
  late final TapGestureRecognizer _recognizer;

  @override
  void initState() {
    super.initState();
    _recognizer = TapGestureRecognizer()
      ..onTap = () => widget.onFile(widget.file);
  }

  @override
  void dispose() {
    _recognizer.onTap = null;
    _recognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Text.rich(
      TextSpan(
        text: widget.file.fullText,
        style: (widget.style ?? const TextStyle()).copyWith(
          color: color,
          decoration: TextDecoration.underline,
          decorationColor: color.withValues(alpha: 0.5),
        ),
        recognizer: _recognizer,
      ),
    );
  }
}
