import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
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

/// QA: `true` omite la validación de proximidad (100 m tienda / 500 m cliente).
/// El API `update-order-status` no comprueba distancia; esto es solo cliente.
/// Poner en `false` antes de producción.
const bool kDisableDeliveryProximityCheckForQa = true;

/// Distancia máxima (m) al punto de entrega para iniciar el temporizador de contacto.
const double _kCustomerContactTimerProximityM = 100;

/// Llamadas al cliente (desde el botón de la app) requeridas antes de iniciar el temporizador.
const int _kCustomerContactMinCalls = 3;

/// Duración del temporizador una vez iniciado (después de proximidad + llamadas).
const int _kCustomerContactCountdownSeconds = 600;

class AcceptedOrderWidget extends StatefulWidget {
  final OrderModel orderModel;
  final String phase;
  final Function onHandover;
  final Function onPickedUp;
  final Function onDelivered;
  final String? estimatedArrivalTime;
  const AcceptedOrderWidget({
    super.key,
    required this.orderModel,
    required this.phase,
    required this.onHandover,
    required this.onPickedUp,
    required this.onDelivered,
    this.estimatedArrivalTime,
  });

  @override
  State<AcceptedOrderWidget> createState() => _AcceptedOrderWidgetState();
}

class _AcceptedOrderWidgetState extends State<AcceptedOrderWidget> {
  double _sliderValue = 0.0;
  bool _isCheckingProximity = false;

  Timer? _customerProximityPollTimer;
  Timer? _customerContactCountdownTimer;
  bool _within100mOfCustomer = false;
  int _customerTelLaunchCount = 0;
  bool _customerContactCountdownStarted = false;
  int? _customerContactSecondsRemaining;

  @override
  void initState() {
    super.initState();
    if (widget.phase == 'going_to_customer') {
      _startCustomerContactMonitoring();
    }
  }

  @override
  void dispose() {
    _stopAndResetCustomerContactTimer();
    super.dispose();
  }

  @override
  void didUpdateWidget(AcceptedOrderWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final idChanged = oldWidget.orderModel.id != widget.orderModel.id;
    final wasCustomer = oldWidget.phase == 'going_to_customer';
    final isCustomer = widget.phase == 'going_to_customer';

    if (idChanged || (wasCustomer && !isCustomer)) {
      _stopAndResetCustomerContactTimer();
    }
    if (isCustomer && (!wasCustomer || idChanged)) {
      _startCustomerContactMonitoring();
    }
  }

  void _stopAndResetCustomerContactTimer() {
    _customerProximityPollTimer?.cancel();
    _customerProximityPollTimer = null;
    _customerContactCountdownTimer?.cancel();
    _customerContactCountdownTimer = null;
    _within100mOfCustomer = false;
    _customerTelLaunchCount = 0;
    _customerContactCountdownStarted = false;
    _customerContactSecondsRemaining = null;
  }

