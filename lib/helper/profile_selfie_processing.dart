import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:sixam_mart_delivery/util/images.dart';

/// Segmentación ML Kit + fondo Tootli (sin dependencia de UI).
class ProfileSelfieProcessing {
  ProfileSelfieProcessing._();

  static const int _outputSize = 800;
  static const int _maxInputSide = 720;
  static const double _maskThreshold = 0.42;

  /// Procesa una foto existente (ruta local) y devuelve bytes JPEG con fondo Tootli.
  static Future<Uint8List?> composeToJpegBytes(String inputPath) async {
    if (!Platform.isAndroid && !Platform.isIOS) return null;

    final bytes = await File(inputPath).readAsBytes();
    var foreground = img.decodeImage(bytes);
    if (foreground == null) return null;

    foreground = img.bakeOrientation(foreground);

    final tmpDir = await getTemporaryDirectory();
    foreground = await _cropIdentificationHeadshot(foreground, tmpDir.path);

    final maxSide = math.max(foreground.width, foreground.height);
    if (maxSide > _maxInputSide) {
      final scale = _maxInputSide / maxSide;
      foreground = img.copyResize(
        foreground,
        width: (foreground.width * scale).round(),
        height: (foreground.height * scale).round(),
        interpolation: img.Interpolation.linear,
      );
    }

    final tmpIn = File(
      '${tmpDir.path}/selfie_ml_in_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await tmpIn.writeAsBytes(img.encodeJpg(foreground, quality: 92));

    SelfieSegmenter? segmenter;
    try {
      segmenter = SelfieSegmenter(
        mode: SegmenterMode.single,
        enableRawSizeMask: false,
      );
      final inputImage = InputImage.fromFilePath(tmpIn.path);
      final mask = await segmenter.processImage(inputImage);
      if (mask == null) return null;

      final maxC = mask.confidences.reduce(math.max);
      if (maxC < 0.12) return null;

      final bgBytes = await rootBundle.load(Images.tootliProfileSelfieBg);
      final bgImg = img.decodeImage(bgBytes.buffer.asUint8List());
      if (bgImg == null) return null;

      final background = _coverResize(bgImg, _outputSize, _outputSize);
      final out = img.Image(width: _outputSize, height: _outputSize);
      img.compositeImage(out, background, dstX: 0, dstY: 0);

      final w = foreground.width;
      final h = foreground.height;
      final offX = (_outputSize - w) ~/ 2;
      final offY = (_outputSize - h) ~/ 2;

      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final mx = (x * mask.width / w).floor().clamp(0, mask.width - 1);
          final my = (y * mask.height / h).floor().clamp(0, mask.height - 1);
          final conf = mask.confidences[my * mask.width + mx];
          if (conf < _maskThreshold) continue;

          final t = ((conf - _maskThreshold) / (1.0 - _maskThreshold))
              .clamp(0.0, 1.0);
          final ox = x + offX;
          final oy = y + offY;
          if (ox < 0 || oy < 0 || ox >= _outputSize || oy >= _outputSize) {
            continue;
          }

          final fp = foreground.getPixel(x, y);
          final bp = out.getPixel(ox, oy);
          final r = (fp.r * t + bp.r * (1 - t)).round().clamp(0, 255);
          final g = (fp.g * t + bp.g * (1 - t)).round().clamp(0, 255);
          final b = (fp.b * t + bp.b * (1 - t)).round().clamp(0, 255);
          out.setPixelRgb(ox, oy, r, g, b);
        }
      }

      return Uint8List.fromList(img.encodeJpg(out, quality: 88));
    } catch (e, st) {
      debugPrint('[ProfileSelfieProcessing] $e\n$st');
      return null;
    } finally {
      await segmenter?.close();
      try {
        await tmpIn.delete();
      } catch (_) {}
    }
  }

  /// Recuadro tipo credencial: rostro + frente/pelo; poco espacio bajo el mentón (sin torso).
  static Future<img.Image> _cropIdentificationHeadshot(
    img.Image src,
    String tmpDirPath,
  ) async {
    final detector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        minFaceSize: 0.08,
      ),
    );
    final tmp = File(
      '$tmpDirPath/selfie_face_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    try {
      await tmp.writeAsBytes(img.encodeJpg(src, quality: 95));
      final faces = await detector.processImage(InputImage.fromFilePath(tmp.path));
      if (faces.isEmpty) {
        return _geometricHeadshotFallback(src);
      }
      faces.sort(
        (a, b) => (b.boundingBox.width * b.boundingBox.height).compareTo(
          a.boundingBox.width * a.boundingBox.height,
        ),
      );
      return _squareCropAroundFace(src, faces.first);
    } catch (e, st) {
      debugPrint('[ProfileSelfieProcessing] face crop $e\n$st');
      return _geometricHeadshotFallback(src);
    } finally {
      await detector.close();
      try {
        if (await tmp.exists()) await tmp.delete();
      } catch (_) {}
    }
  }

  static img.Image _squareCropAroundFace(img.Image src, Face face) {
    final r = face.boundingBox;
    final fw = r.width;
    final fh = r.height;
    if (fw < 8 || fh < 8) return _geometricHeadshotFallback(src);

    final left = r.left;
    final top = r.top;
    final chinY = r.bottom;
    // Más margen arriba (cabello/frente), poco abajo del mentón — sin pecho/cuello largo.
    final padTop = fh * 0.68;
    final padBelowChin = fh * 0.16;
    final padX = fw * 0.50;

    final boxLeft = left - padX;
    final boxTop = top - padTop;
    final boxRight = left + fw + padX;
    final boxBottom = chinY + padBelowChin;

    final boxW = boxRight - boxLeft;
    final boxH = boxBottom - boxTop;
    var side = math.max(boxW, boxH);
    side = math.max(side, math.max(fw, fh) * 1.75);

    final cx = left + fw / 2;
    final cy = top + fh * 0.44;
    var x0 = (cx - side / 2).floor();
    var y0 = (cy - side * 0.44).floor();

    x0 = x0.clamp(0, src.width - 1);
    y0 = y0.clamp(0, src.height - 1);
    var s = side.ceil();
    s = math.min(s, math.min(src.width - x0, src.height - y0));
    if (s < 64) return _geometricHeadshotFallback(src);
    return img.copyCrop(src, x: x0, y: y0, width: s, height: s);
  }

  /// Si no hay cara detectada: encuadre superior centrado (aprox. selfie INE).
  static img.Image _geometricHeadshotFallback(img.Image src) {
    final m = math.min(src.width, src.height);
    var side = (m * 0.70).round();
    side = math.min(side, math.min(src.width, src.height));
    final cx = src.width ~/ 2;
    final cy = (src.height * 0.36).round();
    var left = cx - side ~/ 2;
    var top = cy - side ~/ 2;
    left = left.clamp(0, src.width - side);
    top = top.clamp(0, src.height - side);
    return img.copyCrop(src, x: left, y: top, width: side, height: side);
  }

  static img.Image _coverResize(img.Image src, int tw, int th) {
    final scale = math.max(tw / src.width, th / src.height);
    final nw = (src.width * scale).round();
    final nh = (src.height * scale).round();
    final resized = img.copyResize(
      src,
      width: nw,
      height: nh,
      interpolation: img.Interpolation.linear,
    );
    final x0 = (nw - tw) ~/ 2;
    final y0 = (nh - th) ~/ 2;
    return img.copyCrop(
      resized,
      x: x0,
      y: y0,
      width: tw,
      height: th,
    );
  }
}
