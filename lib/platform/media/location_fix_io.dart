import 'dart:async';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../../shared/media/location_fix_source.dart';

LocationFixSource createLocationFixSource() => _NativeLocationFix();

final class _NativeLocationFix implements LocationFixSource {
  _NativeLocationFix();

  bool _unavailable = false;

  @override
  bool get supported => !_unavailable;

  @override
  Future<LocationFixResult> getCurrentLocation({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (_unavailable) {
      return const LocationFixResult.failure(LocationFixOutcome.unavailable);
    }
    try {
      final enabled = await Geolocator.isLocationServiceEnabled().timeout(
        timeout,
      );
      if (!enabled) {
        return const LocationFixResult.failure(
          LocationFixOutcome.serviceDisabled,
        );
      }
      var permission = await Geolocator.checkPermission().timeout(timeout);
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission().timeout(timeout);
      }
      if (permission == LocationPermission.denied) {
        return const LocationFixResult.failure(LocationFixOutcome.denied);
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationFixResult.failure(
          LocationFixOutcome.deniedForever,
        );
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeout,
        ),
      ).timeout(timeout);
      return LocationFixResult.ok(
        GeoPoint(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracyMeters: position.accuracy.isFinite && position.accuracy >= 0
              ? position.accuracy
              : null,
        ),
      );
    } on MissingPluginException {
      _unavailable = true;
      return const LocationFixResult.failure(LocationFixOutcome.unavailable);
    } on PermissionDefinitionsNotFoundException {
      _unavailable = true;
      return const LocationFixResult.failure(LocationFixOutcome.unavailable);
    } on LocationServiceDisabledException {
      return const LocationFixResult.failure(
        LocationFixOutcome.serviceDisabled,
      );
    } on TimeoutException {
      return const LocationFixResult.failure(LocationFixOutcome.timeout);
    } on Object {
      return const LocationFixResult.failure(LocationFixOutcome.failed);
    }
  }
}