  void _startCustomerContactMonitoring() {
    if (widget.phase != 'going_to_customer') return;
    _customerProximityPollTimer?.cancel();
    _customerProximityPollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _pollCustomerProximityForContactTimer(),
    );
    unawaited(_pollCustomerProximityForContactTimer());
  }

  Future<void> _pollCustomerProximityForContactTimer() async {
    if (!mounted || widget.phase != 'going_to_customer') return;

    if (kDisableDeliveryProximityCheckForQa) {
      if (!_within100mOfCustomer) {
        setState(() => _within100mOfCustomer = true);
      }
      _tryStartCustomerContactCountdown();
      return;
    }

    final double lat =
        double.tryParse(widget.orderModel.deliveryAddress?.latitude ?? '') ??
            0;
    final double lng =
        double.tryParse(widget.orderModel.deliveryAddress?.longitude ?? '') ??
            0;
    if (lat == 0 && lng == 0) return;

    try {
      final Position p = await Geolocator.getCurrentPosition();
      final double d = Geolocator.distanceBetween(
        p.latitude,
        p.longitude,
        lat,
        lng,
      );
      final bool within = d <= _kCustomerContactTimerProximityM;
      if (within != _within100mOfCustomer) {
        setState(() => _within100mOfCustomer = within);
      }
      _tryStartCustomerContactCountdown();
    } catch (_) {}
  }

  void _tryStartCustomerContactCountdown() {
    if (!mounted ||
        _customerContactCountdownStarted ||
        widget.phase != 'going_to_customer') {
      return;
    }
    if (!_within100mOfCustomer || _customerTelLaunchCount < _kCustomerContactMinCalls) {
      return;
    }
    _customerContactCountdownStarted = true;
    _customerProximityPollTimer?.cancel();
    _customerProximityPollTimer = null;
    setState(() {
      _customerContactSecondsRemaining = _kCustomerContactCountdownSeconds;
    });
    _customerContactCountdownTimer?.cancel();
    _customerContactCountdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final int? prev = _customerContactSecondsRemaining;
      if (prev == null || prev <= 0) {
        t.cancel();
        return;
      }
      final int next = prev - 1;
      setState(() => _customerContactSecondsRemaining = next);
      if (next <= 0) {
        t.cancel();
      }
    });
  }

  String _formatMmSs(int seconds) {
    final int m = seconds ~/ 60;
    final int s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Widget _buildCustomerContactTimerCard(BuildContext context) {
    final int calls = _customerTelLaunchCount.clamp(0, 999);
    final bool callsOk = calls >= _kCustomerContactMinCalls;
    final bool locOk = _within100mOfCustomer;
    final int? sec = _customerContactSecondsRemaining;
    final bool finished = sec != null && sec <= 0 && _customerContactCountdownStarted;

    return Container(
      margin: const EdgeInsets.only(top: Dimensions.paddingSizeDefault),
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        border: Border.all(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.contact_phone_outlined, color: Theme.of(context).primaryColor, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'dm_customer_contact_timer_title'.tr,
                  style: robotoMedium.copyWith(fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _timerRequirementRow(
            context,
            done: callsOk,
            label:
                '${'dm_customer_contact_calls_label'.tr} $calls / $_kCustomerContactMinCalls',
          ),
          const SizedBox(height: 6),
          _timerRequirementRow(
            context,
            done: locOk,
            label: locOk
                ? 'dm_customer_contact_within_100'.tr
                : 'dm_customer_contact_not_within_100'.tr,
          ),
          const SizedBox(height: 12),
          if (!_customerContactCountdownStarted)
            Text(
              'dm_customer_contact_timer_waiting'.tr,
              style: robotoRegular.copyWith(
                fontSize: 12,
                color: Theme.of(context).hintColor,
              ),
            )
          else if (finished)
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade700, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'dm_customer_contact_timer_done'.tr,
                    style: robotoMedium.copyWith(
                      fontSize: 13,
                      color: Colors.green.shade800,
                    ),
                  ),
                ),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'dm_customer_contact_timer_running'.tr,
                  style: robotoRegular.copyWith(fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatMmSs(sec ?? 0),
                  style: robotoBold.copyWith(
                    fontSize: 28,
                    color: Theme.of(context).primaryColor,
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          done ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 18,
          color: done ? Colors.green.shade700 : Theme.of(context).hintColor,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: robotoRegular.copyWith(fontSize: 12))),
      ],
    );
  }

  void _showNavigationOptions() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Selecciona tu app de navegación',
              style: robotoBold.copyWith(fontSize: 18),
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
            const SizedBox(height: 10),
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
          Text(name, style: robotoMedium),
        ],
      ),
    );
  }

  void _launchNavigation(String app) async {
    String lat = '';
    String lng = '';

    if (widget.phase == 'going_to_store') {
      lat = widget.orderModel.storeLat ?? '0';
      lng = widget.orderModel.storeLng ?? '0';
    } else {
      lat = widget.orderModel.deliveryAddress?.latitude ?? '0';
      lng = widget.orderModel.deliveryAddress?.longitude ?? '0';
    }

    String url = '';
    if (app == 'google') {
      url =
          'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&mode=d';
    } else {
      url = 'https://waze.com/ul?ll=$lat,$lng&navigate=yes';
    }

    if (await canLaunchUrlString(url)) {
      await launchUrlString(url, mode: LaunchMode.externalApplication);
    } else {
      showCustomSnackBar('Could not launch navigation app');
    }
  }

  void _callStore() async {
    String? phone = widget.orderModel.storePhone;
    if (phone != null && phone.isNotEmpty) {
      if (await canLaunchUrlString('tel:$phone')) {
        await launchUrlString(
          'tel:$phone',
          mode: LaunchMode.externalApplication,
        );
      } else {
        showCustomSnackBar('Could not launch dialer');
      }
    } else {
      showCustomSnackBar('Phone number not found');
    }
  }

  void _callCustomer() async {
    String? phone = widget.orderModel.deliveryAddress?.contactPersonNumber ?? widget.orderModel.customer?.phone;
    if (phone != null && phone.isNotEmpty) {
      if (await canLaunchUrlString('tel:$phone')) {
        await launchUrlString(
          'tel:$phone',
          mode: LaunchMode.externalApplication,
        );
        if (mounted && widget.phase == 'going_to_customer') {
          setState(() => _customerTelLaunchCount++);
          _tryStartCustomerContactCountdown();
        }
      } else {
        showCustomSnackBar('Could not launch dialer');
      }
    } else {
      showCustomSnackBar('Phone number not found');
    }
  }

  void _chatWithStore() {
    Get.toNamed(
      RouteHelper.getChatRoute(
        notificationBody: NotificationBodyModel(
          orderId: widget.orderModel.id,
          vendorId: widget.orderModel.storeId,
        ),
        user: User(
          id: widget.orderModel.storeId,
          fName: widget.orderModel.storeName,
          imageFullUrl: widget.orderModel.storeLogoFullUrl,
          phone: widget.orderModel.storePhone,
        ),
      ),
    );
  }

  void _chatWithCustomer() {
    final int? oid = widget.orderModel.id;
    final bool useTootliDirectChat =
        oid != null &&
        (widget.orderModel.tootliDirectTrackable == true ||
            widget.orderModel.hasTootliDirectPublicTrackingUrl);
    if (useTootliDirectChat) {
      Get.toNamed(RouteHelper.getTootliDirectTrackingChatRoute(oid!));
      return;
    }
    if (widget.orderModel.customer != null) {
      Get.toNamed(
        RouteHelper.getChatRoute(
          notificationBody: NotificationBodyModel(
            orderId: widget.orderModel.id,
            customerId: widget.orderModel.customer!.id,
          ),
          user: User(
            id: widget.orderModel.customer!.id,
            fName: widget.orderModel.customer!.fName,
            lName: widget.orderModel.customer!.lName,
            imageFullUrl: widget.orderModel.customer!.imageFullUrl,
            phone: widget.orderModel.customer!.phone,
          ),
        ),
      );
      return;
    }
    if (widget.orderModel.isGuest == true) {
      showCustomSnackBar(
        'tootli_direct_guest_chat_web_only'.tr,
        isError: false,
      );
      return;
    }
    final int? fallbackCustomerId =
        widget.orderModel.userId ?? widget.orderModel.deliveryAddress?.userId;
    if (fallbackCustomerId != null) {
      final addr = widget.orderModel.deliveryAddress;
      final String rawName = (addr?.contactPersonName ?? '').trim();
      String fName = 'Cliente';
      String lName = '';
      if (rawName.isNotEmpty) {
        final List<String> parts = rawName.split(RegExp(r'\s+'));
        fName = parts.first;
        if (parts.length > 1) {
          lName = parts.sublist(1).join(' ');
        }
      }
      Get.toNamed(
        RouteHelper.getChatRoute(
          notificationBody: NotificationBodyModel(
            orderId: widget.orderModel.id,
            customerId: fallbackCustomerId,
          ),
          user: User(
            id: fallbackCustomerId,
            fName: fName,
            lName: lName,
            imageFullUrl: '',
            phone: addr?.contactPersonNumber,
          ),
        ),
      );
      return;
    }
    showCustomSnackBar('customer_not_found'.tr, isError: true);
  }

  void _showSupportBottomSheet() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).disabledColor.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 15),
            Text('Centro de Soporte', style: robotoBold.copyWith(fontSize: 18)),
            const SizedBox(height: 25),
            _buildSupportOption(
              'Soporte Tootli',
              'Comunícate con nuestro equipo por chat',
              Icons.chat,
              Colors.blue,
              () {
                Get.toNamed(
                  RouteHelper.getChatRoute(
                    notificationBody: NotificationBodyModel(
                      type: AppConstants.admin,
                      orderId: widget.orderModel.id,
                    ),
                    user: User(
                       id: 0,
                       fName: 'Soporte',
                       lName: 'Tootli',
                       imageFullUrl: '',
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 15),
            _buildSupportOption(
              'Emergencia (911)',
              'Solo para casos de gravedad',
              Icons.emergency_share,
              Colors.red,
              () => launchUrlString(
                'tel:911',
                mode: LaunchMode.externalApplication,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportOption(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    Function onTap,
  ) {
    return InkWell(
      onTap: () {
        Get.back();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: robotoBold.copyWith(fontSize: 16, color: color),
                  ),
                  Text(
                    subtitle,
                    style: robotoRegular.copyWith(
                      fontSize: 12,
                      color: Theme.of(context).disabledColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Theme.of(context).disabledColor,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 5,
          ),
        ],
      ),
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Order ID and Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pedido #${widget.orderModel.id}',
                    style: robotoBold.copyWith(fontSize: 24),
                  ),
                  Text(
                    widget.phase == 'going_to_store'
                        ? 'En camino al restaurante'
                        : widget.phase == 'at_store'
                            ? 'Preparando entrega'
                            : 'En camino al cliente',
                    style: robotoRegular.copyWith(
                      color: Theme.of(context).primaryColor,
                      fontSize: 14,
                    ),
                  ),
                  if (widget.estimatedArrivalTime != null)
                    Text(
                      'Llega antes de ${widget.estimatedArrivalTime}',
                      style: robotoMedium.copyWith(
                        color: Colors.orange,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  (widget.phase == 'going_to_store' || widget.phase == 'at_store')
                      ? Icons.restaurant
                      : Icons.person_pin_circle,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              InkWell(
                onTap: _showSupportBottomSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    'SOS',
                    style: robotoBold.copyWith(
                      color: Colors.white,
                      fontSize: 11,
                      height: 1,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          if (widget.phase == 'going_to_store' || widget.phase == 'at_store')
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
              decoration: BoxDecoration(
                color: Theme.of(context).secondaryHeaderColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.orderModel.storeName ?? '',
                          style: robotoMedium.copyWith(fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          widget.orderModel.storeAddress ?? '',
                          style: robotoRegular.copyWith(
                            fontSize: 12,
                            color: Theme.of(context).disabledColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _showNavigationOptions,
                    icon: const Icon(Icons.navigation, color: Colors.blue),
                  ),
                  IconButton(
                    onPressed: _chatWithStore,
                    icon: const Icon(Icons.message, color: Colors.orange),
                  ),
                  IconButton(
                    onPressed: _callStore,
                    icon: const Icon(Icons.call, color: Colors.green),
                  ),
                ],
              ),
            ),

          // Customer Info Card (Always Visible)
          Container(
            padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 5,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.orderModel.customer?.fName ?? ''} ${widget.orderModel.customer?.lName ?? ''}',
                        style: robotoBold.copyWith(
                          fontSize: 18,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        widget.orderModel.deliveryAddress?.address ?? 'Dirección de entrega',
                        style: robotoMedium.copyWith(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (widget.phase != 'going_to_store' && widget.phase != 'at_store')
                  IconButton(
                    onPressed: _showNavigationOptions,
                    icon: const Icon(Icons.navigation, color: Colors.white),
                  ),
                IconButton(
                  onPressed: _chatWithCustomer,
                  icon: const Icon(Icons.message, color: Colors.white),
                ),
                IconButton(
                  onPressed: _callCustomer,
                  icon: const Icon(Icons.call, color: Colors.white),
                ),
              ],
            ),
          ),

          if (widget.phase == 'going_to_store' || widget.phase == 'at_store')
            GetBuilder<OrderController>(
              builder: (orderController) {
                return orderController.orderDetailsModel != null &&
                        orderController.orderDetailsModel!.isNotEmpty
                    ? Container(
                        margin: const EdgeInsets.only(top: 15),
                        padding: const EdgeInsets.all(
                          Dimensions.paddingSizeSmall,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).primaryColor.withOpacity(0.2),
                          ),
                          borderRadius: BorderRadius.circular(
                            Dimensions.radiusDefault,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Productos a recoger:',
                              style: robotoMedium.copyWith(
                                fontSize: 12,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                            const SizedBox(height: 5),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount:
                                  orderController.orderDetailsModel!.length,
                              itemBuilder: (context, index) {
                                var detail =
                                    orderController.orderDetailsModel![index];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2,
                                  ),
                                  child: Text(
                                    '${detail.quantity} x ${detail.itemDetails?.name ?? 'Producto'}',
                                    style: robotoRegular.copyWith(fontSize: 13),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      )
                    : const SizedBox(
                        height: 40,
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
              },
            ),

          if (widget.phase == 'going_to_customer')
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildCustomerContactTimerCard(context),
                GetBuilder<OrderController>(
                  builder: (orderController) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        Text(
                          'Prueba de entrega (Foto):',
                          style: robotoMedium.copyWith(fontSize: 14),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                        InkWell(
                          onTap: () => orderController.pickCameraDirectly(),
                          child: Container(
                            height: 60,
                            width: 60,
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(
                                Dimensions.radiusDefault,
                              ),
                              border: Border.all(
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                            child: Icon(
                              Icons.camera_alt,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 60,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount:
                                  orderController.pickedPrescriptions.length,
                              itemBuilder: (context, index) {
                                return Stack(
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.only(right: 10),
                                      height: 60,
                                      width: 60,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(
                                          Dimensions.radiusDefault,
                                        ),
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
                                      top: 0,
                                      right: 10,
                                      child: InkWell(
                                        onTap: () => orderController
                                            .pickPrescriptionImage(
                                              isRemove: true,
                                              isCamera:
                                                  false, // Not used when isRemove is true
                                            ),
                                        child: Container(
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            size: 16,
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
                        false)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          Text(
                            'Código de verificación (OTP):',
                            style: robotoMedium.copyWith(fontSize: 14),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            onChanged: (value) => orderController.setOtp(value),
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: 'Ingrese el código del cliente',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  Dimensions.radiusDefault,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                      ],
                    );
                  },
                ),
              ],
            ),

          const SizedBox(height: 30),

          // Action Slider
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 60,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Center(
                  child: Text(
                    widget.phase == 'going_to_store'
                        ? 'Pedido recogido'.tr
                        : widget.phase == 'at_store'
                            ? 'on_the_way'.tr
                            : 'Entregar pedido'.tr,
                    style: robotoBold.copyWith(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 60,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 30,
                    ),
                    overlayShape: SliderComponentShape.noOverlay,
                    activeTrackColor: Colors.transparent,
                    inactiveTrackColor: Colors.transparent,
                    thumbColor: Colors.white.withOpacity(0.2),
                  ),
                  child: Slider(
                    value: _sliderValue,
                    onChanged: (value) {
                      setState(() {
                        _sliderValue = value;
                      });
                      if (value > 0.9) {
                        if (widget.phase == 'going_to_store') {
                          _checkProximityAndProceed(
                            targetLat: double.tryParse(widget.orderModel.storeLat ?? '') ?? 0,
                            targetLng: double.tryParse(widget.orderModel.storeLng ?? '') ?? 0,
                            maxDistance: 100,
                            onSuccess: () => widget.onHandover(),
                            errorMessage: 'Debes estar a menos de 100m del restaurante para recoger el pedido.',
                          );
                        } else if (widget.phase == 'at_store') {
                          widget.onPickedUp();
                        } else {
                          _checkProximityAndProceed(
                            targetLat: double.tryParse(widget.orderModel.deliveryAddress?.latitude ?? '') ?? 0,
                            targetLng: double.tryParse(widget.orderModel.deliveryAddress?.longitude ?? '') ?? 0,
                            maxDistance: 500,
                            onSuccess: () => widget.onDelivered(),
                            errorMessage: 'Debes estar a menos de 500m del cliente para entregar el pedido.',
                          );
                        }
                        setState(() {
                          _sliderValue = 0.0;
                        });
                      }
                    },
                    onChangeEnd: (value) {
                      if (value <= 0.9) {
                        setState(() {
                          _sliderValue = 0.0;
                        });
                      }
                    },
                  ),
                ),
              ),
              Positioned(
                left:
                    10 +
                    (_sliderValue * (MediaQuery.of(context).size.width - 100)),
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
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
      if (kDisableDeliveryProximityCheckForQa) {
        onSuccess();
        return;
      }

      Position currentPosition = await Geolocator.getCurrentPosition();

      if (targetLat == 0 || targetLng == 0) {
        onSuccess();
        return;
      }

      double distance = Geolocator.distanceBetween(
        currentPosition.latitude,
        currentPosition.longitude,
        targetLat,
        targetLng,
      );

      if (distance <= maxDistance) {
        onSuccess();
      } else {
        showCustomSnackBar(
          '$errorMessage Estás a ${distance.toInt()}m.',
          isError: true,
        );
      }
    } catch (e) {
      onSuccess();
    } finally {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _isCheckingProximity = false;
          });
        }
      });
    }
  }
}
