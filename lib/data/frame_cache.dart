import '../models/marker.dart';
import '../vision/count_frame.dart';

/// A saved count's frame, and what was marked on it.
class SavedFrame {
  const SavedFrame({
    required this.frame,
    required this.markers,
    required this.ringRadius,
  });

  final CountFrame frame;
  final List<Marker> markers;
  final double ringRadius;
}

/// Frames from counts saved during this session, held in memory.
///
/// Reopening a count should show the photograph it was made from with the rings
/// where they were left, and that needs the frame kept somewhere. This is the
/// stand-in until persistence lands and writes them to disk: counts saved this
/// session come back properly, and anything older — which today means the sample
/// history — falls back to a simulated render of its seed.
///
/// Deliberately small. A decoded photograph is a few megabytes, and holding
/// every one of a long day's counts would be worse than forgetting them.
class FrameCache {
  static const _keep = 5;

  final _frames = <String, SavedFrame>{};
  final _order = <String>[];

  SavedFrame? operator [](String batchId) => _frames[batchId];

  void put(String batchId, SavedFrame frame) {
    if (_frames.remove(batchId) != null) _order.remove(batchId);
    _frames[batchId] = frame;
    _order.add(batchId);
    while (_order.length > _keep) {
      _frames.remove(_order.removeAt(0));
    }
  }
}

final frameCache = FrameCache();
