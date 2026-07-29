import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The single primary action in the app. Safety-orange slab with a darker
/// bottom edge so it still reads as a pressable object through glare and a
/// scratched screen protector, and tall enough to hit with a gloved thumb.
class HiVisButton extends StatelessWidget {
  const HiVisButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 58,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: enabled ? AppColors.hiVisEdge : AppColors.line,
        borderRadius: BorderRadius.circular(AppRadius.button),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Material(
          color: enabled ? AppColors.hiVis : AppColors.surfaceSunk,
          borderRadius: BorderRadius.circular(AppRadius.button),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(AppRadius.button),
            child: SizedBox(
              height: height,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: 22,
                      color: enabled ? AppColors.hiVisInk : AppColors.inkFaint,
                    ),
                    const SizedBox(width: 10),
                  ],
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: enabled ? AppColors.hiVisInk : AppColors.inkFaint,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Secondary action. Outlined, never competing with the hi-vis slab.
class QuietButton extends StatelessWidget {
  const QuietButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 52,
    this.danger = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final tint = danger ? AppColors.warn : AppColors.ink;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.button),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.button),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.line, width: 1.4),
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: tint),
                const SizedBox(width: 9),
              ],
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: tint,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Overlay affordance for opening a frame full-screen. Sits on the image itself
/// so the way to get a closer look is where the eye already is.
class ExpandChip extends StatelessWidget {
  const ExpandChip({super.key, required this.onTap, this.label = 'Expand'});

  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.open_in_full_rounded,
                size: 15,
                color: Colors.white,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Round icon button used on the dark viewfinder chrome.
class ViewfinderIconButton extends StatelessWidget {
  const ViewfinderIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.active = false,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool active;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: active ? AppColors.hiVis : Colors.white.withValues(alpha: 0.14),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox.square(
          dimension: 46,
          child: Icon(
            icon,
            size: 21,
            color: active ? AppColors.hiVisInk : Colors.white,
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
