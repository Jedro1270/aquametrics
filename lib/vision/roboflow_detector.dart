import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset;

import 'package:http/http.dart' as http;

import 'count_frame.dart';
import 'fish_detector.dart';

/// Typed errors for the Roboflow client. Thrown so callers can distinguish a
/// network failure from a bad API key from a malformed response — each needs a
/// different user message.
sealed class RoboflowError implements Exception {
  const RoboflowError(this.message);
  final String message;
  @override
  String toString() => '$runtimeType: $message';
}

class RoboflowConfigError extends RoboflowError {
  const RoboflowConfigError(super.message);
}

class RoboflowApiError extends RoboflowError {
  const RoboflowApiError(super.message);
}

class RoboflowParseError extends RoboflowError {
  const RoboflowParseError(super.message);
}

/// One detection from the Roboflow workflow, parsed from the raw API response.
///
/// Box coordinates are normalised to 0..1 against the source image so markers
/// survive any display size — the same convention the classical detector and
/// the editor use.
class RoboflowDetection {
  const RoboflowDetection({
    required this.center,
    required this.boxWidth,
    required this.boxHeight,
    required this.confidence,
    required this.className,
  });

  final Offset center;
  final double boxWidth;
  final double boxHeight;
  final double confidence;
  final String className;
}

/// The decoded result of a single workflow run.
class RoboflowResult {
  const RoboflowResult({
    required this.detections,
    required this.imageWidth,
    required this.imageHeight,
  });

  final List<RoboflowDetection> detections;
  final int imageWidth;
  final int imageHeight;
}

/// Client for the Roboflow Workflow "fingerlings-dataset-new-n0llf".
///
/// Calls the serverless REST endpoint directly — there is no official Dart SDK
/// for Roboflow, so this models its behaviour on the Python `inference-sdk`:
/// POST JSON with an `api_key` and `inputs`: the image plus every declared
/// workflow parameter. The Python SDK exposes parameters separately, but the
/// serverless REST endpoint requires them in `inputs`.
///
/// The sensitivity slider maps to the workflow's `confidence` parameter:
/// strict (0) keeps only high-confidence detections, inclusive (1) lets
/// marginal ones through. IoU is held at the workflow's default (0.3) because
/// the slider is about what counts as a fish, not about how much overlap is
/// tolerated.
class RoboflowDetector {
  RoboflowDetector({
    required String apiKey,
    String workspace = 'jvd-pagayonan-proton-me',
    String workflowId = 'fingerlings-dataset-new-n0llf',
    String apiUrl = 'https://serverless.roboflow.com',
    http.Client? client,
    Duration timeout = const Duration(seconds: 30),
    int maxRetries = 2,
  }) : _apiKey = apiKey,
       _endpoint = '$apiUrl/$workspace/workflows/$workflowId',
       _client = client ?? http.Client(),
       _timeout = timeout,
       _maxRetries = maxRetries;

  final String _apiKey;
  final String _endpoint;
  final http.Client _client;
  final Duration _timeout;
  final int _maxRetries;

  bool _disposed = false;

  /// Converts the app's 0..1 sensitivity slider to the workflow's confidence
  /// threshold. Increasing sensitivity lowers the threshold and returns more
  /// detections.
  static double confidenceForSensitivity(double sensitivity) =>
      0.50 - sensitivity.clamp(0.0, 1.0) * 0.35;

  /// Releases the HTTP client. Call on app teardown.
  void dispose() {
    if (_disposed) return;
    _client.close();
    _disposed = true;
  }

