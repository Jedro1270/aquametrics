import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../models/marker.dart';
import '../vision/count_frame.dart';
import '../vision/fish_detector.dart';
import '../vision/roboflow_detector.dart';
import '../vision/yolo_detector.dart';

/// Runs a detection on a [CountFrame] at a given [sensitivity].
///
/// The YOLO detector routes through a platform channel and must be awaited on
/// the UI isolate, so this is a plain async function rather than an isolate
/// hop. In tests, [debugDetectorRunner] is swapped for a synchronous fake.
typedef DetectorRunner = Future<DetectorResult> Function(
  CountFrame frame,
  double sensitivity,
);

/// Test seam. Widget tests cannot load a real TFLite model, so they set this to
/// a runner that answers inline with a canned or classical result.
@visibleForTesting
DetectorRunner? debugDetectorRunner;

/// One count under review: the frame, what the detector found in it, and every
/// correction the operator has made on top.
///
/// This lives outside the screen so the inline frame and the expanded viewer edit
/// one shared count instead of two copies that drift apart.
class CountEditor extends ChangeNotifier {
  CountEditor({required this.frame, double sensitivity = 0.5})
    : _sensitivity = sensitivity;

  final CountFrame frame;

  double _sensitivity;
  DetectorResult _found = const DetectorResult.empty();
  String _detectorStatus = 'Waiting to analyse';
  String? _detectorError;
  bool _analysing = true;
  bool _disposed = false;

  /// Rising token, so a slow result from an abandoned run cannot land on top of a
  /// newer one.
  int _run = 0;
  Timer? _settle;

  /// Corrections are held as positions, not indices.
  ///
  /// Moving the sensitivity slider re-runs the detector and hands back a fresh
  /// list of fish in a different order, so an index would silently come to mean a
  /// different fish. A position still means the fish that was standing there.
  final List<Offset> _dropped = <Offset>[];
  final List<Offset> _added = <Offset>[];

  bool get analysing => _analysing;
  String get detectorStatus => _detectorStatus;
  String? get detectorError => _detectorError;

  /// Radius the detector measured from the fish it found. Both the ring that gets
  /// drawn and the area a tap covers come from this, so what you tap is what you
  /// see.
  double get ringRadius => _found.ringRadius;

  double get sensitivity => _sensitivity;

  set sensitivity(double value) {
    if (value == _sensitivity) return;
    _sensitivity = value;
    notifyListeners();
    // A slider drag arrives as a stream of values. Detecting on each one would
    // queue up work that is stale before it finishes.
    _settle?.cancel();
    _settle = Timer(const Duration(milliseconds: 90), analyse);
  }

  String get sensitivityLabel => switch (_sensitivity) {
    < 0.34 => 'Strict',
    < 0.72 => 'Balanced',
    _ => 'Inclusive',
  };

  int get autoCount => _found.count;
  int get removed => _found.fish.where(_isDropped).length;
  int get added => _added.length;
  int get total => autoCount - removed + added;
  int get manualDelta => added - removed;
  bool get edited => added > 0 || removed > 0;

  List<Marker> get markers => [
    for (final p in _found.fish)
      if (!_isDropped(p)) Marker(p: p),
    for (final p in _added) Marker(p: p, manual: true),
  ];

  /// Counts the frame, and counts it again whenever the sensitivity changes.
  Future<void> analyse() async {
    final token = ++_run;
    _analysing = true;
    _detectorError = null;
    _detectorStatus = debugDetectorRunner != null
        ? 'Test detector: analysing image…'
        : globalRoboflowDetector != null
        ? 'Roboflow: running workflow…'
        : globalYoloDetector != null
        ? 'On-device YOLO: analysing image…'
        : 'No detector is configured';
    notifyListeners();

    final runner = debugDetectorRunner ?? _defaultRunner;
    final result = await runner(frame, _sensitivity);
    if (_disposed || token != _run) return;

    _found = result;
    if (debugDetectorRunner != null) {
      _detectorStatus = 'Test detector: ${result.count} detections';
    }
    // A fish the operator dropped may be gone from this run's answer anyway.
    // Forgetting those keeps "you removed" honest about the frame in front of
    // them rather than about a frame two slider positions ago.
    _dropped.removeWhere(
      (p) => !_found.fish.any((fish) => _gap(fish, p) < _matchRadius),
    );
    _analysing = false;
    notifyListeners();
  }

