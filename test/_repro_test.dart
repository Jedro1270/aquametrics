import 'package:aquametrics/data/count_editor.dart';
import 'package:aquametrics/models/fish_field.dart';
import 'package:aquametrics/vision/count_frame.dart';
import 'package:aquametrics/vision/fish_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  debugDetectorRunner = (frame, sensitivity) async {
    if (frame is! SimulatedFrame) return const DetectorResult.empty();
    // Ring radius sized to the field's spacing, matching what the classical
    // detector would measure — so the match radius in tapAt behaves the same
    // way it did when the test ran against detectFingerlings.
    return DetectorResult(
      fish: [for (final s in frame.field.spots) s.p],
      ringRadius: frame.field.spacing * 0.5,
      threshold: 100,
    );
  };

  test('repro: sensitivity change erases corrections', () async {
    final field = FishField.generate(seed: 4242, count: 268);
    final frame = SimulatedFrame(field);
    final editor = CountEditor(frame: frame);

    await editor.analyse();
    // ignore: avoid_print
    print('baseline autoCount=${editor.autoCount} '
        'ringRadius=${editor.ringRadius.toStringAsFixed(4)}');

    // Drop a few detected fish.
    final toDrop = editor.markers.take(5).map((m) => m.p).toList();
    for (final p in toDrop) {
      editor.tapAt(p, scale: 4);
    }
    // Add a couple.
    editor.tapAt(const Offset(0.1, 0.1), scale: 4);
    editor.tapAt(const Offset(0.9, 0.9), scale: 4);

    // ignore: avoid_print
    print('before: auto=${editor.autoCount} removed=${editor.removed} '
        'added=${editor.added} total=${editor.total}');

    expect(editor.removed, 5);
    expect(editor.added, 2);

    // Now change sensitivity — this re-runs the detector.
    editor.sensitivity = 0.75;
    await editor.analyse();

    // ignore: avoid_print
    print('after:  auto=${editor.autoCount} removed=${editor.removed} '
        'added=${editor.added} total=${editor.total}');

    expect(editor.added, 2, reason: 'manual adds were erased');
    expect(editor.removed, greaterThan(0), reason: 'drops were erased');
    editor.dispose();
  });
}
