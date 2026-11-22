import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/l10n_context.dart';
import '../widgets/app_snack_bar.dart';

/// Launches a validated external [Uri] outside the app.
typedef MarkdownExternalUrlLauncher = Future<bool> Function(Uri uri);

final RegExp _bareWww = RegExp(
  r'^www\.[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+(?::\d+)?(?:[/?#].*)?$',
  caseSensitive: false,
);

/// Validates and normalizes a Markdown link [href] for external launch.
///
/// Only `http`, `https` (requiring a non-empty host), and `mailto` (requiring
/// a non-empty recipient path) are permitted. Scheme-relative `//host/...` and
/// bare `www.host.tld/...` links are upgraded to `https`. Relative paths,
/// fragments, and unsafe schemes (`javascript:`, `file:`, `data:`, `intent:`,
/// etc.) return `null`.
Uri? parseExternalMarkdownLink(String href) {
  final trimmed = href.trim();
  if (trimmed.isEmpty) return null;
  final String normalized;
  if (trimmed.startsWith('//')) {
    normalized = 'https:$trimmed';
  } else if (_bareWww.hasMatch(trimmed)) {
    normalized = 'https://$trimmed';
  } else {
    normalized = trimmed;
  }
  final uri = Uri.tryParse(normalized);
  if (uri == null || !uri.hasScheme) return null;
  final scheme = uri.scheme.toLowerCase();
  if (scheme == 'http' || scheme == 'https') {
    if (!uri.hasAuthority || uri.host.trim().isEmpty) return null;
    return uri;
  }
  if (scheme == 'mailto') {
    if (uri.path.trim().isEmpty) return null;
    return uri;
  }
  return null;
}

Future<bool> _defaultExternalLauncher(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// Opens [href] externally when it passes [parseExternalMarkdownLink], or
/// shows a localized snackbar if invalid or if the platform refuses to open it.
Future<void> openExternalMarkdownLink(
  BuildContext context,
  String href, {
  MarkdownExternalUrlLauncher? launcher,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final failedMessage = context.v2L10n.chatMessageUnableToOpenLink;
  final uri = parseExternalMarkdownLink(href);
  if (uri == null) {
    showAppSnackBar(messenger, failedMessage);
    return;
  }
  var opened = false;
  try {
    opened = await (launcher ?? _defaultExternalLauncher)(uri);
  } on Object {
    opened = false;
  }
  if (!opened && context.mounted) {
    showAppSnackBar(
      ScaffoldMessenger.maybeOf(context) ?? messenger,
      failedMessage,
    );
  }
}
