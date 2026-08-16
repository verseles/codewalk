import 'dart:math' as math;

import 'package:codewalk/core/i18n/l10n_context.dart';
import 'package:codewalk/domain/entities/chat_realtime.dart';
import 'package:codewalk/domain/entities/project.dart';
import 'package:codewalk/presentation/providers/chat_provider.dart';
import 'package:codewalk/presentation/widgets/project_icon.dart';
import 'package:codewalk/presentation/widgets/session_tab_strip.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../support/pump_localized_app.dart';

void main() {
  testWidgets('stays absent without tabs', (tester) async {
    await tester.pumpWidget(_app(tabs: const <SessionTabRecord>[]));

    expect(
      find.byKey(const ValueKey<String>('session_tab_strip')),
      findsNothing,
    );
  });

  testWidgets(
    'inactive pinned tabs stay compact in a separate leading region',
    (tester) async {
      final pinned = _tab('pinned', title: 'Pinned session', isPinned: true);
      final regular = _tab('regular', isSelected: true);
      final pinnedKey = sessionTabIdentityKey(pinned.identity);

      await tester.pumpWidget(_app(tabs: <SessionTabRecord>[pinned, regular]));
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('session_tab_pinned_region')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('session_tab_pinned_region_scroll_view'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey<String>('session_tab_title_$pinnedKey')),
        findsNothing,
      );
      expect(find.byTooltip('Pinned session'), findsOneWidget);
      expect(
        tester
            .getSize(find.byKey(ValueKey<String>('session_tab_$pinnedKey')))
            .width,
        moreOrLessEquals(36, epsilon: 0.01),
      );
    },
  );

  testWidgets('selected pinned tab expands with title and trailing controls', (
    tester,
  ) async {
    final pinned = _tab(
      'pinned',
      title: 'Selected pinned session',
      isPinned: true,
      isSelected: true,
    );
    final pinnedKey = sessionTabIdentityKey(pinned.identity);

    await tester.pumpWidget(
      _app(
        tabs: <SessionTabRecord>[pinned],
        trailingBuilder: (context, tab) =>
            const SizedBox(key: ValueKey<String>('pinned_trailing'), width: 24),
      ),
    );

    expect(
      find.byKey(ValueKey<String>('session_tab_title_$pinnedKey')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('pinned_trailing')),
      findsOneWidget,
    );
    expect(
      tester
          .getSize(find.byKey(ValueKey<String>('session_tab_$pinnedKey')))
          .width,
      greaterThan(80),
    );
  });

  testWidgets(
    'a single inactive pinned tab stays compact at phone width',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final pinned = _tab('pinned', isPinned: true);
      final pinnedKey = sessionTabIdentityKey(pinned.identity);

      await tester.pumpWidget(_app(tabs: <SessionTabRecord>[pinned], width: 320));
      await tester.pump();

      final tabRect = tester.getRect(
        find.byKey(ValueKey<String>('session_tab_$pinnedKey')),
      );
      expect(tabRect.width, moreOrLessEquals(36, epsilon: 0.01));
      final regionRect = tester.getRect(
        find.byKey(const ValueKey<String>('session_tab_pinned_region')),
      );
      expect(tabRect.left, greaterThanOrEqualTo(regionRect.left - 0.5));
      expect(tabRect.right, lessThanOrEqualTo(regionRect.right + 0.5));
      expect(tabRect.left - regionRect.left, lessThanOrEqualTo(4.01));
    },
  );

  testWidgets(
    'centers the leading icon inside an inactive pinned tab',
    (tester) async {
      final pinned = _tab('pinned', isPinned: true);
      final pinnedKey = sessionTabIdentityKey(pinned.identity);

      await tester.pumpWidget(_app(tabs: <SessionTabRecord>[pinned]));
      await tester.pump();

      final tabRect = tester.getRect(
        find.byKey(ValueKey<String>('session_tab_$pinnedKey')),
      );
      final iconRect = tester.getRect(
        find.byKey(ValueKey<String>('session_tab_project_icon_$pinnedKey')),
      );
      expect(
        iconRect.center.dx,
        moreOrLessEquals(tabRect.center.dx, epsilon: 0.01),
      );
      // The busy badge still anchors to the leading box corner.
      final busy = _tab(
        'busy',
        isPinned: true,
        status: SessionStatusType.busy,
      );
      final busyKey = sessionTabIdentityKey(busy.identity);
      await tester.pumpWidget(_app(tabs: <SessionTabRecord>[busy]));
      await tester.pump();
      final badgeRect = tester.getRect(
        find.byKey(ValueKey<String>('session_tab_busy_busy_$busyKey')),
      );
      final leadingRect = tester.getRect(
        find.byKey(ValueKey<String>('session_tab_leading_$busyKey')),
      );
      expect(badgeRect.right, moreOrLessEquals(leadingRect.right, epsilon: 0.01));
      expect(
        badgeRect.bottom,
        moreOrLessEquals(leadingRect.bottom, epsilon: 0.01),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'selected pinned tab stays visible when pinned tabs overflow',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final overflow = List<SessionTabRecord>.generate(
        7,
        (index) => _tab('pin_$index', isPinned: true),
      );
      final selected = _tab(
        'pin_selected',
        title: 'Selected overflow',
        isPinned: true,
        isSelected: true,
      );
      final regular = _tab('regular');

      await tester.pumpWidget(
        _app(
          tabs: <SessionTabRecord>[...overflow, selected, regular],
          width: 320,
          trailingBuilder: (context, tab) => const SizedBox(
            key: ValueKey<String>('usage_trailing'),
            width: 40,
            height: 40,
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      final selectedRect = tester.getRect(
        find.byKey(
          ValueKey<String>(
            'session_tab_${sessionTabIdentityKey(selected.identity)}',
          ),
        ),
      );
      // The expanded tab never collapses below its usable minimum, even with
      // the production-sized trailing usage button present.
      expect(selectedRect.width, greaterThanOrEqualTo(100));
      expect(tester.takeException(), isNull);
      // The pinned viewport overflows and the reveal keeps the tab reachable.
      final pinnedScrollable = tester.state<ScrollableState>(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('session_tab_pinned_region_scroll_view'),
          ),
          matching: find.byType(Scrollable),
        ),
      );
      expect(pinnedScrollable.position.maxScrollExtent, greaterThan(0));
      final regionRect = tester.getRect(
        find.byKey(const ValueKey<String>('session_tab_pinned_region')),
      );
      expect(selectedRect.left, greaterThanOrEqualTo(regionRect.left - 0.5));
      expect(selectedRect.right, lessThanOrEqualTo(regionRect.right + 0.5));
    },
  );

  testWidgets(
    'selected pinned tab fits entirely inside its region with regular tabs',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final pinned = _tab(
        'pinned',
        title: 'Selected pinned session',
        isPinned: true,
        isSelected: true,
      );
      final regular = _tab('regular');
      final pinnedKey = sessionTabIdentityKey(pinned.identity);

      await tester.pumpWidget(
        _app(tabs: <SessionTabRecord>[pinned, regular], width: 600),
      );
      await tester.pump();

      final regionRect = tester.getRect(
        find.byKey(const ValueKey<String>('session_tab_pinned_region')),
      );
      final tabRect = tester.getRect(
        find.byKey(ValueKey<String>('session_tab_$pinnedKey')),
      );
      expect(tabRect.left, greaterThanOrEqualTo(regionRect.left - 0.5));
      expect(tabRect.right, lessThanOrEqualTo(regionRect.right + 0.5));
      // The expanded tab keeps its full width instead of being clipped.
      expect(tabRect.width, greaterThanOrEqualTo(300));
      // The regular region keeps usable space.
      final regularScrollRect = tester.getRect(
        find.byKey(const ValueKey<String>('session_tab_strip_scroll_view')),
      );
      expect(regularScrollRect.width, greaterThanOrEqualTo(96));
      expect(
        find.byKey(ValueKey<String>('session_tab_title_$pinnedKey')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'selected pinned tab adapts when the viewport is narrower than expanded',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final pinned = _tab(
        'pinned',
        title: 'A very long selected pinned session title',
        isPinned: true,
        isSelected: true,
      );
      final regular = _tab('regular');
      final pinnedKey = sessionTabIdentityKey(pinned.identity);

      await tester.pumpWidget(
        _app(tabs: <SessionTabRecord>[pinned, regular], width: 320),
      );
      await tester.pump();

      final regionRect = tester.getRect(
        find.byKey(const ValueKey<String>('session_tab_pinned_region')),
      );
      final tabRect = tester.getRect(
        find.byKey(ValueKey<String>('session_tab_$pinnedKey')),
      );
      expect(tabRect.left, greaterThanOrEqualTo(regionRect.left - 0.5));
      expect(tabRect.right, lessThanOrEqualTo(regionRect.right + 0.5));
      // Adapted below the full expanded width so it never needs to scroll.
      expect(tabRect.width, lessThan(278.2));
      final title = tester.widget<Text>(
        find.byKey(ValueKey<String>('session_tab_title_$pinnedKey')),
      );
      expect(title.overflow, TextOverflow.ellipsis);
      expect(
        tester
            .getRect(
              find.byKey(
                const ValueKey<String>('session_tab_strip_scroll_view'),
              ),
            )
            .width,
        greaterThanOrEqualTo(96),
      );
    },
  );

  testWidgets(
    'selected pinned tab stays fully visible among other pinned tabs',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final inactive = _tab('pin_a', isPinned: true);
      final selected = _tab(
        'pin_b',
        title: 'Selected among pinned',
        isPinned: true,
        isSelected: true,
      );
      final regular = _tab('regular');

      await tester.pumpWidget(
        _app(
          tabs: <SessionTabRecord>[inactive, selected, regular],
          width: 600,
        ),
      );
      await tester.pump();

      final regionRect = tester.getRect(
        find.byKey(const ValueKey<String>('session_tab_pinned_region')),
      );
      for (final tab in <SessionTabRecord>[inactive, selected]) {
        final tabRect = tester.getRect(
          find.byKey(
            ValueKey<String>(
              'session_tab_${sessionTabIdentityKey(tab.identity)}',
            ),
          ),
        );
        expect(tabRect.left, greaterThanOrEqualTo(regionRect.left - 0.5));
        expect(tabRect.right, lessThanOrEqualTo(regionRect.right + 0.5));
      }
      final selectedRect = tester.getRect(
        find.byKey(
          ValueKey<String>(
            'session_tab_${sessionTabIdentityKey(selected.identity)}',
          ),
        ),
      );
      expect(selectedRect.width, greaterThanOrEqualTo(300));
      final regularScrollRect = tester.getRect(
        find.byKey(const ValueKey<String>('session_tab_strip_scroll_view')),
      );
      expect(regularScrollRect.width, greaterThanOrEqualTo(96));
    },
  );

  testWidgets(
    'pinned overflow scrolls independently and stays leading in RTL',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final pinned = List<SessionTabRecord>.generate(
        8,
        (index) => _tab('pinned_$index', isPinned: true),
      );
      final regular = _tab('regular', isSelected: true);

      await tester.pumpWidget(
        _app(
          tabs: <SessionTabRecord>[...pinned, regular],
          width: 320,
          textDirection: TextDirection.rtl,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 220));

      final pinnedScrollView = find.byKey(
        const ValueKey<String>('session_tab_pinned_region_scroll_view'),
      );
      final pinnedScrollable = find.descendant(
        of: pinnedScrollView,
        matching: find.byType(Scrollable),
      );
      final pinnedPosition = tester
          .state<ScrollableState>(pinnedScrollable)
          .position;
      expect(pinnedPosition.maxScrollExtent, greaterThan(0));

      final regularScrollView = find.byKey(
        const ValueKey<String>('session_tab_strip_scroll_view'),
      );
      // With no selected pinned tab the cap stays at the responsive 50% limit.
      expect(
        tester
            .getRect(
              find.byKey(const ValueKey<String>('session_tab_pinned_region')),
            )
            .width,
        lessThanOrEqualTo(304 * 0.5 + 0.5),
      );
      expect(
        tester
            .getRect(
              find.byKey(const ValueKey<String>('session_tab_pinned_region')),
            )
            .left,
        greaterThan(tester.getRect(regularScrollView).left),
      );

      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: tester.getCenter(pinnedScrollView),
          scrollDelta: const Offset(0, 80),
        ),
      );
      await tester.pump();
      expect(pinnedPosition.pixels, greaterThan(0));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('exposes selected title semantics and keyboard activation', (
    tester,
  ) async {
    final tab = _tab('alpha', title: 'Alpha session', isSelected: true);
    final activated = <SessionTabIdentity>[];
    final closed = <SessionTabIdentity>[];

    await tester.pumpWidget(
      _app(
        tabs: <SessionTabRecord>[tab],
        onActivate: activated.add,
        onClose: closed.add,
      ),
    );
    await tester.pump();

    final identityKey = sessionTabIdentityKey(tab.identity);
    final activateFinder = find.byKey(
      ValueKey<String>('session_tab_activate_$identityKey'),
    );
    expect(find.byTooltip('Alpha session'), findsOneWidget);
    expect(
      tester
          .widget<Tooltip>(find.byTooltip('Alpha session'))
          .excludeFromSemantics,
      isTrue,
    );
    expect(find.byIcon(Symbols.folder_open), findsOneWidget);
    final tabSemantics = tester.widget<Semantics>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.selected == true &&
            widget.properties.label == 'Chat session: Alpha session' &&
            widget.properties.onTap != null &&
            widget.properties.onLongPress != null,
      ),
    );
    expect(
      tabSemantics.properties.customSemanticsActions?.keys.map(
        (action) => action.label,
      ),
      contains('Session actions'),
    );

    final activation = tester.widget<InkWell>(activateFinder);
    activation.focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(activated, <SessionTabIdentity>[tab.identity]);

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();

    final closeFinder = find.byKey(
      ValueKey<String>('session_tab_close_$identityKey'),
    );
    expect(closeFinder, findsNothing);
    expect(closed, <SessionTabIdentity>[tab.identity]);
  });

  testWidgets('exposes close as a permanent semantics action', (tester) async {
    final tab = _tab('alpha', title: 'Alpha session', isSelected: true);
    final closed = <SessionTabIdentity>[];
    final identityKey = sessionTabIdentityKey(tab.identity);

    await tester.pumpWidget(
      _app(tabs: <SessionTabRecord>[tab], onClose: closed.add),
    );
    await tester.pump();

    expect(
      find.byKey(ValueKey<String>('session_tab_close_$identityKey')),
      findsNothing,
    );
    final tabSemantics = tester.widget<Semantics>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Chat session: Alpha session' &&
            widget.properties.onDismiss != null,
      ),
    );

    tabSemantics.properties.onDismiss!.call();
    await tester.pump();

    expect(closed, <SessionTabIdentity>[tab.identity]);
  });

  testWidgets('keyboard traversal moves directly between tabs', (tester) async {
    final first = _tab('first', isSelected: true);
    final second = _tab('second');
    final activated = <SessionTabIdentity>[];

    await tester.pumpWidget(
      _app(tabs: <SessionTabRecord>[first, second], onActivate: activated.add),
    );
    await tester.pump();

    final firstKey = sessionTabIdentityKey(first.identity);
    final secondKey = sessionTabIdentityKey(second.identity);
    tester
        .widget<InkWell>(
          find.byKey(ValueKey<String>('session_tab_activate_$firstKey')),
        )
        .focusNode!
        .requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(
      tester
          .widget<InkWell>(
            find.byKey(ValueKey<String>('session_tab_activate_$secondKey')),
          )
          .focusNode
          ?.hasFocus,
      isTrue,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(activated, <SessionTabIdentity>[second.identity]);
  });

  testWidgets('prioritizes error attention without replacing retry status', (
    tester,
  ) async {
    final tab = _tab(
      'attention',
      title: 'Needs review',
      status: SessionStatusType.retry,
      pendingQuestionIds: const <String>['question_1'],
      completionToken: 'completion_1',
      errorToken: 'error_1',
    );
    final identityKey = sessionTabIdentityKey(tab.identity);

    await tester.pumpWidget(_app(tabs: <SessionTabRecord>[tab]));

    expect(
      find.byKey(ValueKey<String>('session_tab_leading_error_$identityKey')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey<String>('session_tab_leading_question_$identityKey')),
      findsNothing,
    );
    expect(
      find.byKey(
        ValueKey<String>('session_tab_leading_completion_$identityKey'),
      ),
      findsNothing,
    );
    expect(
      find.byKey(ValueKey<String>('session_tab_busy_retry_$identityKey')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(ValueKey<String>('session_tab_leading_$identityKey')),
        matching: find.byKey(
          ValueKey<String>('session_tab_busy_retry_$identityKey'),
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label ==
                '"Needs review" has an error. Status: Retry',
      ),
      findsOneWidget,
    );
  });

  testWidgets('overlays busy status on the project icon lower right', (
    tester,
  ) async {
    final idle = _tab('working', title: 'Working session');
    final identityKey = sessionTabIdentityKey(idle.identity);
    final titleFinder = find.byKey(
      ValueKey<String>('session_tab_title_$identityKey'),
    );
    final projectIconFinder = find.byKey(
      ValueKey<String>('session_tab_project_icon_$identityKey'),
    );
    final badgeFinder = find.byKey(
      ValueKey<String>('session_tab_busy_busy_$identityKey'),
    );
    final leadingFinder = find.byKey(
      ValueKey<String>('session_tab_leading_$identityKey'),
    );

    await tester.pumpWidget(_app(tabs: <SessionTabRecord>[idle]));
    await tester.pump();

    final idleTitleWidth = tester.getSize(titleFinder).width;
    expect(badgeFinder, findsNothing);

    await tester.pumpWidget(
      _app(
        tabs: <SessionTabRecord>[
          _tab(
            'working',
            title: 'Working session',
            status: SessionStatusType.busy,
          ),
        ],
      ),
    );
    await tester.pump();

    expect(
      find.descendant(of: leadingFinder, matching: projectIconFinder),
      findsOneWidget,
    );
    expect(
      find.descendant(of: leadingFinder, matching: badgeFinder),
      findsOneWidget,
    );
    expect(tester.getSize(titleFinder).width, idleTitleWidth);

    final iconRect = tester.getRect(projectIconFinder);
    final badgeRect = tester.getRect(badgeFinder);
    final leadingRect = tester.getRect(leadingFinder);
    expect(badgeRect.width, moreOrLessEquals(12, epsilon: 0.01));
    expect(badgeRect.height, moreOrLessEquals(12, epsilon: 0.01));
    expect(iconRect.overlaps(badgeRect), isTrue);
    expect(badgeRect.center.dx, greaterThan(iconRect.center.dx));
    expect(badgeRect.center.dy, greaterThan(iconRect.center.dy));
    expect(badgeRect.right, leadingRect.right);
    expect(badgeRect.bottom, leadingRect.bottom);
  });

  testWidgets('custom icon replaces base icon and keeps busy overlay', (
    tester,
  ) async {
    final tab = _tab(
      'custom',
      status: SessionStatusType.busy,
      isPinned: true,
      iconPresetId: 'terminal',
    );
    final identityKey = sessionTabIdentityKey(tab.identity);

    await tester.pumpWidget(_app(tabs: <SessionTabRecord>[tab]));

    expect(
      find.byKey(ValueKey<String>('session_tab_custom_icon_$identityKey')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey<String>('session_tab_project_icon_$identityKey')),
      findsNothing,
    );
    expect(
      find.byKey(ValueKey<String>('session_tab_busy_busy_$identityKey')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey<String>('session_tab_title_$identityKey')),
      findsNothing,
    );
  });

  testWidgets('unknown custom icon falls back to the project icon', (
    tester,
  ) async {
    final tab = _tab('unknown-icon', iconPresetId: 'future-preset');
    final identityKey = sessionTabIdentityKey(tab.identity);

    await tester.pumpWidget(_app(tabs: <SessionTabRecord>[tab]));

    expect(
      find.byKey(ValueKey<String>('session_tab_custom_icon_$identityKey')),
      findsNothing,
    );
    expect(
      find.byKey(ValueKey<String>('session_tab_project_icon_$identityKey')),
      findsOneWidget,
    );
  });

  testWidgets('attention overrides custom icon until attention clears', (
    tester,
  ) async {
    final attention = _tab(
      'custom-attention',
      iconPresetId: 'bug',
      errorToken: 'error-1',
    );
    final identityKey = sessionTabIdentityKey(attention.identity);

    await tester.pumpWidget(_app(tabs: <SessionTabRecord>[attention]));

    expect(
      find.byKey(ValueKey<String>('session_tab_leading_error_$identityKey')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey<String>('session_tab_custom_icon_$identityKey')),
      findsNothing,
    );

    await tester.pumpWidget(
      _app(
        tabs: <SessionTabRecord>[_tab('custom-attention', iconPresetId: 'bug')],
      ),
    );

    expect(
      find.byKey(ValueKey<String>('session_tab_custom_icon_$identityKey')),
      findsOneWidget,
    );
  });

  testWidgets('discovers icons only for open projects', (tester) async {
    final tab = _tab('project');
    final project = Project(
      id: 'proj_project',
      name: 'Project',
      path: tab.identity.directory,
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    );

    await tester.pumpWidget(
      _app(tabs: <SessionTabRecord>[tab], projects: <Project>[project]),
    );

    expect(
      tester.widget<ProjectIcon>(find.byType(ProjectIcon)).autoDiscover,
      isFalse,
    );

    await tester.pumpWidget(
      _app(
        tabs: <SessionTabRecord>[tab],
        projects: <Project>[project],
        openProjectIds: <String>{project.id},
      ),
    );

    expect(
      tester.widget<ProjectIcon>(find.byType(ProjectIcon)).autoDiscover,
      isTrue,
    );
  });

  testWidgets('scrolls overflow and keeps the selected tab visible', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final tabs = List<SessionTabRecord>.generate(
      6,
      (index) => _tab(
        'session_$index',
        title: 'Long session title $index',
        isSelected: index == 5,
      ),
    );

    await tester.pumpWidget(_app(tabs: tabs, width: 300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    final scrollViewFinder = find.byKey(
      const ValueKey<String>('session_tab_strip_scroll_view'),
    );
    final scrollableFinder = find.descendant(
      of: scrollViewFinder,
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(scrollableFinder).position;
    expect(find.byType(Scrollbar), findsNothing);
    expect(position.maxScrollExtent, greaterThan(0));
    expect(position.pixels, greaterThan(0));

    final viewportRect = tester.getRect(scrollViewFinder);
    final selectedRect = tester.getRect(
      find.byKey(
        ValueKey<String>(
          'session_tab_${sessionTabIdentityKey(tabs.last.identity)}',
        ),
      ),
    );
    expect(selectedRect.left, greaterThanOrEqualTo(viewportRect.left - 0.5));
    expect(selectedRect.right, lessThanOrEqualTo(viewportRect.right + 0.5));

    final title = tester.widget<Text>(
      find.byKey(
        ValueKey<String>(
          'session_tab_title_${sessionTabIdentityKey(tabs.last.identity)}',
        ),
      ),
    );
    expect(title.maxLines, 1);
    expect(title.overflow, TextOverflow.ellipsis);

    position.jumpTo(0);
    await tester.pump();
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(scrollViewFinder),
        scrollDelta: const Offset(0, 80),
      ),
    );
    await tester.pump();
    expect(position.pixels, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('reveals the selected tab when tabs are inserted before it', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final selected = _tab('selected', isSelected: true);

    await tester.pumpWidget(
      _app(tabs: <SessionTabRecord>[selected], width: 300),
    );
    await tester.pumpAndSettle();

    final preceding = List<SessionTabRecord>.generate(
      5,
      (index) => _tab('before_$index'),
    );
    await tester.pumpWidget(
      _app(tabs: <SessionTabRecord>[...preceding, selected], width: 300),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    final viewportRect = tester.getRect(
      find.byKey(const ValueKey<String>('session_tab_strip_scroll_view')),
    );
    final selectedRect = tester.getRect(
      find.byKey(
        ValueKey<String>(
          'session_tab_${sessionTabIdentityKey(selected.identity)}',
        ),
      ),
    );
    expect(selectedRect.left, greaterThanOrEqualTo(viewportRect.left - 0.5));
    expect(selectedRect.right, lessThanOrEqualTo(viewportRect.right + 0.5));
  });

  testWidgets('close never activates a tab and focuses its neighbor', (
    tester,
  ) async {
    final first = _tab('first', isSelected: true);
    final second = _tab('second');
    final third = _tab('third');
    var tabs = <SessionTabRecord>[first, second, third];
    final closed = <SessionTabIdentity>[];
    final activated = <SessionTabIdentity>[];

    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return SessionTabStrip(
                tabs: tabs,
                projects: const [],
                openProjectIds: const <String>{},
                isCompact: false,
                onActivate: (tab) => activated.add(tab.identity),
                onClose: (tab) {
                  closed.add(tab.identity);
                  setState(() {
                    tabs = tabs
                        .where(
                          (candidate) => candidate.identity != tab.identity,
                        )
                        .toList(growable: false);
                  });
                },
                onContextMenu: (tab, position, {required haptic}) async {},
                trailingBuilder: (context, tab) => null,
              );
            },
          ),
        ),
      ),
    );

    final secondFinder = find.byKey(
      ValueKey<String>(
        'session_tab_activate_${sessionTabIdentityKey(second.identity)}',
      ),
    );
    await tester.tap(secondFinder);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(secondFinder);
    await tester.pumpAndSettle();

    expect(closed, <SessionTabIdentity>[second.identity]);
    expect(activated, isEmpty);
    expect(
      tester
          .widget<InkWell>(
            find.byKey(
              ValueKey<String>(
                'session_tab_activate_${sessionTabIdentityKey(third.identity)}',
              ),
            ),
          )
          .focusNode
          ?.hasFocus,
      isTrue,
    );

    final firstFinder = find.byKey(
      ValueKey<String>(
        'session_tab_activate_${sessionTabIdentityKey(first.identity)}',
      ),
    );
    final middleClick = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      buttons: kMiddleMouseButton,
    );
    await middleClick.addPointer(location: tester.getCenter(firstFinder));
    await middleClick.down(tester.getCenter(firstFinder));
    await middleClick.up();
    await tester.pump();

    expect(closed, <SessionTabIdentity>[second.identity, first.identity]);
    expect(activated, isEmpty);
    expect(
      tester
          .widget<InkWell>(
            find.byKey(
              ValueKey<String>(
                'session_tab_activate_${sessionTabIdentityKey(third.identity)}',
              ),
            ),
          )
          .focusNode
          ?.hasFocus,
      isTrue,
    );
  });

  test('close fallback prefers right, then left', () {
    final first = _tab('first');
    final second = _tab('second');
    final third = _tab('third');
    final tabs = <SessionTabRecord>[first, second, third];

    expect(sessionTabCloseFallback(tabs, first.identity), same(second));
    expect(sessionTabCloseFallback(tabs, second.identity), same(third));
    expect(sessionTabCloseFallback(tabs, third.identity), same(second));
    expect(
      sessionTabCloseFallback(<SessionTabRecord>[first], first.identity),
      isNull,
    );
    expect(sessionTabCloseFallback(tabs, _identity('missing')), isNull);
  });

  testWidgets('selected tab merges with the content surface below', (
    tester,
  ) async {
    final selected = _tab('alpha', isSelected: true);
    final inactive = _tab('beta');

    await tester.pumpWidget(_app(tabs: <SessionTabRecord>[selected, inactive]));
    await tester.pump();

    final context = tester.element(
      find.byKey(const ValueKey<String>('session_tab_strip')),
    );
    final colorScheme = Theme.of(context).colorScheme;

    // The selected tab takes the content surface colour so it reads as
    // continuous with the panel underneath; inactive tabs stay transparent
    // over the strip band.
    expect(_tabMaterial(tester, selected).color, colorScheme.surface);
    expect(_tabMaterial(tester, inactive).color, Colors.transparent);
  });

  testWidgets('tabs use lower flares, straight sides, and soft top corners', (
    tester,
  ) async {
    final selected = _tab('alpha', isSelected: true);
    final inactive = _tab('beta');

    await tester.pumpWidget(_app(tabs: <SessionTabRecord>[selected, inactive]));
    await tester.pump();

    final selectedShape = _tabMaterial(tester, selected).shape!;
    final inactiveShape = _tabMaterial(tester, inactive).shape!;

    for (final size in const <Size>[Size(317.2, 43.2), Size(278.2, 46.4)]) {
      final selectedPath = selectedShape.getOuterPath(Offset.zero & size);
      final inactivePath = inactiveShape.getOuterPath(Offset.zero & size);
      final rightShoulder = size.width - 10;

      // The selected tab keeps its lower outward flare.
      expect(selectedPath.contains(Offset(6, size.height - 2)), isTrue);
      expect(
        selectedPath.contains(Offset(size.width - 6, size.height - 2)),
        isTrue,
      );

      // The narrower shoulders reduce the visual gap between adjacent tabs.
      expect(selectedPath.contains(const Offset(9, 20)), isFalse);
      expect(selectedPath.contains(const Offset(11, 20)), isTrue);
      expect(selectedPath.contains(Offset(rightShoulder - 1, 20)), isTrue);
      expect(selectedPath.contains(Offset(rightShoulder + 1, 20)), isFalse);

      // Inactive tabs drop the flare: straight sides reach the bottom edge.
      expect(inactivePath.contains(Offset(6, size.height - 2)), isTrue);
      expect(
        inactivePath.contains(Offset(size.width - 6, size.height - 2)),
        isTrue,
      );
      expect(inactivePath.contains(Offset(size.width - 9, 20)), isTrue);

      // Only the active tab uses the softer 8px top radius; inactive tabs
      // round with the 5px radius at the corner itself.
      expect(selectedPath.contains(const Offset(11, 2)), isFalse);
      expect(inactivePath.contains(const Offset(1, 1)), isFalse);
      expect(inactivePath.contains(const Offset(4, 2)), isTrue);
      expect(selectedPath.contains(const Offset(14, 2)), isTrue);
      expect(selectedPath.contains(Offset(size.width / 2, 2)), isTrue);
    }
  });

  testWidgets('reduces desktop and compact tab strip heights by 20 percent', (
    tester,
  ) async {
    final tab = _tab('alpha', isSelected: true);

    await tester.pumpWidget(_app(tabs: <SessionTabRecord>[tab]));
    var size = tester.getSize(
      find.byKey(const ValueKey<String>('session_tab_strip')),
    );
    expect(size.width, 800);
    expect(size.height, moreOrLessEquals(43.2, epsilon: 0.01));

    await tester.pumpWidget(
      _app(tabs: <SessionTabRecord>[tab], isCompact: true),
    );
    size = tester.getSize(
      find.byKey(const ValueKey<String>('session_tab_strip')),
    );
    expect(size.width, 800);
    expect(size.height, moreOrLessEquals(46.4, epsilon: 0.01));
  });

  testWidgets('double touch closes without rendering a close button', (
    tester,
  ) async {
    final tab = _tab('alpha', isSelected: true);
    final closed = <SessionTabIdentity>[];
    final closeFinder = find.byKey(
      ValueKey<String>(
        'session_tab_close_${sessionTabIdentityKey(tab.identity)}',
      ),
    );

    for (final isCompact in <bool>[true, false]) {
      await tester.pumpWidget(
        _app(
          tabs: <SessionTabRecord>[tab],
          isCompact: isCompact,
          onClose: closed.add,
        ),
      );
      await tester.pump();

      expect(closeFinder, findsNothing);
      final tabFinder = find.byKey(
        ValueKey<String>(
          'session_tab_activate_${sessionTabIdentityKey(tab.identity)}',
        ),
      );
      await tester.tap(tabFinder, kind: PointerDeviceKind.touch);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(tabFinder, kind: PointerDeviceKind.touch);
      await tester.pump();
      expect(closed.last, tab.identity);
      await tester.pump(const Duration(seconds: 1));
    }
  });

  testWidgets('right click and long press open the tab context menu', (
    tester,
  ) async {
    final tab = _tab('alpha', isSelected: true);
    final requests = <({SessionTabIdentity identity, bool haptic})>[];
    await tester.pumpWidget(
      _app(
        tabs: <SessionTabRecord>[tab],
        onContextMenu: (tab, position, {required haptic}) async {
          requests.add((identity: tab.identity, haptic: haptic));
        },
      ),
    );
    final finder = find.byKey(
      ValueKey<String>(
        'session_tab_activate_${sessionTabIdentityKey(tab.identity)}',
      ),
    );

    await tester.tap(finder, buttons: kSecondaryMouseButton);
    await tester.pump();
    await tester.longPress(finder);
    await tester.pump();

    tester.widget<InkWell>(finder).focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.f10);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    final semantics = tester.widget<Semantics>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.customSemanticsActions?.keys.any(
                  (action) => action.label == 'Session actions',
                ) ==
                true,
      ),
    );
    semantics.properties.customSemanticsActions!.entries
        .singleWhere((entry) => entry.key.label == 'Session actions')
        .value();
    await tester.pump();

    expect(requests, <({SessionTabIdentity identity, bool haptic})>[
      (identity: tab.identity, haptic: false),
      (identity: tab.identity, haptic: true),
      (identity: tab.identity, haptic: false),
      (identity: tab.identity, haptic: false),
    ]);
  });

  testWidgets('selection is conveyed by more than colour', (tester) async {
    final selected = _tab('alpha', isSelected: true);
    final inactive = _tab('beta');

    await tester.pumpWidget(_app(tabs: <SessionTabRecord>[selected, inactive]));
    await tester.pump();

    Text titleOf(SessionTabRecord tab) => tester.widget<Text>(
      find.byKey(
        ValueKey<String>(
          'session_tab_title_${sessionTabIdentityKey(tab.identity)}',
        ),
      ),
    );

    // Weight differs, so selection survives for users who cannot rely on
    // colour alone even though the accent bar was dropped.
    expect(
      titleOf(selected).style!.fontWeight,
      isNot(titleOf(inactive).style!.fontWeight),
    );
  });

  testWidgets(
    'regular tabs size to content between minimum and maximum widths',
    (tester) async {
      final tabs = <SessionTabRecord>[
        _tab('short', title: 'A'),
        _tab('medium', title: 'Session X'),
        _tab('long', title: 'A very long session title'),
      ];

      await tester.pumpWidget(_app(tabs: tabs));
      await tester.pump();

      double widthOf(SessionTabRecord tab) => tester
          .getSize(
            find.byKey(
              ValueKey<String>(
                'session_tab_${sessionTabIdentityKey(tab.identity)}',
              ),
            ),
          )
          .width;
      // The minimum is a fixed floor for one-character titles.
      expect(widthOf(tabs[0]), moreOrLessEquals(150, epsilon: 0.01));
      // Content-derived widths sit between the floor and the cap.
      expect(
        widthOf(tabs[1]),
        moreOrLessEquals(
          _expectedContentWidth(tester, 'Session X'),
          epsilon: 0.01,
        ),
      );
      // Long titles cap at the maximum.
      expect(widthOf(tabs[2]), moreOrLessEquals(317.2, epsilon: 0.01));
    },
  );

  testWidgets('selected tab reserves the trailing usage button width', (
    tester,
  ) async {
    final inactive = _tab('inactive', title: 'Session X');
    final selected = _tab('selected', title: 'Session X', isSelected: true);

    await tester.pumpWidget(
      _app(
        tabs: <SessionTabRecord>[inactive, selected],
        trailingBuilder: (context, tab) => tab.isSelected
            ? const SizedBox(
                key: ValueKey<String>('usage_trailing'),
                width: 32,
                height: 32,
              )
            : null,
      ),
    );
    await tester.pump();

    double widthOf(SessionTabRecord tab) => tester
        .getSize(
          find.byKey(
            ValueKey<String>(
              'session_tab_${sessionTabIdentityKey(tab.identity)}',
            ),
          ),
        )
        .width;
    expect(
      widthOf(inactive),
      moreOrLessEquals(
        _expectedContentWidth(tester, 'Session X'),
        epsilon: 0.01,
      ),
    );
    // Chrome grows by the 32px button plus 10px padding.
    expect(
      widthOf(selected),
      moreOrLessEquals(
        _expectedContentWidth(tester, 'Session X', selected: true),
        epsilon: 0.01,
      ),
    );
  });

  testWidgets('compact tabs use the compact minimum width', (tester) async {
    final tab = _tab('short', title: 'A');

    await tester.pumpWidget(_app(tabs: <SessionTabRecord>[tab], isCompact: true));
    await tester.pump();

    expect(
      tester
          .getSize(
            find.byKey(
              ValueKey<String>(
                'session_tab_${sessionTabIdentityKey(tab.identity)}',
              ),
            ),
          )
          .width,
      moreOrLessEquals(140, epsilon: 0.01),
    );

    final medium = _tab('medium', title: 'Session X');
    await tester.pumpWidget(
      _app(tabs: <SessionTabRecord>[medium], isCompact: true),
    );
    await tester.pump();
    expect(
      tester
          .getSize(
            find.byKey(
              ValueKey<String>(
                'session_tab_${sessionTabIdentityKey(medium.identity)}',
              ),
            ),
          )
          .width,
      moreOrLessEquals(
        _expectedContentWidth(tester, 'Session X', compact: true),
        epsilon: 0.01,
      ),
    );
  });

  testWidgets('tabs never shrink below the minimum when the viewport is narrow', (
    tester,
  ) async {
    final tabs = List<SessionTabRecord>.generate(
      5,
      (index) => _tab('short_$index', title: 'A'),
    );

    await tester.pumpWidget(_app(tabs: tabs, width: 200));
    await tester.pump();

    for (final tab in tabs) {
      expect(
        tester
            .getSize(
              find.byKey(
                ValueKey<String>(
                  'session_tab_${sessionTabIdentityKey(tab.identity)}',
                ),
              ),
            )
            .width,
        moreOrLessEquals(150, epsilon: 0.01),
      );
    }
    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(
          const ValueKey<String>('session_tab_strip_scroll_view'),
        ),
        matching: find.byType(Scrollable),
      ),
    );
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'minimum wins when the viewport is narrower than the minimum',
    (tester) async {
      final tabs = List<SessionTabRecord>.generate(
        3,
        (index) => _tab('short_$index', title: 'A'),
      );

      // 140px viewport minus 16px padding caps the maximum at 124px, below
      // the 150px minimum: tabs must stay at their floor and scroll.
      await tester.pumpWidget(_app(tabs: tabs, width: 140));
      await tester.pump();

      for (final tab in tabs) {
        expect(
          tester
              .getSize(
                find.byKey(
                  ValueKey<String>(
                    'session_tab_${sessionTabIdentityKey(tab.identity)}',
                  ),
                ),
              )
              .width,
          moreOrLessEquals(150, epsilon: 0.01),
        );
      }
      final scrollable = tester.state<ScrollableState>(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('session_tab_strip_scroll_view'),
          ),
          matching: find.byType(Scrollable),
        ),
      );
      expect(scrollable.position.maxScrollExtent, greaterThan(0));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'long titles cap at the viewport width when it is narrower than the maximum',
    (tester) async {
      final tab = _tab('long', title: 'X' * 30);

      await tester.pumpWidget(_app(tabs: <SessionTabRecord>[tab], width: 300));
      await tester.pump();

      expect(
        tester
            .getSize(
              find.byKey(
                ValueKey<String>(
                  'session_tab_${sessionTabIdentityKey(tab.identity)}',
                ),
              ),
            )
            .width,
        moreOrLessEquals(284, epsilon: 0.01),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('long titles cap at the maximum width and ellipsize', (
    tester,
  ) async {
    final tab = _tab('long', title: 'X' * 60);

    await tester.pumpWidget(_app(tabs: <SessionTabRecord>[tab]));
    await tester.pump();

    expect(
      tester
          .getSize(
            find.byKey(
              ValueKey<String>(
                'session_tab_${sessionTabIdentityKey(tab.identity)}',
              ),
            ),
          )
          .width,
      moreOrLessEquals(317.2, epsilon: 0.01),
    );
    final title = tester.widget<Text>(
      find.byKey(
        ValueKey<String>(
          'session_tab_title_${sessionTabIdentityKey(tab.identity)}',
        ),
      ),
    );
    expect(title.maxLines, 1);
    expect(title.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty titles measure the localized Untitled string', (
    tester,
  ) async {
    final tab = _tab('untitled', title: '   ');

    await tester.pumpWidget(_app(tabs: <SessionTabRecord>[tab]));
    await tester.pump();

    final context = tester.element(find.byType(SessionTabStrip));
    expect(
      tester
          .getSize(
            find.byKey(
              ValueKey<String>(
                'session_tab_${sessionTabIdentityKey(tab.identity)}',
              ),
            ),
          )
          .width,
      moreOrLessEquals(
        _expectedContentWidth(tester, context.l10n.sessionExportUntitled),
        epsilon: 0.01,
      ),
    );
  });

  testWidgets('text scale grows content but leaves the minimum fixed', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final short = _tab('short', title: 'A');
    final medium = _tab('medium', title: 'Session X');

    await tester.pumpWidget(_app(tabs: <SessionTabRecord>[short, medium]));
    await tester.pump();

    double widthOf(SessionTabRecord tab) => tester
        .getSize(
          find.byKey(
            ValueKey<String>(
              'session_tab_${sessionTabIdentityKey(tab.identity)}',
            ),
          ),
        )
        .width;
    expect(widthOf(short), moreOrLessEquals(150, epsilon: 0.01));
    expect(
      widthOf(medium),
      moreOrLessEquals(
        _expectedContentWidth(tester, 'Session X', textScale: 2.0),
        epsilon: 0.01,
      ),
    );
  });

  testWidgets('measures RTL titles and stays in bounds', (tester) async {
    final tab = _tab('rtl', title: 'مثال عربي');

    await tester.pumpWidget(
      _app(
        tabs: <SessionTabRecord>[tab],
        textDirection: TextDirection.rtl,
      ),
    );
    await tester.pump();

    expect(
      tester
          .getSize(
            find.byKey(
              ValueKey<String>(
                'session_tab_${sessionTabIdentityKey(tab.identity)}',
              ),
            ),
          )
          .width,
      moreOrLessEquals(
        _expectedContentWidth(tester, 'مثال عربي'),
        epsilon: 0.01,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('strip shrinks to content when fillWidth is false', (
    tester,
  ) async {
    final tabs = <SessionTabRecord>[_tab('a', title: 'A'), _tab('b', title: 'B')];

    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: UnconstrainedBox(
              child: SessionTabStrip(
                tabs: tabs,
                projects: const [],
                openProjectIds: const <String>{},
                isCompact: false,
                fillWidth: false,
                onActivate: (_) {},
                onClose: (_) {},
                onContextMenu: (tab, position, {required haptic}) async {},
                trailingBuilder: (context, tab) => null,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      tester
          .getSize(find.byKey(const ValueKey<String>('session_tab_strip')))
          .width,
      moreOrLessEquals(316, epsilon: 0.01),
    );
  });

  testWidgets('selected pinned tab sizes to its content width', (tester) async {
    final selected = _tab(
      'pinned',
      title: 'Short',
      isPinned: true,
      isSelected: true,
    );

    await tester.pumpWidget(
      _app(
        tabs: <SessionTabRecord>[selected],
        trailingBuilder: (context, tab) =>
            const SizedBox(key: ValueKey<String>('pinned_trailing'), width: 32),
      ),
    );
    await tester.pump();

    expect(
      tester
          .getSize(
            find.byKey(
              ValueKey<String>(
                'session_tab_${sessionTabIdentityKey(selected.identity)}',
              ),
            ),
          )
          .width,
      moreOrLessEquals(
        _expectedContentWidth(tester, 'Short', selected: true),
        epsilon: 0.01,
      ),
    );
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey<String>('session_tab_pinned_region')),
          )
          .width,
      moreOrLessEquals(
        _expectedContentWidth(tester, 'Short', selected: true),
        epsilon: 0.01,
      ),
    );
  });

  testWidgets('pinning or unpinning the selected tab reveals it in its new region', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var tabs = <SessionTabRecord>[
      for (var i = 0; i < 6; i++) _tab('before_$i', title: 'X' * 30),
      _tab('selected', title: 'A', isSelected: true),
    ];
    late void Function(VoidCallback fn) rebuild;

    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return SessionTabStrip(
                tabs: tabs,
                projects: const [],
                openProjectIds: const <String>{},
                isCompact: false,
                onActivate: (_) {},
                onClose: (_) {},
                onContextMenu: (tab, position, {required haptic}) async {},
                trailingBuilder: (context, tab) => null,
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final selectedKey = ValueKey<String>(
      'session_tab_${sessionTabIdentityKey(tabs.last.identity)}',
    );
    Rect selectedRect() => tester.getRect(find.byKey(selectedKey));

    // Pin the selected tab: it moves to the overflowing pinned region and the
    // reveal must bring it into the pinned viewport.
    rebuild(() {
      tabs = [
        ...tabs.take(6),
        _tab('selected', title: 'A', isSelected: true, isPinned: true),
      ];
    });
    await tester.pump();
    await tester.pumpAndSettle();

    final pinnedViewport = tester.getRect(
      find.byKey(const ValueKey<String>('session_tab_pinned_region_scroll_view')),
    );
    expect(selectedRect().left, greaterThanOrEqualTo(pinnedViewport.left - 0.5));
    expect(selectedRect().right, lessThanOrEqualTo(pinnedViewport.right + 0.5));

    // Unpin it back: the reveal must bring it into the regular viewport.
    rebuild(() {
      tabs = [
        ...tabs.take(6),
        _tab('selected', title: 'A', isSelected: true),
      ];
    });
    await tester.pump();
    await tester.pumpAndSettle();

    final regularViewport = tester.getRect(
      find.byKey(const ValueKey<String>('session_tab_strip_scroll_view')),
    );
    expect(selectedRect().left, greaterThanOrEqualTo(regularViewport.left - 0.5));
    expect(selectedRect().right, lessThanOrEqualTo(regularViewport.right + 0.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('unrelated tab width changes do not yank a visible selected tab', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var tabs = <SessionTabRecord>[
      _tab('lead', title: 'A'),
      _tab('selected', title: 'A', isSelected: true),
      for (var i = 0; i < 5; i++) _tab('trail_$i', title: 'X' * 30),
    ];
    late void Function(VoidCallback fn) rebuild;

    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return SessionTabStrip(
                tabs: tabs,
                projects: const [],
                openProjectIds: const <String>{},
                isCompact: false,
                onActivate: (_) {},
                onClose: (_) {},
                onContextMenu: (tab, position, {required haptic}) async {},
                trailingBuilder: (context, tab) => null,
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(
          const ValueKey<String>('session_tab_strip_scroll_view'),
        ),
        matching: find.byType(Scrollable),
      ),
    );
    // The selected tab [150, 300] is fully visible inside [50, 354].
    scrollable.position.jumpTo(50);
    await tester.pump();

    // Rename an unrelated trailing tab: its width changes, which fires the
    // reveal trigger, but the selected tab stays fully visible so the scroll
    // offset must not move.
    rebuild(() {
      tabs = [
        tabs[0],
        tabs[1],
        tabs[2],
        tabs[3],
        tabs[4],
        _tab('trail_5', title: 'X' * 8),
      ];
    });
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      scrollable.position.pixels,
      moreOrLessEquals(50, epsilon: 0.5),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('renaming a tab re-measures its width and keeps the selected tab visible', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var tabs = <SessionTabRecord>[
      for (var i = 0; i < 3; i++) _tab('before_$i', title: 'X' * 30),
      _tab('selected', title: 'A', isSelected: true),
    ];
    late void Function(VoidCallback fn) rebuild;

    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return SessionTabStrip(
                tabs: tabs,
                projects: const [],
                openProjectIds: const <String>{},
                isCompact: false,
                onActivate: (_) {},
                onClose: (_) {},
                onContextMenu: (tab, position, {required haptic}) async {},
                trailingBuilder: (context, tab) => null,
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    final selectedKey =
        ValueKey<String>('session_tab_${sessionTabIdentityKey(tabs.last.identity)}');
    double selectedWidth() =>
        tester.getSize(find.byKey(selectedKey)).width;
    expect(selectedWidth(), moreOrLessEquals(150, epsilon: 0.01));

    rebuild(() {
      tabs = [
        ...tabs.take(3),
        _tab('selected', title: 'X' * 30, isSelected: true),
      ];
    });
    await tester.pump();
    await tester.pumpAndSettle();

    // The viewport caps the re-measured width (320 - 16px padding).
    expect(selectedWidth(), moreOrLessEquals(304, epsilon: 0.01));
    final viewportRect = tester.getRect(
      find.byKey(const ValueKey<String>('session_tab_strip_scroll_view')),
    );
    final selectedRect = tester.getRect(find.byKey(selectedKey));
    expect(selectedRect.left, greaterThanOrEqualTo(viewportRect.left - 0.5));
    expect(selectedRect.right, lessThanOrEqualTo(viewportRect.right + 0.5));
    expect(tester.takeException(), isNull);
  });
}

/// Mirrors the strip's content-width computation using the app's real text
/// style, so expectations stay exact for the actual font metrics.
double _expectedContentWidth(
  WidgetTester tester,
  String title, {
  bool selected = false,
  bool compact = false,
  double textScale = 1.0,
}) {
  final context = tester.element(find.byType(SessionTabStrip));
  final style = Theme.of(context).textTheme.labelLarge?.copyWith(
    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
  );
  final painter = TextPainter(
    text: TextSpan(text: title.split('\n').first, style: style),
    maxLines: 1,
    textDirection: Directionality.of(context),
    textScaler: TextScaler.linear(textScale),
  )..layout();
  final trailingWidth = selected ? (compact ? 40.0 : 32.0) + 10.0 : 10.0;
  final chrome = 10.0 + 28 + 7 + 2 + trailingWidth;
  // The minimum wins over a narrower effective maximum, mirroring the strip.
  return math.max(
    compact ? 140.0 : 150.0,
    math.min(
      compact ? 278.2 : 317.2,
      (chrome + painter.width + 1.0).ceilToDouble(),
    ),
  );
}

Material _tabMaterial(WidgetTester tester, SessionTabRecord tab) {
  return tester.widget<Material>(
    find.byKey(
      ValueKey<String>('session_tab_${sessionTabIdentityKey(tab.identity)}'),
    ),
  );
}

Widget _app({
  required List<SessionTabRecord> tabs,
  List<Project> projects = const <Project>[],
  Set<String> openProjectIds = const <String>{},
  ValueChanged<SessionTabIdentity>? onActivate,
  ValueChanged<SessionTabIdentity>? onClose,
  SessionTabContextMenuCallback? onContextMenu,
  SessionTabTrailingBuilder? trailingBuilder,
  double width = 800,
  bool isCompact = false,
  bool fillWidth = true,
  TextDirection textDirection = TextDirection.ltr,
}) {
  return localizedMaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: Directionality(
            textDirection: textDirection,
            child: SessionTabStrip(
              tabs: tabs,
              projects: projects,
              openProjectIds: openProjectIds,
              isCompact: isCompact,
              fillWidth: fillWidth,
              onActivate: (tab) => onActivate?.call(tab.identity),
              onClose: (tab) => onClose?.call(tab.identity),
              onContextMenu:
                  onContextMenu ?? (tab, position, {required haptic}) async {},
              trailingBuilder: trailingBuilder ?? (context, tab) => null,
            ),
          ),
        ),
      ),
    ),
  );
}

SessionTabRecord _tab(
  String id, {
  String? title,
  SessionStatusType status = SessionStatusType.idle,
  bool isSelected = false,
  bool isPinned = false,
  String? iconPresetId,
  List<String> pendingQuestionIds = const <String>[],
  String? completionToken,
  String? errorToken,
}) {
  return SessionTabRecord(
    identity: _identity(id),
    title: title ?? 'Session $id',
    lastOpenedAtMs: 0,
    serverUpdatedAtMs: 0,
    status: status,
    pendingQuestionIds: pendingQuestionIds,
    completionToken: completionToken,
    errorToken: errorToken,
    isSelected: isSelected,
    isPinned: isPinned,
    iconPresetId: iconPresetId,
  );
}

SessionTabIdentity _identity(String id) {
  return SessionTabIdentity(
    serverId: 'srv_test',
    directory: '/repo/$id',
    sessionId: 'ses_$id',
  );
}
