import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// A single-channel 8-bit image: the only thing the detector needs.
///
/// Colour buys nothing here. Fingerlings read as pale bodies against dark water
/// whatever the water is tinted, so brightness alone separates them and costs a
/// quarter of the memory to walk.
@immutable
class GrayImage {
  const GrayImage({
    required this.width,
    required this.height,
    required this.luma,
  });

  final int width;
  final int height;

  /// Row-major, `width * height` bytes.
  final Uint8List luma;

  int get length => width * height;

  int at(int x, int y) => luma[y * width + x];

  /// Rec. 601 luma from a packed RGBA buffer, as `ui.Image.toByteData` and
  /// camera plugins both hand it over.
  factory GrayImage.fromRgba(Uint8List rgba, int width, int height) {
    final luma = Uint8List(width * height);
    for (var i = 0, o = 0; i < luma.length; i++, o += 4) {
      // 77/150/29 over 256 is the integer form of 0.299/0.587/0.114.
      luma[i] = (rgba[o] * 77 + rgba[o + 1] * 150 + rgba[o + 2] * 29) >> 8;
    }
    return GrayImage(width: width, height: height, luma: luma);
  }

  /// Box-averaged downsample by an integer [factor].
  ///
  /// Averaging rather than dropping pixels: a nearest-neighbour shrink turns a
  /// thin fish into a dotted line, and the detector would then split one fish
  /// into several blobs.
  GrayImage downsampled(int factor) {
    if (factor <= 1) return this;
    final w = width ~/ factor;
    final h = height ~/ factor;
    final out = Uint8List(w * h);
    final cells = factor * factor;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        var sum = 0;
        for (var dy = 0; dy < factor; dy++) {
          var row = (y * factor + dy) * width + x * factor;
          for (var dx = 0; dx < factor; dx++) {
            sum += luma[row++];
          }
        }
        out[y * w + x] = sum ~/ cells;
      }
    }
    return GrayImage(width: w, height: h, luma: out);
  }

  /// Centre crop to [aspect] (width over height).
  ///
  /// Frames are shown in a 4:3 box with `BoxFit.cover`, which centre-crops in
  /// exactly this way. Analysing the same crop is what keeps a marker on the
  /// fish it was found on.
  GrayImage croppedToAspect(double aspect) {
    var w = width;
    var h = height;
    if (width / height > aspect) {
      w = math.max(1, (height * aspect).round());
    } else {
      h = math.max(1, (width / aspect).round());
    }
    if (w == width && h == height) return this;

    final x0 = (width - w) ~/ 2;
    final y0 = (height - h) ~/ 2;
    final out = Uint8List(w * h);
    for (var y = 0; y < h; y++) {
      final src = (y0 + y) * width + x0;
      out.setRange(y * w, y * w + w, luma, src);
    }
    return GrayImage(width: w, height: h, luma: out);
  }
}
