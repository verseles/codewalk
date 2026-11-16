import 'dart:async';
import 'dart:typed_data';

import 'package:codewalk/features/sessions/project_icon_view.dart';
import 'package:codewalk/features/sessions/session_tab_icon_picker.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk/shared/sessions/project_icon_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:material_symbols_icons/symbols.dart';

Uri raster(String mime, Uint8List bytes) =>
    Uri.dataFromBytes(bytes, mimeType: mime);
final svg = Uri.dataFromString(
  '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16"><path fill="red" d="M0 0h16v16H0z"/></svg>',
  mimeType: 'image/svg+xml',
);

Future<void> show(WidgetTester tester, Uri? source, {ThemeData? theme}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(body: ProjectIconView(source: source, size: 24)),
    ),
  );
  await tester.pump();
  final image = tester.widgetList<Image>(find.byType(Image)).firstOrNull;
  if (image != null) {
    await tester.runAsync(() async {
      final ready = Completer<void>();
      final stream = image.image.resolve(ImageConfiguration.empty);
      final listener = ImageStreamListener(
        (_, _) => ready.complete(),
        onError: (_, _) => ready.complete(),
      );
      stream.addListener(listener);
      await ready.future;
      stream.removeListener(listener);
    });
  }
  await tester.pumpAndSettle();
}

void main() {
  test('URI and size restrictions reject non-images and oversized images', () {
    expect(
      ProjectIconData.fromDataUri(Uri.parse('https://example.com/icon')),
      isNull,
    );
    expect(ProjectIconData.fromDataUri(Uri.dataFromString('text')), isNull);
    expect(
      ProjectIconData.fromDataUri(
        Uri.dataFromBytes(Uint8List(65536), mimeType: 'image/png'),
      ),
      isNull,
    );
    expect(
      ProjectIconData.fromBytes(Uint8List(ProjectIconData.maxBytes + 1)),
      isNull,
    );
    expect(
      ProjectIconData.fromBytes(Uint8List(65537), mediaType: 'image/svg+xml'),
      isNull,
    );
    expect(
      ProjectIconData.fromBytes(
        Uint8List.fromList([1]),
        mediaType: 'text/html',
      ),
      isNull,
    );
    expect(ProjectIconData.fromDataUri(svg)?.svg, isTrue);
    for (final uri in [
      'http://example.com/a',
      'file:///tmp/a',
      'https://u:p@example.com/a',
      'javascript:x',
    ]) {
      expect(isProjectIconNetworkUri(Uri.parse(uri)), isFalse);
    }
    expect(
      isProjectIconNetworkUri(Uri.parse('https://example.com/icon')),
      isTrue,
    );
  });

  testWidgets('PNG and ICO decode, and SVG uses its renderer', (tester) async {
    final pixels = img.Image(width: 2, height: 2)
      ..setPixelRgba(0, 0, 255, 0, 0, 255);
    for (final (mime, bytes) in [
      ('image/png', img.encodePng(pixels)),
      ('image/x-icon', img.encodeIco(pixels)),
    ]) {
      await show(tester, raster(mime, bytes));
      expect(find.byType(Image), findsOneWidget);
      expect(find.byIcon(Symbols.folder_open), findsNothing);
      expect(tester.getSize(find.byType(ProjectIconView)), const Size(24, 24));
      expect(tester.takeException(), isNull);
    }
    await show(tester, svg);
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.byIcon(Symbols.folder_open), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide images preserve their aspect ratio at decode time', (
    tester,
  ) async {
    await show(
      tester,
      raster('image/png', img.encodePng(img.Image(width: 400, height: 100))),
    );
    final decoded = tester.widget<RawImage>(find.byType(RawImage)).image!;
    expect(decoded.width / decoded.height, 4);
    expect(
      decoded.width,
      lessThanOrEqualTo(
        (24 * tester.view.devicePixelRatio).ceil().clamp(1, 128),
      ),
    );
  });

  testWidgets('missing, corrupt and unsupported icons keep theme folder', (
    tester,
  ) async {
    for (final source in [
      null,
      Uri.parse('file:///tmp/logo.png'),
      raster('image/png', Uint8List.fromList([1, 2, 3])),
      Uri.dataFromString('invalid svg', mimeType: 'image/svg+xml'),
    ]) {
      await show(tester, source, theme: ThemeData.dark());
      expect(find.byIcon(Symbols.folder_open), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('the picker previews the project and returns the null preset', (
    tester,
  ) async {
    SessionTabIconSelection? result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: V2Localizations.localizationsDelegates,
        supportedLocales: V2Localizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showSessionTabIconPicker(
                context,
                currentPresetId: null,
                projectIcon: svg,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(ProjectIconView), findsNWidgets(2));
    expect(
      tester
          .widgetList<ProjectIconView>(find.byType(ProjectIconView))
          .every((w) => w.source == svg),
      isTrue,
    );
    await tester.tap(find.text('Use project icon'));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.presetId, isNull);
  });
}
