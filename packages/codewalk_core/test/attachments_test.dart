import 'package:codewalk_core/codewalk_core.dart';
import 'package:test/test.dart';

void main() {
  group('GeoPoint', () {
    test('accepts boundary coordinates, accuracy, and single-line label', () {
      final point = GeoPoint(
        latitude: -90.0,
        longitude: 180.0,
        accuracyMeters: 0.0,
        label: '  Office\nMain\tGate  ',
      );
      expect(point.latitude, -90.0);
      expect(point.longitude, 180.0);
      expect(point.accuracyMeters, 0.0);
      expect(point.label, 'Office Main Gate');
      expect(
        point,
        GeoPoint(
          latitude: -90.0,
          longitude: 180.0,
          accuracyMeters: 0.0,
          label: 'Office Main Gate',
        ),
      );
    });

    test('rejects invalid coordinates, accuracy, and overly long labels', () {
      expect(() => GeoPoint(latitude: 90.1, longitude: 0), throwsArgumentError);
      expect(
        () => GeoPoint(latitude: -90.1, longitude: 0),
        throwsArgumentError,
      );
      expect(
        () => GeoPoint(latitude: double.nan, longitude: 0),
        throwsArgumentError,
      );
      expect(
        () => GeoPoint(latitude: 0, longitude: 180.1),
        throwsArgumentError,
      );
      expect(
        () => GeoPoint(latitude: 0, longitude: double.infinity),
        throwsArgumentError,
      );
      expect(
        () => GeoPoint(latitude: 0, longitude: 0, accuracyMeters: -1),
        throwsArgumentError,
      );
      expect(
        () => GeoPoint(latitude: 0, longitude: 0, label: 'a' * 201),
        throwsArgumentError,
      );
    });

    test('normalizes blank or control-only labels to null', () {
      expect(
        GeoPoint(latitude: 10, longitude: 20, label: '  \n\t\x00 ').label,
        isNull,
      );
    });
  });

  group('AttachmentRef', () {
    test('preserves optional harness-neutral metadata and equality', () {
      final a = AttachmentRef(
        id: 'att-1',
        mimeType: 'image/png',
        name: 'diagram.png',
        content: OutputRef(id: 'media:${'a' * 64}', sizeBytes: 4096),
        kind: const OpenValue.known(AttachmentKind.image),
        width: 800,
        height: 600,
        availability: const OpenValue.known(AttachmentAvailability.remote),
      );
      final b = AttachmentRef(
        id: 'att-1',
        mimeType: 'image/png',
        name: 'diagram.png',
        content: OutputRef(id: 'media:${'a' * 64}', sizeBytes: 4096),
        kind: const OpenValue.known(AttachmentKind.image),
        width: 800,
        height: 600,
        availability: const OpenValue.known(AttachmentAvailability.remote),
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('rejects path-like, traversal, and raw URI content ids', () {
      for (final bad in [
        '/etc/passwd',
        r'C:\Windows\win.ini',
        '../secret',
        'file:///tmp/a.png',
        'data:image/png;base64,AAAA',
        'https://example.com/a.png',
        'http://127.0.0.1/a',
        'content://media/1',
        'id with space',
        'id\nline',
      ]) {
        expect(
          () => AttachmentRef(
            id: 'att',
            mimeType: 'image/png',
            content: OutputRef(id: bad),
          ),
          throwsArgumentError,
          reason: 'Expected rejection for content.id=$bad',
        );
      }
    });

    test('rejects negative image dimensions', () {
      expect(
        () => AttachmentRef(
          id: 'att',
          mimeType: 'image/png',
          content: OutputRef(id: 'local:abc123'),
          width: -1,
        ),
        throwsArgumentError,
      );
      expect(
        () => AttachmentRef(
          id: 'att',
          mimeType: 'image/png',
          content: OutputRef(id: 'local:abc123'),
          height: -2,
        ),
        throwsArgumentError,
      );
    });

    test('supports location attachments and immutable media bytes', () {
      final point = GeoPoint(
        latitude: -23.5505,
        longitude: -46.6333,
        accuracyMeters: 12.5,
        label: 'São Paulo',
      );
      final ref = AttachmentRef(
        id: 'loc-1',
        mimeType: 'application/geo+json',
        name: 'São Paulo',
        content: OutputRef(id: 'geo:deadbeef'),
        kind: const OpenValue.known(AttachmentKind.location),
        location: point,
      );
      expect(ref.location, point);
      final raw = [1, 2, 3];
      final media = AttachmentMedia(bytes: raw, mimeType: 'audio/mpeg');
      raw[0] = 99;
      expect(media.bytes, [1, 2, 3]);
      expect(() => media.bytes[0] = 5, throwsUnsupportedError);
      expect(AttachmentCapabilities.stageUpload, 'attachments.stageUpload');
      expect(AttachmentCapabilities.mediaRead, 'attachments.mediaRead');
    });
  });
}
