/// Replaces credential-looking values in free text before it is stored or
/// shown. It is a finite, best-effort rule, not a guarantee that no secret
/// remains: it removes the forms a session commonly prints (assignments,
/// authorization headers, command flags, URL user info, private-key blocks and
/// well-known token shapes) and leaves ordinary words alone.
///
/// The replacement is [credentialRedaction]; applying the function twice
/// changes nothing more.
String redactCredentialText(String text) {
  var result = text;
  for (final rule in _rules) {
    result = result.replaceAllMapped(rule.pattern, rule.replace);
  }
  return result;
}

/// Redacts [full] with full surrounding context and returns the portion
/// corresponding to UTF-16 code-unit range `[sliceStart, sliceEnd)`.
///
/// Any credential or multi-line private-key block that starts before
/// [sliceStart] and crosses into the slice is excluded from the returned slice
/// (never leaking its secret tail), and any match starting inside the slice and
/// crossing [sliceEnd] is included as its redacted replacement.
String redactCredentialSlice(String full, int sliceStart, int sliceEnd) {
  var text = full;
  var s = sliceStart.clamp(0, text.length);
  var e = sliceEnd.clamp(s, text.length);
  for (final rule in _rules) {
    final matches = rule.pattern.allMatches(text);
    if (matches.isEmpty) continue;
    final out = StringBuffer();
    var cursor = 0;
    var nextS = s;
    var nextE = e;
    for (final m in matches) {
      out.write(text.substring(cursor, m.start));
      final rep = rule.replace(m);
      out.write(rep);
      final repEnd = out.length;
      final delta = rep.length - (m.end - m.start);
      if (m.end <= s) {
        nextS += delta;
      } else if (m.start < s) {
        // Match crosses sliceStart: advance past the redacted replacement so
        // the second half of a split secret or PEM block never leaks.
        nextS = repEnd;
      }
      if (m.end <= e) {
        nextE += delta;
      } else if (m.start < e) {
        // Match crosses sliceEnd: extend to cover the redacted replacement.
        nextE = repEnd;
      }
      cursor = m.end;
    }
    out.write(text.substring(cursor));
    text = out.toString();
    s = nextS.clamp(0, text.length);
    e = nextE.clamp(s, text.length);
  }
  return text.substring(s, e);
}

const credentialRedaction = '[redacted]';

final class _Rule {
  const _Rule(this.pattern, this.replace);
  final RegExp pattern;
  final String Function(Match) replace;
}

String _keepLabel(Match m) => '${m[1]}$credentialRedaction';

const _names =
    r'(?:password|passwd|secret|client[_-]?secret|api[_-]?key|x-api-key|'
    r'access[_-]?token|refresh[_-]?token|auth[_-]?token|id[_-]?token|token|'
    r'secret[_-]?access[_-]?key|private[_-]?key)';

/// A quoted value, escapes included, through its closing quote or the end of
/// the text.
const _double = r'"(?:[^"\\]|\\.)*(?:"|\\?$)';
const _single = r"'(?:[^'\\]|\\.)*(?:'|\\?$)";

/// A value: double-quoted, single-quoted, or up to a separator.
const _value = '($_double|$_single|[^\\s,;&]+)';

/// The schemes of an authorization header.
const _schemes = '(?:bearer|basic|token|digest|negotiate)';

/// Not a value this rule already replaced.
const _fresh = r'(?!\[redacted\])';

final _rules = <_Rule>[
  // A private-key block, through its end marker or the end of the text.
  _Rule(
    RegExp(
      r'-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----[\s\S]*?'
      r'(?:-----END [A-Z0-9 ]*PRIVATE KEY-----|$)',
    ),
    (_) => credentialRedaction,
  ),
  // An authorization header or variable: its scheme stays and its credential
  // goes, whatever its length or case. A Digest credential is a list of
  // parameters, so the rest of its line goes; a quoted one goes whole.
  _Rule(
    RegExp(
      '(\\b(?:[A-Za-z0-9]+[_-])*authorization\\s*[:=]\\s*)'
      '(?!(?:$_schemes\\s+)?\\[redacted\\]|"\\[redacted\\]")'
      '(?:(digest\\s+)[^\\r\\n]*|'
      '((?:$_schemes\\s+)?)($_double|$_single|[^\\s"\',;]+))',
      caseSensitive: false,
    ),
    (m) => m[2] != null
        ? '${m[1]}${m[2]}$credentialRedaction'
        : m[4]!.startsWith('"')
        ? '${m[1]}${m[3]}"$credentialRedaction"'
        : '${m[1]}${m[3]}$credentialRedaction',
  ),
  // An authorization scheme and its credential in other text.
  _Rule(
    RegExp(
      '\\b((?:bearer|basic)\\s+)$_fresh[A-Za-z0-9._~+/=-]{8,}',
      caseSensitive: false,
    ),
    _keepLabel,
  ),
  // A command flag that carries a credential: `--token value`, `--token=value`.
  _Rule(
    RegExp(
      '(--(?:password|passwd|token|api-key|apikey|secret|client-secret|'
      'auth-token)(?:=|\\s+))$_fresh$_value',
      caseSensitive: false,
    ),
    _keepLabel,
  ),
  // A quoted JSON property: `"password": "value"`.
  _Rule(
    RegExp(
      '("(?:[A-Za-z0-9]+[_-])*(?:$_names|(?:proxy-)?authorization)"\\s*:\\s*)'
      '"$_fresh(?:[^"\\\\]|\\\\.)*(?:"|\\\\?\$)',
      caseSensitive: false,
    ),
    (m) => '${m[1]}"$credentialRedaction"',
  ),
  // An assignment: `password=value`, `API_KEY: value`, `export TOKEN=value`.
  _Rule(
    RegExp(
      '(\\b(?:[A-Za-z0-9]+[_-])*$_names\\s*[:=]\\s*)$_fresh$_value',
      caseSensitive: false,
    ),
    _keepLabel,
  ),
  // User info in a URL: `scheme://user:secret@host`.
  _Rule(
    RegExp(r'(\b[a-zA-Z][a-zA-Z0-9+.-]*://)[^\s/@:]+:[^\s/@]+@'),
    (m) => '${m[1]}$credentialRedaction@',
  ),
  // Well-known token shapes.
  _Rule(
    RegExp(r'\bsk-(?:proj-|ant-)?[A-Za-z0-9_-]{16,}'),
    (_) => credentialRedaction,
  ),
  _Rule(
    RegExp(r'\b(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,})'),
    (_) => credentialRedaction,
  ),
  _Rule(RegExp(r'\bxox[abprs]-[A-Za-z0-9-]{10,}'), (_) => credentialRedaction),
  _Rule(RegExp(r'\b(?:AKIA|ASIA)[0-9A-Z]{16}\b'), (_) => credentialRedaction),
  _Rule(
    RegExp(r'\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}'),
    (_) => credentialRedaction,
  ),
];
