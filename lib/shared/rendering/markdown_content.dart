import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

import 'file_path_detector.dart';
import 'file_path_markdown.dart';

typedef MarkdownLinkCallback =
    void Function(String text, String href, String? title);

/// Minimal GFM rendering bridge. Source content is never translated or edited.
/// Links and file spans emit callbacks; this bridge performs no navigation or
/// file I/O. Images remain text until the media-rendering port is available.
class MarkdownContent extends StatefulWidget {
  const MarkdownContent({
    super.key,
    required this.source,
    this.onLink,
    this.onFile,
  });

  final String source;
  final MarkdownLinkCallback? onLink;
  final ValueChanged<FilePathMatch>? onFile;

  @override
  State<MarkdownContent> createState() => _MarkdownContentState();
}

class _MarkdownContentState extends State<MarkdownContent> {
  late final Map<String, MarkdownElementBuilder> _builders = {
    'filepath': FilePathBuilder(onFile: _onFile),
  };

  void _onFile(FilePathMatch file) => widget.onFile?.call(file);

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: widget.source,
      extensionSet: md.ExtensionSet.gitHubFlavored,
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)),
      inlineSyntaxes: [InlineFilePathSyntax(), FilePathSyntax()],
      builders: _builders,
      onTapLink: (text, href, title) {
        if (href != null) widget.onLink?.call(text, href, title);
      },
      imageBuilder: (uri, title, alt) =>
          Text('![${alt ?? ''}]($uri${title == null ? '' : ' "$title"'})'),
    );
  }
}
