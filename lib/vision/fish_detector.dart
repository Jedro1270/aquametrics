import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';

import 'gray_image.dart';

/// What to count, and how eagerly.
@immutable
class DetectorRequest {
  const DetectorRequest({required this.image, this.sensitivity = 0.5});

  final GrayImage image;

  /// 0..1. Drives the real knobs — where the threshold sits relative to Otsu's
  /// split, and how much of a fish has to be visible to count as one — so moving
  /// it re-runs the detector rather than filtering a fixed answer.
  final double sensitivity;
}

/// What the detector found. Positions are normalised to 0..1 against the frame
/// it was given, so they survive being drawn at any size.
@immutable
class DetectorResult {
  const DetectorResult({
    required this.fish,
    required this.ringRadius,
    required this.threshold,
  });

  const DetectorResult.empty()
    : fish = const [],
      ringRadius = 0.02,
      threshold = 0;

  final List<Offset> fish;

  /// Radius to draw a marker at, in short-side units, measured from the fish the
  /// detector actually found rather than assumed. Hit testing reads this too.
  final double ringRadius;

  /// The luma cut-off used, kept for diagnostics.
  final int threshold;

  int get count => fish.length;
}

/// How far the sensitivity slider may push the threshold away from Otsu's
/// split, as a fraction of the gap between water and fish brightness.
const _thresholdSwing = 0.5;

/// Smallest surviving blob, as a fraction of the typical fish, at each end of
/// the slider. Strict drops anything half-hidden; inclusive keeps slivers.
const _minAreaStrict = 0.80;
const _minAreaInclusive = 0.08;

/// Saddle depth needed to call two peaks two fish, as a fraction of the typical
/// fish half-width. Below this the two peaks are treated as one body — which is
/// what stops the long spine of a single fish being split down the middle.
///
/// This is the other end of the slider: strict wants a deep notch before it will
/// call a clump two fish, inclusive settles for a shallow one. It is the honest
/// version of "inclusive catches more but can double-count a clump".
const _saddleStrict = 1.25;
const _saddleInclusive = 0.50;

/// Blobs below this many pixels are sensor noise at any sensitivity.
const _noiseFloor = 6;

/// Otsu always returns a split, even given a frame with nothing in it — point the
/// camera at bare water and it will happily divide the ripples into "fish" and
/// "not fish". Two sanity checks stand between that and a wildly wrong count:
/// fingerlings are much paler than the water they are in, and they never cover
/// half the frame. A frame failing either counts as nothing found.
const _minContrast = 25.0;
const _maxCoverage = 0.45;

/// Ring size reported when there was nothing to measure one from.
const _fallbackRing = 0.02;

/// Counts fingerlings in a frame.
///
/// Otsu's threshold separates pale bodies from dark water, a 3x3 opening clears
/// speckle, an exact Euclidean distance transform finds the spine of every body,
/// and a marker-controlled watershed seeded from the h-maxima of that transform
/// splits a clump into one region per fish.
///
/// Pure and synchronous by design: it holds no engine handles, so it can be
/// handed to [compute] and run off the UI isolate.
DetectorResult detectFingerlings(DetectorRequest request) {
  final image = request.image;
  final w = image.width;
  final h = image.height;
  final n = w * h;
  if (n == 0) return const DetectorResult.empty();

  final sensitivity = request.sensitivity.clamp(0.0, 1.0);

  // Flat-field correction: estimate the local background with a box filter
  // larger than any fish, then subtract it. This normalises uneven lighting
  // and shadows — the biggest source of error on real photographs, where a
  // global threshold can't tell a dark fish from a shadow. After correction
  // the background sits near 128 everywhere and fish stand out at the
  // extremes, so a single Otsu cut on the corrected image is enough.
  final window = math.max(30, math.min(w, h) ~/ 8);
  final corrected = _flatField(image.luma, w, h, window);

  final split = _split(corrected, n, w, h, sensitivity);
  final nothing = DetectorResult(
    fish: const [],
    ringRadius: _fallbackRing,
    threshold: split.cut,
  );
  if (split.contrast < _minContrast) return nothing;

  var mask = Uint8List(n);
  var covered = 0;
  for (var i = 0; i < n; i++) {
    final isFish =
        split.darkFish ? corrected[i] < split.cut : corrected[i] > split.cut;
    if (isFish) {
      mask[i] = 1;
      covered++;
    }
  }
  if (covered > n * _maxCoverage) return nothing;
  mask = _opened(mask, w, h);

  final dist = _distanceTransform(mask, w, h);
  final basins = _watershed(mask, dist, w, h, sensitivity);
  final solid = basins.where((b) => b.area >= _noiseFloor).toList();
  if (solid.isEmpty) return nothing;

  final unitArea = _median([for (final b in solid) b.area.toDouble()]);
  final minArea =
      unitArea *
      (_minAreaStrict + (_minAreaInclusive - _minAreaStrict) * sensitivity);
  final kept = solid.where((b) => b.area >= minArea).toList();
  if (kept.isEmpty) return nothing;

  final shortSide = math.min(w, h);
  return DetectorResult(
    fish: [
      for (final b in kept) Offset(b.cx / w, b.cy / h),
    ],
    ringRadius: _ringRadius(kept, shortSide),
    threshold: split.cut,
  );
}

