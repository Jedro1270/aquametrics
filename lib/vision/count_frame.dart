import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../models/fish_field.dart';
import 'gray_image.dart';
import 'tray_raster.dart';

/// The frame a count is made from: something to show the operator, and the
/// pixels the detector reads.
///
/// A simulated tray and a photograph differ only in where the pixels come from,
/// so everything downstream — detection, correction, the marker overlay — is
/// written once against this.
sealed class CountFrame {
  /// Aspect ratio (width over height) of the pixels the detector analyses and
  /// the image the operator sees. A marker is normalised to 0..1 against this,
  /// so the display box has to match it or the marker drifts off its fish.
  ///
  /// The simulator renders at 4:3. A photograph keeps its native aspect —
  /// centre-cropping a portrait tray to 4:3 landscape throws away most of the
  /// fish, so the photo is analysed and shown at whatever ratio it was taken.
  double get aspect;

  /// Long-side target the detector works at.
  ///
  /// A tray photo holds a few hundred fingerlings, which at this width are
  /// around twenty pixels long: enough for a body to survive a 3x3 opening and
  /// for its distance ridge to be worth measuring, while keeping a pass down to
  /// tens of milliseconds. Analysing a 12-megapixel original would cost a
  /// hundred times as much and find the same fish.
  static const analysisLongSide = 720;

  /// Luma pixels for the classical detector. Kept for the simulator, which has
  /// no encoded bytes to hand to YOLO.
  GrayImage get pixels;

  /// Encoded image bytes (JPEG/PNG) for the YOLO detector, or null for a
  /// simulated frame that has no encoding. When null, the caller falls back to
  /// [pixels] — which only happens in tests against the simulator.
  Uint8List? get encodedBytes;

  /// Pixel dimensions of the encoded image, for YOLO's preprocessing. Matches
  /// [encodedBytes] when present, otherwise [pixels].
  int get pixelWidth;
  int get pixelHeight;
}

/// A simulated capture: a tray rendered from a seed rather than photographed.
///
/// Kept because it is the only way to exercise the whole path — including on a
/// desktop with no camera and no photos — and because a seed reproduces a frame
/// exactly, which a photograph cannot.
final class SimulatedFrame extends CountFrame {
  SimulatedFrame(this.field);

  SimulatedFrame.seeded({required int seed, int fish = 268})
    : field = FishField.generate(seed: seed, count: fish);

  final FishField field;

  @override
  double get aspect => 4 / 3;

  @override
  Uint8List? get encodedBytes => null;

  @override
  int get pixelWidth => pixels.width;

  @override
  int get pixelHeight => pixels.height;

  /// Rasterised on first use. Thumbnails and the viewfinder preview draw the
  /// field directly and never ask for pixels, so they pay nothing for this.
  @override
  late final GrayImage pixels = rasteriseTray(
    field,
    width: CountFrame.analysisLongSide,
  );
}

/// A real photograph.
final class PhotoFrame extends CountFrame {
  PhotoFrame({
    required this.image,
    required this.pixels,
    required this.encodedBytes,
    required this.pixelWidth,
    required this.pixelHeight,
  });

  /// Decoded for display, at [_displayWidth] rather than full size.
  final ui.Image image;

  @override
  final GrayImage pixels;

  /// The original encoded bytes (JPEG/PNG), kept for the YOLO detector which
  /// decodes internally.
  @override
  final Uint8List encodedBytes;

  @override
  final int pixelWidth;

  @override
  final int pixelHeight;

  @override
  double get aspect => image.width / image.height;

  /// Big enough to hold up when zoomed into a clump, small enough not to hand
  /// the GPU a 12-megapixel texture on a budget phone.
  static const _displayWidth = 1600;

  /// Decodes [bytes] once, then derives the detector's copy from the same
  /// decode: one pass over the pixels rather than two.
  static Future<PhotoFrame> decode(Uint8List bytes) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    final originalWidth = descriptor.width;
    final originalHeight = descriptor.height;
    final codec = await descriptor.instantiateCodec(
      // Only ever scaling down: asking for more pixels than the photo has would
      // invent detail and slow the decode for nothing.
      targetWidth: math.min(originalWidth, _displayWidth),
    );
    final frame = await codec.getNextFrame();
    descriptor.dispose();

    final image = frame.image;
    final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final gray = GrayImage.fromRgba(
      rgba!.buffer.asUint8List(),
      image.width,
      image.height,
    );

    // Downsample on the long side so portrait and landscape frames cost the
    // same number of pixels. No aspect crop: a portrait tray centre-cropped to
    // 4:3 loses most of its fish, and a marker normalised to the full frame
    // lands on the fish it was found on as long as the display box matches the
    // photo's own aspect.
    final longSide = math.max(image.width, image.height);
    final factor = math.max(
      1,
      (longSide / CountFrame.analysisLongSide).round(),
    );
    return PhotoFrame(
      image: image,
      pixels: gray.downsampled(factor),
      encodedBytes: bytes,
      pixelWidth: originalWidth,
      pixelHeight: originalHeight,
    );
  }
}
