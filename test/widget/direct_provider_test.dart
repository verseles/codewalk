import 'package:codewalk/presentation/widgets/direct_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Counter extends ChangeNotifier {
  _Counter(this.value);

  int value;
  String label = 'a';

  void bump() {
    value++;
    notifyListeners();
  }

  void relabel(String next) {
    label = next;
    notifyListeners();
  }
}

void main() {
  Widget harness(Widget child, _Counter counter) {
    return ChangeNotifierProvider<_Counter>.value(
      value: counter,
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  testWidgets('DirectConsumer rebuilds on every notification', (
    WidgetTester tester,
  ) async {
    final counter = _Counter(0);
    var builds = 0;
    await tester.pumpWidget(
      harness(
        DirectConsumer<_Counter>(
          builder: (context, value, _) {
            builds++;
            return Text('v=${value.value}:${value.label}');
          },
        ),
        counter,
      ),
    );
    expect(find.text('v=0:a'), findsOneWidget);
    final initialBuilds = builds;

    counter.bump();
    await tester.pump();
    expect(builds, initialBuilds + 1);
    expect(find.text('v=1:a'), findsOneWidget);
  });

  testWidgets('DirectSelector rebuilds only when selected value changes', (
    WidgetTester tester,
  ) async {
    final counter = _Counter(0);
    var builds = 0;
    await tester.pumpWidget(
      harness(
        DirectSelector<_Counter, int>(
          select: (value) => value.value,
          builder: (context, selected, _) {
            builds++;
            return Text('v=$selected');
          },
        ),
        counter,
      ),
    );
    expect(find.text('v=0'), findsOneWidget);
    final initialBuilds = builds;

    // Unselected field changes must not rebuild.
    counter.relabel('b');
    await tester.pump();
    expect(builds, initialBuilds);
    expect(find.text('v=0'), findsOneWidget);

    counter.bump();
    await tester.pump();
    expect(builds, initialBuilds + 1);
    expect(find.text('v=1'), findsOneWidget);
  });
}
