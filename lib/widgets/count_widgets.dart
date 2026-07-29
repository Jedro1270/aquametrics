import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../util/format.dart';

/// Small all-caps label. Used sparingly, above numbers and section groups.
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: color ?? AppColors.inkFaint,
      ),
    );
  }
}

/// Counts up to [value]. The only motion on the home screen: it exists to show
/// the number settling, not to decorate.
class AnimatedCount extends StatelessWidget {
  const AnimatedCount({
    super.key,
    required this.value,
    required this.style,
    this.duration = const Duration(milliseconds: 700),
  });

  final int value;
  final TextStyle? style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(thousands(v.round()), style: style),
    );
  }
}

class _WaterLine extends CustomPainter {
  const _WaterLine();

  @override
  void paint(Canvas canvas, Size size) {
    for (var band = 0; band < 2; band++) {
      final amp = size.height * (0.035 + band * 0.02);
      final baseY = size.height * (0.72 + band * 0.13);
      final phase = band * 1.9;
      final path = Path()..moveTo(0, baseY);
      for (var x = 0.0; x <= size.width; x += 6) {
        final t = x / size.width * math.pi * 2.1 + phase;
        path.lineTo(x, baseY + math.sin(t) * amp);
      }
      path
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(
        path,
        Paint()..color = Colors.white.withValues(alpha: band == 0 ? 0.05 : 0.07),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaterLine oldDelegate) => false;
}

/// Anchor of the home screen: today's running total on a deep-teal slab so the
/// number owns the top of the page without a chart or fake trend badge.
class HeroCountCard extends StatelessWidget {
  const HeroCountCard({
    super.key,
    required this.total,
    required this.sessions,
    required this.lastAt,
  });

  final int total;
  final int sessions;
  final DateTime? lastAt;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final footer = switch ((sessions, lastAt)) {
      (0, _) => 'Nothing counted yet today',
      (final n, final DateTime at) =>
        '$n ${n == 1 ? 'count' : 'counts'}  ·  last at ${clockTime(at)}',
      (final n, _) => '$n ${n == 1 ? 'count' : 'counts'}',
    };

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card + 4),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.teal, AppColors.tealDeep],
          ),
        ),
        child: Stack(
          children: [
            const Positioned.fill(child: CustomPaint(painter: _WaterLine())),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Eyebrow('Today', color: Colors.white.withValues(alpha: 0.62)),
                  const SizedBox(height: 12),
                  // Bottom-aligned rather than baseline-aligned so the number
                  // can sit in a FittedBox: a five-figure total, or a large
                  // system font scale, scales down instead of overflowing.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.bottomLeft,
                          child: AnimatedCount(
                            value: total,
                            style: text.displayLarge?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'fingerlings',
                          style: text.bodyLarge?.copyWith(
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    footer,
                    style: text.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.66),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Outlined secondary metric. Two of these sit under the hero card.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.footnote,
  });

  final String label;
  final int value;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow(label),
          const SizedBox(height: 8),
          Text(thousands(value), style: text.displaySmall),
          if (footnote != null) ...[
            const SizedBox(height: 4),
            Text(
              footnote!,
              style: text.bodySmall?.copyWith(color: AppColors.inkFaint),
            ),
          ],
        ],
      ),
    );
  }
}

/// Section heading with an optional trailing text action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.teal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: const Size(0, 40),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              actionLabel!,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
      ],
    );
  }
}

/// Species dot + name, so a row is scannable without reading the label.
class SpeciesTag extends StatelessWidget {
  const SpeciesTag({super.key, required this.label, required this.tint});

  final String label;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

/// Ring swatch + tally, tying a number back to the markers on the frame.
class MarkerLegend extends StatelessWidget {
  const MarkerLegend({
    super.key,
    required this.color,
    required this.label,
    required this.value,
    this.dark = false,
  });

  final Color color;
  final String label;
  final int value;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  thousands(value),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleMedium?.copyWith(
                    color: dark ? Colors.white : AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall?.copyWith(
              fontSize: 11.5,
              color: dark
                  ? Colors.white.withValues(alpha: 0.6)
                  : AppColors.inkFaint,
            ),
          ),
        ],
      ),
    );
  }
}

/// Marks a batch the operator edited. Trust signal, not decoration.
class CorrectedChip extends StatelessWidget {
  const CorrectedChip({super.key, required this.delta});

  final int delta;

  @override
  Widget build(BuildContext context) {
    final positive = delta > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceSunk,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '${positive ? '+' : '−'}${delta.abs()} by hand',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: AppColors.inkSoft,
        ),
      ),
    );
  }
}
