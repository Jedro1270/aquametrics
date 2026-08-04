import 'dart:math' as math;
import 'dart:typed_data';

import '../models/fish_field.dart';
import 'gray_image.dart';

/// Renders a [FishField] into a pixel buffer: the stand-in for a camera frame.
///
/// The detector is never told where the fish are. It gets pixels, the same as it
/// gets pixels from a photo, and has to find them — which is the only way a
/// simulated frame is worth anything as a test of the counting.
///
/// Geometry mirrors the on-screen render in `widgets/fish_field.dart`, because a
/// marker found here is drawn there and the two have to agree about where a fish
/// is. Brightness values are the luma of the colours that painter uses.
///
/// Pure Dart rather than a canvas: no engine handle, no async, so the whole
/// counting path stays synchronous and testable.
GrayImage rasteriseTray(FishField field, {int width = 720, int noise = 6}) {
  final w = width;
  final h = (width * 3) ~/ 4;
  final base = math.min(w, h).toDouble();
  final luma = Uint8List(w * h);

  _fillWater(luma, w, h);

  for (final spot in field.spots) {
    _drawFish(
      luma,
      w,
      h,
      cx: spot.p.dx * w,
      cy: spot.p.dy * h,
      length: base * field.spacing * FishField.bodyLength * spot.size,
      angle: spot.angle,
      // The painter tints small fish towards the water, so they threshold out
      // first. Same numbers here.
      body: 164.5 + 72.8 * spot.size,
    );
  }

  if (noise > 0) _addNoise(luma, noise);
  return GrayImage(width: w, height: h, luma: luma);
}

/// Radial falloff matching the painter's water gradient, so the detector has to
/// cope with a frame that is brighter in one corner — which every real photo is.
void _fillWater(Uint8List luma, int w, int h) {
  const near = 42.0;
  const far = 18.0;
  final cx = 0.375 * w;
  final cy = 0.275 * h;
  final span = 1.25 * math.min(w, h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final dx = x - cx;
      final dy = y - cy;
      final t = math.min(1.0, math.sqrt(dx * dx + dy * dy) / span);
      luma[y * w + x] = (near + (far - near) * t).round();
    }
  }
}

/// An oval body with a wedge tail and a dark eye, coverage-blended over whatever
/// is already there so overlapping fish read as one bright mass — which is
/// exactly the clump the watershed has to pull apart.
void _drawFish(
  Uint8List luma,
  int w,
  int h, {
  required double cx,
  required double cy,
  required double length,
  required double angle,
  required double body,
}) {
  final cos = math.cos(angle);
  final sin = math.sin(angle);
  final a = length / 2;
  final b = length * 0.34 / 2;
  final reach = length * 0.71;

  final x0 = math.max(0, (cx - reach).floor());
  final x1 = math.min(w - 1, (cx + reach).ceil());
  final y0 = math.max(0, (cy - reach).floor());
  final y1 = math.min(h - 1, (cy + reach).ceil());

  for (var y = y0; y <= y1; y++) {
    for (var x = x0; x <= x1; x++) {
      // Two-by-two supersample. A hard edge would leave the mask jagged and
      // hand the distance transform false peaks along the flank.
      var hits = 0;
      for (var sy = 0; sy < 2; sy++) {
        for (var sx = 0; sx < 2; sx++) {
          final dx = x + 0.25 + sx * 0.5 - cx;
          final dy = y + 0.25 + sy * 0.5 - cy;
          final u = dx * cos + dy * sin;
          final v = -dx * sin + dy * cos;
          if (_inBody(u, v, a, b) || _inTail(u, v, length)) hits++;
        }
      }
      if (hits == 0) continue;
      final i = y * w + x;
      final coverage = hits / 4;
      luma[i] = (luma[i] * (1 - coverage) + body * coverage).round();
    }
  }

  // The eye, as the painter draws it. Left in deliberately: a dark speck inside
  // a bright body is what a fingerling photo actually contains, and the detector
  // has to survive one.
  if (length > 9) {
    final ex = cx + (length * 0.29) * cos - (-length * 0.02) * sin;
    final ey = cy + (length * 0.29) * sin + (-length * 0.02) * cos;
    final r = length * 0.05;
    final ix0 = math.max(0, (ex - r).floor());
    final ix1 = math.min(w - 1, (ex + r).ceil());
    final iy0 = math.max(0, (ey - r).floor());
    final iy1 = math.min(h - 1, (ey + r).ceil());
    for (var y = iy0; y <= iy1; y++) {
      for (var x = ix0; x <= ix1; x++) {
        final dx = x + 0.5 - ex;
        final dy = y + 0.5 - ey;
        if (dx * dx + dy * dy <= r * r) luma[y * w + x] = 19;
      }
    }
  }
}

bool _inBody(double u, double v, double a, double b) =>
    (u * u) / (a * a) + (v * v) / (b * b) <= 1;

bool _inTail(double u, double v, double length) {
  final tip = -0.42 * length;
  final back = -0.70 * length;
  if (u > tip || u < back) return false;
  final spread = 0.19 * length * (tip - u) / (tip - back);
  return v.abs() <= spread;
}

/// Deterministic sensor noise. Fixed seed so a given field always produces the
/// same frame and therefore the same count.
void _addNoise(Uint8List luma, int amplitude) {
  final rnd = math.Random(9161);
  final span = amplitude * 2 + 1;
  for (var i = 0; i < luma.length; i++) {
    luma[i] = (luma[i] + rnd.nextInt(span) - amplitude).clamp(0, 255);
  }
}
