import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:sixam_mart_delivery/features/auth/controllers/auth_controller.dart';
import 'package:sixam_mart_delivery/features/order/controllers/order_controller.dart';
import 'package:sixam_mart_delivery/features/home/controllers/home_controller.dart';
import 'package:sixam_mart_delivery/features/notification/controllers/notification_controller.dart';
import 'package:sixam_mart_delivery/features/profile/controllers/profile_controller.dart';
import 'package:sixam_mart_delivery/helper/price_converter_helper.dart';
import 'package:sixam_mart_delivery/helper/route_helper.dart';
import 'package:sixam_mart_delivery/helper/order_notification_service.dart';
import 'package:sixam_mart_delivery/util/dimensions.dart';
import 'package:sixam_mart_delivery/util/images.dart';
import 'package:sixam_mart_delivery/util/styles.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_button_widget.dart';
import 'package:sixam_mart_delivery/features/home/widgets/earning_widget.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sixam_mart_delivery/helper/mapbox_directions_helper.dart';
import 'package:sixam_mart_delivery/features/dashboard/widgets/premium_order_request_widget.dart';
import 'package:sixam_mart_delivery/features/home/widgets/cash_progress_widget.dart';
import 'package:sixam_mart_delivery/features/address/controllers/address_controller.dart';
import 'package:sixam_mart_delivery/features/address/domain/models/zone_model.dart';
import 'package:sixam_mart_delivery/util/app_constants.dart';
import 'package:sixam_mart_delivery/features/order/domain/models/order_model.dart';
import 'package:sixam_mart_delivery/features/dashboard/widgets/accepted_order_widget.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_snackbar_widget.dart';
import 'dart:math';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.pendingRegistrationDashboard = false,
    this.onNavigateToOrders,
    this.onTapMenu,
    this.onOrderActiveStatusChanged,
    this.onOrderDismissed,
  });

  /// Registro con `application_status` pending (revisión inicial o correcciones del admin).
  final bool pendingRegistrationDashboard;
  final Function()? onNavigateToOrders;
  final Function()? onTapMenu;
  final Function(bool isActive)? onOrderActiveStatusChanged;
  final Function(int? orderId, String? transactionRef)? onOrderDismissed;

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  late final AppLifecycleListener _listener;
  GoogleMapController? _mapController;
  Timer? _gridTimer;
  Timer? _routeOptimizationTimer;
  List<OrderModel> _activeOrders = [];
  OrderModel?
  _pendingRequest; // Para mostrar la ventana de aceptación sobre un pedido activo
  int _selectedOrderIndex = 0;
  String _orderPhase = 'none'; // 'none', 'going_to_store', 'going_to_customer'
  String? _estimatedArrivalTime;
  final AudioPlayer _governanceAudioPlayer = AudioPlayer();
  Timer? _inactivityTimer;
  int _inactivitySeconds = 0;
  LatLng? _lastInactivityPosition;
  bool _isShowingInactivityDialog = false;

  /// Último orderId enviado a showOrderRequest para evitar mostrar el mismo pedido dos veces
  int? _lastShownOrderId;

  /// Indica si el pedido que se está viendo fue tomado por otro mientras se mostraba
  bool _isOrderTakenByOther = false;

  /// Marcadores precargados — se decodifican una sola vez en initState
  Uint8List? _cachedStoreMarker;
  Uint8List? _cachedDestinationMarker;
  StreamSubscription? _notificationSubscription;

  bool _isTrafficEnabled = false;
  bool get isTrafficEnabled => _isTrafficEnabled;

  void toggleTraffic() {
    setState(() {
      _isTrafficEnabled = !_isTrafficEnabled;
    });
  }

  @override
  void initState() {
    super.initState();

    _checkSystemNotification();
    _initNotificationService();
    _startRouteOptimizationTimer();

    _listener = AppLifecycleListener(onStateChange: _onStateChanged);

    // Precargar marcadores del mapa una sola vez para evitar decodificación en cada pedido
    _preloadMarkers();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      Get.find<AddressController>().getZoneList();
    });

    Future.delayed(const Duration(milliseconds: 200), () {
      checkPermission();
    });

    _gridTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _refreshGrids();
    });

    _startInactivityTimer();
    _startRouteOptimizationTimer();
  }

  void _startRouteOptimizationTimer() {
    _routeOptimizationTimer?.cancel();
    _routeOptimizationTimer = Timer.periodic(const Duration(seconds: 30), (
      timer,
    ) {
      if (_activeOrders.length > 1 && mounted) {
        _refreshOptimizedRoute();
      }
    });
  }

  Future<void> _refreshOptimizedRoute() async {
    debugPrint('[Routing] Intentando refrescar ruta optimizada... Pedidos activos: ${_activeOrders.length}');
    Position pos = await Geolocator.getCurrentPosition();
    await Get.find<OrderController>().getOptimizedRoute(
      pos.latitude,
      pos.longitude,
    );
    if (mounted) {
      debugPrint('[Routing] Aplicando polilínea multi-pedido...');
      setMultiOrderPolyline();
    }
  }

  Future<void> _preloadMarkers() async {
    try {
      _cachedStoreMarker = await _convertAssetToUnit8List(
        Images.store,
        width: 40,
      );
      _cachedDestinationMarker = await _convertAssetToUnit8List(
        Images.homeDelivery,
        width: 40,
      );
    } catch (e) {
      debugPrint('[HomeScreen] Error precargando marcadores: $e');
    }
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pendingRegistrationDashboard &&
        !widget.pendingRegistrationDashboard) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadData();
      });
    }
  }

  void _refreshGrids() {
    int? zoneId = Get.find<ProfileController>().profileModel?.zoneId;
    if (zoneId != null) {
      Get.find<AddressController>().getGridList(zoneId);
    }
  }

  Future<void> _loadData() async {
    if (widget.pendingRegistrationDashboard) {
      await Get.find<ProfileController>().getProfile();
      final int? zoneId = Get.find<ProfileController>().profileModel?.zoneId;
      if (zoneId != null) {
        Get.find<AddressController>().getGridList(zoneId);
      }
      return;
    }
    // These methods are synchronous or return void, call them separately
    Get.find<OrderController>().getIgnoreList();
    Get.find<OrderController>().removeFromIgnoreList();

    // Parallelize independent asynchronous data loading
    await Future.wait([
      Get.find<ProfileController>().getProfile(),
      Get.find<OrderController>().getRunningOrders(1),
      Get.find<NotificationController>().getNotificationList(),
    ]);

    int? zoneId = Get.find<ProfileController>().profileModel?.zoneId;
    if (zoneId != null) {
      Get.find<AddressController>().getGridList(zoneId);
    }
  }

  Future<void> _checkSystemNotification() async {
    if (await Permission.notification.status.isDenied ||
        await Permission.notification.status.isPermanentlyDenied) {
      await Get.find<AuthController>().setNotificationActive(false);
    }
  }

  void _onStateChanged(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.detached:
        break;
      case AppLifecycleState.resumed:
        checkPermission();
        _onAppResumed();
        break;
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.hidden:
        break;
      case AppLifecycleState.paused:
        break;
    }
  }

  void _initNotificationService() {
    _notificationSubscription = OrderNotificationService
        .instance
        .notificationStream
        .listen((data) {
          if (!mounted) return;
          final int? orderId = data['orderId'];
          final String? type = data['type'];

          if (type == 'order_request' && orderId != null) {
            Get.find<OrderController>().fetchOrderForNotification(orderId).then(
              (order) {
                if (order != null) {
                  showOrderRequest(order);
                }
              },
            );
          } else if (type == 'inactivity' && orderId != null) {
            showInactivityWarningFromNotification(orderId);
          } else if (type == 'unassigned' && orderId != null) {
            showUnassignedDialogFromNotification(orderId);
          }
        });
  }

  /// Al volver al primer plano con un pedido activo, refresca el estado real
  /// del pedido desde el servidor y redibuja la ruta. Evita la pantalla congelada.
  Future<void> _onAppResumed() async {
    if (!mounted || _activeOrders.isEmpty) return;
    final int? orderId = _activeOrders.first.id;
    if (orderId == null) return;

    debugPrint(
      '[HomeScreen] resumed con pedido activo $orderId — refrescando...',
    );
    final OrderModel? refreshed = await Get.find<OrderController>()
        .fetchOrderForNotification(orderId);
    if (!mounted || refreshed == null) return;

    final String status = refreshed.orderStatus ?? '';
    // Si el pedido ya terminó, limpiar la pantalla
    if (status == 'delivered' ||
        status == 'canceled' ||
        status == 'returned' ||
        status == 'failed') {
      setState(() {
        _activeOrders.removeAt(0);
        if (_activeOrders.isEmpty) {
          _orderPhase = 'none';
          Get.find<HomeController>().clearMapData();
          }
      });
      if (_activeOrders.isEmpty) widget.onOrderActiveStatusChanged?.call(false);
      return;
    }

    // Actualizar fase según el estado real del servidor
    String newPhase = _orderPhase;
    if (status == 'picked_up') {
      newPhase = 'going_to_customer';
    } else if (status == 'handover' ||
        status == 'processing' ||
        status == 'confirmed') {
      newPhase = 'going_to_store';
    }

    setState(() {
      _activeOrders[0] = refreshed;
      _orderPhase = newPhase;
    });
    setPolyline(refreshed);
  }

  Future<void> checkPermission() async {
    var notificationStatus = await Permission.notification.status;
    var batteryStatus = await Permission.ignoreBatteryOptimizations.status;
    var overlayStatus = await Permission.systemAlertWindow.status;

    if (!mounted) return;

    if (notificationStatus.isDenied || notificationStatus.isPermanentlyDenied) {
      Get.find<HomeController>().setNotificationPermissionGranted(false);
      Get.find<HomeController>().setBatteryOptimizationGranted(true);

      await Get.find<AuthController>().setNotificationActive(
        !notificationStatus.isDenied,
      );
    } else if (batteryStatus.isDenied) {
      Get.find<HomeController>().setBatteryOptimizationGranted(false);
      Get.find<HomeController>().setNotificationPermissionGranted(true);
    } else if (overlayStatus.isDenied && GetPlatform.isAndroid) {
      // Opcional: manejar estado de superposición
    } else {
      Get.find<HomeController>().setNotificationPermissionGranted(true);
      Get.find<HomeController>().setBatteryOptimizationGranted(true);
      Get.find<ProfileController>().setBackgroundNotificationActive(true);
    }

    if (batteryStatus.isDenied) {
      Get.find<ProfileController>().setBackgroundNotificationActive(false);
    }
  }

  Future<void> requestNotificationPermission() async {
    if (await Permission.notification.request().isGranted) {
      checkPermission();
      return;
    } else {
      await openAppSettings();
    }

    checkPermission();
  }

  void requestBatteryOptimization() async {
    var status = await Permission.ignoreBatteryOptimizations.status;

    if (status.isGranted) {
      return;
    } else if (status.isDenied) {
      await Permission.ignoreBatteryOptimizations.request();
    } else {
      openAppSettings();
    }

    checkPermission();
  }

  void _getPolygons(List<ZoneModel> zoneList) {
    final homeController = Get.find<HomeController>();
    Set<Polygon> newPolygons = {};
    int? profileZoneId = Get.find<ProfileController>().profileModel?.zoneId;

    for (var zone in zoneList) {
      if (zone.coordinates != null && zone.coordinates!.coordinates != null) {
        newPolygons.add(
          Polygon(
            polygonId: PolygonId('zone_${zone.id}'),
            points: zone.coordinates!.coordinates!,
            strokeWidth: zone.id == profileZoneId ? 5 : 2,
            strokeColor: zone.id == profileZoneId
                ? Theme.of(context).primaryColor
                : Colors.blueGrey.withOpacity(0.3),
            fillColor: zone.id == profileZoneId
                ? Theme.of(context).primaryColor.withOpacity(0.05)
                : Colors.transparent,
          ),
        );
      }
    }
    homeController.setPolygons(newPolygons);
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _gridTimer?.cancel();
    _inactivityTimer?.cancel();
    _governanceAudioPlayer.dispose();
    _listener.dispose();
    _routeOptimizationTimer?.cancel();
    super.dispose();
  }

  bool _hasCenteredOnLaunch = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: null,

      body: Builder(
        builder: (context) {
          final orderController = Get.find<OrderController>();
          // Lógica para detectar si el pedido que se está solicitando fue tomado por otro repartidor o expiró
          if (_pendingRequest != null &&
              _orderPhase == 'none' &&
              !_isOrderTakenByOther) {
            if (orderController.latestOrderList != null) {
              bool exists = orderController.latestOrderList!.any(
                (o) => o.id == _pendingRequest!.id,
              );
              if (!exists) {
                // El pedido ya no está en la lista de disponibles (tomado por otro o expirado)
                _isOrderTakenByOther = true;
                Future.delayed(const Duration(seconds: 3), () {
                  if (mounted && _isOrderTakenByOther) {
                    setState(() {
                      _pendingRequest = null;
                      _isOrderTakenByOther = false;
                    });
                    if (_activeOrders.isEmpty) {
                      widget.onOrderActiveStatusChanged?.call(false);
                    }
                  }
                });
              }
            }
          }

          return Builder(
            builder: (context) {
              final profileController = Get.find<ProfileController>();
              // Auto-centro inicial cuando la ubicación llega por primera vez y no hay pedido activo
              if (!_hasCenteredOnLaunch &&
                  profileController.recordLocationBody != null &&
                  _mapController != null &&
                  _activeOrders.isEmpty &&
                  _pendingRequest == null) {
                _hasCenteredOnLaunch = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  animateToMyLocation();
                });
              }

              LatLng? currentLatLng;
              if (profileController.recordLocationBody != null) {
                currentLatLng = LatLng(
                  profileController.recordLocationBody!.latitude!,
                  profileController.recordLocationBody!.longitude!,
                );
              }

              return Builder(
                builder: (context) {
                  final addressController = Get.find<AddressController>();
                  if (addressController.zoneList != null) {
                    _getPolygons(addressController.zoneList!);
                  }

                  return Stack(
                    children: [
                      GetBuilder<HomeController>(
                        id: 'map',
                        builder: (homeController) {
                          return GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target:
                                  currentLatLng ??
                                  const LatLng(
                                    19.4326,
                                    -99.1332,
                                  ), // Default to CDMX if location unknown
                              zoom: 16,
                            ),
                            myLocationEnabled: true,
                            myLocationButtonEnabled: false,
                            zoomControlsEnabled: false,
                            trafficEnabled: _isTrafficEnabled,
                            polygons: {
                              ...homeController.polygons,
                              ...addressController.gridPolygons,
                            },
                            markers: {
                              ...homeController.markers,
                              if (homeController.currentZoom > 14)
                                ...addressController.gridMarkers,
                            },
                            polylines: homeController.polylines,
                            padding: EdgeInsets.only(
                              bottom:
                                  (_activeOrders.isNotEmpty ||
                                      _pendingRequest != null)
                                  ? 350
                                  : 0,
                            ),

                            onCameraMove: (position) {
                              homeController.setZoom(position.zoom);
                            },
                            onMapCreated: (controller) {
                              _mapController = controller;
                              _mapController?.setMapStyle(AppConstants.darkStyle);

                              // Animate to current location once map is ready
                              if (profileController.recordLocationBody != null) {
                                _mapController?.animateCamera(
                                  CameraUpdate.newLatLng(
                                    LatLng(
                                      profileController
                                          .recordLocationBody!
                                          .latitude!,
                                      profileController
                                          .recordLocationBody!
                                          .longitude!,
                                    ),
                                  ),
                                );
                              }
                            },
                          );
                        }
                      ),

                      // Menu Button
                      GetBuilder<OrderController>(
                        builder: (orderController) {
                          bool hasActiveOrder =
                              (orderController.currentOrderList != null &&
                                  orderController
                                      .currentOrderList!
                                      .isNotEmpty) ||
                              (orderController.latestOrderList != null &&
                                  orderController.latestOrderList!.isNotEmpty);

                          return Positioned(
                            top:
                                context.mediaQueryPadding.top +
                                Dimensions.paddingSizeSmall,
                            left: Dimensions.paddingSizeDefault,
                            child: Container(
                              height: 40,
                              width: 40,
                              decoration: BoxDecoration(
                                color:
                                    (_activeOrders.isNotEmpty ||
                                        _pendingRequest != null)
                                    ? Colors.red
                                    : Theme.of(context).cardColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: Icon(
                                  (_activeOrders.isNotEmpty ||
                                          _pendingRequest != null)
                                      ? Icons.close
                                      : Icons.menu,
                                  size: 25,
                                  color:
                                      (_activeOrders.isNotEmpty ||
                                          _pendingRequest != null)
                                      ? Colors.white
                                      : Theme.of(
                                          context,
                                        ).textTheme.bodyLarge!.color,
                                ),
                                onPressed: () {
                                  if (_pendingRequest != null) {
                                    _performCancellation(
                                      order: _pendingRequest,
                                    );
                                  } else if (_activeOrders.isNotEmpty) {
                                    // Cancelar el pedido que se está viendo actualmente en el widget
                                    cancelOrderRequest();
                                  } else if (!hasActiveOrder) {
                                    widget.onTapMenu?.call();
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      ),

                      // Notification Button
                      if (!profileController.isPendingRegistrationDashboard)
                        Positioned(
                          top:
                              context.mediaQueryPadding.top +
                              Dimensions.paddingSizeSmall,
                          right: Dimensions.paddingSizeDefault,
                          child: GetBuilder<OrderController>(
                            builder: (orderController) {
                              return (orderController.latestOrderList != null &&
                                      orderController
                                          .latestOrderList!
                                          .isNotEmpty)
                                  ? const SizedBox()
                                  : GetBuilder<NotificationController>(
                                      builder: (notificationController) {
                                        return InkWell(
                                          onTap: () => Get.toNamed(
                                            RouteHelper.getNotificationRoute(),
                                          ),
                                          child: Container(
                                            height: 40,
                                            width: 40,
                                            decoration: BoxDecoration(
                                              color: Theme.of(
                                                context,
                                              ).cardColor,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.1),
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 5),
                                                ),
                                              ],
                                            ),
                                            child: Stack(
                                              clipBehavior: Clip.none,
                                              children: [
                                                Center(
                                                  child: Icon(
                                                    Icons.notifications,
                                                    size: 25,
                                                    color: Theme.of(context)
                                                        .textTheme
                                                        .bodyLarge!
                                                        .color,
                                                  ),
                                                ),
                                                if (notificationController
                                                    .hasNotification)
                                                  Positioned(
                                                    top: 5,
                                                    right: 5,
                                                    child: Container(
                                                      height: 10,
                                                      width: 10,
                                                      decoration: BoxDecoration(
                                                        color: Theme.of(
                                                          context,
                                                        ).colorScheme.error,
                                                        shape: BoxShape.circle,
                                                        border: Border.all(
                                                          width: 1,
                                                          color: Theme.of(
                                                            context,
                                                          ).cardColor,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    );
                            },
                          ),
                        ),

                      // Earnings and Cash Button (Hidden if there is an active order)
                      GetBuilder<OrderController>(
                        builder: (orderController) {
                          bool hasActiveOrder =
                              (orderController.currentOrderList != null &&
                                  orderController
                                      .currentOrderList!
                                      .isNotEmpty) ||
                              (orderController.latestOrderList != null &&
                                  orderController.latestOrderList!.isNotEmpty);

                          if (hasActiveOrder) {
                            return const SizedBox();
                          }
                          return Positioned(
                            top:
                                context.mediaQueryPadding.top +
                                Dimensions.paddingSizeSmall,
                            left: 0,
                            right: 0,
                            child: Column(
                              children: [
                                Center(
                                  child: GestureDetector(
                                    onTap: () => _showEarningsBottomSheet(
                                      context,
                                      profileController,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: Dimensions.paddingSizeLarge,
                                        vertical: Dimensions.paddingSizeSmall,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black,
                                        borderRadius: BorderRadius.circular(50),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.3,
                                            ),
                                            blurRadius: 10,
                                            offset: const Offset(0, 5),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            PriceConverterHelper.convertPrice(
                                              profileController
                                                      .profileModel
                                                      ?.balance ??
                                                  0,
                                            ),
                                            style: robotoMedium.copyWith(
                                              color: Colors.white,
                                              fontSize:
                                                  Dimensions.fontSizeSmall,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(
                                  height: Dimensions.paddingSizeSmall,
                                ),
                                const CashProgressWidget(),
                              ],
                            ),
                          );
                        },
                      ),

                      if (!Get.find<HomeController>().isNotificationPermissionGranted)
                        Positioned(
                          top: 70,
                          left: 0,
                          right: 0,
                          child: permissionWarning(
                            context: context,
                            isBatteryPermission: false,
                            onTap: requestNotificationPermission,
                            closeOnTap: () {
                              Get.find<HomeController>().setNotificationPermissionGranted(true);
                            },
                          ),
                        ),

                      if (!Get.find<HomeController>().isBatteryOptimizationGranted)
                        Positioned(
                          top: 70,
                          left: 0,
                          right: 0,
                          child: permissionWarning(
                            context: context,
                            isBatteryPermission: true,
                            onTap: requestBatteryOptimization,
                            closeOnTap: () {
                              Get.find<HomeController>().setBatteryOptimizationGranted(true);
                            },
                          ),
                        ),

                      // Se eliminó el botón de ubicación de aquí, se movió a DashboardScreen
                    ],
                  );
                },
              );
            },
          );
        },
      ),
      bottomSheet: GetBuilder<OrderController>(
        builder: (orderController) {
          return (_pendingRequest != null || _activeOrders.isNotEmpty)
          ? (_pendingRequest != null
                ? () {
                    double? storeLat = double.tryParse(
                      _pendingRequest!.storeLat ?? '',
                    );
                    double? storeLng = double.tryParse(
                      _pendingRequest!.storeLng ?? '',
                    );
                    double? dmLat = Get.find<ProfileController>()
                        .recordLocationBody
                        ?.latitude;
                    double? dmLng = Get.find<ProfileController>()
                        .recordLocationBody
                        ?.longitude;
                    double? distance;
                    if (storeLat != null &&
                        storeLng != null &&
                        dmLat != null &&
                        dmLng != null) {
                      distance =
                          _calculateDistance(dmLat, dmLng, storeLat, storeLng) /
                          1000;
                    }

                    return PremiumOrderRequestWidget(
                      orderModel: _pendingRequest!,
                      distance: distance,
                      isTaken: _isOrderTakenByOther,
                      onAccept: () {
                        final orderToAccept = _pendingRequest!;
                        setState(() {
                          _activeOrders.add(orderToAccept);
                          _pendingRequest = null;
                          if (_activeOrders.length == 1) {
                            _orderPhase = 'going_to_store';
                            _startMovementTimer();
                          }
                        });

                        Get.find<OrderController>()
                            .acceptOrder(orderToAccept.id, 0, orderToAccept)
                            .then((isSuccess) {
                              if (isSuccess) {
                                Get.find<OrderController>().getOrderDetails(
                                  orderToAccept.id,
                                  orderToAccept.orderType == 'parcel',
                                );
                                _updateMultiOrderRoute();
                              } else {
                                setState(() {
                                  _activeOrders.removeWhere(
                                    (o) => o.id == orderToAccept.id,
                                  );
                                  if (_activeOrders.isEmpty) {
                                    _orderPhase = 'none';
                                    _stopMovementTimer();
                                  }
                                });
                              }
                            });
                      },
                      onReject: () =>
                          _performCancellation(order: _pendingRequest),
                    );
                  }()
                : AcceptedOrderWidget(
                    activeOrders: _activeOrders,

                    phase: _orderPhase,
                    estimatedArrivalTime: _estimatedArrivalTime,
                    onOrderSelected: (index) {
                      _selectedOrderIndex = index;
                    },
                    onHandover: (order) async {
                      bool success = await Get.find<OrderController>()
                          .updateOrderStatus(order, 'handover');
                      if (success) {
                        setState(() {
                          _orderPhase = 'at_store';
                        });
                      }
                    },
                    onPickedUp: (order) async {
                      bool success = await Get.find<OrderController>()
                          .updateOrderStatus(order, 'picked_up');
                      if (success) {
                        setState(() {
                          _orderPhase = 'going_to_customer';
                        });
                        _updateMultiOrderRoute();
                      }
                    },
                    onDelivered: (order) async {
                      bool success = await Get.find<OrderController>()
                          .updateOrderStatus(order, 'delivered');
                      if (success) {
                        _performCancellation(order: order, callApi: false);
                      }
                    },
                  ))
          : const SizedBox();
        },
      ),
    );
  }

  void cancelOrderRequest({OrderModel? order, bool callApi = true}) {
    final targetOrder = order ??
        (_activeOrders.isNotEmpty
            ? (_selectedOrderIndex < _activeOrders.length
                ? _activeOrders[_selectedOrderIndex]
                : _activeOrders.first)
            : null);
    if (targetOrder == null) return;

    if (_orderPhase != 'none') {
      Get.dialog(
        Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
          ),
          child: Padding(
            padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 50,
                ),
                const SizedBox(height: Dimensions.paddingSizeDefault),
                Text(
                  '¿Cancelar pedido?',
                  style: robotoBold.copyWith(
                    fontSize: Dimensions.fontSizeLarge,
                  ),
                ),
                const SizedBox(height: Dimensions.paddingSizeSmall),
                Text(
                  'Cancelar ordenes confirmadas puede afectar a tu tasa de rendimiento',
                  textAlign: TextAlign.center,
                  style: robotoRegular.copyWith(
                    fontSize: Dimensions.fontSizeSmall,
                  ),
                ),
                const SizedBox(height: Dimensions.paddingSizeLarge),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Get.back(),
                        child: Text(
                          'Volver',
                          style: robotoMedium.copyWith(color: Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(width: Dimensions.paddingSizeSmall),
                    Expanded(
                      child: CustomButtonWidget(
                        buttonText: 'Confirmar',
                        onPressed: () {
                          Get.back();
                          _performCancellation(callApi: callApi);
                        },
                        height: 40,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      _performCancellation(order: targetOrder, callApi: callApi);
    }
  }

  void _performCancellation({OrderModel? order, bool callApi = true}) async {
    final targetOrder =
        order ?? (_activeOrders.isNotEmpty ? _activeOrders.first : null);
    if (targetOrder == null) return;

    debugPrint(
      "[HomeScreen] ❌ _performCancellation called (callApi: $callApi) for order ${targetOrder.id}",
    );

    OrderNotificationService.instance.stopAudio();
    if (callApi && targetOrder.id != null && targetOrder.id != 999) {
      Get.find<OrderController>().ignoreOrderApi(targetOrder.id!);
    }

    widget.onOrderDismissed?.call(targetOrder.id, targetOrder.transactionReference);

    setState(() {
      if (_pendingRequest?.id == targetOrder.id) {
        _pendingRequest = null;
      }
      _activeOrders.removeWhere((o) => o.id == targetOrder.id);

      if (_activeOrders.isEmpty) {
        _orderPhase = 'none';
        Get.find<HomeController>().clearMapData();
        _estimatedArrivalTime = null;
        _stopMovementTimer();
        widget.onOrderActiveStatusChanged?.call(false);
      } else {
        // Si queda otro pedido, recalculamos ruta para ese
        _updateMultiOrderRoute();
      }
    });

    if (_activeOrders.isEmpty) {
      animateToMyLocation();
    }
  }

  void animateToMyLocation() {
    LatLng dmLocation = LatLng(
      Get.find<ProfileController>().recordLocationBody?.latitude ?? 0,
      Get.find<ProfileController>().recordLocationBody?.longitude ?? 0,
    );
    if (dmLocation.latitude != 0) {
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(dmLocation, 16));
    }
  }

  Future<Uint8List> _createNumberedMarkerBitmap(
    int number,
    Color color, {
    int size = 120, // Aumentado para mejor visibilidad
  }) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final double radius = size / 2.0;

    // Draw shadow
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(Offset(radius + 2, radius + 2), radius - 4, shadowPaint);

    // Draw background circle
    final Paint paint = Paint()..color = color;
    canvas.drawCircle(Offset(radius, radius), radius - 4, paint);

    // Draw border
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.08;
    canvas.drawCircle(Offset(radius, radius), radius - 4, borderPaint);

    // Draw text (number)
    TextPainter painter = TextPainter(textDirection: ui.TextDirection.ltr);
    painter.text = TextSpan(
      text: number.toString(),
      style: TextStyle(
        fontSize: size * 0.5,
        fontWeight: FontWeight.bold,
        color: Colors.white,
        shadows: [
          const Shadow(
            blurRadius: 2.0,
            color: Colors.black,
            offset: Offset(1.0, 1.0),
          ),
        ],
      ),
    );
    painter.layout();
    painter.paint(
      canvas,
      Offset(radius - painter.width / 2, radius - painter.height / 2),
    );

    final img = await pictureRecorder.endRecording().toImage(size, size);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  Future<Uint8List> _convertAssetToUnit8List(
    String imagePath, {
    int width = 50,
  }) async {
    ByteData data = await rootBundle.load(imagePath);
    ui.Codec codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: width,
    );
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
  }

  Future<List<LatLng>> _getRoutePolyline(LatLng origin, LatLng destination) {
    return MapboxDirectionsHelper.getDrivingRoute(origin, destination);
  }

  /// Simula solicitud de pedido solo en UI (mock fijo, id 999). Invocado desde el FAB bug en [DashboardScreen].
  /// Reproduce el mismo audio que un pedido real vía [OrderNotificationService.playOrderRequestAlertSound].
  /// No pasa por FCM, `notifyOrderRequest`, `latest-orders` ni backend: no es el mismo flujo que un pedido real.
  void simulateOrderRequest() {
    if (widget.pendingRegistrationDashboard) return;
    OrderNotificationService.instance.playOrderRequestAlertSound();
    // Datos de prueba para simular un pedido en Mexicaltzingo (DIF)
    OrderModel mockOrder = OrderModel(
      id: 999,
      orderAmount: 150.0,
      orderType: 'delivery',
      deliveryCharge: 25.0,
      storeName: 'Tootli Mexicaltzingo Store',
      storeAddress: 'DIF Mexicaltzingo, Edo Mex',
      storeLat: '19.2091',
      storeLng: '-99.5858',
      deliveryAddress: DeliveryAddress(
        address: 'San Mateo Mexicaltzingo, Edo Mex',
        latitude: '19.2120',
        longitude: '-99.5880',
      ),
      customer: Customer(
        fName: 'Usuario',
        lName: 'Prueba',
        phone: '1234567890',
      ),
    );

    setState(() {
      _activeOrders.add(mockOrder);
      _orderPhase = 'none';
    });
    widget.onOrderActiveStatusChanged?.call(true);

    // Dibujar la ruta en el mapa
    setPolyline(mockOrder);
  }

  /// Llamado desde DashboardScreen cuando llega un FCM de pedido nuevo.
  /// Muestra el bottom sheet moderno con datos reales del pedido.
  /// Soporta actualizaciones (ej. de dummy model a modelo real con datos de red).
  void showOrderRequest(OrderModel order) {
    if (widget.pendingRegistrationDashboard) return;
    if (_activeOrders.length >= 2) {
      debugPrint("[HomeScreen] ⛔ IGNORED - max 2 orders already reached");
      return;
    }

    if (_activeOrders.any((o) => o.id == order.id)) {
      debugPrint("[HomeScreen] ⛔ IGNORED - order ${order.id} already active");
      return;
    }

    debugPrint(
      "[HomeScreen] showOrderRequest(${order.id}) activeCount=${_activeOrders.length}",
    );

    if (!mounted) return;

    _lastShownOrderId = order.id;

    setState(() {
      _pendingRequest = order;
      // Si no hay nada activo, esta solicitud se convierte en la principal para el builder
      if (_activeOrders.isEmpty) {
        _orderPhase = 'none';
      }
    });

    widget.onOrderActiveStatusChanged?.call(true);

    if (order.storeLat != null && order.storeLat != '0') {
      setPolyline(order);
    }
  }

  void restoreActiveOrder(OrderModel order) async {
    if (_activeOrders.any((o) => o.id == order.id)) return;
    if (_activeOrders.length >= 2) return;

    setState(() {
      _activeOrders.add(order);
      if (_activeOrders.length == 1) {
        _orderPhase = order.orderStatus == 'picked_up'
            ? 'going_to_customer'
            : 'going_to_store';
      }
    });
    widget.onOrderActiveStatusChanged?.call(true);

    // Obtener datos frescos del servidor
    final OrderModel? fresh = await Get.find<OrderController>()
        .fetchOrderForNotification(order.id!);
    if (!mounted) return;

    if (fresh != null) {
      setState(() {
        int idx = _activeOrders.indexWhere((o) => o.id == fresh.id);
        if (idx != -1) {
          _activeOrders[idx] = fresh;
        }
      });
    }
    _updateMultiOrderRoute();
  }

  void _updateMultiOrderRoute() {
    if (_activeOrders.isNotEmpty) {
      setPolyline(_activeOrders.first);
    }
  }

  void setMultiOrderPolyline() async {
    final route = Get.find<OrderController>().optimizedRoute;
    if (route == null || route.sequence == null || route.sequence!.isEmpty) {
      if (_activeOrders.isNotEmpty) {
        setPolyline(_activeOrders.first);
      }
      return;
    }

    Get.find<HomeController>().clearMapData();
    

    LatLng lastPoint = LatLng(
      Get.find<ProfileController>().recordLocationBody?.latitude ?? 0,
      Get.find<ProfileController>().recordLocationBody?.longitude ?? 0,
    );

    int polylineIndex = 0;
    for (var point in route.sequence!) {
      LatLng currentPoint = LatLng(point.latitude!, point.longitude!);

      // Get route between segments
      List<LatLng> segmentPoints = await _getRoutePolyline(
        lastPoint,
        currentPoint,
      );
      if (segmentPoints.isEmpty) {
        segmentPoints = [lastPoint, currentPoint];
      }

      // Mapear Order ID a su número de pedido (1, 2, ...) para mostrar en el círculo
      int displayNumber = 1;
      for (int i = 0; i < _activeOrders.length; i++) {
        if (_activeOrders[i].id == point.orderId) {
          displayNumber = i + 1;
          break;
        }
      }

      Color markerColor = point.type == 'pickup' 
          ? const Color(0xFFF39C12) 
          : const Color(0xFF2ECC71);

      Uint8List customMarker = await _createNumberedMarkerBitmap(
        displayNumber,
        markerColor,
      );

      setState(() {
        Get.find<HomeController>().polylines.add(
          Polyline(
            polylineId: PolylineId('segment_$polylineIndex'),
            points: segmentPoints,
            color: polylineIndex == 0
                ? Colors.blue
                : Colors.blue.withOpacity(0.5),
            width: 5,
          ),
        );

        Get.find<HomeController>().markers.add(
          Marker(
            markerId: MarkerId(point.id!),
            position: currentPoint,
            icon: BitmapDescriptor.fromBytes(customMarker),
            infoWindow: InfoWindow(
              title: point.type == 'pickup'
                  ? 'Recoger pedido ${point.orderId}'
                  : 'Entregar pedido ${point.orderId}',
              snippet: point.waitTime != null && point.waitTime! > 0
                  ? 'Espera aprox: ${point.waitTime!.toStringAsFixed(0)} min'
                  : null,
            ),
          ),
        );
      });

      lastPoint = currentPoint;
      polylineIndex++;
    }
  }

  bool get isOrderActive => _activeOrders.isNotEmpty || _pendingRequest != null;

  void setPolyline(OrderModel order) async {
    Get.find<HomeController>().clearMapData();
    bool parcel = order.orderType == 'parcel';

    // ── Diagnóstico de coordenadas ──────────────────────────────
    debugPrint('[Polyline] orderType=${order.orderType} parcel=$parcel');
    debugPrint(
      '[Polyline] storeLat=${order.storeLat} storeLng=${order.storeLng}',
    );
    debugPrint(
      '[Polyline] deliveryAddress.lat=${order.deliveryAddress?.latitude} deliveryAddress.lng=${order.deliveryAddress?.longitude}',
    );
    debugPrint(
      '[Polyline] dmLocation: lat=${Get.find<ProfileController>().recordLocationBody?.latitude} lng=${Get.find<ProfileController>().recordLocationBody?.longitude}',
    );

    LatLng dmLocation = LatLng(
      Get.find<ProfileController>().recordLocationBody?.latitude ?? 0,
      Get.find<ProfileController>().recordLocationBody?.longitude ?? 0,
    );

    final double storeLat =
        double.tryParse(
          parcel
              ? order.deliveryAddress?.latitude ?? '0'
              : order.storeLat ?? '0',
        ) ??
        0;
    final double storeLng =
        double.tryParse(
          parcel
              ? order.deliveryAddress?.longitude ?? '0'
              : order.storeLng ?? '0',
        ) ??
        0;
    final double destLat =
        double.tryParse(
          parcel
              ? order.receiverDetails?.latitude ?? '0'
              : order.deliveryAddress?.latitude ?? '0',
        ) ??
        0;
    final double destLng =
        double.tryParse(
          parcel
              ? order.receiverDetails?.longitude ?? '0'
              : order.deliveryAddress?.longitude ?? '0',
        ) ??
        0;

    debugPrint(
      '[Polyline] storeLocation=($storeLat, $storeLng) destLocation=($destLat, $destLng)',
    );

    // Seguridad: si las coordenadas son (0,0), significa que el OrderModel no trajo
    // los datos de ubicación. En ese caso, refrescar el pedido completo y reintentar.
    if (storeLat == 0 && storeLng == 0) {
      debugPrint(
        '[Polyline] ⚠️ storeLat/storeLng son 0 — recargando pedido completo...',
      );
      final refreshed = await Get.find<OrderController>()
          .fetchOrderForNotification(order.id!);
      if (refreshed != null && mounted) {
        debugPrint(
          '[Polyline] Pedido recargado, storeLat=${refreshed.storeLat}',
        );
        setPolyline(refreshed);
      }
      return;
    }

    LatLng storeLocation = LatLng(storeLat, storeLng);
    LatLng destinationLocation = LatLng(destLat, destLng);

    // Dibujamos marcadores y líneas rectas inmediatamente para evitar demoras visuales
    List<LatLng> segment1Points = [dmLocation, storeLocation];
    List<LatLng> segment2Points = [storeLocation, destinationLocation];

    // Usar marcadores precargados (rápido) o cargarlos si aún no están listos
    Uint8List storeMarker =
        _cachedStoreMarker ??
        await _convertAssetToUnit8List(Images.store, width: 40);
    Uint8List destinationMarker =
        _cachedDestinationMarker ??
        await _convertAssetToUnit8List(Images.homeDelivery, width: 40);
    // Guardar en caché para la próxima vez
    _cachedStoreMarker ??= storeMarker;
    _cachedDestinationMarker ??= destinationMarker;

    // Guard: el widget puede haberse desmontado
    if (!mounted) return;

    // Solo marcadores (sin polilínea) hasta tener rutas GPS; evita el “flash” de línea recta / Haversine.
    setState(() {
      _drawLinesAndMarkersOnMap(
        dmLocation,
        storeLocation,
        destinationLocation,
        segment1Points,
        segment2Points,
        storeMarker,
        destinationMarker,
        0,
        drawPolylines: false,
      );
    });

    _fitCamera(dmLocation, storeLocation, destinationLocation);

    // Rutas reales (Mapbox Directions, modo driving) en paralelo
    Future.wait([
          _getRoutePolyline(dmLocation, storeLocation),
          _getRoutePolyline(storeLocation, destinationLocation),
        ])
        .then((results) {
          List<LatLng> seg1 = results[0];
          List<LatLng> seg2 = results[1];

          if (seg1.isNotEmpty) segment1Points = seg1;
          if (seg2.isNotEmpty) segment2Points = seg2;

          if (!mounted) return;

          // Recalcular distancia real
          double totalDistance = 0;
          List<LatLng> activePoints = _orderPhase == 'going_to_customer'
              ? segment2Points
              : segment1Points;

          for (int i = 0; i < activePoints.length - 1; i++) {
            totalDistance += _calculateDistance(
              activePoints[i].latitude,
              activePoints[i].longitude,
              activePoints[i + 1].latitude,
              activePoints[i + 1].longitude,
            );
          }

          setState(() {
            _drawLinesAndMarkersOnMap(
              dmLocation,
              storeLocation,
              destinationLocation,
              segment1Points,
              segment2Points,
              storeMarker,
              destinationMarker,
              totalDistance,
              drawPolylines: true,
            );
          });
        })
        .catchError((e) {
          debugPrint("[HomeScreen] Error parallelizing polylines: $e");
          if (!mounted) return;
          double fallbackDist = 0;
          for (int i = 0; i < segment1Points.length - 1; i++) {
            fallbackDist += _calculateDistance(
              segment1Points[i].latitude,
              segment1Points[i].longitude,
              segment1Points[i + 1].latitude,
              segment1Points[i + 1].longitude,
            );
          }
          for (int i = 0; i < segment2Points.length - 1; i++) {
            fallbackDist += _calculateDistance(
              segment2Points[i].latitude,
              segment2Points[i].longitude,
              segment2Points[i + 1].latitude,
              segment2Points[i + 1].longitude,
            );
          }
          setState(() {
            _drawLinesAndMarkersOnMap(
              dmLocation,
              storeLocation,
              destinationLocation,
              segment1Points,
              segment2Points,
              storeMarker,
              destinationMarker,
              fallbackDist,
              drawPolylines: true,
            );
          });
        });
  }

  void _drawLinesAndMarkersOnMap(
    LatLng dmLocation,
    LatLng storeLocation,
    LatLng destinationLocation,
    List<LatLng> segment1Points,
    List<LatLng> segment2Points,
    Uint8List storeMarker,
    Uint8List destinationMarker,
    double totalDistance, {
    bool drawPolylines = true,
  }) async {
    int minutes = (totalDistance / 333).ceil();
    if (minutes == 0 && totalDistance > 0) minutes = 1;

    if (totalDistance > 0) {
      DateTime arrivalTime = DateTime.now().add(Duration(minutes: minutes));
      _estimatedArrivalTime = DateFormat('HH:mm').format(arrivalTime);
    } else {
      _estimatedArrivalTime = null;
    }

    final route = Get.find<OrderController>().optimizedRoute;

    // Si es multi-pedido y tenemos secuencia, dibujamos los marcadores numerados
    if (route != null && route.sequence != null && route.sequence!.isNotEmpty) {
      
      Get.find<HomeController>().clearMapData();

      LatLng lastPoint = dmLocation;
      int stopIndex = 1;
      double multiRouteTotalDistance = 0;
      double totalWaitTime = 0;

      // Mapear Order ID a su número de pedido (1, 2, ...) para mostrar en el círculo
      Map<int, int> orderIdToDisplayNumber = {};
      int nextDisplayNumber = 1;

      for (var point in route.sequence!) {
        LatLng currentPoint = LatLng(point.latitude!, point.longitude!);
        
        // Asignar número de pedido (1 para el primer pedido encontrado, 2 para el segundo, etc)
        if (!orderIdToDisplayNumber.containsKey(point.orderId)) {
          orderIdToDisplayNumber[point.orderId!] = nextDisplayNumber++;
        }
        int displayNumber = orderIdToDisplayNumber[point.orderId!]!;

        Color markerColor =
            point.type == 'pickup' ? const Color(0xFFF39C12) : const Color(0xFF2ECC71);

        Uint8List customMarker = await _createNumberedMarkerBitmap(
          displayNumber,
          markerColor,
        );

        Get.find<HomeController>().markers.add(
          Marker(
            markerId: MarkerId(point.id!),
            position: currentPoint,
            icon: BitmapDescriptor.fromBytes(customMarker),
            infoWindow: InfoWindow(
              title:
                  '${point.type == 'pickup' ? 'Tienda' : 'Entrega'} #${point.orderId}',
              snippet: 'Parada #$stopIndex (Pedido $displayNumber)',
            ),
          ),
        );

        if (drawPolylines) {
          List<LatLng> segment = await _getRoutePolyline(
            lastPoint,
            currentPoint,
          );
          if (segment.isEmpty) segment = [lastPoint, currentPoint];

          // Calcular distancia de este segmento
          for (int i = 0; i < segment.length - 1; i++) {
            multiRouteTotalDistance += Geolocator.distanceBetween(
              segment[i].latitude,
              segment[i].longitude,
              segment[i + 1].latitude,
              segment[i + 1].longitude,
            );
          }

          Get.find<HomeController>().polylines.add(
            Polyline(
              polylineId: PolylineId('segment_${point.id}'),
              points: segment,
              color: stopIndex == 1 
                ? const Color(0xFF3498DB) 
                : const Color(0xFF3498DB).withValues(alpha: 0.4),
              width: 6,
            ),
          );
        }

        totalWaitTime += point.waitTime ?? 0;
        lastPoint = currentPoint;
        stopIndex++;
      }

      // Actualizar ETA basado en la ruta completa
      int travelMinutes = (multiRouteTotalDistance / 333).ceil(); // 20km/h aprox
      int totalMinutes = travelMinutes + totalWaitTime.toInt();
      
      if (totalMinutes > 0) {
        DateTime arrivalTime = DateTime.now().add(Duration(minutes: totalMinutes));
        _estimatedArrivalTime = DateFormat('HH:mm').format(arrivalTime);
      }
    } else {
      // Lógica original para un solo pedido
      
      Get.find<HomeController>().clearMapData();

      if (_orderPhase == 'going_to_store' || _orderPhase == 'none') {
        Uint8List customMarker = await _createNumberedMarkerBitmap(
          1,
          const Color(0xFFF39C12), // Orange for store
        );
        Get.find<HomeController>().markers.add(
          Marker(
            markerId: const MarkerId('store'),
            position: storeLocation,
            icon: BitmapDescriptor.fromBytes(customMarker),
          ),
        );
      }

      if (_orderPhase == 'going_to_customer') {
        Uint8List customMarker = await _createNumberedMarkerBitmap(
          1,
          const Color(0xFF2ECC71), // Green for customer
        );
        Get.find<HomeController>().markers.add(
          Marker(
            markerId: const MarkerId('destination'),
            position: destinationLocation,
            icon: BitmapDescriptor.fromBytes(customMarker),
          ),
        );
      }

      if (drawPolylines) {
        if (_orderPhase == 'going_to_store' || _orderPhase == 'none') {
          Get.find<HomeController>().polylines.add(
            Polyline(
              polylineId: const PolylineId('delivery_to_store'),
              points: segment1Points,
              color: Theme.of(context).primaryColor,
              width: 5,
            ),
          );
        }
        if (_orderPhase == 'going_to_customer') {
          Get.find<HomeController>().polylines.add(
            Polyline(
              polylineId: const PolylineId('store_to_destination'),
              points: segment2Points,
              color: Theme.of(context).primaryColor,
              width: 5,
            ),
          );
        }
      }
    }
    if (mounted) { setState(() {}); Get.find<HomeController>().update(['map']); }
  }

  void _fitCamera(
    LatLng dmLocation,
    LatLng storeLocation,
    LatLng destinationLocation,
  ) {
    List<LatLng> pointsToFit = [];
    if (_orderPhase == 'going_to_store') {
      pointsToFit = [dmLocation, storeLocation];
    } else if (_orderPhase == 'going_to_customer') {
      pointsToFit = [storeLocation, destinationLocation];
    } else {
      pointsToFit = [dmLocation, storeLocation, destinationLocation];
    }

    LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(
        pointsToFit.map((p) => p.latitude).reduce(min),
        pointsToFit.map((p) => p.longitude).reduce(min),
      ),
      northeast: LatLng(
        pointsToFit.map((p) => p.latitude).reduce(max),
        pointsToFit.map((p) => p.longitude).reduce(max),
      ),
    );

    if (_orderPhase == 'going_to_store' || _orderPhase == 'going_to_customer') {
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: pointsToFit[0],
            zoom: 17,
            tilt: 45,
            bearing: _calculateBearing(pointsToFit[0], pointsToFit[1]),
          ),
        ),
      );
    } else {
      _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
    }
  }

  void _startMovementTimer() {
    _startInactivityTimer();
  }

  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Solo monitorear si hay un pedido activo o en fase de entrega
      if (_activeOrders.isNotEmpty || _orderPhase != 'none') {
        final profileController = Get.find<ProfileController>();
        final currentPos = profileController.recordLocationBody;

        if (currentPos != null &&
            currentPos.latitude != null &&
            currentPos.longitude != null) {
          LatLng currentLatLng = LatLng(
            currentPos.latitude!,
            currentPos.longitude!,
          );

          if (_lastInactivityPosition == null) {
            _lastInactivityPosition = currentLatLng;
          }

          double distance = _calculateDistance(
            _lastInactivityPosition!.latitude,
            _lastInactivityPosition!.longitude,
            currentLatLng.latitude,
            currentLatLng.longitude,
          );

          // Si se movió más de 15 metros, resetear el contador de inactividad
          if (distance > 15) {
            _inactivitySeconds = 0;
            _lastInactivityPosition = currentLatLng;

            if (_isShowingInactivityDialog) {
              if (Get.isDialogOpen ?? false) {
                Get.back();
              }
              _isShowingInactivityDialog = false;
              _governanceAudioPlayer.stop();
            }
          } else {
            _inactivitySeconds++;
          }
        }

        // 5 minutos (300s) = Alerta de audio y diálogo de advertencia
        if (_inactivitySeconds == 300) {
          _showInactivityWarning();
        }
      } else {
        // No hay pedido activo, resetear contadores
        _inactivitySeconds = 0;
        _lastInactivityPosition = null;
      }
    });
  }

  void _showInactivityWarning() {
    if (_isShowingInactivityDialog) return;
    _isShowingInactivityDialog = true;

    _governanceAudioPlayer.play(AssetSource('Dms_no_moving.mp3'));

    Get.dialog(
      Dialog(
        backgroundColor: Colors.orange,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.white,
                size: 60,
              ),
              const SizedBox(height: Dimensions.paddingSizeDefault),
              Text(
                '¿SIGUES AHÍ?',
                style: robotoBold.copyWith(color: Colors.white, fontSize: 20),
              ),
              const SizedBox(height: Dimensions.paddingSizeSmall),
              const Text(
                'No detectamos movimiento. Por favor continúa con la entrega para evitar la reasignación del pedido.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: Dimensions.paddingSizeLarge),
              CustomButtonWidget(
                buttonText: 'ESTOY EN CAMINO',
                onPressed: () {
                  _inactivitySeconds = 0;
                  _isShowingInactivityDialog = false;
                  _governanceAudioPlayer.stop();
                  Get.back();
                },
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  void _showUnassignedDialog() {
    _governanceAudioPlayer.play(AssetSource('pedido_reasingado.mp3'));
    Get.dialog(
      Dialog(
        backgroundColor: Colors.red,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 60),
              const SizedBox(height: Dimensions.paddingSizeDefault),
              Text(
                'PEDIDO REASIGNADO',
                style: robotoBold.copyWith(color: Colors.white, fontSize: 20),
              ),
              const SizedBox(height: Dimensions.paddingSizeSmall),
              Text(
                'El pedido se reasigno, cancelar ordenes por incatividad afecta a tu cuenta',
                textAlign: TextAlign.center,
                style: robotoMedium.copyWith(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: Dimensions.paddingSizeExtraLarge),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        Dimensions.radiusSmall,
                      ),
                    ),
                  ),
                  onPressed: () => Get.back(),
                  child: Text('ACEPTAR', style: robotoBold),
                ),
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false, // Forzar a que de "Aceptar"
    );
  }

  void showInactivityWarningFromNotification(int orderId) {
    if (_activeOrders.any((o) => o.id == orderId)) {
      _showInactivityWarning();
    }
  }

  void showUnassignedDialogFromNotification(int orderId) {
    final order = _activeOrders.firstWhereOrNull((o) => o.id == orderId);
    if (order != null) {
      _showUnassignedDialog();
      _performCancellation(order: order, callApi: false);
    }
  }

  void _stopMovementTimer() {
    // Reservado para cuando se reactive el timer de movimiento.
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    var p = 0.017453292519943295;
    var c = cos;
    var a =
        0.5 -
        c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)) * 1000; // a metros
  }

  double _calculateBearing(LatLng start, LatLng end) {
    double lat1 = start.latitude * pi / 180;
    double lon1 = start.longitude * pi / 180;
    double lat2 = end.latitude * pi / 180;
    double lon2 = end.longitude * pi / 180;

    double dLon = lon2 - lon1;
    double y = sin(dLon) * cos(lat2);
    double x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
    double brng = atan2(y, x) * 180 / pi;
    return (brng + 360) % 360;
  }

  void _showEarningsBottomSheet(
    BuildContext context,
    ProfileController profileController,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(Dimensions.radiusLarge),
            ),
          ),
          padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 5,
                width: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context).disabledColor,
                  borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                ),
              ),
              const SizedBox(height: Dimensions.paddingSizeLarge),

              Text(
                'your_balance'.tr,
                style: robotoMedium.copyWith(
                  fontSize: Dimensions.fontSizeSmall,
                  color: Theme.of(context).disabledColor,
                ),
              ),
              const SizedBox(height: Dimensions.paddingSizeExtraSmall),
              Text(
                PriceConverterHelper.convertPrice(
                  profileController.profileModel?.balance ?? 0,
                ),
                style: robotoBold.copyWith(
                  fontSize: Dimensions.fontSizeOverLarge,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: Dimensions.paddingSizeDefault),

              Row(
                children: [
                  EarningWidget(
                    title: 'today'.tr,
                    amount: profileController.profileModel?.todaysEarning,
                  ),
                  Container(
                    height: 30,
                    width: 1,
                    color: Theme.of(
                      context,
                    ).disabledColor.withValues(alpha: 0.5),
                  ),
                  EarningWidget(
                    title: 'this_week'.tr,
                    amount: profileController.profileModel?.thisWeekEarning,
                  ),
                  Container(
                    height: 30,
                    width: 1,
                    color: Theme.of(
                      context,
                    ).disabledColor.withValues(alpha: 0.5),
                  ),
                  EarningWidget(
                    title: 'this_month'.tr,
                    amount: profileController.profileModel?.thisMonthEarning,
                  ),
                ],
              ),
              const SizedBox(height: Dimensions.paddingSizeLarge),

              CustomButtonWidget(
                buttonText: 'view_details'.tr,
                onPressed: () {
                  Get.back();
                  Get.toNamed(RouteHelper.getMyAccountRoute());
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget permissionWarning({
    required BuildContext context,
    required bool isBatteryPermission,
    required Function() onTap,
    required Function() closeOnTap,
  }) {
    return GetPlatform.isAndroid
        ? Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: isBatteryPermission
                  ? Colors.orange.withOpacity(0.9)
                  : Theme.of(
                      context,
                    ).textTheme.bodyLarge!.color?.withValues(alpha: 0.7),
            ),
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
                child: Row(
                  children: [
                    Icon(
                      isBatteryPermission
                          ? Icons.battery_alert
                          : Icons.notifications_off,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: Dimensions.paddingSizeSmall),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isBatteryPermission
                                ? 'Optimización de batería activa'
                                : 'Notificaciones desactivadas',
                            style: robotoBold.copyWith(
                              fontSize: Dimensions.fontSizeSmall,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            isBatteryPermission
                                ? 'Permite que Tootli funcione en segundo plano para rastreo constante.'
                                : 'Por favor activa las notificaciones para recibir pedidos.',
                            style: robotoRegular.copyWith(
                              fontSize: Dimensions.fontSizeExtraSmall,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_circle_right_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),
          )
        : const SizedBox();
  }
}
