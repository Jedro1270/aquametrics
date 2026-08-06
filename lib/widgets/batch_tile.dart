import 'package:flutter/material.dart';

import '../data/batch_store.dart';
import '../data/frame_cache.dart';
import '../models/count_batch.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';
import 'count_widgets.dart';
import 'fish_field.dart';

/// One saved count. The number is right-aligned and tabular so a column of
/// these can be compared by eye without reading labels.
class BatchTile extends StatelessWidget {
  const BatchTile({
    super.key,
    required this.store,
    required this.batch,
    required this.onTap,
    this.showTime = true,
  });

  final BatchStore store;
  final CountBatch batch;
  final VoidCallback onTap;
  final bool showTime;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              _SavedThumbnail(store: store, batch: batch),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      batch.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleMedium,
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Flexible(
                          child: SpeciesTag(
                            label: batch.species.label,
                            tint: batch.species.tint,
                          ),
                        ),
                        if (showTime)
                          Flexible(
                            child: Text(
                              '  ·  ${clockTime(batch.capturedAt)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodySmall,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      thousands(batch.total),
                      style: text.displaySmall?.copyWith(fontSize: 24),
                    ),
                  ),
                  if (batch.wasCorrected) ...[
                    const SizedBox(height: 5),
                    CorrectedChip(delta: batch.manualDelta),
                  ],
                ],
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.inkFaint,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedThumbnail extends StatefulWidget {
  const _SavedThumbnail({required this.store, required this.batch});

  final BatchStore store;
  final CountBatch batch;

  @override
  State<_SavedThumbnail> createState() => _SavedThumbnailState();
}

class _SavedThumbnailState extends State<_SavedThumbnail> {
  late Future<SavedFrame?> _frame = widget.store.loadFrame(widget.batch.id);

  @override
  void didUpdateWidget(_SavedThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store ||
        oldWidget.batch.id != widget.batch.id) {
      _frame = widget.store.loadFrame(widget.batch.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SavedFrame?>(
      future: _frame,
      builder: (context, snapshot) {
        final saved = snapshot.data;
        if (saved == null) return TrayThumb(seed: widget.batch.seed);
        return SizedBox.square(
          dimension: 54,
          child: CountFrameView(
            key: ValueKey('saved-thumbnail-${widget.batch.id}'),
            frame: saved.frame,
            radius: AppRadius.thumb,
          ),
        );
      },
    );
  }
}

/// Shown when there is genuinely nothing to list.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.body,
    this.icon = Icons.water_outlined,
  });

  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: AppColors.tealSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.teal, size: 26),
          ),
          const SizedBox(height: 16),
          Text(title, style: text.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(
            body,
            style: text.bodyMedium?.copyWith(color: AppColors.inkSoft),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
