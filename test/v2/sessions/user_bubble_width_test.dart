import 'package:codewalk/features/sessions/session_timeline_tile.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk_core/codewalk_core.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _harness = HarnessRef(HostId('h'), HarnessInstanceId('test'));

ItemMeta _meta(String id, {MessageContext? message}) => ItemMeta(
  id: ItemId('width/$id'),
  generation: 'g1',
  status: const OpenValue.known(ItemStatus.completed),
  source: SourceProvenance(
    harness: _harness,
    version: '2.0.22',
    nativeType: 'user',
  ),
  message: message,
);

UserInput _user(
  String id,
  String text, {
  MessageContext? message,
  List<AttachmentRef> attachments = const [],
}) => UserInput(
  meta: _meta(id, message: message),
  text: text,
  delivery: const OpenValue.known(DeliveryState.delivered),
  attachments: attachments,
);

AssistantText _assistant(String id, String text, {MessageContext? message}) =>
    AssistantText(
      meta: _meta(id, message: message),
      text: text,
      complete: true,
    );

Widget _surface(
  Widget child, {
  double width = 390,
  TextDirection direction = TextDirection.ltr,
  TextScaler textScaler = TextScaler.noScaling,
}) => MaterialApp(
  localizationsDelegates: V2Localizations.localizationsDelegates,
  supportedLocales: V2Localizations.supportedLocales,
  home: Directionality(
    textDirection: direction,
    child: MediaQuery(
      data: MediaQueryData(size: Size(width, 800), textScaler: textScaler),
      child: Scaffold(
        body: SizedBox(width: width, child: child),
      ),
    ),
  ),
);

