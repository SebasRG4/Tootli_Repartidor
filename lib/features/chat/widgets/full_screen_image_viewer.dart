import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Vista completa de imagen con zoom interactivo (pinch-to-zoom) y gesto de cierre.
class FullScreenImageViewer extends StatefulWidget {
  final String imageUrl;
  const FullScreenImageViewer({super.key, required this.imageUrl});

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer>
    with SingleTickerProviderStateMixin {
  late final TransformationController _transformController;
  late final AnimationController _animController;
  Animation<Matrix4>? _resetAnimation;

  @override
  void initState() {
    super.initState();
    _transformController = TransformationController();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _transformController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _onDoubleTap(TapDownDetails details) {
    final position = details.localPosition;
    const double scale = 2.5;

    if (_transformController.value != Matrix4.identity()) {
      // Zoom out → resetear
      _resetAnimation = Matrix4Tween(
        begin: _transformController.value,
        end: Matrix4.identity(),
      ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
      _animController.forward(from: 0);
      _animController.addListener(() {
        _transformController.value = _resetAnimation!.value;
      });
    } else {
      // Zoom in → centrar en el punto tocado
      final Matrix4 zoomed = Matrix4.identity()
        ..translate(-position.dx * (scale - 1), -position.dy * (scale - 1))
        ..scale(scale);
      _resetAnimation = Matrix4Tween(
        begin: Matrix4.identity(),
        end: zoomed,
      ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
      _animController.forward(from: 0);
      _animController.addListener(() {
        _transformController.value = _resetAnimation!.value;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: GestureDetector(
        onDoubleTapDown: _onDoubleTap,
        child: Center(
          child: InteractiveViewer(
            transformationController: _transformController,
            minScale: 0.5,
            maxScale: 5.0,
            child: CachedNetworkImage(
              imageUrl: widget.imageUrl,
              fit: BoxFit.contain,
              placeholder: (_, __) => const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
              errorWidget: (_, __, ___) => const Icon(
                Icons.broken_image,
                color: Colors.white54,
                size: 80,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
