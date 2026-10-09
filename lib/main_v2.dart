import 'package:flutter/widgets.dart';

import 'app/composition_root.dart';
import 'app/v2_bootstrap.dart';

/// Temporary explicit entry point while the legacy reference is retained.
Future<void> main([List<String> args = const []]) async {
  WidgetsFlutterBinding.ensureInitialized();
  Uri? link;
  for (final argument in args.take(8)) {
    if (argument.length <= 4096) {
      final candidate = Uri.tryParse(argument);
      if (candidate?.scheme == 'codewalk' && candidate?.host == 'pair') {
        link = candidate;
        break;
      }
    }
  }
  runApp(
    CodeWalkV2Bootstrap(
      dependencies: await loadAppDependencies(
        initialLink: link,
        listenNativeLinks: true,
      ),
    ),
  );
}
