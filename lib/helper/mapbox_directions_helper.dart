import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sixam_mart_delivery/api/api_client.dart';
import 'package:sixam_mart_delivery/util/app_constants.dart';

/// Polilínea por carretera: el backend llama a Mapbox con `MAPBOX_ACCESS_TOKEN` (nunca en la app).
class MapboxDirectionsHelper {
  static const Duration _timeout = Duration(seconds: 25);

  /// Devuelve puntos [LatLng] siguiendo la vía. Lista vacía si falla o no hay sesión API.
  static Future<List<LatLng>> getDrivingRoute(
    LatLng origin,
    LatLng destination,
  ) async {
    if (!Get.isRegistered<ApiClient>()) {
      debugPrint('[DrivingRoute] ApiClient no registrado');
      return [];
    }

    final oLat = origin.latitude;
    final oLng = origin.longitude;
    final dLat = destination.latitude;
    final dLng = destination.longitude;

    if (oLat == 0 && oLng == 0) return [];
    if (dLat == 0 && dLng == 0) return [];

    if ((oLat - dLat).abs() < 1e-6 && (oLng - dLng).abs() < 1e-6) {
      return [origin];
    }

    final query = Uri(
      queryParameters: <String, String>{
        'origin_lat': oLat.toString(),
        'origin_lng': oLng.toString(),
        'dest_lat': dLat.toString(),
        'dest_lng': dLng.toString(),
      },
    ).query;

    try {
      final api = Get.find<ApiClient>();
      final response = await api
          .getData('${AppConstants.drivingRouteUri}?$query', handleError: false)
          .timeout(_timeout);

      if (response.statusCode != 200) {
        debugPrint(
          '[DrivingRoute] HTTP ${response.statusCode} ${response.statusText}',
        );
        return [];
      }

      final body = response.body;
      if (body is! Map) return [];

      final raw = body['polyline'];
      if (raw is! List) return [];

      final out = <LatLng>[];
      for (final item in raw) {
        if (item is Map) {
          final lat = item['latitude'];
          final lng = item['longitude'];
          if (lat is num && lng is num) {
            out.add(LatLng(lat.toDouble(), lng.toDouble()));
          }
        }
      }
      return out;
    } catch (e, st) {
      debugPrint('[DrivingRoute] Error: $e\n$st');
      return [];
    }
  }
}
