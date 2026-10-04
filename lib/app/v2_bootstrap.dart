import 'package:flutter/material.dart';

/// Minimal v2 composition surface, independent of the retained legacy app.
///
/// Routing, controllers and the shared theme/localizations arrive in V2-020B.
class CodeWalkV2Bootstrap extends StatelessWidget {
  const CodeWalkV2Bootstrap({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'CodeWalk',
      home: Scaffold(body: Center(child: Text('CodeWalk'))),
    );
  }
}
