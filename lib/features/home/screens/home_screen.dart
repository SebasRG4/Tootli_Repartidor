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
import 'package:sixam_mart_delivery/helper/grid_helper.dart';

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
  final Set<Polygon> _polygons = {};
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();

    _checkSystemNotification();

    _listener = AppLifecycleListener(onStateChange: _onStateChanged);

    _loadData();

    Future.delayed(const Duration(milliseconds: 200), () {
      checkPermission();
    });

    Get.find<AddressController>().getZoneList();
  }

  Future<void> _loadData() async {
    Get.find<OrderController>().getIgnoreList();
    Get.find<OrderController>().removeFromIgnoreList();
    await Get.find<ProfileController>().getProfile();

    int? zoneId = Get.find<ProfileController>().profileModel?.zoneId;
    if (zoneId != null) {
      Get.find<AddressController>().getGridList(zoneId);
    }

    await Get.find<OrderController>().getRunningOrders(1);
    await Get.find<NotificationController>().getNotificationList();
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

  void _getPolygons(List<ZoneModel> zoneList, List<dynamic>? gridList) {
    _polygons.clear();
    _markers.clear();
    int? profileZoneId = Get.find<ProfileController>().profileModel?.zoneId;

    for (var zone in zoneList) {
      if (zone.coordinates != null && zone.coordinates!.coordinates != null) {
        _polygons.add(
          Polygon(
            polygonId: PolygonId('zone_${zone.id}'),
            points: zone.coordinates!.coordinates!,
            strokeWidth: zone.id == profileZoneId ? 3 : 1,
            strokeColor: zone.id == profileZoneId
                ? Colors.blueAccent
                : Colors.blueGrey.withValues(alpha: 0.5),
            fillColor: zone.id == profileZoneId
                ? Colors.blueAccent.withValues(alpha: 0.1)
                : Colors.transparent, // Restoring the zone fill color
          ),
        );
      }
    }

    if (gridList != null) {
      for (var grid in gridList) {
        try {
          String hexId = grid['hexagon_id'].toString();
          String deliveryType = grid['delivery_type'].toString();
          List<LatLng> points = GridHelper.getHexagonPoints(hexId);

          if (points.isNotEmpty) {
            Color fillColor = Colors.transparent;
            Color strokeColor = Colors.orangeAccent;
            double width = 1;

            if (deliveryType == 'minutes') {
              fillColor = Colors.orange.withValues(alpha: 0.3);
              strokeColor = Colors.orange;
              width = 2;

              // Add a surge marker to the center
              if (grid['center'] != null) {
                double clat = double.parse(grid['center']['lat'].toString());
                double clng = double.parse(grid['center']['lng'].toString());
                _markers.add(
                  Marker(
                    markerId: MarkerId('surge_marker_$hexId'),
                    position: LatLng(clat, clng),
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueOrange,
                    ),
                    infoWindow: const InfoWindow(title: 'Alta Demanda'),
                  ),
                );
              }
            } else if (deliveryType == 'standard') {
              fillColor = Colors.blue.withValues(alpha: 0.1);
              strokeColor = Colors.blueAccent;
            }

            _polygons.add(
              Polygon(
                polygonId: PolygonId('grid_$hexId'),
                points: points,
                strokeWidth: width.toInt(),
                strokeColor: strokeColor,
                fillColor: fillColor,
              ),
            );
          }
        } catch (e) {
          debugPrint('Error processing grid: $e');
        }
      }
    }
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: null,

      body: GetBuilder<ProfileController>(
        builder: (profileController) {
          LatLng? currentLatLng;
          if (profileController.recordLocationBody != null) {
            currentLatLng = LatLng(
              profileController.recordLocationBody!.latitude!,
              profileController.recordLocationBody!.longitude!,
            );
            _mapController?.animateCamera(
              CameraUpdate.newLatLng(currentLatLng),
            );
          }

          return GetBuilder<AddressController>(
            builder: (addressController) {
              if (addressController.zoneList != null) {
                _getPolygons(
                  addressController.zoneList!,
                  addressController.gridList,
                );
              }

              return Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: currentLatLng ?? const LatLng(0, 0),
                      zoom: 16,
                    ),
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    polygons: _polygons,
                    markers: _markers,
                    onMapCreated: (controller) {
                      _mapController = controller;
                      _mapController?.setMapStyle(AppConstants.darkStyle);
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
                          onTap: () =>
                              Get.toNamed(RouteHelper.getNotificationRoute()),
                          child: Container(
                            height: 40,
                            width: 40,
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
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
                                          color: Theme.of(context).cardColor,
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
                                  profileController.profileModel?.balance ?? 0,
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
                ],
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
