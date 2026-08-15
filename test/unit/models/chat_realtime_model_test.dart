import 'package:codewalk/data/models/chat_realtime_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatEventModel', () {
    test('preserves authoritative global envelope metadata', () {
      final payloadProperties = <String, dynamic>{
        'sessionID': 'ses_1',
        'directory': '/payload/directory',
        'project': 'payload-project',
        'workspace': 'payload-workspace',
      };

      final model = ChatEventModel.fromJson(<String, dynamic>{
        'directory': '/outer/directory',
        'project': 'outer-project',
        'workspace': 'outer-workspace',
        'payload': <String, dynamic>{
          'id': 'evt_1',
          'type': 'session.updated',
          'properties': payloadProperties,
        },
      });

      expect(model.type, 'session.updated');
      expect(model.properties['sessionID'], 'ses_1');
      expect(model.properties['directory'], '/outer/directory');
      expect(model.properties['project'], 'outer-project');
      expect(model.properties['workspace'], 'outer-workspace');
      expect(payloadProperties['directory'], '/payload/directory');
      expect(payloadProperties['project'], 'payload-project');
      expect(payloadProperties['workspace'], 'payload-workspace');
    });

    test('does not synthesize missing global context metadata', () {
      final model = ChatEventModel.fromJson(<String, dynamic>{
        'payload': <String, dynamic>{
          'id': 'evt_connected',
          'type': 'server.connected',
          'properties': <String, dynamic>{},
        },
      });

      expect(model.type, 'server.connected');
      expect(model.properties, isEmpty);
      expect(model.properties.containsKey('directory'), isFalse);
      expect(model.properties.containsKey('project'), isFalse);
      expect(model.properties.containsKey('workspace'), isFalse);
    });

    test('keeps flat event parsing and copies properties', () {
      final properties = <String, dynamic>{'sessionID': 'ses_flat'};
      final model = ChatEventModel.fromJson(<String, dynamic>{
        'type': 'session.status',
        'properties': properties,
      });

      properties['sessionID'] = 'mutated';

      expect(model.type, 'session.status');
      expect(model.properties, <String, dynamic>{'sessionID': 'ses_flat'});
    });
  });

  group('ChatQuestionRequestModel', () {
    test('parses canonical sessionID shape', () {
      final model = ChatQuestionRequestModel.fromJson(<String, dynamic>{
        'id': 'q_1',
        'sessionID': 'ses_1',
        'questions': <Map<String, dynamic>>[],
      });

      expect(model.id, 'q_1');
      expect(model.sessionId, 'ses_1');
    });

    test('tolerates camelCase sessionId', () {
      final model = ChatQuestionRequestModel.fromJson(<String, dynamic>{
        'id': 'q_1',
        'sessionId': 'ses_1',
        'questions': <Map<String, dynamic>>[],
      });

      expect(model.id, 'q_1');
      expect(model.sessionId, 'ses_1');
    });

    test('tolerates request envelope and requestID fallback', () {
      final model = ChatQuestionRequestModel.fromJson(<String, dynamic>{
        'request': <String, dynamic>{
          'requestID': 'q_2',
          'sessionId': 'ses_2',
          'questions': <Map<String, dynamic>>[],
        },
      });

      expect(model.id, 'q_2');
      expect(model.sessionId, 'ses_2');
    });

    test('does not descend into info when top level has request fields', () {
      final model = ChatQuestionRequestModel.fromJson(<String, dynamic>{
        'id': 'q_3',
        'sessionID': 'ses_3',
        'questions': <Map<String, dynamic>>[],
        'info': <String, dynamic>{'id': 'q_wrong', 'sessionID': 'ses_wrong'},
      });

      expect(model.id, 'q_3');
      expect(model.sessionId, 'ses_3');
    });
  });
}
