import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/count_editor.dart';
import '../models/marker.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';
import '../vision/count_frame.dart';
import '../widgets/app_buttons.dart';
import '../widgets/count_widgets.dart';
import '../widgets/fish_field.dart';

/// Full-screen frame inspection. Pinch to zoom into a clump and keep correcting
/// at that magnification, which is the whole point: a ring you cannot see is a
/// ring you cannot trust.
class TrayViewerScreen extends StatefulWidget {
  /// Editable view backed by the shared [CountEditor], so corrections made here
  /// are the same corrections shown on the review screen.
  const TrayViewerScreen.editing({
    super.key,
    required CountEditor this.editor,
    required this.title,
  }) : frame = null,
       markers = const [],
       ringRadius = 0.02;

  /// Read-only view of a saved count.
  const TrayViewerScreen.readOnly({
    super.key,
    required CountFrame this.frame,
    required this.markers,
    required this.ringRadius,
    required this.title,
  }) : editor = null;

  final CountEditor? editor;
  final CountFrame? frame;
  final List<Marker> markers;
  final double ringRadius;
  final String title;

  @override
  State<TrayViewerScreen> createState() => _TrayViewerScreenState();
}

class _TrayViewerScreenState extends State<TrayViewerScreen> {
  final _transform = TransformationController();

  /// Stands in for the editor in read-only mode so the builders below do not
  /// need a null branch.
  final _idle = ValueNotifier<int>(0);

  double _scale = 1;
  Size _viewport = Size.zero;

  Listenable get _refresh => widget.editor ?? _idle;
  bool get _editable => widget.editor != null;
  CountFrame get _frame => widget.editor?.frame ?? widget.frame!;
  List<Marker> get _markers => widget.editor?.markers ?? widget.markers;
  double get _ring => widget.editor?.ringRadius ?? widget.ringRadius;

  @override
  void initState() {
    super.initState();
    _transform.addListener(_onTransform);
  }

  void _onTransform() {
    final next = _transform.value.getMaxScaleOnAxis();
    if ((next - _scale).abs() < 0.01) return;
    setState(() => _scale = next);
  }

  @override
  void dispose() {
    _transform.removeListener(_onTransform);
    _transform.dispose();
    _idle.dispose();
    super.dispose();
  }

  void _resetZoom() => _transform.value = Matrix4.identity();

  /// Stepped zoom button. A double-tap recogniser would compete with the
  /// tap-to-correct gesture and make marker edits feel unreliable, and pinching
  /// with one wet hand is awkward, so the steps are an explicit control.
  void _stepZoom() {
    final next = switch (_scale) {
      < 1.9 => 2.0,
      < 3.9 => 4.0,
      _ => 1.0,
    };
    if (next == 1.0 || _viewport.isEmpty) {
      _resetZoom();
      return;
    }
    // Scale about the centre of the viewport: p' = next * p + c * (1 - next).
    final cx = _viewport.width / 2;
    final cy = _viewport.height / 2;
    _transform.value = Matrix4.identity()
      ..setEntry(0, 0, next)
      ..setEntry(1, 1, next)
      ..setEntry(0, 3, cx * (1 - next))
      ..setEntry(1, 3, cy * (1 - next));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final zoomed = _scale > 1.05;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.water,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                child: Row(
                  children: [
                    ViewfinderIconButton(
                      icon: Icons.close_rounded,
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Close',
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleMedium?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            zoomed
                                ? '${_scale.toStringAsFixed(1)}× — drag to pan'
                                : 'Pinch or use + to zoom in',
                            style: text.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (zoomed) ...[
                      ViewfinderIconButton(
                        icon: Icons.zoom_out_map_rounded,
                        onPressed: _resetZoom,
                        tooltip: 'Fit to screen',
                      ),
                      const SizedBox(width: 8),
                    ],
                    ViewfinderIconButton(
                      icon: _scale < 3.9
                          ? Icons.add_rounded
                          : Icons.refresh_rounded,
                      onPressed: _stepZoom,
                      tooltip: _scale < 3.9 ? 'Zoom in' : 'Back to fit',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    _viewport = constraints.biggest;
                    return ListenableBuilder(
                      listenable: _refresh,
                      builder: (context, _) => InteractiveViewer(
                        transformationController: _transform,
                        minScale: 1,
                        maxScale: 8,
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: _frame.aspect,
                            child: CountFrameView(
                              frame: _frame,
                              markers: _markers,
                              ringRadius: CountEditor.markerRingRadiusForZoom(
                                _ring,
                                scale: _scale,
                              ),
                              radius: 0,
                              // Hand the editor the live zoom so the hit radius
                              // tightens as the operator magnifies.
                              onTapNormalised: _editable
                                  ? (p) => widget.editor!.tapAt(
                                      p,
                                      scale: _scale,
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              ListenableBuilder(
                listenable: _refresh,
                builder: (context, _) => _BottomPanel(
                  editor: widget.editor,
                  readOnlyTotal: _markers.length,
                  editable: _editable,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.editor,
    required this.readOnlyTotal,
    required this.editable,
  });

  final CountEditor? editor;
  final int readOnlyTotal;
  final bool editable;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final e = editor;
    final total = e?.total ?? readOnlyTotal;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.34),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Grouped under one Expanded so the button keeps its natural
              // width instead of fighting the number for flex space.
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.bottomLeft,
                        child: Text(
                          thousands(total),
                          style: text.displaySmall?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          'fingerlings',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (e != null && e.edited)
                TextButton(
                  onPressed: e.clearEdits,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white.withValues(alpha: 0.75),
                    minimumSize: const Size(0, 34),
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
          const SizedBox(height: 12),
          Row(
            children: [
              MarkerLegend(
                color: AppColors.hiVis,
                label: 'Detected',
                value: e?.autoCount ?? readOnlyTotal,
                dark: true,
              ),
              if (e != null) ...[
                MarkerLegend(
                  color: const Color(0xFF3BE38F),
                  label: 'You added',
                  value: e.added,
                  dark: true,
                ),
                MarkerLegend(
                  color: Colors.white.withValues(alpha: 0.45),
                  label: 'You removed',
                  value: e.removed,
                  dark: true,
                ),
              ],
            ],
          ),
          if (e != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  'Sensitivity',
                  style: text.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: AppColors.hiVis,
                      inactiveTrackColor: Colors.white.withValues(alpha: 0.22),
                      thumbColor: Colors.white,
                      overlayColor: Colors.white.withValues(alpha: 0.12),
                      trackHeight: 5,
                    ),
                    child: Slider(
                      value: e.sensitivity,
                      onChanged: (v) => e.sensitivity = v,
                    ),
                  ),
                ),
                Text(
                  e.sensitivityLabel,
                  style: text.bodySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            Text(
              'Tap a ring to drop it, open water to add one. Zoom in for finer '
              'taps.',
              style: text.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
