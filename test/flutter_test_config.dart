import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter_test/flutter_test.dart';

/// Golden references are rendered on x86_64, the CI runner. ARM64 draws the
/// same frames with antialiasing differences of a few pixels (#465), so a
/// golden passes while at most this share of its pixels differs (0.01%).
/// Larger changes still fail on every architecture.
const _precisionTolerance = 0.0001;

/// The framework installs each test file's comparator before this runs, so
/// the tolerant one only replaces that file's comparator, keeping its folder.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final perFile = goldenFileComparator;
  if (perFile is LocalFileComparator) {
    goldenFileComparator = _ToleranceComparator(
      perFile.basedir.resolve('flutter_test_config.dart'),
    );
  }
  await testMain();
}

class _ToleranceComparator extends LocalFileComparator {
  _ToleranceComparator(super.testFile);

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || result.diffPercent <= _precisionTolerance) {
      result.dispose();
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}
