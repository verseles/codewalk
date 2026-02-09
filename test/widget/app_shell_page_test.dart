import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart' hide Provider;

import 'package:codewalk/domain/entities/provider.dart';
import 'package:codewalk/domain/usecases/create_chat_session.dart';
import 'package:codewalk/domain/usecases/delete_chat_session.dart';
import 'package:codewalk/domain/usecases/get_chat_messages.dart';
import 'package:codewalk/domain/usecases/get_chat_sessions.dart';
import 'package:codewalk/domain/usecases/get_providers.dart';
import 'package:codewalk/domain/usecases/send_chat_message.dart';
import 'package:codewalk/presentation/pages/app_shell_page.dart';
import 'package:codewalk/presentation/providers/chat_provider.dart';
import 'package:codewalk/presentation/providers/project_provider.dart';

import '../support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('uses NavigationBar on mobile and can open logs tab', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _testApp(_buildChatProvider(), const Size(430, 900)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);

    await tester.tap(find.text('Logs'));
    await tester.pumpAndSettle();

    expect(find.text('App Logs'), findsOneWidget);
  });

  testWidgets('uses NavigationRail on wide layouts', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _testApp(_buildChatProvider(), const Size(1200, 900)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}

Widget _testApp(ChatProvider provider, Size size) {
  return ChangeNotifierProvider<ChatProvider>.value(
    value: provider,
    child: MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: const AppShellPage(),
      ),
    ),
  );
}

ChatProvider _buildChatProvider() {
  final chatRepo = FakeChatRepository();
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
