import 'dart:convert';
import 'dart:io';

import 'package:codewalk/presentation/services/chat_title_generator.dart';
import 'package:codewalk/presentation/services/workspace_file_operations_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(ChatTitleGenerator.ephemeralSessionIds.clear);

  group('WorkspaceFileOperationsServiceImpl', () {
    test('drive-root direct and nested children retain absolute operation paths', () async {
      for (final parent in ['C:/', 'C:/apps']) {
        final server = _FakeShellServer(shellPayloads: [
          '{"ok":true,"code":"ok","message":"available"}',
          '{"ok":true,"code":"ok"}',
          '{"ok":true,"code":"ok"}',
        ]);
        final service = WorkspaceFileOperationsServiceImpl(dio: server.dio);
        final expected = parent.endsWith('/') ? '${parent}file.txt' : '$parent/file.txt';
        final created = await service.createFile(serverScopeKey: 'windows', rootDirectory: 'C:/', parentDirectory: parent, name: 'file.txt');
        expect(created.ok, isTrue);
        expect(created.path, expected);
        final written = await service.writeFile(serverScopeKey: 'windows', rootDirectory: 'C:/', path: expected, content: 'example');
        expect(written.ok, isTrue);
        expect(written.path, expected);
        expect(server.commands.last, contains("CW_PARENT_INPUT='$parent'"));
        expect(server.shellCallCount, 3);
        final outside = await service.writeFile(serverScopeKey: 'windows', rootDirectory: 'C:/', path: 'D:/file.txt', content: 'example');
        expect(outside.code, WorkspaceFileOperationCode.outsideRoot);
        expect(server.shellCallCount, 3);
      }
    });
    test('extracts the last sentinel payload from nested shell parts', () {
      final payload = WorkspaceFileOperationsServiceImpl.extractSentinelPayload(
        <String, dynamic>{
          'parts': <dynamic>[
            <String, dynamic>{'text': 'noise'},
            <String, dynamic>{
              'state': <String, dynamic>{
                'output': 'first\nCW_FILE_OP_JSON:{"ok":true,"code":"ok"}',
              },
            },
          ],
        },
      );

      expect(payload, '{"ok":true,"code":"ok"}');
    });

    test('prefers the last valid official completed tool output', () {
      final payload = WorkspaceFileOperationsServiceImpl.extractSentinelPayload(
        <String, dynamic>{
          'info': <String, dynamic>{'role': 'assistant'},
          'parts': <dynamic>[
            <String, dynamic>{
              'type': 'tool',
              'state': <String, dynamic>{
                'status': 'completed',
                'output': 'CW_FILE_OP_JSON:{not json}\n',
              },
            },
            <String, dynamic>{
              'type': 'tool',
              'state': <String, dynamic>{
                'status': 'completed',
                'output':
                    'noise\nCW_FILE_OP_JSON:{"ok":false,"code":"missing"}\n',
              },
            },
          ],
        },
      );

      expect(payload, '{"ok":false,"code":"missing"}');
    });

    test('reassembles a sentinel split across official tool outputs', () {
      final payload = WorkspaceFileOperationsServiceImpl.extractSentinelPayload(
        <String, dynamic>{
          'parts': <dynamic>[
            <String, dynamic>{
              'state': <String, dynamic>{
                'status': 'completed',
                'output': 'CW_FILE_OP_',
              },
            },
            <String, dynamic>{
              'state': <String, dynamic>{
                'status': 'completed',
                'output': 'JSON:{"ok":true,"code":"ok"}\n',
              },
            },
          ],
        },
      );

      expect(payload, '{"ok":true,"code":"ok"}');
    });

    test('maps official tool errors without exposing raw shell output', () {
      final message =
          WorkspaceFileOperationsServiceImpl.extractShellFailureMessage(<
            String,
            dynamic
          >{
            'parts': <dynamic>[
              <String, dynamic>{
                'state': <String, dynamic>{
                  'status': 'error',
                  'error':
                      '/secret/project/file: unexpected end of file near token',
                },
              },
            ],
          });

      expect(
        message,
        'File operation shell command was truncated by the server.',
      );
      expect(message, isNot(contains('/secret/project/file')));
    });

    test('parses malformed sentinel payloads as malformed responses', () {
      final result = WorkspaceFileOperationsServiceImpl.parseSentinelPayload(
        '{not json',
      );

      expect(result.ok, isFalse);
      expect(result.code, WorkspaceFileOperationCode.malformedResponse);
    });

    test('quotes shell values containing spaces and single quotes', () {
      final quoted = WorkspaceFileOperationsServiceImpl.shellQuoteForTest(
        "folder/John's notes",
      );

      expect(quoted, "'folder/John'\\''s notes'");
    });

    test(
      'single-line mutation commands execute create write and delete',
      () async {
        final root = Directory.systemTemp.createTempSync('codewalk-file-op-');
        addTearDown(() {
          if (root.existsSync()) {
            root.deleteSync(recursive: true);
          }
        });
        final service = WorkspaceFileOperationsServiceImpl(dio: Dio());
        const name = 'sample.txt';
        final content =
            'first\r\nsecond\n${List<String>.filled(60 * 1024, 'x').join()}';

        final createCommand = service.buildCreateFileCommandForTest(
          rootDirectory: root.path,
          parentDirectory: root.path,
          name: name,
        );
        final writeCommand = service.buildWriteFileCommandForTest(
          rootDirectory: root.path,
          parentDirectory: root.path,
          name: name,
          content: content,
        );
        final deleteCommand = service.buildDeleteCommandForTest(
          rootDirectory: root.path,
          parentDirectory: root.path,
          name: name,
        );

        for (final command in <String>[
          createCommand,
          writeCommand,
          deleteCommand,
        ]) {
          expect(command, isNot(contains('\n')));
        }
        expect(writeCommand, contains("CW_CONTENT_CHUNK_COUNT='2'"));

        final createResult = await Process.run('/bin/sh', <String>[
          '-c',
          createCommand,
        ]);
        expect(createResult.exitCode, 0, reason: '${createResult.stderr}');
        expect(_parsedShellStdout(createResult.stdout).ok, isTrue);
        final file = File('${root.path}/$name');
        expect(file.existsSync(), isTrue);

        final writeResult = await Process.run('/bin/sh', <String>[
          '-c',
          writeCommand,
        ]);
        expect(writeResult.exitCode, 0, reason: '${writeResult.stderr}');
        expect(_parsedShellStdout(writeResult.stdout).ok, isTrue);
        expect(file.readAsStringSync(), content);

        final deleteResult = await Process.run('/bin/sh', <String>[
          '-c',
          deleteCommand,
        ]);
        expect(deleteResult.exitCode, 0, reason: '${deleteResult.stderr}');
        expect(_parsedShellStdout(deleteResult.stdout).ok, isTrue);
        expect(file.existsSync(), isFalse);
      },
      skip: Platform.isWindows ? 'requires a POSIX shell' : false,
    );

    test(
      'duplicate command preserves binary bytes and refuses overwrite',
      () async {
        final root = Directory.systemTemp.createTempSync('codewalk-copy-op-');
        addTearDown(() {
          if (root.existsSync()) {
            root.deleteSync(recursive: true);
          }
        });
        final source = File('${root.path}/source.bin')
          ..writeAsBytesSync(<int>[0, 1, 2, 127, 128, 255]);
        final destination = File('${root.path}/source copy.bin');
        final service = WorkspaceFileOperationsServiceImpl(dio: Dio());
        final command = service.buildDuplicateFileCommandForTest(
          rootDirectory: root.path,
          parentDirectory: root.path,
          sourceName: 'source.bin',
          destinationName: 'source copy.bin',
        );

        expect(command, isNot(contains('\n')));
        final first = await Process.run('/bin/sh', <String>['-c', command]);
        expect(first.exitCode, 0, reason: '${first.stderr}');
        expect(_parsedShellStdout(first.stdout).ok, isTrue);
        expect(destination.readAsBytesSync(), source.readAsBytesSync());

        destination.writeAsBytesSync(<int>[9, 9, 9]);
        final second = await Process.run('/bin/sh', <String>['-c', command]);
        expect(second.exitCode, 0, reason: '${second.stderr}');
        expect(
          _parsedShellStdout(second.stdout).code,
          WorkspaceFileOperationCode.alreadyExists,
        );
        expect(destination.readAsBytesSync(), <int>[9, 9, 9]);
      },
      skip: Platform.isWindows ? 'requires a POSIX shell' : false,
    );

    test('chunks large editor content below environment entry limits', () {
      final service = WorkspaceFileOperationsServiceImpl(dio: Dio());
      final content = List<String>.filled(200 * 1024, 'x').join();
      final expectedBase64 = base64Encode(utf8.encode(content));

      final command = service.buildWriteFileCommandForTest(
        rootDirectory: '/repo/a',
        parentDirectory: '/repo/a',
        name: 'large.txt',
        content: content,
      );
      final chunks = RegExp(
        r"CW_CONTENT_B64_\d+='([^']*)'",
      ).allMatches(command).map((match) => match.group(1)!).toList();

      expect(chunks.length, greaterThan(1));
      expect(chunks.every((chunk) => chunk.length <= 48 * 1024), isTrue);
      expect(chunks.join(), expectedBase64);
      expect(command, isNot(contains("CW_CONTENT_B64='")));
    });

    test('probes capabilities once and caches the result', () async {
      final fakeServer = _FakeShellServer(
        shellPayloads: <String>[
          '{"ok":true,"code":"ok","message":"available"}',
        ],
      );
      final service = WorkspaceFileOperationsServiceImpl(dio: fakeServer.dio);

      final first = await service.getCapabilities(
        serverScopeKey: 'srv',
        directory: '/repo/a',
      );
      final second = await service.getCapabilities(
        serverScopeKey: 'srv',
        directory: '/repo/a',
      );

      expect(first.shellFileOpsSupported, isTrue);
      expect(second.shellFileOpsSupported, isTrue);
      expect(fakeServer.shellCallCount, 1);
      expect(fakeServer.deletedSessions, <String>['ses_1']);
      expect(fakeServer.createdSessionDirectories, <String?>['/repo/a']);
      expect(fakeServer.shellDirectories, <String?>['/repo/a']);
      expect(fakeServer.deletedSessionDirectories, <String?>['/repo/a']);
    });

    test('negotiates and reuses the first working shell decoder', () async {
      final fakeServer = _FakeShellServer(
        shellPayloads: <String?>[
          null,
          null,
          '{"ok":true,"code":"ok","message":"available"}',
          '{"ok":true,"code":"ok","message":"created"}',
        ],
      );
      final service = WorkspaceFileOperationsServiceImpl(dio: fakeServer.dio);

      final result = await service.createFile(
        serverScopeKey: 'srv',
        rootDirectory: '/repo/a',
        parentDirectory: '/repo/a',
        name: 'new.txt',
      );

      expect(result.ok, isTrue);
      expect(fakeServer.shellCallCount, 4);
      expect(fakeServer.commands[0], contains('| base64 -d |'));
      expect(fakeServer.commands[1], contains('| base64 -D |'));
      expect(fakeServer.commands[2], contains('| base64 --decode |'));
      expect(fakeServer.commands[3], contains('| base64 --decode |'));
    });

    test('invalid names fail before any shell call', () async {
      final fakeServer = _FakeShellServer(shellPayloads: const <String>[]);
      final service = WorkspaceFileOperationsServiceImpl(dio: fakeServer.dio);

      final result = await service.createFile(
        serverScopeKey: 'srv',
        rootDirectory: '/repo/a',
        parentDirectory: '/repo/a',
        name: '../bad.dart',
      );

      expect(result.ok, isFalse);
      expect(result.code, WorkspaceFileOperationCode.invalidName);
      expect(fakeServer.shellCallCount, 0);
    });

    test('root directory keeps shell file operations unsupported', () async {
      final fakeServer = _FakeShellServer(shellPayloads: const <String>[]);
      final service = WorkspaceFileOperationsServiceImpl(dio: fakeServer.dio);

      final capabilities = await service.getCapabilities(
        serverScopeKey: 'srv',
        directory: '/',
      );
      final result = await service.createFile(
        serverScopeKey: 'srv',
        rootDirectory: '/',
        parentDirectory: '/',
        name: 'unsafe.txt',
      );

      expect(capabilities.shellFileOpsSupported, isFalse);
      expect(result.ok, isFalse);
      expect(result.code, WorkspaceFileOperationCode.outsideRoot);
      expect(fakeServer.shellCallCount, 0);
    });

    test(
      'probe fails closed when the server canonicalizes directory to root',
      () async {
        final fakeServer = _FakeShellServer(
          shellPayloads: <String>[
            '{"ok":false,"code":"outsideRoot","message":"Path is outside the project root."}',
          ],
        );
        final service = WorkspaceFileOperationsServiceImpl(dio: fakeServer.dio);

        final capabilities = await service.getCapabilities(
          serverScopeKey: 'srv',
          directory: '/tmp/link-to-root',
        );

        expect(capabilities.shellFileOpsSupported, isFalse);
        expect(fakeServer.shellCallCount, 1);
        final script = _decodedMutationScript(fakeServer.commands.single);
        expect(script, contains('pwd -P'));
        expect(script, contains(r'if [ "$root" = / ]'));
      },
    );

    test(
      'mutation script rejects canonical root even for non-literal roots',
      () async {
        final fakeServer = _FakeShellServer(
          shellPayloads: <String>[
            '{"ok":true,"code":"ok","message":"available"}',
            '{"ok":false,"code":"outsideRoot","message":"Path is outside the project root."}',
          ],
        );
        final service = WorkspaceFileOperationsServiceImpl(dio: fakeServer.dio);

        final result = await service.createFile(
          serverScopeKey: 'srv',
          rootDirectory: '/tmp/link-to-root',
          parentDirectory: '/tmp/link-to-root',
          name: 'unsafe.txt',
        );

        expect(result.ok, isFalse);
        expect(result.code, WorkspaceFileOperationCode.outsideRoot);
        expect(fakeServer.shellCallCount, 2);
        expect(
          _decodedMutationScript(fakeServer.commands.last),
          contains(r'if [ "$root" = "/" ]; then cw_fail outsideRoot; fi'),
        );
      },
    );

    test(
      'create file uses probe then operation and returns target path',
      () async {
        final fakeServer = _FakeShellServer(
          shellPayloads: <String>[
            '{"ok":true,"code":"ok","message":"available"}',
            '{"ok":true,"code":"ok","message":"ok"}',
          ],
        );
        final service = WorkspaceFileOperationsServiceImpl(dio: fakeServer.dio);

        final result = await service.createFile(
          serverScopeKey: 'srv',
          rootDirectory: '/repo/a',
          parentDirectory: '/repo/a/lib',
          name: "John's notes.dart",
        );

        expect(result.ok, isTrue);
        expect(result.path, "/repo/a/lib/John's notes.dart");
        expect(fakeServer.shellCallCount, 2);
        expect(
          fakeServer.commands.last,
          contains("CW_NAME='John'\\''s notes.dart'"),
        );
      },
    );

    test('write file uses base64 content and returns target path', () async {
      final fakeServer = _FakeShellServer(
        shellPayloads: <String>[
          '{"ok":true,"code":"ok","message":"available"}',
          '{"ok":true,"code":"ok","message":"ok"}',
        ],
      );
      final service = WorkspaceFileOperationsServiceImpl(dio: fakeServer.dio);

      final result = await service.writeFile(
        serverScopeKey: 'srv',
        rootDirectory: '/repo/a',
        path: 'lib/main.dart',
        content: "void main() {\n  print('hello');\n}\n",
      );

      expect(result.ok, isTrue);
      expect(result.path, '/repo/a/lib/main.dart');
      expect(fakeServer.shellCallCount, 2);
      expect(
        fakeServer.commands.last,
        contains("CW_PARENT_INPUT='/repo/a/lib'"),
      );
      expect(fakeServer.commands.last, contains("CW_NAME='main.dart'"));
      expect(
        fakeServer.commands.last,
        contains(
          "CW_CONTENT_B64_0='${base64Encode(utf8.encode("void main() {\n  print('hello');\n}\n"))}'",
        ),
      );
      expect(fakeServer.commands.last, contains("CW_CONTENT_CHUNK_COUNT='1'"));
      final script = _decodedMutationScript(fakeServer.commands.last);
      expect(script, contains(r'cw_decode_content "$tmp"'));
      expect(script, contains('cw_content_base64 | base64 -D'));
      expect(script, contains('mktemp -d'));
      expect(script, contains('.cw-write.XXXXXX'));
      expect(script, isNot(contains(r'.cw-write-$$.tmp')));
      expect(script, contains(r'cw_copy_mode "$target" "$tmp"'));
      expect(script, contains(r'mv -- "$tmp" "$target"'));
      expect(fakeServer.createdSessionDirectories, <String?>[
        '/repo/a',
        '/repo/a',
      ]);
      expect(fakeServer.shellDirectories, <String?>['/repo/a', '/repo/a']);
      expect(fakeServer.deletedSessionDirectories, <String?>[
        '/repo/a',
        '/repo/a',
      ]);
    });

    test('write file rejects paths outside root before shell calls', () async {
      final fakeServer = _FakeShellServer(shellPayloads: const <String>[]);
      final service = WorkspaceFileOperationsServiceImpl(dio: fakeServer.dio);

      final escapedRelative = await service.writeFile(
        serverScopeKey: 'srv',
        rootDirectory: '/repo/a',
        path: '../outside.dart',
        content: 'changed',
      );
      final escapedAbsolute = await service.writeFile(
        serverScopeKey: 'srv',
        rootDirectory: '/repo/a',
        path: '/repo/ab/main.dart',
        content: 'changed',
      );

      expect(escapedRelative.ok, isFalse);
      expect(escapedRelative.code, WorkspaceFileOperationCode.outsideRoot);
      expect(escapedAbsolute.ok, isFalse);
      expect(escapedAbsolute.code, WorkspaceFileOperationCode.outsideRoot);
      expect(fakeServer.shellCallCount, 0);
    });

    test('write file blocks project root before shell calls', () async {
      final fakeServer = _FakeShellServer(shellPayloads: const <String>[]);
      final service = WorkspaceFileOperationsServiceImpl(dio: fakeServer.dio);

      final result = await service.writeFile(
        serverScopeKey: 'srv',
        rootDirectory: '/repo/a',
        path: '/repo/a',
        content: 'changed',
      );

      expect(result.ok, isFalse);
      expect(result.code, WorkspaceFileOperationCode.rootDeleteBlocked);
      expect(fakeServer.shellCallCount, 0);
    });

    test(
      'write file malformed operation invalidates capability cache',
      () async {
        final fakeServer = _FakeShellServer(
          shellPayloads: <String?>[
            '{"ok":true,"code":"ok","message":"available"}',
            null,
            '{"ok":true,"code":"ok","message":"available"}',
            '{"ok":true,"code":"ok","message":"ok"}',
          ],
        );
        final service = WorkspaceFileOperationsServiceImpl(dio: fakeServer.dio);

        final writeResult = await service.writeFile(
          serverScopeKey: 'srv',
          rootDirectory: '/repo/a',
          path: 'lib/main.dart',
          content: 'changed',
        );
        final createResult = await service.createFile(
          serverScopeKey: 'srv',
          rootDirectory: '/repo/a',
          parentDirectory: '/repo/a/lib',
          name: 'new.dart',
        );

        expect(writeResult.ok, isFalse);
        expect(writeResult.code, WorkspaceFileOperationCode.malformedResponse);
        expect(createResult.ok, isTrue);
        expect(fakeServer.shellCallCount, 4);
        expect(
          _decodedMutationScript(fakeServer.commands[2]),
          contains('pwd -P'),
        );
      },
    );

    test('delete captures rm stderr in failed result', () async {
      final fakeServer = _FakeShellServer(
        shellPayloads: <String>[
          '{"ok":true,"code":"ok","message":"available"}',
          '{"ok":false,"code":"failed","message":"rm: cannot remove markdown.md: Operation not permitted"}',
        ],
      );
      final service = WorkspaceFileOperationsServiceImpl(dio: fakeServer.dio);

      final result = await service.delete(
        serverScopeKey: 'srv',
        rootDirectory: '/repo/a',
        parentDirectory: '/repo/a/docs',
        name: 'markdown.md',
      );

      expect(result.ok, isFalse);
      expect(result.code, WorkspaceFileOperationCode.failed);
      expect(result.message, contains('Operation not permitted'));
      expect(fakeServer.shellCallCount, 2);
      final script = _decodedMutationScript(fakeServer.commands.last);
      expect(script, contains('mktemp -d'));
      expect(script, contains('.cw-delete.XXXXXX'));
      expect(script, contains(r'status="$errdir/status"'));
      expect(script, contains(r'rm -- "$CW_NAME" >/dev/null; printf'));
      expect(script, contains(r'rm -r -- "$CW_NAME" >/dev/null; printf'));
      expect(script, contains('sed -n '));
      expect(script, contains(r'cut -c 1-240 > "$err"'));
      expect(script, contains(r"tr -d '\000-\011\013-\037\177'"));
      expect(script, contains(r'cw_fail_message failed "$rm_error"'));
    });

    test('malformed probe disables shell file operations', () async {
      final fakeServer = _FakeShellServer(shellPayloads: const <String?>[null]);
      final service = WorkspaceFileOperationsServiceImpl(dio: fakeServer.dio);

      final capabilities = await service.getCapabilities(
        serverScopeKey: 'srv',
        directory: '/repo/a',
      );

      expect(capabilities.shellFileOpsSupported, isFalse);
      expect(fakeServer.shellCallCount, 4);
    });

    test('aborts a complete mutation when its server changes', () async {
      final fakeServer = _FakeShellServer(
        shellPayloads: const <String?>[
          '{"ok":true,"code":"ok"}',
          '{"ok":true,"code":"ok"}',
        ],
        switchBaseUrlAfterSession: 'http://next-server',
        replacementAuthorizationAfterSession: 'Basic server-b',
      );
      final service = WorkspaceFileOperationsServiceImpl(dio: fakeServer.dio);

      final result = await service.writeFile(
        serverScopeKey: 'srv',
        rootDirectory: '/repo/a',
        path: '/repo/a/file.txt',
        content: 'content',
      );

      expect(result.code, WorkspaceFileOperationCode.unavailable);
      expect(fakeServer.dio.options.baseUrl, 'http://next-server');
      expect(fakeServer.requestOrigins, <String>['http://localhost']);
      expect(fakeServer.requestAuthorizationHeaders, <String?>[null]);

      fakeServer.dio.options
        ..baseUrl = 'http://localhost'
        ..headers.remove('Authorization');
      final retry = await service.writeFile(
        serverScopeKey: 'srv',
        rootDirectory: '/repo/a',
        path: '/repo/a/file.txt',
        content: 'content',
      );
      expect(retry.ok, isTrue);
      expect(
        fakeServer.requestOrigins,
        List<String>.filled(7, 'http://localhost'),
      );
    });
  });
}

