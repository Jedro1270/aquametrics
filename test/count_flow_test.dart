import 'dart:typed_data';

import 'package:aquametrics/data/count_editor.dart';
import 'package:aquametrics/main.dart';
import 'package:aquametrics/screens/capture_screen.dart';
import 'package:aquametrics/vision/count_frame.dart';
import 'package:aquametrics/vision/fish_detector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

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

  /// Detection runs through a platform channel in production. In a widget test
  /// the TFLite runtime is unavailable, so the editor is pointed at a mock
  /// runner that reads the simulated field's spots and returns them as
  /// detections — enough to exercise the review/correction/save flow.
  void runDetectorInline() {
    debugDetectorRunner = (frame, sensitivity) async {
      if (frame is! SimulatedFrame) return const DetectorResult.empty();
      return DetectorResult(
        fish: [for (final s in frame.field.spots) s.p],
        ringRadius: 0.03,
        threshold: 100,
      );
    };
  }

  /// Clears the detector pass and the marker reveal animation.
  Future<void> settleDetector(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  setUp(() {
    runDetectorInline();
    debugPhotoFrameDecoder = (_) async => SimulatedFrame.seeded(seed: 20740);
  });
  tearDown(() {
    debugDetectorRunner = null;
    debugPhotoFrameDecoder = null;
  });

  Future<XFile?> pickTestImage({
    required ImageSource source,
    required int imageQuality,
  }) async {
    expect(source, ImageSource.camera);
    expect(imageQuality, 92);
    return XFile.fromData(Uint8List.fromList([0]), name: 'camera-tray.jpg');
  }

  testWidgets('home shows today\'s total and recent counts', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(AquaMetricsApp(pickImage: pickTestImage));
    await tester.pumpAndSettle();

    expect(find.text('AquaMetrics'), findsOneWidget);
    expect(find.text('Count fingerlings'), findsOneWidget);
    expect(find.text('Pond 3 transfer'), findsWidgets);
  });

  testWidgets('shutter opens the device camera', (tester) async {
    usePhoneSurface(tester);
    ImageSource? pickedSource;
    var pickedImageQuality = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: CaptureScreen(
          pickImage: ({required source, required imageQuality}) async {
            pickedSource = source;
            pickedImageQuality = imageQuality;
            return null;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('SIMULATED PREVIEW'), findsNothing);

    await tester.tap(find.byIcon(Icons.center_focus_strong_rounded));
    await tester.pump();

    expect(pickedSource, ImageSource.camera);
    expect(pickedImageQuality, 92);
  });

  testWidgets('capture leads to a reviewable count', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(AquaMetricsApp(pickImage: pickTestImage));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Count fingerlings'));
    await tester.pumpAndSettle();
    expect(find.text('Frame the tray'), findsOneWidget);

    // The shutter captures a simulated tray and opens the review screen.
    await tester.tap(find.byIcon(Icons.center_focus_strong_rounded));
    await tester.pump(const Duration(seconds: 1));
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
    await tester.pumpWidget(AquaMetricsApp(pickImage: pickTestImage));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Count fingerlings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.center_focus_strong_rounded));
    await tester.pump(const Duration(seconds: 1));
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
    await tester.pumpWidget(AquaMetricsApp(pickImage: pickTestImage));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Count fingerlings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.center_focus_strong_rounded));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await settleDetector(tester);

    await tester.tap(find.text('Save count'));
    await tester.pumpAndSettle();

    expect(find.text('Count fingerlings'), findsOneWidget);
    expect(find.textContaining('Saved'), findsOneWidget);
  });

  testWidgets('a saved count opens read-only and expands', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(AquaMetricsApp(pickImage: pickTestImage));
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
