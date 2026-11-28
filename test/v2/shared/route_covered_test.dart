import 'dart:async';

import 'package:codewalk/shared/widgets/route_covered.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// A page inside the shell is covered by a route over it in its own
// navigator, or by anything over the shell in the root one (#539).

void main() {
  testWidgets('a page in the shell knows when something covers it', (
    tester,
  ) async {
    late BuildContext page;
    final shell = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Navigator(
          key: shell,
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (context) {
              page = context;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );
    expect(routeCovered(page), isFalse);

    // A dialog over the shell, in the root navigator.
    final dialog = showDialog<void>(
      context: page,
      builder: (_) => const Text('dialog'),
    );
    await tester.pumpAndSettle();
    expect(routeCovered(page), isTrue);
    Navigator.of(page, rootNavigator: true).pop();
    await dialog;
    await tester.pumpAndSettle();
    expect(routeCovered(page), isFalse);

    // A page over it in its own navigator.
    unawaited(
      shell.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const Text('over')),
      ),
    );
    await tester.pumpAndSettle();
    expect(routeCovered(page), isTrue);
  });
}
