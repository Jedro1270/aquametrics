import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/fish_field.dart';
import '../models/marker.dart';
import '../theme/app_theme.dart';
import '../vision/count_frame.dart';

/// Draws a simulated tray.
///
/// Geometry here and in `vision/tray_raster.dart` describe the same fish: this
/// one for the operator, the other for the detector. A marker found in the
/// rasterised copy is drawn over this one, so the two have to agree.
class _FishPainter extends CustomPainter {
  const _FishPainter({required this.field});

  final FishField field;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.25, -0.45),
          radius: 1.25,
          colors: [Color(0xFF17332E), AppColors.water],
        ).createShader(rect),
    );

    final base = math.min(size.width, size.height);
    final len = base * field.spacing * FishField.bodyLength;
    final body = Paint();
    final eye = Paint()..color = const Color(0xFF0A1412);

    for (final s in field.spots) {
      final len2 = len * s.size;
      canvas.save();
      canvas.translate(s.p.dx * size.width, s.p.dy * size.height);
      canvas.rotate(s.angle);
      body.color = Color.lerp(
        const Color(0xFF93ADA7),
        const Color(0xFFE8F0ED),
        s.size,
      )!;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: len2,
          height: len2 * 0.34,
        ),
        body,
      );
      canvas.drawPath(
        Path()
          ..moveTo(-len2 * 0.42, 0)
          ..lineTo(-len2 * 0.70, -len2 * 0.19)
          ..lineTo(-len2 * 0.70, len2 * 0.19)
          ..close(),
        body,
      );
      if (len2 > 9) {
        canvas.drawCircle(
          Offset(len2 * 0.29, -len2 * 0.02),
          len2 * 0.05,
          eye,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _FishPainter old) => old.field != field;
}

class _MarkerPainter extends CustomPainter {
  const _MarkerPainter({
    required this.markers,
    required this.ringRadius,
    required this.progress,
  });

  final List<Marker> markers;

  /// In short-side units, measured by the detector from the fish it found.
  final double ringRadius;

  /// 0..1 sweep so markers land in sequence, reading as work being done rather
  /// than decoration.
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (markers.isEmpty || progress <= 0) return;
    final r = math.min(size.width, size.height) * ringRadius;
    final shown = (markers.length * progress).ceil();

    final halo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..color = const Color(0x66000000);
    final auto = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..color = AppColors.hiVis;
    final manual = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = const Color(0xFF3BE38F);

    for (var i = 0; i < shown; i++) {
      final m = markers[i];
      final c = Offset(m.p.dx * size.width, m.p.dy * size.height);
      canvas.drawCircle(c, r, halo);
      canvas.drawCircle(c, r, m.manual ? manual : auto);
      if (m.manual) {
        canvas.drawCircle(c, 1.6, Paint()..color = const Color(0xFF3BE38F));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MarkerPainter old) =>
      old.markers != markers ||
      old.progress != progress ||
      old.ringRadius != ringRadius;
}

/// A frame with its markers over the top.
///
/// The frame underneath is either a rendered tray or a photograph; everything
/// above it — rings, taps, zoom — is the same either way.
class CountFrameView extends StatelessWidget {
  const CountFrameView({
    super.key,
    required this.frame,
    this.markers = const [],
    this.ringRadius = 0.02,
    this.markerProgress = 1,
    this.radius = AppRadius.card,
    this.onTapNormalised,
  });

  final CountFrame frame;
  final List<Marker> markers;
  final double ringRadius;
  final double markerProgress;
  final double radius;

  /// Reports taps in 0..1 space so callers can add or remove markers.
  final ValueChanged<Offset>? onTapNormalised;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            // onTapUp rather than onTapDown: a tap must win the gesture arena
            // first, so panning a zoomed frame cannot drop a phantom marker.
            onTapUp: onTapNormalised == null
                ? null
                : (details) => onTapNormalised!(
                    Offset(
                      details.localPosition.dx / constraints.maxWidth,
                      details.localPosition.dy / constraints.maxHeight,
                    ),
                  ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                switch (frame) {
                  SimulatedFrame(:final field) => CustomPaint(
                    painter: _FishPainter(field: field),
                  ),
                  // Fill the box, which matches the photo's own aspect — no
                  // centre crop, so every fish the detector saw is shown.
                  PhotoFrame(:final image) => RawImage(
                    image: image,
                    fit: BoxFit.fill,
                  ),
                },
                CustomPaint(
                  painter: _MarkerPainter(
                    markers: markers,
                    ringRadius: ringRadius,
                    progress: markerProgress,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Small square preview for list rows. Uses a thinned field so tiles stay cheap
/// to paint while scrolling.
class TrayThumb extends StatelessWidget {
  const TrayThumb({super.key, required this.seed, this.size = 54});

  final int seed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CountFrameView(
        frame: SimulatedFrame.seeded(seed: seed, fish: 26),
        radius: AppRadius.thumb,
      ),
    );
  }
}
