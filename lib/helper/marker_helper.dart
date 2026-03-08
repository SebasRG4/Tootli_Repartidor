import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/services.dart';

class MarkerHelper {
  static Future<BitmapDescriptor> createCustomMarkerBitmap(
    String text, {
    Color color = Colors.red,
  }) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    textPainter.text = TextSpan(
      text: text,
      style: const TextStyle(
        fontSize: 20.0, // Reduced from 35.0
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );

    textPainter.layout();

    final double textWidth = textPainter.width;
    final double textHeight = textPainter.height;
    final double paddingHorizontal = 10.0; // Reduced
    final double paddingVertical = 4.0; // Reduced
    final double width = textWidth + (paddingHorizontal * 2);
    final double height = textHeight + (paddingVertical * 2);

    final Paint paint = Paint()
      ..color = color
          .withOpacity(0.9) // Subtle transparency
      ..style = PaintingStyle.fill;

    // Flat Pill background (No shadow)
    final RRect rrect = RRect.fromLTRBR(
      0,
      0,
      width,
      height,
      const Radius.circular(30), // More rounded pill
    );
    canvas.drawRRect(rrect, paint);

    // No triangle pointer - Flat design

    textPainter.paint(canvas, Offset(paddingHorizontal, paddingVertical));

    final ui.Image image = await pictureRecorder.endRecording().toImage(
      width.toInt(),
      height.toInt(),
    );
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );

    return BitmapDescriptor.bytes(
      byteData!.buffer.asUint8List(),
      width: width,
      height: height,
    );
  }
}
