import 'dart:async';
import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net_io.dart';
import 'package:harness_opencode/harness_opencode.dart';
import 'package:test/test.dart';

const harness = HarnessRef(HostId('host-a'), HarnessInstanceId('native-a'));

final class TestTransport implements EndpointHttpTransport {
  TestTransport(this.handle);
  final FutureOr<TransportResponse> Function(TransportRequest) handle;
  final requests = <TransportRequest>[];
  @override
  Uri endpoint = Uri.parse('http://127.0.0.1/proxy/');
  @override
  bool isClosed = false;
  @override
  Future<TransportResponse> send(
    TransportRequest request, {
    RequestCancellation? cancellation,
  }) async {
    requests.add(request);
    return handle(request);
  }

  @override
  void close() => isClosed = true;
}

TransportResponse response(Object? body) => TransportResponse(
  statusCode: 200,
  headers: {
    'content-type': ['application/json'],
  },
  body: Stream.value(utf8.encode(jsonEncode(body))),
  cancel: () {},
);

/// A location-scoped answer: its rows under `data`, for the location it names.
Map<String, Object?> located(String directory, [Object? data]) => {
  'location': {'directory': directory},
  'data': ?data,
};

Map<String, String> query(TransportRequest request) =>
    Uri.parse(request.path).queryParameters;

