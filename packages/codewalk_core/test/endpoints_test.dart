import 'package:codewalk_core/codewalk_core.dart';
import 'package:test/test.dart';

void main() {
  EndpointProfile profile({
    String id = 'endpoint_one',
    String label = 'Server',
    String path = '/proxy/',
    int revision = 0,
  }) => EndpointProfile(
    id: id,
    label: label,
    endpoint: Uri.parse('https://example.test$path'),
    bindingRevision: revision,
  );

  test('binding keeps identity, full proxy path and generation, not label', () {
    final original = profile();
    expect(original.bindingRevision, 0);
    expect(original.sameBinding(profile(label: 'Renamed')), isTrue);
    expect(original.sameBinding(profile(id: 'endpoint_two')), isFalse);
    expect(original.sameBinding(profile(path: '/other/')), isFalse);
    expect(original.sameBinding(profile(revision: 2)), isFalse);
    expect(original.sameBinding(profile(path: '/proxy')), isTrue);
  });

  test('binding generation is bounded without wrapping around', () {
    expect(
      profile(revision: EndpointProfile.maxBindingRevision).bindingRevision,
      EndpointProfile.maxBindingRevision,
    );
    for (final revision in [-1, EndpointProfile.maxBindingRevision + 1]) {
      expect(() => profile(revision: revision), throwsFormatException);
    }
  });

  test('the harness kind is validated and stays out of the binding', () {
    EndpointProfile kind(String? value) => EndpointProfile(
      id: 'endpoint_one',
      label: 'Server',
      endpoint: Uri.parse('http://127.0.0.1:4096/proxy/'),
      harnessKind: value,
    );
    expect(kind('opencode').harnessKind, 'opencode');
    expect(kind(null).harnessKind, isNull);
    for (final bad in ['', 'OpenCode', '1code', 'open code', 'a' * 33]) {
      expect(() => kind(bad), throwsFormatException, reason: bad);
    }
    expect(kind('opencode').sameBinding(kind('opencode')), isTrue);
    expect(kind('opencode').sameBinding(kind(null)), isTrue);
  });

  test('harness options resolve legacy and coming-soon kinds', () {
    final options = HarnessOptions(const [
      HarnessOption(
        kind: 'alpha',
        displayName: 'Alpha',
        availability: HarnessAvailability.available,
        methods: {HarnessConnectMethod.manualPassword},
      ),
      HarnessOption(
        kind: 'beta',
        displayName: 'Beta',
        availability: HarnessAvailability.comingSoon,
      ),
    ], defaultKind: 'alpha');
    expect(options.defaultOption.kind, 'alpha');
    expect(options.resolve(null)?.kind, 'alpha');
    expect(options.resolve('beta')?.selectable, isFalse);
    expect(options.resolve('gamma'), isNull);
    expect(
      () => HarnessOptions(options.options, defaultKind: 'beta'),
      throwsArgumentError,
    );
    expect(
      () => HarnessOptions(const [
        HarnessOption(
          kind: 'Not A Kind',
          displayName: 'Bad',
          availability: HarnessAvailability.available,
          methods: {HarnessConnectMethod.manualPassword},
        ),
      ], defaultKind: 'Not A Kind'),
      throwsArgumentError,
    );
    expect(
      () => HarnessOptions([
        ...options.options,
        options.options.first,
      ], defaultKind: 'alpha'),
      throwsArgumentError,
    );
  });
}
