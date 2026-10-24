// V2-042C emulator cells. The production graph pairs with the disposable
// server of tool/ci/v2_device_server.py, sends each scenario's prompt through
// the composer, asks the host to disturb the device and records what the app
// shows. Run only by tool/ci/device_reliability_android.py, which supplies the
// endpoint, the password and the control port.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:codewalk/app/composition_root.dart';
import 'package:codewalk/app/v2_bootstrap.dart';
import 'package:codewalk/features/sessions/session_timeline_tile.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _endpoint = String.fromEnvironment('CW_DEVICE_ENDPOINT');
const _password = String.fromEnvironment('CW_DEVICE_PASSWORD');
const _control = String.fromEnvironment('CW_DEVICE_CONTROL');

/// How long a scenario may take to settle after its disturbance ends.
const _settle = Duration(seconds: 120);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final l10n = lookupV2Localizations(const Locale('en'));

  Future<Map<String, Object?>> control(
    String command, [
    Map<String, Object?> body = const {},
  ]) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse('$_control/$command'));
      request.headers.contentType = ContentType.json;
      // A sized body: the control port does not read a chunked one.
      final bytes = utf8.encode(jsonEncode(body));
      request.contentLength = bytes.length;
      request.add(bytes);
      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
      return (jsonDecode(text) as Map).cast<String, Object?>();
    } finally {
      client.close(force: true);
    }
  }

  testWidgets('V2-042C device reliability cells', (tester) async {
    expect(_endpoint, isNotEmpty, reason: 'run through the device driver');
    final dependencies = await loadAppDependencies(listenNetwork: true);
    await tester.pumpWidget(CodeWalkV2Bootstrap(dependencies: dependencies));
    await tester.pump();

    Future<bool> until(
      bool Function() test, {
      Duration timeout = _settle,
    }) async {
      final deadline = DateTime.now().add(timeout);
      while (DateTime.now().isBefore(deadline)) {
        await tester.pump();
        if (test()) return true;
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      await tester.pump();
      return test();
    }

    String status() {
      final column = find.byKey(const ValueKey('live-status'));
      if (column.evaluate().isEmpty) return '';
      return find
          .descendant(of: column, matching: find.byType(Text))
          .evaluate()
          .map((e) => (e.widget as Text).data ?? '')
          .join(' / ');
    }

    bool live() => status().startsWith(l10n.liveLive);
    bool running() =>
        find.byKey(const ValueKey('live-stop')).evaluate().isNotEmpty;
    // The timeline only: the composer's outbox row repeats a pending prompt.
    int count(String marker) => find
        .descendant(
          of: find.byType(SessionTimelineTile),
          matching: find.textContaining(marker),
        )
        .evaluate()
        .length;
    final unsettled = <String>[];

    // The list's own state, so a cell that does not settle says why.
    Map<String, Object?> catalog() {
      final list = dependencies.sessions!;
      final live = list.liveDiagnostics;
      return {
        'loaded': list.loaded,
        'stale': list.stale,
        'behind': list.behind,
        'failure': list.failure?.name,
        'reconciling': list.reconciling,
        'feed': live.feed,
        'failures': live.failures,
        'suspended': live.suspended,
        'rows': list.sessions.length,
      };
    }

    final endpoint = Uri.parse(_endpoint);
    final hosts = dependencies.hosts;
    await hosts.load();
    final assessment = await hosts.probe(endpoint, _password);
    expect(assessment?.canUse, isTrue, reason: 'the disposable server pairs');
    expect(
      await hosts.add(endpoint, 'Device cells', _password, assessment!),
      isTrue,
    );
    final profile = hosts.profiles.single;
    await dependencies.sessions!.selectProfile(profile.id);

    // The relay's stream log and the host's timestamps are the reconnect
    // evidence: a reconnect can be faster than this view is sampled.
    Future<void> cell(
      String scenario,
      Map<String, Object?> action, {
      required Duration disturbance,
      String slow = 'CW-SLOW',
    }) async {
      final created = await control('create');
      final session = created['session']! as String;
      dependencies.router.go('/s/${profile.id}/$session');
      final opened = await until(live, timeout: const Duration(seconds: 60));
      final marker = '$slow $scenario ${DateTime.now().millisecondsSinceEpoch}';
      await tester.enterText(
        find.byKey(const ValueKey('live-composer-input')),
        marker,
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('live-composer-send')));
      final started = await until(
        running,
        timeout: const Duration(seconds: 30),
      );
      final disturbed = DateTime.now().toUtc();
      final scheduled = await control(action['command']! as String, action);
      // No frame is pumped while the app may be in the background.
      await Future<void>.delayed(disturbance);
      final settled = await until(() => live() && !running());
      final liveAt = DateTime.now().toUtc();
      final record = <String, Object?>{
        'scenario': scenario,
        'session': session,
        'opened_live': opened,
        'turn_started': started,
        'disturbed': disturbed.toIso8601String(),
        'action': scheduled,
        'live_and_idle_at': liveAt.toIso8601String(),
        'settled': settled,
        'prompt_shown': count(marker),
        'status': status(),
        'stuck_running': running(),
        'catalog': catalog(),
      };
      await control('result', record);
      // A turn that never ran was not disturbed: the cell proves nothing.
      if (!started || !settled || count(marker) != 1 || running()) {
        unsettled.add(scenario);
      }
    }

    // The flow cell: send, stop the running turn, then answer a native
    // permission request on the same session. Allow all (the default)
    // answers it by itself; in Ask mode the card's allow action is tapped.
    // The server's pending list is the settlement evidence.
    {
      final created = await control('create');
      final session = created['session']! as String;
      dependencies.router.go('/s/${profile.id}/$session');
      final opened = await until(live, timeout: const Duration(seconds: 60));
      final marker = 'CW-SLOW flow ${DateTime.now().millisecondsSinceEpoch}';
      await tester.enterText(
        find.byKey(const ValueKey('live-composer-input')),
        marker,
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('live-composer-send')));
      final started = await until(
        running,
        timeout: const Duration(seconds: 30),
      );
      if (started) await tester.tap(find.byKey(const ValueKey('live-stop')));
      // Well inside the stub's 30 s answer, so only the stop ends the turn.
      final stopped =
          started &&
          await until(
            () => live() && !running(),
            timeout: const Duration(seconds: 20),
          );
      final asked = await control('permission', {'session': session});
      final allow = find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'live-permission-allow-',
            ),
      );
      var tapped = false;
      var state = const <String, Object?>{};
      final deadline = DateTime.now().add(const Duration(seconds: 60));
      while (DateTime.now().isBefore(deadline)) {
        await tester.pump();
        state = await control('permissions', {'session': session});
        if ((state['pending'] as List?)?.isEmpty ?? false) break;
        if (!tapped && allow.evaluate().isNotEmpty) {
          await tester.tap(allow.first);
          tapped = true;
        }
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      final answered =
          asked['effect'] == 'ask' &&
          ((state['pending'] as List?)?.isEmpty ?? false) &&
          state['saved'] == 0;
      await control('result', {
        'scenario': 'flow',
        'session': session,
        'opened_live': opened,
        'turn_started': started,
        'stopped': stopped,
        'prompt_shown': count(marker),
        'permission': asked,
        'permission_answered': answered,
        'answered_by': tapped ? 'card' : 'allow-all',
        'permission_state': state,
        'status': status(),
      });
      if (!opened || !stopped || count(marker) != 1 || !answered) {
        unsettled.add('flow');
      }
    }

    await cell('drop', {
      'command': 'host/drop',
      'seconds': 15,
    }, disturbance: const Duration(seconds: 18));
    await cell('handover', {
      'command': 'host/handover',
      'seconds': 15,
    }, disturbance: const Duration(seconds: 18));
    await cell(
      'background',
      {'command': 'host/background', 'seconds': 60},
      disturbance: const Duration(seconds: 63),
      slow: 'CW-SLOW90',
    );
    await cell('restart', {
      'command': 'restart',
    }, disturbance: const Duration(seconds: 2));

    // A session another client starts appears in the catalog by itself.
    dependencies.router.go('/');
    await tester.pump();
    final before = catalog();
    final external = await control('session');
    final id = external['session']! as String;
    final appeared = DateTime.now().toUtc();
    final listed = await until(
      () => dependencies.sessions!.sessions.any(
        (row) => row.info.ref.nativeId == id,
      ),
      timeout: const Duration(seconds: 30),
    );
    final listedAt = DateTime.now().toUtc();
    final after = catalog();
    bool? refreshed;
    if (!listed) {
      // Diagnosis only: whether a manual read finds what the feed missed.
      // The cell still fails; nothing here turns it into a pass.
      unawaited(dependencies.sessions!.refresh());
      refreshed = await until(
        () => dependencies.sessions!.sessions.any(
          (row) => row.info.ref.nativeId == id,
        ),
        timeout: const Duration(seconds: 15),
      );
    }
    await control('result', {
      'scenario': 'tui-equivalent',
      'session': id,
      'created': appeared.toIso8601String(),
      'listed': listed,
      'listed_at': listedAt.toIso8601String(),
      'catalog_before': before,
      'catalog_after': after,
      'listed_after_refresh': refreshed,
    });
    if (!listed) unsettled.add('tui-equivalent');
    await tester.pumpWidget(const SizedBox.shrink());
    expect(dependencies.isDisposed, isTrue);
    // Every record is already with the host; a red run marks the cells that
    // did not settle so a green workflow means they all did.
    expect(unsettled, isEmpty, reason: 'cells that did not settle');
  });
}
