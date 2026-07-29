import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';
import '../widgets/batch_tile.dart';
import '../widgets/count_widgets.dart';
import 'batch_detail_screen.dart';
import 'capture_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onSeeAll});

  /// Switches the shell to the History tab.
  final VoidCallback onSeeAll;

  void _startCount(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CaptureScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListenableBuilder(
          listenable: batchStore,
          builder: (context, _) {
            final recent = batchStore.batches.take(4).toList();
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 116),
              children: [
                const _Masthead(),
                const SizedBox(height: 18),
                HeroCountCard(
                  total: batchStore.todayTotal,
                  sessions: batchStore.todayCounts,
                  lastAt: batchStore.lastCapture,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        label: 'Last 7 days',
                        value: batchStore.weekTotal,
                        footnote: 'across all species',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatTile(
                        label: 'All time',
                        value: batchStore.allTimeTotal,
                        footnote: '${batchStore.batches.length} counts',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SectionHeader(
                  title: 'Recent counts',
                  actionLabel: recent.isEmpty ? null : 'See all',
                  onAction: onSeeAll,
                ),
                const SizedBox(height: 4),
                if (recent.isEmpty)
                  const EmptyState(
                    title: 'No counts yet',
                    body: 'Photograph a tray of fingerlings and the count lands '
                        'here, ready to check.',
                    icon: Icons.center_focus_strong_outlined,
                  )
                else
                  for (final batch in recent)
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
              ],
            );
          },
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            ignoring: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 26, 16, 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.shell.withValues(alpha: 0),
                    AppColors.shell,
                    AppColors.shell,
                  ],
                ),
              ),
              child: HiVisButton(
                label: 'Count fingerlings',
                icon: Icons.center_focus_strong_rounded,
                onPressed: () => _startCount(context),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Masthead extends StatelessWidget {
  const _Masthead();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.teal,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.waves_rounded, color: Colors.white, size: 21),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('AquaMetrics', style: text.titleLarge),
            Text(
              'Fingerling counter',
              style: text.bodySmall?.copyWith(color: AppColors.inkFaint),
            ),
          ],
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.line),
          ),
          child: Text(
            _dateLabel(DateTime.now()),
            style: text.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.inkSoft,
            ),
          ),
        ),
      ],
    );
  }

  static String _dateLabel(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day} ${months[d.month - 1]}';
  }
}
