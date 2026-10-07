import 'package:flutter/widgets.dart';

import 'app/composition_root.dart';
import 'app/v2_bootstrap.dart';

/// Temporary explicit entry point while the legacy reference is retained.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(CodeWalkV2Bootstrap(dependencies: await loadAppDependencies()));
}
