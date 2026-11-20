import '../../shared/media/location_fix_source.dart';

LocationFixSource createLocationFixSource() => const _UnsupportedLocationFix();

final class _UnsupportedLocationFix implements LocationFixSource {
  const _UnsupportedLocationFix();

  @override
  bool get supported => false;

  @override
  Future<LocationFixResult> getCurrentLocation({
    Duration timeout = const Duration(seconds: 5),
  }) async => const LocationFixResult.failure(LocationFixOutcome.unavailable);
}
