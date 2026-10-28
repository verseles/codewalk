import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk/shared/rendering/render_code_block.dart';
import 'package:codewalk/shared/theme/opencode_theme_presets.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Long code blocks have accessible horizontal scrollbars (#92).
void main() {
  final tokens = classicThemeTokensFrom(
    ColorScheme.fromSeed(seedColor: Colors.teal),
  );
  final longCode = List.filled(40, 'final value = compute();').join(' ');

  Future<void> show(WidgetTester tester, String code) async {
    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: V2Localizations.localizationsDelegates,
        supportedLocales: V2Localizations.supportedLocales,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: RenderScrollableCodeBlock(
              themeTokens: tokens,
              language: 'dart',
              code: code,
              onCopy: () {},
              child: Text(code, softWrap: false),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  ScrollPosition horizontal(WidgetTester tester) => tester
      .state<ScrollableState>(
        find
            .descendant(
              of: find.byType(RenderScrollableCodeBlock),
              matching: find.byType(Scrollable),
            )
            .first,
      )
      .position;

  FocusNode codeFocus(WidgetTester tester) => Focus.of(
    tester.element(
      find
          .descendant(
            of: find.byType(RenderScrollableCodeBlock),
            matching: find.byType(MouseRegion),
          )
          .first,
    ),
  );

  ScrollPosition vertical(WidgetTester tester) => tester
      .state<ScrollableState>(
        find
            .descendant(
              of: find.byType(RenderScrollableCodeBlock),
              matching: find.byType(Scrollable),
            )
            .last,
      )
      .position;

  testWidgets('an overflowing block scrolls from the keyboard', (tester) async {
    await show(tester, longCode);
    final node = codeFocus(tester);
    expect(node.canRequestFocus, isTrue);
    node.requestFocus();
    await tester.pump();
    final position = horizontal(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    expect(position.pixels, 80);
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    expect(position.pixels, position.maxScrollExtent);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    expect(position.pixels, position.maxScrollExtent - 80);
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    expect(position.pixels, 0);
    // A modified key is left to selection and app shortcuts.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(position.pixels, 0);
  });

  testWidgets(
    'the desktop scrollbar shows on hover and can be dragged',
    (tester) async {
      await show(tester, longCode);
      // The block's own bar, not those the desktop scroll behavior adds.
      Scrollbar bar() => tester.widget<Scrollbar>(
        find
            .descendant(
              of: find.byType(RenderScrollableCodeBlock),
              matching: find.byType(Scrollbar),
            )
            .first,
      );
      expect(bar().thumbVisibility, isFalse);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(
        tester.getCenter(find.byType(RenderScrollableCodeBlock)),
      );
      await tester.pumpAndSettle();
      expect(bar().thumbVisibility, isTrue);
      expect(bar().trackVisibility, isTrue);
      expect(bar().interactive, isTrue);
      final rect = tester.getRect(
        find
            .descendant(
              of: find.byType(RenderScrollableCodeBlock),
              matching: find.byType(Scrollbar),
            )
            .first,
      );
      final thumb = Offset(rect.left + 12, rect.bottom - 3);
      await mouse.moveTo(thumb);
      await mouse.down(thumb);
      await mouse.moveBy(const Offset(60, 0));
      await mouse.up();
      await tester.pumpAndSettle();
      expect(horizontal(tester).pixels, greaterThan(0));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets('a block that fits adds no scrollbar, gutter or tab stop', (
    tester,
  ) async {
    await show(tester, 'short');
    expect(codeFocus(tester).canRequestFocus, isFalse);
    final view = tester.widget<SingleChildScrollView>(
      find
          .descendant(
            of: find.byType(Scrollbar),
            matching: find.byType(SingleChildScrollView),
          )
          .first,
    );
    expect((view.padding! as EdgeInsets).bottom, 8);
  });

  testWidgets('the offset survives a content update and is clamped', (
    tester,
  ) async {
    await show(tester, longCode);
    horizontal(tester).jumpTo(120);
    await show(tester, '$longCode more');
    expect(horizontal(tester).pixels, 120);
    await show(tester, 'final shorter = 1; final shorter2 = 2;');
    final position = horizontal(tester);
    expect(position.pixels, lessThanOrEqualTo(position.maxScrollExtent));
  });

  testWidgets('a vertical wheel is left to the chat', (tester) async {
    await show(tester, longCode);
    final position = horizontal(tester);
    tester.binding.handlePointerEvent(
      PointerScrollEvent(
        position: tester.getCenter(find.byType(RenderScrollableCodeBlock)),
        scrollDelta: const Offset(0, 120),
      ),
    );
    await tester.pump();
    expect(position.pixels, 0);
    tester.binding.handlePointerEvent(
      PointerScrollEvent(
        position: tester.getCenter(find.byType(RenderScrollableCodeBlock)),
        scrollDelta: const Offset(60, 0),
      ),
    );
    await tester.pump();
    expect(position.pixels, 60);
  });

  testWidgets(
    'a vertical wheel over tall code scrolls its parent chat',
    (tester) async {
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final chat = ScrollController();
      addTearDown(chat.dispose);
      final line = List.filled(
        4,
        'final value = computeSomethingLong();',
      ).join(' ');
      final code = List.filled(120, line).join('\n');
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: V2Localizations.localizationsDelegates,
          supportedLocales: V2Localizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              controller: chat,
              child: Column(
                children: [
                  const SizedBox(height: 50),
                  RenderScrollableCodeBlock(
                    themeTokens: tokens,
                    language: 'dart',
                    code: code,
                    onCopy: () {},
                    child: Text(code, softWrap: false),
                  ),
                  const SizedBox(height: 800),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final inner = vertical(tester);
      expect(inner.maxScrollExtent, greaterThan(0));
      tester.binding.handlePointerEvent(
        PointerScrollEvent(
          position: tester.getCenter(find.byType(RenderScrollableCodeBlock)),
          scrollDelta: const Offset(0, 80),
        ),
      );
      await tester.pumpAndSettle();
      expect(chat.offset, 80);
      expect(inner.pixels, 0);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      tester.binding.handlePointerEvent(
        PointerScrollEvent(
          position: tester.getCenter(find.byType(RenderScrollableCodeBlock)),
          scrollDelta: const Offset(0, 60),
        ),
      );
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(chat.offset, 80);
      expect(horizontal(tester).pixels, 60);
      tester.binding.handlePointerEvent(
        PointerScrollEvent(
          position: tester.getCenter(find.byType(RenderScrollableCodeBlock)),
          scrollDelta: const Offset(40, 30),
        ),
      );
      await tester.pumpAndSettle();
      expect(chat.offset, 110);
      expect(horizontal(tester).pixels, 100);
      expect(inner.pixels, 0);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets(
    'standalone tall code keeps its vertical wheel',
    (tester) async {
      await show(tester, List.filled(120, 'code').join('\n'));
      final inner = vertical(tester);
      expect(inner.maxScrollExtent, greaterThan(0));
      tester.binding.handlePointerEvent(
        PointerScrollEvent(
          // Short lines leave empty space beside the narrow vertical viewport.
          position: tester.getCenter(find.byType(Scrollable).last),
          scrollDelta: const Offset(0, 80),
        ),
      );
      await tester.pumpAndSettle();
      expect(inner.pixels, 80);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets(
    'standalone tall code keeps mobile touch scrolling',
    (tester) async {
      await show(tester, List.filled(120, 'code').join('\n'));
      final inner = vertical(tester);
      await tester.dragFrom(
        tester.getCenter(find.byType(Scrollable).last),
        const Offset(0, -120),
      );
      await tester.pumpAndSettle();
      expect(inner.pixels, greaterThan(0));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
