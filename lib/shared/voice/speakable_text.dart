import 'package:markdown/markdown.dart' as md;

/// The words of a message as they are read aloud (#541): Markdown and HTML
/// markers, fenced and indented code, tables, images and math blocks are
/// left out; link text, inline code and list items stay, one sentence or
/// block per line, with no run of spaces.
String speakableText(String markdown) {
  final document = md.Document(
    extensionSet: md.ExtensionSet.gitHubFlavored,
    encodeHtml: false,
  );
  final nodes = document.parseLines(
    markdown.replaceAll('\r\n', '\n').split('\n'),
  );
  final out = StringBuffer();
  for (final node in nodes) {
    _block(node, out);
  }
  return out
      .toString()
      .split('\n')
      .map((line) => line.replaceAll(RegExp(r'[ \t]+'), ' ').trim())
      .where((line) => line.isNotEmpty)
      .join('\n');
}

const _skipped = {'pre', 'table', 'img', 'hr', 'script', 'style'};
const _blocks = {
  'p',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'li',
  'blockquote',
  'ul',
  'ol',
  'div',
};

void _block(md.Node node, StringBuffer out) {
  if (node is md.Text) {
    out.write(_plain(node.text));
    return;
  }
  if (node is! md.Element) return;
  if (_skipped.contains(node.tag)) return;
  // Math blocks ($$ … $$) are not speech.
  if (node.tag == 'p' && _isMathBlock(node)) return;
  final children = node.children ?? const <md.Node>[];
  for (final child in children) {
    _block(child, out);
  }
  if (_blocks.contains(node.tag)) out.write('\n');
  if (node.tag == 'br') out.write('\n');
}

bool _isMathBlock(md.Element paragraph) {
  final text = paragraph.textContent.trim();
  return text.length > 4 && text.startsWith(r'$$') && text.endsWith(r'$$');
}

/// Text inside a node, without HTML tags the parser left as text.
String _plain(String text) => text.replaceAll(RegExp('<[^>]+>'), ' ');
