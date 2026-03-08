import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:sixam_mart_delivery/features/order/domain/models/order_model.dart';
import 'package:sixam_mart_delivery/util/styles.dart';

import 'package:sixam_mart_delivery/helper/price_converter_helper.dart';

class PremiumOrderRequestWidget extends StatefulWidget {
  final OrderModel orderModel;
  final double? distance;
  final Function onAccept;
  final Function onReject;
  const PremiumOrderRequestWidget({
    super.key,
    required this.orderModel,
    this.distance,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<PremiumOrderRequestWidget> createState() =>
      _PremiumOrderRequestWidgetState();
}

class _PremiumOrderRequestWidgetState extends State<PremiumOrderRequestWidget> {
  double _sliderValue = 0.0;
  int _secondsRemaining = 30;
  Timer? _timer;
  AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _startTimer();
    _playNotificationSound();
  }

  void _playNotificationSound() {
    _audioPlayer.play(AssetSource('alert_new_delivery.mp3'));
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
        // Reproducir sonido cada 3 segundos
        if (_secondsRemaining % 3 == 0 && _secondsRemaining > 0) {
          _playNotificationSound();
        }
      } else {
        _timer?.cancel();
        _audioPlayer.stop();
        widget.onReject();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header descriptive (dark)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: const BoxDecoration(
              color: Color(0xFF2C2E3A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Text(
              'Recibir pedidos nuevos: Los pedidos nuevos que no se acepten a tiempo se rechazarán automáticamente...'
                  .tr,
              style: robotoRegular.copyWith(color: Colors.white, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(25),
            child: Column(
              children: [
                // Total Earnings
                Text(
                  PriceConverterHelper.convertPrice(
                    (widget.orderModel.originalDeliveryCharge ?? 0) +
                        (widget.orderModel.dmTips ?? 0),
                  ),
                  style: robotoBold.copyWith(
                    fontSize: 40,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                Text(
                  '${'ganancia_neta'.tr}: ${PriceConverterHelper.convertPrice(widget.orderModel.originalDeliveryCharge ?? 0)} + ${'propina'.tr}: ${PriceConverterHelper.convertPrice(widget.orderModel.dmTips ?? 0)}',
                  style: robotoRegular.copyWith(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),

                const SizedBox(height: 15),

                // Distance and Store
                Text(
                  widget.distance != null
                      ? '${widget.distance!.toStringAsFixed(2)} km'
                      : '... km',
                  style: robotoBold.copyWith(fontSize: 30),
                ),
                Text(
                  widget.orderModel.storeName ?? 'Tienda',
                  style: robotoMedium.copyWith(
                    fontSize: 18,
                    color: Colors.grey,
                  ),
                ),

                const SizedBox(height: 20),

                // Payment info
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.payments, color: Colors.green[600], size: 24),
                    const SizedBox(width: 10),
                    Text(
                      widget.orderModel.paymentMethod == 'cash_on_delivery'
                          ? 'Pago en efectivo'.tr
                          : 'Pago con tarjeta'.tr,
                      style: robotoMedium.copyWith(fontSize: 16),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                // Accept Slider
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: 65,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Aceptar pedido'.tr,
                              style: robotoBold.copyWith(
                                color: Colors.white,
                                fontSize: 22,
                              ),
                            ),
                            const SizedBox(width: 40),
                            Text(
                              '${_secondsRemaining}s',
                              style: robotoMedium.copyWith(
                                color: Colors.white,
                                fontSize: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 65,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 30,
                          ),
                          overlayShape: SliderComponentShape.noOverlay,
                          activeTrackColor: Colors.transparent,
                          inactiveTrackColor: Colors.transparent,
                          thumbColor: Colors.white.withValues(alpha: 0.2),
                        ),
                        child: Slider(
                          value: _sliderValue,
                          onChanged: (value) {
                            setState(() {
                              _sliderValue = value;
                            });
                            if (value > 0.9) {
                              _timer?.cancel();
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
                    // Visual arrow icon for the slider
                    Positioned(
                      left:
                          10 +
                          (_sliderValue *
                              (MediaQuery.of(context).size.width - 100)),
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.double_arrow,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
