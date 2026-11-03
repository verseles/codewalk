import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';

/// Loads the Material Symbols fonts of the resolved package, so golden tests
/// draw the app's glyphs instead of the Ahem placeholder.
Future<void> loadSymbolsFonts() async {
  final library = await Isolate.resolvePackageUri(
    Uri.parse('package:material_symbols_icons/symbols.dart'),
  );
  if (library == null) {
    throw StateError('material_symbols_icons is not in the package config');
  }
  final fonts = File.fromUri(library).parent.uri.resolve('fonts/');
  for (final name in ['MaterialSymbolsOutlined', 'MaterialSymbolsRounded']) {
    final file = File.fromUri(fonts.resolve('$name.ttf'));
    final loader = FontLoader('packages/material_symbols_icons/$name');
    loader.addFont(Future.value(ByteData.view(file.readAsBytesSync().buffer)));
    await loader.load();
  }
}
