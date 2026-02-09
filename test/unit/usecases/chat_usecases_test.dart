import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:codewalk/core/errors/failures.dart';
import 'package:codewalk/domain/entities/chat_message.dart';
import 'package:codewalk/domain/entities/chat_session.dart';
import 'package:codewalk/domain/usecases/create_chat_session.dart';
import 'package:codewalk/domain/usecases/delete_chat_session.dart';
import 'package:codewalk/domain/usecases/get_chat_sessions.dart';
import 'package:codewalk/domain/usecases/send_chat_message.dart';

import '../../support/fakes.dart';

void main() {
  group('chat use cases', () {
    late FakeChatRepository repository;

    setUp(() {
      repository = FakeChatRepository(
        sessions: <ChatSession>[
          ChatSession(
            id: 'ses_1',
            workspaceId: 'default',
            time: DateTime.fromMillisecondsSinceEpoch(1000),
            title: 'Session 1',
          ),
        ],
      );
    });

    test('GetChatSessions forwards optional directory', () async {
      final useCase = GetChatSessions(repository);

      final result = await useCase(
        const GetChatSessionsParams(directory: '/tmp/project'),
      );

      expect(repository.lastGetSessionsDirectory, '/tmp/project');
      expect(result.isRight(), isTrue);
      expect(result.getOrElse(() => const <ChatSession>[]), hasLength(1));
    });

    test(
      'CreateChatSession creates a new session through repository',
      () async {
        final useCase = CreateChatSession(repository);

        final result = await useCase(
          const CreateChatSessionParams(
            projectId: 'default',
            input: SessionCreateInput(title: 'New session'),
          ),
        );

        expect(result.isRight(), isTrue);
        expect(repository.sessions, hasLength(2));
        expect(repository.sessions.first.title, 'New session');
      },
    );

    test(
      'SendChatMessage forwards parameters and streams assistant message',
      () async {
        repository.sendMessageHandler = (_, sessionId, input, __) {
          final assistant = AssistantMessage(
            id: 'msg_assistant_1',
            sessionId: sessionId,
            time: DateTime.fromMillisecondsSinceEpoch(2000),
            completedTime: DateTime.fromMillisecondsSinceEpoch(2100),
            parts: const <MessagePart>[
              TextPart(
                id: 'prt_1',
                messageId: 'msg_assistant_1',
                sessionId: 'ses_1',
                text: 'streamed answer',
              ),
            ],
          );
          return Stream<Either<Failure, ChatMessage>>.value(Right(assistant));
        };

        final useCase = SendChatMessage(repository);
        final input = ChatInput(
          messageId: 'msg_user_1',
          providerId: 'anthropic',
          modelId: 'claude',
          parts: const <ChatInputPart>[TextInputPart(text: 'hello')],
        );

        final values = await useCase(
          SendChatMessageParams(
            projectId: 'default',
            sessionId: 'ses_1',
            input: input,
          ),
        ).toList();

        expect(repository.lastSendProjectId, 'default');
        expect(repository.lastSendSessionId, 'ses_1');
        expect(repository.lastSendInput, input);
        expect(values, hasLength(1));
        final streamed =
            values.single.getOrElse(() => throw StateError('expected right'))
                as AssistantMessage;
        expect((streamed.parts.single as TextPart).text, 'streamed answer');
      },
    );

    test('DeleteChatSession removes session', () async {
      final useCase = DeleteChatSession(repository);

      final result = await useCase(
        const DeleteChatSessionParams(projectId: 'default', sessionId: 'ses_1'),
      );

      expect(result.isRight(), isTrue);
      expect(repository.sessions, isEmpty);
    });
  });
}
