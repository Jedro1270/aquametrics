import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../data/batch_store.dart';
import '../models/count_batch.dart';
import '../theme/app_theme.dart';
import '../vision/count_frame.dart';
import '../widgets/app_buttons.dart';
import '../widgets/species_pills.dart';
import 'review_screen.dart';

/// Framing step. Dark by necessity, not for style: the surrounding chrome should
/// disappear so the operator judges the water, and glare off a white UI would
/// wash out the preview.
typedef ImagePickerCallback =
    Future<XFile?> Function({
      required ImageSource source,
      required int imageQuality,
    });

typedef PhotoFrameDecoder = Future<CountFrame> Function(Uint8List bytes);

@visibleForTesting
PhotoFrameDecoder? debugPhotoFrameDecoder;

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({
    super.key,
    required this.store,
    this.species,
    this.pickImage,
  });

  final BatchStore store;
  final Species? species;
  final ImagePickerCallback? pickImage;

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen>
    with WidgetsBindingObserver {
  late Species _species =
      widget.species ?? widget.store.settings.defaultSpecies;
  bool _torch = false;
  bool _grid = true;
  bool _speciesOpen = false;
  bool _capturing = false;
  bool _initializingCamera = false;
  CameraController? _camera;
  String? _cameraError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.pickImage == null) unawaited(_initializeCamera());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.pickImage != null) return;
    if (state == AppLifecycleState.inactive) {
      unawaited(_disposeCamera());
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_initializeCamera());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    if (_camera != null || _initializingCamera || widget.pickImage != null) {
      return;
    }
    _initializingCamera = true;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _showCameraError('No camera is available on this device.');
        return;
      }
      final description = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final camera = CameraController(
        description,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await camera.initialize();
      if (!mounted) {
        await camera.dispose();
        return;
      }
      setState(() {
        _camera = camera;
        _cameraError = null;
      });
    } on CameraException catch (error) {
      _showCameraError(error.description ?? error.code);
    } finally {
      _initializingCamera = false;
    }
  }

  Future<void> _disposeCamera() async {
    final camera = _camera;
    _camera = null;
    if (mounted) setState(() {});
    await camera?.dispose();
  }

  void _showCameraError(String message) {
    if (mounted) setState(() => _cameraError = message);
  }

  void _review(CountFrame frame, int seed) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReviewScreen(
          store: widget.store,
          frame: frame,
          seed: seed,
          species: _species,
          sensitivity: widget.store.settings.defaultSensitivity,
          confirmBeforeSave: widget.store.settings.confirmBeforeSave,
        ),
      ),
    );
  }

  Future<void> _capture() async {
    if (widget.pickImage != null) return _pickPhoto(ImageSource.camera);
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized || _capturing) return;
    setState(() => _capturing = true);
    try {
      await _reviewPhoto(await camera.takePicture());
    } on CameraException catch (error) {
      _showCameraError(error.description ?? error.code);
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _toggleTorch() async {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized) return;
    final torch = !_torch;
    try {
      await camera.setFlashMode(torch ? FlashMode.torch : FlashMode.off);
      if (mounted) setState(() => _torch = torch);
    } on CameraException catch (error) {
      _showCameraError(error.description ?? error.code);
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final photo =
        await (widget.pickImage?.call(source: source, imageQuality: 92) ??
            ImagePicker().pickImage(source: source, imageQuality: 92));
    if (photo == null || !mounted) return;
    await _reviewPhoto(photo);
  }

  Future<void> _reviewPhoto(XFile photo) async {
    final bytes = await photo.readAsBytes();
    if (!mounted) return;
    final frame =
        await (debugPhotoFrameDecoder?.call(bytes) ?? PhotoFrame.decode(bytes));
    if (!mounted) return;
    _review(frame, photo.name.hashCode & 0x7fffffff);
  }

  Widget _cameraPreview() {
    final camera = _camera;
    if (widget.pickImage != null) return const ColoredBox(color: Colors.black);
    if (camera?.value.isInitialized ?? false) return CameraPreview(camera!);
    if (_cameraError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _cameraError!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }
    return const Center(child: CircularProgressIndicator(color: Colors.white));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

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
                      tooltip: 'Cancel',
                    ),
                    Expanded(
                      child: Text(
                        'Frame the tray',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleMedium?.copyWith(color: Colors.white),
                      ),
                    ),
                    ViewfinderIconButton(
                      icon: _grid
                          ? Icons.grid_on_rounded
                          : Icons.grid_off_rounded,
                      active: false,
                      onPressed: () => setState(() => _grid = !_grid),
                      tooltip: 'Guide grid',
                    ),
                    const SizedBox(width: 8),
                    ViewfinderIconButton(
                      icon: _torch
                          ? Icons.flashlight_on_rounded
                          : Icons.flashlight_off_rounded,
                      active: _torch,
                      onPressed: _toggleTorch,
                      tooltip: 'Light',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: _cameraPreview(),
                        ),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _FramingPainter(showGrid: _grid),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 14,
                        child: Center(child: const _HintPill()),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                child: _speciesOpen
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                        child: SpeciesPills(
                          selected: _species,
                          dark: true,
                          onChanged: (s) => setState(() {
                            _species = s;
                            _speciesOpen = false;
                          }),
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _SpeciesButton(
                          species: _species,
                          onTap: () =>
                              setState(() => _speciesOpen = !_speciesOpen),
                        ),
                      ),
                    ),
                    _Shutter(onPressed: _capture),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: ViewfinderIconButton(
                          icon: Icons.photo_library_outlined,
                          onPressed: () => _pickPhoto(ImageSource.gallery),
                          tooltip: 'Choose a photo',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Corner brackets plus an optional thirds grid. Brackets rather than a full
/// rectangle so the operator's eye stays on the water, not on a border.
class _FramingPainter extends CustomPainter {
  const _FramingPainter({required this.showGrid});

  final bool showGrid;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 18.0;
    final arm = math.min(size.width, size.height) * 0.07;
    final stroke = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final l = inset, t = inset;
    final r = size.width - inset, b = size.height - inset;

    for (final (corner, dx, dy) in [
      (Offset(l, t), 1.0, 1.0),
      (Offset(r, t), -1.0, 1.0),
      (Offset(l, b), 1.0, -1.0),
      (Offset(r, b), -1.0, -1.0),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(corner.dx + dx * arm, corner.dy)
          ..lineTo(corner.dx, corner.dy)
          ..lineTo(corner.dx, corner.dy + dy * arm),
        stroke,
      );
    }

    if (!showGrid) return;
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      final x = l + (r - l) * i / 3;
      final y = t + (b - t) * i / 3;
      canvas.drawLine(Offset(x, t), Offset(x, b), grid);
      canvas.drawLine(Offset(l, y), Offset(r, y), grid);
    }
  }

  @override
  bool shouldRepaint(covariant _FramingPainter old) => old.showGrid != showGrid;
}

class _HintPill extends StatelessWidget {
  const _HintPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wb_sunny_outlined, size: 15, color: Colors.white),
          SizedBox(width: 7),
          Flexible(
            child: Text(
              'Hold the tray flat  ·  keep your shadow out',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeciesButton extends StatelessWidget {
  const _SpeciesButton({required this.species, required this.onTap});

  final Species species;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 14),
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
              Flexible(
                child: Text(
                  species.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.expand_less_rounded,
                size: 18,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Shutter extends StatefulWidget {
  const _Shutter({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_Shutter> createState() => _ShutterState();
}

class _ShutterState extends State<_Shutter> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) {
        setState(() => _down = false);
        widget.onPressed();
      },
      child: Container(
        width: 82,
        height: 82,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
        ),
        child: Center(
          child: AnimatedScale(
            scale: _down ? 0.88 : 1,
            duration: const Duration(milliseconds: 110),
            child: Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.hiVis,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.center_focus_strong_rounded,
                color: AppColors.hiVisInk,
                size: 26,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
