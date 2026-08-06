import 'package:flutter/material.dart';

import '../data/batch_store.dart';
import '../data/frame_cache.dart';
import '../models/count_batch.dart';
import '../models/fish_field.dart';
import '../models/marker.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';
import '../vision/count_frame.dart';
import '../widgets/app_buttons.dart';
import '../widgets/count_widgets.dart';
import '../widgets/fish_field.dart';
import 'tray_viewer_screen.dart';

class BatchDetailScreen extends StatefulWidget {
  const BatchDetailScreen({
    super.key,
    required this.store,
    required this.batch,
  });

  final BatchStore store;
  final CountBatch batch;

  @override
  State<BatchDetailScreen> createState() => _BatchDetailScreenState();
}

class _BatchDetailScreenState extends State<BatchDetailScreen> {
  late final Future<SavedFrame> _savedFrame = _frame();

  CountBatch get batch => widget.batch;

  /// What to show for this count: the persisted photograph it was made from, or
  /// a simulated tray for legacy/test data that has no image.
  Future<SavedFrame> _frame() async {
    try {
      final saved = await widget.store.loadFrame(batch.id);
      if (saved != null) return saved;
    } catch (_) {}
    final field = FishField.generate(seed: batch.seed, count: batch.total);
    return SavedFrame(
      frame: SimulatedFrame(field),
      markers: [for (final spot in field.spots) Marker(p: spot.p)],
      ringRadius: FishField.markerRing,
    );
  }

  void _expand(BuildContext context, SavedFrame frame) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => TrayViewerScreen.readOnly(
          frame: frame.frame,
          markers: frame.markers,
          ringRadius: frame.ringRadius,
          title: batch.label,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete this count?'),
        content: Text(
          '${batch.label} · ${thousands(batch.total)} fingerlings. '
          'This cannot be undone.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(foregroundColor: AppColors.inkSoft),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.warn),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await widget.store.remove(batch.id);
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SavedFrame>(
      future: _savedFrame,
      builder: (context, snapshot) {
        final frame = snapshot.data;
        if (frame != null) return _content(context, frame);
        return const Scaffold(
          backgroundColor: AppColors.shell,
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }

  Widget _content(BuildContext context, SavedFrame frame) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.shell,
      appBar: AppBar(
        backgroundColor: AppColors.shell,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Count details', style: text.titleLarge),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          AspectRatio(
            aspectRatio: frame.frame.aspect,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CountFrameView(
                    frame: frame.frame,
                    markers: frame.markers,
                    ringRadius: frame.ringRadius,
                    onTapNormalised: (_) => _expand(context, frame),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: ExpandChip(onTap: () => _expand(context, frame)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(batch.label, style: text.headlineMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              SpeciesTag(
                label: batch.species.label,
                tint: batch.species.tint,
              ),
              Flexible(
                child: Text(
                  '  ·  ${relativeDay(batch.capturedAt)}, '
                  '${clockTime(batch.capturedAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Eyebrow('Final count'),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.bottomLeft,
                        child: Text(
                          thousands(batch.total),
                          style: text.displayMedium,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        'fingerlings',
                        style: text.bodyMedium?.copyWith(
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: AppColors.line),
                _MetaRow(
                  label: 'Detected automatically',
                  value: thousands(batch.autoCount),
                ),
                const Divider(height: 1, color: AppColors.line),
                _MetaRow(
                  label: 'Corrected by hand',
                  value: batch.manualDelta == 0
                      ? 'None'
                      : '${batch.manualDelta > 0 ? '+' : '−'}'
                            '${batch.manualDelta.abs()}',
                  highlight: batch.wasCorrected,
                ),
                const Divider(height: 1, color: AppColors.line),
                _MetaRow(
                  label: 'Captured',
                  value:
                      '${relativeDay(batch.capturedAt)}, '
                      '${clockTime(batch.capturedAt)}',
                ),
              ],
            ),
          ),
          if (batch.note.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.tealSoft,
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Eyebrow('Note', color: AppColors.teal),
                  const SizedBox(height: 7),
                  Text(
                    batch.note,
                    style: text.bodyLarge?.copyWith(color: AppColors.tealDeep),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          QuietButton(
            label: 'Export as CSV',
            icon: Icons.ios_share_rounded,
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Export lands with local storage')),
            ),
          ),
          const SizedBox(height: 10),
          QuietButton(
            label: 'Delete count',
            icon: Icons.delete_outline_rounded,
            danger: true,
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: text.bodyMedium?.copyWith(color: AppColors.inkSoft),
            ),
          ),
          Text(
            value,
            style: text.titleMedium?.copyWith(
              color: highlight ? AppColors.teal : AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
