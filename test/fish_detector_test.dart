import 'dart:typed_data';

import 'package:aquametrics/models/fish_field.dart';
import 'package:aquametrics/vision/fish_detector.dart';
import 'package:aquametrics/vision/gray_image.dart';
import 'package:aquametrics/vision/tray_raster.dart';
import 'package:flutter_test/flutter_test.dart';

/// The detector is handed pixels and nothing else, so these tests render a frame
/// and check what comes back out — never what went in.
void main() {
  const spacing = 0.1;

  DetectorResult count(List<FishSpot> spots, {double sensitivity = 0.5}) {
    final field = FishField(spots: spots, spacing: spacing);
    return detectFingerlings(
      DetectorRequest(image: rasteriseTray(field), sensitivity: sensitivity),
    );
  }

  FishSpot fish(double x, double y, {double angle = 0, double size = 1}) =>
      FishSpot(p: Offset(x, y), angle: angle, size: size);

  test('empty water counts nothing', () {
    expect(count(const []).count, 0);
  });

  test('one fish counts once, at the right place', () {
    final result = count([fish(0.5, 0.5)]);

    // The regression that matters: a fingerling is a long thin body, so its
    // distance ridge runs the length of it. Splitting on every bump along that
    // ridge counted one fish two or three times.
    expect(result.count, 1);
    expect(result.fish.single.dx, closeTo(0.5, 0.02));
    expect(result.fish.single.dy, closeTo(0.5, 0.02));
  });

  test('a ring is drawn about the size of the fish it found', () {
    final result = count([fish(0.5, 0.5)]);

    // Body length as a fraction of the short side, which is what the rasteriser
    // drew and therefore what a ring has to sit around.
    const length = spacing * FishField.bodyLength;
    expect(result.ringRadius, greaterThan(length * 0.5));
    expect(result.ringRadius, lessThan(length * 1.3));
  });

  test('fish in open water are counted separately', () {
    expect(count([fish(0.25, 0.3), fish(0.7, 0.7)]).count, 2);
  });

  test('a fish is not split by the dark speck of its own eye', () {
    // The rasteriser draws the eye the painter draws, which punches a hole in
    // the mask right behind the head. An early version counted the snout in
    // front of that hole as a second fish.
    expect(count([fish(0.5, 0.5, size: 1)]).count, 1);
  });

  test('a fish crossing the frame edge is still counted once', () {
    expect(count([fish(0.02, 0.5)]).count, 1);
  });

  test('sensitivity moves the count, and in the right direction', () {
    final spots = [
      for (var i = 0; i < 40; i++)
        fish(
          0.1 + (i % 8) * 0.11,
          0.12 + (i ~/ 8) * 0.18,
          angle: i * 0.7,
          size: 0.55 + (i % 5) * 0.09,
        ),
    ];

    final strict = count(spots, sensitivity: 0).count;
    final balanced = count(spots, sensitivity: 0.5).count;
    final inclusive = count(spots, sensitivity: 1).count;

    expect(strict, lessThan(balanced));
    expect(balanced, lessThanOrEqualTo(inclusive));
  });

  test('a full tray lands in the right ballpark', () {
    final field = FishField.generate(seed: 4242, count: 268);
    final truth = field.spots.length;

    final result = detectFingerlings(
      DetectorRequest(image: rasteriseTray(field)),
    );

    // This tray is dense enough that a good number of bodies touch, so getting
    // near the truth depends on the watershed pulling those apart: without it
    // every clump would count once and the number would fall well short.
    //
    // Deliberately loose all the same. Pinning it to a percentage would turn a
    // tuning change into a failing test, and the number to trust is the one
    // measured against real photographs, not against the simulator. What is
    // worth catching here is a pipeline that has started counting clumps or
    // speckle instead of fish.
    expect(result.count, greaterThan((truth * 0.85).round()));
    expect(result.count, lessThan((truth * 1.15).round()));
  });

  test('a blank frame of uniform grey finds nothing to count', () {
    final flat = GrayImage(
      width: 64,
      height: 48,
      luma: Uint8List.fromList(List.filled(64 * 48, 90)),
    );

    // Otsu has no split to find here. The guard is that it returns empty rather
    // than dividing noise into hundreds of fish.
    expect(detectFingerlings(DetectorRequest(image: flat)).count, 0);
  });

  test('dark fish on a bright tray count the same as pale fish on dark water', () {
    // A real photograph of hito on a pale tray is the photographic inverse of
    // the simulator: dark bodies, bright background. Inverting the luma of a
    // rendered tray reproduces that exactly, and the detector must not care
    // which side of the brightness axis the fish sit on — only that they are
    // the minority class.
    final field = FishField.generate(seed: 4242, count: 268);
    final original = rasteriseTray(field);
    final inverted = GrayImage(
      width: original.width,
      height: original.height,
      luma: Uint8List.fromList(
        [for (final v in original.luma) 255 - v],
      ),
    );

    final pale = detectFingerlings(DetectorRequest(image: original)).count;
    final dark = detectFingerlings(DetectorRequest(image: inverted)).count;

    expect(pale, greaterThan(0));
    // Flat-field correction introduces a tiny asymmetry under inversion from
    // clamping at 0/255, so the two counts may differ by a watershed boundary
    // case. The point is that polarity does not break the count, not that the
    // pipeline is bit-exact under inversion.
    expect((dark - pale).abs(), lessThanOrEqualTo(2));
  });
}
