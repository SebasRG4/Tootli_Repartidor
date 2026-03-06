import 'dart:async';
import 'dart:io';
import 'package:sixam_mart_delivery/features/auth/controllers/auth_controller.dart';
import 'package:sixam_mart_delivery/features/order/controllers/order_controller.dart';
import 'package:sixam_mart_delivery/features/disbursement/helper/disbursement_helper.dart';
import 'package:sixam_mart_delivery/features/profile/controllers/profile_controller.dart';
import 'package:sixam_mart_delivery/helper/notification_helper.dart';
import 'package:sixam_mart_delivery/helper/route_helper.dart';
import 'package:sixam_mart_delivery/main.dart';
import 'package:sixam_mart_delivery/util/dimensions.dart';
import 'package:sixam_mart_delivery/util/styles.dart';
import 'package:sixam_mart_delivery/features/order/widgets/slider_button_widget.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_alert_dialog_widget.dart';
import 'package:sixam_mart_delivery/features/dashboard/widgets/bottom_nav_item_widget.dart';
import 'package:sixam_mart_delivery/features/dashboard/widgets/new_request_dialog_widget.dart';
import 'package:sixam_mart_delivery/features/home/screens/home_screen.dart';
import 'package:sixam_mart_delivery/features/profile/screens/profile_screen.dart';
import 'package:sixam_mart_delivery/features/order/screens/order_request_screen.dart';
import 'package:sixam_mart_delivery/features/order/screens/order_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:sixam_mart_delivery/util/images.dart';

class DashboardScreen extends StatefulWidget {
  final int pageIndex;
  final bool fromOrderDetails;
  const DashboardScreen({
    super.key,
    required this.pageIndex,
    this.fromOrderDetails = false,
  });

  @override
  DashboardScreenState createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  PageController? _pageController;
  int _pageIndex = 0;
  late List<Widget> _screens;
  final _channel = const MethodChannel('com.sixamtech/app_retain');
  late StreamSubscription _stream;
  DisbursementHelper disbursementHelper = DisbursementHelper();
  bool _canExit = false;
  bool _isBottomBarVisible = true;

