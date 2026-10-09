import 'package:codewalk_core/codewalk_core.dart';
import 'package:pub_semver/pub_semver.dart';

/// Approved compatibility table; a supported minimum is not proof of testing.
final class OpenCodeCompatibility {
  static final minimum = Version(2, 0, 20);
  static const tested = ['2.0.21', '2.0.22'];
  static const knownBad = <String>[];

  static Version? parse(String value) {
    if (value.length > 128) return null;
    final match = RegExp(
      r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)'
      r'(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?'
      r'(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$',
    ).firstMatch(value);
    if (match == null) return null;
    if (match
            .group(4)
            ?.split('.')
            .any(
              (part) =>
                  part.length > 1 &&
                  part.startsWith('0') &&
                  RegExp(r'^\d+$').hasMatch(part),
            ) ??
        false) {
      return null;
    }
    try {
      // Validate the complete input before dropping its build suffix.
      Version.parse(value);
      // Pub orders build suffixes; support/test status must ignore build metadata.
      return Version.parse(value.split('+').first);
    } on FormatException {
      return null;
    }
  }

  static EndpointAssessment assess(String value) {
    final version = parse(value);
    if (version == null) {
      return const EndpointAssessment(EndpointStatus.unrecognized);
    }
    if (version < minimum || knownBad.contains(version.toString())) {
      return EndpointAssessment(EndpointStatus.belowMinimum, version: value);
    }
    return EndpointAssessment(
      tested.contains(version.toString())
          ? EndpointStatus.compatible
          : EndpointStatus.untested,
      version: value,
    );
  }
}
