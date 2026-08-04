import 'package:aquametrics/models/fish_field.dart';
import 'package:aquametrics/vision/fish_detector.dart';
import 'package:aquametrics/vision/tray_raster.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accuracy against ground truth', () {
    final seeds = [1207, 4419, 8802, 3311, 6754, 9128, 5560, 20740];
    for (final density in [120, 268, 420]) {
      var worst = 0.0;
      final line = StringBuffer('n=$density  ');
      for (final seed in seeds) {
        final field = FishField.generate(seed: seed, count: density);
        final truth = field.spots.length;
        final sw = Stopwatch()..start();
        final result = detectFingerlings(
          DetectorRequest(image: rasteriseTray(field), sensitivity: 0.5),
        );
        sw.stop();
        final err = (result.count - truth) / truth * 100;
        if (err.abs() > worst) worst = err.abs();
        line.write(
          '$truth/${result.count} (${err.toStringAsFixed(1)}%, '
          '${sw.elapsedMilliseconds}ms)  ',
        );
      }
      // ignore: avoid_print
      print('$line   worst=${worst.toStringAsFixed(1)}%');
    }
  });

  test('sensitivity sweep', () {
    final field = FishField.generate(seed: 4242, count: 268);
    final image = rasteriseTray(field);
    final line = StringBuffer('truth=${field.spots.length}  ');
    for (final s in [0.0, 0.25, 0.5, 0.75, 1.0]) {
      final r = detectFingerlings(
        DetectorRequest(image: image, sensitivity: s),
      );
      line.write('$s->${r.count}/t${r.threshold}/r'
          '${r.ringRadius.toStringAsFixed(4)}  ');
    }
    // ignore: avoid_print
    print(line);
  });
}
