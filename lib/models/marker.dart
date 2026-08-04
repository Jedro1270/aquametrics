import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';

/// One ring drawn over a frame. Normalised to 0..1 like everything else that
/// describes a position in a frame.
@immutable
class Marker {
  const Marker({required this.p, this.manual = false});

  final Offset p;

  /// True when the operator placed this marker by hand rather than the detector.
  final bool manual;
}
