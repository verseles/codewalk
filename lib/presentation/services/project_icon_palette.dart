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

/// Alpha-weighted quantization avoids averaging distinct hues into a new one.
ui.Color? dominantProjectIconColor(ByteData pixels) {
  final buckets = <int, List<int>>{};
  for (var i = 0; i + 3 < pixels.lengthInBytes; i += 4) {
    final alpha = pixels.getUint8(i + 3);
    if (alpha < 16) continue;
    final r = pixels.getUint8(i);
    final g = pixels.getUint8(i + 1);
    final b = pixels.getUint8(i + 2);
    final key = ((r >> 4) << 8) | ((g >> 4) << 4) | (b >> 4);
    final bucket = buckets.putIfAbsent(key, () => [0, 0, 0, 0]);
    bucket[0] += alpha;
    bucket[1] += r * alpha;
    bucket[2] += g * alpha;
    bucket[3] += b * alpha;
  }
  List<int>? winner;
  for (final bucket in buckets.values) {
    if (winner == null || bucket[0] > winner[0]) winner = bucket;
  }
  if (winner == null) return null;
  return ui.Color.fromARGB(
    255,
    (winner[1] / winner[0]).round(),
    (winner[2] / winner[0]).round(),
    (winner[3] / winner[0]).round(),
  );
}
