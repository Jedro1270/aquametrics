import 'package:flutter/material.dart';

import '../data/count_editor.dart';
import '../data/mock_data.dart';
import '../models/count_batch.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';
import '../widgets/app_buttons.dart';
import '../widgets/count_widgets.dart';
import '../widgets/fish_field.dart';
import '../widgets/species_pills.dart';
import 'tray_viewer_screen.dart';

/// Review and correct. This is the screen that decides whether anyone trusts the
/// app: the detector's number is presented as a starting point, and fixing it is
/// a first-class action rather than buried in a menu.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.seed, required this.species});

  final int seed;
  final Species species;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen>
    with TickerProviderStateMixin {
  static const _spotsInFrame = 268;

  late final CountEditor _editor = CountEditor(
    tray: FishField.generate(seed: widget.seed, count: _spotsInFrame),
  );
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final AnimationController _scan = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  )..repeat();

  final _labelCtrl = TextEditingController(text: 'Pond 3 transfer');
  final _noteCtrl = TextEditingController();

  late Species _species = widget.species;
  bool _analyzing = true;

  @override
  void initState() {
    super.initState();
    // Stands in for the detector pass so the flow has the right rhythm.
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      _scan.stop();
      setState(() => _analyzing = false);
      _reveal.forward();
    });
  }

  @override
  void dispose() {
    _reveal.dispose();
    _scan.dispose();
    _editor.dispose();
    _labelCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  String get _title {
    final label = _labelCtrl.text.trim();
    return label.isEmpty ? 'Captured frame' : label;
  }

  void _expand() {
    if (_analyzing) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => TrayViewerScreen.editing(
          editor: _editor,
          title: _title,
        ),
      ),
    );
  }

  void _save() {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final saved = _editor.total;

    batchStore.add(
      CountBatch(
        id: 'b-${DateTime.now().microsecondsSinceEpoch}',
        label: _title,
        species: _species,
        autoCount: _editor.autoCount,
        manualDelta: _editor.manualDelta,
        capturedAt: DateTime.now(),
        seed: widget.seed,
        note: _noteCtrl.text.trim(),
      ),
    );

    navigator.popUntil((route) => route.isFirst);
    messenger.showSnackBar(
      SnackBar(content: Text('Saved  ·  ${thousands(saved)} fingerlings')),
    );
  }

  @override
  Widget build(BuildContext context) {
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
        title: Text('Review count', style: text.titleLarge),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retake'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.teal,
              textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _frame(),
          const SizedBox(height: 14),
          ListenableBuilder(
            listenable: _editor,
            builder: (context, _) => _countCard(text),
          ),
          const SizedBox(height: 12),
          ListenableBuilder(
            listenable: _editor,
            builder: (context, _) => _sensitivityCard(text),
          ),
          const SizedBox(height: 12),
          _detailsCard(text),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: const BoxDecoration(
          color: AppColors.shell,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: SafeArea(
          top: false,
          child: HiVisButton(
            label: 'Save count',
            icon: Icons.check_rounded,
            onPressed: _analyzing ? null : _save,
          ),
        ),
      ),
    );
  }

  Widget _frame() {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Stack(
        children: [
          Positioned.fill(
            child: ListenableBuilder(
              listenable: Listenable.merge([_editor, _reveal]),
              builder: (context, _) => MockTrayImage(
                field: _editor.tray,
                markers: _analyzing ? const [] : _editor.markers,
                markerProgress: _reveal.value,
                onTapNormalised: _editor.tapAt,
              ),
            ),
          ),
          if (_analyzing)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _scan,
                  builder: (context, _) => _ScanOverlay(progress: _scan.value),
                ),
              ),
            )
          else
            Positioned(top: 10, right: 10, child: ExpandChip(onTap: _expand)),
        ],
      ),
    );
  }

  Widget _countCard(TextTheme text) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Eyebrow('Counted'),
              const Spacer(),
              if (_editor.edited)
                TextButton(
                  onPressed: _editor.clearEdits,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.inkSoft,
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Undo my edits',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.bottomLeft,
                  child: AnimatedCount(
                    value: _analyzing ? 0 : _editor.total,
                    style: text.displayMedium,
                    duration: const Duration(milliseconds: 220),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'fingerlings',
                  style: text.bodyMedium?.copyWith(color: AppColors.inkSoft),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.line),
          const SizedBox(height: 12),
          Row(
            children: [
              MarkerLegend(
                color: AppColors.hiVis,
                label: 'Detected',
                value: _editor.autoCount,
              ),
              MarkerLegend(
                color: const Color(0xFF17B26A),
                label: 'You added',
                value: _editor.added,
              ),
              MarkerLegend(
                color: AppColors.inkFaint,
                label: 'You removed',
                value: _editor.removed,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: AppColors.shell,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.touch_app_outlined,
                  size: 17,
                  color: AppColors.inkSoft,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tap a ring to drop it, or open water to add one. Expand the '
                    'frame to zoom into a clump.',
                    style: text.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sensitivityCard(TextTheme text) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Detection sensitivity',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleMedium,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.tealSoft,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  _editor.sensitivityLabel,
                  style: text.bodySmall?.copyWith(
                    color: AppColors.tealDeep,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Slider(
            value: _editor.sensitivity,
            onChanged: _analyzing ? null : (v) => _editor.sensitivity = v,
          ),
          Text(
            'Strict skips faint or half-hidden fish. Inclusive catches more but '
            'can double-count a clump.',
            style: text.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _detailsCard(TextTheme text) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Details', style: text.titleMedium),
          const SizedBox(height: 12),
          TextField(
            controller: _labelCtrl,
            textCapitalization: TextCapitalization.sentences,
            decoration: _inputDecoration('Label', 'e.g. Pond 3 transfer'),
          ),
          const SizedBox(height: 14),
          const Eyebrow('Species'),
          const SizedBox(height: 9),
          SpeciesPills(
            selected: _species,
            onChanged: (s) => setState(() => _species = s),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _noteCtrl,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: _inputDecoration(
              'Note (optional)',
              'Water clarity, who counted, anything odd',
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, String hint) {
    const border = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: AppColors.line),
    );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: AppColors.shell,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      labelStyle: const TextStyle(color: AppColors.inkSoft, fontSize: 14),
      hintStyle: const TextStyle(color: AppColors.inkFaint, fontSize: 14),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: AppColors.teal, width: 1.6),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.line),
      ),
      child: child,
    );
  }
}

/// Sweep while the frame is being processed. Ends when the work ends — nothing
/// loops once there is a result on screen.
class _ScanOverlay extends StatelessWidget {
  const _ScanOverlay({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(color: Colors.black.withValues(alpha: 0.42)),
          ),
          Positioned.fill(
            child: Align(
              alignment: Alignment(0, -1 + progress * 2),
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.hiVis.withValues(alpha: 0),
                      AppColors.hiVis.withValues(alpha: 0.5),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Finding fingerlings…',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
