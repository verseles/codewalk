import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_svg/flutter_svg.dart';

import 'project_icon_models.dart';

/// Samples the rendered artwork, including SVG gradients and transparency.
/// A failed or empty image has no palette and retains the normal tab colors.
Future<ui.Color?> extractProjectIconColor(ProjectIconData icon) async {
  if (icon.bytes.isEmpty || icon.bytes.length > projectIconMaxBytes) {
    return null;
  }
  ui.Image? image;
  try {
    if (icon.metadata.storedFormat == ProjectIconFormat.svg) {
      final info = await vg.loadPicture(SvgBytesLoader(icon.bytes), null);
      try {
        final size = info.size;
        if (!size.width.isFinite || !size.height.isFinite || size.isEmpty) {
          return null;
        }
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        final scale = 48 / math.max(size.width, size.height);
        canvas.scale(scale);
        canvas.drawPicture(info.picture);
        final picture = recorder.endRecording();
        try {
          image = await picture.toImage(
            math.max(1, (size.width * scale).ceil()),
            math.max(1, (size.height * scale).ceil()),
          );
        } finally {
          picture.dispose();
        }
      } finally {
        info.picture.dispose();
      }
    } else {
      final buffer = await ui.ImmutableBuffer.fromUint8List(icon.bytes);
      try {
        final descriptor = await ui.ImageDescriptor.encoded(buffer);
        try {
          if (descriptor.width <= 0 ||
              descriptor.height <= 0 ||
              descriptor.width * descriptor.height > 16000000) {
            return null;
          }
          final scale = math.min(
            1.0,
            48 / math.max(descriptor.width, descriptor.height),
          );
          final codec = await descriptor.instantiateCodec(
            targetWidth: math.max(1, (descriptor.width * scale).round()),
            targetHeight: math.max(1, (descriptor.height * scale).round()),
          );
          try {
            image = (await codec.getNextFrame()).image;
          } finally {
            codec.dispose();
          }
        } finally {
          descriptor.dispose();
        }
      } finally {
        buffer.dispose();
      }
    }
    final pixels = await image.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    );
    return pixels == null ? null : dominantProjectIconColor(pixels);
  } catch (_) {
    return null;
  } finally {
    image?.dispose();
  }
}

/// Favor the visible artwork color over dark outlines and neutral backgrounds.
ui.Color? dominantProjectIconColor(ByteData pixels) {
  final coloredBuckets = <int, List<int>>{};
  final darkColoredBuckets = <int, List<int>>{};
  final neutralBuckets = <int, List<int>>{};
  for (var i = 0; i + 3 < pixels.lengthInBytes; i += 4) {
    final alpha = pixels.getUint8(i + 3);
    if (alpha < 16) continue;
    final r = pixels.getUint8(i);
    final g = pixels.getUint8(i + 1);
    final b = pixels.getUint8(i + 2);
    final brightest = math.max(r, math.max(g, b));
    final chroma = (brightest - math.min(r, math.min(g, b))).toInt();
    final colored = chroma >= 28;
    final key = ((r >> 4) << 8) | ((g >> 4) << 4) | (b >> 4);
    final buckets = colored
        ? (brightest >= 48 ? coloredBuckets : darkColoredBuckets)
        : neutralBuckets;
    final bucket = buckets.putIfAbsent(key, () => [0, 0, 0, 0, 0]);
    final brightnessWeight = 16 + (brightest * brightest >> 8);
    bucket[0] +=
        alpha * (colored ? chroma * brightnessWeight : brightnessWeight);
    bucket[1] += alpha;
    bucket[2] += r * alpha;
    bucket[3] += g * alpha;
    bucket[4] += b * alpha;
  }
  List<int>? winner;
  final hasColor = coloredBuckets.isNotEmpty || darkColoredBuckets.isNotEmpty;
  final candidates = coloredBuckets.isNotEmpty
      ? coloredBuckets
      : darkColoredBuckets.isNotEmpty
      ? darkColoredBuckets
      : neutralBuckets;
  for (final bucket in candidates.values) {
    if (winner == null || bucket[0] > winner[0]) winner = bucket;
  }
  if (winner == null) return null;
  var r = (winner[2] / winner[1]).round();
  var g = (winner[3] / winner[1]).round();
  var b = (winner[4] / winner[1]).round();
  if (!hasColor) {
    final neutral = math.max(128, math.max(r, math.max(g, b)));
    return ui.Color.fromARGB(255, neutral, neutral, neutral);
  }
  final brightest = math.max(r, math.max(g, b));
  if (brightest < 192) {
    final scale = 192 / brightest;
    r = (r * scale).round();
    g = (g * scale).round();
    b = (b * scale).round();
  }
  return ui.Color.fromARGB(255, r, g, b);
}
