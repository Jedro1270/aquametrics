import 'package:aquametrics/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Walks the capture → review → expand → save flow. Any layout overflow or
/// failed assertion along the way fails the test, which is the cheapest way to
/// check the screens on a real phone geometry without a device attached.
void main() {
  /// The default 800x600 test surface is not a phone, and the review screen is
  /// laid out for one.
  void usePhoneSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// Clears the simulated detector pass and the marker reveal animation.
  Future<void> settleDetector(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  testWidgets('home shows today\'s total and recent counts', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(const AquaMetricsApp());
    await tester.pumpAndSettle();

    expect(find.text('AquaMetrics'), findsOneWidget);
    expect(find.text('Count fingerlings'), findsOneWidget);
    expect(find.text('Pond 3 transfer'), findsWidgets);
  });

  testWidgets('capture leads to a reviewable count', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(const AquaMetricsApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Count fingerlings'));
    await tester.pumpAndSettle();
    expect(find.text('Frame the tray'), findsOneWidget);

    // The gallery button shares the capture path with the shutter and its icon
    // is unambiguous while the home route is still in the tree.
    await tester.tap(find.byIcon(Icons.photo_library_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Review count'), findsOneWidget);

    await settleDetector(tester);
    expect(find.text('Save count'), findsOneWidget);
    expect(find.text('Detection sensitivity'), findsOneWidget);
  });

  testWidgets('review frame expands, stays editable, and shares its count', (
    tester,
  ) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(const AquaMetricsApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Count fingerlings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.photo_library_outlined));
    await tester.pumpAndSettle();
    await settleDetector(tester);

    expect(find.text('Expand'), findsOneWidget);
    await tester.tap(find.text('Expand'));
    await tester.pumpAndSettle();

    // The expanded viewer carries the correction controls, not just the image.
    expect(find.text('Sensitivity'), findsOneWidget);
    expect(find.text('You added'), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);

    // Stepping the zoom must not throw and must offer a way back to fit.
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.zoom_out_map_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.zoom_out_map_rounded));
    await tester.pumpAndSettle();

    // Correcting inside the viewer, then closing it, must leave the review
    // screen showing the same corrected count.
    await tester.tapAt(tester.getCenter(find.byType(InteractiveViewer)));
    await tester.pumpAndSettle();
    expect(find.text('Undo my edits'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Review count'), findsOneWidget);
    expect(find.text('Undo my edits'), findsOneWidget);
  });

  testWidgets('saving a count returns home and lands in the list', (
    tester,
  ) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(const AquaMetricsApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Count fingerlings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.photo_library_outlined));
    await tester.pumpAndSettle();
    await settleDetector(tester);

    await tester.tap(find.text('Save count'));
    await tester.pumpAndSettle();

    expect(find.text('Count fingerlings'), findsOneWidget);
    expect(find.textContaining('Saved'), findsOneWidget);
  });

  testWidgets('a saved count opens read-only and expands', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(const AquaMetricsApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Buyer sample — Delgado'));
    await tester.pumpAndSettle();
    expect(find.text('Count details'), findsOneWidget);

    await tester.tap(find.text('Expand'));
    await tester.pumpAndSettle();

    // Read-only: no correction controls, but zoom still works.
    expect(find.text('Sensitivity'), findsNothing);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
  });
}
