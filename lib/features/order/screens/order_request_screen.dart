import 'dart:async';
import 'package:sixam_mart_delivery/features/order/controllers/order_controller.dart';
import 'package:sixam_mart_delivery/features/order/domain/models/order_model.dart';
import 'package:sixam_mart_delivery/features/profile/controllers/profile_controller.dart';
import 'package:sixam_mart_delivery/util/dimensions.dart';
import 'package:sixam_mart_delivery/util/images.dart';
import 'package:sixam_mart_delivery/util/styles.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_app_bar_widget.dart';
import 'package:sixam_mart_delivery/common/widgets/title_widget.dart';
import 'package:sixam_mart_delivery/features/order/widgets/order_requset_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

class OrderRequestScreen extends StatefulWidget {
  final Function onTap;
  final Function()? onTapMenu;
  const OrderRequestScreen({super.key, required this.onTap, this.onTapMenu});

  @override
  OrderRequestScreenState createState() => OrderRequestScreenState();
}

class OrderRequestScreenState extends State<OrderRequestScreen> {
  Timer? _timer;
  bool _isNotificationPermissionGranted = true;
  bool _isBatteryOptimizationGranted = true;
  bool _isOverlayPermissionGranted = true;

  @override
  initState() {
    super.initState();

    if (Get.find<ProfileController>().profileModel == null) {
      Get.find<ProfileController>().getProfile();
    }

    Get.find<OrderController>().getLatestOrders(filterIgnored: false);
    Get.find<OrderController>().getRunningOrders(1);
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      Get.find<OrderController>().getLatestOrders(filterIgnored: false);
      Get.find<OrderController>().getRunningOrders(1);
    });

    _checkPermission();
  }

  Future<void> _checkPermission() async {
    debugPrint("[OrderRequestScreen] Checking permissions...");
    var notificationStatus = await Permission.notification.status;
    var batteryStatus = await Permission.ignoreBatteryOptimizations.status;
    var overlayStatus = await Permission.systemAlertWindow.status;
    debugPrint(
      "[OrderRequestScreen] Notif: $notificationStatus, Battery: $batteryStatus, Overlay: $overlayStatus",
    );
    if (mounted) {
      setState(() {
        _isNotificationPermissionGranted =
            !notificationStatus.isDenied &&
            !notificationStatus.isPermanentlyDenied;
        _isBatteryOptimizationGranted = !batteryStatus.isDenied;
        _isOverlayPermissionGranted = overlayStatus.isGranted;
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
    _timer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBarWidget(
        title: 'centro_de_pedidos'.tr, // Antes 'tootli_requests'.tr
        isBackButtonExist: false,
        onMenuPressed: widget.onTapMenu,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Get.find<OrderController>().getLatestOrders(filterIgnored: false);
          await Get.find<ProfileController>().getProfile();
          await Get.find<OrderController>().getRunningOrders(1);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  if (!_isNotificationPermissionGranted)
                    _permissionWarning(
                      isBatteryPermission: false,
                      onTap: () async {
                        await Permission.notification.request();
                        _checkPermission();
                      },
                      closeOnTap: () {
                        setState(() => _isNotificationPermissionGranted = true);
                      },
                    ),

                  if (!_isBatteryOptimizationGranted)
                    _permissionWarning(
                      isBatteryPermission: true,
                      onTap: () async {
                        await Permission.ignoreBatteryOptimizations.request();
                        _checkPermission();
                      },
                      closeOnTap: () {
                        setState(() => _isBatteryOptimizationGranted = true);
                      },
                    ),

                  if (!_isOverlayPermissionGranted && GetPlatform.isAndroid)
                    _permissionWarning(
                      isOverlayPermission: true,
                      onTap: () async {
                        await Permission.systemAlertWindow.request();
                        _checkPermission();
                      },
                      closeOnTap: () {
                        setState(() => _isOverlayPermissionGranted = true);
                      },
                    ),
                ],
              ),
            ),

            GetBuilder<ProfileController>(builder: (profileController) {
              final profile = profileController.profileModel;
              if (profile != null) {
                debugPrint("[OrderRequestScreen] 👤 Profile info: Active=${profile.active}, Zone=${profile.zoneId}, Status=${profile.applicationStatus}");
              } else {
                debugPrint("[OrderRequestScreen] 👤 Profile is NULL");
              }
              return const SliverToBoxAdapter(child: SizedBox());
            }),

            GetBuilder<OrderController>(
              builder: (orderController) {
                int latestCount = orderController.latestOrderList?.length ?? 0;
                int runningCount =
                    orderController.currentOrderList?.length ?? 0;
                debugPrint(
                  "[OrderRequestScreen] 🏗️ Building list. Latest: $latestCount, Running: $runningCount",
                );

                List<OrderModel> allOrders = [];
                if (orderController.latestOrderList != null) {
                  allOrders.addAll(orderController.latestOrderList!);
                }
                if (orderController.currentOrderList != null) {
                  // Solo agregar órdenes que estén en estado pendiente o confirmado
                  // para que parezcan "solicitudes" en este centro.
                  for (var order in orderController.currentOrderList!) {
                    if (order.orderStatus == 'pending' ||
                        order.orderStatus == 'confirmed') {
                      if (!allOrders.any((element) => element.id == order.id)) {
                        allOrders.add(order);
                      }
                    }
                  }
                }

                return orderController.latestOrderList != null &&
                        orderController.currentOrderList != null
                    ? allOrders.isNotEmpty
                          ? SliverPadding(
                              padding: const EdgeInsets.all(
                                Dimensions.paddingSizeSmall,
                              ),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate((
                                  context,
                                  index,
                                ) {
                                  return OrderRequestWidget(
                                    orderModel: allOrders[index],
                                    index: index,
                                    onTap: widget.onTap,
                                  );
                                }, childCount: allOrders.length),
                              ),
                            )
                          : SliverFillRemaining(
                              child: Center(
                                child: Text('no_order_request_available'.tr),
                              ),
                            )
                    : const SliverFillRemaining(
                        child: Center(child: CircularProgressIndicator()),
                      );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _permissionWarning({
    bool isBatteryPermission = false,
    bool isOverlayPermission = false,
    required Function() onTap,
    required Function() closeOnTap,
  }) {
    String text = '';
    if (isBatteryPermission) {
      text =
          'for_better_performance_allow_notification_to_run_in_background'.tr;
    } else if (isOverlayPermission) {
      text =
          'Para ver pedidos sobre otras apps, activa el permiso de superposición'
              .tr;
    } else {
      text = 'notification_is_disabled_please_allow_notification'.tr;
    }

    return GetPlatform.isAndroid
        ? Container(
            width: double.infinity,
            color: Theme.of(
              context,
            ).textTheme.bodyLarge!.color?.withValues(alpha: 0.7),
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
                child: Row(
                  children: [
                    if (isBatteryPermission || isOverlayPermission)
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Image.asset(
                          Images.allertIcon,
                          height: 20,
                          width: 20,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        text,
                        style: robotoRegular.copyWith(
                          fontSize: Dimensions.fontSizeSmall,
                          color: Colors.white,
                        ),
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
