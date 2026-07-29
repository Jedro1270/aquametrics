import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../models/count_batch.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';
import '../widgets/batch_tile.dart';
import '../widgets/count_widgets.dart';
import 'batch_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  /// null means "All species".
  Species? _filter;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return ListenableBuilder(
      listenable: batchStore,
      builder: (context, _) {
        final days = [
          for (final (day, items) in batchStore.byDay)
            (
              day,
              _filter == null
                  ? items
                  : items.where((b) => b.species == _filter).toList(),
            ),
        ].where((entry) => entry.$2.isNotEmpty).toList();

        final shownTotal = days.fold(
          0,
          (acc, entry) => acc + entry.$2.fold(0, (a, b) => a + b.total),
        );

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('History', style: text.headlineMedium),
                const Spacer(),
                Text(
                  '${thousands(shownTotal)} counted',
                  style: text.bodyMedium?.copyWith(color: AppColors.inkSoft),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _FilterRow(
              selected: _filter,
              onChanged: (s) => setState(() => _filter = s),
            ),
            const SizedBox(height: 18),
            if (days.isEmpty)
              const EmptyState(
                title: 'Nothing here',
                body: 'No counts match this species yet.',
                icon: Icons.filter_alt_outlined,
              )
            else
              for (final (day, items) in days) ...[
                _DayHeader(
                  day: day,
                  total: items.fold(0, (a, b) => a + b.total),
                  counts: items.length,
                ),
                const SizedBox(height: 10),
                for (final batch in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: BatchTile(
                      batch: batch,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => BatchDetailScreen(batch: batch),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
              ],
          ],
        );
      },
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.selected, required this.onChanged});

  final Species? selected;
  final ValueChanged<Species?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          _Chip(
            label: 'All',
            active: selected == null,
            onTap: () => onChanged(null),
          ),
          for (final s in Species.values) ...[
            const SizedBox(width: 8),
            _Chip(
              label: s.label,
              tint: s.tint,
              active: selected == s,
              onTap: () => onChanged(s),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.active,
    required this.onTap,
    this.tint,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.tealSoft : AppColors.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active ? AppColors.teal : AppColors.line,
              width: active ? 1.5 : 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (tint != null) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: tint,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: active ? AppColors.tealDeep : AppColors.inkSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.day,
    required this.total,
    required this.counts,
  });

  final DateTime day;
  final int total;
  final int counts;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Eyebrow(relativeDay(day), color: AppColors.inkSoft),
        const SizedBox(width: 10),
        const Expanded(child: Divider(height: 1, color: AppColors.line)),
        const SizedBox(width: 10),
        Text(
          '${thousands(total)}  ·  $counts ${counts == 1 ? 'count' : 'counts'}',
          style: text.bodySmall?.copyWith(color: AppColors.inkFaint),
        ),
      ],
    );
  }
}
