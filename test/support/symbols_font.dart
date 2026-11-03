import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

/// Loads the Material Symbols fonts of the package version the workspace
/// resolved, read from the package config, so golden tests draw the app's
/// glyphs instead of the Ahem placeholder.
Future<void> loadSymbolsFonts() async {
  final config = File('.dart_tool/package_config.json').absolute;
  final packages = (jsonDecode(config.readAsStringSync()) as Map)['packages'];
  final entry = (packages as List).cast<Map<String, dynamic>>().firstWhere(
    (package) => package['name'] == 'material_symbols_icons',
    orElse: () => throw StateError('material_symbols_icons is not resolved'),
  );
  final rootUri = entry['rootUri'] as String;
  final root = config.uri.resolve(
    rootUri.endsWith('/') ? rootUri : '$rootUri/',
  );
  final fonts = root.resolve('${entry['packageUri'] ?? 'lib/'}fonts/');
  for (final name in ['MaterialSymbolsOutlined', 'MaterialSymbolsRounded']) {
    final file = File.fromUri(fonts.resolve('$name.ttf'));
    final loader = FontLoader('packages/material_symbols_icons/$name');
    loader.addFont(Future.value(ByteData.view(file.readAsBytesSync().buffer)));
    await loader.load();
  }
}
