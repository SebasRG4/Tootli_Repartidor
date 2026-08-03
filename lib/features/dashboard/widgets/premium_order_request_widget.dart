import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sixam_mart_delivery/features/order/controllers/order_controller.dart';
import 'package:sixam_mart_delivery/features/order/domain/models/order_model.dart';
import 'package:sixam_mart_delivery/util/styles.dart';
import 'package:sixam_mart_delivery/helper/order_notification_service.dart';
import 'package:sixam_mart_delivery/helper/price_converter_helper.dart';

class PremiumOrderRequestWidget extends StatefulWidget {
  final OrderModel orderModel;
  final double? distance;
  final Function onAccept;
  final Function onReject;
  final bool isTaken;

  const PremiumOrderRequestWidget({
    super.key,
    required this.orderModel,
    this.distance,
    required this.onAccept,
    required this.onReject,
    this.isTaken = false,
  });

  @override
  State<PremiumOrderRequestWidget> createState() =>
      _PremiumOrderRequestWidgetState();
}

class _PremiumOrderRequestWidgetState
    extends State<PremiumOrderRequestWidget> {
  double _sliderValue = 0.0;
  int _secondsRemaining = 30;
  Timer? _timer;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isAccepted = false;
  bool _isRejected = false;
  bool _isMounted = false;

  @override
  void initState() {
    super.initState();
    _isMounted = true;
    _startTimer();
  }

  @override
  void didUpdateWidget(PremiumOrderRequestWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderModel != widget.orderModel ||
        oldWidget.distance != widget.distance ||
        oldWidget.isTaken != widget.isTaken) {
      if (_isMounted) setState(() {});
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isMounted) {
        timer.cancel();
        return;
      }

      if (_secondsRemaining > 0) {
        if (_isMounted) {
          setState(() {
            _secondsRemaining--;
          });
        }
      } else {
        timer.cancel();
        _audioPlayer.stop();
        if (_isMounted && !_isRejected && !_isAccepted) {
          _isRejected = true;
          OrderNotificationService.instance.stopAudio();
          debugPrint(
            '[PremiumOrderRequestWidget] ⏱️ Timer expirado — disparando onReject',
          );
          widget.onReject();
        }
      }
    });
  }

  @override
  void dispose() {
    _isMounted = false;
    _timer?.cancel();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatDistance(double? distInKm) {
    if (distInKm == null || distInKm <= 0) return '--';
    if (distInKm < 1.0) {
      int meters = (distInKm * 1000).round();
      return '$meters m';
    } else {
      return '${distInKm.toStringAsFixed(1)} km';
    }
  }

  double? _calculateTripDistance() {
    final bool isParcel =
        widget.orderModel.orderType == 'parcel' ||
        widget.orderModel.moduleType == 'taxi';
    double? oLat, oLng, dLat, dLng;

    if (isParcel) {
      oLat = double.tryParse(
        widget.orderModel.deliveryAddress?.latitude ?? '',
      );
      oLng = double.tryParse(
        widget.orderModel.deliveryAddress?.longitude ?? '',
      );
      dLat = double.tryParse(widget.orderModel.receiverDetails?.latitude ?? '');
      dLng = double.tryParse(
        widget.orderModel.receiverDetails?.longitude ?? '',
      );
    } else {
      oLat = double.tryParse(widget.orderModel.storeLat ?? '');
      oLng = double.tryParse(widget.orderModel.storeLng ?? '');
      dLat = double.tryParse(
        widget.orderModel.deliveryAddress?.latitude ?? '',
      );
      dLng = double.tryParse(
        widget.orderModel.deliveryAddress?.longitude ?? '',
      );
    }

    if (oLat != null &&
        oLat != 0 &&
        oLng != null &&
        oLng != 0 &&
        dLat != null &&
        dLat != 0 &&
        dLng != null &&
        dLng != 0) {
      return Geolocator.distanceBetween(oLat, oLng, dLat, dLng) / 1000;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bool isLoading =
        widget.orderModel.orderStatus == null &&
        widget.orderModel.createdAt == null;
    final bool isParcel =
        widget.orderModel.orderType == 'parcel' ||
        widget.orderModel.moduleType == 'taxi';

    final String originAddress = isParcel
        ? (widget.orderModel.deliveryAddress?.address ??
            widget.orderModel.storeAddress ??
            widget.orderModel.storeName ??
            'Origen no especificado'.tr)
        : (widget.orderModel.storeName ??
            widget.orderModel.storeAddress ??
            'Tienda'.tr);

    final String destinationAddress = isParcel
        ? (widget.orderModel.receiverDetails?.address ??
            widget.orderModel.deliveryAddress?.address ??
            'Destino no especificado'.tr)
        : (widget.orderModel.deliveryAddress?.address ??
            'Destino no especificado'.tr);

    final double? pickupDist = widget.distance;
    final double? tripDist = _calculateTripDistance();
    final double? totalDist =
        (pickupDist != null || tripDist != null)
            ? ((pickupDist ?? 0) + (tripDist ?? 0))
            : null;

    // Paleta de colores oscuros premium
    const Color cardBg = Color(0xFF0F1E22);
    const Color containerBg = Color(0xFF14262B);
    const Color innerBorderColor = Color(0xFF1E353B);
    const Color neonGreen = Color(0xFF00E676);
    const Color neonGreenBg = Color(0xFF0C3829);

    return Container(
      decoration: const BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          // Botón superior de cierre 'X' y barra decorativa
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () {
                    _timer?.cancel();
                    _audioPlayer.stop();
                    OrderNotificationService.instance.stopAudio();
                    widget.onReject();
                  },
                  child: Container(
                    height: 38,
                    width: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C2C30),
                      shape: BoxShape.circle,
                      border: Border.all(color: innerBorderColor),
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white70,
                      size: 20,
                    ),
                  ),
                ),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 38), // Balance simétrico
              ],
            ),
          ),

          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                // ── 1. Tarjeta Principal: Alta demanda, Ganancia y 3 Distancias ──────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: containerBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: innerBorderColor),
                  ),
                  child: Column(
                    children: [
                      // Badges de Alta Demanda y Temporizador
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: neonGreenBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: neonGreen.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.flash_on,
                                  color: neonGreen,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Alta demanda'.tr,
                                  style: robotoBold.copyWith(
                                    color: neonGreen,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3D141A),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.redAccent.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.access_time_filled,
                                  color: Color(0xFFFF5252),
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${_secondsRemaining}s',
                                  style: robotoBold.copyWith(
                                    color: const Color(0xFFFF5252),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Monto de Ganancia Total
                      if (isLoading)
                        const SizedBox(
                          height: 60,
                          child: Center(
                            child: CircularProgressIndicator(color: neonGreen),
                          ),
                        )
                      else ...[
                        GetBuilder<OrderController>(
                          builder: (orderController) {
                            double totalEarnings = orderController
                                .getTotalEarningsForOrder(widget.orderModel);
                            return Column(
                              children: [
                                Text(
                                  PriceConverterHelper.convertPrice(
                                    totalEarnings,
                                  ),
                                  style: robotoBold.copyWith(
                                    fontSize: 44,
                                    color: neonGreen,
                                    letterSpacing: -1,
                                  ),
                                ),
                                Text(
                                  'Ganancia total'.tr,
                                  style: robotoBold.copyWith(
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Incluye propina'.tr,
                                  style: robotoRegular.copyWith(
                                    fontSize: 12,
                                    color: Colors.white54,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],

                      const SizedBox(height: 16),
                      Divider(
                        color: Colors.white.withValues(alpha: 0.08),
                        height: 1,
                      ),
                      const SizedBox(height: 14),

                      // 3 Columnas de Distancia: A recoger | Viaje | Total
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          // Columna 1: A recoger
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Transform.rotate(
                                  angle: 0.7, // Rotar la flecha de navegación
                                  child: const Icon(
                                    Icons.navigation,
                                    color: neonGreen,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'A recoger'.tr,
                                      style: robotoRegular.copyWith(
                                        fontSize: 11,
                                        color: Colors.white54,
                                      ),
                                    ),
                                    Text(
                                      _formatDistance(pickupDist),
                                      style: robotoBold.copyWith(
                                        fontSize: 15,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          Container(
                            height: 24,
                            width: 1,
                            color: Colors.white.withValues(alpha: 0.1),
                          ),

                          // Columna 2: Viaje
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.alt_route,
                                  color: Colors.amber,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Viaje'.tr,
                                      style: robotoRegular.copyWith(
                                        fontSize: 11,
                                        color: Colors.white54,
                                      ),
                                    ),
                                    Text(
                                      _formatDistance(tripDist),
                                      style: robotoBold.copyWith(
                                        fontSize: 15,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          Container(
                            height: 24,
                            width: 1,
                            color: Colors.white.withValues(alpha: 0.1),
                          ),

                          // Columna 3: Total
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.flag_outlined,
                                  color: neonGreen,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Total'.tr,
                                      style: robotoRegular.copyWith(
                                        fontSize: 11,
                                        color: Colors.white54,
                                      ),
                                    ),
                                    Text(
                                      _formatDistance(totalDist),
                                      style: robotoBold.copyWith(
                                        fontSize: 15,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ── 2. Tarjeta de Ruta: RECOGER EN ➔ ENTREGAR EN ──────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: containerBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: innerBorderColor),
                  ),
                  child: Column(
                    children: [
                      // Recoger En
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Color(0xFF073828),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.gps_fixed,
                              color: neonGreen,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'RECOGER EN'.tr,
                                  style: robotoBold.copyWith(
                                    fontSize: 11,
                                    color: neonGreen,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  originAddress,
                                  style: robotoMedium.copyWith(
                                    fontSize: 14,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: Colors.white38,
                            size: 22,
                          ),
                        ],
                      ),

                      // Conector punteado vertical
                      Padding(
                        padding: const EdgeInsets.only(left: 18, top: 4, bottom: 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Column(
                            children: List.generate(
                              3,
                              (_) => Container(
                                margin: const EdgeInsets.symmetric(vertical: 1.5),
                                width: 2,
                                height: 3,
                                color: Colors.white24,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Entregar En
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Color(0xFF3D141A),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.location_on,
                              color: Color(0xFFFF5252),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ENTREGAR EN'.tr,
                                  style: robotoBold.copyWith(
                                    fontSize: 11,
                                    color: const Color(0xFFFF5252),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  destinationAddress,
                                  style: robotoMedium.copyWith(
                                    fontSize: 14,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: Colors.white38,
                            size: 22,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ── 3. Tarjeta de Método de Pago ─────────────────────────────
                Builder(
                  builder: (context) {
                    final String pm = widget.orderModel.paymentMethod ?? '';
                    String paymentText;
                    String badgeText;
                    IconData paymentIcon;

                    if (pm == 'cash_on_delivery') {
                      paymentText = 'Efectivo'.tr;
                      badgeText = 'Pago al entregar'.tr;
                      paymentIcon = Icons.payments;
                    } else if (pm == 'digital_payment') {
                      paymentText = 'Tarjeta'.tr;
                      badgeText = 'Pago digital'.tr;
                      paymentIcon = Icons.credit_card;
                    } else if (pm == 'wallet') {
                      paymentText = 'Saldo Tootli'.tr;
                      badgeText = 'Pago con Saldo'.tr;
                      paymentIcon = Icons.account_balance_wallet;
                    } else {
                      paymentText = pm.isNotEmpty
                          ? pm.replaceAll('_', ' ').capitalizeFirst!
                          : 'Digital'.tr;
                      badgeText = 'Pago en línea'.tr;
                      paymentIcon = Icons.payment;
                    }

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: containerBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: innerBorderColor),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF073828),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      paymentIcon,
                                      color: neonGreen,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Método de pago'.tr,
                                        style: robotoRegular.copyWith(
                                          fontSize: 11,
                                          color: Colors.white54,
                                        ),
                                      ),
                                      Text(
                                        paymentText,
                                        style: robotoBold.copyWith(
                                          fontSize: 15,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: neonGreenBg,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: neonGreen.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.account_balance_wallet_outlined,
                                      color: neonGreen,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      badgeText,
                                      style: robotoMedium.copyWith(
                                        color: neonGreen,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (pm == 'cash_on_delivery' &&
                              widget.orderModel.cashOnPickupAmount != null &&
                              widget.orderModel.cashOnPickupAmount! > 0) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade900.withValues(
                                  alpha: 0.2,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.amber.shade700,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    color: Colors.amber.shade400,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        children: [
                                          TextSpan(
                                            text: 'deberas_pagar_al_restaurante'.tr,
                                            style: robotoRegular.copyWith(
                                              color: Colors.white70,
                                              fontSize: 12,
                                            ),
                                          ),
                                          TextSpan(
                                            text:
                                                ' ${PriceConverterHelper.convertPrice(widget.orderModel.cashOnPickupAmount)} ',
                                            style: robotoBold.copyWith(
                                              color: Colors.amber.shade400,
                                              fontSize: 13,
                                            ),
                                          ),
                                          TextSpan(
                                            text:
                                                'en_efectivo_al_recoger_el_pedido'.tr,
                                            style: robotoRegular.copyWith(
                                              color: Colors.white70,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),

                // ── 4. Deslizador de Aceptación Verde Brillante ──────────────
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: 64,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: (isLoading || widget.isTaken)
                            ? Colors.grey.shade800
                            : const Color(0xFF00C853),
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              widget.isTaken
                                  ? 'Pedido tomado'.tr
                                  : 'Desliza para aceptar'.tr,
                              style: robotoBold.copyWith(
                                color: Colors.white,
                                fontSize: 18,
                                letterSpacing: 0.3,
                              ),
                            ),
                            if (!widget.isTaken) ...[
                              const SizedBox(width: 30),
                              Text(
                                '${_secondsRemaining}s',
                                style: robotoBold.copyWith(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (!isLoading)
                      Positioned.fill(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 64,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 30,
                            ),
                            overlayShape: SliderComponentShape.noOverlay,
                            activeTrackColor: Colors.transparent,
                            inactiveTrackColor: Colors.transparent,
                            thumbColor: Colors.white.withValues(alpha: 0.25),
                          ),
                          child: Slider(
                            value: _sliderValue,
                            onChanged: widget.isTaken
                                ? null
                                : (value) {
                                    setState(() {
                                      _sliderValue = value;
                                    });
                                    if (value > 0.9 &&
                                        !_isAccepted &&
                                        !_isRejected) {
                                      _isAccepted = true;
                                      _timer?.cancel();
                                      OrderNotificationService.instance
                                          .stopAudio();
                                      _audioPlayer.stop();
                                      widget.onAccept();
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
                    if (!isLoading)
                      Positioned(
                        left:
                            8 +
                            (_sliderValue *
                                (MediaQuery.of(context).size.width - 100)),
                        child: IgnorePointer(
                          child: Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00E676),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.keyboard_double_arrow_right,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                // Pie Informativo
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      color: neonGreen,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Acepta el viaje y comienza a ganar'.tr,
                      style: robotoRegular.copyWith(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
