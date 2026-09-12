import 'dart:convert';
import 'dart:io';

import 'package:codewalk/data/datasources/quota_remote_datasource.dart';
import 'package:codewalk/presentation/services/chat_title_generator.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

String _decodeShellScript(String command) {
  final match = RegExp(
    r"Buffer\.from\('([^']+)'\s*,\s*'base64'\)",
  ).firstMatch(command);
  expect(match, isNotNull);
  final encoded = match!.group(1)!;
  return utf8.decode(base64Decode(encoded));
}

void main() {
  tearDown(ChatTitleGenerator.ephemeralSessionIds.clear);

  test('uses OpenChamber REST endpoints when available', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/api/quota/providers') {
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: <String, dynamic>{
                  'providers': <String>['claude'],
                },
              ),
            );
            return;
          }
          if (options.path == '/api/quota/claude') {
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: <String, dynamic>{
                  'providerId': 'claude',
                  'providerName': 'Claude',
                  'ok': true,
                  'configured': true,
                  'usage': <String, dynamic>{
                    'windows': <String, dynamic>{
                      '5h': <String, dynamic>{'usedPercent': 50},
                    },
                  },
                  'fetchedAt': DateTime.now().millisecondsSinceEpoch,
                },
              ),
            );
            return;
          }
          handler.reject(
            DioException(
              requestOptions: options,
              error: 'Unexpected ${options.path}',
            ),
          );
        },
      ),
    );

    final dataSource = QuotaRemoteDataSourceImpl(dio: dio);
    final results = await dataSource.fetchQuotaResults();

    expect(results, hasLength(1));
    expect(results.first.providerId, 'claude');
  });

  test('falls back to shell discovery when REST endpoints are unavailable', () async {
    final dio = Dio();
    String? shellCommand;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/api/quota/providers') {
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response<dynamic>(
                  requestOptions: options,
                  statusCode: 404,
                ),
              ),
            );
            return;
          }
          if (options.path == '/session' && options.method == 'POST') {
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: <String, dynamic>{'id': 'ses_quota_probe'},
              ),
            );
            return;
          }
          if (options.path == '/session/ses_quota_probe/shell') {
            shellCommand =
                (options.data as Map<String, dynamic>)['command'] as String?;
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: <String, dynamic>{
                  'parts': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'type': 'text',
                      'text':
                          'CW_QUOTA_JSON:{"results":[{"providerId":"openrouter","providerName":"OpenRouter","ok":true,"configured":true,"usage":{"windows":{"credits":{"usedPercent":63,"valueLabel":"\$12.00 remaining"}}},"fetchedAt":1}]}',
                    },
                  ],
                },
              ),
            );
            return;
          }
          if (options.path == '/session/ses_quota_probe' &&
              options.method == 'DELETE') {
            handler.resolve(
              Response<dynamic>(requestOptions: options, statusCode: 200),
            );
            return;
          }
          handler.reject(
            DioException(
              requestOptions: options,
              error: 'Unexpected ${options.path}',
            ),
          );
        },
      ),
    );

    final dataSource = QuotaRemoteDataSourceImpl(dio: dio);
    final results = await dataSource.fetchQuotaResults();

    expect(results, hasLength(1));
    expect(results.first.providerId, 'openrouter');
    expect(
      results.first.usage?.windows['credits']?.valueLabel,
      '\$12.00 remaining',
    );

    final script = _decodeShellScript(shellCommand!);
    expect(script, contains('const AG = ['));
    expect(script, contains("p.join(CFG, 'antigravity-accounts.json')"));
    expect(script, contains('function rGem(a)'));
    expect(script, contains('function rAnti()'));
    expect(script, contains('v1internal:retrieveUserQuota'));
    expect(script, contains('Client-Metadata'));
    expect(script, contains('https://oauth2.googleapis.com/token'));
    expect(script, contains('function rGAccess(src)'));
    expect(script, contains('function fOCG(a)'));
    expect(script, contains("getE(a, ['opencode-go'])"));
    expect(script, contains('https://opencode.ai/zen/go/v1/usage'));
    expect(script, contains("Authorization: 'Bearer ' + k"));
    final openCodeGoProbe = script.substring(
      script.indexOf('async function fOCG(a)'),
      script.indexOf('async function fNanoGpt(a)'),
    );
    expect(openCodeGoProbe, isNot(contains('Cookie:')));
    expect(script, isNot(contains('OPENCODE_GO_WORKSPACE_ID')));
    expect(script, isNot(contains('OPENCODE_GO_AUTH_COOKIE')));
    expect(script, contains("['rolling', 'rolling']"));
    expect(script, contains("errCode: 'authentication'"));
    expect(script, contains("errCode: 'invalid_response'"));
    expect(script, contains('AbortSignal.timeout(15000)'));
    // The unsupported-keys filter is a minified string literal in the JS
    // shell-fallback; assert on a robust anchor (the trailing "].includes(k)"
    // pattern) plus the order-stable quota auth key set so the assertion
    // survives adding new provider keys to the Dart register.
    expect(script, contains('].includes(k)'));
    expect(
      script,
      contains('"ollama-cloud","ollamacloud"'),
      reason:
          'Quota shell-fallback must keep the ollama/ollamacloud aliases '
          'in its unsupported-filter list so the ollama-cloud register is '
          'honored.',
    );
    expect(script, contains("const GDP = 'rising-fact-p41fc';"));
    expect(
      script,
      contains(
        "const GGID = '681255809395-oo8ft2oprdrnp9e3aqf6av3hmdib135j.apps.googleusercontent.com';",
      ),
    );
    expect(
      script,
      contains(
        "const AGID = '1071006060591-tmhssin2h21lcre235vtolojh4g403ep.apps.googleusercontent.com';",
      ),
    );
    expect(script, contains('const GGSC = '));
    expect(script, contains('const AGSC = '));
    expect(script, contains('async function fXai(a)'));
    expect(script, contains('function parseXaiUsage('));
    expect(
      script,
      contains(
        'https://grok.com/grok_api_v2.GrokBuildBilling/GetGrokCreditsConfig',
      ),
    );
    expect(script, contains('https://auth.x.ai/oauth2/token'));
    expect(script, contains('const xa = await fXai(a); if (xa) R.push(xa);'));
    expect(script, contains('async function fDeepseek(a)'));
    expect(script, contains('https://api.deepseek.com/user/balance'));
    expect(
      script,
      contains('const ds = await fDeepseek(a); if (ds) R.push(ds);'),
    );
    expect(script, contains('async function fClinePass(a)'));
    expect(
      script,
      contains('https://api.cline.bot/api/v1/users/me/plan/usage-limits'),
    );
    expect(
      script,
      contains('const cp = await fClinePass(a); if (cp) R.push(cp);'),
    );
  });

  test('generated quota shell script is valid JavaScript', () async {
    final dio = Dio();
    String? shellCommand;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/api/quota/providers') {
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response<dynamic>(
                  requestOptions: options,
                  statusCode: 404,
                ),
              ),
            );
            return;
          }
          if (options.path == '/session' && options.method == 'POST') {
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: <String, dynamic>{'id': 'ses_syntax_probe'},
              ),
            );
            return;
          }
          if (options.path == '/session/ses_syntax_probe/shell') {
            shellCommand =
                (options.data as Map<String, dynamic>)['command'] as String?;
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: <String, dynamic>{
                  'parts': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'type': 'text',
                      'text': 'CW_QUOTA_JSON:{"results":[]}',
                    },
                  ],
                },
              ),
            );
            return;
          }
          if (options.path == '/session/ses_syntax_probe' &&
              options.method == 'DELETE') {
            handler.resolve(
              Response<dynamic>(requestOptions: options, statusCode: 200),
            );
            return;
          }
          handler.reject(
            DioException(
              requestOptions: options,
              error: 'Unexpected ${options.path}',
            ),
          );
        },
      ),
    );

    final dataSource = QuotaRemoteDataSourceImpl(dio: dio);
    await dataSource.fetchQuotaResults();

    final script = _decodeShellScript(shellCommand!);
    final tempFile = File(
      '${Directory.systemTemp.path}/codewalk_quota_shell_syntax_${DateTime.now().microsecondsSinceEpoch}.js',
    );
    await tempFile.writeAsString(script);
    addTearDown(() async {
      if (tempFile.existsSync()) {
        tempFile.deleteSync();
      }
    });

    late final ProcessResult result;
    try {
      result = await Process.run('node', <String>['--check', tempFile.path]);
    } on ProcessException {
      markTestSkipped('Node.js is not available; skipping JS syntax check.');
      return;
    }
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
  });

  test('OpenCode Go probe parses partial usage from the bearer API', () async {
    final dio = Dio();
    String? shellCommand;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/api/quota/providers') {
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response<dynamic>(
                  requestOptions: options,
                  statusCode: 404,
                ),
              ),
            );
            return;
          }
          if (options.path == '/session' && options.method == 'POST') {
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: <String, dynamic>{'id': 'ses_opencode_go_probe'},
              ),
            );
            return;
          }
          if (options.path == '/session/ses_opencode_go_probe/shell') {
            shellCommand =
                (options.data as Map<String, dynamic>)['command'] as String?;
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: <String, dynamic>{
                  'parts': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'type': 'text',
                      'text': 'CW_QUOTA_JSON:{"results":[]}',
                    },
                  ],
                },
              ),
            );
            return;
          }
          if (options.path == '/session/ses_opencode_go_probe' &&
              options.method == 'DELETE') {
            handler.resolve(
              Response<dynamic>(requestOptions: options, statusCode: 200),
            );
            return;
          }
          handler.reject(
            DioException(
              requestOptions: options,
              error: 'Unexpected ${options.path}',
            ),
          );
        },
      ),
    );
    await QuotaRemoteDataSourceImpl(dio: dio).fetchQuotaResults();
    final script = _decodeShellScript(shellCommand!);
    final probe = script.substring(
      script.indexOf('async function fOCG(a)'),
      script.indexOf('async function fNanoGpt(a)'),
    );
    const mockFetch = '''
const fetch = async (url, options) => {
  if (url !== 'https://opencode.ai/zen/go/v1/usage') throw new Error(url);
  if (options.headers.Authorization !== 'Bearer test-key') throw new Error('auth');
  if (Object.hasOwn(options.headers, 'Cookie')) throw new Error('cookie');
  return {
    ok: true,
    status: 200,
    json: async () => ({
      usage: {
        rolling: { percent: 25, resetsAt: '2026-08-12T12:00:00.000Z' },
        weekly: { percent: 40, resetsAt: '2026-08-19T12:00:00.000Z' },
        monthly: { percent: 55 },
      },
    }),
  };
};
''';
    final executable = [
      "const P = 'CW_QUOTA_JSON:';",
      'function getE(a, al) { for (const x of al) if (a[x]) return a[x]; return null; }',
      "function nE(e) { if (!e) return null; if (typeof e === 'string') return { token: e }; return typeof e === 'object' ? e : null; }",
      script.substring(
        script.indexOf('function bR('),
        script.indexOf('function tUW('),
      ),
      script.substring(
        script.indexOf('function tUW('),
        script.indexOf('function gWin('),
      ),
      mockFetch,
      probe,
      "fOCG({'opencode-go': {key: 'test-key'}}).then((value) => console.log(P + JSON.stringify(value)));",
    ].join('\n');
    late final ProcessResult result;
    try {
      result = await Process.run('node', <String>['-e', executable]);
    } on ProcessException {
      markTestSkipped('Node.js is not available; skipping JS behavior check.');
      return;
    }
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    final output = (result.stdout as String).trim();
    expect(output, startsWith('CW_QUOTA_JSON:'));
    final payload = jsonDecode(output.substring('CW_QUOTA_JSON:'.length));
    expect(payload['ok'], isTrue);
    expect(payload['errorCode'], isNull);
    expect(payload['usage']['windows']['rolling']['usedPercent'], 25);
    expect(payload['usage']['windows']['weekly']['usedPercent'], 40);
    expect(payload['usage']['windows']['monthly']['usedPercent'], 55);
    expect(payload['usage']['windows']['monthly']['resetAt'], isNull);
  });

  test(
    'xAI probe is skipped without host OAuth and parses billing protobuf',
    () async {
      final dio = Dio();
      String? shellCommand;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path == '/api/quota/providers') {
              handler.reject(
                DioException(
                  requestOptions: options,
                  response: Response<dynamic>(
                    requestOptions: options,
                    statusCode: 404,
                  ),
                ),
              );
              return;
            }
            if (options.path == '/session' && options.method == 'POST') {
              handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  statusCode: 200,
                  data: <String, dynamic>{'id': 'ses_xai_probe'},
                ),
              );
              return;
            }
            if (options.path == '/session/ses_xai_probe/shell') {
              shellCommand =
                  (options.data as Map<String, dynamic>)['command'] as String?;
              handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  statusCode: 200,
                  data: <String, dynamic>{
                    'parts': <Map<String, dynamic>>[
                      <String, dynamic>{
                        'type': 'text',
                        'text': 'CW_QUOTA_JSON:{"results":[]}',
                      },
                    ],
                  },
                ),
              );
              return;
            }
            if (options.path == '/session/ses_xai_probe' &&
                options.method == 'DELETE') {
              handler.resolve(
                Response<dynamic>(requestOptions: options, statusCode: 200),
              );
              return;
            }
            handler.reject(
              DioException(
                requestOptions: options,
                error: 'Unexpected ${options.path}',
              ),
            );
          },
        ),
      );
      await QuotaRemoteDataSourceImpl(dio: dio).fetchQuotaResults();
      final script = _decodeShellScript(shellCommand!);
      final helpers = [
        script.substring(
          script.indexOf('function asS('),
          script.indexOf('function toN('),
        ),
        script.substring(
          script.indexOf('function getE('),
          script.indexOf('function nE('),
        ),
        script.substring(
          script.indexOf('function nE('),
          script.indexOf('function asO('),
        ),
        script.substring(
          script.indexOf('function bR('),
          script.indexOf('function tUW('),
        ),
        script.substring(
          script.indexOf('function tUW('),
          script.indexOf('function gWin('),
        ),
      ].join('\n');
      final parseFn = script.substring(
        script.indexOf('function parseXaiUsage('),
        script.indexOf('async function fXai(a)'),
      );
      final probe = script.substring(
        script.indexOf('async function fXai(a)'),
        script.indexOf('(async () => {'),
      );
      const runner = '''
function floatMsg(percent) {
  const body = Buffer.alloc(5);
  body[0] = 0x0d;
  body.writeFloatLE(percent, 1);
  return body;
}
function frame(msg) {
  const out = Buffer.alloc(5 + msg.length);
  out[0] = 0;
  out.writeUInt32BE(msg.length, 1);
  msg.copy(out, 5);
  return out;
}
const fetch = async (url, options) => {
  if (String(url).includes('oauth2/token')) throw new Error('refresh should not run');
  if (!String(url).includes('GetGrokCreditsConfig')) throw new Error(url);
  if (options.headers.Authorization !== 'Bearer test-token') throw new Error('auth');
  const framed = frame(floatMsg(42.5));
  return {
    ok: true,
    status: 200,
    headers: { get: () => null },
    arrayBuffer: async () => framed.buffer.slice(framed.byteOffset, framed.byteOffset + framed.byteLength),
  };
};
Promise.resolve()
  .then(async () => {
    const skipped = await fXai({});
    const apiKey = await fXai({ xai: { type: 'api', key: 'xai-key' } });
    const parsed = parseXaiUsage(new Uint8Array(floatMsg(12.25)));
    const framed = parseXaiUsage(new Uint8Array(frame(floatMsg(88))));
    const fetched = await fXai({
      xai: { type: 'oauth', access: 'test-token', refresh: 'r', expires: Date.now() + 3600000 },
    });
    console.log(P + JSON.stringify({ skipped, apiKey, parsed, framed, fetched }));
  })
  .catch((err) => {
    console.log(P + JSON.stringify({ error: String(err && err.stack || err) }));
    process.exitCode = 1;
  });
''';
      final executable = [
        "const P = 'CW_QUOTA_JSON:';",
        helpers,
        parseFn,
        probe,
        runner,
      ].join('\n');
      late final ProcessResult result;
      try {
        result = await Process.run('node', <String>['-e', executable]);
      } on ProcessException {
        markTestSkipped(
          'Node.js is not available; skipping JS behavior check.',
        );
        return;
      }
      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      final output = (result.stdout as String).trim();
      expect(output, startsWith('CW_QUOTA_JSON:'));
      final payload =
          jsonDecode(output.substring('CW_QUOTA_JSON:'.length))
              as Map<String, dynamic>;
      expect(payload['error'], isNull);
      expect(payload['skipped'], isNull);
      expect(payload['apiKey'], isNull);
      expect((payload['parsed'] as Map)['usedPercent'], closeTo(12.25, 0.001));
      expect((payload['framed'] as Map)['usedPercent'], closeTo(88, 0.001));
      expect(payload['fetched']['providerId'], 'xai');
      expect(payload['fetched']['ok'], isTrue);
      expect(
        payload['fetched']['usage']['windows']['billing_cycle']['usedPercent'],
        closeTo(42.5, 0.001),
      );
    },
  );

  test(
    'DeepSeek and ClinePass probes skip missing keys and parse usage',
    () async {
      final dio = Dio();
      String? shellCommand;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path == '/api/quota/providers') {
              handler.reject(
                DioException(
                  requestOptions: options,
                  response: Response<dynamic>(
                    requestOptions: options,
                    statusCode: 404,
                  ),
                ),
              );
              return;
            }
            if (options.path == '/session' && options.method == 'POST') {
              handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  statusCode: 200,
                  data: <String, dynamic>{'id': 'ses_ds_cp_probe'},
                ),
              );
              return;
            }
            if (options.path == '/session/ses_ds_cp_probe/shell') {
              shellCommand =
                  (options.data as Map<String, dynamic>)['command'] as String?;
              handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  statusCode: 200,
                  data: <String, dynamic>{
                    'parts': <Map<String, dynamic>>[
                      <String, dynamic>{
                        'type': 'text',
                        'text': 'CW_QUOTA_JSON:{"results":[]}',
                      },
                    ],
                  },
                ),
              );
              return;
            }
            if (options.path == '/session/ses_ds_cp_probe' &&
                options.method == 'DELETE') {
              handler.resolve(
                Response<dynamic>(requestOptions: options, statusCode: 200),
              );
              return;
            }
            handler.reject(
              DioException(
                requestOptions: options,
                error: 'Unexpected ${options.path}',
              ),
            );
          },
        ),
      );
      await QuotaRemoteDataSourceImpl(dio: dio).fetchQuotaResults();
      final script = _decodeShellScript(shellCommand!);
      final helpers = [
        script.substring(
          script.indexOf('function getE('),
          script.indexOf('function nE('),
        ),
        script.substring(
          script.indexOf('function nE('),
          script.indexOf('function asO('),
        ),
        script.substring(
          script.indexOf('function asO('),
          script.indexOf('function asS('),
        ),
        script.substring(
          script.indexOf('function asS('),
          script.indexOf('function pickS('),
        ),
        script.substring(
          script.indexOf('function toN('),
          script.indexOf('function toTs('),
        ),
        script.substring(
          script.indexOf('function toTs('),
          script.indexOf('function pgR('),
        ),
        script.substring(
          script.indexOf('function bR('),
          script.indexOf('function tUW('),
        ),
        script.substring(
          script.indexOf('function tUW('),
          script.indexOf('function gWin('),
        ),
      ].join('\n');
      final deepseek = script.substring(
        script.indexOf('async function fDeepseek(a)'),
        script.indexOf('async function fClinePass(a)'),
      );
      final cline = script.substring(
        script.indexOf('async function fClinePass(a)'),
        script.indexOf('(async () => {'),
      );
      const runner = '''
let mode = 'usd';
const fetch = async (url, options) => {
  if (String(url).includes('api.deepseek.com/user/balance')) {
    if (options.headers.Authorization !== 'Bearer ds-key') throw new Error('ds-auth');
    if (mode === 'cny') {
      return {
        ok: true,
        status: 200,
        json: async () => ({ balance_infos: [{ currency: 'CNY', total_balance: '8' }] }),
      };
    }
    return {
      ok: true,
      status: 200,
      json: async () => ({
        balance_infos: [
          { currency: 'CNY', total_balance: '3.00' },
          { currency: 'USD', total_balance: 12.5 },
        ],
      }),
    };
  }
  if (String(url).includes('api.cline.bot')) {
    if (options.headers.Authorization !== 'Bearer cline-key') throw new Error('cp-auth');
    if (mode === 'empty-cp') {
      return { ok: true, status: 200, json: async () => ({ data: { limits: [] } }) };
    }
    return {
      ok: true,
      status: 200,
      json: async () => ({
        data: {
          limits: [
            { type: 'five_hour', percentUsed: 40, resetsAt: '2026-09-12T18:00:00.000Z' },
            { type: 'weekly', percentUsed: '55' },
            { type: 'monthly', percentUsed: 10 },
            { type: 'unknown', percentUsed: 99 },
          ],
        },
      }),
    };
  }
  throw new Error(url);
};
Promise.resolve()
  .then(async () => {
    const skippedDs = await fDeepseek({});
    const skippedCp = await fClinePass({});
    const ds = await fDeepseek({ deepseek: { key: 'ds-key' } });
    mode = 'cny';
    const cny = await fDeepseek({ deepseek: { token: 'ds-key' } });
    mode = 'usd';
    const cp = await fClinePass({ 'cline-pass': { key: 'cline-key' } });
    mode = 'empty-cp';
    const emptyCp = await fClinePass({ 'cline-pass': { token: 'cline-key' } });
    console.log(P + JSON.stringify({ skippedDs, skippedCp, ds, cny, cp, emptyCp }));
  })
  .catch((err) => {
    console.log(P + JSON.stringify({ error: String(err && err.stack || err) }));
    process.exitCode = 1;
  });
''';
      final executable = [
        "const P = 'CW_QUOTA_JSON:';",
        helpers,
        deepseek,
        cline,
        runner,
      ].join('\n');
      late final ProcessResult result;
      try {
        result = await Process.run('node', <String>['-e', executable]);
      } on ProcessException {
        markTestSkipped(
          'Node.js is not available; skipping JS behavior check.',
        );
        return;
      }
      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      final output = (result.stdout as String).trim();
      expect(output, startsWith('CW_QUOTA_JSON:'));
      final payload =
          jsonDecode(output.substring('CW_QUOTA_JSON:'.length))
              as Map<String, dynamic>;
      expect(payload['error'], isNull);
      expect(payload['skippedDs'], isNull);
      expect(payload['skippedCp'], isNull);
      expect(payload['ds']['providerId'], 'deepseek');
      expect(payload['ds']['ok'], isTrue);
      expect(
        payload['ds']['usage']['windows']['credits_balance']['valueLabel'],
        '\$12.50',
      );
      expect(
        payload['cny']['usage']['windows']['credits_balance']['valueLabel'],
        '¥8.00',
      );
      expect(payload['cp']['providerId'], 'cline-pass');
      expect(payload['cp']['ok'], isTrue);
      expect(payload['cp']['usage']['windows']['5h']['usedPercent'], 40);
      expect(payload['cp']['usage']['windows']['weekly']['usedPercent'], 55);
      expect(payload['cp']['usage']['windows']['monthly']['usedPercent'], 10);
      expect(payload['cp']['usage']['windows'].containsKey('unknown'), isFalse);
      expect(payload['emptyCp']['ok'], isFalse);
    },
  );

  test(
    'falls back to shell when REST returns non-404 error (e.g. 500)',
    () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path == '/api/quota/providers') {
              // Simulate a 500 internal server error – previously this
              // returned an empty list instead of null, preventing the
              // shell fallback from being attempted.
              handler.reject(
                DioException(
                  requestOptions: options,
                  response: Response<dynamic>(
                    requestOptions: options,
                    statusCode: 500,
                  ),
                ),
              );
              return;
            }
            if (options.path == '/session' && options.method == 'POST') {
              handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  statusCode: 200,
                  data: <String, dynamic>{'id': 'ses_500_fallback'},
                ),
              );
              return;
            }
            if (options.path == '/session/ses_500_fallback/shell') {
              handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  statusCode: 200,
                  data: <String, dynamic>{
                    'parts': <Map<String, dynamic>>[
                      <String, dynamic>{
                        'type': 'text',
                        'text':
                            'CW_QUOTA_JSON:{"results":[{"providerId":"claude","providerName":"Claude","ok":true,"configured":true,"usage":{"windows":{"5h":{"usedPercent":30}}},"fetchedAt":1}]}',
                      },
                    ],
                  },
                ),
              );
              return;
            }
            if (options.path == '/session/ses_500_fallback' &&
                options.method == 'DELETE') {
              handler.resolve(
                Response<dynamic>(requestOptions: options, statusCode: 200),
              );
              return;
            }
            handler.reject(
              DioException(
                requestOptions: options,
                error: 'Unexpected ${options.path}',
              ),
            );
          },
        ),
      );

      final dataSource = QuotaRemoteDataSourceImpl(dio: dio);
      final results = await dataSource.fetchQuotaResults();

      expect(results, hasLength(1));
      expect(results.first.providerId, 'claude');
      expect(results.first.usage?.windows['5h']?.usedPercent, 30);
    },
  );

  test(
    'parses Google model quota payloads from shell fallback results',
    () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path == '/api/quota/providers') {
              handler.reject(
                DioException(
                  requestOptions: options,
                  response: Response<dynamic>(
                    requestOptions: options,
                    statusCode: 404,
                  ),
                ),
              );
              return;
            }
            if (options.path == '/session' && options.method == 'POST') {
              handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  statusCode: 200,
                  data: <String, dynamic>{'id': 'ses_google_probe'},
                ),
              );
              return;
            }
            if (options.path == '/session/ses_google_probe/shell') {
              handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  statusCode: 200,
                  data: <String, dynamic>{
                    'parts': <Map<String, dynamic>>[
                      <String, dynamic>{
                        'type': 'text',
                        'text':
                            'CW_QUOTA_JSON:{"results":[{"providerId":"google","providerName":"Google","ok":true,"configured":true,"usage":{"windows":{},"models":{"gemini/gemini-2.5-pro":{"windows":{"daily":{"usedPercent":44,"remainingPercent":56,"windowSeconds":86400}}},"antigravity/gemini-2.5-flash":{"windows":{"5h":{"usedPercent":72,"remainingPercent":28,"windowSeconds":18000}}}}},"fetchedAt":1}]}',
                      },
                    ],
                  },
                ),
              );
              return;
            }
            if (options.path == '/session/ses_google_probe' &&
                options.method == 'DELETE') {
              handler.resolve(
                Response<dynamic>(requestOptions: options, statusCode: 200),
              );
              return;
            }
            handler.reject(
              DioException(
                requestOptions: options,
                error: 'Unexpected ${options.path}',
              ),
            );
          },
        ),
      );

      final dataSource = QuotaRemoteDataSourceImpl(dio: dio);
      final results = await dataSource.fetchQuotaResults();

      expect(results, hasLength(1));
      expect(results.first.providerId, 'google');
      expect(
        results.first.usage?.models.keys,
        containsAll(<String>[
          'gemini/gemini-2.5-pro',
          'antigravity/gemini-2.5-flash',
        ]),
      );
      expect(
        results
            .first
            .usage
            ?.models['gemini/gemini-2.5-pro']
            ?.windows['daily']
            ?.usedPercent,
        44,
      );
      expect(
        results
            .first
            .usage
            ?.models['antigravity/gemini-2.5-flash']
            ?.windows['5h']
            ?.windowSeconds,
        18000,
      );
    },
  );

  Dio createMockDio(String resultsJson) {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/api/quota/providers') {
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response<dynamic>(
                  requestOptions: options,
                  statusCode: 404,
                ),
              ),
            );
            return;
          }
          if (options.path == '/session' && options.method == 'POST') {
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: <String, dynamic>{'id': 'ses_quota_probe'},
              ),
            );
            return;
          }
          if (options.path == '/session/ses_quota_probe/shell') {
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: <String, dynamic>{
                  'parts': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'type': 'text',
                      'text': 'CW_QUOTA_JSON:$resultsJson',
                    },
                  ],
                },
              ),
            );
            return;
          }
          if (options.path == '/session/ses_quota_probe' &&
              options.method == 'DELETE') {
            handler.resolve(
              Response<dynamic>(requestOptions: options, statusCode: 200),
            );
            return;
          }
          handler.reject(
            DioException(
              requestOptions: options,
              error: 'Unexpected ${options.path}',
            ),
          );
        },
      ),
    );
    return dio;
  }

  test('parses nano-gpt quota payload from shell fallback', () async {
    final dio = createMockDio(
      '{"results":[{"providerId":"nano-gpt","providerName":"NanoGPT","ok":true,"configured":true,"usage":{"windows":{"daily":{"usedPercent":50,"windowSeconds":86400,"resetAt":1000,"valueLabel":null}}},"fetchedAt":1}]}',
    );
    final dataSource = QuotaRemoteDataSourceImpl(dio: dio);
    final results = await dataSource.fetchQuotaResults();
    expect(results, hasLength(1));
    expect(results.first.providerId, 'nano-gpt');
    expect(results.first.usage?.windows['daily']?.usedPercent, 50.0);
  });

  test('parses wafer quota payload from shell fallback', () async {
    final dio = createMockDio(
      '{"results":[{"providerId":"wafer","providerName":"Wafer.ai","ok":true,"configured":true,"usage":{"windows":{"5h":{"usedPercent":75,"windowSeconds":18000,"resetAt":1000,"valueLabel":"+5 overage"}}},"fetchedAt":1}]}',
    );
    final dataSource = QuotaRemoteDataSourceImpl(dio: dio);
    final results = await dataSource.fetchQuotaResults();
    expect(results, hasLength(1));
    expect(results.first.providerId, 'wafer');
    expect(
      results.first.usage?.windows['5h']?.valueLabel,
      contains('+5 overage'),
    );
  });

  test('parses github-copilot-addon quota payload from shell fallback', () async {
    final dio = createMockDio(
      '{"results":[{"providerId":"github-copilot-addon","providerName":"GitHub Copilot Add-on","ok":true,"configured":true,"usage":{"windows":{"premium":{"usedPercent":30,"windowSeconds":null,"resetAt":1000,"valueLabel":"30 / 100 left"}}},"fetchedAt":1}]}',
    );
    final dataSource = QuotaRemoteDataSourceImpl(dio: dio);
    final results = await dataSource.fetchQuotaResults();
    expect(results, hasLength(1));
    expect(results.first.providerId, 'github-copilot-addon');
  });

  test('parses kimi-for-coding quota payload from shell fallback', () async {
    final dio = createMockDio(
      '{"results":[{"providerId":"kimi-for-coding","providerName":"Kimi for Coding","ok":true,"configured":true,"usage":{"windows":{"weekly":{"usedPercent":20,"windowSeconds":null,"resetAt":1000,"valueLabel":null}}},"fetchedAt":1}]}',
    );
    final dataSource = QuotaRemoteDataSourceImpl(dio: dio);
    final results = await dataSource.fetchQuotaResults();
    expect(results, hasLength(1));
    expect(results.first.providerId, 'kimi-for-coding');
  });

  test('parses zhipuai-coding-plan quota payload from shell fallback', () async {
    final dio = createMockDio(
      '{"results":[{"providerId":"zhipuai-coding-plan","providerName":"Zhipu AI Coding Plan","ok":true,"configured":true,"usage":{"windows":{"Tokens":{"usedPercent":40,"windowSeconds":18000,"resetAt":1000,"valueLabel":null}}},"fetchedAt":1}]}',
    );
    final dataSource = QuotaRemoteDataSourceImpl(dio: dio);
    final results = await dataSource.fetchQuotaResults();
    expect(results, hasLength(1));
    expect(results.first.providerId, 'zhipuai-coding-plan');
  });

  test('parses minimax-coding-plan quota payload from shell fallback', () async {
    final dio = createMockDio(
      '{"results":[{"providerId":"minimax-coding-plan","providerName":"MiniMax Coding Plan (minimax.io)","ok":true,"configured":true,"usage":{"windows":{"5h":{"usedPercent":60,"windowSeconds":18000,"resetAt":1000,"valueLabel":null}}},"fetchedAt":1}]}',
    );
    final dataSource = QuotaRemoteDataSourceImpl(dio: dio);
    final results = await dataSource.fetchQuotaResults();
    expect(results, hasLength(1));
    expect(results.first.providerId, 'minimax-coding-plan');
  });

  test(
    'parses minimax-cn-coding-plan quota payload from shell fallback',
    () async {
      final dio = createMockDio(
        '{"results":[{"providerId":"minimax-cn-coding-plan","providerName":"MiniMax Coding Plan (minimaxi.com)","ok":true,"configured":true,"usage":{"windows":{"5h":{"usedPercent":30,"windowSeconds":18000,"resetAt":1000,"valueLabel":"70 / 100 remains"}}},"fetchedAt":1}]}',
      );
      final dataSource = QuotaRemoteDataSourceImpl(dio: dio);
      final results = await dataSource.fetchQuotaResults();
      expect(results, hasLength(1));
      expect(results.first.providerId, 'minimax-cn-coding-plan');
    },
  );

  test('parses zai-coding-plan quota payload from shell fallback', () async {
    final dio = createMockDio(
      '{"results":[{"providerId":"zai-coding-plan","providerName":"z.ai","ok":true,"configured":true,"usage":{"windows":{"5h":{"usedPercent":10,"windowSeconds":18000,"resetAt":1000,"valueLabel":null}}},"fetchedAt":1}]}',
    );
    final dataSource = QuotaRemoteDataSourceImpl(dio: dio);
    final results = await dataSource.fetchQuotaResults();
    expect(results, hasLength(1));
    expect(results.first.providerId, 'zai-coding-plan');
  });

  test('parses cursor quota payload from shell fallback', () async {
    final dio = createMockDio(
      '{"results":[{"providerId":"cursor","providerName":"Cursor","ok":true,"configured":true,"usage":{"windows":{"billing_cycle":{"usedPercent":15,"windowSeconds":null,"resetAt":1000,"valueLabel":"\$1.50"}}},"fetchedAt":1}]}',
    );
    final dataSource = QuotaRemoteDataSourceImpl(dio: dio);
    final results = await dataSource.fetchQuotaResults();
    expect(results, hasLength(1));
    expect(results.first.providerId, 'cursor');
  });

  test('parses ollama-cloud quota payload from shell fallback', () async {
    final dio = createMockDio(
      '{"results":[{"providerId":"ollama-cloud","providerName":"Ollama Cloud","ok":true,"configured":true,"usage":{"windows":{"session":{"usedPercent":80,"windowSeconds":null,"resetAt":null,"valueLabel":null}}},"fetchedAt":1}]}',
    );
    final dataSource = QuotaRemoteDataSourceImpl(dio: dio);
    final results = await dataSource.fetchQuotaResults();
    expect(results, hasLength(1));
    expect(results.first.providerId, 'ollama-cloud');
  });

  test('parses deepseek quota payload from shell fallback', () async {
    final dio = createMockDio(
      '{"results":[{"providerId":"deepseek","providerName":"DeepSeek","ok":true,"configured":true,"usage":{"windows":{"credits_balance":{"usedPercent":null,"valueLabel":"\$12.50"}}},"fetchedAt":1}]}',
    );
    final results = await QuotaRemoteDataSourceImpl(
      dio: dio,
    ).fetchQuotaResults();
    expect(results, hasLength(1));
    expect(results.first.providerId, 'deepseek');
    expect(
      results.first.usage?.windows['credits_balance']?.valueLabel,
      '\$12.50',
    );
  });

  test('parses cline-pass quota payload from shell fallback', () async {
    final dio = createMockDio(
      '{"results":[{"providerId":"cline-pass","providerName":"ClinePass","ok":true,"configured":true,"usage":{"windows":{"5h":{"usedPercent":40},"weekly":{"usedPercent":55},"monthly":{"usedPercent":10}}},"fetchedAt":1}]}',
    );
    final results = await QuotaRemoteDataSourceImpl(
      dio: dio,
    ).fetchQuotaResults();
    expect(results, hasLength(1));
    expect(results.first.providerId, 'cline-pass');
    expect(results.first.usage?.windows['5h']?.usedPercent, 40);
  });

  test('supported auth keys hydration matches generated JS', () async {
    final dio = Dio();
    String? shellCommand;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/api/quota/providers') {
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response<dynamic>(
                  requestOptions: options,
                  statusCode: 404,
                ),
              ),
            );
            return;
          }
          if (options.path == '/session' && options.method == 'POST') {
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: <String, dynamic>{'id': 'ses_quota_probe'},
              ),
            );
            return;
          }
          if (options.path == '/session/ses_quota_probe/shell') {
            shellCommand =
                (options.data as Map<String, dynamic>)['command'] as String?;
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: <String, dynamic>{'parts': <Map<String, dynamic>>[]},
              ),
            );
            return;
          }
          if (options.path == '/session/ses_quota_probe' &&
              options.method == 'DELETE') {
            handler.resolve(
              Response<dynamic>(requestOptions: options, statusCode: 200),
            );
            return;
          }
        },
      ),
    );
    final dataSource = QuotaRemoteDataSourceImpl(dio: dio);
    await dataSource.fetchQuotaResults();
    final script = _decodeShellScript(shellCommand!);

    final expectedKeys = <String>[
      'anthropic',
      'claude',
      'openrouter',
      'openai',
      'codex',
      'chatgpt',
      'google',
      'google.oauth',
      'github-copilot',
      'copilot',
      'github-copilot-addon',
      'opencode-go',
      'nano-gpt',
      'nanogpt',
      'nano_gpt',
      'wafer',
      'wafer-ai',
      'wafer_ai',
      'wafer.ai',
      'kimi-for-coding',
      'kimi',
      'zhipuai-coding-plan',
      'zhipuai',
      'zhipu',
      'minimax-coding-plan',
      'minimax-cn-coding-plan',
      'zai-coding-plan',
      'zai',
      'z.ai',
      'cursor',
      'ollama-cloud',
      'ollamacloud',
      'deepseek',
      'cline-pass',
      'snowflake-cortex',
      'snowflake',
      'cortex',
      'grok',
      'xai',
      'x-ai',
      'cohere',
      'cohere-north',
      'cohere-north-mini-code',
    ];
    for (final key in expectedKeys) {
      expect(script, contains('"$key"'));
    }
  });

  test('minimax-cn uses inverted semantics in JS code', () async {
    final dio = Dio();
    String? shellCommand;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/api/quota/providers') {
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response<dynamic>(
                  requestOptions: options,
                  statusCode: 404,
                ),
              ),
            );
            return;
          }
          if (options.path == '/session' && options.method == 'POST') {
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: <String, dynamic>{'id': 'ses_quota_probe'},
              ),
            );
            return;
          }
          if (options.path == '/session/ses_quota_probe/shell') {
            shellCommand =
                (options.data as Map<String, dynamic>)['command'] as String?;
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: <String, dynamic>{'parts': <Map<String, dynamic>>[]},
              ),
            );
            return;
          }
          if (options.path == '/session/ses_quota_probe' &&
              options.method == 'DELETE') {
            handler.resolve(
              Response<dynamic>(requestOptions: options, statusCode: 200),
            );
            return;
          }
        },
      ),
    );
    final dataSource = QuotaRemoteDataSourceImpl(dio: dio);
    await dataSource.fetchQuotaResults();
    final script = _decodeShellScript(shellCommand!);

    expect(script, contains('intervalTotal - intervalUsage'));
    expect(script, contains('weeklyTotal - weeklyUsage'));
  });

  test(
    'minimax providers fall back to remaining_percent when total is 0',
    () async {
      // Regression for the Coding Plan rate-limit response, which returns
      // total=0 / usage=0 with a separate `current_*_remaining_percent` field
      // that the popup filter would otherwise hide (usedPercent == null).
      final dio = Dio();
      String? shellCommand;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path == '/api/quota/providers') {
              handler.reject(
                DioException(
                  requestOptions: options,
                  response: Response<dynamic>(
                    requestOptions: options,
                    statusCode: 404,
                  ),
                ),
              );
              return;
            }
            if (options.path == '/session' && options.method == 'POST') {
              handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  statusCode: 200,
                  data: <String, dynamic>{'id': 'ses_quota_probe'},
                ),
              );
              return;
            }
            if (options.path == '/session/ses_quota_probe/shell') {
              shellCommand =
                  (options.data as Map<String, dynamic>)['command'] as String?;
              handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  statusCode: 200,
                  data: <String, dynamic>{'parts': <Map<String, dynamic>>[]},
                ),
              );
              return;
            }
            if (options.path == '/session/ses_quota_probe' &&
                options.method == 'DELETE') {
              handler.resolve(
                Response<dynamic>(requestOptions: options, statusCode: 200),
              );
              return;
            }
          },
        ),
      );
      final dataSource = QuotaRemoteDataSourceImpl(dio: dio);
      await dataSource.fetchQuotaResults();
      final script = _decodeShellScript(shellCommand!);

      // Both providers must consult the remaining_percent fallback.
      expect(script, contains('current_interval_remaining_percent'));
      expect(script, contains('current_weekly_remaining_percent'));
      // The fallback must compute usedPercent as (100 - remaining).
      expect(script, contains('100 - intervalRemPct'));
      expect(script, contains('100 - weeklyRemPct'));
    },
  );

  test('fGHA reads github-copilot-addon key alias', () async {
    // Regression: fGHA must read the standalone 'github-copilot-addon' key,
    // not just 'github-copilot'/'copilot'. Without the alias, users who only
    // configure the addon would have fGHA return null and no quota row.
    final dio = Dio();
    String? shellCommand;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/api/quota/providers') {
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response<dynamic>(
                  requestOptions: options,
                  statusCode: 404,
                ),
              ),
            );
            return;
          }
          if (options.path == '/session' && options.method == 'POST') {
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: <String, dynamic>{'id': 'ses_quota_probe'},
              ),
            );
            return;
          }
          if (options.path == '/session/ses_quota_probe/shell') {
            shellCommand =
                (options.data as Map<String, dynamic>)['command'] as String?;
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: <String, dynamic>{'parts': <Map<String, dynamic>>[]},
              ),
            );
            return;
          }
          if (options.path == '/session/ses_quota_probe' &&
              options.method == 'DELETE') {
            handler.resolve(
              Response<dynamic>(requestOptions: options, statusCode: 200),
            );
            return;
          }
        },
      ),
    );
    final dataSource = QuotaRemoteDataSourceImpl(dio: dio);
    await dataSource.fetchQuotaResults();
    final script = _decodeShellScript(shellCommand!);

    expect(script, contains("'github-copilot-addon'"));
  });
}
