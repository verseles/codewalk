import 'package:codewalk/features/sessions/session_live_controller.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'fakes.dart';
import 'live_fakes.dart';

void main() {
  late CatalogRig rig;
  late LiveDirectory directory;
  late SessionLiveController controller;
  late SessionRef ref;
  setUp(() async {
    rig = CatalogRig();
    await rig.save('a');
    await rig.sessions.initialize();
    directory = LiveDirectory();
    final summary = CatalogSource(profile('a')).row('one');
    ref = summary.info.ref;
    controller = SessionLiveController(
      hosts: rig.hosts,
      profile: profile('a'),
      summary: summary,
      directory: directory,
    );
  });
  tearDown(() {
    controller.dispose();
    rig.dispose();
  });

  test(
    'opens one lease with the saved credential and follows its views',
    () async {
      final opening = controller.start();
      expect(controller.loading, isTrue);
      expect(directory.credentials.single.secret, 'fake-a');
      final handle = directory.grant(ref);
      await opening;
      await pumpEventQueue();
      expect(controller.phase, SessionLivePhase.connecting);
      handle.emit(
        SessionLiveView(
          session: ref,
          phase: SessionLivePhase.live,
          state: liveState(ref),
        ),
      );
      await pumpEventQueue();
      expect(controller.phase, SessionLivePhase.live);
      expect(controller.loading, isFalse);
      expect(controller.canRetry, isFalse);
      expect(controller.state, isNotNull);
      controller.dispose();
      expect(handle.closes, 1);
    },
  );

  test('terminal failures can retry; a live view cannot', () async {
    final opening = controller.start();
    directory.fail(SessionLiveFailure.capacity);
    await opening;
    expect(controller.failure, SessionLiveFailure.capacity);
    expect(controller.canRetry, isTrue);
    final retry = controller.retry();
    expect(directory.opens, hasLength(2));
    final handle = directory.grant(ref);
    await retry;
    handle.emit(SessionLiveView(session: ref, phase: SessionLivePhase.live));
    await pumpEventQueue();
    expect(controller.failure, isNull);
    expect(controller.canRetry, isFalse);
    await controller.retry();
    expect(directory.opens, hasLength(2));
    handle.emit(
      SessionLiveView(session: ref, phase: SessionLivePhase.degraded),
    );
    await pumpEventQueue();
    expect(controller.canRetry, isTrue);
  });

  test(
    'a lease granted after dispose or restart is closed, not adopted',
    () async {
      final first = controller.start();
      final second = controller.start();
      directory.opens.first.complete(LiveHandle(ref));
      await first;
      final late = directory.opens.first.future;
      expect((await late as LiveHandle).closes, 1);
      final handle = directory.grant(ref);
      await second;
      expect(handle.closes, 0);
      controller.dispose();
      expect(handle.closes, 1);
    },
  );

  test('a lease for another session is rejected', () async {
    final opening = controller.start();
    final foreign = directory.grant(
      SessionRef(ref.host, ref.harness, 'ses_other'),
    );
    await opening;
    expect(foreign.closes, 1);
    expect(controller.failure, SessionLiveFailure.incompatibleResponse);
  });

  test('removing the credential detaches the lease', () async {
    final opening = controller.start();
    final handle = directory.grant(ref);
    await opening;
    await rig.hosts.remove(rig.hosts.profiles.single);
    await pumpEventQueue();
    expect(handle.closes, 1);
    expect(controller.view, isNull);
    expect(controller.failure, SessionLiveFailure.authenticationRequired);
  });

  test('no credential fails before opening anything', () async {
    await rig.hosts.remove(rig.hosts.profiles.single);
    await controller.start();
    expect(directory.opens, isEmpty);
    expect(controller.failure, SessionLiveFailure.authenticationRequired);
  });
}
