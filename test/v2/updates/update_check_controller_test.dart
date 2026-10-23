import 'dart:async';
import 'dart:convert';

import 'package:codewalk/features/settings/update_check_controller.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/shared/releases/release_source.dart';
import 'package:codewalk/shared/releases/update_selector.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryBackend implements MetadataBackend {
  final values = <String, Object>{};
  bool failWrite = false;
  @override
  Future<Object?> read(String key) async => values[key];
  @override
  Future<void> write(String key, Object value) async {
    if (failWrite) throw StateError('storage');
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async => values.remove(key);
}

class PendingTask implements ReleaseSourceTask {
  final completion = Completer<ReleaseSourceResult>();
  bool cancelled = false;
  @override
  Future<ReleaseSourceResult> get result => completion.future;
  @override
  void cancel() => cancelled = true;
}

class ControlledSource implements ReleaseSource {
  final tasks = <PendingTask>[];
  bool closed = false;
  @override
  ReleaseSourceTask start() => PendingTask().also(tasks.add);
  @override
  void close() => closed = true;
}

extension<T> on T {
  T also(void Function(T) action) {
    action(this);
    return this;
  }
}

String listing(List<String> tags) => jsonEncode([
  for (final tag in tags)
    {
      'tag_name': tag,
      'draft': false,
      'prerelease': tag.contains('-'),
      'assets': [
        {
          'name': 'codewalk-linux-x64.tar.gz',
          'browser_download_url':
              'https://github.com/verseles/codewalk/releases/download/$tag/codewalk-linux-x64.tar.gz',
        },
      ],
    },
]);

void main() {
  late MemoryBackend backend;
  late ControlledSource source;
  var installed = '2.0.0-beta.1';

  UpdateCheckController controller({
    UpdateTarget? target = UpdateTarget.linuxX64,
  }) => UpdateCheckController(
    source: source,
    store: V2MetadataStore(backend: backend),
    installedVersion: () async => installed,
    target: target,
  );

  setUp(() {
    backend = MemoryBackend();
    source = ControlledSource();
    installed = '2.0.0-beta.1';
  });

  Future<void> answer(String body) async {
    await pumpEventQueue();
    source.tasks.last.completion.complete(ReleaseSourceResult.success(body));
  }

  test('stable is the default and never offers a beta', () async {
    final updates = controller();
    final check = updates.check();
    expect(updates.status, UpdateCheckStatus.checking);
    await answer(listing(['v2.0.0-beta.2']));
    await check;
    expect(updates.channel, UpdateChannel.stable);
    expect(updates.status, UpdateCheckStatus.upToDate);
    expect(updates.installedVersion, '2.0.0-beta.1');
  });

  test('a second tap while checking starts nothing', () async {
    final updates = controller();
    final first = updates.check();
    final second = updates.check();
    await answer(listing(['v2.0.0']));
    await Future.wait([first, second]);
    expect(source.tasks, hasLength(1));
    expect(updates.status, UpdateCheckStatus.available);
  });

  test('the beta opt-in is saved and offers the newest beta', () async {
    final updates = controller();
    await updates.setChannel(UpdateChannel.beta);
    expect(backend.values[UpdateCheckController.channelKey], 'beta');
    final check = updates.check();
    await answer(listing(['v2.0.0-beta.10', 'v2.0.0-beta.2']));
    await check;
    expect(updates.status, UpdateCheckStatus.available);
    expect(updates.candidate?.tag, 'v2.0.0-beta.10');

    final restored = controller();
    await restored.restore();
    expect(restored.channel, UpdateChannel.beta);
  });

  test('an unreadable or unknown saved channel keeps stable', () async {
    backend.values[UpdateCheckController.channelKey] = 42;
    final updates = controller();
    await updates.restore();
    expect(updates.channel, UpdateChannel.stable);
  });

  test('changing channel cancels a check in flight', () async {
    final updates = controller();
    final check = updates.check();
    await pumpEventQueue();
    await updates.setChannel(UpdateChannel.beta);
    expect(source.tasks.single.cancelled, isTrue);
    expect(updates.status, UpdateCheckStatus.idle);
    source.tasks.single.completion.complete(
      ReleaseSourceResult.success(listing(['v2.0.0'])),
    );
    await check;
    expect(updates.status, UpdateCheckStatus.idle);
    expect(updates.candidate, isNull);
  });

  test('a failed source, bad body or unparsable version fails', () async {
    final updates = controller();
    var check = updates.check();
    await pumpEventQueue();
    source.tasks.last.completion.complete(
      const ReleaseSourceResult.failure(ReleaseSourceFailure.timeout),
    );
    await check;
    expect(updates.status, UpdateCheckStatus.failed);

    check = updates.check();
    await answer('{"message":"API rate limit exceeded"}');
    await check;
    expect(updates.status, UpdateCheckStatus.failed);

    installed = 'unknown';
    await updates.check();
    expect(updates.status, UpdateCheckStatus.failed);
  });

  test('a write failure keeps the choice for the session', () async {
    backend.failWrite = true;
    final updates = controller();
    await updates.setChannel(UpdateChannel.beta);
    expect(updates.channel, UpdateChannel.beta);
  });

  test('an unsupported platform never checks', () async {
    final updates = controller(target: null);
    expect(updates.supported, isFalse);
    await updates.check();
    expect(source.tasks, isEmpty);
    expect(updates.status, UpdateCheckStatus.idle);
  });

  test('dispose cancels the check and closes the source', () async {
    final updates = controller();
    final check = updates.check();
    await pumpEventQueue();
    updates.dispose();
    expect(source.tasks.single.cancelled, isTrue);
    expect(source.closed, isTrue);
    source.tasks.single.completion.complete(
      ReleaseSourceResult.success(listing(['v2.0.0'])),
    );
    await check;
  });
}
