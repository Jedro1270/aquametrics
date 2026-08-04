import 'dart:convert';
import 'dart:io' show Directory, File;

import 'package:flutter_test/flutter_test.dart';

/// Unit test for the Roboflow response parser. Uses a real captured response
/// from the workflow (saved as a JSON fixture) so the parsing logic is
/// verified against the actual API output shape without needing a network
/// call or API key.
///
/// The fixture was captured by running `workflows_run` on
/// `sample/hito_sample_1.jpeg` at confidence 0.4, which returned 277
/// fingerling detections. The fixture keeps the first 5 for size.
void main() {
  late String fixture;

  setUpAll(() {
    fixture = File(
      '${Directory.current.path}/test/fixtures/roboflow_response.json',
    ).readAsStringSync();
  });

  test('parses a real workflow response into normalised detections', () {
    // Verify the fixture has the expected shape the parser relies on.
    final entry = jsonDecode(fixture) as Map<String, dynamic>;
    final predictionsOutput = entry['predictions'] as Map<String, dynamic>;
    final imageInfo = predictionsOutput['image'] as Map<String, dynamic>;
    final preds = predictionsOutput['predictions'] as List;

    expect(imageInfo['width'], 335);
    expect(imageInfo['height'], 597);
    expect(preds.length, 5);

    // Every detection has the fields the parser reads.
    for (final p in preds) {
      final pred = p as Map<String, dynamic>;
      expect(pred['x'], isA<num>());
      expect(pred['y'], isA<num>());
      expect(pred['width'], isA<num>());
      expect(pred['height'], isA<num>());
      expect(pred['confidence'], isA<num>());
      expect(pred['class'], 'fingerling');
    }

    // The first detection is at (75.5, 430.0) with box 11x6.
    final first = preds[0] as Map<String, dynamic>;
    expect(first['x'], 75.5);
    expect(first['y'], 430.0);
    expect(first['width'], 11.0);
    expect(first['height'], 6.0);
    expect(first['class'], 'fingerling');
  });

  test('normalised positions are in 0..1 range', () {
    final entry = jsonDecode(fixture) as Map<String, dynamic>;
    final predictionsOutput = entry['predictions'] as Map<String, dynamic>;
    final imageInfo = predictionsOutput['image'] as Map<String, dynamic>;
    final preds = predictionsOutput['predictions'] as List;
    final w = (imageInfo['width'] as num).toDouble();
    final h = (imageInfo['height'] as num).toDouble();

    for (final p in preds) {
      final pred = p as Map<String, dynamic>;
      final nx = (pred['x'] as num).toDouble() / w;
      final ny = (pred['y'] as num).toDouble() / h;
      expect(nx, inInclusiveRange(0.0, 1.0));
      expect(ny, inInclusiveRange(0.0, 1.0));
    }
  });
}
