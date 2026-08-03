import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:flutter_mapbox_navigation/flutter_mapbox_navigation.dart';
import 'package:sixam_mart_delivery/features/order/domain/models/order_model.dart';
import 'package:sixam_mart_delivery/features/profile/controllers/profile_controller.dart';

class OrderLocationController extends GetxController {
  OrderModel orderModel;
  
  OrderLocationController({required this.orderModel});

  MapBoxNavigationViewController? _mapBoxController;
  MapBoxNavigationViewController? get mapBoxController => _mapBoxController;

  bool _isNavigating = false;
  bool get isNavigating => _isNavigating;

  bool _routeBuilt = false;
  bool get routeBuilt => _routeBuilt;

  bool _isMapLoading = false; // Removido el delay inicial para mayor velocidad
  bool get isMapLoading => _isMapLoading;

  late MapBoxOptions _navigationOption;
  MapBoxOptions get navigationOption => _navigationOption;

  @override
  void onInit() {
    super.onInit();
    _initMapBoxOptions();
  }

  void updateOrderModel(OrderModel newOrder) {
    if (orderModel.orderStatus != newOrder.orderStatus || orderModel.id != newOrder.id) {
      orderModel = newOrder;
      // Reconstruir la ruta si el estado cambia (ej: de recogido a entregando)
      if (_mapBoxController != null) {
        _buildAndStartRoute();
      }
    }
  }

  @override
  void onClose() {
    _mapBoxController?.finishNavigation();
    super.onClose();
  }

  void _initMapBoxOptions() {
    _navigationOption = MapBoxOptions(
      initialLatitude: Get.find<ProfileController>().recordLocationBody?.latitude ?? 19.4326,
      initialLongitude: Get.find<ProfileController>().recordLocationBody?.longitude ?? -99.1332,
      zoom: 15.0,
      tilt: 0.0,
      bearing: 0.0,
      enableRefresh: false,
      alternatives: false, // Desactivado para mejorar el rendimiento
      voiceInstructionsEnabled: true,
      bannerInstructionsEnabled: true,
      allowsUTurnAtWayPoints: true,
      mode: MapBoxNavigationMode.drivingWithTraffic,
      units: VoiceUnits.metric,
      simulateRoute: false,
      animateBuildRoute: true,
      language: "es",
      mapStyleUrlDay: "mapbox://styles/mapbox/navigation-night-v1", // Mismo estilo oscuro para el día
      mapStyleUrlNight: "mapbox://styles/mapbox/navigation-night-v1",
      longPressDestinationEnabled: false,
      padding: const EdgeInsets.only(bottom: 280), // Sube la interfaz nativa para que no la tape tu widget
    );
  }



  Future<void> onMapCreated(MapBoxNavigationViewController controller) async {
    _mapBoxController = controller;
    await _mapBoxController?.initialize();
    _buildAndStartRoute();
  }

  void onRouteEvent(RouteEvent e) {
    if (kDebugMode) {
      print('RouteEvent: ${e.eventType}');
    }
    
    if (e.eventType == MapBoxEvent.navigation_finished || e.eventType == MapBoxEvent.navigation_cancelled) {
      _isNavigating = false;
      update();
    } else if (e.eventType == MapBoxEvent.route_built) {
      debugPrint('[MapBox] 📍 Ruta construida exitosamente. Iniciando navegación automática...');
      // Iniciar la navegación automáticamente en cuanto la ruta esté lista
      _mapBoxController?.startNavigation(options: _navigationOption);
      _isNavigating = true;
      update();
    } else if (e.eventType == MapBoxEvent.route_build_failed) {
      debugPrint('[MapBox] ❌ Error al construir la ruta');
    }
  }

  Future<void> _buildAndStartRoute() async {
    if (_mapBoxController == null) return;
    
    bool parcel = orderModel.orderType == 'parcel';
    double deliveryManLat = Get.find<ProfileController>().recordLocationBody?.latitude ?? 0;
    double deliveryManLng = Get.find<ProfileController>().recordLocationBody?.longitude ?? 0;
    
    var wayPoints = <WayPoint>[];
    wayPoints.add(WayPoint(name: "Mi Ubicación", latitude: deliveryManLat, longitude: deliveryManLng));

    // Determinar a dónde vamos basándonos en el estado actual
    bool goingToStore = orderModel.orderStatus == 'accepted' || 
                        orderModel.orderStatus == 'processing' || 
                        orderModel.orderStatus == 'handover' ||
                        orderModel.orderStatus == 'confirmed';

    bool isTaxi = orderModel.orderType == 'taxi';
    
    // Si vamos a recoger (Tienda o Remitente/Cliente de taxi)
    if (goingToStore) {
      if (!parcel && !isTaxi) {
        double storeLat = double.tryParse(orderModel.storeLat ?? '0') ?? 0.0;
        double storeLng = double.tryParse(orderModel.storeLng ?? '0') ?? 0.0;
        if (storeLat != 0 && storeLng != 0) {
          wayPoints.add(WayPoint(name: orderModel.storeName ?? "Recogida", latitude: storeLat, longitude: storeLng));
        }
      } else {
        double senderLat = double.tryParse(orderModel.deliveryAddress?.latitude ?? '0') ?? 0.0;
        double senderLng = double.tryParse(orderModel.deliveryAddress?.longitude ?? '0') ?? 0.0;
        if (senderLat != 0 && senderLng != 0) {
          wayPoints.add(WayPoint(name: "Recogida", latitude: senderLat, longitude: senderLng));
        }
      }
    } 
    // Si ya recogimos, vamos al destino final
    else {
      double destLat = 0.0;
      double destLng = 0.0;

      if (parcel) {
        destLat = double.tryParse(orderModel.receiverDetails?.latitude ?? '0') ?? 0.0;
        destLng = double.tryParse(orderModel.receiverDetails?.longitude ?? '0') ?? 0.0;
      } else if (isTaxi) {
        destLat = double.tryParse(orderModel.receiverDetails?.latitude ?? '0') ?? 0.0;
        destLng = double.tryParse(orderModel.receiverDetails?.longitude ?? '0') ?? 0.0;
      } else {
        destLat = double.tryParse(orderModel.deliveryAddress?.latitude ?? '0') ?? 0.0;
        destLng = double.tryParse(orderModel.deliveryAddress?.longitude ?? '0') ?? 0.0;
      }

      if (destLat != 0 && destLng != 0) {
        wayPoints.add(WayPoint(name: "Entrega Final", latitude: destLat, longitude: destLng));
      }
    }

    if (wayPoints.length < 2) {
      debugPrint('Error building Mapbox route: No hay suficientes puntos válidos');
      return;
    }

    try {
      _routeBuilt = true;
      update(); 
      
      // Construir la ruta (la navegación se iniciará automáticamente en onRouteEvent al recibir route_built)
      await _mapBoxController?.buildRoute(wayPoints: wayPoints, options: _navigationOption);
    } catch (e) {
      if (kDebugMode) {
        print('Error launching Mapbox native route: $e');
      }
    }
  }
}
