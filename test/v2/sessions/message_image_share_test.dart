import 'dart:async';
import 'dart:typed_data';

import 'package:codewalk/features/sessions/message_image_share.dart';
import 'package:codewalk/features/sessions/session_timeline_tile.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk/shared/media/message_image.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/gestures.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';

// #540: a message shared, or saved, as an image.

ItemMeta _meta(String id) => ItemMeta(
  id: ItemId('test/$id'),
  generation: 'test',
  status: const OpenValue.known(ItemStatus.completed),
  source: SourceProvenance(
    harness: const HarnessRef(HostId('h'), HarnessInstanceId('test')),
    version: '2.0.22',
    nativeType: 'test',
  ),
);

AssistantText _agent(String text, {bool complete = true}) =>
    AssistantText(meta: _meta('a'), text: text, complete: complete);

final class _Sink implements MessageImageSink {
  _Sink(this.mode, {this.outcome = MessageImageOutcome.shared});

  @override
  final MessageImageMode mode;
  final MessageImageOutcome outcome;
  final delivered = Completer<(Uint8List, String, Rect?)>();

  @override
  Future<MessageImageOutcome> deliver(
    Uint8List png, {
    required String fileName,
    Rect? origin,
  }) async {
    delivered.complete((png, fileName, origin));
    return outcome;
  }
}

final _shareButton = find.byKey(const ValueKey('message-action-shareImage'));

Future<void> _pump(WidgetTester tester, _Sink? sink, Widget tile) async {
  await tester.pumpWidget(
    Provider<MessageImageSink?>.value(
      value: sink,
      child: MaterialApp(
        localizationsDelegates: V2Localizations.localizationsDelegates,
        supportedLocales: V2Localizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(children: [tile, const SizedBox(height: 600)]),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The capture runs on the engine, outside the test's fake time: real time
/// and frames take turns until the image reaches the sink.
Future<(Uint8List, String, Rect?)> _delivered(
  WidgetTester tester,
  _Sink sink,
) async {
  for (var i = 0; i < 100 && !sink.delivered.isCompleted; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  return sink.delivered.future;
}

Future<void> _openBar(WidgetTester tester, Finder text) async {
  await tester.tap(text);
  await tester.pumpAndSettle();
  await tester.pump(kDoubleTapTimeout);
}

void main() {
  test('the scale follows the screen, up to 3, and fits the image', () {
    expect(messageImageRatio(const Size(300, 100), devicePixelRatio: 2), 2);
    expect(messageImageRatio(const Size(300, 100), devicePixelRatio: 4), 3);
    // Tall: the height bound wins.
    final tall = messageImageRatio(const Size(300, 6000), devicePixelRatio: 3)!;
    expect((6000 + 2 * messageImagePadding) * tall, closeTo(8192, 0.01));
    // Too tall even at half size.
    expect(
      messageImageRatio(const Size(300, 20000), devicePixelRatio: 3),
      isNull,
    );
  });

  test('the file is named after the moment', () {
    final at = DateTime(2026, 3, 4, 5, 6, 7);
    expect(messageImageFileName(at), 'codewalk-message-20260304-050607.png');
  });

  testWidgets('a message shares as a PNG with a margin on the surface', (
    tester,
  ) async {
    final sink = _Sink(MessageImageMode.share);
    await _pump(tester, sink, SessionTimelineTile(item: _agent('the answer')));
    await _openBar(tester, find.text('the answer'));
    final message = tester.getSize(
      find.byKey(const ValueKey('message-bubble-test/a')),
    );
    expect(
      find.descendant(of: _shareButton, matching: find.byType(IconButton)),
      findsOneWidget,
    );
    await tester.tap(_shareButton);
    await tester.pump();
    final (png, name, origin) = await _delivered(tester, sink);
    expect(name, startsWith('codewalk-message-'));
    expect(origin, isNotNull);
    final decoded = img.decodePng(png)!;
    final ratio = tester.view.devicePixelRatio.clamp(0, 3);
    expect(
      decoded.width,
      closeTo((message.width + 2 * messageImagePadding) * ratio, 2),
    );
    expect(
      decoded.height,
      closeTo((message.height + 2 * messageImagePadding) * ratio, 2),
    );
    // The margin is the theme's opaque surface.
    expect(decoded.getPixel(1, 1).a, 255);
  });

  testWidgets('where files cannot be shared, the image is saved', (
    tester,
  ) async {
    final sink = _Sink(
      MessageImageMode.save,
      outcome: MessageImageOutcome.saved,
    );
    await _pump(tester, sink, SessionTimelineTile(item: _agent('the answer')));
    await _openBar(tester, find.text('the answer'));
    // The bar names it by long press.
    await tester.longPress(_shareButton);
    await tester.pump();
    expect(find.text('Save as image'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(_shareButton);
    await tester.pump();
    await _delivered(tester, sink);
    await tester.pumpAndSettle();
    expect(find.text('Image saved'), findsOneWidget);
  });

  testWidgets('a failed delivery says so', (tester) async {
    final sink = _Sink(
      MessageImageMode.share,
      outcome: MessageImageOutcome.failed,
    );
    await _pump(tester, sink, SessionTimelineTile(item: _agent('the answer')));
    await _openBar(tester, find.text('the answer'));
    await tester.tap(_shareButton);
    await tester.pump();
    await _delivered(tester, sink);
    await tester.pumpAndSettle();
    expect(find.text('The image could not be made'), findsOneWidget);
  });

  testWidgets('only a whole message, and only where images can go', (
    tester,
  ) async {
    await _pump(
      tester,
      _Sink(MessageImageMode.share),
      SessionTimelineTile(item: _agent('still writing', complete: false)),
    );
    await _openBar(tester, find.text('still writing'));
    expect(find.byKey(const ValueKey('message-action-copy')), findsOneWidget);
    expect(_shareButton, findsNothing);

    await _pump(tester, null, SessionTimelineTile(item: _agent('the answer')));
    await _openBar(tester, find.text('the answer'));
    expect(_shareButton, findsNothing);
  });
}
