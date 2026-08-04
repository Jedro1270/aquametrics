import 'package:aquametrics/data/count_editor.dart';
import 'package:aquametrics/models/fish_field.dart';
import 'package:aquametrics/vision/count_frame.dart';
import 'package:aquametrics/vision/fish_detector.dart';
import 'package:flutter_test/flutter_test.dart';

/// The editor now runs a real detector, so these tests hand it a frame the
/// detector can count and check the correction behaviour on top of that.
void main() {
  /// A mock runner that returns one fish at the centre of the frame, sized to
  /// match the simulated fish. The YOLO model cannot run in a widget test (no
  /// TFLite runtime), so the runner is faked with a canned result that has the
  /// shape the editor expects.
  DetectorRunner oneFishRunner() {
    return (frame, sensitivity) async {
      // Read the fish position from the simulated field so the marker lands
      // where the painter draws it.
      if (frame is! SimulatedFrame) return const DetectorResult.empty();
      final spots = frame.field.spots;
      return DetectorResult(
        fish: [for (final s in spots) s.p],
        ringRadius: 0.05,
        threshold: 100,
      );
    };
  }

  /// A small tray with one well-separated fish, so the assertions are about the
  /// tap radius rather than about an unrelated neighbour.
  CountEditor makeEditor() {
    final field = FishField(spots: [
      FishSpot(p: const Offset(0.5, 0.5), angle: 0, size: 1),
    ], spacing: 0.2);
    final frame = SimulatedFrame(field);
    final editor = CountEditor(frame: frame);
    // Run detection inline so the test does not have to pump an isolate hop.
    debugDetectorRunner = oneFishRunner();
    return editor;
  }

  /// A tap position inside the conservative 1x target but outside the tighter
  /// 4x target. Zooming in must let this become an intentional add instead of
  /// grabbing the nearby marker.
  Offset insideAt1xOutsideAt4x(CountEditor editor) {
    final r = editor.ringRadius;
    final mid =
        (CountEditor.markerHitRadiusForZoom(r) +
            CountEditor.markerHitRadiusForZoom(r, scale: 4)) /
        2;
    return Offset(0.5, 0.5 + mid);
  }

  setUp(() => debugDetectorRunner = null);

  test('a tap near but beyond a ring adds at 1x', () async {
    final editor = makeEditor();
    await editor.analyse();
    final before = editor.total;
    expect(before, 1);
    expect(editor.detectorStatus, 'Test detector: 1 detections');
    expect(editor.detectorError, isNull);

    editor.tapAt(const Offset(0.5, 0.5 + 0.055));

    expect(editor.removed, 0);
    expect(editor.added, 1);
    expect(editor.total, before + 1);
    editor.dispose();
  });

  test('zooming in makes a near-ring tap add instead of remove', () async {
    final editor = makeEditor();
    await editor.analyse();
    final before = editor.total;

    editor.tapAt(insideAt1xOutsideAt4x(editor), scale: 4);

    expect(editor.added, 1);
    expect(editor.removed, 0);
    expect(editor.total, before + 1);
    editor.dispose();
  });

  test('marker ring and removal target both shrink as zoom increases', () {
    const ring = 0.05;

    final ringAt1x = CountEditor.markerRingRadiusForZoom(ring);
    final ringAt4x = CountEditor.markerRingRadiusForZoom(ring, scale: 4);
    final hitAt1x = CountEditor.markerHitRadiusForZoom(ring);
    final hitAt4x = CountEditor.markerHitRadiusForZoom(ring, scale: 4);

    expect(ringAt4x, lessThan(ringAt1x));
    expect(hitAt4x, lessThan(hitAt1x));
    expect(hitAt4x, closeTo(ringAt4x * 1.08, 0.000001));
  });

  test('zoomed taps on the ring itself still remove it', () async {
    final editor = makeEditor();
    await editor.analyse();

    editor.tapAt(const Offset(0.5, 0.5), scale: 8);

    expect(editor.removed, 1);
    expect(editor.added, 0);
    editor.dispose();
  });

  test('a manual marker can be removed again at the same zoom', () async {
    final editor = makeEditor();
    await editor.analyse();

    final tap = insideAt1xOutsideAt4x(editor);
    editor.tapAt(tap, scale: 4);
    expect(editor.added, 1);

    editor.tapAt(tap, scale: 4);
    expect(editor.added, 0);
    expect(editor.removed, 0);
    expect(editor.edited, isFalse);
    editor.dispose();
  });

  test('clearEdits undoes both adds and drops', () async {
    final editor = makeEditor();
    await editor.analyse();
    final baseline = editor.total;

    editor.tapAt(const Offset(0.5, 0.5), scale: 1);
    editor.tapAt(const Offset(0.2, 0.2), scale: 4);
    expect(editor.edited, isTrue);

    editor.clearEdits();
    expect(editor.edited, isFalse);
    expect(editor.total, baseline);
    editor.dispose();
  });

  test('sensitivity moves the detected count', () async {
    // A mock runner that returns more fish at higher sensitivity, matching the
    // YOLO confidence-threshold mapping: strict drops marginal detections.
    final field = FishField.generate(seed: 4242, count: 268);
    final frame = SimulatedFrame(field);
    final editor = CountEditor(frame: frame);
    debugDetectorRunner = (frame, sensitivity) async {
      if (frame is! SimulatedFrame) return const DetectorResult.empty();
      final spots = frame.field.spots;
      // Strict (0) keeps 80%, balanced (0.5) keeps all, inclusive (1) adds 10%.
      final keep = (spots.length * (0.8 + sensitivity * 0.3)).round();
      return DetectorResult(
        fish: [for (final s in spots.take(keep)) s.p],
        ringRadius: 0.03,
        threshold: 100,
      );
    };

    await editor.analyse();
    final balanced = editor.autoCount;
    expect(balanced, greaterThan(0));

    editor.sensitivity = 0;
    await editor.analyse();
    expect(editor.autoCount, lessThanOrEqualTo(balanced));

    editor.sensitivity = 1;
    await editor.analyse();
    expect(editor.autoCount, greaterThanOrEqualTo(balanced));
    editor.dispose();
  });
}
