import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A single fingerling in the mock frame. Positions are normalised to 0..1 so
/// the same field renders at any size, from a 56px thumbnail to a full screen.
@immutable
class FishSpot {
  const FishSpot({
    required this.p,
    required this.angle,
    required this.size,
    this.manual = false,
  });

  final Offset p;

  /// Heading in radians.
  final double angle;

  /// 0.55..1.0. Stands in for detector confidence: the sensitivity slider keeps
  /// or drops spots by this value, which is how a real area/threshold filter
  /// behaves on small or partly occluded fish.
  final double size;

  /// True when the operator placed this marker by hand.
  final bool manual;
}

/// A generated tray of fingerlings. Deterministic for a given seed so a saved
/// batch always renders identically.
@immutable
class FishField {
  const FishField({required this.spots, required this.spacing});

  final List<FishSpot> spots;

  /// Mean normalised distance between neighbours. Drives fish and marker sizing
  /// so a dense tray reads as small fish rather than overlapping blobs.
  final double spacing;

  static const _pad = 0.06;

  factory FishField.generate({required int seed, required int count}) {
    final rnd = math.Random(seed);
    const span = 1 - _pad * 2;
    final spacing = math.sqrt(span * span / math.max(count, 1));
    final minDist = spacing * 0.58;
    final spots = <FishSpot>[];
    var guard = 0;
    while (spots.length < count && guard < count * 80) {
      guard++;
      final p = Offset(
        _pad + rnd.nextDouble() * span,
        _pad + rnd.nextDouble() * span,
      );
      if (spots.any((s) => (s.p - p).distance < minDist)) continue;
      spots.add(
        FishSpot(
          p: p,
          angle: rnd.nextDouble() * math.pi * 2,
          size: 0.55 + rnd.nextDouble() * 0.45,
        ),
      );
    }
    return FishField(spots: spots, spacing: spacing);
  }
}

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
    final len = base * field.spacing * 0.92;
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
    required this.field,
    required this.markers,
    required this.progress,
  });

  final FishField field;
  final List<FishSpot> markers;

  /// 0..1 sweep so markers land in sequence, reading as work being done rather
  /// than decoration.
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (markers.isEmpty || progress <= 0) return;
    final base = math.min(size.width, size.height);
    final r = base * field.spacing * 0.5;
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
      if (m.manual) canvas.drawCircle(c, 1.6, Paint()..color = const Color(0xFF3BE38F));
    }
  }

  @override
  bool shouldRepaint(covariant _MarkerPainter old) =>
      old.markers != markers || old.progress != progress || old.field != field;
}

/// Stand-in for a captured frame. Swapping this for a real camera still later
/// means replacing the bottom layer only; the marker layer stays as-is.
class MockTrayImage extends StatelessWidget {
  const MockTrayImage({
    super.key,
    required this.field,
    this.markers = const [],
    this.markerProgress = 1,
    this.radius = AppRadius.card,
    this.onTapNormalised,
  });

  final FishField field;
  final List<FishSpot> markers;
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
            onTapDown: onTapNormalised == null
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
                CustomPaint(painter: _FishPainter(field: field)),
                CustomPaint(
                  painter: _MarkerPainter(
                    field: field,
                    markers: markers,
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
      child: MockTrayImage(
        field: FishField.generate(seed: seed, count: 26),
        radius: AppRadius.thumb,
      ),
    );
  }
}
