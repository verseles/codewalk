import 'package:codewalk/data/datasources/chat_remote_datasource.dart';
import 'package:codewalk/data/models/chat_session_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<RequestOptions> sendCommand(String text) async {
    late RequestOptions request;
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          request = options;
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: <String, dynamic>{
                'info': <String, dynamic>{
                  'id': 'msg_command_1',
                  'sessionID': 'ses_1',
                  'role': 'assistant',
                  'time': <String, dynamic>{
                    'created': 1739079900000,
                    'completed': 1739079900100,
                  },
                },
                'parts': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 'prt_command_1',
                    'messageID': 'msg_command_1',
                    'sessionID': 'ses_1',
                    'type': 'text',
                    'text': 'done',
                  },
                ],
              },
            ),
          );
        },
      ),
    );

    final remote = ChatRemoteDataSourceImpl(dio: dio);
    final messages = await remote
        .sendMessage(
          'default',
          'ses_1',
          ChatInputModel(
            messageId: 'msg_user_command',
            providerId: 'mock-provider',
            modelId: 'mock-model',
            mode: 'command',
            parts: <ChatInputPartModel>[
              ChatInputPartModel(type: 'text', text: text),
            ],
          ),
          directory: '/workspace/project',
        )
        .toList();

    expect(messages, hasLength(1));
    return request;
  }

  group('OpenCode slash-command request contract', () {
    test('sends required empty arguments and string model', () async {
      final request = await sendCommand('/dcp-compress');
      final payload = Map<String, dynamic>.from(request.data as Map);

      expect(request.path, '/session/ses_1/command');
      expect(request.queryParameters['directory'], '/workspace/project');
      expect(payload['command'], 'dcp-compress');
      expect(payload['arguments'], '');
      expect(payload['model'], 'mock-provider/mock-model');
      expect(payload['model'], isA<String>());
    });

    test('preserves non-empty arguments with the official model shape', () async {
      final request = await sendCommand('/dcp-compress general');
      final payload = Map<String, dynamic>.from(request.data as Map);

      expect(payload['command'], 'dcp-compress');
      expect(payload['arguments'], 'general');
      expect(payload['model'], 'mock-provider/mock-model');
      expect(payload['model'], isA<String>());
    });
  });
}
