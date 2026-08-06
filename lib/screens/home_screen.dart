import 'package:flutter/material.dart';

import '../data/batch_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';
import '../widgets/batch_tile.dart';
import '../widgets/count_widgets.dart';
import 'batch_detail_screen.dart';
import 'capture_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.store,
    required this.onSeeAll,
    this.pickImage,
  });

  final BatchStore store;

  /// Switches the shell to the History tab.
  final VoidCallback onSeeAll;
  final ImagePickerCallback? pickImage;

  void _startCount(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CaptureScreen(store: store, pickImage: pickImage),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            final recent = store.batches.take(4).toList();
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 116),
              children: [
                const _Masthead(),
                const SizedBox(height: 18),
                HeroCountCard(
                  total: store.todayTotal,
                  sessions: store.todayCounts,
                  lastAt: store.lastCapture,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        label: 'Last 7 days',
                        value: store.weekTotal,
                        footnote: 'across all species',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatTile(
                        label: 'All time',
                        value: store.allTimeTotal,
                        footnote: '${store.batches.length} counts',
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
                    body:
                        'Photograph a tray of fingerlings and the count lands '
                        'here, ready to check.',
                    icon: Icons.center_focus_strong_outlined,
                  )
                else
                  for (final batch in recent)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: BatchTile(
                        store: store,
                        batch: batch,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                BatchDetailScreen(store: store, batch: batch),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The fade must not take pointer events, or it silently swallows
              // taps on the list tile scrolling underneath it.
              IgnorePointer(
                child: Container(
                  height: 28,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.shell.withValues(alpha: 0),
                        AppColors.shell,
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                color: AppColors.shell,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: HiVisButton(
                  label: 'Count fingerlings',
                  icon: Icons.center_focus_strong_rounded,
                  onPressed: () => _startCount(context),
                ),
              ),
            ],
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
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AquaMetrics',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.titleLarge,
              ),
              Text(
                'Fingerling counter',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall?.copyWith(color: AppColors.inkFaint),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
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
