import 'package:codewalk_core/codewalk_core.dart';
import 'package:pub_semver/pub_semver.dart';

/// Approved compatibility table: every stable v2 release from the minimum on
/// is usable, so the app never argues about newer server versions (#507).
final class OpenCodeCompatibility {
  static final minimum = Version(2, 0, 20);
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

  /// Permits the v2 protocol for every stable release from the minimum on.
  static bool supportsV2(String value) {
    final version = parse(value);
    return version != null &&
        version.major == 2 &&
        version.preRelease.isEmpty &&
        version >= minimum &&
        !knownBad.contains(version.toString());
  }

  static EndpointAssessment assess(String value) {
    final version = parse(value);
    if (version == null) {
      return const EndpointAssessment(EndpointStatus.unrecognized);
    }
    if (version < minimum || knownBad.contains(version.toString())) {
      return EndpointAssessment(EndpointStatus.belowMinimum, version: value);
    }
    if (!supportsV2(value)) {
      return EndpointAssessment(EndpointStatus.unrecognized, version: value);
    }
    return EndpointAssessment(EndpointStatus.compatible, version: value);
  }
}
