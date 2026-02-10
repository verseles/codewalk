import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:codewalk/data/models/chat_session_model.dart';
import 'package:codewalk/domain/entities/chat_session.dart';

void main() {
  group('ChatSessionModel', () {
    test('parses summary map into compact display text', () {
      final model = ChatSessionModel.fromJson(<String, dynamic>{
        'id': 'ses_1',
        'workspaceId': 'ws_1',
        'time': <String, dynamic>{'created': 1000, 'updated': 1000},
        'summary': <String, dynamic>{'additions': 12, 'deletions': 3},
      });

      final domain = model.toDomain();
      expect(domain.summary, 'additions: 12, deletions: 3');
      expect(domain.shared, isFalse);
    });

    test('roundtrips domain object through model json', () {
      final original = ChatSession(
        id: 'ses_2',
        workspaceId: 'ws_2',
        time: DateTime.fromMillisecondsSinceEpoch(5000),
        title: 'Session title',
        shared: true,
        summary: 'summary',
        path: const SessionPath(root: '/repo', workspace: '/repo/ws'),
      );

      final model = ChatSessionModel.fromDomain(original);
      final encoded = jsonEncode(model.toJson());
      final decoded = ChatSessionModel.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );

      final roundtrip = decoded.toDomain();
      expect(roundtrip.id, original.id);
      expect(roundtrip.workspaceId, original.workspaceId);
      expect(roundtrip.title, original.title);
      expect(roundtrip.path, original.path);
      expect(roundtrip.shared, isFalse);
    });

    test('uses non-empty title fallback fields and trims value', () {
      final withNameFallback = ChatSessionModel.fromJson(<String, dynamic>{
        'id': 'ses_name',
        'workspaceId': 'ws_1',
        'time': <String, dynamic>{'created': 1000, 'updated': 1000},
        'title': '   ',
        'name': '  Legacy Name  ',
      });

      final withSessionTitleFallback = ChatSessionModel.fromJson(
        <String, dynamic>{
          'id': 'ses_session_title',
          'workspaceId': 'ws_1',
          'time': <String, dynamic>{'created': 1000, 'updated': 1000},
          'title': '',
          'name': '   ',
          'sessionTitle': '  Session Title Field ',
        },
      );

      expect(withNameFallback.toDomain().title, 'Legacy Name');
      expect(withSessionTitleFallback.toDomain().title, 'Session Title Field');
    });
  });

  group('ChatInputModel', () {
    test('supports nested model schema and serializes back to new format', () {
      final model = ChatInputModel.fromJson(<String, dynamic>{
        'messageID': 'msg_1',
        'agent': 'code',
        'variant': 'high',
        'model': <String, dynamic>{
          'providerID': 'anthropic',
          'modelID': 'claude-3-5-sonnet',
        },
        'parts': <dynamic>[
          <String, dynamic>{'type': 'text', 'text': 'hello'},
        ],
      });

      expect(model.providerId, 'anthropic');
      expect(model.modelId, 'claude-3-5-sonnet');
      expect(model.variant, 'high');
      expect(model.mode, 'code');

      final json = model.toJson();
      expect(json['noReply'], isFalse);
      expect(
        (json['model'] as Map<String, dynamic>)['providerID'],
        'anthropic',
      );
      expect(
        (json['model'] as Map<String, dynamic>)['modelID'],
        'claude-3-5-sonnet',
      );
      expect(json['variant'], 'high');
      expect(json['agent'], 'code');
    });

    test('serializes file parts with mime and url fields', () {
      final input = ChatInput(
        providerId: 'google',
        modelId: 'gemini-2.5-flash',
        parts: const <ChatInputPart>[
          TextInputPart(text: 'look at this'),
          FileInputPart(
            mime: 'application/pdf',
            url: 'data:application/pdf;base64,Zm9v',
            filename: 'sample.pdf',
          ),
        ],
      );

      final model = ChatInputModel.fromDomain(input);
      final json = model.toJson();
      final parts = json['parts'] as List<dynamic>;

      expect(parts, hasLength(2));
      expect(parts[1]['type'], 'file');
      expect(parts[1]['mime'], 'application/pdf');
      expect(parts[1]['url'], 'data:application/pdf;base64,Zm9v');
      expect(parts[1]['filename'], 'sample.pdf');
    });
  });
}
