import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixam_mart_delivery/features/order/domain/models/order_model.dart';
import 'package:sixam_mart_delivery/features/order/controllers/order_controller.dart';
import 'package:sixam_mart_delivery/features/splash/controllers/splash_controller.dart';
import 'dart:io';
import 'package:sixam_mart_delivery/util/dimensions.dart';
import 'package:sixam_mart_delivery/util/styles.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_snackbar_widget.dart';
import 'package:sixam_mart_delivery/helper/route_helper.dart';
import 'package:sixam_mart_delivery/util/app_constants.dart';
import 'package:sixam_mart_delivery/features/notification/domain/models/notification_body_model.dart';
import 'package:sixam_mart_delivery/features/chat/domain/models/conversation_model.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:sixam_mart_delivery/helper/dm_call_log_verification_helper.dart';
import 'package:sixam_mart_delivery/helper/dm_contact_timer_helper.dart';
import 'package:sixam_mart_delivery/main.dart'
    show flutterLocalNotificationsPlugin;
import 'package:sixam_mart_delivery/common/widgets/custom_bottom_sheet_widget.dart';
import 'package:sixam_mart_delivery/features/order/widgets/cancellation_dialogue_widget.dart';
import 'package:sixam_mart_delivery/features/order/widgets/parcel_cancelation/cancellation_reason_bottom_sheet.dart';

/// QA: `true` omite la validación de proximidad (100 m tienda / 500 m cliente).
const bool kDisableDeliveryProximityCheckForQa = true;

class AcceptedOrderWidget extends StatefulWidget {
  final List<OrderModel> activeOrders;
  final String phase;
  final Function(OrderModel) onHandover;
  final Function(OrderModel) onPickedUp;
  final Function(OrderModel) onDelivered;
  final String? estimatedArrivalTime;
  final Function(int)? onOrderSelected;

  const AcceptedOrderWidget({
    super.key,
    required this.activeOrders,
    required this.phase,
    required this.onHandover,
    required this.onPickedUp,
    required this.onDelivered,
    this.estimatedArrivalTime,
    this.onOrderSelected,
  });

  @override
  State<AcceptedOrderWidget> createState() => _AcceptedOrderWidgetState();
}

