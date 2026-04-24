import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_snackbar_widget.dart';
import 'package:sixam_mart_delivery/helper/profile_selfie_processing.dart';

/// Marco ovalado + consejos sobre la vista previa (cámara frontal) antes de capturar.
class ProfileSelfieCameraScreen extends StatefulWidget {
  const ProfileSelfieCameraScreen({super.key});

  @override
  State<ProfileSelfieCameraScreen> createState() =>
      _ProfileSelfieCameraScreenState();
}

class _ProfileSelfieCameraScreenState extends State<ProfileSelfieCameraScreen> {
  CameraController? _controller;
  bool _initializing = true;
  bool _capturing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Evita pigeon "channel-error" al llamar availableCameras() antes de que
    // la vista / transición de Get estén listas en el hilo principal.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initCamera(attempt: 0);
    });
  }

  static const int _maxCameraInitAttempts = 3;

  Future<void> _initCamera({required int attempt}) async {
    if (!mounted) return;
    await Future<void>.delayed(Duration(milliseconds: 120 + (attempt * 280)));
    if (!mounted) return;
    try {
      final cameras = await availableCameras();
      CameraDescription? front;
      for (final c in cameras) {
        if (c.lensDirection == CameraLensDirection.front) {
          front = c;
          break;
        }
      }
      front ??= cameras.isNotEmpty ? cameras.first : null;
      if (front == null) {
        if (mounted) {
          setState(() {
            _error = 'profile_selfie_guide_error'.tr;
            _initializing = false;
          });
        }
        return;
      }

      final controller = CameraController(
        front,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _initializing = false;
      });
    } catch (e, st) {
      debugPrint('[ProfileSelfieCameraScreen] init $e\n$st');
      final canRetry = e is CameraException &&
          e.code == 'channel-error' &&
          attempt + 1 < _maxCameraInitAttempts;
      if (canRetry && mounted) {
        return _initCamera(attempt: attempt + 1);
      }
      if (mounted) {
        setState(() {
          _error = 'profile_selfie_guide_error'.tr;
          _initializing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _onCapture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _capturing) {
      return;
    }
    setState(() => _capturing = true);
    try {
      final shot = await controller.takePicture();
      final out = await ProfileSelfieProcessing.composeToJpegBytes(shot.path);
      if (!mounted) return;
      if (out == null) {
        showCustomSnackBar('profile_selfie_compose_failed'.tr, isError: true);
        setState(() => _capturing = false);
        return;
      }
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/tootli_profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await file.writeAsBytes(out, flush: true);
      Get.back(result: XFile(file.path, mimeType: 'image/jpeg'));
    } catch (e, st) {
      debugPrint('[ProfileSelfieCameraScreen] capture $e\n$st');
      if (mounted) {
        showCustomSnackBar('profile_selfie_compose_failed'.tr, isError: true);
        setState(() => _capturing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return PopScope(
      canPop: !_capturing,
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.black26,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: _capturing ? null : () => Get.back(),
          ),
          title: Text(
            'profile_selfie_guide_title'.tr,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (_initializing)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 16),
                    Text(
                      'profile_selfie_guide_preparing'.tr,
                      style: const TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else if (_error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: () => Get.back(),
                        child: Text('ok'.tr),
                      ),
                    ],
                  ),
                ),
              )
            else if (_controller != null && _controller!.value.isInitialized)
              Stack(
                fit: StackFit.expand,
                children: [
                  _buildFullBleedPreview(_controller!),
                  const CustomPaint(
                    painter: SelfieOvalGuidePainter(),
                    child: SizedBox.expand(),
                  ),
                  Positioned(
                    top: MediaQuery.paddingOf(context).top + kToolbarHeight + 8,
                    left: 20,
                    right: 20,
                    child: Text(
                      'profile_selfie_guide_subtitle'.tr,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        shadows: [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 0,
                    child: SafeArea(
                      top: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _tipRow(Icons.straighten, 'profile_selfie_guide_tip_1'.tr),
                          const SizedBox(height: 8),
                          _tipRow(Icons.face, 'profile_selfie_guide_tip_2'.tr),
                          const SizedBox(height: 8),
                          _tipRow(
                            Icons.wb_sunny_outlined,
                            'profile_selfie_guide_tip_3'.tr,
                          ),
                          const SizedBox(height: 20),
                          Center(
                            child: Semantics(
                              label: 'profile_selfie_guide_capture'.tr,
                              button: true,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _capturing ? null : _onCapture,
                                  customBorder: const CircleBorder(),
                                  child: Ink(
                                    width: 76,
                                    height: 76,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 4,
                                      ),
                                      color: primary.withValues(alpha: 0.35),
                                    ),
                                    child: Icon(
                                      Icons.camera_alt,
                                      color: Colors.white,
                                      size: 32,
                                      shadows: const [
                                        Shadow(
                                          color: Colors.black45,
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            if (_capturing)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _tipRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              height: 1.35,
              shadows: [
                Shadow(color: Colors.black87, blurRadius: 4),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Vista previa a pantalla completa sin estirar (usa ratio real del sensor).
  static Widget _buildFullBleedPreview(CameraController controller) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        if (!controller.value.isInitialized) {
          return const SizedBox.shrink();
        }
        final ar = controller.value.aspectRatio;
        // Misma lógica que CameraPreview interno: alto lógico = ancho * ar (retrato).
        final previewH = w * ar;
        final scale = previewH > 0 && previewH < h ? h / previewH : 1.0;
        return ClipRect(
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.center,
            child: SizedBox(
              width: w,
              height: previewH,
              child: CameraPreview(controller),
            ),
          ),
        );
      },
    );
  }
}

/// Oscurece fuera del óvalo y dibuja el marco de la cara (guía de encuadre).
class SelfieOvalGuidePainter extends CustomPainter {
  const SelfieOvalGuidePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * 0.5;
    final cy = size.height * 0.38;
    // Marco más estrecho y alto, alineado a foto tipo credencial.
    final ovalW = size.width * 0.58;
    final ovalH = ovalW * 1.32;

    final full = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final oval = Path()
      ..addOval(
        Rect.fromCenter(
          center: Offset(cx, cy),
          width: ovalW,
          height: ovalH,
        ),
      );
    final dim = Path.combine(PathOperation.difference, full, oval);

    canvas.drawPath(
      dim,
      Paint()..color = Colors.black.withValues(alpha: 0.52),
    );

    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = Colors.white.withValues(alpha: 0.92);
    canvas.drawPath(oval, border);

    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: 0.35);
    canvas.drawPath(
      Path()..addOval(Rect.fromCenter(center: Offset(cx, cy), width: ovalW + 14, height: ovalH + 18)),
      dash,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
