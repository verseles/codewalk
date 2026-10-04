import 'package:codewalk/shared/layout/window_size_class.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('context classification follows viewport changes', (
    tester,
  ) async {
    final resolved = <WindowSizeClass>[];
    Widget surface(double width) => MediaQuery(
      data: MediaQueryData(size: Size(width, 800)),
      child: Builder(
        builder: (context) {
          resolved.add(context.windowSizeClass);
          return const SizedBox();
        },
      ),
    );
    await tester.pumpWidget(surface(390));
    await tester.pumpWidget(surface(1280));
    expect(resolved, [WindowSizeClass.compact, WindowSizeClass.large]);
  });

  group('WindowSizeClass.fromWidth', () {
    test('returns compact for widths below 600', () {
      expect(WindowSizeClass.fromWidth(0), WindowSizeClass.compact);
      expect(WindowSizeClass.fromWidth(320), WindowSizeClass.compact);
      expect(WindowSizeClass.fromWidth(599), WindowSizeClass.compact);
    });

    test('returns medium at boundary 600', () {
      expect(WindowSizeClass.fromWidth(600), WindowSizeClass.medium);
    });

    test('returns medium for widths 600-839', () {
      expect(WindowSizeClass.fromWidth(700), WindowSizeClass.medium);
      expect(WindowSizeClass.fromWidth(839), WindowSizeClass.medium);
    });

    test('returns expanded at boundary 840', () {
      expect(WindowSizeClass.fromWidth(840), WindowSizeClass.expanded);
    });

    test('returns expanded for widths 840-1199', () {
      expect(WindowSizeClass.fromWidth(1000), WindowSizeClass.expanded);
      expect(WindowSizeClass.fromWidth(1199), WindowSizeClass.expanded);
    });

    test('returns large at boundary 1200', () {
      expect(WindowSizeClass.fromWidth(1200), WindowSizeClass.large);
    });

    test('returns large for widths 1200-1599', () {
      expect(WindowSizeClass.fromWidth(1400), WindowSizeClass.large);
      expect(WindowSizeClass.fromWidth(1599), WindowSizeClass.large);
    });

    test('returns extraLarge at boundary 1600', () {
      expect(WindowSizeClass.fromWidth(1600), WindowSizeClass.extraLarge);
    });

    test('returns extraLarge for very wide widths', () {
      expect(WindowSizeClass.fromWidth(2560), WindowSizeClass.extraLarge);
    });
  });

  group('WindowSizeClass convenience getters', () {
    test('isCompact', () {
      expect(WindowSizeClass.compact.isCompact, isTrue);
      expect(WindowSizeClass.medium.isCompact, isFalse);
    });

    test('isAtLeastMedium', () {
      expect(WindowSizeClass.compact.isAtLeastMedium, isFalse);
      expect(WindowSizeClass.medium.isAtLeastMedium, isTrue);
      expect(WindowSizeClass.expanded.isAtLeastMedium, isTrue);
    });

    test('isAtLeastExpanded', () {
      expect(WindowSizeClass.compact.isAtLeastExpanded, isFalse);
      expect(WindowSizeClass.medium.isAtLeastExpanded, isFalse);
      expect(WindowSizeClass.expanded.isAtLeastExpanded, isTrue);
      expect(WindowSizeClass.large.isAtLeastExpanded, isTrue);
    });

    test('isAtLeastLarge', () {
      expect(WindowSizeClass.expanded.isAtLeastLarge, isFalse);
      expect(WindowSizeClass.large.isAtLeastLarge, isTrue);
      expect(WindowSizeClass.extraLarge.isAtLeastLarge, isTrue);
    });

    test('isAtLeastExtraLarge', () {
      expect(WindowSizeClass.large.isAtLeastExtraLarge, isFalse);
      expect(WindowSizeClass.extraLarge.isAtLeastExtraLarge, isTrue);
    });
  });
}