/// Otsu's split, biased by the slider, along with how far apart the two sides of
/// it actually are and which side the fish are on.
///
/// The bias is scaled by the distance between the two class means rather than
/// being a fixed number of luma steps, so one notch of the slider means the same
/// thing in flat overcast light as it does in hard sun.
///
/// Polarity is decided by the frame border, not by population: a tray fills the
/// photo edge to edge, so whichever side of the cut dominates the border is the
/// background, and the other side is the fish. This is robust where the
/// minority-class heuristic is not — a dense tray can have fish covering half
/// the frame, making "the smaller class" a coin flip, but the border still
/// belongs to the tray.
({int cut, double contrast, bool darkFish}) _split(
  Uint8List luma,
  int n,
  int w,
  int h,
  double sensitivity,
) {
  final histogram = Int32List(256);
  for (var i = 0; i < n; i++) {
    histogram[luma[i]]++;
  }

  var total = 0.0;
  for (var v = 0; v < 256; v++) {
    total += histogram[v] * v.toDouble();
  }

  var belowWeight = 0.0;
  var belowSum = 0.0;
  var best = -1.0;
  var split = 0;
  for (var v = 0; v < 255; v++) {
    belowWeight += histogram[v];
    if (belowWeight == 0) continue;
    belowSum += histogram[v] * v.toDouble();
    final aboveWeight = n - belowWeight;
    if (aboveWeight == 0) break;
    final gap = belowSum / belowWeight - (total - belowSum) / aboveWeight;
    final variance = belowWeight * aboveWeight * gap * gap;
    if (variance > best) {
      best = variance;
      split = v;
    }
  }

  belowWeight = 0;
  belowSum = 0;
  for (var v = 0; v <= split; v++) {
    belowWeight += histogram[v];
    belowSum += histogram[v] * v.toDouble();
  }
  if (belowWeight == 0 || belowWeight == n) {
    return (cut: split, contrast: 0, darkFish: false);
  }
  final water = belowSum / belowWeight;
  final fish = (total - belowSum) / (n - belowWeight);
  final contrast = (fish - water).abs();

  // The class that dominates the frame border is the background; the other is
  // the fish. A tray fills the photo edge to edge, so this holds even when fish
  // cover nearly half the frame — where the minority-class heuristic would flip.
  var borderDark = 0;
  var borderBright = 0;
  for (var x = 0; x < w; x++) {
    if (luma[x] <= split) {
      borderDark++;
    } else {
      borderBright++;
    }
    if (luma[(h - 1) * w + x] <= split) {
      borderDark++;
    } else {
      borderBright++;
    }
  }
  for (var y = 1; y < h - 1; y++) {
    if (luma[y * w] <= split) {
      borderDark++;
    } else {
      borderBright++;
    }
    if (luma[y * w + w - 1] <= split) {
      borderDark++;
    } else {
      borderBright++;
    }
  }
  final darkFish = borderBright > borderDark;

  final bias = (sensitivity - 0.5) * _thresholdSwing * contrast;
  // For pale fish, raising sensitivity lowers the cut so more pixels clear
  // `luma > cut`. For dark fish, the mask is `luma < cut`, so the cut has to
  // move the other way to let more pixels in.
  var cut = (split + (darkFish ? bias : -bias)).round().clamp(0, 255);

  // The inclusive end of the slider can push the cut so far that the fish
  // class swallows the background — a dense real tray then trips the coverage
  // guard and the count collapses to nothing. Cap the cut at the most
  // inclusive value that keeps the fish class under [_maxCoverage], so the
  // slider saturates instead of self-destructing. The cap never crosses the
  // Otsu split: a tray that dense at the balanced point is left for the
  // coverage guard to judge.
  final prefix = Int32List(257);
  for (var v = 0; v < 256; v++) {
    prefix[v + 1] = prefix[v] + histogram[v];
  }
  final cap = (_maxCoverage * n).floor();
  if (darkFish) {
    // Fish are `luma < cut`; raising the cut is the inclusive direction.
    while (cut > split && prefix[cut] > cap) {
      cut--;
    }
  } else {
    // Fish are `luma > cut`; lowering the cut is the inclusive direction.
    while (cut < split && (n - prefix[cut + 1]) > cap) {
      cut++;
    }
  }
  return (cut: cut, contrast: contrast, darkFish: darkFish);
}

