import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

@JS('cwSp04')
external set bridge(JSFunction value);

String base = '', authorization = '', session = '';
Future<void> transition = Future<void>.value();
final attempts = <Sse>[];
final milestones = <Map<String, Object?>>[];
int generation = 0, activeReaders = 0, maxActiveReaders = 0;
bool enabled = false, recovering = false;
String? recoveryError;
Sse? current;
web.AbortController? hydration;
int now() => DateTime.now().millisecondsSinceEpoch;
void mark(String kind, [Map<String, Object?> extra = const {}]) =>
    milestones.add({'kind': kind, 'atMs': now(), ...extra});
Future<T> serial<T>(Future<T> Function() action) {
  final result = transition.then((_) => action());
  transition = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
  return result;
}

void main() {
  bridge = ((JSString input) => dispatch(input.toDart).toJS).toJS;
  runApp(const SizedBox.shrink());
}

Future<JSString> dispatch(String input) async {
  try {
    final o = jsonDecode(input) as Map<String, dynamic>;
    Object result;
    switch (o['op']) {
      case 'configure':
        enabled = false;
        generation++;
        hydration?.abort();
        current?.abort();
        result = await serial(() async {
          await stop();
          base = o['base'] as String;
          authorization = o['authorization'] as String;
          session = (o['session'] as String?) ?? '';
          return {'ok': true, 'origin': web.window.location.origin};
        });
      case 'info':
        result = await request('/api/info');
      case 'start':
        result = await serial(() async {
          await start();
          enabled = session.isNotEmpty;
          return state();
        });
      case 'state':
        result = state();
      case 'shutdown':
        // Invalidate queued recovery before waiting for the serial transition.
        enabled = false;
        generation++;
        hydration?.abort();
        current?.abort();
        result = await serial(() async {
          try {
            await stop();
          } finally {
            authorization = '';
          }
          return {...state(), 'credentialsCleared': authorization.isEmpty};
        });
      default:
        throw ArgumentError('unknown operation');
    }
    return jsonEncode(result).toJS;
  } catch (error) {
    return jsonEncode({'ok': false, 'errorType': error.runtimeType.toString()}).toJS;
  }
}

Map<String, Object?> state() => {
  'ok': true,
  'origin': web.window.location.origin,
  'visibility': web.document.visibilityState,
  'activeReaders': activeReaders,
  'maxActiveReaders': maxActiveReaders,
  'activeAttempts': attempts.where((a) => !a.ended).length,
  'milestones': milestones,
  'recoveryError': recoveryError,
  'attempts': attempts.map((a) => a.result()).toList(),
};

Future<bool> ownedListener(web.AbortController controller) async {
  final response = await web.window.fetch('/__native_owned'.toJS,
    web.RequestInit(signal: controller.signal, credentials: 'omit',
      redirect: 'error', cache: 'no-store')).toDart;
  if (response.status != 200) return false;
  final proof = jsonDecode((await response.text().toDart).toDart) as Map;
  return proof['owned'] == true && proof['base'] == base;
}

Future<Map<String, Object?>> request(String path, {int timeoutMs = 12000,
    web.AbortController? cancellation}) async {
  final controller = cancellation ?? web.AbortController();
  final timer = Timer(Duration(milliseconds: timeoutMs), () => controller.abort());
  final headers = web.Headers();
  headers.set('Authorization', authorization);
  headers.set('Accept', 'application/json');
  try {
    if (!await ownedListener(controller)) return {'ok': false, 'errorType': 'UnownedListener'};
    final response = await web.window.fetch((base + path).toJS,
      web.RequestInit(headers: headers, signal: controller.signal,
        credentials: 'omit', redirect: 'error')).toDart;
    final text = (await response.text().toDart).toDart;
    // Retry/auth classification uses HTTP status, independent of an error body's schema.
    if (response.status != 200) return {'ok': true, 'status': response.status,
      'body': {'bytes': utf8.encode(text).length}};
    final json = response.headers.get('content-type')?.contains('application/json') == true;
    Object? body;
    try {
      body = text.isEmpty ? null : json ? jsonDecode(text) : {'bytes': utf8.encode(text).length};
    } on FormatException {
      throw StateError('invalid JSON response');
    }
    return {'ok': true, 'status': response.status, 'body': body};
  } finally {
    timer.cancel();
  }
}

Future<void> stop() async {
  final old = current;
  if (old == null) return;
  if (!old.ended) old.abort();
  await old.done.timeout(const Duration(seconds: 12));
}

Future<void> start({int timeoutMs = 12000}) async {
  await stop();
  final next = Sse(attempts.length + 1);
  current = next;
  attempts.add(next);
  next.done = next.read();
  unawaited(next.done.then((_) => recover(next)));
  final timer = Timer(Duration(milliseconds: timeoutMs), next.abort);
  try {
    while (!next.connected && !next.ended) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    if (!next.connected) {
      await next.done.timeout(const Duration(seconds: 12));
      throw StateError('SSE connection failed');
    }
  } finally {
    timer.cancel();
  }
}