WorkspaceFileOperationResult _parsedShellStdout(dynamic stdout) {
  final payload = WorkspaceFileOperationsServiceImpl.extractSentinelPayload(
    <String, dynamic>{
      'parts': <dynamic>[
        <String, dynamic>{
          'state': <String, dynamic>{
            'status': 'completed',
            'output': stdout.toString(),
          },
        },
      ],
    },
  );
  expect(payload, isNotNull);
  return WorkspaceFileOperationsServiceImpl.parseSentinelPayload(payload!);
}

String _decodedMutationScript(String command) {
  final match = RegExp("printf '%s' '([^']+)'").firstMatch(command);
  expect(match, isNotNull);
  return utf8.decode(base64Decode(match!.group(1)!));
}

class _FakeShellServer {
  _FakeShellServer({
    required List<String?> shellPayloads,
    this.switchBaseUrlAfterSession,
    this.replacementAuthorizationAfterSession,
  }) : _shellPayloads = List<String?>.from(shellPayloads) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final path = options.uri.path;
          requestOrigins.add(options.uri.origin);
          requestAuthorizationHeaders.add(
            options.headers['Authorization'] as String?,
          );
          if (options.method == 'POST' && path == '/session') {
            final id = 'ses_${createdSessions.length + 1}';
            createdSessions.add(id);
            createdSessionDirectories.add(
              options.queryParameters['directory'] as String?,
            );
            final nextBaseUrl = switchBaseUrlAfterSession;
            if (nextBaseUrl != null && !_didSwitchBaseUrl) {
              _didSwitchBaseUrl = true;
              dio.options.baseUrl = nextBaseUrl;
              final replacementAuthorization =
                  replacementAuthorizationAfterSession;
              if (replacementAuthorization != null) {
                dio.options.headers['Authorization'] = replacementAuthorization;
              }
            }
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: <String, dynamic>{'id': id},
              ),
            );
            return;
          }

          if (options.method == 'POST' && path.endsWith('/shell')) {
            shellCallCount += 1;
            shellDirectories.add(
              options.queryParameters['directory'] as String?,
            );
            final data = Map<String, dynamic>.from(options.data as Map);
            commands.add(data['command'] as String? ?? '');
            final payload = _shellPayloads.isEmpty
                ? null
                : _shellPayloads.removeAt(0);
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: <String, dynamic>{
                  'parts': <dynamic>[
                    if (payload != null)
                      <String, dynamic>{'text': 'CW_FILE_OP_JSON:$payload'},
                  ],
                },
              ),
            );
            return;
          }

          if (options.method == 'DELETE' && path.startsWith('/session/')) {
            deletedSessions.add(path.substring('/session/'.length));
            deletedSessionDirectories.add(
              options.queryParameters['directory'] as String?,
            );
            handler.resolve(
              Response<dynamic>(requestOptions: options, statusCode: 200),
            );
            return;
          }

          handler.reject(
            DioException(
              requestOptions: options,
              error: 'Unexpected request: ${options.method} $path',
            ),
          );
        },
      ),
    );
  }

  final Dio dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
  final List<String?> _shellPayloads;
  final String? switchBaseUrlAfterSession;
  final String? replacementAuthorizationAfterSession;
  final List<String> requestOrigins = <String>[];
  final List<String?> requestAuthorizationHeaders = <String?>[];
  bool _didSwitchBaseUrl = false;
  final List<String> createdSessions = <String>[];
  final List<String> deletedSessions = <String>[];
  final List<String?> createdSessionDirectories = <String?>[];
  final List<String?> shellDirectories = <String?>[];
  final List<String?> deletedSessionDirectories = <String?>[];
  final List<String> commands = <String>[];
  int shellCallCount = 0;
}
