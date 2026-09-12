import 'dart:convert';

import 'package:codewalk/domain/entities/chat_message.dart';
import 'package:codewalk/domain/entities/chat_session.dart';
import 'package:codewalk/presentation/services/session_export_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const exporter = SessionExportService();
  final created = DateTime.utc(2026, 5, 25, 12, 0);
  final completed = DateTime.utc(2026, 5, 25, 12, 1);
  final session = ChatSession(
    id: 'ses_123',
    workspaceId: 'workspace-a',
    time: created,
    title: 'Export Test',
    directory: '/repo',
    summary: 'A short session',
    path: const SessionPath(root: '/repo', workspace: '/repo'),
  );

  test('builds readable Markdown transcript with role and part summaries', () {
    final markdown = exporter.markdown(session, [
      UserMessage(
        id: 'local_user_1',
        sessionId: session.id,
        time: created,
        parts: const [
          TextPart(
            id: 'prt_user',
            messageId: 'local_user_1',
            sessionId: 'ses_123',
            text: 'Please inspect `lib/main.dart`.',
          ),
        ],
      ),
      AssistantMessage(
        id: 'msg_2',
        sessionId: session.id,
        time: completed,
        completedTime: completed,
        providerId: 'opencode',
        modelId: 'gpt-test',
        cost: 0.0025,
        tokens: const MessageTokens(input: 10, output: 20, reasoning: 5),
        parts: [
          const ReasoningPart(
            id: 'prt_reasoning',
            messageId: 'msg_2',
            sessionId: 'ses_123',
            text: 'Need to read the file first.',
          ),
          ToolPart(
            id: 'prt_tool',
            messageId: 'msg_2',
            sessionId: 'ses_123',
            callId: 'call_1',
            tool: 'read',
            state: ToolStateCompleted(
              input: const {'filePath': 'lib/main.dart'},
              output: 'void main() {}',
              time: ToolTime(start: created, end: completed),
              title: 'Read main',
            ),
          ),
          const PatchPart(
            id: 'prt_patch',
            messageId: 'msg_2',
            sessionId: 'ses_123',
            files: ['lib/main.dart'],
            hash: 'abc123',
          ),
        ],
      ),
    ]);

    expect(markdown, contains('# Export Test'));
    expect(markdown, contains('## 1. User - 2026-05-25T12:00:00.000Z'));
    expect(markdown, contains('Please inspect `lib/main.dart`.'));
    expect(markdown, contains('## 2. Assistant - 2026-05-25T12:01:00.000Z'));
    expect(markdown, contains('_provider `opencode` · model `gpt-test`'));
    expect(markdown, contains('> Reasoning'));
    expect(markdown, contains('### Tool: `read`'));
    expect(markdown, contains('- Patch: `abc123`'));
  });

  test('builds JSON transcript and omits local optimistic IDs', () {
    final jsonText = exporter.json(session, [
      UserMessage(
        id: 'local_user_123_1',
        sessionId: session.id,
        time: created,
        parts: const [
          TextPart(
            id: 'prt_local',
            messageId: 'local_user_123_1',
            sessionId: 'ses_123',
            text: 'Hello',
          ),
        ],
      ),
      AssistantMessage(
        id: 'msg_2',
        sessionId: 'ses_123',
        time: created,
        error: const MessageError(
          name: 'ProviderAuthError',
          message: 'Auth failed',
          statusCode: 401,
        ),
      ),
    ]);
    final decoded = jsonDecode(jsonText) as Map<String, dynamic>;
    final messages = decoded['messages'] as List<dynamic>;
    final localMessage = messages.first as Map<String, dynamic>;
    final localPart =
        (localMessage['parts'] as List<dynamic>).first as Map<String, dynamic>;
    final assistant = messages.last as Map<String, dynamic>;

    expect(decoded['schema'], 'codewalk.session_export.v1');
    expect(localMessage.containsKey('id'), isFalse);
    expect(localPart.containsKey('messageId'), isFalse);
    expect(assistant['id'], 'msg_2');
    expect((assistant['error'] as Map<String, dynamic>)['statusCode'], 401);
  });

  test('builds safe file names from session title', () {
    expect(exporter.fileName(session, 'md'), 'export-test_ses_123.md');
  });

  test('preserves non-latin letters in export file names', () {
    final named = ChatSession(
      id: session.id,
      workspaceId: session.workspaceId,
      time: session.time,
      title: '分析测试',
      directory: session.directory,
      summary: session.summary,
      path: session.path,
    );
    expect(exporter.fileName(named, 'md'), '分析测试_ses_123.md');
  });

  test('preserves indic combining marks in export file names', () {
    final named = ChatSession(
      id: session.id,
      workspaceId: session.workspaceId,
      time: session.time,
      title: 'विश्लेषण',
      directory: session.directory,
      summary: session.summary,
      path: session.path,
    );
    expect(exporter.fileName(named, 'md'), 'विश्लेषण_ses_123.md');
  });
}
