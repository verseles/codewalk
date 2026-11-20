import 'package:codewalk_core/codewalk_core.dart';

enum LocationFixOutcome {
  ok,
  denied,
  deniedForever,
  serviceDisabled,
  unavailable,
  timeout,
  failed,
}

final class LocationFixResult {
  const LocationFixResult.ok(GeoPoint this.point)
    : outcome = LocationFixOutcome.ok;
  const LocationFixResult.failure(this.outcome)
    : assert(outcome != LocationFixOutcome.ok),
      point = null;

  final LocationFixOutcome outcome;
  final GeoPoint? point;
}

/// Optional platform GPS/location reader behind a clean port. Manual
/// coordinate entry always stays available when this returns unavailable/denied.
abstract interface class LocationFixSource {
  bool get supported;
  Future<LocationFixResult> getCurrentLocation({
    Duration timeout = const Duration(seconds: 5),
  });
}
