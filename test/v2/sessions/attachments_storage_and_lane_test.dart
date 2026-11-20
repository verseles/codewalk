import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:codewalk/platform/sessions/attachment_staging_store.dart';
import 'package:codewalk/platform/sessions/opencode_attachment_lane.dart';
import 'package:codewalk/platform/sessions/prompt_outbox_store.dart';
import 'package:codewalk/platform/sessions/prompt_payload_store.dart';
import 'package:codewalk/platform/storage/attachment_blob_store.dart';
import 'package:codewalk/platform/storage/attachment_blob_store_io.dart';
import 'package:codewalk/shared/media/attachment_sniff.dart';
import 'package:codewalk/shared/sessions/session_attachments.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_test/flutter_test.dart';
import 'package:harness_opencode/harness_opencode.dart';

import 'outbox_fakes.dart';

final _png1x1 = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
  0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41,
  0x54, 0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
  0x00, 0x03, 0x01, 0x01, 0x00, 0x18, 0xDD, 0x8D,
  0xB0, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E,
  0x44, 0xAE, 0x42, 0x60, 0x82,
]);

final _pdfBytes = Uint8List.fromList(utf8.encode('%PDF-1.7\n1 0 obj\n<<>>\nendobj\n'));
final _mp3Bytes = Uint8List.fromList([0x49, 0x44, 0x33, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]);
final _wavBytes = Uint8List.fromList([
  0x52, 0x49, 0x46, 0x46, 0x24, 0x00, 0x00, 0x00,
  0x57, 0x41, 0x56, 0x45, 0x66, 0x6D, 0x74, 0x20,
]);

const _harness = HarnessRef(HostId('profile_one'), HarnessInstanceId('profile_one'));
const _session = SessionRef(HostId('profile_one'), HarnessInstanceId('profile_one'), 'ses_one');
final _profile = EndpointProfile(
  id: 'profile_one',
  label: 'Local',
  endpoint: Uri.parse('http://127.0.0.1/'),
  bindingRevision: 0,
);

final class _ScriptedTransport implements EndpointHttpTransport {
  _ScriptedTransport(this.handler);
  final Future<TransportResponse> Function(TransportRequest request) handler;
  final requests = <TransportRequest>[];

  @override
  Uri get endpoint => Uri.parse('http://127.0.0.1/');

  @override
  bool get isClosed => false;

  @override
  Future<TransportResponse> send(
    TransportRequest request, {
    RequestCancellation? cancellation,
  }) {
    requests.add(request);
    return handler(request);
  }

  @override
  void close() {}
}

