import 'dart:math';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class GridHelper {
  static const double gridSize = 0.005;

  static List<LatLng> getHexagonPoints(String hexId) {
    List<String> parts = hexId.split('_');
    if (parts.length != 3) return [];

    int rx = int.parse(parts[1], radix: 16) - 1000000;
    int rz = int.parse(parts[2], radix: 16) - 1000000;

    double lng = 1.5 * rx * gridSize;
    double lat = (rz + 0.5 * rx) * gridSize * sqrt(3);

    LatLng center = LatLng(lat, lng);
    List<LatLng> points = [];

    for (int i = 0; i < 6; i++) {
      double angleDeg = 60.0 * i;
      double angleRad = pi / 180.0 * angleDeg;
      // Using the same proportions as the axial conversion
      points.add(
        LatLng(
          center.latitude + gridSize * sqrt(3) * sin(angleRad),
          center.longitude + gridSize * cos(angleRad),
        ),
      );
    }

    return points;
  }
}