  @override
  void initState() {
    super.initState();

    _pageIndex = widget.pageIndex;
    _pageController = PageController(initialPage: widget.pageIndex);

    _screens = [
      HomeScreen(onNavigateToOrders: () => _setPage(2)),
      OrderRequestScreen(onTap: () => _setPage(0)),
      const OrderScreen(),
      const ProfileScreen(),
    ];

    showDisbursementWarningMessage();
    Get.find<OrderController>().getLatestOrders();

    _stream = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      String? type = message.data['body_loc_key'] ?? message.data['type'];
      String? orderID =
          message.data['title_loc_key'] ?? message.data['order_id'];
      bool isParcel = (message.data['order_type'] == 'parcel_order');
      if (type != 'assign' &&
          type != 'new_order' &&
          type != 'message' &&
          type != 'order_request' &&
          type != 'order_status') {
        NotificationHelper.showNotification(
          message,
          flutterLocalNotificationsPlugin,
        );
      }
      if (type == 'new_order' || type == 'order_request') {
        Get.find<OrderController>().getRunningOrders(
          Get.find<OrderController>().offset,
          status: 'all',
        );
        Get.find<OrderController>().getOrderCount(
          Get.find<OrderController>().orderType,
        );
        Get.find<OrderController>().getLatestOrders();
        Get.dialog(
          NewRequestDialogWidget(
            isRequest: true,
            onTap: () => _navigateRequestPage(),
            orderId: int.parse(message.data['order_id'].toString()),
            isParcel: isParcel,
          ),
        );
      } else if (type == 'assign' && orderID != null && orderID.isNotEmpty) {
        Get.find<OrderController>().getRunningOrders(
          Get.find<OrderController>().offset,
          status: 'all',
        );
        Get.find<OrderController>().getOrderCount(
          Get.find<OrderController>().orderType,
        );
        Get.find<OrderController>().getLatestOrders();
        Get.dialog(
          NewRequestDialogWidget(
            isRequest: false,
            orderId: int.parse(message.data['order_id'].toString()),
            isParcel: isParcel,
            onTap: () {
              Get.offAllNamed(
                RouteHelper.getOrderDetailsRoute(
                  int.parse(orderID),
                  fromNotification: true,
                ),
              );
            },
          ),
        );
      } else if (type == 'block') {
        Get.find<AuthController>().clearSharedData();
        Get.find<ProfileController>().stopLocationRecord();
        Get.offAllNamed(RouteHelper.getSignInRoute());
      }
    });
  }

  Future<void> showDisbursementWarningMessage() async {
    if (!widget.fromOrderDetails) {
      disbursementHelper.enableDisbursementWarningMessage(true);
    }
  }

  void _navigateRequestPage() {
    if (Get.find<ProfileController>().profileModel != null &&
        Get.find<ProfileController>().profileModel!.active == 1 &&
        Get.find<OrderController>().currentOrderList != null &&
        Get.find<OrderController>().currentOrderList!.isEmpty) {
      _setPage(1);
    } else {
      if (Get.find<ProfileController>().profileModel == null ||
          Get.find<ProfileController>().profileModel!.active == 0) {
        Get.dialog(
          CustomAlertDialogWidget(
            description: 'you_are_offline_now'.tr,
            onOkPressed: () => Get.back(),
          ),
        );
      } else {
        _setPage(1);
      }
    }
  }

  @override
  void dispose() {
    super.dispose();

    _stream.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (_pageIndex != 0) {
          _setPage(0);
        } else {
          if (_canExit) {
            if (GetPlatform.isAndroid) {
              if (Get.find<ProfileController>().profileModel != null &&
                  Get.find<ProfileController>().profileModel!.active == 1) {
                _channel.invokeMethod('sendToBackground');
              }
              SystemNavigator.pop();
            } else if (GetPlatform.isIOS) {
              exit(0);
            }
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'back_press_again_to_exit'.tr,
                style: const TextStyle(color: Colors.white),
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
              margin: const EdgeInsets.all(Dimensions.paddingSizeSmall),
            ),
          );
          _canExit = true;
          Timer(const Duration(seconds: 2), () {
            _canExit = false;
          });
        }
      },
      child: GetBuilder<ProfileController>(
        builder: (profileController) {
          bool isHome = _pageIndex == 0;
          bool isOffline = profileController.profileModel?.active == 0;
          bool showBottomBar = isOffline || _isBottomBarVisible;
          bool hasSlider = isHome && profileController.profileModel != null;
          double barHeight =
              (hasSlider ? 150 : 70) +
              30 +
              MediaQuery.of(context).padding.bottom;

          return Scaffold(
            body: Stack(
              children: [
                PageView.builder(
                  controller: _pageController,
                  itemCount: _screens.length,
                  physics: const NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    return _screens[index];
                  },
                ),
                if (!showBottomBar)
                  Positioned(
                    bottom: Dimensions.paddingSizeExtraSmall,
                    left: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () => setState(() => _isBottomBarVisible = true),
                      onVerticalDragUpdate: (details) {
                        if (details.delta.dy < -5) {
                          setState(() => _isBottomBarVisible = true);
                        }
                      },
                      child: Center(
                        child: Container(
                          width: 80,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).primaryColor.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(
                              Dimensions.radiusExtraLarge,
                            ),
                          ),
                          child: const Icon(
                            Icons.keyboard_arrow_up,
                            color: Colors.white,
                            size: 25,
                          ),
                        ),
                      ),
                    ),
                  ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  bottom: showBottomBar ? 0 : -barHeight,
                  left: 0,
                  right: 0,
                  child: GestureDetector(
                    onVerticalDragUpdate: (details) {
                      if (details.delta.dy > 5 && !isOffline) {
                        setState(() => _isBottomBarVisible = false);
                      }
                    },
                    child: Container(
                      height: barHeight,
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey[Get.isDarkMode ? 800 : 200]!,
                            spreadRadius: 1,
                            blurRadius: 5,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          if (hasSlider)
                            Padding(
                              padding: const EdgeInsets.only(
                                left: Dimensions.paddingSizeDefault,
                                right: Dimensions.paddingSizeDefault,
                                top: Dimensions.paddingSizeSmall,
                                bottom: Dimensions.paddingSizeDefault,
                              ),
                              child: SliderButton(
                                action: () {
                                  profileController.updateActiveStatus(
                                    back: false,
                                  );
                                },
                                label: Text(
                                  (profileController.profileModel!.active == 1
                                          ? 'desconectarse'
                                          : 'conectarse')
                                      .tr,
                                  style: robotoMedium.copyWith(
                                    color: Colors.white,
                                    fontSize: Dimensions.fontSizeLarge,
                                  ),
                                ),
                                dismissThresholds: 0.5,
                                dismissible: false,
                                shimmer: true,
                                width: context.width - 40,
                                height: 50,
                                buttonSize: 45,
                                radius: 10,
                                icon: Center(
                                  child: Icon(
                                    Icons.double_arrow_sharp,
                                    color: Colors.green,
                                    size: 25,
                                  ),
                                ),
                                buttonColor: Colors.white,
                                backgroundColor: Colors.green,
                                highlightedColor: Colors.white,
                                baseColor: Colors.white,
                              ),
                            ),
                          Row(
                            children: [
                              BottomNavItemWidget(
                                iconData: Images.home,
                                label: 'home'.tr,
                                isSelected: _pageIndex == 0,
                                onTap: () => _setPage(0),
                              ),
                              BottomNavItemWidget(
                                iconData: Images.request,
                                label: 'request'.tr,
                                isSelected: _pageIndex == 1,
                                pageIndex: 1,
                                onTap: () {
                                  _navigateRequestPage();
                                },
                              ),
                              BottomNavItemWidget(
                                iconData: Images.bag,
                                label: 'orders'.tr,
                                isSelected: _pageIndex == 2,
                                onTap: () => _setPage(2),
                              ),
                              BottomNavItemWidget(
                                iconData: Images.userP,
                                label: 'profile'.tr,
                                isSelected: _pageIndex == 3,
                                onTap: () => _setPage(3),
                              ),
                            ],
                          ),

                          if (!isOffline)
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _isBottomBarVisible = false),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 5,
                                ),
                                color: Colors.transparent,
                                child: Icon(
                                  Icons.keyboard_arrow_down,
                                  color: Theme.of(
                                    context,
                                  ).disabledColor.withOpacity(0.5),
                                  size: 25,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _setPage(int pageIndex) {
    setState(() {
      _pageController!.jumpToPage(pageIndex);
      _pageIndex = pageIndex;
    });
  }
}
