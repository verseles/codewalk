import 'dart:convert';
import 'dart:io';

import 'package:codewalk/data/datasources/quota_remote_datasource.dart';
import 'package:codewalk/presentation/services/chat_title_generator.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

Future<String> _probeScript() async {
  final dio = Dio();
  String? command;
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        Object? data;
        var status = 200;
        if (options.path == '/api/quota/providers') {
          status = 404;
        } else if (options.path == '/session') {
          data = {'id': 'quota_metadata_test'};
        } else if (options.path.endsWith('/shell')) {
          command = (options.data as Map)['command'] as String;
          data = {
            'parts': [
              {'type': 'text', 'text': 'CW_QUOTA_JSON:{"results":[]}'},
            ],
          };
        }
        handler.resolve(
          Response<dynamic>(
            requestOptions: options,
            statusCode: status,
            data: data,
          ),
        );
      },
    ),
  );
  await QuotaRemoteDataSourceImpl(dio: dio).fetchQuotaResults();
  final encoded = RegExp(
    r"Buffer\.from\('([^']+)'\s*,\s*'base64'\)",
  ).firstMatch(command!)!.group(1)!;
  final script = utf8.decode(base64Decode(encoded));
  return script.substring(0, script.indexOf('(async () => {'));
}

void main() {
  tearDown(ChatTitleGenerator.ephemeralSessionIds.clear);

  test(
    'G1 quota probes preserve actual periods and distinct Codex windows',
    () async {
      final script = await _probeScript();
      const runner = r'''
const assert = require('node:assert/strict');
Date.now = () => Date.parse('2026-09-15T00:00:00Z');
const nowSec = Date.now() / 1000;
function vint(value) {
  let n = BigInt(value); const out = [];
  do { let b = Number(n & 127n); n >>= 7n; out.push(n ? b | 128 : b); } while (n);
  return Buffer.from(out);
}
function msg(field, body) { return Buffer.concat([vint(field * 8 + 2), vint(body.length), body]); }
function scalar(field, value) { return Buffer.concat([vint(field * 8), vint(value)]); }
function percent(value) { const b = Buffer.alloc(5); b[0] = 13; b.writeFloatLE(value, 1); return b; }
function stamp(field, seconds) { return msg(field, scalar(1, seconds)); }
function period(start, end) {
  return msg(8, Buffer.concat([scalar(1, 2), ...(start === null ? [] : [stamp(2, start)]), ...(end === null ? [] : [stamp(3, end)])]));
}
function config(start, end, extra = Buffer.alloc(0), usage = percent(25)) {
  return msg(1, Buffer.concat([usage, period(start, end), extra]));
}
function frame(body, flag = 0) {
  const head = Buffer.alloc(5); head[0] = flag; head.writeUInt32BE(body.length, 1);
  return Buffer.concat([head, body]);
}
const start = nowSec - 2 * 86400, end = start + 7 * 86400;
const valid = config(start, end, Buffer.concat([stamp(5, nowSec + 3600), msg(99, Buffer.from('opaque text'))]));
const parsed = parseXaiUsage(valid);
assert.equal(parsed.windowSeconds, 604800);
assert.equal(parsed.resetAt, end * 1000); // Prefer matching current period, not legacy reset.
assert.equal(parsed.usedPercent, 25);
assert.equal(parseXaiUsage(config(start, start + 28 * 86400)).windowSeconds, 28 * 86400);
assert.equal(parseXaiUsage(config(start, end, Buffer.alloc(0), Buffer.alloc(0))).usedPercent, 0);
for (const [s, e] of [[null, end], [start, null], [end, start], [nowSec + 10, end], [start - 86400, start]]) {
  const result = parseXaiUsage(config(s, e));
  assert.equal(result.usedPercent, 25);
  assert.equal(result.windowSeconds, null);
  assert.equal(result.resetAt, null);
}
assert.equal(parseXaiUsage(config(start, end, period(start, end))).windowSeconds, null);
assert.equal(parseXaiUsage(Buffer.concat([frame(config(start, null)), frame(config(null, end))])).windowSeconds, null);
assert.equal(parseXaiUsage(percent(12)).windowSeconds, null);
assert.equal(parseXaiUsage(frame(valid)).windowSeconds, 604800);
assert.throws(() => parseXaiUsage(Buffer.concat([frame(valid), frame(Buffer.from('grpc-status: 7\r\n'), 128)])));
assert.throws(() => parseXaiUsage(Buffer.from([0, 0, 0, 1, 0])));

let response;
const fetch = async (url) => {
  if (String(url).includes('GetGrokCreditsConfig')) return {ok:true, status:200, headers:{get:()=>null}, arrayBuffer:async()=>valid};
  assert.equal(url, 'https://chatgpt.com/backend-api/wham/usage');
  return {ok:true, json:async()=>response};
};
const window = (duration, used = 30) => ({limit_window_seconds:duration, used_percent:used, reset_at:end});
(async () => {
  const xai = await fXai({xai:{type:'oauth', access:'fixture', expires:Date.now()+3600000}});
  assert.equal(xai.usage.windows.billing_cycle.windowSeconds, 604800);
  for (const [primary, secondary, keys] of [
    [window(604800), null, ['weekly']],
    [window(18000), null, ['5h']],
    [window(18000), window(604800), ['5h','weekly']],
    [window(604800), window(18000), ['weekly','5h']],
    [window(604800), window(604800, 70), ['weekly','weekly_secondary']],
    [null, window(604800), ['weekly']],
    [window(null), null, ['primary']],
    [window(0), null, ['primary']],
    [window(7200), null, ['primary']],
  ]) {
    response = {rate_limit:{primary_window:primary, secondary_window:secondary}};
    const result = await fX({openai:{access:'fixture'}});
    assert.equal(result.ok, true);
    assert.deepEqual(Object.keys(result.usage.windows), keys);
    if (primary && Number.isInteger(primary.limit_window_seconds) && primary.limit_window_seconds > 0) {
      assert.equal(result.usage.windows[keys[0]].windowSeconds, primary.limit_window_seconds);
    }
  }
  response = {credits:{balance:10}, rate_limit:{primary_window:window(604800)}};
  const result = await fX({openai:{access:'fixture'}});
  assert.equal(result.usage.windows.credits.valueLabel, '$10.00 remaining');
  console.log('G1 metadata OK');
})().catch(error => { console.error(error); process.exitCode = 1; });
''';
      final result = await Process.run('node', ['-e', '$script\n$runner']);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect(result.stdout, contains('G1 metadata OK'));
    },
  );

  for (final switchAt in [
    '/api/quota/providers',
    '/session',
    '/session/probe/shell',
  ]) {
    test('G1 quota stops old server chain after $switchAt', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://server-a.test'));
      final requests = <String>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final path = options.uri.path;
            requests.add('${options.method} ${options.uri}');
            if (path == switchAt) dio.options.baseUrl = 'https://server-b.test';
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: path == '/api/quota/providers' ? 404 : 200,
                data: path == '/session'
                    ? {'id': 'probe'}
                    : {
                        'parts': [
                          {
                            'type': 'text',
                            'text': 'CW_QUOTA_JSON:{"results":[]}',
                          },
                        ],
                      },
              ),
            );
          },
        ),
      );
      await QuotaRemoteDataSourceImpl(dio: dio).fetchQuotaResults();
      expect(
        requests.every((request) => request.contains('server-a.test')),
        isTrue,
      );
      expect(requests.last, endsWith(switchAt));
      expect(requests.any((request) => request.startsWith('DELETE')), isFalse);
    });
  }
}
