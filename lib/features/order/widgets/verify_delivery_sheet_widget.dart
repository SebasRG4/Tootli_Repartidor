import 'dart:async';
import 'package:sixam_mart_delivery/features/notification/controllers/notification_controller.dart';
import 'package:sixam_mart_delivery/features/order/controllers/order_controller.dart';
import 'package:sixam_mart_delivery/features/order/domain/models/order_model.dart';
import 'package:sixam_mart_delivery/features/profile/controllers/profile_controller.dart';
import 'package:sixam_mart_delivery/helper/price_converter_helper.dart';
import 'package:sixam_mart_delivery/helper/route_helper.dart';
import 'package:sixam_mart_delivery/util/dimensions.dart';
import 'package:sixam_mart_delivery/util/images.dart';
import 'package:sixam_mart_delivery/util/styles.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_button_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:sixam_mart_delivery/features/order/widgets/bottom_view/delivery_confirmation_section.dart';

class VerifyDeliverySheetWidget extends StatefulWidget {
  final OrderModel currentOrderModel;
  final bool? verify;
  final bool? cod;
  final double? orderAmount;
  final bool isSenderPay;
  final bool? isParcel;
  final bool? isSetOtp;
  const VerifyDeliverySheetWidget({super.key, required this.currentOrderModel, required this.verify, required this.orderAmount,
    required this.cod, this.isSenderPay = false, this.isParcel = false, this.isSetOtp = true});

  @override
  State<VerifyDeliverySheetWidget> createState() => _VerifyDeliverySheetWidgetState();
}

class _VerifyDeliverySheetWidgetState extends State<VerifyDeliverySheetWidget> {

