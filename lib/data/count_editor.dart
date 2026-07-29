import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../widgets/fish_field.dart';

/// Mutable state of a count under review: the detector's threshold plus every
/// correction the operator has made.
///
/// This lives outside the screen so the inline frame and the expanded viewer
/// edit one shared count instead of two copies that drift apart.
class CountEditor extends ChangeNotifier {
  CountEditor({required this.tray, double sensitivity = 0.72})
    : _sensitivity = sensitivity;

  final FishField tray;

  double _sensitivity;
  final Set<int> _rejected = <int>{};
  final List<FishSpot> _manual = <FishSpot>[];

  double get sensitivity => _sensitivity;

  set sensitivity(double value) {
    if (value == _sensitivity) return;
    _sensitivity = value;
    notifyListeners();
  }

  /// Sensitivity maps to a minimum blob size, which is how an area filter on a
  /// thresholded mask actually behaves: raise it and small or partly hidden fish
  /// drop out.
  double get _minSize => 1.0 - _sensitivity * 0.45;

  List<int> get _detected => [
    for (var i = 0; i < tray.spots.length; i++)
      if (tray.spots[i].size >= _minSize) i,
  ];

  List<int> get _kept => _detected.where((i) => !_rejected.contains(i)).toList();

  int get autoCount => _detected.length;
  int get removed => autoCount - _kept.length;
  int get added => _manual.length;
  int get total => _kept.length + added;
  int get manualDelta => added - removed;
  bool get edited => added > 0 || removed > 0;

  List<FishSpot> get markers => [
    for (final i in _kept) tray.spots[i],
    ..._manual,
  ];

  String get sensitivityLabel => switch (_sensitivity) {
    < 0.36 => 'Strict',
    < 0.72 => 'Balanced',
    _ => 'Inclusive',
  };

  /// Drops the nearest marker under [n], or drops a new one there if the tap
  /// landed on open water. [n] is normalised to 0..1.
  void tapAt(Offset n) {
    final hit = tray.spacing * 0.72;

    for (var i = _manual.length - 1; i >= 0; i--) {
      if ((_manual[i].p - n).distance < hit) {
        _manual.removeAt(i);
        notifyListeners();
        return;
      }
    }

    int? nearest;
    var best = hit;
    for (final i in _kept) {
      final d = (tray.spots[i].p - n).distance;
      if (d < best) {
        best = d;
        nearest = i;
      }
    }

    if (nearest != null) {
      _rejected.add(nearest);
    } else {
      _manual.add(FishSpot(p: n, angle: 0, size: 1, manual: true));
    }
    notifyListeners();
  }

  void clearEdits() {
    if (!edited) return;
    _rejected.clear();
    _manual.clear();
    notifyListeners();
  }
}
