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

import 'package:sixam_mart_delivery/features/home/screens/home_screen.dart';
import 'package:sixam_mart_delivery/helper/order_notification_service.dart';
import 'package:sixam_mart_delivery/features/mission/controllers/mission_controller.dart';
import 'package:sixam_mart_delivery/features/profile/screens/profile_screen.dart';
import 'package:sixam_mart_delivery/features/order/screens/order_request_screen.dart';
import 'package:sixam_mart_delivery/features/order/screens/order_screen.dart';
import 'package:sixam_mart_delivery/features/dashboard/widgets/online_panel_widget.dart';
import 'package:sixam_mart_delivery/features/dashboard/widgets/offline_panel_widget.dart';
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
  bool _isOrderActive = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<HomeScreenState> _homeScreenKey =
      GlobalKey<HomeScreenState>();

  @override
  void initState() {
    super.initState();

    _pageIndex = widget.pageIndex;
    _pageController = PageController(initialPage: widget.pageIndex);

    showDisbursementWarningMessage();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.find<OrderController>().getLatestOrders();
      Get.find<MissionController>().getMissionList();
    });

    // Registrar el listener para taps en notificaciones de pedidos nuevos
    // (cuando el repartidor abre la app desde la notificación del lock screen)
    OrderNotificationService.instance.onOrderRequestTapped = (int orderId) {
      Get.find<OrderController>().getLatestOrders().then((_) {
        final latestOrders = Get.find<OrderController>().latestOrderList;
        if (latestOrders != null && latestOrders.isNotEmpty) {
          final orderModel = latestOrders.firstWhere(
            (o) => o.id == orderId,
            orElse: () => latestOrders.first,
          );
          // Navegar al Home si el usuario está en otra tab
          if (_pageIndex != 0) {
            _setPage(0);
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _homeScreenKey.currentState?.showOrderRequest(orderModel);
          });
        }
      });
    };

    _stream = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      String? type = message.data['body_loc_key'] ?? message.data['type'];
      String? orderID =
          message.data['title_loc_key'] ?? message.data['order_id'];


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
        // Refrescar la lista de pedidos pendientes y luego mostrar el bottom sheet moderno
        Get.find<OrderController>().getLatestOrders().then((_) {
          final orderId = int.tryParse(message.data['order_id'].toString());
          final latestOrders = Get.find<OrderController>().latestOrderList;
          if (orderId != null && latestOrders != null && latestOrders.isNotEmpty) {
            // Buscar el pedido específico por ID, o usar el primero de la lista
            final orderModel = latestOrders.firstWhere(
              (o) => o.id == orderId,
              orElse: () => latestOrders.first,
            );
            // Navegar al Home si el usuario está en otra tab
            if (_pageIndex != 0) {
              _setPage(0);
            }
            // Disparar el bottom sheet moderno directamente en HomeScreen
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _homeScreenKey.currentState?.showOrderRequest(orderModel);
            });
          }
        });
      } else if (type == 'assign' && orderID != null && orderID.isNotEmpty) {
        Get.find<OrderController>().getRunningOrders(
          Get.find<OrderController>().offset,
          status: 'all',
        );
        Get.find<OrderController>().getOrderCount(
          Get.find<OrderController>().orderType,
        );
        Get.find<OrderController>().getLatestOrders();
        // Para pedidos tipo 'assign' (asignados directamente), navegar a los detalles sin diálogo
        Get.offAllNamed(
          RouteHelper.getOrderDetailsRoute(
            int.parse(orderID),
            fromNotification: true,
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
          _screens = [
            HomeScreen(
              key: _homeScreenKey,
              onNavigateToOrders: () => _setPage(2),
              onTapMenu: () => _scaffoldKey.currentState?.openDrawer(),
              onOrderActiveStatusChanged: (isActive) {
                if (_isOrderActive != isActive) {
                  setState(() {
                    _isOrderActive = isActive;
                  });
                }
              },
            ),
            OrderRequestScreen(
              onTap: () => _setPage(0),
              onTapMenu: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            OrderScreen(
              onTapMenu: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            ProfileScreen(
              onTapMenu: () => _scaffoldKey.currentState?.openDrawer(),
            ),
          ];

          bool isHome = _pageIndex == 0;
          bool isOffline = profileController.profileModel?.active == 0;
          bool showBottomBar = isOffline || _isBottomBarVisible;
          bool hasSlider = isHome && profileController.profileModel != null;

          return Scaffold(
            key: _scaffoldKey,
            drawer: _buildDrawer(profileController),
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
                if (!showBottomBar && hasSlider)
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

                // Floating Buttons (Location and Bug) — se ocultan cuando hay pedido activo
                if (hasSlider && !_isOrderActive)
                  Positioned(
                    bottom:
                        MediaQuery.of(context).size.height *
                        (isOffline ? 0.36 : 0.26),
                    right: Dimensions.paddingSizeDefault,
                    child: Column(
                      children: [
                        // Bug/Orders Button
                        FloatingActionButton.small(
                          heroTag: 'bug_button',
                          onPressed: () {
                            _homeScreenKey.currentState?.simulateOrderRequest();
                          },
                          backgroundColor: Theme.of(context).primaryColor,
                          child: const Icon(
                            Icons.bug_report,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: Dimensions.paddingSizeSmall),

                        // Location Button
                        FloatingActionButton.small(
                          heroTag: 'location_button',
                          onPressed: () => _homeScreenKey.currentState
                              ?.animateToMyLocation(),
                          backgroundColor: Theme.of(context).cardColor,
                          child: Icon(
                            Icons.my_location,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (hasSlider && !_isOrderActive)
                  DraggableScrollableSheet(
                    initialChildSize: isOffline ? 0.35 : 0.25,
                    minChildSize: isOffline ? 0.35 : 0.25,
                    maxChildSize: 0.85,
                    snap: true,
                    builder: (context, scrollController) {
                      return isOffline
                          ? OfflinePanelWidget(
                              scrollController: scrollController,
                              onConnect: () {
                                profileController.updateActiveStatus(
                                  back: false,
                                );
                                Get.find<MissionController>().getMissionList();
                              },
                            )
                          : OnlinePanelWidget(
                              scrollController: scrollController,
                              onDisconnect: () {
                                profileController.updateActiveStatus(
                                  back: false,
                                );
                              },
                            );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDrawer(ProfileController profileController) {
    return Drawer(
      backgroundColor: Theme.of(context).cardColor,
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: Theme.of(context).primaryColor),
            accountName: Text(
              profileController.profileModel?.fName ?? '',
              style: robotoBold.copyWith(
                fontSize: Dimensions.fontSizeLarge,
                color: Colors.white,
              ),
            ),
            accountEmail: Text(
              profileController.profileModel?.email ?? '',
              style: robotoRegular.copyWith(color: Colors.white),
            ),
            currentAccountPicture: ClipOval(
              child: profileController.profileModel?.imageFullUrl != null
                  ? Image.network(
                      profileController.profileModel!.imageFullUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Image.asset(Images.placeholder),
                    )
                  : Image.asset(Images.placeholder),
            ),
          ),

          // Performance Metrics Section
          Container(
            margin: const EdgeInsets.symmetric(
              horizontal: Dimensions.paddingSizeDefault,
            ),
            padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
              border: Border.all(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Métricas de Desempeño',
                  style: robotoBold.copyWith(
                    fontSize: Dimensions.fontSizeSmall,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: Dimensions.paddingSizeSmall),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMetricItem(
                      'Rating',
                      '${profileController.profileModel?.avgRating ?? 0}',
                      Icons.star,
                      Colors.orange,
                    ),
                    _buildMetricItem(
                      'Hoy',
                      '${profileController.profileModel?.todaysOrderCount ?? 0}',
                      Icons.today,
                      Colors.blue,
                    ),
                    _buildMetricItem(
                      'Semana',
                      '${profileController.profileModel?.thisWeekOrderCount ?? 0}',
                      Icons.calendar_view_week,
                      Colors.green,
                    ),
                  ],
                ),
              ],
            ),
          ),
          ListTile(
            leading: Icon(
              Icons.home,
              color: _pageIndex == 0 ? Theme.of(context).primaryColor : null,
            ),
            title: Text(
              'home'.tr,
              style: robotoMedium.copyWith(
                color: _pageIndex == 0 ? Theme.of(context).primaryColor : null,
              ),
            ),
            selected: _pageIndex == 0,
            onTap: () {
              Get.back();
              _setPage(0);
            },
          ),
          ListTile(
            leading: Icon(
              Icons.list_alt,
              color: _pageIndex == 1 ? Theme.of(context).primaryColor : null,
            ),
            title: Text(
              'request'.tr,
              style: robotoMedium.copyWith(
                color: _pageIndex == 1 ? Theme.of(context).primaryColor : null,
              ),
            ),
            selected: _pageIndex == 1,
            onTap: () {
              Get.back();
              _setPage(1);
            },
          ),
          ListTile(
            leading: Icon(
              Icons.shopping_bag,
              color: _pageIndex == 2 ? Theme.of(context).primaryColor : null,
            ),
            title: Text(
              'orders'.tr,
              style: robotoMedium.copyWith(
                color: _pageIndex == 2 ? Theme.of(context).primaryColor : null,
              ),
            ),
            selected: _pageIndex == 2,
            onTap: () {
              Get.back();
              _setPage(2);
            },
          ),
          ListTile(
            leading: Icon(
              Icons.person,
              color: _pageIndex == 3 ? Theme.of(context).primaryColor : null,
            ),
            title: Text(
              'profile'.tr,
              style: robotoMedium.copyWith(
                color: _pageIndex == 3 ? Theme.of(context).primaryColor : null,
              ),
            ),
            selected: _pageIndex == 3,
            onTap: () {
              Get.back();
              _setPage(3);
            },
          ),
          ListTile(
            leading: Icon(
              Icons.military_tech,
              color: Get.currentRoute == RouteHelper.mission
                  ? Theme.of(context).primaryColor
                  : null,
            ),
            title: Text(
              'driver_missions'.tr,
              style: robotoMedium.copyWith(
                color: Get.currentRoute == RouteHelper.mission
                    ? Theme.of(context).primaryColor
                    : null,
              ),
            ),
            onTap: () {
              Get.back();
              Get.toNamed(RouteHelper.getMissionRoute());
            },
          ),
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: Text(
              'logout'.tr,
              style: robotoMedium.copyWith(color: Colors.red),
            ),
            onTap: () {
              Get.back();
              Get.find<AuthController>().clearSharedData();
              Get.find<ProfileController>().stopLocationRecord();
              Get.offAllNamed(RouteHelper.getSignInRoute());
            },
          ),
          SizedBox(
            height:
                MediaQuery.of(context).padding.bottom +
                Dimensions.paddingSizeDefault,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: robotoBold.copyWith(fontSize: Dimensions.fontSizeLarge),
        ),
        Text(
          label,
          style: robotoRegular.copyWith(
            fontSize: 10,
            color: Theme.of(context).disabledColor,
          ),
        ),
      ],
    );
  }

  void _setPage(int pageIndex) {
    setState(() {
      _pageController!.jumpToPage(pageIndex);
      _pageIndex = pageIndex;
    });
  }
}
