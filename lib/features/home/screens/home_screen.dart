import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:sixam_mart_delivery/features/auth/controllers/auth_controller.dart';
import 'package:sixam_mart_delivery/features/order/controllers/order_controller.dart';
import 'package:sixam_mart_delivery/features/notification/controllers/notification_controller.dart';
import 'package:sixam_mart_delivery/features/profile/controllers/profile_controller.dart';
import 'package:sixam_mart_delivery/helper/price_converter_helper.dart';
import 'package:sixam_mart_delivery/helper/route_helper.dart';
import 'package:sixam_mart_delivery/util/dimensions.dart';
import 'package:sixam_mart_delivery/util/images.dart';
import 'package:sixam_mart_delivery/util/styles.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_button_widget.dart';
import 'package:sixam_mart_delivery/features/home/widgets/earning_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sixam_mart_delivery/features/address/controllers/address_controller.dart';
import 'package:sixam_mart_delivery/features/address/domain/models/zone_model.dart';
import 'package:sixam_mart_delivery/util/app_constants.dart';
import 'package:sixam_mart_delivery/features/order/widgets/order_requset_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onNavigateToOrders});
  final Function()? onNavigateToOrders;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final AppLifecycleListener _listener;
  bool _isNotificationPermissionGranted = true;
  bool _isBatteryOptimizationGranted = true;
  GoogleMapController? _mapController;
  Timer? _gridTimer;
  double _currentZoom = 16;
  final Set<Polygon> _polygons = {};
  final Set<Marker> _markers = {};
  int _previousOrderCount = 0;

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

  void _refreshGrids() {
    int? zoneId = Get.find<ProfileController>().profileModel?.zoneId;
    if (zoneId != null) {
      Get.find<AddressController>().getGridList(zoneId);
    }
  }

  Future<void> _loadData() async {
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
    _listener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: null,

      body: GetBuilder<OrderController>(
        builder: (orderController) {
          // Check for new orders to show dialog
          if (orderController.latestOrderList != null &&
              orderController.latestOrderList!.length > _previousOrderCount) {
            _previousOrderCount = orderController.latestOrderList!.length;
            if (orderController.latestOrderList!.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (BuildContext context) {
                    return Dialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          Dimensions.radiusDefault,
                        ),
                      ),
                      insetPadding: const EdgeInsets.all(
                        Dimensions.paddingSizeSmall,
                      ),
                      child: OrderRequestWidget(
                        orderModel: orderController.latestOrderList![0],
                        index: 0,
                        onTap: () {
                          Get.back(); // close dialog
                        },
                      ),
                    );
                  },
                );
              });
            }
          } else if (orderController.latestOrderList != null) {
            _previousOrderCount = orderController.latestOrderList!.length;
          }

          return GetBuilder<ProfileController>(
            builder: (profileController) {
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

                      // Notification Button
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
                            isBatteryPermission: true,
                            onTap: requestBatteryOptimization,
                            closeOnTap: () {
                              setState(() {
                                _isBatteryOptimizationGranted = true;
                              });
                            },
                          ),
                        ),

                      // My Location Button
                      Positioned(
                        bottom: 20,
                        right: 20,
                        child: InkWell(
                          onTap: () {
                            if (profileController.recordLocationBody != null) {
                              _mapController?.animateCamera(
                                CameraUpdate.newLatLngZoom(
                                  LatLng(
                                    profileController
                                        .recordLocationBody!
                                        .latitude!,
                                    profileController
                                        .recordLocationBody!
                                        .longitude!,
                                  ),
                                  17,
                                ),
                              );
                            }
                          },
                          child: Container(
                            height: 50,
                            width: 50,
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.my_location,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
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
    required bool isBatteryPermission,
    required Function() onTap,
    required Function() closeOnTap,
  }) {
    return GetPlatform.isAndroid
        ? Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).textTheme.bodyLarge!.color?.withValues(alpha: 0.7),
            ),
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
                child: Row(
                  children: [
                    if (isBatteryPermission)
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Image.asset(
                          Images.allertIcon,
                          height: 20,
                          width: 20,
                        ),
                      ),

                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              isBatteryPermission
                                  ? 'for_better_performance_allow_notification_to_run_in_background'
                                        .tr
                                  : 'notification_is_disabled_please_allow_notification'
                                        .tr,
                              maxLines: 2,
                              style: robotoRegular.copyWith(
                                fontSize: Dimensions.fontSizeSmall,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: Dimensions.paddingSizeSmall),
                          const Icon(
                            Icons.arrow_circle_right_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        : const SizedBox();
  }
}
