import 'dart:math' as math;

import 'package:aquametrics/data/count_editor.dart';
import 'package:aquametrics/widgets/fish_field.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Distance in short-side units, mirroring how the editor measures taps.
  double gap(Offset a, Offset b) {
    final dx = (a.dx - b.dx) * FishField.aspect;
    final dy = a.dy - b.dy;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// A detected spot with plenty of open water around it, so the assertions are
  /// about the tap radius rather than about an unrelated neighbour.
  ({FishSpot spot, Offset nearby}) isolatedSpot(FishField tray) {
    for (final spot in tray.spots) {
      // Comfortably above the default sensitivity threshold of 1 - 0.72 * 0.45.
      if (spot.size < 0.75) continue;
      final probe = Offset(spot.p.dx, spot.p.dy + tray.spacing * 0.7);
      final crowded = tray.spots.any(
        (other) =>
            other != spot &&
            other.size >= 0.676 &&
            gap(other.p, probe) < tray.spacing * 1.2,
      );
      if (!crowded) return (spot: spot, nearby: probe);
    }
    fail('no isolated spot in the generated field');
  }

  final tray = FishField.generate(seed: 4242, count: 268);
  final target = isolatedSpot(tray);

  test('a tap just outside a ring still removes it at 1x', () {
    final editor = CountEditor(tray: tray);
    final before = editor.total;

    editor.tapAt(target.nearby);

    // At 1x the finger tolerance is deliberately generous, because a tap on an
    // unzoomed frame cannot be precise.
    expect(editor.removed, 1);
    expect(editor.added, 0);
    expect(editor.total, before - 1);
  });

  test('the same tap adds a marker once zoomed in', () {
    final editor = CountEditor(tray: tray);
    final before = editor.total;

    editor.tapAt(target.nearby, scale: 4);

    // This is the reported bug: zooming in to add was grabbing the nearest ring.
    expect(editor.added, 1);
    expect(editor.removed, 0);
    expect(editor.total, before + 1);
  });

  test('zoomed taps on the ring itself still remove it', () {
    final editor = CountEditor(tray: tray);

    editor.tapAt(target.spot.p, scale: 8);

    expect(editor.removed, 1);
    expect(editor.added, 0);
  });

  test('the hit radius never shrinks below the visible ring', () {
    final editor = CountEditor(tray: tray);
    // Just inside the drawn ring at extreme zoom: what you see is what you tap.
    final justInside = Offset(
      target.spot.p.dx,
      target.spot.p.dy + tray.spacing * FishField.markerRing * 0.9,
    );

    editor.tapAt(justInside, scale: 100);

    expect(editor.removed, 1);
  });

  test('a manual marker can be removed again at the same zoom', () {
    final editor = CountEditor(tray: tray);

    editor.tapAt(target.nearby, scale: 4);
    expect(editor.added, 1);

    editor.tapAt(target.nearby, scale: 4);
    expect(editor.added, 0);
    expect(editor.removed, 0);
    expect(editor.edited, isFalse);
  });

  test('sensitivity still drives the detected count', () {
    final editor = CountEditor(tray: tray);
    final balanced = editor.autoCount;

    editor.sensitivity = 0;
    expect(editor.autoCount, lessThan(balanced));

    editor.sensitivity = 1;
    expect(editor.autoCount, greaterThan(balanced));
  });
}
