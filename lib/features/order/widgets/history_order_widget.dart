import 'package:sixam_mart_delivery/features/order/domain/models/order_model.dart';
import 'package:sixam_mart_delivery/helper/date_converter_helper.dart';
import 'package:sixam_mart_delivery/util/dimensions.dart';
import 'package:sixam_mart_delivery/util/images.dart';
import 'package:sixam_mart_delivery/util/styles.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_image_widget.dart';
import 'package:sixam_mart_delivery/features/order/screens/order_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../screens/order_status.dart';

class HistoryOrderWidget extends StatelessWidget {
  final OrderModel orderModel;
  final bool isRunning;
  final int index;
  const HistoryOrderWidget({super.key, required this.orderModel, required this.isRunning, required this.index});

  @override
  Widget build(BuildContext context) {
    bool parcel = orderModel.orderType == 'parcel';
    bool isTaxi = orderModel.moduleType == 'taxi';

    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => OrderDetailsScreen(orderId: orderModel.id, isRunningOrder: isRunning, orderIndex: index))),
      child: Container(
        padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
        margin: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          boxShadow: Get.isDarkMode ? null : [BoxShadow(color: Colors.grey[200]!, spreadRadius: 1, blurRadius: 5)],
          borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
        ),
        child: Row(children: [

          // Image of the card
          // Container(
          //   height: 70, width: 70, alignment: Alignment.center,
          //   decoration: parcel ? BoxDecoration(
          //     borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
          //     color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
          //   ) : null,
          //   child: ClipRRect(
          //     borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
          //     child: CustomImageWidget(
          //       image: parcel ? '${orderModel.parcelCategory != null ? orderModel.parcelCategory!.imageFullUrl : ''}' : orderModel.storeLogoFullUrl ?? '',
          //       height: parcel ? 45 : 70, width: parcel ? 45 : 70, fit: BoxFit.cover,
          //     ),
          //   ),
          // ),
          // const SizedBox(width: Dimensions.paddingSizeSmall),

          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('order'.tr, style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall)),
                const SizedBox(width: Dimensions.paddingSizeExtraSmall),
                Text('#${orderModel.id}', style: robotoBold.copyWith(fontSize: Dimensions.fontSizeSmall)),
                Expanded(
                  child: (orderModel.detailsCount ?? 0) > 0 ? Text(' (${orderModel.detailsCount} ${ (orderModel.detailsCount ?? 0) > 1 ?'items'.tr : "item".tr})', style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall)) : SizedBox(),
                ),
                if (orderModel.transactionReference != null)
                  Container(
                    margin: const EdgeInsets.only(right: Dimensions.paddingSizeExtraSmall),
                    padding: const EdgeInsets.symmetric(vertical: 2, horizontal: Dimensions.paddingSizeExtraSmall),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                      color: Colors.blue.withValues(alpha: 0.1),
                      border: Border.all(color: Colors.blue, width: 0.5),
                    ),
                    child: Text('${'misma_direccion'.tr} (#${orderModel.transactionReference})', style: robotoMedium.copyWith(fontSize: 10, color: Colors.blue)),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: Dimensions.paddingSizeExtraSmall, horizontal: Dimensions.paddingSizeSmall),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                    color: (orderModel.orderStatus == 'canceled' || orderModel.orderStatus == 'failed') ? Colors.red.withValues(alpha: 0.2) : orderModel.orderStatus == 'returned' ? Colors.orangeAccent.withValues(alpha: 0.2) : orderModel.orderStatus == 'handover' ? Colors.blueAccent.withValues(alpha: 0.2) :  Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  ),
                  child: Text(getOrderStatus(orderModel.orderStatus!),
                      style: robotoMedium.copyWith(
                    fontSize: Dimensions.fontSizeExtraSmall,
                      color: (orderModel.orderStatus == 'canceled' || orderModel.orderStatus == 'failed') ? Colors.red : orderModel.orderStatus == 'returned' ? Colors.orangeAccent : orderModel.orderStatus == 'handover' ? Colors.blueAccent : Theme.of(context).primaryColor,
                  )),
                ) ,
              ]),
              const SizedBox(height: Dimensions.paddingSizeExtraSmall),
                Text(
                  DateConverterHelper.dateTimeStringToDateTime(orderModel.createdAt!),
                  style: robotoRegular.copyWith(color: Theme.of(context).disabledColor, fontSize: Dimensions.fontSizeSmall),
                ),
              const SizedBox(height: Dimensions.paddingSizeExtraSmall),
              Divider(thickness: 1, color: Theme.of(context).disabledColor.withValues(alpha: 0.1)),

              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                isTaxi ? Row(
                  children: [
                    Icon(Icons.local_taxi_rounded, size: 16, color: Theme.of(context).disabledColor),
                    SizedBox(width: Dimensions.paddingSizeExtraSmall),
                    Text(
                       (orderModel.customer?.fName != null ? '${orderModel.customer?.fName} ${orderModel.customer?.lName ?? ''}'.trim() : 'Pasajero'),
                      style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).disabledColor),
                    ),
                  ],
                ) : parcel ? Row(
                  children: [
                    orderModel.parcelCategory!.name == 'Gifts' ? Image.asset(Images.giftIcon, width: 16) : Icon(Icons.store_mall_directory, size: 16, color:  Theme.of(context).disabledColor),
                    SizedBox(width: Dimensions.paddingSizeExtraSmall),
                    Text(
                       orderModel.parcelCategory != null ? orderModel.parcelCategory!.name! : 'no_parcel_category_data_found'.tr ,
                      style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).disabledColor),
                    ),
                  ],
                ) : Row(
                  children: [
                    Icon(Icons.store_mall_directory, size: 16, color:  Theme.of(context).disabledColor),
                    SizedBox(width: Dimensions.paddingSizeExtraSmall),
                    Text(orderModel.storeName ?? 'no_store_data_found'.tr,
                    style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).disabledColor),),
                  ],
                ) ,
                Container(
                  padding: EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeSmall, vertical: Dimensions.paddingSizeExtraSmall),
                  decoration: BoxDecoration(
                    color: Theme.of(context).disabledColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                  ),
                  child: Text(isTaxi ? 'viaje'.tr : orderModel.moduleType == 'parcel' ? 'parcel'.tr : orderModel.moduleType == 'food' ? 'food'.tr : orderModel.moduleType == 'grocery' ? 'grocery'.tr : orderModel.moduleType == 'pharmacy' ? 'pharmacy'.tr : orderModel.moduleType!,
                    style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).disabledColor),
                  ),
                ),

              ]),

            ]),
          ),

        ]),
      ),
    );
  }
}
