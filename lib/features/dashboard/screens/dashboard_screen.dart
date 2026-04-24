import 'dart:async';
import 'dart:io';
import 'package:sixam_mart_delivery/features/order/controllers/order_controller.dart';
import 'package:sixam_mart_delivery/features/order/domain/models/order_model.dart';
import 'package:sixam_mart_delivery/features/disbursement/helper/disbursement_helper.dart';
import 'package:sixam_mart_delivery/features/profile/controllers/profile_controller.dart';
import 'package:sixam_mart_delivery/helper/notification_helper.dart';
import 'package:sixam_mart_delivery/util/dimensions.dart';

import 'package:sixam_mart_delivery/features/home/screens/home_screen.dart';
import 'package:sixam_mart_delivery/helper/order_notification_service.dart';
import 'package:sixam_mart_delivery/helper/pusher_service.dart';
import 'package:sixam_mart_delivery/features/mission/controllers/mission_controller.dart';
import 'package:sixam_mart_delivery/features/profile/screens/profile_screen.dart';
import 'package:sixam_mart_delivery/features/order/screens/order_request_screen.dart';
import 'package:sixam_mart_delivery/features/order/screens/order_screen.dart';
import 'package:sixam_mart_delivery/features/dashboard/widgets/dashboard_drawer_widget.dart';
import 'package:sixam_mart_delivery/features/dashboard/widgets/online_panel_widget.dart';
import 'package:sixam_mart_delivery/features/dashboard/widgets/offline_panel_widget.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

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

class DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  PageController? _pageController;
  int _pageIndex = 0;
  late List<Widget> _screens;
  final _channel = const MethodChannel('com.sixamtech/app_retain');
  StreamSubscription<RemoteMessage>? _stream;
  Timer? _latestOrdersPoller;
  DisbursementHelper disbursementHelper = DisbursementHelper();
  bool _canExit = false;
  bool _isBottomBarVisible = true;
  bool _isOrderActive = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<HomeScreenState> _homeScreenKey =
      GlobalKey<HomeScreenState>();
  /// IDs de pedidos ya enviados al HomeScreen para evitar duplicados
  final Set<int> _shownOrderIds = {};

  @override
  void initState() {
    super.initState();

    _pageIndex = widget.pageIndex;
    _pageController = PageController(initialPage: widget.pageIndex);
    WidgetsBinding.instance.addObserver(this);
    NotificationHelper.setAppInForeground(true);

    showDisbursementWarningMessage();
    _startLatestOrdersPolling();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.find<OrderController>().getLatestOrders().then((_) {
        if (!mounted) return;
        final latestOrders = Get.find<OrderController>().latestOrderList;
        if (latestOrders != null && latestOrders.isNotEmpty) {
          // Usar _dispatchOrderToHome en vez de showOrderRequest directo.
          // Esto asegura que pase por la deduplicación de _shownOrderIds:
          // si el FCM ya mostró este pedido, el initState no lo mostrará de nuevo.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _dispatchOrderToHome(latestOrders.first);
          });
        } else {
          Get.find<OrderController>().getRunningOrders(1).then((_) {
            if (!mounted) return;
            final runningOrders = Get.find<OrderController>().currentOrderList;
            if (runningOrders != null && runningOrders.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _homeScreenKey.currentState?.restoreActiveOrder(runningOrders.first);
              });
            }
          });
        }
      });
    });
    Get.find<MissionController>().getMissionList();

    // Registrar el listener para que el Dashboard reaccione a notificaciones
    // centralizadas en NotificationHelper vía OrderNotificationService.
    OrderNotificationService.instance.onOrderRequestTapped = (int orderId) {
      print("[Dashboard] \n┌────────────────────────────────────────┐");
      print("[Dashboard] │  📩 CALLBACK FIRED for order $orderId   │");
      print("[Dashboard] └────────────────────────────────────────┘");
      print("[Dashboard] mounted=$mounted, _pageIndex=$_pageIndex");
      if (!mounted) return;
      if (_pageIndex != 0) _setPage(0);
      _triggerShowOrder(orderId);
    };

    // 🚀 Start Real-Time WebSocket Connection
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final profileModel = Get.find<ProfileController>().profileModel;
      if (profileModel != null && profileModel.id != null) {
        PusherService.instance.initPusher(profileModel.id!);
      }
    });
  }

  /// Polling defensivo para no depender 100% de FCM.
  /// Si el push no llega (app reiniciándose, red, OEM, etc.), la app aún mostrará
  /// el bottom sheet al detectar pedidos en `latest-orders`.
  void _startLatestOrdersPolling() {
    _latestOrdersPoller?.cancel();
    _latestOrdersPoller = Timer.periodic(const Duration(seconds: 15), (_) async {
      if (!mounted) return;
      // Solo cuando el usuario está en Home y no hay pedido activo
      if (_pageIndex != 0 || _isOrderActive) return;

      await Get.find<OrderController>().getLatestOrders();
      if (!mounted) return;
      final latestOrders = Get.find<OrderController>().latestOrderList;
      if (latestOrders != null && latestOrders.isNotEmpty) {
        _dispatchOrderToHome(latestOrders.first);
      }
    });
  }

  /// Busca el [OrderModel] y lo muestra en HomeScreen con la menor latencia posible.
  /// Implementa una estrategia de "Respuesta Instantánea" abriendo el UI inmediatamente.
  void _triggerShowOrder(int orderId) {
    print("[Dashboard] _triggerShowOrder($orderId) called");
    print("[Dashboard] _shownOrderIds = $_shownOrderIds");
    // ── Paso 0: Deduplicación INMEDIATA (antes de cualquier async) ──────────
    if (_shownOrderIds.contains(orderId)) {
      print("[Dashboard] ⛔ orderId=$orderId BLOCKED by _shownOrderIds dedup");
      return;
    }
    _shownOrderIds.add(orderId);
    print("[Dashboard] ✅ orderId=$orderId passed dedup check");

    // ── Paso 1: Respuesta Instantánea (Shell Loading) ──────────────────────
    debugPrint("[FCM] orderId=$orderId disparando UI instantánea...");
    
    // Buscar en caché primero para evitar el shell si ya los tenemos
    final cachedOrder = Get.find<OrderController>()
        .latestOrderList
        ?.firstWhereOrNull((o) => o.id == orderId);

    if (cachedOrder != null) {
      debugPrint("[FCM] orderId=$orderId encontrado en caché.");
      _dispatchOrderToHome(cachedOrder);
      _refreshCounters();
    } else {
      // Mostrar shell inmediato con un modelo parcial (solo ID)
      // HomeScreen y PremiumOrderRequestWidget manejarán el estado de carga
      final dummyOrder = OrderModel(id: orderId);
      _dispatchOrderToHome(dummyOrder);

      // ── Paso 2: Fetch de datos reales en segundo plano ────────────────────
      debugPrint("[FCM] orderId=$orderId consultando latest-orders en segundo plano...");
      Get.find<OrderController>().getLatestOrders().then((_) {
        if (!mounted) return;
        final order = Get.find<OrderController>()
            .latestOrderList
            ?.firstWhereOrNull((o) => o.id == orderId);

        if (order != null) {
          debugPrint("[FCM] orderId=$orderId datos obtenidos de latest-orders. Actualizando UI...");
          _dispatchOrderToHome(order);
          _refreshCounters();
        } else {
          // Fallback a fetch directo si no está en latest-orders (asignado)
          Get.find<OrderController>().fetchOrderForNotification(orderId).then((fetched) {
            if (!mounted) return;
            if (fetched != null) {
              debugPrint("[FCM] orderId=$orderId datos obtenidos por fetch directo. Actualizando UI...");
              _dispatchOrderToHome(fetched);
            }
            _refreshCounters();
          });
        }
      });
    }
  }


  /// Refresca contadores y lista de corridas en paralelo, sin bloquear el bottom sheet.
  void _refreshCounters() {
    Get.find<OrderController>().getRunningOrders(
      Get.find<OrderController>().offset,
      status: 'all',
    );
    Get.find<OrderController>().getOrderCount(
      Get.find<OrderController>().orderType,
    );
  }




  /// Envía el [order] al HomeScreen asegurando que el key y el state existen.
  /// Implementa deduplicación estricta por ID y manejo de race conditions.
  void _dispatchOrderToHome(OrderModel order) {
    if (!mounted) return;
    
    final id = order.id;
    if (id == null) return;

    final homeState = _homeScreenKey.currentState;
    
    print("[Dashboard] _dispatchOrderToHome($id) - homeState is ${homeState != null ? 'NOT null' : 'NULL'}");
    
    if (homeState == null) {
      print("[Dashboard] ⚠️ HomeScreenState is null, retrying next frame for order $id");
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _dispatchOrderToHome(order);
      });
      return;
    }
    
    print("[Dashboard] ✅ DISPATCHING order $id to HomeScreen.showOrderRequest()");
    homeState.showOrderRequest(order);
  }


  Future<void> showDisbursementWarningMessage() async {
    if (!widget.fromOrderDetails) {
      disbursementHelper.enableDisbursementWarningMessage(true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    NotificationHelper.setAppInForeground(false);
    _stream?.cancel();
    _latestOrdersPoller?.cancel();
    PusherService.instance.disconnect();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      NotificationHelper.setAppInForeground(true);
      
      // Reconectar inmediatamente el WebSocket de Soketi si se durmió por iOS/Android
      PusherService.instance.disconnect();
      final profileModel = Get.find<ProfileController>().profileModel;
      if (profileModel != null && profileModel.id != null) {
        PusherService.instance.initPusher(profileModel.id!);
      }

      // 🛡️ Mecanismo de seguridad (Fallback): Si onMessageOpenedApp de FCM falla al 
      // tocar el banner (común en iOS), rescatamos los pedidos asignados consultando la red.
      Get.find<OrderController>().getLatestOrders().then((_) {
        if (!mounted || _pageIndex != 0 || _isOrderActive) return;
        final latestOrders = Get.find<OrderController>().latestOrderList;
        if (latestOrders != null && latestOrders.isNotEmpty) {
          _dispatchOrderToHome(latestOrders.first);
        }
      });

    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      NotificationHelper.setAppInForeground(false);
    }
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
            drawer: DashboardDrawerWidget(
              profileController: profileController,
              pageIndex: _pageIndex,
              onSelectPage: (int index) {
                Get.back();
                _setPage(index);
              },
            ),
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

  void _setPage(int pageIndex) {
    setState(() {
      _pageController!.jumpToPage(pageIndex);
      _pageIndex = pageIndex;
    });
  }
}
