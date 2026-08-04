import 'dart:io' show Directory, File;

import 'package:aquametrics/vision/count_frame.dart';
import 'package:aquametrics/vision/roboflow_detector.dart';
import 'package:flutter_test/flutter_test.dart';

/// Smoke test for the Roboflow workflow integration. Runs the real workflow
/// on `sample/hito_sample_1.jpeg` and asserts the expected output keys exist.
///
/// Skips when `ROBOFLOW_API_KEY` is not set — this is a live network test, not
/// a unit test, so it should not fail CI or local runs without a key.
///
/// Run with:
///   flutter test --dart-define=ROBOFLOW_API_KEY=your_key_here \
///       test/roboflow_smoke_test.dart
void main() {
  final apiKey = roboflowApiKey;

  test(
    'Roboflow workflow returns fingerling detections on sample image',
    () async {
      if (apiKey == null) {
        throw StateError(
          'Pass --dart-define=ROBOFLOW_API_KEY=... to run this smoke test. '
          'Get one at app.roboflow.com/settings/api.',
        );
      }

      final samplePath =
          '${Directory.current.path}/sample/hito_sample_1.jpeg';
      final bytes = await File(samplePath).readAsBytes();

      final detector = RoboflowDetector(apiKey: apiKey);
      addTearDown(detector.dispose);

      // Use a real PhotoFrame so the detector gets encoded JPEG bytes.
      final frame = await PhotoFrame.decode(bytes);

      final strict = await detector.detect(frame, 0);
      final balanced = await detector.detect(frame, 0.5);
      final inclusive = await detector.detect(frame, 1);

      // ignore: avoid_print
      print(
        'Roboflow sensitivity sweep: '
        'strict=${strict.count}, balanced=${balanced.count}, '
        'inclusive=${inclusive.count}',
      );

      // The workflow returned 277 detections at confidence 0.4 in the grounding
      // run. The exact counts can vary with a model update, but lowering the
      // confidence threshold must never reduce the count.
      expect(strict.fish, isNotEmpty, reason: 'No fish detected');
      expect(strict.count, lessThanOrEqualTo(balanced.count));
      expect(balanced.count, lessThanOrEqualTo(inclusive.count));
      expect(strict.count, lessThan(inclusive.count));

      // Every fish position is normalised to 0..1.
      for (final p in inclusive.fish) {
        expect(p.dx, inInclusiveRange(0.0, 1.0));
        expect(p.dy, inInclusiveRange(0.0, 1.0));
      }

      // Ring radius is sane — a fingerling is small relative to the tray.
      expect(inclusive.ringRadius, inInclusiveRange(0.005, 0.15));
    },
    // Live network test — skip without an API key so `flutter test` passes
    // in environments without Roboflow credentials.
    skip: apiKey == null
        ? 'Pass --dart-define=ROBOFLOW_API_KEY=... to run this live smoke test'
        : false,
  );
}
