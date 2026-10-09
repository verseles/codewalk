import 'package:codewalk/features/hosts/hosts_controller.dart';
import 'package:codewalk/shared/diagnostics/diagnostics_controller.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../hosts/fakes.dart';

void main() {
  test(
    'committed removal is success even when catalog refresh fails',
    () async {
      final repo = MemoryProfiles();
      final profile = EndpointProfile(
      id: 'endpoint_test',
        label: 'Example',
        endpoint: Uri.parse('https://example.invalid'),
      );
      repo.profiles.add(profile);
      repo.failLoad = true;
      final logs = DiagnosticsController()..setEnabled(true);
      final hosts = HostsController(
        repository: repo,
        prober: FakeProber(),
        diagnostics: logs,
      );
      await hosts.remove(profile);
      expect(repo.profiles, isEmpty);
      expect(hosts.storageError, isTrue);
      expect(logs.events.map((e) => (e.operation, e.outcome)), [
        (DiagnosticOperation.profileRemove, DiagnosticOutcome.success),
        (DiagnosticOperation.hostCatalogLoad, DiagnosticOutcome.failure),
      ]);
      hosts.dispose();
      logs.dispose();
    },
  );
}
