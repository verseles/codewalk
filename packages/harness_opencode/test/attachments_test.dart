import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net.dart';
import 'package:crypto/crypto.dart';
import 'package:harness_opencode/harness_opencode.dart';
import 'package:harness_opencode/src/history_projection.dart';
import 'package:test/test.dart';

final _harness = const HarnessRef(
  HostId('host-a'),
  HarnessInstanceId('opencode-a'),
);
final _session = SessionRef(
  _harness.host,
  _harness.harness,
  'ses_0123456789abcdef',
);

final class _FakeTransport implements EndpointHttpTransport {
  _FakeTransport(this.handler);
  final Future<TransportResponse> Function(TransportRequest) handler;
  final requests = <TransportRequest>[];

  @override
  Uri get endpoint => Uri.parse('http://127.0.0.1:49374');

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

TransportResponse _jsonResponse(int status, Object body) => TransportResponse(
  statusCode: status,
  headers: const {'content-type': ['application/json']},
  body: Stream.value(utf8.encode(jsonEncode(body))),
  cancel: () {},
);

TransportResponse _bytesResponse(int status, List<int> bytes, String mime) =>
    TransportResponse(
      statusCode: status,
      headers: {
        'content-type': [mime],
      },
      body: Stream.value(bytes),
      cancel: () {},
    );

void main() {
  group('attachment_encoding', () {
    test('sniffs magic bytes for image, PDF, audio, and UTF-8 text', () {
      expect(
        sniffOpenCodeMime(
          Uint8List.fromList([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
        ),
        'image/png',
      );
      expect(
        sniffOpenCodeMime(Uint8List.fromList([0xff, 0xd8, 0xff, 0xe0])),
        'image/jpeg',
      );
      expect(
        sniffOpenCodeMime(Uint8List.fromList(utf8.encode('GIF89a'))),
        'image/gif',
      );
      expect(
        sniffOpenCodeMime(Uint8List.fromList(utf8.encode('%PDF-1.7'))),
        'application/pdf',
      );
      expect(
        sniffOpenCodeMime(Uint8List.fromList(utf8.encode('RIFF1234WEBP'))),
        'image/webp',
      );
      expect(
        sniffOpenCodeMime(Uint8List.fromList(utf8.encode('RIFF1234WAVE'))),
        'audio/wav',
      );
      expect(
        sniffOpenCodeMime(Uint8List.fromList(utf8.encode('ID3\x03\x00'))),
        'audio/mpeg',
      );
      expect(
        sniffOpenCodeMime(Uint8List.fromList(utf8.encode('OggS\x00'))),
        'audio/ogg',
      );
      expect(
        sniffOpenCodeMime(Uint8List.fromList(utf8.encode('fLaC\x00'))),
        'audio/flac',
      );
      expect(
        sniffOpenCodeMime(
          Uint8List.fromList([
            0, 0, 0, 20, // box size
            0x66, 0x74, 0x79, 0x70, // ftyp
            0x4d, 0x34, 0x41, 0x20, // M4A
            0, 0, 0, 0,
            0x4d, 0x34, 0x41, 0x20,
          ]),
        ),
        'audio/mp4',
      );
      expect(
        sniffOpenCodeMime(Uint8List.fromList(utf8.encode('hello world\n'))),
        'text/plain',
      );
      expect(
        sniffOpenCodeMime(Uint8List.fromList([0x00, 0x01, 0x02, 0x03])),
        'application/octet-stream',
      );
    });

    test('gates inline eligibility on model inputModalities and sizes', () {
      const noCaps = <String, bool?>{};
      const imgOnly = {'image': true, 'pdf': false};
      const imgAndPdf = {'image': true, 'pdf': true};

      expect(
        canInlineOpenCodeAttachment(
          mimeType: 'image/png',
          byteSize: 1024,
          inputModalities: noCaps,
        ),
        isFalse,
      );
      expect(
        canInlineOpenCodeAttachment(
          mimeType: 'image/png',
          byteSize: 1024,
          inputModalities: imgOnly,
        ),
        isTrue,
      );
      expect(
        canInlineOpenCodeAttachment(
          mimeType: 'application/pdf',
          byteSize: 1024,
          inputModalities: imgOnly,
        ),
        isFalse,
      );
      expect(
        canInlineOpenCodeAttachment(
          mimeType: 'application/pdf',
          byteSize: 1024,
          inputModalities: imgAndPdf,
        ),
        isTrue,
      );
      expect(
        canInlineOpenCodeAttachment(
          mimeType: 'text/plain',
          byteSize: openCodeMaxInlineTextBytes,
          inputModalities: noCaps,
        ),
        isTrue,
      );
      expect(
        canInlineOpenCodeAttachment(
          mimeType: 'text/plain',
          byteSize: openCodeMaxInlineTextBytes + 1,
          inputModalities: noCaps,
        ),
        isFalse,
      );
      expect(
        canInlineOpenCodeAttachment(
          mimeType: 'audio/mpeg',
          byteSize: 100,
          inputModalities: {'audio': true, 'image': true, 'pdf': true},
        ),
        isFalse,
      );
    });

    test('sanitizes filenames and enforces confined temporary upload paths', () {
      expect(
        sanitizeOpenCodeUploadFilename('../../etc/passwd'),
        'passwd',
      );
      expect(
        sanitizeOpenCodeUploadFilename('..hidden file (1).mp3'),
        'hidden_file_1_.mp3',
      );
      expect(sanitizeOpenCodeUploadFilename('...'), 'attachment.bin');
      final longName = '${'a' * 150}.pdf';
      final sanitized = sanitizeOpenCodeUploadFilename(longName);
      expect(sanitized.length, lessThanOrEqualTo(120));
      expect(sanitized, endsWith('.pdf'));

      final expected = buildOpenCodeUploadPath(
        temporaryPath: '/tmp/opencode/',
        uploadId: 'upl_12345678',
        filename: 'voice note.mp3',
      );
      expect(expected, '/tmp/opencode/uploads/upl_12345678/voice_note.mp3');
      expect(
        isTrustedOpenCodeUploadPath(
          returnedPath: expected,
          expectedPath: expected,
          temporaryPath: '/tmp/opencode',
        ),
        isTrue,
      );
      expect(
        isTrustedOpenCodeUploadPath(
          returnedPath: '/tmp/other/file.mp3',
          expectedPath: expected,
          temporaryPath: '/tmp/opencode',
        ),
        isFalse,
      );
      expect(
        () => buildOpenCodeUploadPath(
          temporaryPath: 'relative/tmp',
          uploadId: 'upl_12345678',
          filename: 'a.txt',
        ),
        throwsArgumentError,
      );
    });

    test('round-trips location fences and preserves plain text', () {
      final point = GeoPoint(
        latitude: -23.55052,
        longitude: -46.633308,
        accuracyMeters: 15.2,
        label: 'Praça da Sé',
      );
      final fence = formatCodeWalkLocationFence(point);
      final combined = 'Meet here\n$fence';
      final parsed = parseCodeWalkLocationFences(combined);
      expect(parsed.remainingText, 'Meet here');
      expect(parsed.locations, [point]);

      final plain = parseCodeWalkLocationFences('No fence here');
      expect(plain.remainingText, 'No fence here');
      expect(plain.locations, isEmpty);
    });
  });

  group('attachment_upload_client', () {
    test('streams upload body and validates returned path', () async {
      final received = <int>[];
      final transport = _FakeTransport((req) async {
        expect(req.method, 'POST');
        expect(req.path, startsWith('api/experimental/fs/write?'));
        expect(req.headers['Content-Type'], 'application/octet-stream');
        expect(req.body, isNull);
        expect(req.bodyStream, isNotNull);
        await for (final chunk in req.bodyStream!) {
          received.addAll(chunk);
        }
        final uri = Uri.parse('http://localhost/${req.path}');
        final path = uri.queryParameters['path']!;
        return _jsonResponse(200, {
          'data': {'path': path},
        });
      });

      final client = OpenCodeAttachmentUploadClient(
        transport,
        harness: _harness,
        connectedVersion: '2.0.22',
      );
      final data = utf8.encode('audio-stream-bytes');
      final res = await client.upload(
        sessionDirectory: '/work/repo',
        temporaryPath: '/tmp/oc',
        uploadId: 'abc12345def67890',
        filename: 'clip.mp3',
        bytes: Stream.fromIterable([data.sublist(0, 5), data.sublist(5)]),
        length: data.length,
      );
      expect(res, isA<OpenCodeUploadCompleted>());
      expect(
        (res as OpenCodeUploadCompleted).serverPath,
        '/tmp/oc/uploads/abc12345def67890/clip.mp3',
      );
      expect(received, data);
    });

    test('rejects untrusted server path outside tmp/uploads', () async {
      final transport = _FakeTransport(
        (_) async => _jsonResponse(200, {
          'data': {'path': '/etc/evil.mp3'},
        }),
      );
      final client = OpenCodeAttachmentUploadClient(
        transport,
        harness: _harness,
        connectedVersion: '2.0.22',
      );
      final res = await client.upload(
        sessionDirectory: '/work/repo',
        temporaryPath: '/tmp/oc',
        uploadId: 'abc12345def67890',
        filename: 'clip.mp3',
        bytes: Stream.value(const [1, 2, 3]),
        length: 3,
      );
      expect(
        res,
        isA<OpenCodeUploadFailed>().having((r) => r.reason, 'reason', 'untrustedPath'),
      );
    });
  });

  group('media_client & reader negotiation', () {
    test('fetches media:<64-hex> with LRU caching and falls back on 400 header', () async {
      final png = Uint8List.fromList([0x89, 0x50, 0x4e, 0x47, 1, 2, 3, 4]);
      final hash = sha256.convert(png).toString();
      var mediaCalls = 0;
      var messageCalls = 0;
      final transport = _FakeTransport((req) async {
        if (req.path.startsWith('api/experimental/media/')) {
          mediaCalls++;
          return _bytesResponse(200, png, 'image/png');
        }
        if (req.path.startsWith('api/session/${_session.nativeId}/message')) {
          messageCalls++;
          if (req.headers[openCodeCapabilitiesHeader] != null) {
            return _jsonResponse(400, {'error': 'unsupported header'});
          }
          return _jsonResponse(200, {
            'data': [
              {
                'id': 'msg_001',
                'type': 'user',
                'time': {'created': 1700000000000},
                'text': 'Look at this',
                'files': [
                  {
                    'data': base64Encode(png),
                    'mime': 'image/png',
                    'name': 'shot.png',
                    'source': {'type': 'inline'},
                  },
                ],
              },
            ],
            'cursor': {'previous': null, 'next': null},
          });
        }
        if (req.path.startsWith('api/model')) {
          return _jsonResponse(200, {
            'location': {'directory': '/work/repo'},
            'data': [
              {
                'id': 'claude-sonnet',
                'providerID': 'anthropic',
                'name': 'Claude Sonnet',
                'enabled': true,
                'capabilities': {
                  'tools': true,
                  'input': ['text', 'image', 'pdf'],
                  'output': ['text'],
                },
                'limit': {'context': 200000, 'output': 8192},
                'variants': const [],
              },
            ],
          });
        }
        return _jsonResponse(404, {});
      });

      final media = OpenCodeMediaClient(transport);
      final ref = AttachmentRef(
        id: 'att-1',
        mimeType: 'image/png',
        content: OutputRef(id: 'media:$hash'),
        kind: const OpenValue.known(AttachmentKind.image),
        availability: const OpenValue.known(AttachmentAvailability.remote),
      );
      final first = await media.read(ref);
      final second = await media.read(ref);
      expect(first?.bytes, png);
      expect(second?.bytes, png);
      expect(mediaCalls, 1);

      final reader = OpenCodeSessionReader(
        transport,
        harness: _harness,
        onInlineMedia: media.putInline,
      );
      final page = await reader.readHistory(_session, sourceVersion: '2.0.22');
      expect(messageCalls, 2); // 400 retry without header
      final user = page.items.whereType<UserInput>().single;
      expect(user.attachments, hasLength(1));
      expect(user.attachments.single.content.id, 'inline:$hash');
      expect((await media.read(user.attachments.single))?.bytes, png);

      final models = await reader.readModels('/work/repo');
      expect(models.single.inputModalities['image'], isTrue);
      expect(models.single.inputModalities['pdf'], isTrue);
      expect(models.single.inputModalities['audio'], isFalse);
    });
  });

  group('prompt_client & projection round-trip', () {
    test('builds deterministic payload for image, path audio, and location and projects back cleanly', () async {
      final png = Uint8List.fromList([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
      final audioSha = sha256.convert(utf8.encode('fake-audio')).toString();
      final point = GeoPoint(
        latitude: 37.7749,
        longitude: -122.4194,
        accuracyMeters: 10.0,
        label: 'SF',
      );
      late Map<String, Object?> sentBody;
      final transport = _FakeTransport((req) async {
        sentBody = jsonDecode(utf8.decode(req.body!)) as Map<String, Object?>;
        return _jsonResponse(200, {
          'data': {
            'id': sentBody['id'],
            'sessionID': _session.nativeId,
            'type': 'user',
            'delivery': sentBody['delivery'],
            'time': {'created': 1700000000000},
            'payload': {
              'text': sentBody['text'],
              'files': [
                {
                  'data': base64Encode(png),
                  'mime': 'image/png',
                  'name': 'shot.png',
                  'source': {'type': 'inline'},
                },
              ],
              'metadata': sentBody['metadata'],
            },
          },
        });
      });

      final media = OpenCodeMediaClient(transport);
      final client = OpenCodePromptClient(
        transport,
        harness: _harness,
        connectedVersion: '2.0.22',
        onInlineMedia: media.putInline,
      );
      final attempt = await client.send(
        session: _session,
        commandId: const CommandId('cmd-1'),
        messageId: 'msg_0123456789abcdef',
        draft: PromptDraft(text: ''),
        delivery: Delivery.steer,
        attachments: [
          OpenCodeInlineAttachment(
            name: 'shot.png',
            mimeType: 'image/png',
            base64Data: base64Encode(png),
            byteSize: png.length,
          ),
          OpenCodePathAttachment(
            name: 'memo.mp3',
            mimeType: 'audio/mpeg',
            serverPath: '/tmp/oc/uploads/upl_12345678/memo.mp3',
            byteSize: 4096,
            kind: AttachmentKind.audio,
            sha256: audioSha,
          ),
          OpenCodeLocationAttachment(point: point),
        ],
      );
      expect(attempt.submission?.kind.known, SubmissionKind.admitted);
      expect(sentBody['files'], hasLength(1)); // only inline image in files[]
      final user = attempt.items.whereType<UserInput>().single;
      expect(user.text, '');
      expect(user.attachments, hasLength(3));
      expect(user.attachments[0].kind.known, AttachmentKind.image);
      expect(user.attachments[1].kind.known, AttachmentKind.audio);
      expect(user.attachments[1].content.id, 'local:$audioSha');
      expect(user.attachments[2].kind.known, AttachmentKind.location);
      expect(user.attachments[2].location, point);
      // No user-context-manifest emitted when all attachments projected.
      expect(attempt.items.whereType<UnknownItem>(), isEmpty);

      // Verify history projection fallback when server drops metadata.
      final historyItems = projectOpenCodeHistory(
        [
          {
            'id': 'msg_fallback',
            'type': 'user',
            'time': {'created': 1700000000000},
            'text': 'Here\n${formatCodeWalkLocationFence(point)}',
          },
        ],
        _session,
        sourceVersion: '2.0.22',
      );
      final fallbackUser = historyItems.whereType<UserInput>().single;
      expect(fallbackUser.text, 'Here');
      expect(fallbackUser.attachments.single.kind.known, AttachmentKind.location);
      expect(fallbackUser.attachments.single.location, point);
    });

    test('inlines small UTF-8 text MIME types, handles 0/-0 coords, 19 MiB base64 media/admission caps, and conditional media-uri latch', () async {
      // 1. Small UTF-8 text MIME types (json, markdown, csv, yaml) inline <=256 KiB.
      for (final mime in [
        'text/plain',
        'text/markdown',
        'text/csv',
        'text/yaml',
        'application/json',
        'application/xml',
      ]) {
        expect(
          canInlineOpenCodeAttachment(
            mimeType: mime,
            byteSize: 1024,
            inputModalities: const {},
          ),
          isTrue,
          reason: '$mime <= 256 KiB should inline',
        );
        expect(
          canInlineOpenCodeAttachment(
            mimeType: mime,
            byteSize: openCodeMaxInlineTextBytes + 1,
            inputModalities: const {},
          ),
          isFalse,
          reason: '$mime > 256 KiB should fall back to upload',
        );
      }

      // 2. (0.0, -0.0) formats cleanly as 0 without negative zero and round-trips.
      final zeroPoint = GeoPoint(latitude: 0.0, longitude: -0.0);
      final zeroFence = formatCodeWalkLocationFence(zeroPoint);
      expect(zeroFence, contains('latitude: 0\n'));
      expect(zeroFence, contains('longitude: 0\n'));
      expect(zeroFence, isNot(contains('-0')));
      expect(parseCodeWalkLocationFences(zeroFence).locations.single, zeroPoint);

      // 3. 19 MiB inline payload (~25.3 MiB base64, > 24 MiB) passes both
      //    PromptClient admission and OpenCodeSessionReader history read.
      final bigBytes = Uint8List(19 * 1024 * 1024)
        ..setRange(0, 8, [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
      final bigB64 = base64Encode(bigBytes);
      final bigHash = sha256.convert(bigBytes).toString();
      var headerSeenCount = 0;
      var failBoth400 = true;
      final transport = _FakeTransport((req) async {
        if (req.headers[openCodeCapabilitiesHeader] != null) {
          headerSeenCount++;
        }
        if (req.path.startsWith('api/session/${_session.nativeId}/prompt')) {
          final body = jsonDecode(utf8.decode(req.body!)) as Map<String, Object?>;
          return _jsonResponse(200, {
            'data': {
              'id': body['id'],
              'sessionID': _session.nativeId,
              'type': 'user',
              'delivery': body['delivery'],
              'time': {'created': 1700000000000},
              'payload': {
                'text': body['text'],
                'files': [
                  {
                    'data': bigB64,
                    'mime': 'image/png',
                    'name': 'large.png',
                    'source': {'type': 'inline'},
                  },
                ],
              },
            },
          });
        }
        if (req.path.startsWith('api/session/${_session.nativeId}/message')) {
          if (failBoth400) {
            return _jsonResponse(400, {'error': 'bad cursor'});
          }
          return _jsonResponse(200, {
            'data': [
              {
                'id': 'msg_big',
                'type': 'user',
                'time': {'created': 1700000000000},
                'text': 'Big image',
                'files': [
                  {
                    'data': bigB64,
                    'mime': 'image/png',
                    'name': 'large.png',
                    'source': {'type': 'inline'},
                  },
                ],
              },
            ],
            'cursor': {'previous': null, 'next': null},
          });
        }
        return _jsonResponse(404, {});
      });

      final client = OpenCodePromptClient(
        transport,
        harness: _harness,
        connectedVersion: '2.0.22',
      );
      final admitted = await client.send(
        session: _session,
        commandId: const CommandId('cmd-19m'),
        messageId: 'msg_19m_0123456789',
        draft: PromptDraft(text: 'big'),
        delivery: Delivery.steer,
        attachments: [
          OpenCodeInlineAttachment(
            name: 'large.png',
            mimeType: 'image/png',
            base64Data: bigB64,
            byteSize: bigBytes.length,
          ),
        ],
      );
      expect(admitted.submission?.kind.known, SubmissionKind.admitted);

      // 4. An unrelated 400 that fails both headered and headerless reads must
      //    NOT latch _mediaUriRefused permanently.
      final reader = OpenCodeSessionReader(transport, harness: _harness);
      await expectLater(
        () => reader.readHistory(_session, sourceVersion: '2.0.22'),
        throwsA(isA<OpenCodeSessionReadException>()),
      );
      expect(headerSeenCount, 1);

      failBoth400 = false;
      final page = await reader.readHistory(_session, sourceVersion: '2.0.22');
      // Header was sent again because refusal was not latched!
      expect(headerSeenCount, 2);
      final user = page.items.whereType<UserInput>().single;
      expect(user.attachments.single.content.id, 'inline:$bigHash');
    });

    test('envelope accepts all openCodeIsInlineTextMime types and readHistory adaptively halves limit on bodyTooLarge', () async {
      // 1. buildOpenCodePromptEnvelope directly accepts text/markdown & application/json.
      final mdBytes = utf8.encode('# Title');
      final env = buildOpenCodePromptEnvelope(
        displayText: 'read',
        attachments: [
          OpenCodeInlineAttachment(
            name: 'README.md',
            mimeType: 'text/markdown',
            base64Data: base64Encode(mdBytes),
            byteSize: mdBytes.length,
          ),
          OpenCodeInlineAttachment(
            name: 'data.json',
            mimeType: 'application/json',
            base64Data: base64Encode(utf8.encode('{}')),
            byteSize: 2,
          ),
        ],
      );
      expect(env.refusal, isNull);
      expect(env.envelope?.files, hasLength(2));

      // 2. readHistory halves limit on bodyTooLarge until a single row fits,
      //    while encoding nextCursor with the caller's original limit!
      final requestedLimits = <String?>[];
      final transport = _FakeTransport((req) async {
        final uri = Uri.parse(req.path);
        final lim = uri.queryParameters['limit'];
        requestedLimits.add(lim);
        if (int.parse(lim ?? '50') > 1) {
          // Exceed custom 1 KiB maxMediaBodyBytes when >1 message requested.
          return _bytesResponse(200, Uint8List(2048), 'application/json');
        }
        return _jsonResponse(200, {
          'data': [
            {
              'id': 'msg_one',
              'type': 'user',
              'time': {'created': 1700000000000},
              'text': 'Fits at limit=1',
            },
          ],
          'cursor': {
            'previous': null,
            'next': uri.queryParameters['cursor'] == null ? 'cur_next' : null,
          },
        });
      });

      final reader = OpenCodeSessionReader(
        transport,
        harness: _harness,
        maxMediaBodyBytes: 1024,
      );
      final firstPage = await reader.readHistory(
        _session,
        sourceVersion: '2.0.22',
        limit: 4,
      );
      expect(requestedLimits, ['4', '2', '1']);
      expect(firstPage.items.whereType<UserInput>().single.text, 'Fits at limit=1');
      expect(firstPage.nextCursor, isNotNull);

      // Passing the returned nextCursor with the caller's original limit=4 succeeds!
      final secondPage = await reader.readHistory(
        _session,
        sourceVersion: '2.0.22',
        limit: 4,
        cursor: firstPage.nextCursor,
      );
      expect(secondPage.items.whereType<UserInput>().single.text, 'Fits at limit=1');
    });
  });
}
