import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class HomeController extends GetxController {
  bool _trafficEnabled = false;
  bool get trafficEnabled => _trafficEnabled;

  bool _showEarnings = true;
  bool get showEarnings => _showEarnings;

  double _currentZoom = 16;
  double get currentZoom => _currentZoom;

  final Set<Polygon> _polygons = {};
  Set<Polygon> get polygons => _polygons;

  final Set<Marker> _markers = {};
  Set<Marker> get markers => _markers;

  final Set<Polyline> _polylines = {};
  Set<Polyline> get polylines => _polylines;
  
  bool _isNotificationPermissionGranted = true;
  bool get isNotificationPermissionGranted => _isNotificationPermissionGranted;
  
  bool _isBatteryOptimizationGranted = true;
  bool get isBatteryOptimizationGranted => _isBatteryOptimizationGranted;

  void toggleTraffic() {
    _trafficEnabled = !_trafficEnabled;
    update(['map']);
  }

  void toggleShowEarnings() {
    _showEarnings = !_showEarnings;
    update();
  }

  void setZoom(double zoom) {
    if ((_currentZoom > 14.5) != (zoom > 14.5)) {
      _currentZoom = zoom;
      update(['map']);
    } else {
      _currentZoom = zoom;
    }
  }

  void setPolygons(Set<Polygon> newPolygons) {
    _polygons.clear();
    _polygons.addAll(newPolygons);
    update(['map']);
  }

  void setMarkers(Set<Marker> newMarkers) {
    _markers.clear();
    _markers.addAll(newMarkers);
    update(['map']);
  }
  
  void setPolylines(Set<Polyline> newPolylines) {
    _polylines.clear();
    _polylines.addAll(newPolylines);
    update(['map']);
  }

  void clearMapData() {
    _polylines.clear();
    _markers.clear();
    update(['map']);
  }

  void setNotificationPermissionGranted(bool granted) {
    if (_isNotificationPermissionGranted != granted) {
      _isNotificationPermissionGranted = granted;
      update(['permissions']);
    }
  }

  void setBatteryOptimizationGranted(bool granted) {
    if (_isBatteryOptimizationGranted != granted) {
      _isBatteryOptimizationGranted = granted;
      update(['permissions']);
    }
  }
}
