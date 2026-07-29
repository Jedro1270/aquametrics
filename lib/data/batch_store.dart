import 'package:flutter/foundation.dart';

import '../models/count_batch.dart';

/// In-memory store for the UI pass. Swap the body of these methods for sqflite
/// when persistence lands; the screens only talk to this interface.
class BatchStore extends ChangeNotifier {
  BatchStore(List<CountBatch> seed) : _batches = [...seed];

  final List<CountBatch> _batches;

  /// Newest first.
  List<CountBatch> get batches {
    final sorted = [..._batches]
      ..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    return List.unmodifiable(sorted);
  }

  void add(CountBatch batch) {
    _batches.add(batch);
    notifyListeners();
  }

  void remove(String id) {
    _batches.removeWhere((b) => b.id == id);
    notifyListeners();
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  int _sum(Iterable<CountBatch> items) =>
      items.fold(0, (acc, b) => acc + b.total);

  int get todayTotal {
    final now = DateTime.now();
    return _sum(_batches.where((b) => _sameDay(b.capturedAt, now)));
  }

  int get todayCounts =>
      _batches.where((b) => _sameDay(b.capturedAt, DateTime.now())).length;

  DateTime? get lastCapture {
    if (_batches.isEmpty) return null;
    return batches.first.capturedAt;
  }

  int get weekTotal {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    return _sum(_batches.where((b) => b.capturedAt.isAfter(cutoff)));
  }

  int get allTimeTotal => _sum(_batches);

  /// Batches grouped into day buckets, newest day first.
  List<(DateTime, List<CountBatch>)> get byDay {
    final buckets = <DateTime, List<CountBatch>>{};
    for (final b in batches) {
      final key = DateTime(
        b.capturedAt.year,
        b.capturedAt.month,
        b.capturedAt.day,
      );
      buckets.putIfAbsent(key, () => []).add(b);
    }
    final keys = buckets.keys.toList()..sort((a, b) => b.compareTo(a));
    return [for (final k in keys) (k, buckets[k]!)];
  }
}
