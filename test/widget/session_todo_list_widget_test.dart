import 'package:codewalk/domain/entities/chat_session.dart';
import 'package:codewalk/presentation/widgets/session_todo_list_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

void main() {
  const todos = <SessionTodo>[
    SessionTodo(
      id: '1',
      content: 'Set up database',
      status: 'completed',
      priority: 'high',
    ),
    SessionTodo(
      id: '2',
      content: 'Write API endpoints',
      status: 'in_progress',
      priority: 'medium',
    ),
    SessionTodo(
      id: '3',
      content: 'Add tests',
      status: 'pending',
      priority: 'low',
    ),
  ];

  Widget buildWidget({
    List<SessionTodo> items = todos,
    bool collapsed = false,
    VoidCallback? onToggle,
    int maxVisibleItems = 5,
    bool disableAnimations = false,
  }) {
    return MaterialApp(
      theme: ThemeData(splashFactory: InkRipple.splashFactory),
      home: Scaffold(
        body: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: disableAnimations),
            child: SessionTodoListWidget(
              todos: items,
              collapsed: collapsed,
              onToggleCollapsed: onToggle ?? () {},
              maxVisibleItems: maxVisibleItems,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows all items when expanded', (WidgetTester tester) async {
    await tester.pumpWidget(buildWidget());

    expect(find.text('Tasks (3)'), findsOneWidget);
    expect(find.text('Set up database'), findsOneWidget);
    expect(find.text('Write API endpoints'), findsOneWidget);
    expect(find.text('Add tests'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('session_todo_progress_bar')),
      findsOneWidget,
    );
    expect(find.text('Progress 1/3 completed'), findsNothing);
  });

  testWidgets('shows summary with in-progress task when collapsed', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildWidget(collapsed: true));

    expect(find.text('Task 2/3 Write API endpoints'), findsOneWidget);
    expect(find.text('Set up database'), findsNothing);
    expect(find.text('Add tests'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('session_todo_progress_bar')),
      findsOneWidget,
    );
    expect(find.text('Progress 1/3 completed'), findsNothing);
  });

  testWidgets('shows completed count when collapsed with no in-progress', (
    WidgetTester tester,
  ) async {
    const mixed = <SessionTodo>[
      SessionTodo(
        id: '1',
        content: 'First',
        status: 'completed',
        priority: 'medium',
      ),
      SessionTodo(
        id: '2',
        content: 'Second',
        status: 'pending',
        priority: 'low',
      ),
    ];
    await tester.pumpWidget(buildWidget(items: mixed, collapsed: true));

    expect(find.text('Tasks 1/2 completed'), findsOneWidget);
  });

  testWidgets('uses compact collapsed summary on mobile for in-progress item', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildWidget(collapsed: true));

    expect(find.text('2/3 in progress'), findsOneWidget);
    expect(find.text('Task 2/3 Write API endpoints'), findsNothing);
  });

  testWidgets(
    'uses compact completed summary on mobile when none in progress',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);

      const mixed = <SessionTodo>[
        SessionTodo(
          id: '1',
          content: 'First',
          status: 'completed',
          priority: 'medium',
        ),
        SessionTodo(
          id: '2',
          content: 'Second',
          status: 'pending',
          priority: 'low',
        ),
      ];
      await tester.pumpWidget(buildWidget(items: mixed, collapsed: true));

      expect(find.text('1/2 done'), findsOneWidget);
      expect(find.text('Tasks 1/2 completed'), findsNothing);
    },
  );

  testWidgets('calls onToggleCollapsed when header tapped', (
    WidgetTester tester,
  ) async {
    var toggled = false;
    await tester.pumpWidget(buildWidget(onToggle: () => toggled = true));

    await tester.tap(find.text('Tasks (3)'));
    expect(toggled, isTrue);
  });

  testWidgets('returns SizedBox.shrink for empty list', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildWidget(items: const []));

    expect(find.byType(SessionTodoListWidget), findsOneWidget);
    expect(find.text('Tasks'), findsNothing);
  });

  testWidgets('hides after all todos completed with delay', (
    WidgetTester tester,
  ) async {
    const allCompleted = <SessionTodo>[
      SessionTodo(
        id: '1',
        content: 'Done task',
        status: 'completed',
        priority: 'medium',
      ),
    ];
    await tester.pumpWidget(buildWidget(items: allCompleted));

    expect(find.text('Tasks (1)'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    expect(find.text('Tasks (1)'), findsNothing);
  });

  testWidgets('shows scrollbar when items exceed maxVisibleItems', (
    WidgetTester tester,
  ) async {
    final manyTodos = List<SessionTodo>.generate(
      8,
      (i) => SessionTodo(
        id: '$i',
        content: 'Task item $i',
        status: i == 3 ? 'in_progress' : 'pending',
        priority: 'medium',
      ),
    );
    await tester.pumpWidget(buildWidget(items: manyTodos, maxVisibleItems: 5));

    expect(find.byType(Scrollbar), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);
  });

  testWidgets('does not show scrollbar when items within limit', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildWidget(maxVisibleItems: 5));

    expect(find.byType(Scrollbar), findsNothing);
    expect(find.byType(ListView), findsNothing);
  });

  testWidgets('respects maxVisibleItems 10 for desktop', (
    WidgetTester tester,
  ) async {
    final manyTodos = List<SessionTodo>.generate(
      12,
      (i) => SessionTodo(
        id: '$i',
        content: 'Desktop task $i',
        status: 'pending',
        priority: 'low',
      ),
    );
    await tester.pumpWidget(buildWidget(items: manyTodos, maxVisibleItems: 10));

    expect(find.byType(Scrollbar), findsOneWidget);
  });

  testWidgets('animations enabled keeps the in-progress spinner', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildWidget());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(Symbols.progress_activity), findsNothing);
  });

  testWidgets('reduced motion renders a static in-progress indicator', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildWidget(disableAnimations: true));

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byIcon(Symbols.progress_activity), findsOneWidget);
  });
}
