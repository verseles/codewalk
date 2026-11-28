import 'dart:async';
import 'dart:typed_data';

import 'package:codewalk/features/sessions/session_attachment_scope.dart';
import 'package:codewalk/features/sessions/session_timeline_tile.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk/shared/media/attachment_picker.dart';
import 'package:codewalk/shared/media/audio_playback.dart';
import 'package:codewalk_core/codewalk_core.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

final _png1x1 = Uint8List.fromList([
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x02,
  0x00,
  0x00,
  0x00,
  0x90,
  0x77,
  0x53,
  0xDE,
  0x00,
  0x00,
  0x00,
  0x0C,
  0x49,
  0x44,
  0x41,
  0x54,
  0x08,
  0xD7,
  0x63,
  0xF8,
  0xCF,
  0xC0,
  0x00,
  0x00,
  0x03,
  0x01,
  0x01,
  0x00,
  0x18,
  0xDD,
  0x8D,
  0xB0,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

final _mp3Bytes = Uint8List.fromList([
  0x49,
  0x44,
  0x33,
  0x03,
  0x00,
  0x00,
  0x00,
]);
final _pdfBytes = Uint8List.fromList('%PDF-1.7\ndoc'.codeUnits);

final _source = SourceProvenance(
  harness: const HarnessRef(HostId('h1'), HarnessInstanceId('i1')),
  version: '2.0.22',
  nativeType: 'user',
);

UserInput _userItem(
  String id,
  List<AttachmentRef> attachments, {
  String text = '',
}) => UserInput(
  meta: ItemMeta(
    id: ItemId(id),
    generation: 'g1',
    status: const OpenValue.known(ItemStatus.completed),
    source: _source,
  ),
  text: text,
  attachments: attachments,
  delivery: const OpenValue.known(DeliveryState.delivered),
  confirmed: true,
);

final class _FakeFacet implements AttachmentFacet {
  _FakeFacet(this.mediaById);
  final Map<String, AttachmentMedia> mediaById;
  int failCount = 0;

  @override
  Future<AttachmentMedia?> read(AttachmentRef ref) async {
    if (failCount > 0) {
      failCount--;
      throw StateError('transient read failure');
    }
    return mediaById[ref.content.id];
  }
}

final class _FakeAudioPlayback implements AudioPlaybackPort {
  _FakeAudioPlayback();
  @override
  bool get supported => true;
  final _controller = StreamController<AudioPlaybackState>.broadcast();
  AudioPlaybackState _state = const AudioPlaybackState();
  final seekHistory = <Duration>[];

  @override
  AudioPlaybackState get current => _state;

  @override
  Stream<AudioPlaybackState> get updates => _controller.stream;

  void _emit(AudioPlaybackState next) {
    _state = next;
    _controller.add(next);
  }

  @override
  Future<void> togglePlay({
    required String id,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    if (_state.activeId == id && _state.status == AudioPlaybackStatus.playing) {
      _emit(_state.copyWith(status: AudioPlaybackStatus.paused));
      return;
    }
    _emit(
      AudioPlaybackState(
        activeId: id,
        status: AudioPlaybackStatus.playing,
        position: const Duration(seconds: 5),
        duration: const Duration(seconds: 30),
      ),
    );
  }

  @override
  Future<void> seek(Duration position) async {
    seekHistory.add(position);
    _emit(_state.copyWith(position: position));
  }

  @override
  Future<void> stop({String? id}) async {
    if (id != null && current.activeId != id) return;
    _emit(const AudioPlaybackState());
  }

  @override
  Future<void> dispose() => _controller.close();
}

final class _FakeFileOpener implements AttachmentFileOpener {
  _FakeFileOpener();
  final opened = <({String filename, String mimeType, int bytes})>[];

  @override
  Future<bool> openBytes({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) async {
    opened.add((filename: filename, mimeType: mimeType, bytes: bytes.length));
    return true;
  }
}

final class _FakeMapLauncher implements MapUriLauncher {
  _FakeMapLauncher({this.succeed = true});
  bool succeed;
  final launched = <GeoPoint>[];

  @override
  Future<bool> launchLocation(GeoPoint point) async {
    launched.add(point);
    return succeed;
  }
}

Widget _wrap({
  required Widget child,
  AttachmentFacet? facet,
  AudioPlaybackPort? audio,
  AttachmentFileOpener? opener,
  MapUriLauncher? mapLauncher,
}) => MultiProvider(
  providers: [
    Provider<AudioPlaybackPort?>.value(value: audio),
    Provider<AttachmentFileOpener?>.value(value: opener),
    Provider<MapUriLauncher?>.value(value: mapLauncher),
  ],
  child: MaterialApp(
    localizationsDelegates: V2Localizations.localizationsDelegates,
    supportedLocales: V2Localizations.supportedLocales,
    home: Scaffold(
      body: SessionAttachmentScope(
        facet: facet,
        child: SingleChildScrollView(child: child),
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'renders image lightbox, file opener, audio player with scrubber, and location map card',
    (tester) async {
      final imgRef = AttachmentRef(
        id: 'att_img',
        mimeType: 'image/png',
        name: 'diagram.png',
        kind: const OpenValue.known(AttachmentKind.image),
        width: 1,
        height: 1,
        availability: const OpenValue.known(AttachmentAvailability.ready),
        content: OutputRef(
          id: 'inline:img1',
          mimeType: 'image/png',
          sizeBytes: _png1x1.length,
        ),
      );
      final fileRef = AttachmentRef(
        id: 'att_pdf',
        mimeType: 'application/pdf',
        name: 'report.pdf',
        kind: const OpenValue.known(AttachmentKind.file),
        availability: const OpenValue.known(AttachmentAvailability.remote),
        content: OutputRef(
          id: 'media:pdf1',
          mimeType: 'application/pdf',
          sizeBytes: _pdfBytes.length,
        ),
      );
      final audioRef = AttachmentRef(
        id: 'att_aud',
        mimeType: 'audio/mpeg',
        name: 'voice-note.mp3',
        kind: const OpenValue.known(AttachmentKind.audio),
        availability: const OpenValue.known(AttachmentAvailability.ready),
        content: OutputRef(
          id: 'local:aud1',
          mimeType: 'audio/mpeg',
          sizeBytes: _mp3Bytes.length,
        ),
      );
      final point = GeoPoint(
        latitude: -23.55052,
        longitude: -46.633308,
        accuracyMeters: 8,
        label: 'Paulista Ave',
      );
      final locRef = AttachmentRef(
        id: 'att_loc',
        mimeType: 'application/geo+json',
        name: 'Paulista Ave',
        kind: const OpenValue.known(AttachmentKind.location),
        location: point,
        availability: const OpenValue.known(AttachmentAvailability.ready),
        content: OutputRef(id: 'geo:loc1', mimeType: 'application/geo+json'),
      );

      final facet = _FakeFacet({
        'inline:img1': AttachmentMedia(bytes: _png1x1, mimeType: 'image/png'),
        'media:pdf1': AttachmentMedia(
          bytes: _pdfBytes,
          mimeType: 'application/pdf',
        ),
        'local:aud1': AttachmentMedia(bytes: _mp3Bytes, mimeType: 'audio/mpeg'),
      });
      final audio = _FakeAudioPlayback();
      addTearDown(audio.dispose);
      final opener = _FakeFileOpener();
      final mapLauncher = _FakeMapLauncher();

      await tester.pumpWidget(
        _wrap(
          facet: facet,
          audio: audio,
          opener: opener,
          mapLauncher: mapLauncher,
          child: SessionTimelineTile(
            item: _userItem('u1', [
              imgRef,
              fileRef,
              audioRef,
              locRef,
            ], text: 'Look at these'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('timeline-attachment-strip')),
        findsOneWidget,
      );
      expect(find.text('Look at these'), findsOneWidget);

      // 1. Image thumbnail taps into fullscreen InteractiveViewer lightbox.
      await tester.tap(find.byKey(const ValueKey('attachment-image-att_img')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('attachment-image-lightbox')),
        findsOneWidget,
      );
      expect(find.byType(InteractiveViewer), findsOneWidget);
      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();

      // 2. File card opens cached bytes via AttachmentFileOpener.
      await tester.tap(find.byKey(const ValueKey('attachment-file-att_pdf')));
      await tester.pumpAndSettle();
      expect(opener.opened, hasLength(1));
      expect(opener.opened.single.filename, 'report.pdf');
      expect(opener.opened.single.bytes, _pdfBytes.length);

      // 3. Audio card plays, updates clock, seeks via Slider, and pauses.
      await tester.tap(
        find.byKey(const ValueKey('attachment-audio-play-att_aud')),
      );
      await tester.pumpAndSettle();
      expect(audio.current.status, AudioPlaybackStatus.playing);
      expect(find.text('0:05 / 0:30'), findsOneWidget);
      await tester.drag(
        find.byKey(const ValueKey('attachment-audio-slider-att_aud')),
        const Offset(40, 0),
      );
      await tester.pumpAndSettle();
      expect(audio.seekHistory, isNotEmpty);
      await tester.tap(
        find.byKey(const ValueKey('attachment-audio-play-att_aud')),
      );
      await tester.pumpAndSettle();
      expect(audio.current.status, AudioPlaybackStatus.paused);

      // 4. Location card launches map URI with exact GeoPoint.
      await tester.tap(
        find.byKey(const ValueKey('attachment-location-att_loc')),
      );
      await tester.pumpAndSettle();
      expect(mapLauncher.launched, [point]);
    },
  );

  testWidgets(
    'image retry, >25MP guard, omitted audio fallback, and map failure snackbar behave honestly',
    (tester) async {
      final flakyImg = AttachmentRef(
        id: 'att_flaky',
        mimeType: 'image/png',
        name: 'flaky.png',
        kind: const OpenValue.known(AttachmentKind.image),
        availability: const OpenValue.known(AttachmentAvailability.remote),
        content: OutputRef(id: 'media:flaky', mimeType: 'image/png'),
      );
      final hugeImg = AttachmentRef(
        id: 'att_huge',
        mimeType: 'image/png',
        name: 'huge.png',
        kind: const OpenValue.known(AttachmentKind.image),
        width: 6000,
        height: 5000, // 30 MP > 25 MP guard
        availability: const OpenValue.known(AttachmentAvailability.ready),
        content: OutputRef(id: 'inline:huge', mimeType: 'image/png'),
      );
      final omittedAudio = AttachmentRef(
        id: 'att_omitted',
        mimeType: 'audio/mpeg',
        name: 'server-only.mp3',
        kind: const OpenValue.known(AttachmentKind.audio),
        availability: const OpenValue.known(AttachmentAvailability.omitted),
        content: OutputRef(id: 'path:abc123', mimeType: 'audio/mpeg'),
      );
      final locRef = AttachmentRef(
        id: 'att_loc_fail',
        mimeType: 'application/geo+json',
        kind: const OpenValue.known(AttachmentKind.location),
        location: GeoPoint(latitude: 1.23456, longitude: 2.34567),
        availability: const OpenValue.known(AttachmentAvailability.ready),
        content: OutputRef(id: 'geo:fail', mimeType: 'application/geo+json'),
      );

      final facet = _FakeFacet({
        'media:flaky': AttachmentMedia(bytes: _png1x1, mimeType: 'image/png'),
      })..failCount = 1;
      final audio = _FakeAudioPlayback();
      addTearDown(audio.dispose);
      final mapLauncher = _FakeMapLauncher(succeed: false);

      await tester.pumpWidget(
        _wrap(
          facet: facet,
          audio: audio,
          mapLauncher: mapLauncher,
          child: SessionTimelineTile(
            item: _userItem('u2', [flakyImg, hugeImg, omittedAudio, locRef]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Flaky image shows Retry, then recovers on tap.
      expect(
        find.byKey(const ValueKey('attachment-image-retry-att_flaky')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('attachment-image-retry-att_flaky')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('attachment-image-att_flaky')),
        findsOneWidget,
      );

      // >25 MP image uses safe fallback tile instead of inline decode.
      expect(
        find.byKey(const ValueKey('attachment-image-fallback-att_huge')),
        findsOneWidget,
      );

      // Omitted audio shows disabled play button and no slider.
      expect(
        find.byKey(const ValueKey('attachment-audio-slider-att_omitted')),
        findsNothing,
      );

      // Failed map launch shows snackbar fallback.
      await tester.tap(
        find.byKey(const ValueKey('attachment-location-att_loc_fail')),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('coordinates copied'), findsOneWidget);
    },
  );

  testWidgets(
    'probes fetched bytes for >25MP guard when metadata omits dimensions and bounds lightbox decode size',
    (tester) async {
      // 24-byte PNG header declaring 6000x5000 (30 MP) without width/height on AttachmentRef.
      final hugeHeaderPng = Uint8List(24)
        ..setRange(0, 8, [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        ..[18] = 0x17
        ..[19] =
            0x70 // 6000
        ..[22] = 0x13
        ..[23] = 0x88; // 5000
      // Unknown-dimension valid image bytes (1x1 PNG treated as image/bmp so probe returns null)
      // to verify lightbox always applies a bounded ResizeImage when dimensions are unknown.
      final timelineHuge = AttachmentRef(
        id: 'att_timeline_huge',
        mimeType: 'image/png',
        name: 'remote-huge.png',
        kind: const OpenValue.known(AttachmentKind.image),
        availability: const OpenValue.known(AttachmentAvailability.remote),
        content: OutputRef(id: 'media:hugehdr', mimeType: 'image/png'),
      );
      final unknownDimImg = AttachmentRef(
        id: 'att_unknown_dim',
        mimeType: 'image/bmp',
        name: 'unknown.bmp',
        kind: const OpenValue.known(AttachmentKind.image),
        availability: const OpenValue.known(AttachmentAvailability.remote),
        content: OutputRef(id: 'media:unk', mimeType: 'image/bmp'),
      );

      final opener = _FakeFileOpener();
      final facet = _FakeFacet({
        'media:hugehdr': AttachmentMedia(
          bytes: hugeHeaderPng,
          mimeType: 'image/png',
        ),
        'media:unk': AttachmentMedia(bytes: _png1x1, mimeType: 'image/bmp'),
      });

      await tester.pumpWidget(
        _wrap(
          facet: facet,
          opener: opener,
          child: SessionTimelineTile(
            item: _userItem('u3', [timelineHuge, unknownDimImg]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Probed 6000x5000 PNG degrades to fallback tile and taps through to external opener.
      expect(
        find.byKey(
          const ValueKey('attachment-image-fallback-att_timeline_huge'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('attachment-image-att_timeline_huge')),
        findsNothing,
      );
      await tester.tap(
        find.byKey(
          const ValueKey('attachment-image-fallback-att_timeline_huge'),
        ),
      );
      await tester.pumpAndSettle();
      expect(opener.opened, hasLength(1));

      // Lightbox bounds decode width via ResizeImage when dimensions are unknown.
      await tester.tap(
        find.byKey(const ValueKey('attachment-image-att_unknown_dim')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('attachment-image-lightbox')),
        findsOneWidget,
      );
      final lightboxImage = tester.widget<Image>(
        find.descendant(
          of: find.byKey(const ValueKey('attachment-image-lightbox')),
          matching: find.byType(Image),
        ),
      );
      expect(lightboxImage.image, isA<ResizeImage>());
      expect((lightboxImage.image as ResizeImage).width, 2048);
    },
  );
}
