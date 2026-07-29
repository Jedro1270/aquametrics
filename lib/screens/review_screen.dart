import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../models/count_batch.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';
import '../widgets/app_buttons.dart';
import '../widgets/count_widgets.dart';
import '../widgets/fish_field.dart';
import '../widgets/species_pills.dart';

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

  late final FishField _tray = FishField.generate(
    seed: widget.seed,
    count: _spotsInFrame,
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
  double _sensitivity = 0.72;
  final Set<int> _rejected = <int>{};
  final List<FishSpot> _manual = <FishSpot>[];

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
    _labelCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  /// Sensitivity maps to a minimum blob size, which is how an area filter on a
  /// thresholded mask actually behaves: raise it and small or partly hidden fish
  /// drop out.
  double get _minSize => 1.0 - _sensitivity * 0.45;

  List<int> get _detected => [
    for (var i = 0; i < _tray.spots.length; i++)
      if (_tray.spots[i].size >= _minSize) i,
  ];

  List<int> get _kept =>
      _detected.where((i) => !_rejected.contains(i)).toList();

  int get _autoCount => _detected.length;
  int get _removed => _autoCount - _kept.length;
  int get _added => _manual.length;
  int get _total => _kept.length + _added;
  bool get _edited => _added > 0 || _removed > 0;

  List<FishSpot> get _markers => [
    for (final i in _kept) _tray.spots[i],
    ..._manual,
  ];

  String get _sensitivityWord => switch (_sensitivity) {
    < 0.36 => 'Strict',
    < 0.72 => 'Balanced',
    _ => 'Inclusive',
  };

  void _handleTap(Offset n) {
    if (_analyzing) return;
    final hit = _tray.spacing * 0.72;

    for (var i = _manual.length - 1; i >= 0; i--) {
      if ((_manual[i].p - n).distance < hit) {
        setState(() => _manual.removeAt(i));
        return;
      }
    }

    int? nearest;
    var best = hit;
    for (final i in _kept) {
      final d = (_tray.spots[i].p - n).distance;
      if (d < best) {
        best = d;
        nearest = i;
      }
    }

    final target = nearest;
    setState(() {
      if (target != null) {
        _rejected.add(target);
      } else {
        _manual.add(FishSpot(p: n, angle: 0, size: 1, manual: true));
      }
    });
  }

  void _save() {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final saved = _total;
    final label = _labelCtrl.text.trim();

    batchStore.add(
      CountBatch(
        id: 'b-${DateTime.now().microsecondsSinceEpoch}',
        label: label.isEmpty ? 'Untitled count' : label,
        species: _species,
        autoCount: _autoCount,
        manualDelta: _added - _removed,
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
          _countCard(text),
          const SizedBox(height: 12),
          _sensitivityCard(text),
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
            child: AnimatedBuilder(
              animation: _reveal,
              builder: (context, _) => MockTrayImage(
                field: _tray,
                markers: _analyzing ? const [] : _markers,
                markerProgress: _reveal.value,
                onTapNormalised: _handleTap,
              ),
            ),
          ),
          if (_analyzing)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _scan,
                  builder: (context, _) =>
                      _ScanOverlay(progress: _scan.value),
                ),
              ),
            ),
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
              if (_edited)
                TextButton(
                  onPressed: () => setState(() {
                    _rejected.clear();
                    _manual.clear();
                  }),
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
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              AnimatedCount(
                value: _analyzing ? 0 : _total,
                style: text.displayMedium,
                duration: const Duration(milliseconds: 220),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
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
              _Legend(
                color: AppColors.hiVis,
                label: 'Detected',
                value: _autoCount,
              ),
              _Legend(
                color: const Color(0xFF17B26A),
                label: 'You added',
                value: _added,
              ),
              _Legend(
                color: AppColors.inkFaint,
                label: 'You removed',
                value: _removed,
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
                    'Tap a ring to drop it. Tap open water to add one the '
                    'detector missed.',
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
              Text('Detection sensitivity', style: text.titleMedium),
              const Spacer(),
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
                  _sensitivityWord,
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
            value: _sensitivity,
            onChanged: _analyzing
                ? null
                : (v) => setState(() => _sensitivity = v),
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

class _Legend extends StatelessWidget {
  const _Legend({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final int value;

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
              Text(thousands(value), style: text.titleMedium),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: text.bodySmall?.copyWith(
              fontSize: 11.5,
              color: AppColors.inkFaint,
            ),
          ),
        ],
      ),
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