/// Flat-field correction: subtracts a local background estimate so that fish
/// stand out from their immediate surroundings regardless of uneven lighting or
/// shadows.
///
/// The background is a box filter with a window larger than any fish, computed
/// as a separable running average with edge clamping. After subtraction the
/// background centres near 128 and fish sit at the extremes, which is what the
/// Otsu split needs to find a clean cut.
Uint8List _flatField(Uint8List luma, int w, int h, int window) {
  final half = window ~/ 2;

  // Horizontal pass: running average over a window of `window` pixels, with the
  // window clamped at the edges so border pixels average over fewer samples
  // rather than wrapping or zero-padding.
  final horiz = Float32List(w * h);
  final prefix = Float64List(w + 1);
  for (var y = 0; y < h; y++) {
    final o = y * w;
    prefix[0] = 0;
    for (var x = 0; x < w; x++) {
      prefix[x + 1] = prefix[x] + luma[o + x];
    }
    for (var x = 0; x < w; x++) {
      final x0 = math.max(0, x - half);
      final x1 = math.min(w - 1, x + half);
      horiz[o + x] = (prefix[x1 + 1] - prefix[x0]) / (x1 - x0 + 1);
    }
  }

  // Vertical pass on the horizontally-averaged image.
  final out = Uint8List(w * h);
  final colPrefix = Float64List(h + 1);
  for (var x = 0; x < w; x++) {
    colPrefix[0] = 0;
    for (var y = 0; y < h; y++) {
      colPrefix[y + 1] = colPrefix[y] + horiz[y * w + x];
    }
    for (var y = 0; y < h; y++) {
      final y0 = math.max(0, y - half);
      final y1 = math.min(h - 1, y + half);
      final bg = (colPrefix[y1 + 1] - colPrefix[y0]) / (y1 - y0 + 1);
      final i = y * w + x;
      out[i] = (luma[i] - bg + 128).round().clamp(0, 255);
    }
  }
  return out;
}

/// 3x3 opening: erode, then dilate. Separable because a square structuring
/// element is, which keeps it two cheap passes per step instead of nine.
Uint8List _opened(Uint8List mask, int w, int h) =>
    _dilate(_erode(mask, w, h), w, h);

Uint8List _erode(Uint8List mask, int w, int h) {
  final rows = Uint8List(w * h);
  for (var y = 0; y < h; y++) {
    final o = y * w;
    for (var x = 0; x < w; x++) {
      final left = x > 0 ? mask[o + x - 1] : 0;
      final right = x < w - 1 ? mask[o + x + 1] : 0;
      rows[o + x] = (mask[o + x] & left & right);
    }
  }
  final out = Uint8List(w * h);
  for (var y = 0; y < h; y++) {
    final o = y * w;
    for (var x = 0; x < w; x++) {
      final up = y > 0 ? rows[o - w + x] : 0;
      final down = y < h - 1 ? rows[o + w + x] : 0;
      out[o + x] = (rows[o + x] & up & down);
    }
  }
  return out;
}

