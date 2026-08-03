import 'dart:io';
import 'dart:async';
import 'package:dotted_border/dotted_border.dart';
import 'package:photo_view/photo_view.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_button_widget.dart';
import 'package:sixam_mart_delivery/features/order/controllers/order_controller.dart';
import 'package:sixam_mart_delivery/features/order/widgets/bottom_view/parcel_bottom_view.dart';
import 'package:sixam_mart_delivery/features/order/widgets/bottom_view/regular_order_bottom_view.dart';
import 'package:sixam_mart_delivery/features/splash/controllers/splash_controller.dart';
import 'package:sixam_mart_delivery/features/notification/domain/models/notification_body_model.dart';
import 'package:sixam_mart_delivery/features/chat/domain/models/conversation_model.dart';
import 'package:sixam_mart_delivery/features/order/domain/models/order_details_model.dart';
import 'package:sixam_mart_delivery/features/order/domain/models/order_model.dart';
import 'package:sixam_mart_delivery/helper/date_converter_helper.dart';
import 'package:sixam_mart_delivery/helper/price_converter_helper.dart';
import 'package:sixam_mart_delivery/helper/responsive_helper.dart';
import 'package:sixam_mart_delivery/helper/route_helper.dart';
import 'package:sixam_mart_delivery/helper/string_extension.dart';
import 'package:sixam_mart_delivery/util/app_constants.dart';
import 'package:sixam_mart_delivery/util/dimensions.dart';
import 'package:sixam_mart_delivery/util/styles.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_app_bar_widget.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_snackbar_widget.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_image_widget.dart';
import 'package:sixam_mart_delivery/features/order/widgets/order_item_widget.dart';
import 'package:sixam_mart_delivery/features/order/widgets/info_card_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../widgets/custom_order_details_card.dart';

