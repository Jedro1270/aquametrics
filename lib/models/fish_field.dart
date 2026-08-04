import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';

/// A single fingerling in a simulated frame. Positions are normalised to 0..1 so
/// the same field renders at any size, from a 56px thumbnail to a full screen.
@immutable
class FishSpot {
  const FishSpot({required this.p, required this.angle, required this.size});

  final Offset p;

  /// Heading in radians.
  final double angle;

  /// 0.55..1.0, scaling the drawn body. Small fish and fish low in the water
  /// come out fainter and thinner, which is what gives the detector something
  /// real to be uncertain about.
  final double size;
}

/// A generated tray of fingerlings. Deterministic for a given seed so a saved
/// batch always renders identically.
///
/// This is ground truth for a simulated capture, not a count: nothing reads
/// [spots] to answer "how many fish are there". The detector is handed pixels
/// and has to work it out, the same as it would with a photo.
@immutable
class FishField {
  const FishField({required this.spots, required this.spacing});

  final List<FishSpot> spots;

  /// Mean normalised distance between neighbours. Drives fish sizing so a dense
  /// tray reads as small fish rather than overlapping blobs.
  final double spacing;

  /// Body length as a multiple of [spacing], before each spot's own size factor.
  static const bodyLength = 0.92;

  /// Marker ring radius for a synthetic field, as a multiple of [spacing] in
  /// short-side units. Only used where there are no detections to size rings
  /// from, which today means a saved count reopened from the mock history.
  static const markerRing = 0.5;

  static const _pad = 0.06;

  factory FishField.generate({required int seed, required int count}) {
    final rnd = math.Random(seed);
    const span = 1 - _pad * 2;
    final spacing = math.sqrt(span * span / math.max(count, 1));
    final minDist = spacing * 0.58;
    final spots = <FishSpot>[];
    var guard = 0;
    while (spots.length < count && guard < count * 80) {
      guard++;
      final p = Offset(
        _pad + rnd.nextDouble() * span,
        _pad + rnd.nextDouble() * span,
      );
      if (spots.any((s) => (s.p - p).distance < minDist)) continue;
      spots.add(
        FishSpot(
          p: p,
          angle: rnd.nextDouble() * math.pi * 2,
          size: 0.55 + rnd.nextDouble() * 0.45,
        ),
      );
    }
    return FishField(spots: spots, spacing: spacing);
  }
}