  /// Runs the workflow on a [CountFrame], returning detections in the same
  /// [DetectorResult] shape the editor already consumes.
  ///
  /// [sensitivity] 0..1 maps to a confidence threshold: 0 (strict) → 0.50,
  /// 0.5 (balanced) → 0.30, 1 (inclusive) → 0.15. The mapping is inverted —
  /// a higher sensitivity *lowers* the confidence cut so more fish survive —
  /// to match the classical detector's direction.
  Future<DetectorResult> detect(CountFrame frame, double sensitivity) async {
    if (_disposed) return const DetectorResult.empty();

    final bytes = frame.encodedBytes;
    if (bytes == null) return const DetectorResult.empty();

    final confidence = confidenceForSensitivity(sensitivity);
    // IoU held at the workflow's default — NMS overlap is geometry, not
    // confidence.
    const iouThreshold = 0.3;

    final result = await _runWithRetries(
      imageBytes: bytes,
      confidence: confidence,
      iouThreshold: iouThreshold,
    );

    if (result.detections.isEmpty) return const DetectorResult.empty();

    final fish = <Offset>[];
    final diagonals = <double>[];
    for (final d in result.detections) {
      fish.add(d.center);
      final diag = math.sqrt(d.boxWidth * d.boxWidth + d.boxHeight * d.boxHeight);
      diagonals.add(diag / result.imageWidth);
    }

    // Ring radius from the median box diagonal, normalised to the image's
    // short side so it's aspect-ratio independent.
    final shortSide = math.min(result.imageWidth, result.imageHeight);
    final ringRadius = (_median(diagonals) * 0.7 * result.imageWidth / shortSide)
        .clamp(0.006, 0.12);

    return DetectorResult(
      fish: fish,
      ringRadius: ringRadius,
      threshold: (confidence * 255).round(),
    );
  }

  /// Runs the workflow with retries and exponential backoff. Retries on
  /// network errors and 5xx responses; 4xx errors are thrown immediately
  /// because they indicate a config problem that won't fix itself.
  Future<RoboflowResult> _runWithRetries({
    required Uint8List imageBytes,
    required double confidence,
    required double iouThreshold,
  }) async {
    final body = jsonEncode({
      'api_key': _apiKey,
      'inputs': {
        'image': {
          'type': 'base64',
          'value': base64Encode(imageBytes),
        },
        'confidence': confidence,
        'iou_threshold': iouThreshold,
        'class_agnostic_nms': false,
        'max_detections': 1000,
      },
    });

    var attempt = 0;
    while (true) {
      attempt++;
      try {
        final response = await _client
            .post(Uri.parse(_endpoint), body: body, headers: _headers)
            .timeout(_timeout);

        if (response.statusCode >= 500 && attempt <= _maxRetries) {
          await _backoff(attempt);
          continue;
        }
        if (response.statusCode != 200) {
          throw RoboflowApiError(
            'Workflow returned ${response.statusCode}: ${response.body}',
          );
        }
        return _parseResponse(response.body);
      } on http.ClientException catch (e) {
        if (attempt > _maxRetries) throw RoboflowApiError(e.message);
        await _backoff(attempt);
      } on TimeoutException {
        if (attempt > _maxRetries) {
          throw const RoboflowApiError('Workflow request timed out');
        }
        await _backoff(attempt);
      }
    }
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
  };

  /// Exponential backoff: 500ms, 1s, 2s, ...
  Future<void> _backoff(int attempt) async {
    final delay = Duration(milliseconds: 500 * (1 << (attempt - 1)));
    await Future.delayed(delay);
  }