void _setSurfaceSize(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('short user messages shrink to content on phone and desktop', (
    tester,
  ) async {
    for (final laneWidth in [390.0, 1280.0]) {
      _setSurfaceSize(tester, laneWidth);
      await tester.pumpWidget(
        _surface(
          Column(
            children: [
              SessionTimelineTile(item: _user('hi', 'Oi')),
              SessionTimelineTile(item: _user('greet', 'Olá, tudo bem?')),
            ],
          ),
          width: laneWidth,
        ),
      );
      final hiRect = tester.getRect(
        find.byKey(const ValueKey('message-bubble-width/hi')),
      );
      final greetRect = tester.getRect(
        find.byKey(const ValueKey('message-bubble-width/greet')),
      );
      expect(hiRect.width, lessThan(120));
      // Under Flutter's square Ahem test font, 14 chars take ~230px + chrome,
      // well below the 85% phone (331.5) and 640 desktop caps.
      expect(greetRect.width, lessThan(laneWidth == 390.0 ? 300 : 320));
      expect(hiRect.width, lessThan(greetRect.width));
      expect(hiRect.height, greaterThanOrEqualTo(48));
      expect(hiRect.right, closeTo(laneWidth, 0.5));
      expect(greetRect.right, closeTo(laneWidth, 0.5));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('short user bubble with clock header still shrink-wraps', (
    tester,
  ) async {
    _setSurfaceSize(tester, 390);
    final msg = MessageContext(
      message: MessageRef('m1'),
      created: DateTime.utc(2026, 11, 25, 13, 5),
    );
    await tester.pumpWidget(
      _surface(
        SessionTimelineTile(
          item: _user('clock', 'Oi', message: msg),
          messageHeader: true,
        ),
        width: 390,
      ),
    );
    final rect = tester.getRect(
      find.byKey(const ValueKey('message-bubble-width/clock')),
    );
    expect(rect.width, lessThan(140));
    expect(rect.height, greaterThanOrEqualTo(48));
    expect(rect.height, lessThan(120));
    expect(tester.takeException(), isNull);
  });

  testWidgets('long user paragraph caps at 85% on phone and 640 on desktop', (
    tester,
  ) async {
    final longText = List.filled(
      8,
      'palavras longas para quebrar linha',
    ).join(' ');
    for (final (laneWidth, cap) in [(390.0, 390.0 * 0.85), (1280.0, 640.0)]) {
      _setSurfaceSize(tester, laneWidth);
      await tester.pumpWidget(
        _surface(
          SingleChildScrollView(
            child: SessionTimelineTile(item: _user('long', longText)),
          ),
          width: laneWidth,
        ),
      );
      final rect = tester.getRect(
        find.byKey(const ValueKey('message-bubble-width/long')),
      );
      expect(rect.width, lessThanOrEqualTo(cap + 0.5));
      expect(rect.width, greaterThan(cap - 48));
      expect(rect.right, closeTo(laneWidth, 0.5));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'narrow viewport, 200% text scale, RTL, fence and attachments stay bounded',
    (tester) async {
      final attachment = AttachmentRef(
        id: 'att-1',
        kind: const OpenValue.known(AttachmentKind.file),
        mimeType: 'text/plain',
        name: 'note.txt',
        availability: const OpenValue.known(AttachmentAvailability.ready),
        content: OutputRef(
          id: 'local:txt1',
          mimeType: 'text/plain',
          sizeBytes: 42,
        ),
      );
      await tester.pumpWidget(
        _surface(
          SingleChildScrollView(
            child: Column(
              children: [
                SessionTimelineTile(item: _user('narrow', 'Oi')),
                SessionTimelineTile(
                  item: _user('fence', '```dart\nfinal x = 1234567890;\n```'),
                ),
                SessionTimelineTile(
                  item: _user('att', 'Oi', attachments: [attachment]),
                ),
              ],
            ),
          ),
          width: 150,
          direction: TextDirection.rtl,
          textScaler: const TextScaler.linear(2.0),
        ),
      );
      const cap = 150.0 * 0.85;
      for (final id in ['narrow', 'fence', 'att']) {
        final rect = tester.getRect(
          find.byKey(ValueKey('message-bubble-width/$id')),
        );
        expect(rect.width, lessThanOrEqualTo(cap + 0.5));
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('assistant text keeps full reading lane width up to 760', (
    tester,
  ) async {
    _setSurfaceSize(tester, 1280);
    final msg = MessageContext(
      message: MessageRef('a1'),
      created: DateTime.utc(2026, 11, 25, 13, 5),
      completed: DateTime.utc(2026, 11, 25, 13, 5, 3),
    );
    await tester.pumpWidget(
      _surface(
        SessionTimelineTile(
          item: _assistant('a', 'Ok', message: msg),
          messageHeader: true,
        ),
        width: 1280,
      ),
    );
    final rect = tester.getRect(
      find.byKey(const ValueKey('message-bubble-width/a')),
    );
    expect(rect.width, closeTo(760, 0.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'plainTruncated and prefixMissing stay bounded and keep assistant 760 lane',
    (tester) async {
      _setSurfaceSize(tester, 1280);
      final huge = List.filled(70000, 'a').join();
      final assistantTrunc = AssistantText(
        meta: _meta('at'),
        text: huge,
        complete: true,
        prefixMissing: true,
      );
      final assistantPrefix = AssistantText(
        meta: _meta('ap'),
        text: 'continued answer',
        complete: true,
        prefixMissing: true,
      );
      final userTrunc = _user('ut', huge);
      await tester.pumpWidget(
        _surface(
          SingleChildScrollView(
            child: Column(
              children: [
                SessionTimelineTile(item: assistantTrunc),
                SessionTimelineTile(item: assistantPrefix),
                SessionTimelineTile(item: userTrunc),
              ],
            ),
          ),
          width: 1280,
        ),
      );
      expect(
        tester
            .getRect(find.byKey(const ValueKey('message-bubble-width/at')))
            .width,
        closeTo(760, 0.5),
      );
      expect(
        tester
            .getRect(find.byKey(const ValueKey('message-bubble-width/ap')))
            .width,
        closeTo(760, 0.5),
      );
      expect(
        tester
            .getRect(find.byKey(const ValueKey('message-bubble-width/ut')))
            .width,
        lessThanOrEqualTo(640.5),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