class OrderDetailsScreen extends StatefulWidget {
  final int? orderId;
  final bool? isRunningOrder;
  final int? orderIndex;
  final bool fromNotification;
  final bool fromLocationScreen;
  const OrderDetailsScreen({
    super.key,
    required this.orderId,
    required this.isRunningOrder,
    required this.orderIndex,
    this.fromNotification = false,
    this.fromLocationScreen = false,
  });

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen>
    with WidgetsBindingObserver {
  Timer? _timer;

  void _startApiCalling() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      Get.find<OrderController>().getOrderWithId(widget.orderId!);
    });
  }

  Future<void> _loadData() async {
    Get.find<OrderController>().pickPrescriptionImage(
      isRemove: true,
      isCamera: false,
    );
    await Get.find<OrderController>().getOrderWithId(widget.orderId);
    Get.find<OrderController>().getOrderDetails(
      widget.orderId,
      Get.find<OrderController>().orderModel!.orderType == 'parcel',
    );
    await Get.find<OrderController>().getLatestOrders();
    if (Get.find<OrderController>().showDeliveryImageField) {
      Get.find<OrderController>().changeDeliveryImageStatus(isUpdate: false);
    }
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      _startApiCalling();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      _timer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      // Reanudar el polling al volver al primer plano si el pedido no ha terminado
      final orderStatus =
          Get.find<OrderController>().orderModel?.orderStatus ?? '';
      final isTerminal =
          orderStatus == 'delivered' ||
          orderStatus == 'canceled' ||
          orderStatus == 'returned' ||
          orderStatus == 'failed';
      if (!isTerminal) {
        _startApiCalling();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
    _timer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if ((widget.fromNotification || widget.fromLocationScreen)) {
          Future.delayed(const Duration(milliseconds: 0), () async {
            await Get.offAllNamed(RouteHelper.getInitialRoute());
          });
        } else {
          return;
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).cardColor,
        appBar: CustomAppBarWidget(
          title: 'order_details'.tr,
          onBackPressed: () {
            if (widget.fromNotification || widget.fromLocationScreen) {
              Get.offAllNamed(RouteHelper.getInitialRoute());
            } else {
              Get.back();
            }
          },
        ),
        body: SafeArea(
          child: GetBuilder<OrderController>(
            builder: (orderController) {
              // Cancelar el timer si el pedido llegó a un estado terminal
              final _terminalStatuses = {
                'delivered',
                'canceled',
                'returned',
                'failed',
              };
              if (_terminalStatuses.contains(
                orderController.orderModel?.orderStatus,
              )) {
                _timer?.cancel();
              }

              OrderModel? controllerOrderModel = orderController.orderModel;

              bool restConfModel =
                  Get.find<SplashController>()
                      .configModel!
                      .orderConfirmationModel !=
                  'deliveryman';

              bool? parcel,
                  pickedUp,
                  cod,
                  wallet,
                  partialPay,
                  offlinePay,
                  digitalyPaid,
                  isDelivered;
              bool isTaxi = false;

              bool showDeliveryConfirmImage = false;

              double? deliveryCharge = 0;
              double itemsPrice = 0;
              double? discount = 0;
              double? couponDiscount = 0;
              double? tax = 0;
              double addOns = 0;
              double? dmTips = 0;
              double additionalCharge = 0;
              double extraPackagingAmount = 0;
              double referrerBonusAmount = 0;
              bool? isPrescriptionOrder = false;
              bool? taxIncluded = false;
              bool showChatPermission = true;
              OrderModel? order = controllerOrderModel;
              if (order != null && orderController.orderDetailsModel != null) {
                deliveryCharge = order.originalDeliveryCharge;
                dmTips = order.dmTips;
                isPrescriptionOrder = order.prescriptionOrder;
                discount =
                    order.storeDiscountAmount! +
                    order.flashAdminDiscountAmount! +
                    order.flashStoreDiscountAmount!;
                tax = order.totalTaxAmount;
                taxIncluded = order.taxStatus;
                additionalCharge = order.additionalCharge!;
                extraPackagingAmount = order.extraPackagingAmount!;
                referrerBonusAmount = order.referrerBonusAmount!;
                couponDiscount = order.couponDiscountAmount;
                if (isPrescriptionOrder!) {
                  double orderAmount = order.orderAmount ?? 0;
                  itemsPrice =
                      (orderAmount + discount) -
                      ((taxIncluded! ? 0 : tax!) +
                          deliveryCharge! +
                          additionalCharge) -
                      dmTips!;
                } else {
                  for (OrderDetailsModel orderDetails
                      in orderController.orderDetailsModel!) {
                    for (AddOn addOn in orderDetails.addOns!) {
                      addOns = addOns + (addOn.price! * addOn.quantity!);
                    }
                    itemsPrice =
                        itemsPrice +
                        (orderDetails.price! * orderDetails.quantity!);
                  }
                }

                if (order.storeBusinessModel == 'commission') {
                  showChatPermission = true;
                } else if (order.storeBusinessModel == 'subscription') {
                  showChatPermission = order.storeChatPermission == 1;
                } else {
                  showChatPermission = true;
                }
              }
              double subTotal = itemsPrice + addOns;
              double total =
                  itemsPrice +
                  addOns -
                  discount +
                  (taxIncluded! ? 0 : tax!) +
                  deliveryCharge! -
                  couponDiscount! +
                  dmTips! +
                  additionalCharge +
                  extraPackagingAmount -
                  referrerBonusAmount +
                  (order?.parcelInsuranceFee ?? 0);

              if (controllerOrderModel != null) {
                parcel = controllerOrderModel.orderType == 'parcel';
                isTaxi = controllerOrderModel.moduleType == 'taxi';
                pickedUp =
                    controllerOrderModel.orderStatus == AppConstants.pickedUp;
                cod = controllerOrderModel.paymentMethod == 'cash_on_delivery';
                wallet = controllerOrderModel.paymentMethod == 'wallet';
                digitalyPaid =
                    controllerOrderModel.paymentMethod == 'ssl_commerz';
                partialPay =
                    controllerOrderModel.paymentMethod == 'partial_payment';
                offlinePay =
                    controllerOrderModel.paymentMethod == 'offline_payment';

                showDeliveryConfirmImage =
                    pickedUp &&
                    Get.find<SplashController>()
                        .configModel!
                        .dmPictureUploadStatus! &&
                    controllerOrderModel.orderStatus != 'delivered';
                isDelivered = controllerOrderModel.orderStatus == 'delivered';
              }

              return (orderController.orderDetailsModel != null &&
                      controllerOrderModel != null)
                  ? Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            padding: EdgeInsets.all(
                              Dimensions.paddingSizeDefault,
                            ),
                            physics: const ClampingScrollPhysics(),
                            child: controllerOrderModel.orderStatus?.toLowerCase() == 'canceled'
                                ? _buildCanceledOrderView(
                                    context,
                                    orderController,
                                    controllerOrderModel,
                                    parcel!,
                                    order!,
                                    showChatPermission,
                                    isDelivered == true,
                                  )
                                : Column(
                                    children: [
                                Row(
                                  children: [
                                    Text(
                                      '${parcel! ? 'delivery_id'.tr : 'order_id'.tr}:',
                                      style: robotoRegular,
                                    ),
                                    const SizedBox(
                                      width: Dimensions.paddingSizeExtraSmall,
                                    ),

                                    Text(
                                      controllerOrderModel.id.toString(),
                                      style: robotoBold,
                                    ),
                                    const SizedBox(
                                      width: Dimensions.paddingSizeExtraSmall,
                                    ),

                                    const Expanded(child: SizedBox()),
                                    Container(
                                      height: 7,
                                      width: 7,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color:
                                            controllerOrderModel.orderStatus
                                                    ?.toLowerCase() ==
                                                "canceled"
                                            ? Colors.red
                                            : Colors.green,
                                      ),
                                    ),
                                    const SizedBox(
                                      width: Dimensions.paddingSizeExtraSmall,
                                    ),

                                    Text(
                                      controllerOrderModel.orderStatus!.tr,
                                      style: robotoBold,
                                    ),
                                    if (controllerOrderModel.transactionReference != null)
                                      Container(
                                        margin: const EdgeInsets.only(left: Dimensions.paddingSizeSmall),
                                        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: Dimensions.paddingSizeExtraSmall),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                                          color: Colors.blue.withValues(alpha: 0.1),
                                          border: Border.all(color: Colors.blue, width: 0.5),
                                        ),
                                        child: Text('${'misma_direccion'.tr} (#${controllerOrderModel.transactionReference})', style: robotoMedium.copyWith(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold)),
                                      ),
                                  ],
                                ),

                                const SizedBox(
                                  height: Dimensions.paddingSizeLarge,
                                ),

                                _buildFailedDeliveryInstructionCard(context, controllerOrderModel),

                                parcel &&
                                        order?.orderStatus ==
                                            AppConstants.canceled &&
                                        !(order
                                                ?.parcelCancellation
                                                ?.beforePickup ==
                                            1)
                                    ? Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'return_date_and_time'.tr,
                                            style: robotoRegular,
                                          ),

                                          Text(
                                            order
                                                        ?.parcelCancellation
                                                        ?.returnDate !=
                                                    null
                                                ? DateConverterHelper.dateTimeStringToDateTime(
                                                    order!
                                                        .parcelCancellation!
                                                        .returnDate!,
                                                  )
                                                : 'not_set_yet'.tr,
                                            style: robotoRegular,
                                          ),
                                        ],
                                      )
                                    : const SizedBox(),

                                controllerOrderModel.scheduleAt!.isNotEmpty &&
                                        controllerOrderModel.scheduleAt != null
                                    ? Column(
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                '${'schedule'.tr} ',
                                                style: robotoRegular,
                                              ),
                                              const Expanded(child: SizedBox()),

                                              Text(
                                                DateConverterHelper.dateTimeStringToDateTime(
                                                  controllerOrderModel
                                                      .scheduleAt!,
                                                ),
                                                style: robotoRegular,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(
                                            height: Dimensions.paddingSizeLarge,
                                          ),
                                        ],
                                      )
                                    : const SizedBox(),

                                SizedBox(
                                  height:
                                      parcel &&
                                          order?.orderStatus ==
                                              AppConstants.canceled &&
                                          !(order
                                                  ?.parcelCancellation
                                                  ?.beforePickup ==
                                              1)
                                      ? Dimensions.paddingSizeLarge
                                      : 0,
                                ),

                                if (isDelivered != true)
                                  Row(
                                    children: [
                                      Text(
                                        '${digitalyPaid == true && controllerOrderModel.chargePayer != null
                                            ? 'paid_by'.tr
                                            : parcel
                                            ? 'charge_payer'.tr
                                            : 'item'.tr}:',
                                        style: robotoRegular,
                                      ),
                                      const SizedBox(
                                        width: Dimensions.paddingSizeExtraSmall,
                                      ),
                                      Text(
                                        digitalyPaid == true &&
                                                controllerOrderModel
                                                        .chargePayer !=
                                                    null
                                            ? controllerOrderModel.chargePayer!
                                            : parcel
                                            ? controllerOrderModel
                                                  .chargePayer!
                                                  .tr
                                            : orderController
                                                  .orderDetailsModel!
                                                  .length
                                                  .toString(),
                                        style: robotoMedium.copyWith(
                                          color: Theme.of(context).primaryColor,
                                        ),
                                      ),
                                      const Expanded(child: SizedBox()),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal:
                                              Dimensions.paddingSizeSmall,
                                          vertical:
                                              Dimensions.paddingSizeExtraSmall,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(
                                            context,
                                          ).primaryColor.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(
                                            5,
                                          ),
                                        ),
                                        child: Text(
                                          cod!
                                              ? 'cod'.tr
                                              : wallet!
                                              ? 'wallet'.tr
                                              : partialPay!
                                              ? 'partially_pay'.tr
                                              : offlinePay!
                                              ? 'offline_payment'.tr
                                              : 'digitally_paid'.tr,
                                          style: robotoMedium.copyWith(
                                            fontSize:
                                                Dimensions.fontSizeExtraSmall,
                                            color: Theme.of(
                                              context,
                                            ).primaryColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                if (isDelivered != true)
                                  orderController
                                              .orderDetailsModel!
                                              .isNotEmpty &&
                                          orderController
                                                  .orderDetailsModel![0]
                                                  .itemDetails !=
                                              null &&
                                          orderController
                                                  .orderDetailsModel![0]
                                                  .itemDetails!
                                                  .moduleType ==
                                              'food'
                                      ? Column(
                                          children: [
                                            const SizedBox(
                                              height:
                                                  Dimensions.paddingSizeLarge,
                                            ),
                                            Row(
                                              children: [
                                                Text(
                                                  '${'cutlery'.tr} ',
                                                  style: robotoRegular,
                                                ),
                                                const Expanded(
                                                  child: SizedBox(),
                                                ),

                                                Text(
                                                  controllerOrderModel.cutlery!
                                                      ? 'yes'.tr
                                                      : 'no'.tr,
                                                  style: robotoRegular,
                                                ),
                                              ],
                                            ),
                                          ],
                                        )
                                      : const SizedBox(),

                                SizedBox(height: Dimensions.paddingSizeSmall),
                                Divider(
                                  thickness: 1,
                                  color: Theme.of(
                                    context,
                                  ).disabledColor.withValues(alpha: 0.05),
                                ),
                                SizedBox(
                                  height: Dimensions.paddingSizeExtraSmall,
                                ),

                                isDelivered != true &&
                                        controllerOrderModel
                                                .unavailableItemNote !=
                                            null
                                    ? CustomOrderDetailsCard(
                                        title:
                                            '${'unavailable_item_note'.tr}: ',
                                        metaValue: controllerOrderModel
                                            .unavailableItemNote!,
                                      )
                                    : const SizedBox(),
                                SizedBox(
                                  height:
                                      controllerOrderModel
                                              .unavailableItemNote !=
                                          null
                                      ? Dimensions.paddingSizeSmall
                                      : 0,
                                ),

                                isDelivered != true &&
                                        controllerOrderModel.deliveryInstruction != null && !controllerOrderModel.deliveryInstruction!.contains('Tarifa de multitienda')
                                    ? CustomOrderDetailsCard(
                                        title: '${'delivery_instruction'.tr}: ',
                                        metaValue: controllerOrderModel
                                            .deliveryInstruction!
                                            .tr,
                                      )
                                    : const SizedBox(),

                                SizedBox(
                                  height:
                                      controllerOrderModel
                                              .deliveryInstruction !=
                                          null
                                      ? Dimensions.paddingSizeSmall
                                      : 0,
                                ),

                                isDelivered != true &&
                                        controllerOrderModel
                                                .bringChangeAmount !=
                                            null &&
                                        controllerOrderModel
                                                .bringChangeAmount! >
                                            0
                                    ? Container(
                                        width: double.infinity,
                                        margin: EdgeInsets.only(
                                          top: Dimensions.paddingSizeSmall,
                                        ),
                                        padding: const EdgeInsets.all(
                                          Dimensions.paddingSizeSmall,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0XFF009AF1,
                                          ).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(
                                            Dimensions.radiusSmall,
                                          ),
                                        ),
                                        child: RichText(
                                          text: TextSpan(
                                            children: [
                                              TextSpan(
                                                text: 'please_bring'.tr,
                                                style: robotoRegular.copyWith(
                                                  color: Theme.of(
                                                    context,
                                                  ).textTheme.bodyLarge?.color,
                                                ),
                                              ),
                                              TextSpan(
                                                text:
                                                    ' ${PriceConverterHelper.convertPrice(controllerOrderModel.bringChangeAmount)}',
                                                style: robotoMedium.copyWith(
                                                  color: Theme.of(
                                                    context,
                                                  ).textTheme.bodyLarge?.color,
                                                ),
                                              ),
                                              TextSpan(
                                                text:
                                                    ' ${'in_change_for_the_customer_when_making_the_delivery'.tr}',
                                                style: robotoRegular.copyWith(
                                                  color: Theme.of(
                                                    context,
                                                  ).textTheme.bodyLarge?.color,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                    : const SizedBox(),
                                const SizedBox(
                                  height: Dimensions.paddingSizeSmall,
                                ),

                                if (controllerOrderModel.transactionReference != null)
                                  Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(bottom: Dimensions.paddingSizeDefault),
                                    padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                                      border: Border.all(color: Colors.blue, width: 1),
                                    ),
                                    child: Row(children: [
                                      const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                                      const SizedBox(width: Dimensions.paddingSizeSmall),
                                      Expanded(child: Text(
                                        'Este es un ${'misma_direccion'.tr}. Se debe entregar junto con los demás pedidos de la misma dirección.',
                                        style: robotoMedium.copyWith(color: Colors.blue, fontSize: Dimensions.fontSizeSmall),
                                      )),
                                    ]),
                                  ),

                                if (controllerOrderModel.paymentMethod == 'cash_on_delivery' &&
                                    controllerOrderModel.orderType == 'delivery' &&
                                    controllerOrderModel.cashOnPickupAmount != null &&
                                    controllerOrderModel.cashOnPickupAmount! > 0 &&
                                    (controllerOrderModel.orderStatus == 'accepted' ||
                                     controllerOrderModel.orderStatus == 'confirmed' ||
                                     controllerOrderModel.orderStatus == 'processing' ||
                                     controllerOrderModel.orderStatus == 'handover'))
                                  Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(bottom: Dimensions.paddingSizeDefault),
                                    padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.amber.shade800,
                                          Colors.amber.shade600,
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.amber.withValues(alpha: 0.3),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                          Icons.payments_outlined,
                                          color: Colors.white,
                                          size: 28,
                                        ),
                                        const SizedBox(width: Dimensions.paddingSizeSmall),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'pago_en_recoleccion'.tr,
                                                style: robotoBold.copyWith(
                                                  color: Colors.white,
                                                  fontSize: Dimensions.fontSizeLarge,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              RichText(
                                                text: TextSpan(
                                                  children: [
                                                    TextSpan(
                                                      text: 'deberas_pagar_al_restaurante'.tr,
                                                      style: robotoRegular.copyWith(
                                                        color: Colors.white.withValues(alpha: 0.9),
                                                        fontSize: Dimensions.fontSizeDefault,
                                                      ),
                                                    ),
                                                    TextSpan(
                                                      text: ' ${PriceConverterHelper.convertPrice(controllerOrderModel.cashOnPickupAmount)} ',
                                                      style: robotoBold.copyWith(
                                                        color: Colors.white,
                                                        fontSize: Dimensions.fontSizeDefault,
                                                        fontWeight: FontWeight.w900,
                                                      ),
                                                    ),
                                                    TextSpan(
                                                      text: 'en_efectivo_al_recoger_el_pedido'.tr,
                                                      style: robotoRegular.copyWith(
                                                        color: Colors.white.withValues(alpha: 0.9),
                                                        fontSize: Dimensions.fontSizeDefault,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                InfoCardWidget(
                                  title: isTaxi 
                                      ? 'Detalles del Pasajero'
                                      : (parcel
                                          ? 'sender_details'.tr
                                          : 'store_details'.tr),
                                  address: parcel || isTaxi
                                      ? controllerOrderModel.deliveryAddress
                                      : DeliveryAddress(
                                          address:
                                              controllerOrderModel.storeAddress,
                                        ),
                                  image: parcel || isTaxi
                                      ? ''
                                      : '${controllerOrderModel.storeLogoFullUrl}',
                                  name: isTaxi 
                                      ? (controllerOrderModel.customer?.fName != null ? '${controllerOrderModel.customer?.fName} ${controllerOrderModel.customer?.lName ?? ''}'.trim() : 'Pasajero')
                                      : (parcel
                                          ? controllerOrderModel
                                                .deliveryAddress!
                                                .contactPersonName
                                          : controllerOrderModel.storeName),
                                  phone: parcel || isTaxi
                                      ? controllerOrderModel
                                            .deliveryAddress!
                                            .contactPersonNumber
                                      : controllerOrderModel.storePhone,
                                  latitude: parcel
                                      ? controllerOrderModel
                                            .deliveryAddress!
                                            .latitude
                                      : controllerOrderModel.storeLat,
                                  longitude: parcel
                                      ? controllerOrderModel
                                            .deliveryAddress!
                                            .longitude
                                      : controllerOrderModel.storeLng,
                                  showButton:
                                      (controllerOrderModel.orderStatus !=
                                          'delivered' &&
                                      controllerOrderModel.orderStatus !=
                                          'failed' &&
                                      controllerOrderModel.orderStatus !=
                                          'canceled' &&
                                      controllerOrderModel.orderStatus !=
                                          'refunded'),
                                  isStore: parcel ? false : true,
                                  isChatAllow:
                                      showChatPermission && isDelivered != true,
                                  showCallButton: isDelivered != true,
                                  messageOnTap: () => Get.toNamed(
                                    RouteHelper.getChatRoute(
                                      notificationBody: NotificationBodyModel(
                                        orderId: controllerOrderModel.id,
                                        vendorId: orderController
                                            .orderDetailsModel![0]
                                            .vendorId,
                                      ),
                                      user: User(
                                        id: controllerOrderModel.storeId,
                                        fName: controllerOrderModel.storeName,
                                        imageFullUrl: controllerOrderModel
                                            .storeLogoFullUrl,
                                        phone: controllerOrderModel.storePhone,
                                      ),
                                    ),
                                  ),
                                  order: order!,
                                ),
                                const SizedBox(
                                  height: Dimensions.paddingSizeLarge,
                                ),

                                InfoCardWidget(
                                  title: parcel
                                      ? 'receiver_details'.tr
                                      : 'customer_contact_details'.tr,
                                  address: parcel
                                      ? controllerOrderModel.receiverDetails
                                      : controllerOrderModel.deliveryAddress,
                                  image: parcel
                                      ? ''
                                      : controllerOrderModel.customer != null
                                      ? '${controllerOrderModel.customer!.imageFullUrl}'
                                      : '',
                                  name: parcel
                                      ? controllerOrderModel
                                            .receiverDetails!
                                            .contactPersonName
                                      : controllerOrderModel
                                            .deliveryAddress!
                                            .contactPersonName,
                                  phone: parcel
                                      ? controllerOrderModel
                                            .receiverDetails!
                                            .contactPersonNumber
                                      : controllerOrderModel
                                            .deliveryAddress!
                                            .contactPersonNumber,
                                  latitude: parcel
                                      ? controllerOrderModel
                                            .receiverDetails!
                                            .latitude
                                      : controllerOrderModel
                                            .deliveryAddress!
                                            .latitude,
                                  longitude: parcel
                                      ? controllerOrderModel
                                            .receiverDetails!
                                            .longitude
                                      : controllerOrderModel
                                            .deliveryAddress!
                                            .longitude,
                                  showButton:
                                      controllerOrderModel.orderStatus !=
                                          'delivered' &&
                                      controllerOrderModel.orderStatus !=
                                          'failed' &&
                                      controllerOrderModel.orderStatus !=
                                          'canceled' &&
                                      controllerOrderModel.orderStatus !=
                                          'refunded' &&
                                      controllerOrderModel.orderStatus !=
                                          'returned',
                                  isStore: parcel ? false : true,
                                  isChatAllow:
                                      (showChatPermission ||
                                          controllerOrderModel
                                                  .tootliDirectTrackable ==
                                              true) &&
                                      isDelivered != true,
                                  showCallButton: isDelivered != true,
                                  messageOnTap: () {
                                    final int? oid = controllerOrderModel.id;
                                    final bool useTootliDirectChat =
                                        oid != null &&
                                        (controllerOrderModel
                                                    .tootliDirectTrackable ==
                                                true ||
                                            controllerOrderModel
                                                .hasTootliDirectPublicTrackingUrl);
                                    if (useTootliDirectChat) {
                                      Get.toNamed(
                                        RouteHelper.getTootliDirectTrackingChatRoute(
                                          oid!,
                                        ),
                                      );
                                      return;
                                    }
                                    final Customer? c =
                                        controllerOrderModel.customer;
                                    if (c == null) {
                                      if (controllerOrderModel.isGuest ==
                                          true) {
                                        showCustomSnackBar(
                                          'tootli_direct_guest_chat_web_only'
                                              .tr,
                                          isError: false,
                                        );
                                      } else {
                                        showCustomSnackBar(
                                          'customer_not_found'.tr,
                                          isError: true,
                                        );
                                      }
                                      return;
                                    }
                                    Get.toNamed(
                                      RouteHelper.getChatRoute(
                                        notificationBody: NotificationBodyModel(
                                          orderId: controllerOrderModel.id,
                                          customerId: c.id,
                                        ),
                                        user: User(
                                          id: c.id,
                                          fName: c.fName,
                                          lName: c.lName,
                                          imageFullUrl: c.imageFullUrl,
                                          phone: c.phone,
                                        ),
                                      ),
                                    );
                                  },
                                  order: order,
                                ),
                                const SizedBox(
                                  height: Dimensions.paddingSizeLarge,
                                ),

                                isDelivered != true && parcel
                                    ? Container(
                                        padding: const EdgeInsets.all(
                                          Dimensions.paddingSizeSmall,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).cardColor,
                                          borderRadius: BorderRadius.circular(
                                            Dimensions.radiusSmall,
                                          ),
                                          boxShadow: Get.isDarkMode
                                              ? null
                                              : [
                                                  BoxShadow(
                                                    color: Colors.grey[200]!,
                                                    spreadRadius: 1,
                                                    blurRadius: 5,
                                                  ),
                                                ],
                                        ),
                                        child:
                                            controllerOrderModel
                                                    .parcelCategory !=
                                                null
                                            ? Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'parcel_category'.tr,
                                                    style: robotoBold,
                                                  ),
                                                  const SizedBox(
                                                    height: Dimensions
                                                        .paddingSizeExtraSmall,
                                                  ),
                                                  Row(
                                                    children: [
                                                      ClipRRect(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              Dimensions
                                                                  .radiusSmall,
                                                            ),
                                                        child: CustomImageWidget(
                                                          image:
                                                              '${controllerOrderModel.parcelCategory!.imageFullUrl}',
                                                          height: 35,
                                                          width: 35,
                                                          fit: BoxFit.cover,
                                                        ),
                                                      ),
                                                      const SizedBox(
                                                        width: Dimensions
                                                            .paddingSizeSmall,
                                                      ),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              controllerOrderModel
                                                                  .parcelCategory!
                                                                  .name!,
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style: robotoRegular
                                                                  .copyWith(
                                                                    fontSize:
                                                                        Dimensions
                                                                            .fontSizeSmall,
                                                                  ),
                                                            ),
                                                            Text(
                                                              controllerOrderModel
                                                                  .parcelCategory!
                                                                  .description!,
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style: robotoRegular.copyWith(
                                                                fontSize: Dimensions
                                                                    .fontSizeSmall,
                                                                color: Theme.of(
                                                                  context,
                                                                ).disabledColor,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  if (controllerOrderModel.parcelDeclaredValue != null && controllerOrderModel.parcelDeclaredValue! > 0) ...[
                                                    const SizedBox(height: Dimensions.paddingSizeSmall),
                                                    Divider(color: Theme.of(context).disabledColor.withValues(alpha: 0.3)),
                                                    const SizedBox(height: Dimensions.paddingSizeExtraSmall),
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Text('declared_value'.tr, style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).disabledColor)),
                                                        Text(PriceConverterHelper.convertPrice(controllerOrderModel.parcelDeclaredValue), style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall)),
                                                      ],
                                                    ),
                                                  ],
                                                  if (controllerOrderModel.parcelInsuranceFee != null && controllerOrderModel.parcelInsuranceFee! > 0) ...[
                                                    const SizedBox(height: Dimensions.paddingSizeExtraSmall),
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Text('insurance_fee'.tr, style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).disabledColor)),
                                                        Text(PriceConverterHelper.convertPrice(controllerOrderModel.parcelInsuranceFee), style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall)),
                                                      ],
                                                    ),
                                                  ],
                                                ],
                                              )
                                            : SizedBox(
                                                width: context.width,
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'parcel_category'.tr,
                                                      style: robotoRegular,
                                                    ),
                                                    const SizedBox(
                                                      height: Dimensions
                                                          .paddingSizeExtraSmall,
                                                    ),

                                                    Text(
                                                      'no_parcel_category_data_found'
                                                          .tr,
                                                      style: robotoMedium,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                      )
                                    : Container(
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).cardColor,
                                          borderRadius: BorderRadius.circular(
                                            Dimensions.radiusSmall,
                                          ),
                                          boxShadow: Get.isDarkMode
                                              ? null
                                              : [
                                                  BoxShadow(
                                                    color: Colors.grey[200]!,
                                                    spreadRadius: 1,
                                                    blurRadius: 5,
                                                  ),
                                                ],
                                        ),
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 10,
                                        ),
                                        child: Column(
                                          spacing: 10,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'item_info'.tr,
                                              style: robotoBold.copyWith(
                                                fontSize:
                                                    Dimensions.fontSizeDefault,
                                              ),
                                            ),
                                            ListView.separated(
                                              shrinkWrap: true,
                                              physics:
                                                  const NeverScrollableScrollPhysics(),
                                              itemCount: orderController
                                                  .orderDetailsModel!
                                                  .length,
                                              itemBuilder: (context, index) {
                                                return OrderItemWidget(
                                                  order: controllerOrderModel,
                                                  orderDetails: orderController
                                                      .orderDetailsModel![index],
                                                );
                                              },
                                              separatorBuilder:
                                                  (context, index) {
                                                    return Divider(height: 25);
                                                  },
                                            ),
                                          ],
                                        ),
                                      ),
                                 if (parcel && controllerOrderModel.parcelCategory?.buyAndDeliver == true && isDelivered != true)
                                   ParcelReceiptUploadWidget(order: controllerOrderModel, orderController: orderController),
                                SizedBox(
                                  height:
                                      parcel && order.parcelCancellation != null
                                      ? Dimensions.paddingSizeLarge
                                      : 0,
                                ),

                                parcel && order.parcelCancellation != null
                                    ? Container(
                                        padding: const EdgeInsets.all(
                                          Dimensions.paddingSizeSmall,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).cardColor,
                                          borderRadius: BorderRadius.circular(
                                            Dimensions.radiusSmall,
                                          ),
                                          boxShadow: Get.isDarkMode
                                              ? null
                                              : [
                                                  BoxShadow(
                                                    color: Colors.grey[200]!,
                                                    spreadRadius: 1,
                                                    blurRadius: 5,
                                                  ),
                                                ],
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            order
                                                            .parcelCancellation!
                                                            .returnFee !=
                                                        null &&
                                                    order
                                                            .parcelCancellation!
                                                            .returnFee! >
                                                        0
                                                ? Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                          12,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Theme.of(context)
                                                          .disabledColor
                                                          .withValues(
                                                            alpha: 0.1,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            Dimensions
                                                                .radiusDefault,
                                                          ),
                                                    ),
                                                    child: Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      children: [
                                                        Text(
                                                          order.orderStatus ==
                                                                  AppConstants
                                                                      .returned
                                                              ? 'collected_return_fee_from_customer'
                                                                    .tr
                                                              : 'collect_return_fee_from_customer'
                                                                    .tr,
                                                          style: robotoRegular,
                                                        ),

                                                        Text(
                                                          PriceConverterHelper.convertPrice(
                                                            order
                                                                .parcelCancellation!
                                                                .returnFee,
                                                          ),
                                                          style: robotoBold,
                                                        ),
                                                      ],
                                                    ),
                                                  )
                                                : const SizedBox(),
                                            SizedBox(
                                              height:
                                                  order
                                                              .parcelCancellation!
                                                              .returnFee !=
                                                          null &&
                                                      order
                                                              .parcelCancellation!
                                                              .returnFee! >
                                                          0
                                                  ? Dimensions.paddingSizeSmall
                                                  : 0,
                                            ),

                                            Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .error
                                                    .withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      Dimensions.radiusDefault,
                                                    ),
                                              ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    'canceled_by'.tr,
                                                    style: robotoRegular
                                                        .copyWith(
                                                          color: Theme.of(
                                                            context,
                                                          ).colorScheme.error,
                                                        ),
                                                  ),

                                                  Text(
                                                    order
                                                            .parcelCancellation
                                                            ?.cancelBy
                                                            ?.toTitleCase() ??
                                                        '',
                                                    style: robotoRegular,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(
                                              height:
                                                  Dimensions.paddingSizeSmall,
                                            ),

                                            order.parcelCancellation?.reason !=
                                                        null &&
                                                    order
                                                        .parcelCancellation!
                                                        .reason!
                                                        .isNotEmpty
                                                ? Text(
                                                    'cancellation_reason'.tr,
                                                    style: robotoSemiBold,
                                                  )
                                                : const SizedBox(),
                                            SizedBox(
                                              height:
                                                  order
                                                              .parcelCancellation
                                                              ?.reason !=
                                                          null &&
                                                      order
                                                          .parcelCancellation!
                                                          .reason!
                                                          .isNotEmpty
                                                  ? Dimensions.paddingSizeSmall
                                                  : 0,
                                            ),

                                            order.parcelCancellation?.reason !=
                                                        null &&
                                                    order
                                                        .parcelCancellation!
                                                        .reason!
                                                        .isNotEmpty
                                                ? Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                          12,
                                                        ),
                                                    width: double.maxFinite,
                                                    decoration: BoxDecoration(
                                                      color: Theme.of(context)
                                                          .disabledColor
                                                          .withValues(
                                                            alpha: 0.1,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            Dimensions
                                                                .radiusDefault,
                                                          ),
                                                    ),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: List.generate(
                                                        order
                                                            .parcelCancellation!
                                                            .reason!
                                                            .length,
                                                        (index) {
                                                          return Row(
                                                            children: [
                                                              Container(
                                                                height: 5,
                                                                width: 5,
                                                                decoration: BoxDecoration(
                                                                  color: Theme.of(context)
                                                                      .textTheme
                                                                      .bodyLarge
                                                                      ?.color
                                                                      ?.withValues(alpha: 0.7),
                                                                  shape: BoxShape
                                                                      .circle,
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                width: Dimensions
                                                                    .paddingSizeSmall,
                                                              ),

                                                              Expanded(
                                                                child: Text(
                                                                  order
                                                                          .parcelCancellation!
                                                                          .reason?[index] ??
                                                                      '',
                                                                  style: robotoRegular.copyWith(
                                                                    color: Theme.of(context)
                                                                        .textTheme
                                                                        .bodyLarge
                                                                        ?.color
                                                                        ?.withValues(alpha: 0.7),
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                  )
                                                : const SizedBox(),
                                            SizedBox(
                                              height:
                                                  order
                                                              .parcelCancellation
                                                              ?.reason !=
                                                          null &&
                                                      order
                                                          .parcelCancellation!
                                                          .reason!
                                                          .isNotEmpty
                                                  ? Dimensions.paddingSizeSmall
                                                  : 0,
                                            ),

                                            order.parcelCancellation?.note !=
                                                    null
                                                ? Text(
                                                    'comments'.tr,
                                                    style: robotoSemiBold,
                                                  )
                                                : const SizedBox(),
                                            SizedBox(
                                              height:
                                                  order
                                                          .parcelCancellation
                                                          ?.note !=
                                                      null
                                                  ? Dimensions.paddingSizeSmall
                                                  : 0,
                                            ),

                                            order.parcelCancellation?.note !=
                                                    null
                                                ? Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                          12,
                                                        ),
                                                    width: double.maxFinite,
                                                    decoration: BoxDecoration(
                                                      color: Theme.of(context)
                                                          .disabledColor
                                                          .withValues(
                                                            alpha: 0.1,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            Dimensions
                                                                .radiusDefault,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      order
                                                              .parcelCancellation
                                                              ?.note ??
                                                          '',
                                                      style: robotoRegular
                                                          .copyWith(
                                                            color:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .textTheme
                                                                    .bodyLarge
                                                                    ?.color
                                                                    ?.withValues(
                                                                      alpha:
                                                                          0.7,
                                                                    ),
                                                          ),
                                                    ),
                                                  )
                                                : const SizedBox(),
                                          ],
                                        ),
                                      )
                                    : const SizedBox(),

                                (controllerOrderModel.orderNote != null &&
                                        controllerOrderModel
                                            .orderNote!
                                            .isNotEmpty)
                                    ? Container(
                                        margin: !parcel
                                            ? EdgeInsets.only(
                                                top:
                                                    Dimensions.paddingSizeLarge,
                                              )
                                            : null,
                                        padding: const EdgeInsets.all(
                                          Dimensions.paddingSizeSmall,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).cardColor,
                                          borderRadius: BorderRadius.circular(
                                            Dimensions.radiusSmall,
                                          ),
                                          boxShadow: Get.isDarkMode
                                              ? null
                                              : [
                                                  BoxShadow(
                                                    color: Colors.grey[200]!,
                                                    spreadRadius: 1,
                                                    blurRadius: 5,
                                                  ),
                                                ],
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'additional_note'.tr,
                                              style: robotoBold.copyWith(
                                                fontSize:
                                                    Dimensions.fontSizeDefault,
                                              ),
                                            ),
                                            const SizedBox(
                                              height:
                                                  Dimensions.paddingSizeSmall,
                                            ),
                                            Container(
                                              width: 1170,
                                              padding: const EdgeInsets.all(
                                                Dimensions.paddingSizeSmall,
                                              ),
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(5),
                                                border: Border.all(
                                                  width: 1,
                                                  color: Theme.of(
                                                    context,
                                                  ).disabledColor,
                                                ),
                                              ),
                                              child: Text(
                                                controllerOrderModel.orderNote!,
                                                style: robotoRegular.copyWith(
                                                  fontSize:
                                                      Dimensions.fontSizeSmall,
                                                  color: Theme.of(
                                                    context,
                                                  ).disabledColor,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : const SizedBox(),

                                // SizedBox(height: (controllerOrderModel.orderNote != null && controllerOrderModel.orderNote!.isNotEmpty) ? Dimensions.paddingSizeLarge : 0),
                                (Get.find<SplashController>()
                                            .getModule(
                                              controllerOrderModel.moduleType,
                                            )
                                            .orderAttachment! &&
                                        controllerOrderModel
                                                .orderAttachmentFullUrl !=
                                            null &&
                                        controllerOrderModel
                                            .orderAttachmentFullUrl!
                                            .isNotEmpty)
                                    ? Container(
                                        margin: EdgeInsets.only(
                                          top: Dimensions.paddingSizeLarge,
                                        ),
                                        padding: const EdgeInsets.all(
                                          Dimensions.paddingSizeSmall,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).cardColor,
                                          borderRadius: BorderRadius.circular(
                                            Dimensions.radiusSmall,
                                          ),
                                          boxShadow: Get.isDarkMode
                                              ? null
                                              : [
                                                  BoxShadow(
                                                    color: Colors.grey[200]!,
                                                    spreadRadius: 1,
                                                    blurRadius: 5,
                                                  ),
                                                ],
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'prescription'.tr,
                                              style: robotoRegular,
                                            ),
                                            const SizedBox(
                                              height:
                                                  Dimensions.paddingSizeSmall,
                                            ),

                                            GridView.builder(
                                              gridDelegate:
                                                  SliverGridDelegateWithFixedCrossAxisCount(
                                                    childAspectRatio: 1.5,
                                                    crossAxisCount:
                                                        ResponsiveHelper.isTab(
                                                          context,
                                                        )
                                                        ? 5
                                                        : 3,
                                                    mainAxisSpacing: 10,
                                                    crossAxisSpacing: 5,
                                                  ),
                                              shrinkWrap: true,
                                              physics:
                                                  const NeverScrollableScrollPhysics(),
                                              itemCount: controllerOrderModel
                                                  .orderAttachmentFullUrl!
                                                  .length,
                                              itemBuilder: (BuildContext context, index) {
                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        right: 8,
                                                      ),
                                                  child: InkWell(
                                                    onTap: () => openDialog(
                                                      context,
                                                      controllerOrderModel
                                                          .orderAttachmentFullUrl![index],
                                                    ),
                                                    child: Center(
                                                      child: ClipRRect(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              Dimensions
                                                                  .radiusSmall,
                                                            ),
                                                        child: CustomImageWidget(
                                                          image: controllerOrderModel
                                                              .orderAttachmentFullUrl![index],
                                                          width: 100,
                                                          height: 100,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                            const SizedBox(
                                              height:
                                                  Dimensions.paddingSizeLarge,
                                            ),
                                          ],
                                        ),
                                      )
                                    : const SizedBox(),

                                (controllerOrderModel.orderStatus ==
                                            'delivered' &&
                                        controllerOrderModel
                                                .orderProofFullUrl !=
                                            null &&
                                        controllerOrderModel
                                            .orderProofFullUrl!
                                            .isNotEmpty)
                                    ? Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(
                                            height: Dimensions.paddingSizeSmall,
                                          ),
                                          Text(
                                            'order_proof'.tr,
                                            style: robotoRegular,
                                          ),
                                          const SizedBox(
                                            height: Dimensions.paddingSizeSmall,
                                          ),

                                          GridView.builder(
                                            gridDelegate:
                                                SliverGridDelegateWithFixedCrossAxisCount(
                                                  childAspectRatio: 1.5,
                                                  crossAxisCount:
                                                      ResponsiveHelper.isTab(
                                                        context,
                                                      )
                                                      ? 5
                                                      : 3,
                                                  mainAxisSpacing: 10,
                                                  crossAxisSpacing: 5,
                                                ),
                                            shrinkWrap: true,
                                            physics:
                                                const NeverScrollableScrollPhysics(),
                                            itemCount: controllerOrderModel
                                                .orderProofFullUrl!
                                                .length,
                                            itemBuilder: (BuildContext context, index) {
                                              return Padding(
                                                padding: const EdgeInsets.only(
                                                  right: 8,
                                                ),
                                                child: InkWell(
                                                  onTap: () => openDialog(
                                                    context,
                                                    controllerOrderModel
                                                        .orderProofFullUrl![index],
                                                  ),
                                                  child: Center(
                                                    child: ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            Dimensions
                                                                .radiusSmall,
                                                          ),
                                                      child: CustomImageWidget(
                                                        image: controllerOrderModel
                                                            .orderProofFullUrl![index],
                                                        width: 100,
                                                        height: 100,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      )
                                    : const SizedBox(),

                                Container(
                                  margin: EdgeInsets.only(
                                    top: Dimensions.paddingSizeLarge,
                                  ),
                                  padding: const EdgeInsets.all(
                                    Dimensions.paddingSizeSmall,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).cardColor,
                                    borderRadius: BorderRadius.circular(
                                      Dimensions.radiusSmall,
                                    ),
                                    boxShadow: Get.isDarkMode
                                        ? null
                                        : [
                                            BoxShadow(
                                              color: Colors.grey[200]!,
                                              spreadRadius: 1,
                                              blurRadius: 5,
                                            ),
                                          ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'ganancia_neta_por_este_viaje'.tr,
                                        style: robotoBold.copyWith(
                                          fontSize: Dimensions.fontSizeDefault,
                                        ),
                                      ),
                                      SizedBox(
                                        height: Dimensions.paddingSizeSmall,
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'ganancia_limpia_envio_propina'.tr,
                                            style: robotoRegular,
                                          ),
                                          Text(
                                            PriceConverterHelper.convertPrice(
                                              (order?.deliveryCharge ?? 0) +
                                                  (order?.dmTips ?? 0),
                                            ),
                                            style: robotoMedium.copyWith(
                                              fontSize:
                                                  Dimensions.fontSizeLarge,
                                              color: Theme.of(
                                                context,
                                              ).primaryColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                /*Container(
                    margin: EdgeInsets.only(top: Dimensions.paddingSizeLarge),
                    padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                      boxShadow: Get.isDarkMode ? null : [BoxShadow(color: Colors.grey[200]!, spreadRadius: 1, blurRadius: 5)],
                    ),
                    child: 
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('billing_summary'.tr, style: robotoBold.copyWith(fontSize: Dimensions.fontSizeDefault)),
                      SizedBox(height: Dimensions.paddingSizeSmall),

                      !parcel ? Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('item_price'.tr, style: robotoRegular),
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(PriceConverterHelper.convertPrice(itemsPrice), style: robotoRegular),
                        ]),
                      ]) : const SizedBox(),
                      SizedBox(height: !parcel ? 10 : 0),

                      Get.find<SplashController>().getModuleConfig(order.moduleType).addOn! ? Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('addons'.tr, style: robotoRegular),
                          Text('(+) ${PriceConverterHelper.convertPrice(addOns)}', style: robotoRegular),
                        ],
                      ) : const SizedBox(),

                      Get.find<SplashController>().getModuleConfig(order.moduleType).addOn! ? Divider(
                        thickness: 1, color: Theme.of(context).hintColor.withValues(alpha: 0.5),
                      ) : const SizedBox(),

                      Get.find<SplashController>().getModuleConfig(order.moduleType).addOn! ? Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('subtotal'.tr, style: robotoMedium),
                          Text(PriceConverterHelper.convertPrice(subTotal), style: robotoMedium),
                        ],
                      ) : const SizedBox(),
                      SizedBox(height: Get.find<SplashController>().getModuleConfig(order.moduleType).addOn! ? 10 : 0),

                      !parcel ? Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('discount'.tr, style: robotoRegular),
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          Text('(-) ${PriceConverterHelper.convertPrice(discount)}', style: robotoRegular),
                        ]),
                      ]) : const SizedBox(),
                      SizedBox(height: !parcel ? 10 : 0),

                      couponDiscount > 0 ? Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('coupon_discount'.tr, style: robotoRegular),
                        Text(
                          '(-) ${PriceConverterHelper.convertPrice(couponDiscount)}',
                          style: robotoRegular,
                        ),
                      ]) : const SizedBox(),
                      SizedBox(height: couponDiscount > 0 ? 10 : 0),

                      (referrerBonusAmount > 0) ? Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('referral_discount'.tr, style: robotoRegular),
                          Text('(-) ${PriceConverterHelper.convertPrice(referrerBonusAmount)}', style: robotoRegular),
                        ],
                      ) : const SizedBox(),
                      SizedBox(height: referrerBonusAmount > 0 ? 10 : 0),

                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('delivery_fee'.tr, style: robotoRegular),
                        Text('(+) ${PriceConverterHelper.convertPrice(deliveryCharge)}', style: robotoRegular),
                      ]),
                      const SizedBox(height: 10),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('delivery_man_tips'.tr, style: robotoRegular),
                          Text('(+) ${PriceConverterHelper.convertPrice(dmTips)}', style: robotoRegular),
                        ],
                      ),
                      const SizedBox(height: 10),

                      (extraPackagingAmount > 0) ? Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('extra_packaging'.tr, style: robotoRegular),
                          Text('(+) ${PriceConverterHelper.convertPrice(extraPackagingAmount)}', style: robotoRegular),
                        ],
                      ) : const SizedBox(),
                      SizedBox(height: extraPackagingAmount > 0 ? 10 : 0),

                      (order.additionalCharge != null && order.additionalCharge! > 0) ? Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Expanded(
                          child: Text(Get.find<SplashController>().configModel!.additionalChargeName!, style: robotoRegular, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        SizedBox(width: Dimensions.paddingSizeSmall),

                        Text('(+) ${PriceConverterHelper.convertPrice(order.additionalCharge)}', style: robotoRegular, textDirection: TextDirection.ltr),
                      ]) : const SizedBox(),
                      (order.additionalCharge != null && order.additionalCharge! > 0) ? const SizedBox(height: 10) : const SizedBox(),

                      parcel && (order.parcelInsuranceFee ?? 0) > 0 ? Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('insurance_fee'.tr, style: robotoRegular),
                        Text('(+) ${PriceConverterHelper.convertPrice(order.parcelInsuranceFee)}', style: robotoRegular),
                      ]) : const SizedBox(),
                      parcel && (order.parcelInsuranceFee ?? 0) > 0 ? const SizedBox(height: 10) : const SizedBox(),

                      (tax! == 0) || taxIncluded ? const SizedBox() : Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('vat_tax'.tr, style: robotoRegular),
                        Text('(+) ${PriceConverterHelper.convertPrice(tax)}', style: robotoRegular),
                      ]),

                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: Dimensions.paddingSizeSmall),
                        child: Divider(thickness: 1, color: Theme.of(context).hintColor.withValues(alpha: 0.5)),
                      ),

                      partialPay! ? DottedBorder(
                        options: RoundedRectDottedBorderOptions(
                          color: Theme.of(context).primaryColor,
                          strokeWidth: 1,
                          strokeCap: StrokeCap.butt,
                          dashPattern: const [8, 5],
                          padding: const EdgeInsets.all(0),
                          radius: const Radius.circular(Dimensions.radiusDefault),
                        ),
                        child: Ink(
                          padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
                          color: !restConfModel ? Theme.of(context).primaryColor.withValues(alpha: 0.05) : Colors.transparent,
                          child: Column(children: [

                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Text(cod! ? 'amount_collect_from_customer'.tr : 'total_amount'.tr, style: robotoMedium.copyWith(
                                fontSize: Dimensions.fontSizeLarge, color: Theme.of(context).primaryColor,
                              )),
                              Text(
                                PriceConverterHelper.convertPrice(total),
                                style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeLarge, color: Theme.of(context).primaryColor),
                              ),
                            ]),
                            const SizedBox(height: 10),

                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Text('paid_by_wallet'.tr, style: !restConfModel ? robotoMedium : robotoRegular),
                              Text(
                                PriceConverterHelper.convertPrice(order.payments![0].amount),
                                style: !restConfModel ? robotoMedium : robotoRegular,
                              ),
                            ]),
                            const SizedBox(height: 10),

                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Text('${order.payments?[1].paymentStatus == 'paid' ? 'paid_by'.tr : 'due_amount'.tr} (${order.payments![1].paymentMethod?.tr})', style: !restConfModel ? robotoMedium : robotoRegular),
                              Text(
                                PriceConverterHelper.convertPrice(order.payments![1].amount),
                                style: !restConfModel ? robotoMedium : robotoRegular,
                              ),
                            ]),
                          ]),
                        ),
                      ) : const SizedBox(),
                      SizedBox(height: partialPay ? 20 : 0),

                      !partialPay ? Row(children: [
                        Text(cod! ? 'amount_collect_from_customer'.tr : 'total_amount'.tr, style: robotoMedium.copyWith(
                          fontSize: Dimensions.fontSizeLarge, color: Theme.of(context).primaryColor,
                        )),

                        taxIncluded ? Text(' ${'vat_tax_inc'.tr}', style: robotoMedium.copyWith(
                          fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).primaryColor,
                        )) : const SizedBox(),

                        const Expanded(child: SizedBox()),

                        Text(
                          PriceConverterHelper.convertPrice(total),
                          style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeLarge, color: Theme.of(context).primaryColor),
                        ),
                      ]) : const SizedBox(),
                    ]),
                  ),*/
                              ],
                            ),
                          ),
                        ),

                        parcel
                            ? ParcelBottomView(
                                orderController: orderController,
                                controllerOrderModel: controllerOrderModel,
                                orderId: widget.orderId!,
                                fromLocationScreen: widget.fromLocationScreen,
                                showDeliveryConfirmImage:
                                    showDeliveryConfirmImage,
                                total: total,
                              )
                            : RegularOrderBottomView(
                                orderController: orderController,
                                controllerOrderModel: controllerOrderModel,
                                fromLocationScreen: widget.fromLocationScreen,
                                orderId: widget.orderId!,
                                showDeliveryConfirmImage:
                                    showDeliveryConfirmImage,
                                total: total,
                              ),
                      ],
                    )
                  : const Center(child: CircularProgressIndicator());
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCanceledOrderView(
    BuildContext context,
    OrderController orderController,
    OrderModel controllerOrderModel,
    bool parcel,
    OrderModel order,
    bool showChatPermission,
    bool isDelivered,
  ) {
    return Column(
      children: [
        // 1. id pedido - estado
        Row(
          children: [
            Text(
              '${parcel ? 'delivery_id'.tr : 'order_id'.tr}:',
              style: robotoRegular,
            ),
            const SizedBox(
              width: Dimensions.paddingSizeExtraSmall,
            ),
            Text(
              controllerOrderModel.id.toString(),
              style: robotoBold,
            ),
            const SizedBox(
              width: Dimensions.paddingSizeExtraSmall,
            ),
            const Expanded(child: SizedBox()),
            Container(
              height: 7,
              width: 7,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red,
              ),
            ),
            const SizedBox(
              width: Dimensions.paddingSizeExtraSmall,
            ),
            Text(
              controllerOrderModel.orderStatus!.tr,
              style: robotoBold,
            ),
          ],
        ),
        const SizedBox(height: Dimensions.paddingSizeLarge),

        _buildFailedDeliveryInstructionCard(context, controllerOrderModel),

        // 2. horario
        parcel &&
                order.orderStatus ==
                    AppConstants.canceled &&
                !(order
                        .parcelCancellation
                        ?.beforePickup ==
                    1)
            ? Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'return_date_and_time'.tr,
                    style: robotoRegular,
                  ),
                  Text(
                    order
                                .parcelCancellation
                                ?.returnDate !=
                            null
                        ? DateConverterHelper.dateTimeStringToDateTime(
                            order
                                .parcelCancellation!
                                .returnDate!,
                          )
                        : 'not_set_yet'.tr,
                    style: robotoRegular,
                  ),
                ],
              )
            : const SizedBox(),

        controllerOrderModel.scheduleAt!.isNotEmpty &&
                controllerOrderModel.scheduleAt != null
            ? Column(
                children: [
                  Row(
                    children: [
                      Text(
                        '${'schedule'.tr} ',
                        style: robotoRegular,
                      ),
                      const Expanded(child: SizedBox()),
                      Text(
                        DateConverterHelper.dateTimeStringToDateTime(
                          controllerOrderModel
                              .scheduleAt!,
                        ),
                        style: robotoRegular,
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: Dimensions.paddingSizeLarge,
                  ),
                ],
              )
            : const SizedBox(),

        SizedBox(
          height:
              parcel &&
                  order.orderStatus ==
                      AppConstants.canceled &&
                  !(order
                          .parcelCancellation
                          ?.beforePickup ==
                      1)
                  ? Dimensions.paddingSizeLarge
                  : 0,
        ),

        // 3. detalles de la tienda / pasajero
        InfoCardWidget(
          title: (controllerOrderModel.moduleType == 'taxi')
              ? 'Detalles del Pasajero'
              : (parcel
                  ? 'sender_details'.tr
                  : 'store_details'.tr),
          address: parcel || (controllerOrderModel.moduleType == 'taxi')
              ? controllerOrderModel.deliveryAddress
              : DeliveryAddress(
                  address:
                      controllerOrderModel.storeAddress,
                ),
          image: parcel || (controllerOrderModel.moduleType == 'taxi')
              ? ''
              : '${controllerOrderModel.storeLogoFullUrl}',
          name: (controllerOrderModel.moduleType == 'taxi')
              ? (controllerOrderModel.customer?.fName != null ? '${controllerOrderModel.customer?.fName} ${controllerOrderModel.customer?.lName ?? ''}'.trim() : 'Pasajero')
              : (parcel
                  ? controllerOrderModel
                        .deliveryAddress!
                        .contactPersonName
                  : controllerOrderModel.storeName),
          phone: parcel || (controllerOrderModel.moduleType == 'taxi')
              ? controllerOrderModel
                    .deliveryAddress!
                    .contactPersonNumber
              : controllerOrderModel.storePhone,
          latitude: parcel
              ? controllerOrderModel
                    .deliveryAddress!
                    .latitude
              : controllerOrderModel.storeLat,
          longitude: parcel
              ? controllerOrderModel
                    .deliveryAddress!
                    .longitude
              : controllerOrderModel.storeLng,
          showButton: false,
          isStore: !parcel,
          isChatAllow: false,
          showCallButton: false,
          messageOnTap: () {},
          order: order,
        ),
        const SizedBox(height: Dimensions.paddingSizeLarge),

        // 4. detalles de contacto del cliente
        InfoCardWidget(
          title: parcel
              ? 'receiver_details'.tr
              : 'customer_contact_details'.tr,
          address: parcel
              ? controllerOrderModel.receiverDetails
              : controllerOrderModel.deliveryAddress,
          image: parcel
              ? ''
              : controllerOrderModel.customer != null
              ? '${controllerOrderModel.customer!.imageFullUrl}'
              : '',
          name: parcel
              ? controllerOrderModel
                    .receiverDetails!
                    .contactPersonName
              : controllerOrderModel
                    .deliveryAddress!
                    .contactPersonName,
          phone: parcel
              ? controllerOrderModel
                    .receiverDetails!
                    .contactPersonNumber
              : controllerOrderModel
                    .deliveryAddress!
                    .contactPersonNumber,
          latitude: parcel
              ? controllerOrderModel
                    .receiverDetails!
                    .latitude
              : controllerOrderModel
                    .deliveryAddress!
                    .latitude,
          longitude: parcel
              ? controllerOrderModel
                    .receiverDetails!
                    .longitude
              : controllerOrderModel
                    .deliveryAddress!
                    .longitude,
          showButton: false,
          isStore: !parcel,
          isChatAllow: false,
          showCallButton: false,
          messageOnTap: () {},
          order: order,
        ),
        const SizedBox(height: Dimensions.paddingSizeLarge),

        // 5. informacion del articulo
        parcel
            ? Container(
                padding: const EdgeInsets.all(
                  Dimensions.paddingSizeSmall,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(
                    Dimensions.radiusSmall,
                  ),
                  boxShadow: Get.isDarkMode
                      ? null
                      : [
                          BoxShadow(
                            color: Colors.grey[200]!,
                            spreadRadius: 1,
                            blurRadius: 5,
                          ),
                        ],
                ),
                child:
                    controllerOrderModel
                            .parcelCategory !=
                        null
                    ? Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            'parcel_category'.tr,
                            style: robotoBold,
                          ),
                          const SizedBox(
                            height: Dimensions
                                .paddingSizeExtraSmall,
                          ),
                          Row(
                            children: [
                              ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(
                                      Dimensions
                                          .radiusSmall,
                                    ),
                                child: CustomImageWidget(
                                  image:
                                      '${controllerOrderModel.parcelCategory!.imageFullUrl}',
                                  height: 35,
                                  width: 35,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(
                                width: Dimensions
                                    .paddingSizeSmall,
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
                                  children: [
                                    Text(
                                      controllerOrderModel
                                          .parcelCategory!
                                          .name!,
                                      maxLines: 1,
                                      overflow:
                                          TextOverflow
                                              .ellipsis,
                                      style: robotoRegular
                                          .copyWith(
                                            fontSize:
                                                Dimensions
                                                    .fontSizeSmall,
                                          ),
                                    ),
                                    Text(
                                      controllerOrderModel
                                          .parcelCategory!
                                          .description!,
                                      maxLines: 1,
                                      overflow:
                                          TextOverflow
                                              .ellipsis,
                                      style: robotoRegular.copyWith(
                                        fontSize: Dimensions
                                            .fontSizeSmall,
                                        color: Theme.of(
                                          context,
                                        ).disabledColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    : SizedBox(
                        width: context.width,
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              'parcel_category'.tr,
                              style: robotoRegular,
                            ),
                            const SizedBox(
                              height: Dimensions
                                  .paddingSizeExtraSmall,
                            ),
                            Text(
                              'no_parcel_category_data_found'
                                  .tr,
                              style: robotoMedium,
                            ),
                          ],
                        ),
                      ),
              )
            : Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(
                    Dimensions.radiusSmall,
                  ),
                  boxShadow: Get.isDarkMode
                      ? null
                      : [
                          BoxShadow(
                            color: Colors.grey[200]!,
                            spreadRadius: 1,
                            blurRadius: 5,
                          ),
                        ],
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                child: Column(
                  spacing: 10,
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'item_info'.tr,
                      style: robotoBold.copyWith(
                        fontSize:
                            Dimensions.fontSizeDefault,
                      ),
                    ),
                    ListView.separated(
                      shrinkWrap: true,
                      physics:
                          const NeverScrollableScrollPhysics(),
                      itemCount: orderController
                          .orderDetailsModel!
                          .length,
                      itemBuilder: (context, index) {
                        return OrderItemWidget(
                          order: controllerOrderModel,
                          orderDetails: orderController
                              .orderDetailsModel![index],
                        );
                      },
                      separatorBuilder:
                          (context, index) {
                            return const Divider(height: 25);
                          },
                    ),
                  ],
                ),
              ),
        const SizedBox(height: Dimensions.paddingSizeLarge),

        // 6. ganancia neta por este viaje
        Container(
          padding: const EdgeInsets.all(
            Dimensions.paddingSizeSmall,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(
              Dimensions.radiusSmall,
            ),
            boxShadow: Get.isDarkMode
                ? null
                : [
                    BoxShadow(
                      color: Colors.grey[200]!,
                      spreadRadius: 1,
                      blurRadius: 5,
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'ganancia_neta_por_este_viaje'.tr,
                style: robotoBold.copyWith(
                  fontSize: Dimensions.fontSizeDefault,
                ),
              ),
              const SizedBox(
                height: Dimensions.paddingSizeSmall,
              ),
              Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ganancia_limpia_envio_propina'.tr,
                    style: robotoRegular,
                  ),
                  Text(
                    PriceConverterHelper.convertPrice(
                      (order.deliveryCharge ?? 0) +
                          (order.dmTips ?? 0),
                    ),
                    style: robotoMedium.copyWith(
                      fontSize:
                          Dimensions.fontSizeLarge,
                      color: Theme.of(
                        context,
                      ).primaryColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void openDialog(BuildContext context, String imageUrl) => showDialog(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
              child: PhotoView(
                tightMode: true,
                imageProvider: NetworkImage(imageUrl),
                heroAttributes: PhotoViewHeroAttributes(tag: imageUrl),
              ),
            ),

            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                splashRadius: 5,
                onPressed: () => Get.back(),
                icon: const Icon(Icons.cancel, color: Colors.red),
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget _buildFailedDeliveryInstructionCard(BuildContext context, OrderModel order) {
    final status = order.orderStatus?.toLowerCase() ?? '';
    final isNotReceived = status == 'returned' || status == 'failed' || status == 'canceled';
    
    // Solo mostrar si el pedido no fue recibido (devuelto, fallido o cancelado)
    if (!isNotReceived) {
      return const SizedBox();
    }

    final action = order.failedDeliveryAction?.toLowerCase() ?? 'return';
    final isDonation = action == 'donation' || action == 'donate';
    
    final Color cardColor = isDonation ? const Color(0xFFE0F2F1) : const Color(0xFFFFF8E1);
    final Color borderColor = isDonation ? const Color(0xFF4DB6AC) : const Color(0xFFFFD54F);
    final Color textColor = isDonation ? const Color(0xFF004D40) : const Color(0xFFFF8F00);
    final Color iconColor = isDonation ? Colors.teal : Colors.amber.shade800;
    final IconData icon = isDonation ? Icons.volunteer_activism : Icons.assignment_return;
    
    final String title = isDonation ? 'Instrucción del Administrador: Donación' : 'Instrucción del Administrador: Retornar a Tienda';
    final String instructionText = isDonation
        ? 'El cliente no recibió el pedido. El administrador ha decidido que este pedido sea DONADO. Por favor, dona los productos a una persona o institución que lo necesite. No es necesario regresarlo a la tienda.'
        : 'El cliente no recibió el pedido. Por favor, regresa los productos a la tienda o restaurante de origen: ${order.storeName ?? "la tienda"}.';
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: Dimensions.paddingSizeLarge),
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: iconColor.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 26),
              const SizedBox(width: Dimensions.paddingSizeSmall),
              Expanded(
                child: Text(
                  title,
                  style: robotoBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: textColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: Dimensions.paddingSizeSmall),
          Text(
            instructionText,
            style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeDefault, color: textColor.withValues(alpha: 0.85), height: 1.4),
          ),
          if (order.failedDeliveryInstruction != null && order.failedDeliveryInstruction!.trim().isNotEmpty) ...[
            const SizedBox(height: Dimensions.paddingSizeSmall),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                border: Border.all(color: borderColor.withValues(alpha: 0.5), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Instrucciones especiales del Administrador:',
                    style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: textColor),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    order.failedDeliveryInstruction!,
                    style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: textColor),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ParcelReceiptUploadWidget extends StatelessWidget {
  final OrderModel order;
  final OrderController orderController;
  const ParcelReceiptUploadWidget({super.key, required this.order, required this.orderController});

  @override
  Widget build(BuildContext context) {
    bool hasUploaded = order.parcelReceiptPhotos != null && order.parcelReceiptPhotos!.isNotEmpty;
    bool hasPending = orderController.pickedReceiptPhotos.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(top: Dimensions.paddingSizeLarge),
      padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
        boxShadow: Get.isDarkMode ? null : [
          BoxShadow(
            color: Colors.grey[200]!,
            spreadRadius: 1,
            blurRadius: 5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('receipt_images'.tr, style: robotoBold),
              Text('receipt_photo_limit'.tr, style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).disabledColor)),
            ],
          ),
          const SizedBox(height: Dimensions.paddingSizeSmall),

          if (hasUploaded) ...[
            Text('receipt_photos'.tr, style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall)),
            const SizedBox(height: Dimensions.paddingSizeExtraSmall),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: order.parcelReceiptPhotos!.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: Dimensions.paddingSizeSmall),
                    child: InkWell(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => Dialog(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                              child: CustomImageWidget(
                                image: order.parcelReceiptPhotos![index],
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                        child: CustomImageWidget(
                          image: order.parcelReceiptPhotos![index],
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: Dimensions.paddingSizeSmall),
          ],

          Text('add_receipt_photo'.tr, style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall)),
          const SizedBox(height: Dimensions.paddingSizeExtraSmall),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...List.generate(orderController.pickedReceiptPhotos.length, (index) {
                  return Stack(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(right: Dimensions.paddingSizeSmall),
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                          image: DecorationImage(
                            image: FileImage(File(orderController.pickedReceiptPhotos[index].path)),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 8,
                        child: InkWell(
                          onTap: () => orderController.removeReceiptPhotoAt(index),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(4),
                            child: const Icon(Icons.close, color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                    ],
                  );
                }),

                if (orderController.pickedReceiptPhotos.length < 3)
                  InkWell(
                    onTap: () {
                      Get.bottomSheet(
                        Container(
                          color: Theme.of(context).cardColor,
                          padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('select_receipt_photos'.tr, style: robotoBold),
                              const SizedBox(height: Dimensions.paddingSizeLarge),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  InkWell(
                                    onTap: () {
                                      Get.back();
                                      orderController.pickReceiptPhoto(isCamera: true, isRemove: false);
                                    },
                                    child: Column(
                                      children: [
                                        const Icon(Icons.camera_alt, size: 40),
                                        const SizedBox(height: Dimensions.paddingSizeExtraSmall),
                                        Text('camera'.tr, style: robotoMedium),
                                      ],
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () {
                                      Get.back();
                                      orderController.pickReceiptPhoto(isCamera: false, isRemove: false);
                                    },
                                    child: Column(
                                      children: [
                                        const Icon(Icons.photo, size: 40),
                                        const SizedBox(height: Dimensions.paddingSizeExtraSmall),
                                        Text('gallery'.tr, style: robotoMedium),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: Dimensions.paddingSizeLarge),
                            ],
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(context).primaryColor, style: BorderStyle.solid),
                        borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                      ),
                      child: Icon(Icons.camera_alt, color: Theme.of(context).primaryColor),
                    ),
                  ),
              ],
            ),
          ),

          if (hasPending) ...[
            const SizedBox(height: Dimensions.paddingSizeDefault),
            CustomButtonWidget(
              isLoading: orderController.isLoading,
              buttonText: 'upload_receipt'.tr,
              onPressed: () {
                orderController.uploadReceiptPhotos(order.id!);
              },
            ),
          ],
        ],
      ),
    );
  }
}