Uint8List _dilate(Uint8List mask, int w, int h) {
  final rows = Uint8List(w * h);
  for (var y = 0; y < h; y++) {
    final o = y * w;
    for (var x = 0; x < w; x++) {
      final left = x > 0 ? mask[o + x - 1] : 0;
      final right = x < w - 1 ? mask[o + x + 1] : 0;
      rows[o + x] = (mask[o + x] | left | right);
    }
  }
  final out = Uint8List(w * h);
  for (var y = 0; y < h; y++) {
    final o = y * w;
    for (var x = 0; x < w; x++) {
      final up = y > 0 ? rows[o - w + x] : 0;
      final down = y < h - 1 ? rows[o + w + x] : 0;
      out[o + x] = (rows[o + x] | up | down);
    }
  }
  return out;
}

/// Exact Euclidean distance from every set pixel to the nearest clear one, by
/// Felzenszwalb and Huttenlocher's lower-envelope method: two linear passes
/// rather than the chamfer approximation, because the peak of this surface is
/// what tells one fish from two.
///
/// Everything outside the frame counts as water, so a fish cut off by the edge
/// is not mistaken for a very thick one.
Float32List _distanceTransform(Uint8List mask, int w, int h) {
  const far = 1e20;
  final span = math.max(w, h);
  final f = Float64List(span);
  final d = Float64List(span);
  final v = Int32List(span);
  final z = Float64List(span + 1);
  final squared = Float64List(w * h);

  for (var x = 0; x < w; x++) {
    for (var y = 0; y < h; y++) {
      f[y] = mask[y * w + x] != 0 ? far : 0.0;
    }
    _lowerEnvelope(f, d, v, z, h);
    for (var y = 0; y < h; y++) {
      squared[y * w + x] = d[y];
    }
  }

  for (var y = 0; y < h; y++) {
    final o = y * w;
    for (var x = 0; x < w; x++) {
      f[x] = squared[o + x];
    }
    _lowerEnvelope(f, d, v, z, w);
    final toEdgeY = math.min(y + 1, h - y);
    for (var x = 0; x < w; x++) {
      final toEdge = math.min(math.min(x + 1, w - x), toEdgeY).toDouble();
      squared[o + x] = math.min(d[x], toEdge * toEdge);
    }
  }

  final out = Float32List(w * h);
  for (var i = 0; i < out.length; i++) {
    if (mask[i] != 0) out[i] = math.sqrt(squared[i]);
  }
  return out;
}

/// One-dimensional squared distance transform of a sampled function.
void _lowerEnvelope(
  Float64List f,
  Float64List out,
  Int32List v,
  Float64List z,
  int n,
) {
  const far = 1e20;
  var k = 0;
  v[0] = 0;
  z[0] = -far;
  z[1] = far;
  for (var q = 1; q < n; q++) {
    var s =
        (f[q] + q * q - (f[v[k]] + v[k] * v[k])) / (2.0 * q - 2.0 * v[k]);
    while (s <= z[k]) {
      k--;
      s = (f[q] + q * q - (f[v[k]] + v[k] * v[k])) / (2.0 * q - 2.0 * v[k]);
    }
    k++;
    v[k] = q;
    z[k] = s;
    z[k + 1] = far;
  }
  k = 0;
  for (var q = 0; q < n; q++) {
    while (z[k + 1] < q) {
      k++;
    }
    final dx = q - v[k];
    out[q] = dx * dx + f[v[k]];
  }
}

/// One region of the mask, taken to be one fish.
class _Basin {
  _Basin(this.peak);

  final double peak;
  int area = 0;
  double cx = 0;
  double cy = 0;
}