  Timer? _timer;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    if(widget.isSetOtp!) {
      Get.find<OrderController>().setOtp('');
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.find<OrderController>().pickPrescriptionImage(isRemove: true, isCamera: false);
    });
  }

  @override
  void dispose() {
    super.dispose();

    _timer?.cancel();
  }

  void _startTimer() {
    _seconds = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _seconds = _seconds - 1;
      if(_seconds == 0) {
        timer.cancel();
        _timer?.cancel();
      }
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDonation = widget.currentOrderModel.orderStatus == 'returned' &&
        ((widget.currentOrderModel.failedDeliveryAction?.toLowerCase() ?? '') == 'donation' ||
            widget.currentOrderModel.failedDeliveryAction?.toLowerCase() == 'donate');

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: Get.isDarkMode ? Colors.grey.shade900 : Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: GetBuilder<OrderController>(builder: (orderController) {
          return Padding(
            padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
            child: Column(mainAxisSize: MainAxisSize.min, children: [

              Container(
                height: 5, width: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
                  color: Theme.of(context).disabledColor.withValues(alpha: 0.5),
                ),
              ),

              widget.verify! ? Column(children: [
                const SizedBox(height: Dimensions.paddingSizeLarge),

                Text(
                  widget.currentOrderModel.orderStatus == 'returned'
                      ? (isDonation ? 'Confirmación de Donación' : 'Confirmación de Retorno')
                      : 'otp_verification'.tr,
                  style: robotoBold,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Dimensions.paddingSizeLarge),

                if (isDonation) ...[
                  Text(
                    'Por favor captura al menos una foto como evidencia de la donación para poder confirmar.',
                    style: robotoRegular.copyWith(color: Theme.of(context).disabledColor),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: Dimensions.paddingSizeLarge),
                  const DeliveryConfirmationSection(),
                  const SizedBox(height: Dimensions.paddingSizeLarge),
                ] else ...[
                  Text('enter_otp_number'.tr, style: robotoRegular.copyWith(color: Theme.of(context).disabledColor), textAlign: TextAlign.center),
                  const SizedBox(height: Dimensions.paddingSizeLarge),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(width: 48), // Equilibrar el ancho del botón en el lado derecho
                      SizedBox(
                        width: 180,
                        child: PinCodeTextField(
                          length: 4,
                          appContext: context,
                          keyboardType: TextInputType.number,
                          animationType: AnimationType.slide,
                          pinTheme: PinTheme(
                            shape: PinCodeFieldShape.underline,
                            fieldHeight: 30,
                            fieldWidth: 30,
                            borderWidth: 2,
                            borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                            selectedColor: Theme.of(context).primaryColor,
                            selectedFillColor: Get.isDarkMode ? Colors.grey.shade900 : Colors.white,
                            inactiveFillColor: Get.isDarkMode ? Colors.grey.shade900 : Theme.of(context).cardColor,
                            inactiveColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                            activeColor: Theme.of(context).primaryColor.withValues(alpha: 0.7),
                            activeFillColor: Get.isDarkMode ? Colors.grey.shade900 : Theme.of(context).cardColor,
                          ),
                          animationDuration: const Duration(milliseconds: 300),
                          backgroundColor: Colors.transparent,
                          enableActiveFill: true,
                          onChanged: (String text) => orderController.setOtp(text),
                          beforeTextPaste: (text) => true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.keyboard_hide_rounded, color: Theme.of(context).primaryColor, size: 28),
                        onPressed: () => FocusScope.of(context).unfocus(),
                        tooltip: 'Ocultar teclado',
                      ),
                    ],
                  ),
                  const SizedBox(height: Dimensions.paddingSizeSmall),

                  Text(
                    widget.currentOrderModel.orderStatus == 'returned'
                        ? 'Por favor pida al personal de la tienda el PIN de confirmación de retorno.'
                        : 'collect_otp_from_customer'.tr,
                    style: robotoRegular,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: Dimensions.paddingSizeLarge),
                ],

              ]) : Column(children: [
                const SizedBox(height: Dimensions.paddingSizeLarge),

                Image.asset(Images.deliveredSuccess, height: 100, width: 100),
                const SizedBox(height: Dimensions.paddingSizeSmall),

                Text(
                  widget.isSenderPay ? 'want_to_collect_order_amount'.tr : 'want_to_complete_the_order'.tr, textAlign: TextAlign.center,
                  style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeLarge),
                ),
                const SizedBox(height: Dimensions.paddingSizeLarge),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(
                    '${'order_amount'.tr}:', textAlign: TextAlign.center,
                    style: robotoBold.copyWith(fontSize: Dimensions.fontSizeLarge),
                  ),
                  const SizedBox(width: Dimensions.paddingSizeExtraSmall),
                  Text(
                    PriceConverterHelper.convertPrice(widget.orderAmount), textAlign: TextAlign.center,
                    style: robotoBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: Theme.of(context).primaryColor),
                  ),
                ]),

                const SizedBox(height: 40),
              ]),

             !orderController.isLoading ? CustomButtonWidget(
                buttonText: isDonation ? 'Confirmar Donación' : (widget.verify! ? 'submit'.tr : 'ok'.tr),
                radius: Dimensions.radiusDefault,
                margin: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
                onPressed: (isDonation ? orderController.pickedPrescriptions.isEmpty : (widget.verify! && orderController.otp.length != 4)) ? null : () {

                   if(widget.cod!){
                     if(widget.verify! && widget.isParcel!) {
                       Get.back(result: 'show_price_view');
                     } else {
                       Get.find<OrderController>().updateOrderStatus(widget.currentOrderModel, widget.currentOrderModel.orderStatus == 'handover' ? 'picked_up' : 'delivered', parcel: widget.isParcel, stopOtherDataCall: true);
                     }
                  } else{
                    Get.find<OrderController>().updateOrderStatus(widget.currentOrderModel, widget.currentOrderModel.orderStatus == 'handover' ? 'picked_up' : 'delivered', parcel: widget.isParcel).then((success) {
                      if(success) {
                        Get.find<ProfileController>().getProfile();
                        Get.find<OrderController>().getRunningOrders(orderController.offset);
                        if(!widget.isSenderPay) {
                          Get.offAllNamed(RouteHelper.getInitialRoute());
                        }
                      }
                    });
                  }

                },
              ) : const Center(child: CircularProgressIndicator()),

              (widget.verify! && widget.currentOrderModel.orderStatus != 'returned') ? Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(
                  'did_not_receive_user_notification'.tr,
                  style: robotoRegular.copyWith(color: Theme.of(context).hintColor, fontSize: Dimensions.fontSizeSmall),
                ),

                Get.find<NotificationController>().hideNotificationButton ? const SizedBox() : InkWell(
                  onTap: _seconds < 1 ? () {
                    Get.find<NotificationController>().sendDeliveredNotification(widget.currentOrderModel.id);
                    _startTimer();
                  } : null,
                  child: Text('${'resend_it'.tr}${_seconds > 0 ? ' (${_seconds}s)' : ''}', style: TextStyle(color: Theme.of(context).primaryColor),),
                )
              ]) : const SizedBox(),
              const SizedBox(height: Dimensions.paddingSizeLarge),
            ]),
          );
        }),
      ),
    );
  }
}