  /// Default runner: prefers the Roboflow workflow (cloud inference) when an
  /// API key was provided at startup, falling back to the on-device YOLO
  /// model. Both are set as top-level globals by `main()` because this code
  /// cannot reach inherited widgets.
  Future<DetectorResult> _defaultRunner(
    CountFrame frame,
    double sensitivity,
  ) async {
    final roboflow = globalRoboflowDetector;
    if (roboflow != null) {
      try {
        final result = await roboflow.detect(frame, sensitivity);
        final confidence = RoboflowDetector.confidenceForSensitivity(
          sensitivity,
        );
        _detectorStatus =
            'Roboflow: ${result.count} detections · confidence '
            '${confidence.toStringAsFixed(3)}';
        return result;
      } catch (error) {
        _detectorError = _errorSummary(error);
        _detectorStatus = 'Roboflow failed; trying on-device YOLO…';
      }
    }
    final yolo = globalYoloDetector;
    if (yolo != null) {
      try {
        final result = await yolo.detectAsync(frame, sensitivity);
        _detectorStatus = 'On-device YOLO: ${result.count} detections';
        return result;
      } catch (error) {
        _detectorError = _errorSummary(error);
        _detectorStatus = 'On-device YOLO failed';
        return const DetectorResult.empty();
      }
    }
    if (roboflow != null) {
      _detectorStatus = 'Roboflow failed; no on-device model is loaded';
    }
    return const DetectorResult.empty();
  }

  String _errorSummary(Object error) {
    final summary = error.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    return summary.length <= 180 ? summary : '${summary.substring(0, 177)}…';
  }

  /// The removal target starts only slightly larger than the visible ring and
  /// physically contracts as zoom increases. This lets an operator add next to
  /// a marker without dropping it, while a deliberate tap on the marker's
  /// centre remains easy at any zoom level.
  static const _hitAt1x = 1.08;
  static const _zoomExponent = 1.25;

  /// Radius used to remove a marker at a given [scale].
  static double markerHitRadiusForZoom(double ringRadius, {double scale = 1}) {
    final zoom = math.max(scale, 1);
    return (ringRadius * _hitAt1x / math.pow(zoom, _zoomExponent)).toDouble();
  }

  /// Ring radius passed to the painter before [InteractiveViewer] applies its
  /// zoom transform. This keeps the visible ring aligned with the hit target.
  static double markerRingRadiusForZoom(double ringRadius, {double scale = 1}) {
    final zoom = math.max(scale, 1);
    return (ringRadius / math.pow(zoom, _zoomExponent)).toDouble();
  }

  /// How close a position has to be to count as the same fish, as a fraction of
  /// the ring radius.
  static const _matchAsRingFraction = 0.75;

  double get _matchRadius => _found.ringRadius * _matchAsRingFraction;

  bool _isDropped(Offset fish) =>
      _dropped.any((p) => _gap(fish, p) < _matchRadius);

  /// Distance between two normalised points, in short-side units.
  ///
  /// Normalised coordinates are anisotropic when the frame is not square: a raw
  /// normalised distance would describe an ellipse stretched across the wider
  /// axis rather than the circle the operator sees.
  double _gap(Offset a, Offset b) {
    final dx = (a.dx - b.dx) * frame.aspect;
    final dy = a.dy - b.dy;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Drops the nearest marker under [n], or adds one there if the tap landed on
  /// open water. [n] is normalised to 0..1, and [scale] is the current zoom, so
  /// that zooming in genuinely buys precision.
  void tapAt(Offset n, {double scale = 1}) {
    final hit = markerHitRadiusForZoom(_found.ringRadius, scale: scale);

    for (var i = _added.length - 1; i >= 0; i--) {
      if (_gap(_added[i], n) < hit) {
        _added.removeAt(i);
        notifyListeners();
        return;
      }
    }

    Offset? nearest;
    var best = hit;
    for (final fish in _found.fish) {
      if (_isDropped(fish)) continue;
      final d = _gap(fish, n);
      if (d < best) {
        best = d;
        nearest = fish;
      }
    }

    if (nearest != null) {
      _dropped.add(nearest);
    } else {
      _added.add(n);
    }
    notifyListeners();
  }

  void clearEdits() {
    if (!edited) return;
    _dropped.clear();
    _added.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _settle?.cancel();
    super.dispose();
  }
}