/// Marker-controlled watershed over the distance transform, flooded from the
/// tallest pixel down.
///
/// Peaks are not picked in advance. A pixel that arrives with no labelled
/// neighbour starts a basin; a pixel that joins two basins either merges them or
/// leaves them apart, depending on how far it sits below their peaks. That test
/// is the h-maxima transform, and it is what makes an elongated body — whose
/// distance ridge is long and nearly flat — count once, while two bodies pressed
/// together, with a deep notch between them, count twice.
List<_Basin> _watershed(
  Uint8List mask,
  Float32List dist,
  int w,
  int h,
  double sensitivity,
) {
  final n = w * h;

  // Bucket sort by descending distance. Eighth-of-a-pixel buckets: finer than
  // the flood cares about, and it keeps this linear instead of a real sort.
  const buckets = 8.0;
  var top = 0;
  var foreground = 0;
  for (var i = 0; i < n; i++) {
    if (mask[i] == 0) continue;
    foreground++;
    final key = (dist[i] * buckets).round();
    if (key > top) top = key;
  }
  if (foreground == 0) return const [];

  final counts = Int32List(top + 1);
  for (var i = 0; i < n; i++) {
    if (mask[i] != 0) counts[(dist[i] * buckets).round()]++;
  }
  // The median distance over the mask stands in for a typical fish half-width,
  // so the saddle test scales itself to the fish in front of it.
  final median = _bucketMedian(counts, foreground) / buckets;
  final depth =
      _saddleStrict + (_saddleInclusive - _saddleStrict) * sensitivity;
  final saddle = math.max(0.7, depth * median);

  final start = Int32List(top + 1);
  var offset = 0;
  for (var key = top; key >= 0; key--) {
    start[key] = offset;
    offset += counts[key];
  }
  final order = Int32List(foreground);
  final cursor = Int32List.fromList(start);
  for (var i = 0; i < n; i++) {
    if (mask[i] != 0) order[cursor[(dist[i] * buckets).round()]++] = i;
  }

  final label = Int32List(n);
  final parent = <int>[0];
  final peak = <double>[0];
  final basins = <int, _Basin>{};

  int find(int a) {
    while (parent[a] != a) {
      parent[a] = parent[parent[a]];
      a = parent[a];
    }
    return a;
  }

  final roots = <int>[];
  for (final p in order) {
    final level = dist[p];
    final x = p % w;
    final y = p ~/ w;

    roots.clear();
    for (var dy = -1; dy <= 1; dy++) {
      final ny = y + dy;
      if (ny < 0 || ny >= h) continue;
      for (var dx = -1; dx <= 1; dx++) {
        final nx = x + dx;
        if (nx < 0 || nx >= w || (dx == 0 && dy == 0)) continue;
        final other = label[ny * w + nx];
        if (other == 0) continue;
        final root = find(other);
        if (!roots.contains(root)) roots.add(root);
      }
    }

    if (roots.isEmpty) {
      parent.add(parent.length);
      peak.add(level);
      label[p] = parent.length - 1;
      continue;
    }

    // The deepest basin here is the one to keep. Any neighbour whose peak is
    // less than a saddle above this level is not a fish of its own — it is a bump
    // on the same body, so it gets folded in. Neighbours that do clear the saddle
    // are separate fish and are left alone, which makes this pixel part of the
    // divide between them.
    var host = roots.first;
    for (final root in roots) {
      if (peak[root] > peak[host]) host = root;
    }
    for (final root in roots) {
      if (root == host || peak[root] - level >= saddle) continue;
      parent[root] = host;
    }
    label[p] = host;
  }

  for (var i = 0; i < n; i++) {
    if (mask[i] == 0) continue;
    final root = find(label[i]);
    final basin = basins.putIfAbsent(root, () => _Basin(peak[root]));
    basin.area++;
    basin.cx += i % w;
    basin.cy += i ~/ w;
  }
  for (final basin in basins.values) {
    basin.cx /= basin.area;
    basin.cy /= basin.area;
  }
  return basins.values.toList();
}

/// Ring radius in short-side units.
///
/// A ring should sit around a whole fish, so it is sized from the body's long
/// axis: the distance transform peak gives the half-width, and area over that
/// gives the half-length. Measuring it beats assuming it, because a photo taken
/// from higher up has smaller fish in it and the rings should follow.
double _ringRadius(List<_Basin> basins, int shortSide) {
  final halfLengths = <double>[
    for (final b in basins)
      if (b.peak > 0) b.area / (math.pi * b.peak),
  ];
  if (halfLengths.isEmpty) return _fallbackRing;
  final radius = 1.4 * _median(halfLengths);
  return (radius / shortSide).clamp(0.006, 0.12);
}

double _median(List<double> values) {
  if (values.isEmpty) return 0;
  values.sort();
  final mid = values.length ~/ 2;
  if (values.length.isOdd) return values[mid];
  return (values[mid - 1] + values[mid]) / 2;
}

/// Median of a value already tallied into buckets.
double _bucketMedian(Int32List counts, int total) {
  final half = total ~/ 2;
  var seen = 0;
  for (var key = 0; key < counts.length; key++) {
    seen += counts[key];
    if (seen > half) return key.toDouble();
  }
  return 0;
}
