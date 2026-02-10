import 'package:flutter_test/flutter_test.dart';

import 'package:codewalk/data/models/provider_model.dart';

void main() {
  group('ProvidersResponseModel', () {
    test('parses new schema with all/default/connected', () {
      final model = ProvidersResponseModel.fromJson(<String, dynamic>{
        'all': <dynamic>[
          <String, dynamic>{
            'id': 'anthropic',
            'name': 'Anthropic',
            'env': <String>['ANTHROPIC_API_KEY'],
            'models': <String, dynamic>{
              'claude-3-5-sonnet': <String, dynamic>{
                'id': 'claude-3-5-sonnet',
                'name': 'Claude 3.5 Sonnet',
                'release_date': '2025-01-01',
                'capabilities': <String, dynamic>{
                  'attachment': true,
                  'reasoning': true,
                  'temperature': false,
                  'toolcall': true,
                  'input': <String, dynamic>{
                    'text': true,
                    'image': true,
                    'pdf': false,
                  },
                  'output': <String, dynamic>{'text': true},
                },
                'cost': <String, dynamic>{
                  'input': '0.003',
                  'output': 0.015,
                  'cache': <String, dynamic>{'read': 0.0003, 'write': 0.003},
                },
                'limit': <String, dynamic>{'context': 200000, 'output': 8192},
                'variants': <String, dynamic>{
                  'low': <String, dynamic>{
                    'name': 'Low',
                    'description': 'Fast reasoning',
                    'effort': 1,
                  },
                  'high': <String, dynamic>{'label': 'High', 'effort': 3},
                },
              },
            },
          },
        ],
        'default': <String, String>{'anthropic': 'claude-3-5-sonnet'},
        'connected': <String>['anthropic'],
      });

      expect(model.providers, hasLength(1));
      expect(model.defaultModels['anthropic'], 'claude-3-5-sonnet');
      expect(model.connected, <String>['anthropic']);

      final provider = model.toDomain().providers.single;
      final domainModel = provider.models['claude-3-5-sonnet'];

      expect(provider.id, 'anthropic');
      expect(domainModel?.toolCall, isTrue);
      expect(domainModel?.cost.cacheRead, closeTo(0.0003, 0.0000001));
      expect(domainModel?.limit.context, 200000);
      expect(domainModel?.variants.keys, containsAll(<String>['low', 'high']));
      expect(domainModel?.variants['low']?.name, 'Low');
      expect(domainModel?.variants['high']?.name, 'High');
      expect(
        domainModel?.modalities?['input'],
        containsAll(<String>['text', 'image']),
      );
    });

    test('parses legacy schema and skips invalid models', () {
      final model = ProvidersResponseModel.fromJson(<String, dynamic>{
        'providers': <dynamic>[
          <String, dynamic>{
            'id': 'openai',
            'models': <String, dynamic>{
              'valid-model': <String, dynamic>{
                'id': 'valid-model',
                'cost': <String, dynamic>{'input': 1, 'output': 2},
                'limit': <String, dynamic>{'context': 1000, 'output': 100},
                'tool_call': true,
              },
              'invalid-model': 'broken',
            },
          },
        ],
        'default': <String, String>{'openai': 'valid-model'},
      });

      final provider = model.providers.single;
      expect(provider.name, 'openai');
      expect(provider.models.keys, <String>['valid-model']);
      expect(provider.models['valid-model']?.toolCall, isTrue);
    });
  });
}