void main() {
  group('attachment_sniff & map URI helpers', () {
    test('sniffs magic bytes, probes dimensions, and sanitizes filenames', () {
      expect(sniffAttachmentMime(_png1x1, byteSize: _png1x1.length), 'image/png');
      expect(probeImageDimensions(_png1x1, 'image/png'), (width: 1, height: 1));
      expect(
        sniffAttachmentMime(_pdfBytes, byteSize: _pdfBytes.length),
        'application/pdf',
      );
      expect(
        sniffAttachmentMime(_mp3Bytes, byteSize: _mp3Bytes.length),
        'audio/mpeg',
      );
      expect(
        sniffAttachmentMime(_wavBytes, byteSize: _wavBytes.length),
        'audio/wav',
      );
      expect(
        sniffAttachmentMime(
          Uint8List.fromList(utf8.encode('hello world')),
          byteSize: 11,
          filename: 'notes.md',
        ),
        'text/markdown',
      );
      expect(
        sniffAttachmentMime(
          Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]),
          byteSize: 6,
        ),
        'image/jpeg',
      );
      expect(
        sniffAttachmentMime(
          Uint8List.fromList([0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0x02, 0x00, 0x03, 0x00]),
          byteSize: 10,
        ),
        'image/gif',
      );
      expect(
        probeImageDimensions(
          Uint8List.fromList([0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0x02, 0x00, 0x03, 0x00]),
          'image/gif',
        ),
        (width: 2, height: 3),
      );
      expect(
        sniffAttachmentMime(
          Uint8List.fromList([0x4F, 0x67, 0x67, 0x53, 0x00]),
          byteSize: 5,
        ),
        'audio/ogg',
      );
      expect(
        sniffAttachmentMime(
          Uint8List.fromList([0x66, 0x4C, 0x61, 0x43, 0x00]),
          byteSize: 5,
        ),
        'audio/flac',
      );
      expect(
        sanitizeAttachmentFilename('../../etc/passwd'),
        'passwd',
      );
      expect(sanitizeAttachmentFilename('...'), 'attachment');
      expect(formatAttachmentBytes(512), '512 B');
      expect(formatAttachmentBytes(2048), '2.0 KB');
      expect(formatAttachmentBytes(3 * 1024 * 1024), '3.0 MB');
    });

    test('builds strictly numeric allowlisted map URIs', () {
      final point = GeoPoint(
        latitude: -23.55052,
        longitude: -46.633308,
        label: 'https://evil.example/phish',
      );
      final android = buildAllowlistedMapUri(
        point,
        platform: TargetPlatform.android,
      );
      expect(android.scheme, 'geo');
      expect(isAllowlistedMapUri(android), isTrue);

      final desktop = buildAllowlistedMapUri(
        point,
        platform: TargetPlatform.linux,
      );
      expect(desktop.scheme, 'https');
      expect(desktop.host, 'www.openstreetmap.org');
      expect(isAllowlistedMapUri(desktop), isTrue);

      expect(isAllowlistedMapUri(Uri.parse('javascript:alert(1)')), isFalse);
      expect(isAllowlistedMapUri(Uri.parse('https://evil.example/x')), isFalse);
    });
  });

  group('AttachmentBlobStore & PromptPayloadStore & StagingStore', () {
    test('MemoryAttachmentBlobStore enforces LRU and preserves pinned blobs', () async {
      final store = MemoryAttachmentBlobStore(maxBytes: 10);
      final a = await store.putBytes(Uint8List.fromList([1, 2, 3, 4, 5, 6]));
      await store.pin('draft:1', [a.sha256]);
      final b = await store.putBytes(Uint8List.fromList([7, 8, 9, 10, 11, 12]));
      // Pinned `a` survives LRU eviction; `b` stays as newest.
      expect(await store.readBytes(a.sha256), isNotNull);
      expect(await store.readBytes(b.sha256), isNotNull);
      await store.unpin('draft:1');
      final c = await store.putBytes(Uint8List.fromList([20, 21, 22, 23, 24, 25]));
      expect(await store.readBytes(c.sha256), isNotNull);
      expect(
        () => store.putStream(Stream.value([1, 2, 3, 4, 5]), maxBytes: 4),
        throwsA(isA<AttachmentStageException>()),
      );
      expect(
        () => store.putStream(const Stream.empty(), maxBytes: 4),
        throwsA(isA<AttachmentStageException>()),
      );
      expect(() => requireBlobDigest('../bad'), throwsArgumentError);
    });

    test('FileAttachmentBlobStore writes atomically, pins, and evicts', () async {
      final tempDir = await Directory.systemTemp.createTemp('cw2_blob_test_');
      addTearDown(() => tempDir.delete(recursive: true));
      final store = FileAttachmentBlobStore(
        directory: () async => tempDir,
        maxBytes: 12,
      );
      final streamed = await store.putStream(
        Stream.fromIterable([
          [1, 2, 3, 4],
          [5, 6, 7, 8],
        ]),
        maxBytes: 1024,
      );
      expect(streamed.byteSize, 8);
      expect(streamed.head, [1, 2, 3, 4, 5, 6, 7, 8]);
      await store.pin('owner-a', [streamed.sha256]);
      expect(await store.byteSizeOf(streamed.sha256), 8);
      final read = await store.readBytes(streamed.sha256);
      expect(read, [1, 2, 3, 4, 5, 6, 7, 8]);
      final chunks = await store.openRead(streamed.sha256)!.expand((c) => c).toList();
      expect(chunks, [1, 2, 3, 4, 5, 6, 7, 8]);

      final second = await store.putBytes(Uint8List.fromList(List.filled(8, 9)));
      // Pinned first blob survives even when total > 12.
      expect(await store.byteSizeOf(streamed.sha256), 8);
      expect(await store.byteSizeOf(second.sha256), 8);
      await store.unpin('owner-a');
    });

    test('PromptPayloadStore verifies sha256 and releases pins', () async {
      final blobs = MemoryAttachmentBlobStore();
      final store = PromptPayloadStore(blobs);
      const id = CommandId('cmd-1');
      final ref = await store.write(id, '{"id":"msg_1","text":"hi"}');
      expect(ref, isNotNull);
      expect(await store.read(ref!), '{"id":"msg_1","text":"hi"}');
      // Corrupt expected byte length fails verification.
      expect(
        await store.read(PromptPayloadRef(sha256: ref.sha256, byteLength: 1)),
        isNull,
      );
      await store.release(id);
    });

    test('AttachmentStagingStore persists manifests and drops orphaned blobs', () async {
      final payloads = OutboxStore();
      final blobs = MemoryAttachmentBlobStore();
      final staging = AttachmentStagingStore(payloads: payloads, blobs: blobs);
      final stored = await blobs.putBytes(_png1x1);
      final staged = StagedAttachment(
        id: 'att_1',
        kind: AttachmentKind.image,
        name: 'shot.png',
        mimeType: 'image/png',
        byteSize: _png1x1.length,
        sha256: stored.sha256,
        width: 1,
        height: 1,
      );
      final loc = StagedAttachment.location(
        id: 'att_2',
        location: GeoPoint(latitude: 10.0, longitude: 20.0, label: 'HQ'),
      );
      expect(await staging.save('scope-a', [staged, loc]), isTrue);
      final loaded = await staging.load('scope-a');
      expect(loaded, [staged, loc]);
      await staging.clear('scope-a');
      expect(await staging.load('scope-a'), isEmpty);
    });
  });

  group('OpenCodeAttachmentLane & OpenCodePromptOutbox v2', () {
    test('prepares inline image, streamed audio upload, and location, and resolves media', () async {
      final blobs = MemoryAttachmentBlobStore();
      final pngStored = await blobs.putBytes(_png1x1);
      final mp3Stored = await blobs.putBytes(_mp3Bytes);
      final remoteHash = sha256.convert([9, 8, 7]).toString();

      final transport = _ScriptedTransport((request) async {
        final uri = Uri.parse(request.path);
        if (request.method == 'POST' && uri.path.endsWith('api/experimental/fs/write')) {
          final uploaded = <int>[];
          await for (final chunk in request.bodyStream!) {
            uploaded.addAll(chunk);
          }
          expect(uploaded, _mp3Bytes);
          return outboxJson({
            'data': {'path': uri.queryParameters['path']},
          });
        }
        if (request.method == 'GET' && uri.path.endsWith('api/experimental/media/$remoteHash')) {
          return TransportResponse(
            statusCode: 200,
            headers: const {'content-type': ['image/png']},
            body: Stream.value(_png1x1),
            cancel: () {},
          );
        }
        return outboxJson({'error': 'unexpected'}, status: 404);
      });

      final hydrated = hydrate(
        beginHydration(
          SessionState(
            _session,
            streamPosition: StreamPosition(id: 's', epoch: 'e', seq: BigInt.zero),
          ),
          generation: 'g1',
          readStart: StreamPosition(id: 's', epoch: 'e', seq: BigInt.one),
        ),
        SessionSnapshot(
          ref: _session,
          hydrationGeneration: 'g1',
          info: SnapshotValue(
            value: SessionInfo(
              ref: _session,
              title: 'Test',
              project: ProjectRef(_harness.host, '/work/repo'),
              ownership: const OwnershipInfo.unknown(reason: 'test'),
            ),
            boundary: SnapshotBoundary(
              owner: const SessionOwner(_session),
              hydrationGeneration: 'g1',
              readStart: StreamPosition(id: 's', epoch: 'e', seq: BigInt.one),
              readStartedAt: DateTime.utc(2026),
              authority: const OpenValue.known(SnapshotAuthority.authoritative),
            ),
          ),
        ),
      ).state;

      final lane = OpenCodeAttachmentLane(
        transport: transport,
        harness: _harness,
        connectedVersion: '2.0.22',
        blobs: blobs,
        temporaryPath: '/tmp/oc',
        view: (_) => SessionLiveView(
          session: _session,
          phase: SessionLivePhase.live,
          state: hydrated,
        ),
        modelInputModalities: (_) => const {'image': true, 'pdf': true},
        currentBinding: () => true,
      );
      addTearDown(lane.dispose);

      expect(lane.supportsStageUpload, isTrue);
      expect(lane.supportsMediaRead, isTrue);

      final imgRef = StagedAttachment(
        id: 'a1',
        kind: AttachmentKind.image,
        name: 'shot.png',
        mimeType: 'image/png',
        byteSize: _png1x1.length,
        sha256: pngStored.sha256,
        width: 1,
        height: 1,
      ).toAttachmentRef();
      final audioRef = StagedAttachment(
        id: 'a2',
        kind: AttachmentKind.audio,
        name: 'voice.mp3',
        mimeType: 'audio/mpeg',
        byteSize: _mp3Bytes.length,
        sha256: mp3Stored.sha256,
      ).toAttachmentRef();
      final locRef = StagedAttachment.location(
        id: 'a3',
        location: GeoPoint(latitude: -23.5, longitude: -46.6, label: 'Office'),
      ).toAttachmentRef();

      final prepared = await lane.prepareForSubmit(
        session: _session,
        draft: PromptDraft(text: 'check', attachments: [imgRef, audioRef, locRef]),
      );
      expect(prepared, hasLength(3));
      expect(prepared[0], isA<OpenCodeInlineAttachment>());
      expect(prepared[1], isA<OpenCodePathAttachment>());
      expect(prepared[2], isA<OpenCodeLocationAttachment>());

      // Read local blob & remote media:<hash> through AttachmentFacet.
      final localMedia = await lane.read(audioRef);
      expect(localMedia?.bytes, _mp3Bytes);
      final remoteMedia = await lane.read(
        AttachmentRef(
          id: 'r1',
          mimeType: 'image/png',
          kind: const OpenValue.known(AttachmentKind.image),
          content: OutputRef(id: 'media:$remoteHash', mimeType: 'image/png'),
        ),
      );
      expect(remoteMedia?.bytes, _png1x1);

      // Inline cache sink populates memory & local store.
      final inlineHash = sha256.convert([1, 2, 3]).toString();
      lane.cacheInlineMedia('inline:$inlineHash', Uint8List.fromList([1, 2, 3]), 'text/plain');
      final inlineRead = await lane.read(
        AttachmentRef(
          id: 'i1',
          mimeType: 'text/plain',
          content: OutputRef(id: 'inline:$inlineHash', mimeType: 'text/plain'),
        ),
      );
      expect(inlineRead?.bytes, [1, 2, 3]);
    });

    test('OpenCodePromptOutbox spills >32KiB attachment payloads out-of-band, replays cleanly, and restores on take-back', () async {
      final server = OutboxServer();
      final store = OutboxStore();
      final blobs = MemoryAttachmentBlobStore();
      final payloadBlobs = PromptPayloadStore(blobs);

      // 40 KiB PNG-headed payload forces out-of-band PromptPayloadStore (>32 KiB).
      final bigPng = Uint8List(40 * 1024)..setRange(0, _png1x1.length, _png1x1);
      final stored = await blobs.putBytes(bigPng);
      final imgRef = StagedAttachment(
        id: 'att_big',
        kind: AttachmentKind.image,
        name: 'big.png',
        mimeType: 'image/png',
        byteSize: bigPng.length,
        sha256: stored.sha256,
      ).toAttachmentRef();

      final client = OpenCodePromptClient(
        server.transport,
        harness: _harness,
        connectedVersion: '2.0.22',
      );
      final reader = OpenCodeSessionReader(server.transport, harness: _harness);
      addTearDown(reader.dispose);

      final outbox = OpenCodePromptOutbox(
        store: store,
        client: client,
        reader: reader,
        ids: OpenCodeMessageIds(),
        profile: _profile,
        payloadBlobs: payloadBlobs,
        prepareAttachments: ({required session, required draft, cancellation}) async => [
          OpenCodeInlineAttachment(
            name: 'big.png',
            mimeType: 'image/png',
            base64Data: base64Encode(bigPng),
            byteSize: bigPng.length,
          ),
        ],
      );

      // 1. Lost network on initial send -> uncertain + ledger stays tiny (<4 KiB!).
      server.reachServer = false;
      final first = await outbox.submit(
        session: _session,
        commandId: const CommandId('cmd-big'),
        draft: PromptDraft(text: 'see attached', attachments: [imgRef]),
        delivery: Delivery.queue,
      );
      expect(first.entry?.state, SubmissionKind.uncertain);
      expect(first.entry?.attachments, hasLength(1));
      expect(first.entry?.shownText, 'see attached');
      final rawLedger = store.values[OpenCodePromptOutbox.keyFor(_session)]!;
      expect(rawLedger.length, lessThan(4096));
      expect((jsonDecode(rawLedger) as Map)['schema'], 2);

      // 2. Reconcile replays exact sealed payload from PromptPayloadStore!
      server.reachServer = true;
      final reconciled = await outbox.reconcile(_session, const CommandId('cmd-big'));
      expect(reconciled.posts, 1);
      expect(reconciled.entry?.state, SubmissionKind.admitted);
      expect(server.transport.bodies.last['files'], hasLength(1));

      // 3. Take-back cancels and preserves shownText + attachments.
      final taken = await outbox.cancel(
        _session,
        const CommandId('cmd-big'),
        takeBack: true,
      );
      expect(taken.entry?.state, SubmissionKind.cancelled);
      expect(taken.entry?.takenBack, isTrue);
      expect(taken.entry?.shownText, 'see attached');
      expect(taken.entry?.attachments.single.id, 'att_big');

      // 4. Dismiss releases out-of-band payload pin cleanly.
      expect(await outbox.dismiss(_session, const CommandId('cmd-big')), isTrue);
    });

    test('OpenCodeAttachmentLane maps upload failure reasons accurately and inlines small UTF-8 JSON without temp upload', () async {
      final blobs = MemoryAttachmentBlobStore();
      final jsonBytes = Uint8List.fromList(utf8.encode('{"hello": "world"}'));
      final jsonStored = await blobs.putBytes(jsonBytes);
      final mp3Stored = await blobs.putBytes(_mp3Bytes);

      final hydrated = hydrate(
        beginHydration(
          SessionState(
            _session,
            streamPosition: StreamPosition(id: 's', epoch: 'e', seq: BigInt.zero),
          ),
          generation: 'g1',
          readStart: StreamPosition(id: 's', epoch: 'e', seq: BigInt.one),
        ),
        SessionSnapshot(
          ref: _session,
          hydrationGeneration: 'g1',
          info: SnapshotValue(
            value: SessionInfo(
              ref: _session,
              title: 'Test',
              project: ProjectRef(_harness.host, '/work/repo'),
              ownership: const OwnershipInfo.unknown(reason: 'test'),
            ),
            boundary: SnapshotBoundary(
              owner: const SessionOwner(_session),
              hydrationGeneration: 'g1',
              readStart: StreamPosition(id: 's', epoch: 'e', seq: BigInt.one),
              readStartedAt: DateTime.utc(2026),
              authority: const OpenValue.known(SnapshotAuthority.authoritative),
            ),
          ),
        ),
      ).state;

      // 1. Small UTF-8 .json file inlines cleanly even with temporaryPath == null!
      final noUploadLane = OpenCodeAttachmentLane(
        transport: _ScriptedTransport((_) async => outboxJson({}, status: 500)),
        harness: _harness,
        connectedVersion: '2.0.22',
        blobs: blobs,
        temporaryPath: null,
        view: (_) => SessionLiveView(
          session: _session,
          phase: SessionLivePhase.live,
          state: hydrated,
        ),
        modelInputModalities: (_) => const {},
        currentBinding: () => true,
      );
      addTearDown(noUploadLane.dispose);

      final jsonRef = StagedAttachment(
        id: 'a_json',
        kind: AttachmentKind.file,
        name: 'config.json',
        mimeType: 'application/json',
        byteSize: jsonBytes.length,
        sha256: jsonStored.sha256,
      ).toAttachmentRef();
      final prepared = await noUploadLane.prepareForSubmit(
        session: _session,
        draft: PromptDraft(text: 'check json', attachments: [jsonRef]),
      );
      expect(prepared.single, isA<OpenCodeInlineAttachment>());
      expect((prepared.single as OpenCodeInlineAttachment).mimeType, 'text/plain');

      // 2. Upload HTTP errors & pre-send cancel map to exact typed reasons.
      final audioRef = StagedAttachment(
        id: 'a_mp3',
        kind: AttachmentKind.audio,
        name: 'clip.mp3',
        mimeType: 'audio/mpeg',
        byteSize: _mp3Bytes.length,
        sha256: mp3Stored.sha256,
      ).toAttachmentRef();

      for (final entry in <(int, String)>[
        (401, 'authenticationRequired'),
        (403, 'authenticationRequired'),
        (404, 'uploadUnavailable'),
        (429, 'rateLimited'),
      ]) {
        final lane = OpenCodeAttachmentLane(
          transport: _ScriptedTransport(
            (_) async => outboxJson({'error': 'fail'}, status: entry.$1),
          ),
          harness: _harness,
          connectedVersion: '2.0.22',
          blobs: blobs,
          temporaryPath: '/tmp/oc',
          view: (_) => SessionLiveView(
            session: _session,
            phase: SessionLivePhase.live,
            state: hydrated,
          ),
          modelInputModalities: (_) => const {},
          currentBinding: () => true,
        );
        addTearDown(lane.dispose);
        await expectLater(
          () => lane.prepareForSubmit(
            session: _session,
            draft: PromptDraft(text: '', attachments: [audioRef]),
          ),
          throwsA(
            isA<OpenCodeAttachmentPrepareException>().having(
              (e) => e.reason,
              'reason',
              entry.$2,
            ),
          ),
        );
      }

      final cancelledToken = RequestCancellation()..cancel();
      await expectLater(
        () => noUploadLane.prepareForSubmit(
          session: _session,
          draft: PromptDraft(text: '', attachments: [jsonRef]),
          cancellation: cancelledToken,
        ),
        throwsA(
          isA<OpenCodeAttachmentPrepareException>().having(
            (e) => e.reason,
            'reason',
            'cancelledBeforeSend',
          ),
        ),
      );
    });

    test('OpenCodePromptOutbox pins local attachment blobs across LRU eviction until dismissed', () async {
      final server = OutboxServer();
      final store = OutboxStore();
      // Tight 64 KiB cache so inserting two 40 KiB blobs forces LRU eviction.
      final blobs = MemoryAttachmentBlobStore(maxBytes: 64 * 1024);
      final payloadBlobs = PromptPayloadStore(blobs);

      final keptBytes = Uint8List.fromList(List.filled(24 * 1024, 0x41));
      final keptStored = await blobs.putBytes(keptBytes);
      await blobs.pin('staging:sess-1', [keptStored.sha256]);
      final attRef = StagedAttachment(
        id: 'att_pinned',
        kind: AttachmentKind.file,
        name: 'notes.txt',
        mimeType: 'text/plain',
        byteSize: keptBytes.length,
        sha256: keptStored.sha256,
      ).toAttachmentRef();

      final client = OpenCodePromptClient(
        server.transport,
        harness: _harness,
        connectedVersion: '2.0.22',
      );
      final reader = OpenCodeSessionReader(server.transport, harness: _harness);
      addTearDown(reader.dispose);

      final outbox = OpenCodePromptOutbox(
        store: store,
        client: client,
        reader: reader,
        ids: OpenCodeMessageIds(),
        profile: _profile,
        payloadBlobs: payloadBlobs,
        attachmentBlobs: blobs,
        prepareAttachments: ({required session, required draft, cancellation}) async => [
          OpenCodeInlineAttachment(
            name: 'notes.txt',
            mimeType: 'text/plain',
            base64Data: base64Encode(keptBytes),
            byteSize: keptBytes.length,
          ),
        ],
      );

      final submitted = await outbox.submit(
        session: _session,
        commandId: const CommandId('cmd-pin'),
        draft: PromptDraft(text: 'keep me', attachments: [attRef]),
        delivery: Delivery.queue,
      );
      expect(submitted.entry?.state, SubmissionKind.admitted);

      // Composer clears staging pins after send.
      await blobs.unpin('staging:sess-1');

      // Heavy LRU churn must NOT evict the outbox-pinned attachment blob.
      await blobs.putBytes(Uint8List.fromList(List.filled(40 * 1024, 0x42)));
      await blobs.putBytes(Uint8List.fromList(List.filled(40 * 1024, 0x43)));
      expect(await blobs.readBytes(keptStored.sha256), keptBytes);

      // Once dismissed, the outbox pin is released and LRU can reclaim space.
      expect(await outbox.dismiss(_session, const CommandId('cmd-pin')), isTrue);
      await blobs.putBytes(Uint8List.fromList(List.filled(40 * 1024, 0x44)));
      await blobs.putBytes(Uint8List.fromList(List.filled(40 * 1024, 0x45)));
      expect(await blobs.readBytes(keptStored.sha256), isNull);
    });
  });
}
