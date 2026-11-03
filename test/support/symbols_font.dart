import 'dart:io';

import 'package:flutter/services.dart';

/// Loads the Material Symbols fonts from the pub cache, as the parity suite
/// does, so golden tests draw the app's glyphs instead of the Ahem placeholder.
Future<void> loadSymbolsFonts() async {
  final pubCache =
      Platform.environment['PUB_CACHE'] ??
      '${Platform.environment['HOME']}/.pub-cache';
  final candidates = Directory('$pubCache/hosted/pub.dev')
      .listSync()
      .whereType<Directory>()
      .where((d) => d.path.contains('material_symbols_icons'))
      .toList();
  if (candidates.isEmpty) {
    throw StateError(
      'Cannot find material_symbols_icons in pub cache: $pubCache',
    );
  }
  final dir = candidates.last.path;
  for (final name in ['MaterialSymbolsOutlined', 'MaterialSymbolsRounded']) {
    final file = File('$dir/lib/fonts/$name.ttf');
    final loader = FontLoader('packages/material_symbols_icons/$name');
    loader.addFont(Future.value(ByteData.view(file.readAsBytesSync().buffer)));
    await loader.load();
  }
}