  /// Parses the workflow response defensively. Roboflow's MCP runner returns
  /// an array (one entry per input image), while the serverless REST endpoint
  /// returns that single entry directly. Both entries are keyed by the
  /// workflow's output names.
  RoboflowResult _parseResponse(String body) {
    final Object decoded;
    try {
      decoded = jsonDecode(body);
    } catch (e) {
      throw RoboflowParseError('Response is not valid JSON: $e');
    }

    final Map<String, dynamic> entry;
    switch (decoded) {
      case final List<dynamic> entries:
        if (entries.isEmpty) {
          throw const RoboflowParseError('Response array is empty');
        }
        if (entries.first is! Map<String, dynamic>) {
          throw const RoboflowParseError('Response array entry is not an object');
        }
        entry = entries.first as Map<String, dynamic>;
      case final Map<String, dynamic> object:
        entry = object;
      default:
        throw RoboflowParseError(
          'Response must be an object or array, got ${decoded.runtimeType}',
        );
    }

    // The serverless REST endpoint wraps workflow outputs in `outputs` and
    // also includes a `profiler_trace`; MCP exposes the workflow entry
    // directly. Unwrap the REST envelope when present.
    final outputContainer = entry['outputs'];
    final Map<String, dynamic> outputEntry;
    switch (outputContainer) {
      case final Map<String, dynamic> outputs:
        outputEntry = outputs;
      case final List<dynamic> outputs
          when outputs.isNotEmpty && outputs.first is Map<String, dynamic>:
        outputEntry = outputs.first as Map<String, dynamic>;
      default:
        outputEntry = entry;
    }
    // The workflow's output is named "predictions" (from the workflow
    // definition), but we read it defensively in case the name changes.
    final predictionsOutput = _findKey(outputEntry, ['predictions']) as Map?;
    if (predictionsOutput == null) {
      throw RoboflowParseError(
        'No predictions output in response. Keys: ${outputEntry.keys.toList()}',
      );
    }

    final imageInfo = predictionsOutput['image'] as Map?;
    final imageWidth = (imageInfo?['width'] as num?)?.toInt() ?? 0;
    final imageHeight = (imageInfo?['height'] as num?)?.toInt() ?? 0;
    if (imageWidth == 0 || imageHeight == 0) {
      throw const RoboflowParseError('Missing image dimensions in response');
    }

    final preds = predictionsOutput['predictions'] as List?;
    if (preds == null) {
      throw const RoboflowParseError('No predictions list in response');
    }

    final detections = <RoboflowDetection>[];
    for (final p in preds) {
      final pred = p as Map;
      final x = (pred['x'] as num?)?.toDouble();
      final y = (pred['y'] as num?)?.toDouble();
      final w = (pred['width'] as num?)?.toDouble();
      final h = (pred['height'] as num?)?.toDouble();
      final conf = (pred['confidence'] as num?)?.toDouble();
      if (x == null || y == null || w == null || h == null || conf == null) {
        continue;
      }
      detections.add(RoboflowDetection(
        center: Offset(x / imageWidth, y / imageHeight),
        boxWidth: w,
        boxHeight: h,
        confidence: conf,
        className: (pred['class'] as String?) ?? 'fingerling',
      ));
    }

    return RoboflowResult(
      detections: detections,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
    );
  }

  /// Finds the first matching key in a map, case-insensitive. Used to read
  /// workflow outputs by name without hard-coding the exact casing.
  Object? _findKey(Map<String, dynamic> map, List<String> candidates) {
    for (final key in map.keys) {
      for (final candidate in candidates) {
        if (key.toLowerCase() == candidate.toLowerCase()) {
          return map[key];
        }
      }
    }
    return null;
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
/// because [CountEditor.analyse] cannot reach inherited widgets from where it
/// runs — it needs a direct reference to the detector.
RoboflowDetector? globalRoboflowDetector;

/// The Roboflow API key, baked in at compile time via `--dart-define`.
///
/// Pass it when building or running:
///
/// ```
/// flutter run --dart-define=ROBOFLOW_API_KEY=your_key_here
/// ```
///
/// Get a key at app.roboflow.com/settings/api. When unset, the app falls back
/// to the on-device YOLO model.
const _roboflowApiKey = String.fromEnvironment('ROBOFLOW_API_KEY');

/// Whether a Roboflow API key was provided at compile time.
bool get hasRoboflowApiKey => _roboflowApiKey.isNotEmpty;

/// The compiled-in Roboflow API key, or null if not provided.
String? get roboflowApiKey =>
    _roboflowApiKey.isEmpty ? null : _roboflowApiKey;
