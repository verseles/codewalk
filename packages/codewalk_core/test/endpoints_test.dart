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
}
