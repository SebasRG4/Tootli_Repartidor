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

class AcceptedOrderWidget extends StatefulWidget {
  final OrderModel orderModel;
  final String phase;
  final Function onPickedUp;
  final Function onDelivered;
  final String? estimatedArrivalTime;
  const AcceptedOrderWidget({
    super.key,
    required this.orderModel,
    required this.phase,
    required this.onPickedUp,
    required this.onDelivered,
    this.estimatedArrivalTime,
  });

  @override
  State<AcceptedOrderWidget> createState() => _AcceptedOrderWidgetState();
}

class _AcceptedOrderWidgetState extends State<AcceptedOrderWidget> {
  double _sliderValue = 0.0;

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

  void _callPerson() async {
    String? phone = widget.phase == 'going_to_store'
        ? widget.orderModel.storePhone
        : widget.orderModel.deliveryAddress?.contactPersonNumber;

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
              'Comunícate con nuestro equipo',
              Icons.headset_mic,
              Colors.blue,
              () {
                String? phone = Get.find<SplashController>().configModel?.phone;
                if (phone != null && phone.isNotEmpty) {
                  launchUrlString(
                    'tel:$phone',
                    mode: LaunchMode.externalApplication,
                  );
                } else {
                  showCustomSnackBar('Número de soporte no configurado');
                }
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
                  widget.phase == 'going_to_store'
                      ? Icons.restaurant
                      : Icons.person_pin_circle,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: _showSupportBottomSheet,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.emergency, color: Colors.red),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Store Info Card
          Container(
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
                        (widget.phase == 'going_to_store'
                                ? widget.orderModel.storeName
                                : widget.orderModel.deliveryAddress?.address) ??
                            '',
                        style: robotoMedium.copyWith(fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        (widget.phase == 'going_to_store'
                                ? widget.orderModel.storeAddress
                                : '${widget.orderModel.customer?.fName} ${widget.orderModel.customer?.lName}') ??
                            '',
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
                  onPressed: _callPerson,
                  icon: const Icon(Icons.call, color: Colors.green),
                ),
              ],
            ),
          ),

          if (widget.phase == 'going_to_store')
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
                          onTap: () => orderController.pickPrescriptionImage(
                            isRemove: false,
                            isCamera: true,
                          ),
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
                          widget.onPickedUp();
                        } else {
                          widget.onDelivered();
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
}
