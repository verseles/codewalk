import 'package:codewalk_core/codewalk_core.dart';

class MemoryProfiles implements EndpointProfileRepository {
  final profiles = <EndpointProfile>[];
  final secrets = <String, String>{};
  bool failSave = false;
  bool failLoad = false;
  @override
  Future<List<EndpointProfile>> load() async {
    if (failLoad) throw StateError('controlled catalog read failure');
    return List.of(profiles);
  }

  @override
  Future<void> save(EndpointProfile profile, String secret) async {
    if (failSave) throw StateError('controlled persistence failure');
    profiles.add(profile);
    secrets[profile.id] = secret;
  }

  @override
  Future<String?> readSecret(EndpointProfile profile) async =>
      secrets[profile.id];
  @override
  Future<void> remove(EndpointProfile profile) async {
    profiles.removeWhere((p) => p.id == profile.id);
    secrets.remove(profile.id);
  }
}

class FakeProber implements EndpointProber {
  EndpointAssessment assessment = const EndpointAssessment(
    EndpointStatus.compatible,
    version: '2.0.22',
  );
  final tasks = <FakeProbeTask>[];
  Future<EndpointAssessment>? pendingResult;
  @override
  EndpointProbeTask start(Uri endpoint, String secret) {
    final task = FakeProbeTask(pendingResult ?? Future.value(assessment));
    tasks.add(task);
    return task;
  }
}

class FakeProbeTask implements EndpointProbeTask {
  FakeProbeTask(this.result);
  @override
  final Future<EndpointAssessment> result;
  bool cancelled = false;
  @override
  void cancel() {
    cancelled = true;
  }
}
