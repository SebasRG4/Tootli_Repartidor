import 'dart:async';
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
  });
  /// Registro con `application_status` pending (revisión inicial o correcciones del admin).
  final bool pendingRegistrationDashboard;
  final Function()? onNavigateToOrders;
  final Function()? onTapMenu;
  final Function(bool isActive)? onOrderActiveStatusChanged;

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  late final AppLifecycleListener _listener;
  bool _isNotificationPermissionGranted = true;
  bool _isBatteryOptimizationGranted = true;
  GoogleMapController? _mapController;
  Timer? _gridTimer;
  double _currentZoom = 16;
  final Set<Polygon> _polygons = {};
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  OrderModel? _activeOrderRequest;
  String _orderPhase = 'none'; // 'none', 'going_to_store', 'going_to_customer'
  double? _lastLat;
  double? _lastLng;
  int _noMovementCount = 0;
  String? _estimatedArrivalTime;
  Timer? _noMovementTimer;
  final AudioPlayer _governanceAudioPlayer = AudioPlayer();
  /// Último orderId enviado a showOrderRequest para evitar mostrar el mismo pedido dos veces
  int? _lastShownOrderId;

  @override
  void initState() {
    super.initState();

    _checkSystemNotification();

    _listener = AppLifecycleListener(onStateChange: _onStateChanged);

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
        break;
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.hidden:
        break;
      case AppLifecycleState.paused:
        break;
    }
  }

  Future<void> checkPermission() async {
    var notificationStatus = await Permission.notification.status;
    var batteryStatus = await Permission.ignoreBatteryOptimizations.status;

    if (notificationStatus.isDenied || notificationStatus.isPermanentlyDenied) {
      setState(() {
        _isNotificationPermissionGranted = false;
        _isBatteryOptimizationGranted = true;
      });

      await Get.find<AuthController>().setNotificationActive(
        !notificationStatus.isDenied,
      );
    } else if (batteryStatus.isDenied) {
      setState(() {
        _isBatteryOptimizationGranted = false;
        _isNotificationPermissionGranted = true;
      });
    } else {
      setState(() {
        _isNotificationPermissionGranted = true;
        _isBatteryOptimizationGranted = true;
      });
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
    _polygons.clear();
    int? profileZoneId = Get.find<ProfileController>().profileModel?.zoneId;

    for (var zone in zoneList) {
      if (zone.coordinates != null && zone.coordinates!.coordinates != null) {
        _polygons.add(
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
  }

  @override
  void dispose() {
    _gridTimer?.cancel();
    _noMovementTimer?.cancel();
    _governanceAudioPlayer.dispose();
    _listener.dispose();
    super.dispose();
  }

  bool _hasCenteredOnLaunch = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: null,

      body: GetBuilder<OrderController>(
        builder: (orderController) {

          return GetBuilder<ProfileController>(
            builder: (profileController) {
              // Auto-centro inicial cuando la ubicación llega por primera vez y no hay pedido activo
              if (!_hasCenteredOnLaunch &&
                  profileController.recordLocationBody != null &&
                  _mapController != null &&
                  _activeOrderRequest == null) {
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

              return GetBuilder<AddressController>(
                builder: (addressController) {
                  if (addressController.zoneList != null) {
                    _getPolygons(addressController.zoneList!);
                  }

                  return Stack(
                    children: [
                      GoogleMap(
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
                        polygons: {
                          ..._polygons,
                          ...addressController.gridPolygons,
                        },
                        markers: {
                          ..._markers,
                          if (_currentZoom > 14)
                            ...addressController.gridMarkers,
                        },
                        polylines: _polylines,
                        padding: EdgeInsets.only(
                          bottom: _activeOrderRequest != null ? 350 : 0,
                        ),
                        onCameraMove: (position) {
                          // Only trigger setState if we cross the zoom threshold (14.5)
                          bool wasVisible = _currentZoom > 14.5;
                          bool isVisible = position.zoom > 14.5;

                          if (wasVisible != isVisible) {
                            setState(() {
                              _currentZoom = position.zoom;
                            });
                          }
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
                      ),

                      // Menu Button
                      Positioned(
                        top:
                            context.mediaQueryPadding.top +
                            Dimensions.paddingSizeSmall,
                        left: Dimensions.paddingSizeDefault,
                        child: Container(
                          height: 40,
                          width: 40,
                          decoration: BoxDecoration(
                            color: _activeOrderRequest != null
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
                              _activeOrderRequest != null
                                  ? Icons.close
                                  : Icons.menu,
                              size: 25,
                              color: _activeOrderRequest != null
                                  ? Colors.white
                                  : Theme.of(
                                      context,
                                    ).textTheme.bodyLarge!.color,
                            ),
                            onPressed: _activeOrderRequest != null
                                ? cancelOrderRequest
                                : widget.onTapMenu,
                          ),
                        ),
                      ),

                      // Notification Button
                      if (!profileController.isPendingRegistrationDashboard)
                      Positioned(
                        top:
                            context.mediaQueryPadding.top +
                            Dimensions.paddingSizeSmall,
                        right: Dimensions.paddingSizeDefault,
                        child: GetBuilder<NotificationController>(
                          builder: (notificationController) {
                            return InkWell(
                              onTap: () => Get.toNamed(
                                RouteHelper.getNotificationRoute(),
                              ),
                              child: Container(
                                height: 40,
                                width: 40,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.1,
                                      ),
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
                                        color: Theme.of(
                                          context,
                                        ).textTheme.bodyLarge!.color,
                                      ),
                                    ),
                                    if (notificationController.hasNotification)
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
                        ),
                      ),

                      // Earnings Button
                      Positioned(
                        top:
                            context.mediaQueryPadding.top +
                            Dimensions.paddingSizeSmall,
                        left: 0,
                        right: 0,
                        child: Center(
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
                                    color: Colors.black.withValues(alpha: 0.3),
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
                                      profileController.profileModel?.balance ??
                                          0,
                                    ),
                                    style: robotoMedium.copyWith(
                                      color: Colors.white,
                                      fontSize: Dimensions.fontSizeSmall,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      if (!_isNotificationPermissionGranted)
                        Positioned(
                          top: 70,
                          left: 0,
                          right: 0,
                          child: permissionWarning(
                            context: context,
                            isBatteryPermission: false,
                            onTap: requestNotificationPermission,
                            closeOnTap: () {
                              setState(() {
                                _isNotificationPermissionGranted = true;
                              });
                            },
                          ),
                        ),

                      if (!_isBatteryOptimizationGranted)
                        Positioned(
                          top: 70,
                          left: 0,
                          right: 0,
                          child: permissionWarning(
                            context: context,
                            isBatteryPermission: true,
                            onTap: requestBatteryOptimization,
                            closeOnTap: () {
                              setState(() {
                                _isBatteryOptimizationGranted = true;
                              });
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
      bottomSheet: _activeOrderRequest != null
          ? (_orderPhase == 'none'
                ? () {
                    double? storeLat = double.tryParse(
                      _activeOrderRequest!.storeLat ?? '',
                    );
                    double? storeLng = double.tryParse(
                      _activeOrderRequest!.storeLng ?? '',
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
                      orderModel: _activeOrderRequest!,
                      distance: distance,
                      onAccept: () {
                        // Guard: si ya se está procesando, no hacer nada
                        if (_orderPhase != 'none') return;
                        setState(() {
                          _orderPhase = 'going_to_store'; // Bloquear inmediatamente
                          _startMovementTimer();
                        });
                        // Llamar al API de aceptación una sola vez
                        Get.find<OrderController>().acceptOrder(
                          _activeOrderRequest!.id,
                          0,
                          _activeOrderRequest!,
                        ).then((isSuccess) {
                          if (isSuccess) {
                            Get.find<OrderController>().getOrderDetails(
                              _activeOrderRequest!.id,
                              _activeOrderRequest!.orderType == 'parcel',
                            );
                            setPolyline(_activeOrderRequest!);
                          } else {
                            // Si falla, revertir el estado
                            setState(() {
                              _orderPhase = 'none';
                              _activeOrderRequest = null;
                              _stopMovementTimer();
                            });
                            widget.onOrderActiveStatusChanged?.call(false);
                          }
                        });
                      },
                      onReject: _performCancellation,
                    );
                  }()
                : AcceptedOrderWidget(
                    orderModel: _activeOrderRequest!,
                    phase: _orderPhase,
                    estimatedArrivalTime: _estimatedArrivalTime,
                    onHandover: () async {
                      bool success = await Get.find<OrderController>()
                          .updateOrderStatus(_activeOrderRequest!, 'handover');
                      if (success) {
                        setState(() {
                          _orderPhase = 'at_store';
                        });
                      } else {
                        showCustomSnackBar(
                          'Error al actualizar el estado del pedido a recogido (handover)',
                          isError: true,
                        );
                      }
                    },
                    onPickedUp: () async {
                      bool success = await Get.find<OrderController>()
                          .updateOrderStatus(_activeOrderRequest!, 'picked_up');
                      if (success) {
                        setState(() {
                          _orderPhase = 'going_to_customer';
                        });
                        setPolyline(_activeOrderRequest!);
                      } else {
                        showCustomSnackBar(
                          'Error al actualizar el estado del pedido a en camino',
                          isError: true,
                        );
                      }
                    },
                    onDelivered: () async {
                      bool success = await Get.find<OrderController>()
                          .updateOrderStatus(_activeOrderRequest!, 'delivered');
                      if (success) {
                        showCustomSnackBar(
                          'Pedido entregado con éxito',
                          isError: false,
                        );
                        setState(() {
                          _activeOrderRequest = null;
                          _orderPhase = 'none';
                          _polylines.clear();
                          _markers.clear();
                          _polygons.clear();
                          _stopMovementTimer();
                        });
                        widget.onOrderActiveStatusChanged?.call(false);
                      }
                    },
                  ))
          : null,
    );
  }

  void cancelOrderRequest() {
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
                          _performCancellation();
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
      _performCancellation();
    }
  }

  void _performCancellation() async {
    OrderNotificationService.instance.stopAudio();
    if (_activeOrderRequest != null && _activeOrderRequest!.id != 999) {
      Get.find<OrderController>().ignoreOrderApi(_activeOrderRequest!.id!);
    }

    setState(() {
      _activeOrderRequest = null;
      _orderPhase = 'none';
      _polylines.clear();
      _markers.clear();
      _noMovementCount = 0;
      _estimatedArrivalTime = null;
      _stopMovementTimer();
    });
    widget.onOrderActiveStatusChanged?.call(false);
    animateToMyLocation();
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

  Future<List<LatLng>> _getRoutePolyline(
    LatLng origin,
    LatLng destination,
  ) {
    return MapboxDirectionsHelper.getDrivingRoute(origin, destination);
  }

  /// Simula una solicitud de pedido en UI (sin backend). Antes se invocaba desde el FAB
  /// con icono de bug en [DashboardScreen]; quedó comentado allí para producción.
  /// Para volver a usarlo: descomenta el bloque `bug_button` en `dashboard_screen.dart`.
  void simulateOrderRequest() {
    if (widget.pendingRegistrationDashboard) return;
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
      _activeOrderRequest = mockOrder;
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
    print("\n┌──────────────────────────────────────────────┐");
    print("│  🏠 HomeScreen.showOrderRequest(${order.id})      │");
    print("└──────────────────────────────────────────────┘");
    print("[HomeScreen] mounted=$mounted");
    print("[HomeScreen] _activeOrderRequest=${_activeOrderRequest?.id}");
    print("[HomeScreen] _lastShownOrderId=$_lastShownOrderId");
    print("[HomeScreen] _orderPhase=$_orderPhase");
    print("[HomeScreen] order.storeLat=${order.storeLat}, order.storeName=${order.storeName}");

    if (!mounted) {
      print("[HomeScreen] ⛔ NOT MOUNTED - returning");
      return;
    }

    // Si ya tenemos un pedido activo con DIFERENTE ID, ignorar el nuevo
    if (_activeOrderRequest != null && _activeOrderRequest!.id != order.id) {
       print("[HomeScreen] ⛔ IGNORED - active order already ${_activeOrderRequest!.id}");
       return;
    }

    bool isUpdate = _activeOrderRequest != null && _activeOrderRequest!.id == order.id;

    // Deduplicación para pedidos nuevos (no updates)
    if (!isUpdate && order.id != null && order.id == _lastShownOrderId) {
      print("[HomeScreen] ⛔ IGNORED - duplicate orderId ${order.id}");
      return;
    }
    _lastShownOrderId = order.id;

    print("[HomeScreen] ✅ ${isUpdate ? 'UPDATING' : 'SHOWING'} bottom sheet for order ${order.id}");

    // Reproducir alerta sonora solo si es un pedido nuevo (no en update)
    if (!isUpdate) {
      try {
        _governanceAudioPlayer.stop(); // Solo detener previas si las hay
      } catch (e) {
        print("[HomeScreen] Error stopping audio: $e");
      }
    }

    setState(() {
      _activeOrderRequest = order;
      if (!isUpdate) _orderPhase = 'none';
    });
    print("[HomeScreen] ✅ setState called - _activeOrderRequest is now ${_activeOrderRequest?.id}");

    if (!isUpdate) widget.onOrderActiveStatusChanged?.call(true);

    // Dibujar la ruta solo si tenemos coordenadas (el dummy model no las tiene)
    if (order.storeLat != null && order.storeLat != '0') {
      setPolyline(order);
    }
  }


  void restoreActiveOrder(OrderModel order) {
    if (_activeOrderRequest != null) return;

    setState(() {
      _activeOrderRequest = order;
      if (order.orderStatus == 'picked_up') {
        _orderPhase = 'going_to_customer';
      } else {
        _orderPhase = 'going_to_store';
      }
      _startMovementTimer();
    });
    
    Get.find<OrderController>().getOrderDetails(
      order.id,
      order.orderType == 'parcel',
    );

    widget.onOrderActiveStatusChanged?.call(true);
    setPolyline(order);
  }

  bool get isOrderActive => _activeOrderRequest != null;

  void setPolyline(OrderModel order) async {
    _polylines.clear();
    bool parcel = order.orderType == 'parcel';

    // ── Diagnóstico de coordenadas ──────────────────────────────
    debugPrint('[Polyline] orderType=${order.orderType} parcel=$parcel');
    debugPrint('[Polyline] storeLat=${order.storeLat} storeLng=${order.storeLng}');
    debugPrint('[Polyline] deliveryAddress.lat=${order.deliveryAddress?.latitude} deliveryAddress.lng=${order.deliveryAddress?.longitude}');
    debugPrint('[Polyline] dmLocation: lat=${Get.find<ProfileController>().recordLocationBody?.latitude} lng=${Get.find<ProfileController>().recordLocationBody?.longitude}');

    LatLng dmLocation = LatLng(
      Get.find<ProfileController>().recordLocationBody?.latitude ?? 0,
      Get.find<ProfileController>().recordLocationBody?.longitude ?? 0,
    );

    final double storeLat = double.tryParse(
          parcel ? order.deliveryAddress?.latitude ?? '0' : order.storeLat ?? '0',
        ) ?? 0;
    final double storeLng = double.tryParse(
          parcel ? order.deliveryAddress?.longitude ?? '0' : order.storeLng ?? '0',
        ) ?? 0;
    final double destLat = double.tryParse(
          parcel ? order.receiverDetails?.latitude ?? '0' : order.deliveryAddress?.latitude ?? '0',
        ) ?? 0;
    final double destLng = double.tryParse(
          parcel ? order.receiverDetails?.longitude ?? '0' : order.deliveryAddress?.longitude ?? '0',
        ) ?? 0;

    debugPrint('[Polyline] storeLocation=($storeLat, $storeLng) destLocation=($destLat, $destLng)');

    // Seguridad: si las coordenadas son (0,0), significa que el OrderModel no trajo
    // los datos de ubicación. En ese caso, refrescar el pedido completo y reintentar.
    if (storeLat == 0 && storeLng == 0) {
      debugPrint('[Polyline] ⚠️ storeLat/storeLng son 0 — recargando pedido completo...');
      final refreshed = await Get.find<OrderController>().fetchOrderForNotification(order.id!);
      if (refreshed != null && mounted) {
        debugPrint('[Polyline] Pedido recargado, storeLat=${refreshed.storeLat}');
        setPolyline(refreshed);
      }
      return;
    }

    LatLng storeLocation = LatLng(storeLat, storeLng);
    LatLng destinationLocation = LatLng(destLat, destLng);

    // Dibujamos marcadores y líneas rectas inmediatamente para evitar demoras visuales
    List<LatLng> segment1Points = [dmLocation, storeLocation];
    List<LatLng> segment2Points = [storeLocation, destinationLocation];

    Uint8List storeMarker = await _convertAssetToUnit8List(
      Images.store,
      width: 40,
    );
    Uint8List destinationMarker = await _convertAssetToUnit8List(
      Images.homeDelivery,
      width: 40,
    );

    // Guard: el widget puede haberse desmontado
    if (!mounted) return;

    // Pintar rápido línea recta o marcadores para evitar que el Bottom Sheet se trabe
    setState(() {
      _drawLinesAndMarkersOnMap(
        dmLocation,
        storeLocation,
        destinationLocation,
        segment1Points,
        segment2Points,
        storeMarker,
        destinationMarker,
        0, // Sin distancia real aún
      );
    });

    // Ajustar cámara inicial rápidamente
    _fitCamera(dmLocation, storeLocation, destinationLocation);

    // Ajustar cámara inicial rápidamente
    _fitCamera(dmLocation, storeLocation, destinationLocation);

    // Sustituir línea recta por ruta real (Mapbox Directions, modo driving) en paralelo
    Future.wait([
      _getRoutePolyline(dmLocation, storeLocation),
      _getRoutePolyline(storeLocation, destinationLocation),
    ]).then((results) {
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
        );
      });
    }).catchError((e) {
      debugPrint("[HomeScreen] Error parallelizing polylines: $e");
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
    double totalDistance,
  ) {
    int minutes = (totalDistance / 333).ceil();
    if (minutes == 0 && totalDistance > 0) minutes = 1;

    if (totalDistance > 0) {
      DateTime arrivalTime = DateTime.parse(
        DateTime.now().add(Duration(minutes: minutes)).toString(),
      );
      _estimatedArrivalTime = DateFormat('HH:mm').format(arrivalTime);
    } else {
      _estimatedArrivalTime = null;
    }

    _markers.clear();
    _polylines.clear();
    // En la fase de ir a la tienda, mostramos el marcador de la tienda
      if (_orderPhase == 'going_to_store' || _orderPhase == 'none') {
        _markers.add(
          Marker(
            markerId: const MarkerId('store'),
            position: storeLocation,
            icon: BitmapDescriptor.bytes(storeMarker),
          ),
        );
      }

      // En la fase de ir al cliente, mostramos el marcador del destino
      if (_orderPhase == 'going_to_customer') {
        _markers.add(
          Marker(
            markerId: const MarkerId('destination'),
            position: destinationLocation,
            icon: BitmapDescriptor.bytes(destinationMarker),
          ),
        );
      }

      // Segmento 1: Repartidor -> Tienda (Solo si no hemos recogido)
      if (_orderPhase == 'going_to_store' || _orderPhase == 'none') {
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('delivery_to_store'),
            points: segment1Points,
            color: Theme.of(Get.context!).primaryColor,
            width: 5,
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
        );
      }

      // Segmento 2: Tienda -> Cliente (Solo si ya recogimos el pedido)
      if (_orderPhase == 'going_to_customer') {
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('store_to_destination'),
            points: segment2Points,
            color: Theme.of(Get.context!).primaryColor,
            width: 5,
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
        );
      } else if (_orderPhase == 'none') {
        // En vista previa mostramos la ruta al cliente punteada
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('store_to_destination'),
            points: segment2Points,
            color: Theme.of(Get.context!).primaryColor.withOpacity(0.6),
            width: 5,
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            patterns: [PatternItem.dash(15), PatternItem.gap(10)],
          ),
        );
      }
  }

  void _fitCamera(LatLng dmLocation, LatLng storeLocation, LatLng destinationLocation) {
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
    _noMovementTimer?.cancel();
    _noMovementCount = 0;
    _lastLat = Get.find<ProfileController>().recordLocationBody?.latitude;
    _lastLng = Get.find<ProfileController>().recordLocationBody?.longitude;

    _noMovementTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_orderPhase != 'going_to_store' &&
          _orderPhase != 'going_to_customer') {
        _stopMovementTimer();
        return;
      }

      /*
      // COMENTADO MIENTRAS TANTO PARA EVITAR INACTIVIDAD
      double? currentLat =
          Get.find<ProfileController>().recordLocationBody?.latitude;
      double? currentLng =
          Get.find<ProfileController>().recordLocationBody?.longitude;

      if (currentLat != null &&
          currentLng != null &&
          _lastLat != null &&
          _lastLng != null) {
        double distance = _calculateDistance(
          _lastLat!,
          _lastLng!,
          currentLat,
          currentLng,
        );

        if (distance < 50) {
          _noMovementCount++;
          // A partir de 1.5 min (3 checks de 30s) empieza a sonar
          if (_noMovementCount == 3) {
            _governanceAudioPlayer.play(AssetSource('Dms_no_moving.mp3'));
            showCustomSnackBar(
              '¡Muévete pronto! Si no avanzas, el pedido se cancelará automáticamente',
              isError: true,
            );
          } else if (_noMovementCount > 3 && _noMovementCount < 6) {
            // Repetir cada 30s hasta llegar a los 3 min
            _governanceAudioPlayer.play(AssetSource('Dms_no_moving.mp3'));
          } else if (_noMovementCount >= 6) {
            // Llegamos a los 3 min (6 checks de 30s)
            // _performCancellation(); // COMENTADO TEMPORALMENTE
            _showUnassignedDialog();
          }
        } else {
          _noMovementCount = 0;
          _lastLat = currentLat;
          _lastLng = currentLng;
        }
      } else {
        _lastLat = currentLat;
        _lastLng = currentLng;
      }
      */
    });
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

  void _stopMovementTimer() {
    _noMovementTimer?.cancel();
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