class _AcceptedOrderWidgetState extends State<AcceptedOrderWidget>
    with WidgetsBindingObserver {
  double _sliderValue = 0.0;
  int _currentIndex = 0;
  bool _isCheckingProximity = false;
  bool _isDetailsExpanded = true;
  bool _isCustomerDetailsExpanded = true;
  bool _isMinimized = false;

  Timer? _customerProximityPollTimer;
  Timer? _customerContactCountdownTimer;
  bool _within100mOfCustomer = false;
  int _customerTelLaunchCount = 0;
  bool _customerContactCountdownStarted = false;
  int? _customerContactSecondsRemaining;
  bool _awaitingCallReturnConfirm = false;
  DateTime? _customerCallLaunchedAt;
  static const String _prefPrefixCalls = 'dm_cust_confirmed_call_attempts_';
  static const String _prefPrefixEndMs = 'dm_cust_contact_timer_end_ms_';
  static const String _prefPrefixStarted = 'dm_cust_contact_timer_started_';
  static const String _prefPrefixStartMs = 'dm_cust_contact_timer_start_ms_';
  static const String _prefPrefixAttemptsJson = 'dm_cust_call_attempts_json_';
  static const String _prefPrefixProtocolActivated =
      'dm_cust_protocol_activated_';

  bool _isWaitingProtocolActivated = false;
  int? _countdownDeadlineMs;
  int? _countdownStartMs;

  OrderModel get _currentOrder => widget.activeOrders[_currentIndex];
  int? get _oid => _currentOrder.id;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Fetch initial order details
    Future.delayed(Duration.zero, () {
      Get.find<OrderController>().getOrderDetails(
        _oid,
        _currentOrder.orderType == 'parcel',
      );
    });

    if (widget.phase == 'going_to_customer') {
      _restoreContactTimerFromPrefs().then((_) {
        if (widget.phase == 'going_to_customer') {
          _startCustomerContactMonitoring();
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeLocalContactTimersOnly();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (widget.phase == 'going_to_customer') {
        if (_awaitingCallReturnConfirm) {
          _awaitingCallReturnConfirm = false;
          _processCustomerCallAfterDialer();
        }
        if (_customerContactCountdownStarted) {
          _syncCountdownFromStoredDeadline();
        }
      }
    }
  }

  void _disposeLocalContactTimersOnly() {
    _customerProximityPollTimer?.cancel();
    _customerContactCountdownTimer?.cancel();
  }

  Future<void> _restoreContactTimerFromPrefs() async {
    final int? oid = _oid;
    if (oid == null) return;
    final SharedPreferences p = await SharedPreferences.getInstance();
    _customerTelLaunchCount = p.getInt('$_prefPrefixCalls$oid') ?? 0;
    _isWaitingProtocolActivated =
        p.getBool('$_prefPrefixProtocolActivated$oid') ?? false;
    _customerContactCountdownStarted =
        p.getBool('$_prefPrefixStarted$oid') ?? false;
    _countdownStartMs = p.getInt('$_prefPrefixStartMs$oid');
    final int? endMs = p.getInt('$_prefPrefixEndMs$oid');
    if (endMs != null && _customerContactCountdownStarted) {
      _countdownDeadlineMs = endMs;
      final int left = ((endMs - DateTime.now().millisecondsSinceEpoch) / 1000)
          .ceil()
          .clamp(0, 600);
      _customerContactSecondsRemaining = left;
      if (left > 0) {
        _runCountdownTicker();
      }
    }
    _reportContactStatusToController();
    if (mounted) setState(() {});
  }

  Future<void> _persistProtocolActivated() async {
    final int? oid = _oid;
    if (oid == null) return;
    final SharedPreferences p = await SharedPreferences.getInstance();
    await p.setBool('$_prefPrefixProtocolActivated$oid', true);
  }

  Future<void> _persistCallCount() async {
    final int? oid = _oid;
    if (oid == null) return;
    final SharedPreferences p = await SharedPreferences.getInstance();
    await p.setInt('$_prefPrefixCalls$oid', _customerTelLaunchCount);
  }

  Future<void> _persistCountdownState(int startMs, int deadlineMs) async {
    final int? oid = _oid;
    if (oid == null) return;
    final SharedPreferences p = await SharedPreferences.getInstance();
    await p.setInt('$_prefPrefixEndMs$oid', deadlineMs);
    await p.setInt('$_prefPrefixStartMs$oid', startMs);
    await p.setBool('$_prefPrefixStarted$oid', true);
  }

  Future<void> _clearContactOrderPrefs() async {
    final int? oid = _oid;
    if (oid == null) return;
    final SharedPreferences p = await SharedPreferences.getInstance();
    await p.remove('$_prefPrefixCalls$oid');
    await p.remove('$_prefPrefixEndMs$oid');
    await p.remove('$_prefPrefixStarted$oid');
    await p.remove('$_prefPrefixStartMs$oid');
    await p.remove('$_prefPrefixProtocolActivated$oid');
  }

  void _reportContactStatusToController() {
    Get.find<OrderController>().reportDeliveryCancelContactSnapshot(
      orderId: _oid,
      phase: widget.phase,
      customerCallCount: _customerTelLaunchCount,
      within100mOfCustomer: _within100mOfCustomer,
      contactCountdownStarted: _customerContactCountdownStarted,
      contactSecondsRemaining: _customerContactSecondsRemaining,
    );
  }

  void _syncCountdownFromStoredDeadline() async {
    if (_countdownDeadlineMs == null) await _restoreContactTimerFromPrefs();
    if (_countdownDeadlineMs == null) return;
    final int left =
        ((_countdownDeadlineMs! - DateTime.now().millisecondsSinceEpoch) / 1000)
            .ceil()
            .clamp(0, 600);
    setState(() => _customerContactSecondsRemaining = left);
    if (left > 0) _runCountdownTicker();
  }

  Future<void> _processCustomerCallAfterDialer() async {
    if (!mounted) return;
    final String? target =
        _currentOrder.deliveryAddress?.contactPersonNumber ??
        _currentOrder.customer?.phone;
    if (DmCallLogVerificationHelper.isAndroid) {
      final bool granted =
          await DmCallLogVerificationHelper.ensureCallLogAccess();
      if (!granted) {
        _showCustomerCallConfirmDialog();
        return;
      }
      final bool found =
          await DmCallLogVerificationHelper.hasRecentOutgoingCallTo(
            targetPhoneRaw: target,
            notBefore: (_customerCallLaunchedAt ?? DateTime.now()).subtract(
              const Duration(minutes: 1),
            ),
          );
      if (found) {
        await _applyCustomerCallAttemptConfirmed();
      } else {
        _showCustomerCallConfirmDialog();
      }
    } else {
      _showCustomerCallConfirmDialog();
    }
  }

  Future<void> _applyCustomerCallAttemptConfirmed() async {
    setState(() {
      _customerTelLaunchCount++;
    });
    await _persistCallCount();
    _reportContactStatusToController();
    await _tryStartCustomerContactCountdown();
  }

  void _showCustomerCallConfirmDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Llamada'),
        content: const Text('¿Lograste realizar la llamada al cliente?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _applyCustomerCallAttemptConfirmed();
            },
            child: const Text('Sí'),
          ),
        ],
      ),
    );
  }

  void _startCustomerContactMonitoring() {
    _customerProximityPollTimer?.cancel();
    _customerProximityPollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _pollCustomerProximity(),
    );
  }

  void _pollCustomerProximity() async {
    if (kDisableDeliveryProximityCheckForQa) {
      setState(() => _within100mOfCustomer = true);
      _tryStartCustomerContactCountdown();
      return;
    }
    final double lat =
        double.tryParse(_currentOrder.deliveryAddress?.latitude ?? '') ?? 0;
    final double lng =
        double.tryParse(_currentOrder.deliveryAddress?.longitude ?? '') ?? 0;
    if (lat == 0 || lng == 0) return;
    try {
      Position p = await Geolocator.getCurrentPosition();
      double d = Geolocator.distanceBetween(p.latitude, p.longitude, lat, lng);
      setState(() => _within100mOfCustomer = d <= 100);
      _reportContactStatusToController();
      _tryStartCustomerContactCountdown();
    } catch (_) {}
  }

  Future<void> _tryStartCustomerContactCountdown() async {
    if (_customerContactCountdownStarted ||
        _customerTelLaunchCount < 3 ||
        !_within100mOfCustomer)
      return;
    _customerContactCountdownStarted = true;
    final int startMs = DateTime.now().millisecondsSinceEpoch;
    final int deadline = startMs + 600000;
    await _persistCountdownState(startMs, deadline);
    setState(() {
      _countdownDeadlineMs = deadline;
      _countdownStartMs = startMs;
      _customerContactSecondsRemaining = 600;
    });
    _reportContactStatusToController();
    _runCountdownTicker();
  }

  void _runCountdownTicker() {
    _customerContactCountdownTimer?.cancel();
    _customerContactCountdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (t) {
        if (!mounted || _countdownDeadlineMs == null) {
          t.cancel();
          return;
        }
        final int next =
            ((_countdownDeadlineMs! - DateTime.now().millisecondsSinceEpoch) /
                    1000)
                .ceil()
                .clamp(0, 600);
        setState(() => _customerContactSecondsRemaining = next);
        _reportContactStatusToController();
        if (next <= 0) t.cancel();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.activeOrders.isEmpty) return const SizedBox();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF121217),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeLarge,
        vertical: Dimensions.paddingSizeDefault,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _isMinimized = !_isMinimized),
            behavior: HitTestBehavior.opaque,
            child: Column(
              children: [
                Center(
                  child: Container(
                    height: 5,
                    width: 40,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),

          if (widget.activeOrders.length > 1 ||
              (widget.activeOrders.length == 1 && _isMinimized)) ...[
            Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(25),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: List.generate(widget.activeOrders.length, (index) {
                  bool isActive = _currentIndex == index;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _currentIndex = index;
                          _isMinimized = false; // Expand when switching
                        });
                        widget.onOrderSelected?.call(index);
                        Get.find<OrderController>().getOrderDetails(
                          widget.activeOrders[_currentIndex].id,
                          widget.activeOrders[_currentIndex].orderType ==
                              'parcel',
                        );
                      },
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isActive
                              ? const Color(0xFF2ECC71)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Center(
                              child: Text(
                                'Pedido ${index + 1}',
                                style: robotoBold.copyWith(
                                  color: isActive
                                      ? Colors.black
                                      : Colors.white60,
                                  fontSize:
                                      (widget.activeOrders.length == 1 &&
                                          _isMinimized)
                                      ? 20
                                      : 16,
                                ),
                              ),
                            ),
                            if (index ==
                                0) // The first stop in the optimized list
                              Positioned(
                                top: -8,
                                right: -10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2ECC71),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.black,
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    'SIGUIENTE',
                                    style: robotoBold.copyWith(
                                      color: Colors.black,
                                      fontSize: 8,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],

          if (!_isMinimized) ...[
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 25),
                    // Progress Steps
                    Row(
                      children: [
                        _buildProgressStep(true),
                        _buildProgressLine(widget.phase != 'going_to_store'),
                        _buildProgressStep(widget.phase != 'going_to_store'),
                        _buildProgressLine(widget.phase == 'going_to_customer'),
                        _buildProgressStep(widget.phase == 'going_to_customer'),
                      ],
                    ),
                    const SizedBox(height: 25),

                    // --- STORE CONTAINER ---
                    if (widget.phase == 'going_to_store' ||
                        widget.phase == 'at_store') ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(
                          Dimensions.paddingSizeDefault,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Store Header
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () => setState(
                                    () => _isDetailsExpanded =
                                        !_isDetailsExpanded,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFFF39C12,
                                      ).withValues(alpha: 0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.restaurant,
                                      color: Color(0xFFF39C12),
                                      size: 20,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(
                                      () => _isDetailsExpanded =
                                          !_isDetailsExpanded,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                _currentOrder.storeName ??
                                                    'Restaurante',
                                                style: robotoBold.copyWith(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 5),
                                            Icon(
                                              _isDetailsExpanded
                                                  ? Icons.keyboard_arrow_up
                                                  : Icons.keyboard_arrow_down,
                                              color: Colors.white38,
                                              size: 18,
                                            ),
                                          ],
                                        ),
                                        if (!_isDetailsExpanded)
                                          Text(
                                            _currentOrder.storeAddress ??
                                                'Dirección del restaurante',
                                            style: robotoRegular.copyWith(
                                              color: Colors.white38,
                                              fontSize: 12,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                _buildStopActionIconButton(
                                  icon: Icons.chat_bubble_rounded,
                                  label: 'Mensaje',
                                  color: const Color(0xFF3498DB),
                                  onTap: _chatWithStore,
                                ),
                              ],
                            ),

                            if (_isDetailsExpanded) ...[
                              const SizedBox(height: 15),
                              Row(
                                children: [
                                  const SizedBox(width: 42),
                                  Expanded(
                                    child: Text(
                                      _currentOrder.storeAddress ??
                                          'Dirección del restaurante',
                                      style: robotoRegular.copyWith(
                                        color: Colors.white70,
                                        fontSize: 13,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  _buildStopActionIconButton(
                                    icon: Icons.call,
                                    label: 'Llamar',
                                    color: const Color(0xFF2ECC71),
                                    onTap: _callStore,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 15),
                              const Divider(color: Colors.white10, height: 1),
                              const SizedBox(height: 15),
                              _buildProductListSection(),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 15),
                    ],

                    // --- CUSTOMER CONTAINER ---
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(
                        Dimensions.paddingSizeDefault,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Customer Header
                          GestureDetector(
                            onTap: () => setState(
                              () => _isCustomerDetailsExpanded =
                                  !_isCustomerDetailsExpanded,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF2ECC71,
                                    ).withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.person,
                                    color: Color(0xFF2ECC71),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              '${_currentOrder.customer?.fName ?? ''} ${_currentOrder.customer?.lName ?? ''}',
                                              style: robotoBold.copyWith(
                                                color: Colors.white,
                                                fontSize: 16,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 5),
                                          Icon(
                                            _isCustomerDetailsExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                            color: Colors.white38,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          // Payment Method Badge
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: (_currentOrder.paymentMethod == 'cash_on_delivery')
                                                  ? Colors.orange.withValues(alpha: 0.1)
                                                  : Colors.blue.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: (_currentOrder.paymentMethod == 'cash_on_delivery')
                                                    ? Colors.orange.withValues(alpha: 0.3)
                                                    : Colors.blue.withValues(alpha: 0.3),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  (_currentOrder.paymentMethod == 'cash_on_delivery') ? Icons.money : Icons.credit_card,
                                                  size: 12,
                                                  color: (_currentOrder.paymentMethod == 'cash_on_delivery') ? Colors.orange : Colors.blue,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  (_currentOrder.paymentMethod == 'cash_on_delivery') ? 'Efectivo' : 'Pagado',
                                                  style: robotoMedium.copyWith(
                                                    color: (_currentOrder.paymentMethod == 'cash_on_delivery') ? Colors.orange : Colors.blue,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (!_isCustomerDetailsExpanded)
                                        Text(
                                          _currentOrder.deliveryAddress?.address ?? 'Dirección de entrega',
                                          style: robotoRegular.copyWith(color: Colors.white38, fontSize: 12),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                                if (!_isCustomerDetailsExpanded)
                                  _buildStopActionIconButton(
                                    icon: Icons.chat_bubble_rounded,
                                    label: 'Mensaje',
                                    color: const Color(0xFF3498DB),
                                    onTap: _chatWithCustomer,
                                  ),
                              ],
                            ),
                          ),

                          if (_isCustomerDetailsExpanded) ...[
                            const SizedBox(height: 15),
                            Row(
                              children: [
                                const SizedBox(width: 42),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _currentOrder.deliveryAddress?.address ?? 'Dirección de entrega',
                                        style: robotoRegular.copyWith(color: Colors.white70, fontSize: 13),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 10),
                                      if (_currentOrder.paymentMethod == 'cash_on_delivery')
                                        Text(
                                          'Cobrar: \$${_currentOrder.orderAmount}',
                                          style: robotoBold.copyWith(
                                            color: const Color(0xFF2ECC71),
                                            fontSize: 15,
                                          ),
                                        ),
                                      const SizedBox(height: 5),
                                      Text(
                                        'Referencia: ${_currentOrder.deliveryAddress?.house ?? ''} ${_currentOrder.deliveryAddress?.floor ?? ''}',
                                        style: robotoRegular.copyWith(
                                          color: Colors.white38,
                                          fontSize: 12,
                                        ),
                                      ),

                                      // --- DELIVERY INSTRUCTIONS ---
                                      if ((_currentOrder.orderNote != null && _currentOrder.orderNote!.isNotEmpty) ||
                                          (_currentOrder.deliveryInstruction != null && _currentOrder.deliveryInstruction!.isNotEmpty)) ...[
                                        const SizedBox(height: 12),
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.05),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  const Icon(Icons.info_outline, color: Color(0xFF3498DB), size: 14),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    'INSTRUCCIONES',
                                                    style: robotoBold.copyWith(color: const Color(0xFF3498DB), fontSize: 10, letterSpacing: 0.5),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              if (_currentOrder.orderNote != null && _currentOrder.orderNote!.isNotEmpty)
                                                Text(
                                                  _currentOrder.orderNote!,
                                                  style: robotoMedium.copyWith(color: Colors.white, fontSize: 13),
                                                ),
                                              if (_currentOrder.orderNote != null && _currentOrder.orderNote!.isNotEmpty &&
                                                  _currentOrder.deliveryInstruction != null && _currentOrder.deliveryInstruction!.isNotEmpty)
                                                const SizedBox(height: 5),
                                              if (_currentOrder.deliveryInstruction != null && _currentOrder.deliveryInstruction!.isNotEmpty)
                                                Text(
                                                  _currentOrder.deliveryInstruction!,
                                                  style: robotoMedium.copyWith(color: Colors.white, fontSize: 13),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  children: [
                                    _buildStopActionIconButton(
                                      icon: Icons.chat_bubble_rounded,
                                      label: 'Mensaje',
                                      color: const Color(0xFF3498DB),
                                      onTap: _chatWithCustomer,
                                    ),
                                    const SizedBox(height: 10),
                                    _buildStopActionIconButton(
                                      icon: Icons.call,
                                      label: 'Llamar',
                                      color: const Color(0xFF2ECC71),
                                      onTap: _callCustomer,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],

                          if (widget.phase == 'going_to_customer') ...[
                            const SizedBox(height: 20),
                            const Divider(color: Colors.white10, height: 1),
                            const SizedBox(height: 15),
                            if (_isWaitingProtocolActivated) ...[
                              _buildCustomerContactTimerCard(context),
                              const SizedBox(height: 20),
                            ],
                            _buildDeliveryEvidenceSection(),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 25),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pedido #${_currentOrder.id}',
                        style: robotoBold.copyWith(
                          color: Colors.white,
                          fontSize: 28,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF2ECC71),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.phase == 'going_to_store'
                                  ? 'En camino al restaurante'
                                  : widget.phase == 'at_store'
                                  ? 'En el restaurante'
                                  : 'En camino al cliente',
                              style: robotoMedium.copyWith(
                                color: const Color(0xFF2ECC71),
                                fontSize: 16,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (widget.estimatedArrivalTime != null)
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time_filled,
                              color: Color(0xFFF39C12),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Llega antes de las ${widget.estimatedArrivalTime}',
                                style: robotoMedium.copyWith(
                                  color: const Color(0xFFF39C12),
                                  fontSize: 15,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (widget.phase == 'going_to_customer' &&
                        !_isWaitingProtocolActivated) ...[
                      GestureDetector(
                        onTap: _activateWaitingProtocol,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFF39C12,
                            ).withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: const Color(
                                0xFFF39C12,
                              ).withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.timer_outlined,
                                color: Color(0xFFF39C12),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'No contactado',
                                style: robotoBold.copyWith(
                                  color: const Color(0xFFF39C12),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: _showNavigationOptions,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF1B5E20,
                              ).withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: const Color(
                                  0xFF2ECC71,
                                ).withValues(alpha: 0.5),
                              ),
                            ),
                            child: const Icon(
                              Icons.near_me,
                              color: Color(0xFF2ECC71),
                              size: 28,
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        GestureDetector(
                          onTap: _showSupportBottomSheet,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFFB71C1C,
                              ).withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: Colors.red.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Text(
                              'sos',
                              style: robotoBold.copyWith(
                                color: Colors.red,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 30),

            // Prominent Chat Button (Only when delivering to customer)
            if (widget.phase == 'going_to_customer')
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: GestureDetector(
                  onTap: _chatWithCustomer,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3498DB).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: const Color(0xFF3498DB).withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.chat_bubble_outline,
                          color: Color(0xFF3498DB),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'CHATEAR CON CLIENTE',
                          style: robotoBold.copyWith(
                            color: const Color(0xFF3498DB),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 65,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2ECC71),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Center(
                    child: Text(
                      widget.phase == 'going_to_store'
                          ? 'LLEGUÉ AL RESTAURANTE'
                          : widget.phase == 'at_store'
                          ? 'PEDIDO RECOGIDO'
                          : 'ENTREGAR PEDIDO',
                      style: robotoBold.copyWith(
                        color: Colors.black,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 65,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 32,
                      ),
                      overlayShape: SliderComponentShape.noOverlay,
                      activeTrackColor: Colors.transparent,
                      inactiveTrackColor: Colors.transparent,
                      thumbColor: Colors.black.withOpacity(0.1),
                    ),
                    child: Slider(
                      value: _sliderValue,
                      onChanged: (value) {
                        setState(() => _sliderValue = value);
                        if (value > 0.9) {
                          if (widget.phase == 'going_to_store') {
                            _checkProximityAndProceed(
                              targetLat:
                                  double.tryParse(
                                    _currentOrder.storeLat ?? '',
                                  ) ??
                                  0,
                              targetLng:
                                  double.tryParse(
                                    _currentOrder.storeLng ?? '',
                                  ) ??
                                  0,
                              maxDistance: 100,
                              onSuccess: () => widget.onHandover(_currentOrder),
                              errorMessage:
                                  'Debes estar cerca del restaurante para marcar llegada.',
                            );
                          } else if (widget.phase == 'at_store') {
                            _checkProximityAndProceed(
                              targetLat:
                                  double.tryParse(
                                    _currentOrder.storeLat ?? '',
                                  ) ??
                                  0,
                              targetLng:
                                  double.tryParse(
                                    _currentOrder.storeLng ?? '',
                                  ) ??
                                  0,
                              maxDistance: 100,
                              onSuccess: () => widget.onPickedUp(_currentOrder),
                              errorMessage:
                                  'Debes estar cerca del restaurante para recoger el pedido.',
                            );
                          } else {
                            _checkProximityAndProceed(
                              targetLat:
                                  double.tryParse(
                                    _currentOrder.deliveryAddress?.latitude ??
                                        '',
                                  ) ??
                                  0,
                              targetLng:
                                  double.tryParse(
                                    _currentOrder.deliveryAddress?.longitude ??
                                        '',
                                  ) ??
                                  0,
                              maxDistance: 500,
                              onSuccess: () =>
                                  widget.onDelivered(_currentOrder),
                              errorMessage:
                                  'Debes estar cerca del cliente para entregar.',
                            );
                          }
                          setState(() => _sliderValue = 0.0);
                        }
                      },
                      onChangeEnd: (value) {
                        if (value <= 0.9) setState(() => _sliderValue = 0.0);
                      },
                    ),
                  ),
                ),
                Positioned(
                  left:
                      10 +
                      (_sliderValue *
                          (MediaQuery.of(context).size.width - 120)),
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.black,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressStep(bool completed) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: completed ? const Color(0xFF2ECC71) : Colors.white24,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildProgressLine(bool completed) {
    return Expanded(
      child: Container(
        height: 4,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: completed ? const Color(0xFF2ECC71) : Colors.white10,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildProductListSection() {
    return GetBuilder<OrderController>(
      builder: (orderController) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Productos a recoger:',
              style: robotoMedium.copyWith(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 10),
            if (orderController.orderDetailsModel != null &&
                orderController.orderDetailsModel!.isNotEmpty)
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: orderController.orderDetailsModel!.length,
                itemBuilder: (context, index) {
                  var detail = orderController.orderDetailsModel![index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFF39C12,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${detail.quantity}x',
                            style: robotoBold.copyWith(
                              color: const Color(0xFFF39C12),
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            detail.itemDetails?.name ?? 'Producto',
                            style: robotoRegular.copyWith(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              )
            else
              const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildDeliveryEvidenceSection() {
    return GetBuilder<OrderController>(
      builder: (orderController) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Evidencia de Entrega',
              style: robotoMedium.copyWith(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                GestureDetector(
                  onTap: () => orderController.pickCameraDirectly(),
                  child: Container(
                    height: 60,
                    width: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF2ECC71).withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Color(0xFF2ECC71),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 60,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: orderController.pickedPrescriptions.length,
                      itemBuilder: (context, index) {
                        return Stack(
                          children: [
                            Container(
                              margin: const EdgeInsets.only(right: 10),
                              height: 60,
                              width: 60,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                image: DecorationImage(
                                  image: FileImage(
                                    File(
                                      orderController
                                          .pickedPrescriptions[index]
                                          .path,
                                    ),
                                  ),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: -2,
                              right: 8,
                              child: GestureDetector(
                                onTap: () =>
                                    orderController.pickPrescriptionImage(
                                      isRemove: true,
                                      isCamera: false,
                                    ),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
            if (Get.find<SplashController>()
                    .configModel
                    ?.orderDeliveryVerification ??
                false) ...[
              const SizedBox(height: 15),
              TextField(
                onChanged: (value) => orderController.setOtp(value),
                keyboardType: TextInputType.number,
                style: robotoMedium.copyWith(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Código de Verificación',
                  hintStyle: robotoRegular.copyWith(color: Colors.white24),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 15),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF2ECC71)),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildStopActionIconButton({
    required IconData icon,
    required String label,
    required Color color,
    required Function() onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 4),
          Text(label, style: robotoMedium.copyWith(color: color, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildStopContactButton({
    required IconData icon,
    required Color color,
    required Function() onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  void _showNavigationOptions() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF121217),
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Navegación',
              style: robotoBold.copyWith(fontSize: 18, color: Colors.white),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavOption(
                  'Google Maps',
                  Icons.map,
                  Colors.green,
                  () => _launchNavigation('google'),
                ),
                _buildNavOption(
                  'Waze',
                  Icons.navigation,
                  Colors.blue,
                  () => _launchNavigation('waze'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavOption(
    String name,
    IconData icon,
    Color color,
    Function onTap,
  ) {
    return InkWell(
      onTap: () {
        Get.back();
        onTap();
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: 8),
          Text(name, style: robotoMedium.copyWith(color: Colors.white)),
        ],
      ),
    );
  }

  void _launchNavigation(String app) async {
    String lat = widget.phase == 'going_to_store'
        ? (_currentOrder.storeLat ?? '0')
        : (_currentOrder.deliveryAddress?.latitude ?? '0');
    String lng = widget.phase == 'going_to_store'
        ? (_currentOrder.storeLng ?? '0')
        : (_currentOrder.deliveryAddress?.longitude ?? '0');
    String url = app == 'google'
        ? 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&mode=d'
        : 'https://waze.com/ul?ll=$lat,$lng&navigate=yes';
    if (await canLaunchUrlString(url))
      await launchUrlString(url, mode: LaunchMode.externalApplication);
  }

  void _showSupportBottomSheet() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF121217),
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Soporte',
              style: robotoBold.copyWith(fontSize: 18, color: Colors.white),
            ),
            const SizedBox(height: 20),
            _buildSupportOption(
              'Mensaje con soporte',
              Icons.chat_bubble_outline,
              const Color(0xFF3498DB),
              () => _chatWithAdmin(null),
            ),
            const SizedBox(height: 10),
            _buildSupportOption(
              'No puedo continuar con el pedido',
              Icons.cancel_outlined,
              Colors.orange,
              () => _chatWithAdmin('No puedo continuar con el pedido'),
            ),
            const SizedBox(height: 10),
            _buildSupportOption(
              'Llamar al 911',
              Icons.emergency,
              Colors.red,
              () => launchUrlString('tel:911'),
            ),
          ],
        ),
      ),
    );
  }

  void _chatWithAdmin(String? prefill) {
    if (prefill == 'No puedo continuar con el pedido') {
      Get.dialog(
        CancellationDialogueWidget(orderId: _currentOrder.id!),
        barrierDismissible: true,
      );
    } else {
      Get.find<OrderController>().openAdminSupportChatForCancelRequest(
        orderId: _currentOrder.id!,
        order: _currentOrder,
        cancellationReason: prefill,
      );
    }
  }

  Widget _buildSupportOption(
    String title,
    IconData icon,
    Color color,
    Function onTap,
  ) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: robotoMedium.copyWith(color: Colors.white)),
      onTap: () {
        Get.back();
        onTap();
      },
    );
  }

  void _callCustomer() async {
    String? phone =
        _currentOrder.deliveryAddress?.contactPersonNumber ??
        _currentOrder.customer?.phone;
    if (phone != null && await canLaunchUrlString('tel:$phone')) {
      _awaitingCallReturnConfirm = true;
      _customerCallLaunchedAt = DateTime.now();
      await launchUrlString('tel:$phone', mode: LaunchMode.externalApplication);
    }
  }

  void _activateWaitingProtocol() {
    if (_customerTelLaunchCount < 3) {
      showCustomSnackBar(
        'Debes realizar al menos 3 llamadas al cliente antes de activar el protocolo de espera.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isWaitingProtocolActivated = true;
      _customerContactCountdownStarted = true;
      _countdownStartMs = DateTime.now().millisecondsSinceEpoch;
      _countdownDeadlineMs = DateTime.now()
          .add(const Duration(minutes: 10))
          .millisecondsSinceEpoch;
      _customerContactSecondsRemaining = 600; // 10 minutes
    });

    _persistProtocolActivated();
    _persistContactTimerStarted();
    _runCountdownTicker();
    _reportContactStatusToController();

    Get.find<OrderController>().openAdminSupportChatForCancelRequest(
      orderId: _currentOrder.id!,
      order: _currentOrder,
    );
  }

  Future<void> _persistContactTimerStarted() async {
    final int? oid = _oid;
    if (oid == null) return;
    final SharedPreferences p = await SharedPreferences.getInstance();
    await p.setBool('$_prefPrefixStarted$oid', true);
    await p.setInt('$_prefPrefixStartMs$oid', _countdownStartMs!);
    await p.setInt('$_prefPrefixEndMs$oid', _countdownDeadlineMs!);
  }

  void _chatWithCustomer() {
    final int? oid = _currentOrder.id;
    final bool useTootliDirectChat =
        oid != null &&
        (_currentOrder.tootliDirectTrackable == true ||
            _currentOrder.hasTootliDirectPublicTrackingUrl);
    if (useTootliDirectChat) {
      Get.toNamed(RouteHelper.getTootliDirectTrackingChatRoute(oid));
      return;
    }
    if (_currentOrder.customer != null) {
      Get.toNamed(
        RouteHelper.getChatRoute(
          notificationBody: NotificationBodyModel(
            orderId: _currentOrder.id,
            customerId: _currentOrder.customer!.id,
          ),
          user: User(
            id: _currentOrder.customer!.id,
            fName: _currentOrder.customer!.fName,
            lName: _currentOrder.customer!.lName,
            imageFullUrl: _currentOrder.customer!.imageFullUrl,
            phone: _currentOrder.customer!.phone,
          ),
        ),
      );
      return;
    }
    if (_currentOrder.isGuest == true) {
      showCustomSnackBar(
        'Chat para invitados solo disponible en web'.tr,
        isError: false,
      );
      return;
    }
    final int? fallbackCustomerId =
        _currentOrder.userId ?? _currentOrder.deliveryAddress?.userId;
    if (fallbackCustomerId != null) {
      final addr = _currentOrder.deliveryAddress;
      Get.toNamed(
        RouteHelper.getChatRoute(
          notificationBody: NotificationBodyModel(
            orderId: _currentOrder.id,
            customerId: fallbackCustomerId,
          ),
          user: User(
            id: fallbackCustomerId,
            fName: 'Cliente',
            lName: '',
            imageFullUrl: '',
            phone: addr?.contactPersonNumber,
          ),
        ),
      );
      return;
    }
    showCustomSnackBar('Cliente no encontrado'.tr, isError: true);
  }

  void _chatWithStore() {
    Get.toNamed(
      RouteHelper.getChatRoute(
        notificationBody: NotificationBodyModel(
          orderId: _currentOrder.id,
          vendorId: _currentOrder.storeId,
        ),
        user: User(
          id: _currentOrder.storeId,
          fName: _currentOrder.storeName,
          imageFullUrl: _currentOrder.storeLogoFullUrl,
          phone: _currentOrder.storePhone,
        ),
      ),
    );
  }

  void _callStore() async {
    String? phone = _currentOrder.storePhone;
    if (phone != null && phone.isNotEmpty) {
      if (await canLaunchUrlString('tel:$phone')) {
        await launchUrlString(
          'tel:$phone',
          mode: LaunchMode.externalApplication,
        );
      }
    }
  }

  Future<void> _checkProximityAndProceed({
    required double targetLat,
    required double targetLng,
    required double maxDistance,
    required Function() onSuccess,
    required String errorMessage,
  }) async {
    if (_isCheckingProximity) return;
    _isCheckingProximity = true;
    try {
      if (kDisableDeliveryProximityCheckForQa || targetLat == 0) {
        onSuccess();
        return;
      }
      Position p = await Geolocator.getCurrentPosition();
      double d = Geolocator.distanceBetween(
        p.latitude,
        p.longitude,
        targetLat,
        targetLng,
      );
      if (d <= maxDistance)
        onSuccess();
      else
        showCustomSnackBar(
          '$errorMessage Estás a ${d.toInt()}m.',
          isError: true,
        );
    } catch (_) {
      onSuccess();
    } finally {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _isCheckingProximity = false);
      });
    }
  }

  Widget _buildCustomerContactTimerCard(BuildContext context) {
    final bool callsOk = _customerTelLaunchCount >= 3;
    final bool locOk = _within100mOfCustomer;
    final int? sec = _customerContactSecondsRemaining;
    final bool finished =
        sec != null && sec <= 0 && _customerContactCountdownStarted;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFFF39C12).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.timer_outlined,
                color: Color(0xFFF39C12),
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                'Protocolo de Espera',
                style: robotoMedium.copyWith(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _timerRequirementRow(
            context,
            done: callsOk,
            label: 'Llamadas confirmadas: $_customerTelLaunchCount / 3',
          ),
          const SizedBox(height: 8),
          _timerRequirementRow(
            context,
            done: locOk,
            label: locOk
                ? 'En zona de entrega'
                : 'Debes estar a < 100m del cliente',
          ),
          const SizedBox(height: 15),
          if (!_customerContactCountdownStarted)
            Text(
              'El temporizador iniciará al cumplir los requisitos.',
              style: robotoRegular.copyWith(
                color: Colors.white38,
                fontSize: 12,
              ),
            )
          else if (finished)
            Text(
              'Tiempo agotado. Puedes contactar a soporte.',
              style: robotoBold.copyWith(
                color: const Color(0xFF2ECC71),
                fontSize: 13,
              ),
            )
          else
            Row(
              children: [
                Text(
                  'Tiempo restante: ',
                  style: robotoRegular.copyWith(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                Text(
                  _formatMmSs(sec ?? 0),
                  style: robotoBold.copyWith(
                    color: const Color(0xFFF39C12),
                    fontSize: 20,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _timerRequirementRow(
    BuildContext context, {
    required bool done,
    required String label,
  }) {
    return Row(
      children: [
        Icon(
          done ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 16,
          color: done ? const Color(0xFF2ECC71) : Colors.white24,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: robotoRegular.copyWith(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  String _formatMmSs(int seconds) {
    final int m = seconds ~/ 60;
    final int s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
