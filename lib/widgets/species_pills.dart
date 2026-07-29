import 'package:flutter/material.dart';

import '../models/count_batch.dart';
import '../theme/app_theme.dart';

/// Horizontal species selector. Pills rather than a dropdown so the choice is
/// one tap and visible at a glance.
class SpeciesPills extends StatelessWidget {
  const SpeciesPills({
    super.key,
    required this.selected,
    required this.onChanged,
    this.dark = false,
  });

  final Species selected;
  final ValueChanged<Species> onChanged;

  /// Inverted palette for the viewfinder chrome.
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final s in Species.values)
          _Pill(
            species: s,
            active: s == selected,
            dark: dark,
            onTap: () => onChanged(s),
          ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.species,
    required this.active,
    required this.dark,
    required this.onTap,
  });

  final Species species;
  final bool active;
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final Color border;
    if (dark) {
      bg = active ? Colors.white : Colors.white.withValues(alpha: 0.10);
      fg = active ? AppColors.ink : Colors.white;
      border = active ? Colors.white : Colors.white.withValues(alpha: 0.22);
    } else {
      bg = active ? AppColors.tealSoft : AppColors.surface;
      fg = active ? AppColors.tealDeep : AppColors.inkSoft;
      border = active ? AppColors.teal : AppColors.line;
    }

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border, width: active ? 1.5 : 1.2),
          ),
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
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
