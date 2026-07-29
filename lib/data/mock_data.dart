import '../models/count_batch.dart';
import 'batch_store.dart';

DateTime _at(int daysAgo, int hour, int minute) {
  final now = DateTime.now();
  final day = DateTime(now.year, now.month, now.day).subtract(
    Duration(days: daysAgo),
  );
  return DateTime(day.year, day.month, day.day, hour, minute);
}

/// Counts sit in the low hundreds because that is what one tray photo actually
/// holds. Larger transfers are several frames, not one giant number.
final _mockBatches = <CountBatch>[
  CountBatch(
    id: 'b-1',
    label: 'Pond 3 transfer',
    species: Species.tilapia,
    autoCount: 236,
    manualDelta: 3,
    capturedAt: _at(0, 7, 42),
    seed: 1207,
    note: 'Second scoop. Two stuck to the tray wall, added by hand.',
  ),
  CountBatch(
    id: 'b-2',
    label: 'Pond 3 transfer',
    species: Species.tilapia,
    autoCount: 251,
    manualDelta: 0,
    capturedAt: _at(0, 8, 5),
    seed: 4419,
  ),
  CountBatch(
    id: 'b-3',
    label: 'Buyer sample — Delgado',
    species: Species.bangus,
    autoCount: 184,
    manualDelta: -2,
    capturedAt: _at(0, 10, 18),
    seed: 8802,
    note: 'Removed two glare spots on the water line.',
  ),
  CountBatch(
    id: 'b-4',
    label: 'Tank B stocking',
    species: Species.hito,
    autoCount: 312,
    manualDelta: 5,
    capturedAt: _at(1, 15, 30),
    seed: 3311,
  ),
  CountBatch(
    id: 'b-5',
    label: 'Tank B stocking',
    species: Species.hito,
    autoCount: 288,
    manualDelta: 0,
    capturedAt: _at(1, 15, 52),
    seed: 6754,
  ),
  CountBatch(
    id: 'b-6',
    label: 'Nursery audit',
    species: Species.sugpo,
    autoCount: 204,
    manualDelta: -6,
    capturedAt: _at(3, 9, 12),
    seed: 9128,
    note: 'Murky water, dropped the sensitivity a notch.',
  ),
  CountBatch(
    id: 'b-7',
    label: 'Nursery audit',
    species: Species.sugpo,
    autoCount: 197,
    manualDelta: 0,
    capturedAt: _at(4, 16, 40),
    seed: 5560,
  ),
];

final batchStore = BatchStore(_mockBatches);
