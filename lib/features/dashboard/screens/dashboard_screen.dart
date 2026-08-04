import 'dart:async';
import 'dart:io';
import 'package:sixam_mart_delivery/common/widgets/custom_snackbar_widget.dart';
import 'package:sixam_mart_delivery/features/auth/controllers/auth_controller.dart';
import 'package:sixam_mart_delivery/features/order/controllers/order_controller.dart';
import 'package:sixam_mart_delivery/features/order/domain/models/order_model.dart';
import 'package:sixam_mart_delivery/features/disbursement/helper/disbursement_helper.dart';
import 'package:sixam_mart_delivery/features/profile/controllers/profile_controller.dart';
import 'package:sixam_mart_delivery/helper/notification_helper.dart';
import 'package:sixam_mart_delivery/util/dimensions.dart';
import 'package:sixam_mart_delivery/util/styles.dart';

import 'package:sixam_mart_delivery/features/home/screens/home_screen.dart';
import 'package:sixam_mart_delivery/features/my_account/screens/my_earning_screen.dart';
import 'package:sixam_mart_delivery/helper/order_notification_service.dart';
import 'package:sixam_mart_delivery/helper/pusher_service.dart';
import 'package:sixam_mart_delivery/features/mission/controllers/mission_controller.dart';
import 'package:sixam_mart_delivery/features/profile/screens/profile_screen.dart';
import 'package:sixam_mart_delivery/features/order/screens/order_request_screen.dart';
import 'package:sixam_mart_delivery/features/order/screens/order_screen.dart';
import 'package:sixam_mart_delivery/features/dashboard/widgets/dashboard_drawer_widget.dart';
import 'package:sixam_mart_delivery/features/dashboard/widgets/pending_registration_panel_widget.dart';
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

class DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
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

  /// transactionReferences de grupos multitienda ya mostrados (bloquea hermanos individuales)
  final Set<String> _shownTransactionRefs = {};

  /// Mapa transactionRef → orderIds del grupo (para limpiar _shownOrderIds en reoferta)
  final Map<String, Set<int>> _transactionRefOrderIds = {};

  bool? _lastPendingRegistration;
  bool _handledRegistrationApprovalTransition = false;

  @override
  void initState() {
    super.initState();

    _pageIndex = widget.pageIndex;
    _pageController = PageController(initialPage: widget.pageIndex);
    WidgetsBinding.instance.addObserver(this);
    NotificationHelper.setAppInForeground(true);

    showDisbursementWarningMessage();
    final bool canFetchData =
        Get.find<AuthController>().isLoggedIn() &&
        !Get.find<ProfileController>().isPendingRegistrationDashboard;

    if (canFetchData) {
      _startLatestOrdersPolling();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!canFetchData) return;
      Get.find<OrderController>().getLatestOrders().then((_) {
        if (!mounted) return;
        final latestOrders = Get.find<OrderController>().latestOrderList;
        if (latestOrders != null &&
            latestOrders.isNotEmpty &&
            _pageIndex == 0) {
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
                _homeScreenKey.currentState?.restoreActiveOrder(
                  runningOrders.first,
                );
              });
            }
          });
        }
      });
    });
    if (!Get.find<ProfileController>().isPendingRegistrationDashboard) {
      Get.find<MissionController>().getMissionList();
    }

    // Registrar el listener para que el Dashboard reaccione a notificaciones
    // centralizadas en NotificationHelper vía OrderNotificationService.
    OrderNotificationService.instance.onOrderRequestTapped = (int orderId) {
      if (Get.find<ProfileController>().isPendingRegistrationDashboard) return;
      debugPrint(
        "[Dashboard] 📩 CALLBACK FIRED for order $orderId. Current page: $_pageIndex",
      );
      if (!mounted) return;

      // Si ya está en la pantalla de Centro de Pedidos, solo refrescamos la lista.
      if (_pageIndex == 1) {
        debugPrint(
          "[Dashboard] Already in OrderRequestScreen, just refreshing latest orders...",
        );
        Get.find<OrderController>().getLatestOrders(filterIgnored: false);
      } else {
        // Si está en otra pantalla, lo llevamos a Home (página 0) para mostrar el Bottom Sheet
        // o a OrderRequestScreen (página 1) si así lo prefiriera el usuario.
        // Por ahora mantenemos el flujo de Home para el Bottom Sheet Premium.
        _setPage(0);
        _triggerShowOrder(orderId);
      }
    };

    OrderNotificationService.instance.onInactivityAlert = (int orderId) {
      if (Get.find<ProfileController>().isPendingRegistrationDashboard) return;
      debugPrint("[Dashboard] 📩 INACTIVITY CALLBACK for order $orderId");
      if (!mounted) return;
      _setPage(0);
      _homeScreenKey.currentState?.showInactivityWarningFromNotification(
        orderId,
      );
    };

    OrderNotificationService.instance.onOrderUnassigned = (int orderId) {
      if (Get.find<ProfileController>().isPendingRegistrationDashboard) return;
      debugPrint("[Dashboard] 📩 UNASSIGNED CALLBACK for order $orderId");
      if (!mounted) return;
      _setPage(0);
      _homeScreenKey.currentState?.showUnassignedDialogFromNotification(
        orderId,
      );
    };

    // Escuchar cambios en OrderController para auto-restaurar pedidos activos si aparecen (ej. por FCM)
    Get.find<OrderController>().addListener(() {
      if (!mounted || _pageIndex != 0) return;

      final runningOrders = Get.find<OrderController>().currentOrderList;
      if (runningOrders != null && runningOrders.isNotEmpty) {
        // Restaurar el primer pedido si HomeScreen no tiene nada
        _homeScreenKey.currentState?.restoreActiveOrder(runningOrders.first);

        // Si hay un segundo pedido en la lista, también intentar restaurarlo
        if (runningOrders.length > 1) {
          _homeScreenKey.currentState?.restoreActiveOrder(runningOrders[1]);
        }
      }
    });

    // 🚀 Start Real-Time WebSocket Connection
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (Get.find<ProfileController>().isPendingRegistrationDashboard) return;
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
    _latestOrdersPoller = Timer.periodic(const Duration(seconds: 15), (
      _,
    ) async {
      if (!mounted) return;
      if (Get.find<ProfileController>().isPendingRegistrationDashboard) return;
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
    debugPrint("[Dashboard] _triggerShowOrder($orderId)");
    // ── Paso 0: Deduplicación por ID ──────────────────────────────────────
    if (_shownOrderIds.contains(orderId)) {
      debugPrint("[Dashboard] ⛔ orderId=$orderId BLOCKED by dedup (ID)");
      return;
    }

    // ── Paso 0b: Deduplicación por transactionReference (multitienda) ──────
    // Si la caché ya tiene este pedido y pertenece a un grupo ya mostrado, omitir.
    final cachedForRef = Get.find<OrderController>().latestOrderList
        ?.firstWhereOrNull((o) => o.id == orderId);
    if (cachedForRef != null &&
        cachedForRef.transactionReference != null &&
        cachedForRef.transactionReference!.isNotEmpty &&
        _shownTransactionRefs.contains(cachedForRef.transactionReference)) {
      debugPrint(
        "[Dashboard] ⛔ orderId=$orderId BLOCKED by dedup (transactionRef=${cachedForRef.transactionReference})",
      );
      _shownOrderIds.add(orderId); // registrar para no revisitar
      // Asociar este orderId al grupo para limpiarlo en reoferta
      _transactionRefOrderIds
          .putIfAbsent(cachedForRef.transactionReference!, () => {})
          .add(orderId);
      return;
    }

    _shownOrderIds.add(orderId);
    debugPrint("[Dashboard] ✅ orderId=$orderId passed dedup check");

    // ── Paso 1: Respuesta Instantánea (Shell Loading) ──────────────────────
    debugPrint("[FCM] orderId=$orderId disparando UI instantánea...");

    // Buscar en caché primero para evitar el shell si ya los tenemos
    final cachedOrder = Get.find<OrderController>().latestOrderList
        ?.firstWhereOrNull((o) => o.id == orderId);

    if (cachedOrder != null) {
      debugPrint("[FCM] orderId=$orderId encontrado en caché.");
      _registerTransactionRef(cachedOrder);
      _dispatchOrderToHome(cachedOrder);
      _refreshCounters();
    } else {
      // Mostrar shell inmediato con un modelo parcial (solo ID)
      // HomeScreen y PremiumOrderRequestWidget manejarán el estado de carga
      final dummyOrder = OrderModel(id: orderId);
      _dispatchOrderToHome(dummyOrder);

      // ── Paso 2: Fetch de datos reales en segundo plano ────────────────────
      debugPrint(
        "[FCM] orderId=$orderId consultando latest-orders en segundo plano...",
      );
      Get.find<OrderController>().getLatestOrders().then((_) {
        if (!mounted) return;
        final order = Get.find<OrderController>().latestOrderList
            ?.firstWhereOrNull((o) => o.id == orderId);

        if (order != null) {
          // ── Paso 2b: Comprobar dedup por transactionRef DESPUÉS del fetch ──
          if (order.transactionReference != null &&
              order.transactionReference!.isNotEmpty &&
              _shownTransactionRefs.contains(order.transactionReference)) {
            debugPrint(
              "[Dashboard] ⛔ orderId=$orderId BLOCKED post-fetch (transactionRef=${order.transactionReference} ya mostrado)",
            );
            _refreshCounters();
            return;
          }
          _registerTransactionRef(order);
          debugPrint(
            "[FCM] orderId=$orderId datos obtenidos de latest-orders. Actualizando UI...",
          );
          _dispatchOrderToHome(order);
          _refreshCounters();
        } else {
          // Fallback a fetch directo si no está en latest-orders (asignado)
          Get.find<OrderController>().fetchOrderForNotification(orderId).then((
            fetched,
          ) {
            if (!mounted) return;
            if (fetched != null) {
              if (fetched.transactionReference != null &&
                  fetched.transactionReference!.isNotEmpty &&
                  _shownTransactionRefs.contains(
                    fetched.transactionReference,
                  )) {
                debugPrint(
                  "[Dashboard] ⛔ orderId=$orderId BLOCKED fallback (transactionRef=${fetched.transactionReference} ya mostrado)",
                );
                _refreshCounters();
                return;
              }
              _registerTransactionRef(fetched);
              debugPrint(
                "[FCM] orderId=$orderId datos obtenidos por fetch directo. Actualizando UI...",
              );
              _dispatchOrderToHome(fetched);
            }
            _refreshCounters();
          });
        }
      });
    }
  }

  /// Registra el transactionReference del pedido para bloquear hermanos multitienda.
  void _registerTransactionRef(OrderModel order) {
    if (order.transactionReference != null &&
        order.transactionReference!.isNotEmpty) {
      final ref = order.transactionReference!;
      _shownTransactionRefs.add(ref);
      if (order.id != null) {
        _transactionRefOrderIds.putIfAbsent(ref, () => {}).add(order.id!);
      }
      debugPrint(
        "[Dashboard] 🔗 Registrado transactionRef=$ref (orderId=${order.id})",
      );
    }
  }

  /// Libera el bloqueo de un grupo multitienda (cuando el pedido es rechazado/ignorado).
  /// Limpia: transactionRef, todos los orderIds del grupo en _shownOrderIds,
  /// y los processedOrderIds de OrderNotificationService para que la siguiente reoferta
  /// del backend (mismos IDs) llegue limpia.
  /// [orderId] es el ID del pedido principal que fue rechazado (siempre limpiado).
  /// [transactionRef] limpia también los hermanos del grupo multitienda.
  void releaseTransactionRef(int? orderId, String? transactionRef) {
    final idsToRelease = <int>{};

    // 1. Siempre limpiar el orderId principal (cubre dummies sin transactionRef)
    if (orderId != null) {
      idsToRelease.add(orderId);
      _shownOrderIds.remove(orderId);
    }

    // 2. Si hay transactionRef, limpiar todos los hermanos del grupo
    if (transactionRef != null && transactionRef.isNotEmpty) {
      _shownTransactionRefs.remove(transactionRef);
      final groupIds = _transactionRefOrderIds.remove(transactionRef) ?? {};
      for (final id in groupIds) {
        _shownOrderIds.remove(id);
        idsToRelease.add(id);
      }
    }

    // 3. Limpiar el dedup interno de OrderNotificationService
    if (idsToRelease.isNotEmpty) {
      OrderNotificationService.instance.releaseOrderIds(idsToRelease);
    }

    debugPrint(
      "[Dashboard] 🔓 releaseTransactionRef: ref=$transactionRef — "
      "orderIds limpiados: $idsToRelease (listos para reoferta)",
    );
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

    debugPrint(
      "[Dashboard] 📨 _dispatchOrderToHome called for order $id (Current page: $_pageIndex)",
    );

    // 🔊 Si es un pedido nuevo detectado por Polling/Init (no por FCM/Pusher),
    // forzamos el sonido para que el repartidor no lo pierda.
    if (!_shownOrderIds.contains(id)) {
      debugPrint("****************************************************");
      debugPrint("🔊 [Dashboard] DETECTED NEW ORDER $id - TRIGGERING SOUND");
      debugPrint("****************************************************");
      OrderNotificationService.instance.playOrderRequestAlertSound();
      _shownOrderIds.add(id);
    }

    final homeState = _homeScreenKey.currentState;

    debugPrint(
      "[Dashboard] _dispatchOrderToHome($id) - homeState=${homeState != null ? 'ok' : 'null'}",
    );

    if (homeState == null) {
      debugPrint(
        "[Dashboard] ⚠️ HomeScreenState es null, reintentando en siguiente frame para order $id",
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _dispatchOrderToHome(order);
      });
      return;
    }

    debugPrint("[Dashboard] ✅ DISPATCHING order $id a HomeScreen");
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

      // Refrescar perfil al volver al primer plano (p. ej. admin acaba de aprobar el registro).
      if (Get.isRegistered<ProfileController>()) {
        Get.find<ProfileController>().getProfile().then((_) {
          if (!mounted) return;
          PusherService.instance.disconnect();
          final profileModel = Get.find<ProfileController>().profileModel;
          if (profileModel != null && profileModel.id != null) {
            PusherService.instance.resetReconnectAttempts();
            PusherService.instance.initPusher(profileModel.id!);
          }
          if (Get.find<ProfileController>().isPendingRegistrationDashboard) {
            return;
          }
          Get.find<OrderController>().getLatestOrders().then((_) {
            if (!mounted || _pageIndex != 0 || _isOrderActive) return;
            final latestOrders = Get.find<OrderController>().latestOrderList;
            if (latestOrders != null && latestOrders.isNotEmpty) {
              _dispatchOrderToHome(latestOrders.first);
            }
          });
        });
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
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
          final bool pendingReg =
              profileController.isPendingRegistrationDashboard;
          if (pendingReg) {
            _handledRegistrationApprovalTransition = false;
          } else if (_lastPendingRegistration == true && !pendingReg) {
            if (!_handledRegistrationApprovalTransition) {
              _handledRegistrationApprovalTransition = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                _startLatestOrdersPolling();
                if (Get.isRegistered<MissionController>()) {
                  Get.find<MissionController>().getMissionList();
                }
              });
            }
          }
          _lastPendingRegistration = pendingReg;

          _screens = [
            HomeScreen(
              key: _homeScreenKey,
              pendingRegistrationDashboard: pendingReg,
              onNavigateToOrders: () => _setPage(2),
              onTapMenu: () => _scaffoldKey.currentState?.openDrawer(),
              onOrderActiveStatusChanged: (isActive) {
                if (_isOrderActive != isActive) {
                  setState(() {
                    _isOrderActive = isActive;
                  });
                }
              },
              onOrderDismissed: (orderId, transactionRef) {
                releaseTransactionRef(orderId, transactionRef);
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
            const MyEarningScreen(),
          ];

          bool isHome = _pageIndex == 0;
          bool isOffline = profileController.profileModel?.active == 0;
          bool showBottomBar = isOffline || _isBottomBarVisible;
          bool hasSlider = isHome && profileController.profileModel != null;

          debugPrint(
            '[Dashboard Build Debug] isHome=$isHome, hasSlider=$hasSlider, active=${profileController.profileModel?.active}, appStatus=${profileController.profileModel?.applicationStatus}, _isOrderActive=$_isOrderActive, pendingReg=$pendingReg, isOffline=$isOffline',
          );

          return Scaffold(
            key: _scaffoldKey,
            drawerEnableOpenDragGesture: !_isOrderActive,
            drawer: DashboardDrawerWidget(
              profileController: profileController,
              pageIndex: _pageIndex,
              isPendingRegistrationDashboard: pendingReg,
              onSelectPage: (int index) {
                Get.back();
                _setPage(index);
              },
            ),
            bottomNavigationBar: null,
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

                // FAB controls: Location and Layer toggles (circular black buttons)
                if (hasSlider && !_isOrderActive && !pendingReg)
                  Positioned(
                    bottom:
                        MediaQuery.of(context).size.height *
                        (isOffline ? 0.38 : 0.28),
                    right: Dimensions.paddingSizeDefault,
                    child: Column(
                      children: [
                        // Location Button
                        Container(
                          height: 40,
                          width: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F161E),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(
                              Icons.gps_fixed,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: () => _homeScreenKey.currentState
                                ?.animateToMyLocation(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Traffic toggle Button
                        Builder(
                          builder: (context) {
                            final bool trafficActive =
                                _homeScreenKey.currentState?.isTrafficEnabled ??
                                false;
                            return Container(
                              height: 40,
                              width: 40,
                              decoration: BoxDecoration(
                                color: trafficActive
                                    ? const Color(0xFF5EC44B)
                                    : const Color(0xFF0F161E),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: Icon(
                                  Icons.layers,
                                  color: trafficActive
                                      ? Colors.black
                                      : Colors.white,
                                  size: 20,
                                ),
                                onPressed: () {
                                  _homeScreenKey.currentState?.toggleTraffic();
                                  setState(() {});
                                },
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                if (hasSlider && !_isOrderActive)
                  DraggableScrollableSheet(
                    initialChildSize: pendingReg
                        ? 0.28
                        : (isOffline ? 0.35 : 0.25),
                    minChildSize: pendingReg ? 0.22 : (isOffline ? 0.35 : 0.25),
                    maxChildSize: 0.85,
                    snap: true,
                    builder: (context, scrollController) {
                      if (pendingReg) {
                        return PendingRegistrationPanelWidget(
                          scrollController: scrollController,
                          adminRevisionMessage: profileController
                              .profileModel
                              ?.registrationRevisionMessage,
                          showRevisionFootnote:
                              profileController
                                  .profileModel
                                  ?.registrationRevisionRequired ==
                              true,
                        );
                      }
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
                              onGoToOrderCenter: () => _setPage(1),
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
    if (Get.find<ProfileController>().isPendingRegistrationDashboard &&
        pageIndex != 0) {
      showCustomSnackBar('registration_in_progress_title'.tr, isError: false);
      return;
    }
    setState(() {
      _pageController!.jumpToPage(pageIndex);
      _pageIndex = pageIndex;
    });

    if (pageIndex != 0) {
      _homeScreenKey.currentState?.cancelOrderRequest(callApi: false);
    }
  }
}
