import 'dart:async';
import 'dart:ffi' show Abi;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter_test/flutter_test.dart';

/// Golden references are rendered on x86_64, the CI runner, where a golden
/// passes while at most this share of its pixels differs (0.01%).
const _precisionTolerance = 0.0001;

/// ARM64 rounds antialiased edges differently (#465): text and curves near
/// fractional positions drift by up to about 0.2% of a small golden, as in
/// the composer's chip. Other hosts allow this much; the exact check stays
/// on x86_64 in CI (owner decision, 2026-11-13).
const _crossArchitectureTolerance = 0.003;

final _tolerance =
    const {Abi.linuxX64, Abi.macosX64, Abi.windowsX64}.contains(Abi.current())
    ? _precisionTolerance
    : _crossArchitectureTolerance;

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
    if (result.passed || result.diffPercent <= _tolerance) {
      result.dispose();
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}
