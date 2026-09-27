import 'dart:convert';
import 'dart:typed_data';

import 'package:codewalk/presentation/services/project_icon_models.dart';
import 'package:codewalk/presentation/services/project_icon_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import '../../support/project_icon_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('dominant pixels ignore hidden RGB and weight straight alpha', () {
    final bytes = Uint8List.fromList([
      255,
      0,
      0,
      255,
      255,
      0,
      0,
      255,
      0,
      0,
      255,
      255,
      0,
      255,
      0,
      0,
      0,
      255,
      0,
      8,
      0,
      255,
      0,
      8,
    ]);
    expect(
      dominantProjectIconColor(ByteData.sublistView(bytes)),
      const Color(0xffff0000),
    );
    expect(dominantProjectIconColor(ByteData(16)), isNull);
    expect(
      dominantProjectIconColor(
        ByteData.sublistView(Uint8List.fromList([128, 128, 128, 128])),
      ),
      const Color(0xff808080),
    );
  });

  test('PNG samples actual artwork and transparency', () async {
    final image = img.Image(width: 96, height: 48, numChannels: 4);
    img.fill(image, color: img.ColorRgba8(0, 0, 255, 0));
    img.fillRect(
      image,
      x1: 30,
      y1: 10,
      x2: 70,
      y2: 40,
      color: img.ColorRgba8(255, 0, 0, 255),
    );
    final color = await extractProjectIconColor(
      paletteIcon(img.encodePng(image)),
    );
    expect(color, isNotNull);
    expect(color!.r, greaterThan(0.9));
    expect(color.b, lessThan(0.1));
  });

  test(
    'SVG fits large viewBox including artwork away from the origin',
    () async {
      final color = await extractProjectIconColor(
        paletteIcon(
          utf8.encode(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1000 500">'
            '<rect x="500" y="100" width="300" height="300" fill="#00ff00"/>'
            '</svg>',
          ),
          format: ProjectIconFormat.svg,
        ),
      );
      expect(color, const Color(0xff00ff00));
    },
  );

  test(
    'malformed, empty and oversized artwork fails without a palette',
    () async {
      expect(await extractProjectIconColor(paletteIcon([1, 2, 3])), isNull);
      expect(await extractProjectIconColor(paletteIcon([])), isNull);
      expect(
        await extractProjectIconColor(
          paletteIcon(Uint8List(projectIconMaxBytes + 1)),
        ),
        isNull,
      );
    },
  );
}
