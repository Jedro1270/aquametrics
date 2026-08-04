import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:flutter_vision/flutter_vision.dart';

import 'count_frame.dart';
import 'fish_detector.dart';

/// A YOLO-based fingerling detector backed by `flutter_vision`.
///
/// One instance is shared across the app: the model is loaded once at startup
/// and kept resident, because re-loading a TFLite interpreter per count would
/// cost hundreds of milliseconds and leak native memory.
///
/// The sensitivity slider maps to YOLO's confidence threshold: strict keeps
/// only high-confidence detections, inclusive lets marginal ones through. IoU
/// is held at a fixed 0.45 — the standard NMS overlap — because the slider is
/// about what counts as a fish, not about how much overlap is tolerated.
class YoloDetector {
  YoloDetector._(this._vision, this._modelPath, this._labelsPath);

  final FlutterVision _vision;
  final String _modelPath;
  final String _labelsPath;

  bool _loaded = false;

  /// Loads the YOLO model from the asset bundle. Call once at startup.
  static Future<YoloDetector> create({
    String modelPath = 'assets/models/fish.tflite',
    String labelsPath = 'assets/models/labels.txt',
    int numThreads = 2,
  }) async {
    final vision = FlutterVision();
    final detector = YoloDetector._(vision, modelPath, labelsPath);
    await detector._load(numThreads: numThreads);
    return detector;
  }

  Future<void> _load({required int numThreads}) async {
    if (_loaded) return;
    await _vision.loadYoloModel(
      modelPath: _modelPath,
      labels: _labelsPath,
      modelVersion: 'yolo11',
      quantization: false,
      numThreads: numThreads,
      isAsset: true,
      useGpu: false,
    );
    _loaded = true;
  }

  /// Releases the native interpreter. Call on app teardown.
  Future<void> dispose() async {
    if (!_loaded) return;
    await _vision.closeYoloModel();
    _loaded = false;
  }

  /// Runs detection on a [CountFrame], returning results in the same
  /// [DetectorResult] shape the editor already consumes.
  ///
  /// [sensitivity] 0..1 maps to a confidence threshold: 0 (strict) keeps only
  /// the most confident detections, 1 (inclusive) lets marginal ones through.
  /// The mapping is inverted — a higher sensitivity *lowers* the confidence
  /// cut so more fish survive — to match the classical detector's direction.
  ///
  /// [flutter_vision] routes through a platform channel, so this must be
  /// awaited on the UI isolate rather than inside `compute()`.
  Future<DetectorResult> detectAsync(CountFrame frame, double sensitivity) async {
    final bytes = frame.encodedBytes;
    if (bytes == null || !_loaded) return const DetectorResult.empty();

    final s = sensitivity.clamp(0.0, 1.0);
    final confThreshold = 0.50 - s * 0.35;
    const iouThreshold = 0.45;

    final results = await _vision.yoloOnImage(
      bytesList: bytes,
      imageHeight: frame.pixelHeight,
      imageWidth: frame.pixelWidth,
      iouThreshold: iouThreshold,
      confThreshold: confThreshold,
      classThreshold: confThreshold,
    );

    // flutter_vision returns box as [x1, y1, x2, y2, class_confidence] in
    // pixel coordinates of the original image — corner format, not
    // center+dimensions. Convert to box centres normalised to 0..1 so markers
    // survive any display size.
    final w = frame.pixelWidth.toDouble();
    final h = frame.pixelHeight.toDouble();
    final fish = <Offset>[];
    final diagonals = <double>[];
    for (final r in results) {
      final box = r['box'];
      if (box is! List || box.length < 4) continue;
      final x1 = (box[0] as num).toDouble();
      final y1 = (box[1] as num).toDouble();
      final x2 = (box[2] as num).toDouble();
      final y2 = (box[3] as num).toDouble();
      final cx = (x1 + x2) / 2;
      final cy = (y1 + y2) / 2;
      fish.add(Offset(cx / w, cy / h));
      final bw = x2 - x1;
      final bh = y2 - y1;
      diagonals.add(math.sqrt(bw * bw + bh * bh));
    }

    if (fish.isEmpty) return const DetectorResult.empty();

    // Ring radius: sized from the median box diagonal so a marker sits around
    // a whole fish. This is what the editor uses for hit-testing and drawing.
    final shortSide = math.min(w, h);
    final ringRadius = (_median(diagonals) * 0.7 / shortSide).clamp(0.006, 0.12);

    return DetectorResult(
      fish: fish,
      ringRadius: ringRadius,
      threshold: (confThreshold * 255).round(),
    );
  }

  double _median(List<double> values) {
    if (values.isEmpty) return 0;
    values.sort();
    final mid = values.length ~/ 2;
    if (values.length.isOdd) return values[mid];
    return (values[mid - 1] + values[mid]) / 2;
  }
}

/// Global detector instance, set once at startup by the app's main widget.
///
/// Kept as a top-level mutable rather than inherited through the widget tree
/// because [CountEditor.analyse] runs on an isolate and cannot reach inherited
/// widgets — it needs a direct reference to the detector.
YoloDetector? globalYoloDetector;