void main() {
  test(
    'ordered selectable default agent carries its model reference',
    () async {
      final transport = TestTransport(
        (request) => Uri.parse(request.path).path == 'api/config'
            ? response(<Object?>[])
            : response(
                located('/work/a', [
                  {'id': 'hidden', 'mode': 'primary', 'hidden': true},
                  {
                    'id': 'build',
                    'name': 'Build',
                    'mode': 'primary',
                    'hidden': false,
                    'model': {
                      'id': 'preferred',
                      'providerID': 'provider',
                      'variant': 'high',
                    },
                  },
                ]),
              ),
      );
      final result = await OpenCodeLocationReader(
        transport,
        harness: harness,
      ).readDefaultAgentDetails(directory: '/work/a');
      expect(result?.id, 'build');
      expect(result?.name, 'Build');
      expect(result?.modelId, 'preferred');
      expect(result?.providerId, 'provider');
      expect(result?.variant, 'high');
    },
  );

  TestTransport agents(String? configured) => TestTransport(
    (request) => Uri.parse(request.path).path == 'api/config'
        ? response([
            if (configured != null)
              {
                'type': 'document',
                'path': '/work/a/opencode.json',
                'info': {'default_agent': configured},
              },
          ])
        : response(
            located('/work/a', [
              {'id': 'review', 'mode': 'primary', 'hidden': false},
              {'id': 'build', 'mode': 'primary', 'hidden': false},
              {
                'id': 'plan',
                'mode': 'primary',
                'hidden': false,
                'model': {'id': 'm', 'providerID': 'p'},
              },
              {'id': 'helper', 'mode': 'subagent', 'hidden': false},
            ]),
          ),
  );

  test('the configured default agent wins when selectable', () async {
    final result = await OpenCodeLocationReader(
      agents('plan'),
      harness: harness,
    ).readDefaultAgentDetails(directory: '/work/a');
    expect(result?.id, 'plan');
    expect(result?.modelId, 'm');
  });

  test('an unselectable configured agent falls back to build', () async {
    for (final configured in ['helper', 'missing', null]) {
      final result = await OpenCodeLocationReader(
        agents(configured),
        harness: harness,
      ).readDefaultAgentDetails(directory: '/work/a');
      expect(result?.id, 'build', reason: '$configured');
    }
  });

  test(
    'the default agent is the highest-priority document that sets it',
    () async {
      final transport = TestTransport((request) {
        expect(Uri.parse(request.path).path, 'api/config');
        return response([
          {
            'type': 'document',
            'path': '/etc/opencode.json',
            'info': {'default_agent': 'plan'},
          },
          {
            'type': 'document',
            'path': '/work/a/opencode.json',
            'info': {'shell': 'zsh'},
          },
          {
            'type': 'document',
            'path': '/work/a/.opencode.json',
            'info': {'default_agent': 'build'},
          },
        ]);
      });
      final reader = OpenCodeLocationReader(transport, harness: harness);
      expect(await reader.readDefaultAgent(directory: '/work/a'), 'build');
      expect(query(transport.requests.single), {
        'location[directory]': '/work/a',
      });
    },
  );

  test('no document sets a default agent, so there is none', () async {
    final transport = TestTransport((_) => response(<Object?>[]));
    final reader = OpenCodeLocationReader(transport, harness: harness);
    expect(await reader.readDefaultAgent(directory: '/work/a'), isNull);
  });

  test('the default model is named, or by its id without a name', () async {
    final named = TestTransport((request) {
      expect(Uri.parse(request.path).path, 'api/model/default');
      return response(
        located('/work/a', {
          'id': 'm1',
          'modelID': 'model_1',
          'providerID': 'p',
          'name': 'Model One',
        }),
      );
    });
    expect(
      await OpenCodeLocationReader(
        named,
        harness: harness,
      ).readDefaultModel(directory: '/work/a'),
      'Model One',
    );

    final unnamed = TestTransport(
      (_) => response(
        located('/work/a', {
          'id': 'm2',
          'modelID': 'model_2',
          'providerID': 'p',
        }),
      ),
    );
    expect(
      await OpenCodeLocationReader(
        unnamed,
        harness: harness,
      ).readDefaultModel(directory: '/work/a'),
      'model_2',
    );
  });

  test('an absent default model is null', () async {
    final transport = TestTransport((_) => response(located('/work/a')));
    expect(
      await OpenCodeLocationReader(
        transport,
        harness: harness,
      ).readDefaultModel(directory: '/work/a'),
      isNull,
    );
  });

  test('an answer for another location is refused', () async {
    final transport = TestTransport(
      (_) => response(located('/work/b', {'modelID': 'model_2'})),
    );
    await expectLater(
      OpenCodeLocationReader(
        transport,
        harness: harness,
      ).readDefaultModel(directory: '/work/a'),
      throwsA(anything),
    );
  });

  test(
    'an agent is named by its registered name, or its id without one',
    () async {
      final transport = TestTransport((request) {
        expect(Uri.parse(request.path).path, 'api/agent');
        return response(
          located('/work/a', [
            {
              'id': 'build',
              'name': 'Build',
              'mode': 'primary',
              'hidden': false,
            },
            {'id': 'plan', 'mode': 'primary', 'hidden': false},
          ]),
        );
      });
      final reader = OpenCodeLocationReader(transport, harness: harness);
      expect(
        await reader.readAgentName(directory: '/work/a', id: 'build'),
        'Build',
      );
      expect(
        await reader.readAgentName(directory: '/work/a', id: 'plan'),
        'plan',
      );
      expect(
        await reader.readAgentName(directory: '/work/a', id: 'missing'),
        isNull,
      );
    },
  );

  test('providers are named by their name, or their id without one', () async {
    final transport = TestTransport((request) {
      expect(Uri.parse(request.path).path, 'api/provider');
      expect(query(request), {'location[directory]': '/work/a'});
      return response(
        located('/work/a', [
          {'id': 'anthropic', 'name': 'Anthropic'},
          {'id': 'local', 'name': '  '},
        ]),
      );
    });
    final reader = OpenCodeLocationReader(transport, harness: harness);
    expect(await reader.readProviderNames(directory: '/work/a'), {
      'anthropic': 'Anthropic',
      'local': 'local',
    });
  });

  test('the providers of another location are refused', () async {
    final transport = TestTransport(
      (_) => response(
        located('/work/b', [
          {'id': 'anthropic', 'name': 'Anthropic'},
        ]),
      ),
    );
    await expectLater(
      OpenCodeLocationReader(
        transport,
        harness: harness,
      ).readProviderNames(directory: '/work/a'),
      throwsA(isA<OpenCodeSessionReadException>()),
    );
  });
}
