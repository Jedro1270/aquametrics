import 'package:flutter/material.dart';

/// Species commonly moved as fingerlings in local hatcheries.
enum Species {
  tilapia('Tilapia', Color(0xFF2E7D6F)),
  bangus('Bangus', Color(0xFF3A6DA6)),
  hito('Hito', Color(0xFF7A5B36)),
  sugpo('Sugpo', Color(0xFFB4552E));

  const Species(this.label, this.tint);

  final String label;
  final Color tint;
}

/// One counting session: a captured frame, what the detector found, and any
/// correction the operator applied on top of it.
@immutable
class CountBatch {
  const CountBatch({
    required this.id,
    required this.label,
    required this.species,
    required this.autoCount,
    required this.manualDelta,
    required this.capturedAt,
    required this.seed,
    this.note = '',
  });

  final String id;
  final String label;
  final Species species;

  /// What the detector reported before the operator touched it.
  final int autoCount;

  /// Operator correction. Positive means markers added, negative means removed.
  final int manualDelta;

  final DateTime capturedAt;

  /// Drives the mock tray render so a batch always looks the same.
  final int seed;

  final String note;

  int get total => autoCount + manualDelta;

  bool get wasCorrected => manualDelta != 0;
}
