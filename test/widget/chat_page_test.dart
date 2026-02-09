import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart' hide Provider;

import 'package:codewalk/core/errors/failures.dart';
import 'package:codewalk/domain/entities/chat_message.dart';
import 'package:codewalk/domain/entities/chat_session.dart';
import 'package:codewalk/domain/entities/provider.dart';
import 'package:codewalk/domain/usecases/create_chat_session.dart';
import 'package:codewalk/domain/usecases/delete_chat_session.dart';
import 'package:codewalk/domain/usecases/get_chat_messages.dart';
import 'package:codewalk/domain/usecases/get_chat_sessions.dart';
import 'package:codewalk/domain/usecases/get_providers.dart';
import 'package:codewalk/domain/usecases/send_chat_message.dart';
import 'package:codewalk/presentation/pages/chat_page.dart';
import 'package:codewalk/presentation/providers/chat_provider.dart';
import 'package:codewalk/presentation/providers/project_provider.dart';

import '../support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChatPage responsive shell', () {
    testWidgets('shows drawer on mobile width', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(700, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final provider = _buildChatProvider();

      await tester.pumpWidget(_testApp(provider));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.menu), findsOneWidget);
      expect(find.text('Desktop Shortcuts'), findsNothing);
    });

    testWidgets('shows utility pane on large desktop width', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1300, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final provider = _buildChatProvider();

      await tester.pumpWidget(_testApp(provider));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.menu), findsNothing);
      expect(find.text('Keyboard shortcuts'), findsOneWidget);
      expect(find.text('Conversations'), findsOneWidget);
    });
  });

  testWidgets('sends message from chat input and renders assistant response', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = FakeChatRepository(
      sessions: <ChatSession>[
        ChatSession(
          id: 'ses_1',
          workspaceId: 'default',
          time: DateTime.fromMillisecondsSinceEpoch(1000),
          title: 'Session 1',
        ),
      ],
    );

    repository.sendMessageHandler = (_, sessionId, __, ___) {
      final reply = AssistantMessage(
        id: 'msg_assistant_widget',
        sessionId: sessionId,
        time: DateTime.fromMillisecondsSinceEpoch(2000),
        completedTime: DateTime.fromMillisecondsSinceEpoch(2200),
        parts: const <MessagePart>[
          TextPart(
            id: 'prt_widget_reply',
            messageId: 'msg_assistant_widget',
            sessionId: 'ses_1',
            text: 'ok from widget',
          ),
        ],
      );
      return Stream<Either<Failure, ChatMessage>>.value(Right(reply));
    };

    final provider = _buildChatProvider(chatRepository: repository);

    await tester.pumpWidget(_testApp(provider));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Session 1'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'hello from widget');
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(repository.lastSendInput, isNotNull);
    expect(find.text('hello from widget'), findsOneWidget);
    expect(find.text('ok from widget'), findsOneWidget);
  });
}

Widget _testApp(ChatProvider provider) {
  return ChangeNotifierProvider<ChatProvider>.value(
    value: provider,
    child: const MaterialApp(home: ChatPage()),
  );
}

ChatProvider _buildChatProvider({FakeChatRepository? chatRepository}) {
  final chatRepo = chatRepository ?? FakeChatRepository();
  final appRepo = FakeAppRepository()
    ..providersResult = Right(
      ProvidersResponse(
        providers: <Provider>[
          Provider(
            id: 'provider_1',
            name: 'Provider 1',
            env: const <String>[],
            models: <String, Model>{'model_1': _model('model_1')},
          ),
        ],
        defaultModels: const <String, String>{'provider_1': 'model_1'},
        connected: const <String>['provider_1'],
      ),
    );

  return ChatProvider(
    sendChatMessage: SendChatMessage(chatRepo),
    getChatSessions: GetChatSessions(chatRepo),
    createChatSession: CreateChatSession(chatRepo),
    getChatMessages: GetChatMessages(chatRepo),
    getProviders: GetProviders(appRepo),
    deleteChatSession: DeleteChatSession(chatRepo),
    projectProvider: ProjectProvider(
      projectRepository: FakeProjectRepository(),
    ),
    localDataSource: InMemoryAppLocalDataSource(),
  );
}

Model _model(String id) {
  return Model(
    id: id,
    name: id,
    releaseDate: '2025-01-01',
    attachment: false,
    reasoning: false,
    temperature: true,
    toolCall: false,
    cost: const ModelCost(input: 0.001, output: 0.002),
    limit: const ModelLimit(context: 1000, output: 100),
    options: const <String, dynamic>{},
  );
}
