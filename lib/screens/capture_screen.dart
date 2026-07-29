import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/count_batch.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';
import '../widgets/fish_field.dart';
import '../widgets/species_pills.dart';
import 'review_screen.dart';

/// Framing step. Dark by necessity, not for style: the surrounding chrome should
/// disappear so the operator judges the water, and glare off a white UI would
/// wash out the preview.
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key, this.species = Species.tilapia});

  final Species species;

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  late Species _species = widget.species;
  bool _torch = false;
  bool _grid = true;
  bool _speciesOpen = false;

  /// Stands in for the live preview until the camera plugin is wired up.
  final FishField _preview = FishField.generate(seed: 20740, count: 268);

  void _capture() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReviewScreen(
          seed: DateTime.now().millisecondsSinceEpoch % 100000,
          species: _species,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.water,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                child: Row(
                  children: [
                    ViewfinderIconButton(
                      icon: Icons.close_rounded,
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Cancel',
                    ),
                    const Spacer(),
                    Text(
                      'Frame the tray',
                      style: text.titleMedium?.copyWith(color: Colors.white),
                    ),
                    const Spacer(),
                    ViewfinderIconButton(
                      icon: _grid
                          ? Icons.grid_on_rounded
                          : Icons.grid_off_rounded,
                      active: false,
                      onPressed: () => setState(() => _grid = !_grid),
                      tooltip: 'Guide grid',
                    ),
                    const SizedBox(width: 8),
                    ViewfinderIconButton(
                      icon: _torch
                          ? Icons.flashlight_on_rounded
                          : Icons.flashlight_off_rounded,
                      active: _torch,
                      onPressed: () => setState(() => _torch = !_torch),
                      tooltip: 'Light',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: MockTrayImage(field: _preview, radius: 20),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _FramingPainter(showGrid: _grid),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 14,
                        child: Center(child: const _HintPill()),
                      ),
                      const Positioned(top: 14, left: 14, child: _SimBadge()),
                    ],
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                child: _speciesOpen
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                        child: SpeciesPills(
                          selected: _species,
                          dark: true,
                          onChanged: (s) => setState(() {
                            _species = s;
                            _speciesOpen = false;
                          }),
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _SpeciesButton(
                          species: _species,
                          onTap: () =>
                              setState(() => _speciesOpen = !_speciesOpen),
                        ),
                      ),
                    ),
                    _Shutter(onPressed: _capture),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: ViewfinderIconButton(
                          icon: Icons.photo_library_outlined,
                          onPressed: _capture,
                          tooltip: 'Choose a photo',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Corner brackets plus an optional thirds grid. Brackets rather than a full
/// rectangle so the operator's eye stays on the water, not on a border.
class _FramingPainter extends CustomPainter {
  const _FramingPainter({required this.showGrid});

  final bool showGrid;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 18.0;
    final arm = math.min(size.width, size.height) * 0.07;
    final stroke = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final l = inset, t = inset;
    final r = size.width - inset, b = size.height - inset;

    for (final (corner, dx, dy) in [
      (Offset(l, t), 1.0, 1.0),
      (Offset(r, t), -1.0, 1.0),
      (Offset(l, b), 1.0, -1.0),
      (Offset(r, b), -1.0, -1.0),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(corner.dx + dx * arm, corner.dy)
          ..lineTo(corner.dx, corner.dy)
          ..lineTo(corner.dx, corner.dy + dy * arm),
        stroke,
      );
    }

    if (!showGrid) return;
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      final x = l + (r - l) * i / 3;
      final y = t + (b - t) * i / 3;
      canvas.drawLine(Offset(x, t), Offset(x, b), grid);
      canvas.drawLine(Offset(l, y), Offset(r, y), grid);
    }
  }

  @override
  bool shouldRepaint(covariant _FramingPainter old) =>
      old.showGrid != showGrid;
}

class _HintPill extends StatelessWidget {
  const _HintPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wb_sunny_outlined, size: 15, color: Colors.white),
          SizedBox(width: 7),
          Text(
            'Hold the tray flat  ·  keep your shadow out',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Honest label: nothing behind this is a real camera feed yet.
class _SimBadge extends StatelessWidget {
  const _SimBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Text(
        'SIMULATED PREVIEW',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.85),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _SpeciesButton extends StatelessWidget {
  const _SpeciesButton({required this.species, required this.onTap});

  final Species species;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: species.tint,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                species.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.expand_less_rounded,
                size: 18,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Shutter extends StatefulWidget {
  const _Shutter({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_Shutter> createState() => _ShutterState();
}

class _ShutterState extends State<_Shutter> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) {
        setState(() => _down = false);
        widget.onPressed();
      },
      child: Container(
        width: 82,
        height: 82,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
        ),
        child: Center(
          child: AnimatedScale(
            scale: _down ? 0.88 : 1,
            duration: const Duration(milliseconds: 110),
            child: Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.hiVis,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.center_focus_strong_rounded,
                color: AppColors.hiVisInk,
                size: 26,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