Future<void> recover(Sse old) async {
  if (!enabled || recovering || old.locallyAborted || old.fatal || !old.connected) return;
  recovering = true;
  final epoch = generation;
  Timer? budgetTimer;
  try {
    await serial(() async {
      if (!enabled || epoch != generation || current != old) return;
      mark('naturalDisconnect', {'attempt': old.number, 'outcome': old.outcome});
      final deadline = now() + 20000;
      budgetTimer = Timer(const Duration(seconds: 20), () {
        if (epoch == generation && enabled) {
          current?.abort();
          hydration?.abort();
        }
      });
      for (var i = 0; i < 12 && now() < deadline; i++) {
        final backoff = i < 3 ? 250 : 1000;
        await Future<void>.delayed(Duration(milliseconds: (deadline - now()).clamp(1, backoff)));
        if (!enabled || epoch != generation) return;
        if (now() >= deadline) break;
        try {
          await start(timeoutMs: (deadline - now()).clamp(1, 1500));
        } catch (_) {
          if (current!.fatal) rethrow;
          continue;
        }
        if (!enabled || epoch != generation) { await stop(); return; }
        if (now() >= deadline) break;
        final cancellation = web.AbortController();
        hydration = cancellation;
        Map<String, Object?> snapshot;
        try {
          snapshot = await request('/api/session/$session',
            timeoutMs: deadline - now(), cancellation: cancellation);
        } on StateError {
          rethrow;
        } catch (_) {
          if (!enabled || epoch != generation) { await stop(); return; }
          await stop();
          continue;
        } finally {
          if (hydration == cancellation) hydration = null;
        }
        if (!enabled || epoch != generation) { await stop(); return; }
        if (now() >= deadline) break;
        if (snapshot['ok'] != true || const [502, 503, 504].contains(snapshot['status'])) {
          await stop();
          continue;
        }
        if (snapshot['status'] != 200) throw StateError('snapshot status');
        final data = (snapshot['body'] as Map)['data'] as Map;
        if (data['id'] != session) throw StateError('snapshot identity');
        mark('streamRecovered', {'fromAttempt': old.number,
          'attempt': current!.number, 'id': data['id'], 'title': data['title']});
        return;
      }
      throw StateError('bounded recovery exhausted');
    });
  } catch (error) {
    if (epoch == generation && enabled) {
      recoveryError = error.runtimeType.toString();
      enabled = false;
      await stop();
    }
  } finally {
    budgetTimer?.cancel();
    recovering = false;
  }
}

class Sse {
  Sse(this.number);
  final int number;
  final startedMs = now();
  final controller = web.AbortController();
  final events = <Map<String, Object?>>[], chunks = <Map<String, Object?>>[];
  late Future<void> done;
  bool connected = false, ended = false, released = false, locallyAborted = false, fatal = false;
  int? status, endedMs, readerMs, releasedMs;
  String? mediaType, errorType, outcome;
  String pending = '';
  void abort() { locallyAborted = true; controller.abort(); }
  Future<void> read() async {
    web.ReadableStreamDefaultReader? reader;
    StreamController<List<int>>? bytes;
    Future<void>? decoding;
    try {
      if (!await ownedListener(controller)) { outcome = 'unowned-listener'; return; }
      final headers = web.Headers();
      headers.set('Authorization', authorization);
      headers.set('Accept', 'text/event-stream');
      final response = await web.window.fetch('$base/api/event'.toJS,
        web.RequestInit(headers: headers, signal: controller.signal,
          credentials: 'omit', redirect: 'error')).toDart;
      status = response.status;
      mediaType = response.headers.get('content-type');
      if (status != 200 || mediaType?.startsWith('text/event-stream') != true || response.body == null) {
        fatal = !const [502, 503, 504].contains(status);
        outcome = fatal ? 'invalid-response' : 'transient-response';
        await response.body?.cancel().toDart;
        throw StateError('SSE response rejected');
      }
      reader = web.ReadableStreamDefaultReader(response.body!);
      readerMs = now();
      activeReaders++;
      if (activeReaders > maxActiveReaders) maxActiveReaders = activeReaders;
      bytes = StreamController<List<int>>();
      decoding = bytes.stream.transform(utf8.decoder).forEach((text) {
        pending += text;
        while (pending.contains('\n\n')) {
          final end = pending.indexOf('\n\n');
          final frame = pending.substring(0, end);
          pending = pending.substring(end + 2);
          final data = frame.split('\n').where((s) => s.startsWith('data:'))
              .map((s) => s.substring(5).trimLeft()).join('\n');
          if (data.isEmpty) continue;
          final event = jsonDecode(data) as Map<String, dynamic>;
          if (event['type'] == 'server.connected' ||
              (event['type'] == 'session.renamed' && (event['data'] as Map)['sessionID'] == session)) {
            events.add({'event': event, 'atMs': now(), 'read': chunks.length});
            if (event['type'] == 'server.connected') connected = true;
          }
        }
      }).catchError((Object error) {
        errorType = error.runtimeType.toString(); fatal = true;
        outcome = 'decode-error'; controller.abort();
      });
      while (true) {
        final part = await reader.read().toDart;
        if (part.done) { outcome = 'eof'; break; }
        final chunk = (part.value as JSUint8Array).toDart;
        chunks.add({'bytes': chunk.length, 'atMs': now()});
        bytes.add(chunk);
      }
    } catch (error) {
      errorType = error.runtimeType.toString();
      outcome ??= locallyAborted ? 'local-abort' : 'read-error';
    } finally {
      try { await bytes?.close(); await decoding; }
      finally {
        if (reader != null) {
          reader.releaseLock(); released = true; releasedMs = now(); activeReaders--;
        }
        endedMs = now(); ended = true;
      }
    }
  }
  Map<String, Object?> result() => {'number': number, 'status': status,
    'mediaType': mediaType, 'connected': connected, 'ended': ended,
    'released': released, 'locallyAborted': locallyAborted, 'fatal': fatal,
    'startedMs': startedMs, 'readerMs': readerMs, 'releasedMs': releasedMs,
    'endedMs': endedMs, 'outcome': outcome, 'errorType': errorType,
    'events': events, 'chunks': chunks};
}
