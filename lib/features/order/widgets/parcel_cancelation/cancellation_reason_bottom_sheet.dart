import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_bottom_sheet_widget.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_button_widget.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_snackbar_widget.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_text_field_widget.dart';
import 'package:sixam_mart_delivery/features/order/controllers/order_controller.dart';
import 'package:sixam_mart_delivery/features/order/domain/models/order_model.dart';
import 'package:sixam_mart_delivery/features/order/widgets/parcel_cancelation/custom_check_box_widget.dart';
import 'package:sixam_mart_delivery/features/order/widgets/parcel_cancelation/parcel_return_date_time_bottom_sheet.dart';
import 'package:sixam_mart_delivery/util/app_constants.dart';
import 'package:sixam_mart_delivery/util/dimensions.dart';
import 'package:sixam_mart_delivery/util/styles.dart';

class CancellationReasonBottomSheet extends StatefulWidget {
  final bool isBeforePickup;
  final int orderId;
  const CancellationReasonBottomSheet({
    super.key,
    required this.isBeforePickup,
    required this.orderId,
  });

  @override
  State<CancellationReasonBottomSheet> createState() =>
      _CancellationReasonBottomSheetState();
}

class _CancellationReasonBottomSheetState
    extends State<CancellationReasonBottomSheet> {
  TextEditingController commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Get.find<OrderController>().clearSelectedParcelCancelReason();
    Get.find<OrderController>().getParcelCancellationReasons(
      isBeforePickup: widget.isBeforePickup,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<OrderController>(
      builder: (orderController) {
        return Container(
          width: context.width,
          padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(
                  left: Dimensions.paddingSizeSmall,
                  right: Dimensions.paddingSizeSmall,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        height: 5,
                        width: 40,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).disabledColor.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(
                            Dimensions.radiusDefault,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: Dimensions.paddingSizeLarge),

                    Container(
                      padding: const EdgeInsets.all(
                        Dimensions.paddingSizeDefault,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(
                          Dimensions.radiusDefault,
                        ),
                        border: Border.all(color: Colors.red.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.red,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: Dimensions.paddingSizeSmall),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Solicitar Cancelación',
                                  style: robotoBold.copyWith(
                                    fontSize: Dimensions.fontSizeLarge,
                                    color: Colors.red,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'El equipo de soporte evaluará tu solicitud.',
                                  style: robotoRegular.copyWith(
                                    fontSize: Dimensions.fontSizeSmall,
                                    color: Theme.of(context).disabledColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Dimensions.paddingSizeLarge),

                    orderController.parcelCancellationReasons != null &&
                            orderController
                                .parcelCancellationReasons!
                                .isNotEmpty
                        ? Text(
                            'Motivo principal',
                            style: robotoBold.copyWith(
                              fontSize: Dimensions.fontSizeLarge,
                            ),
                          )
                        : SizedBox(),

                    orderController.parcelCancellationReasons != null
                        ? orderController.parcelCancellationReasons!.isNotEmpty
                              ? Flexible(
                                  child: ListView.builder(
                                    padding: const EdgeInsets.symmetric(
                                      vertical:
                                          Dimensions.paddingSizeExtraSmall,
                                    ),
                                    shrinkWrap: true,
                                    itemCount: orderController
                                        .parcelCancellationReasons
                                        ?.length,
                                    itemBuilder: (context, index) {
                                      final reason = orderController
                                          .parcelCancellationReasons?[index];
                                      return CustomCheckBoxWidget(
                                        title: reason?.reason ?? '',
                                        value: orderController
                                            .isReasonSelected(
                                              reason?.reason ?? '',
                                            ),
                                        onClick: (bool? selected) {
                                          orderController
                                              .toggleParcelCancelReason(
                                                reason!.reason!,
                                                selected ?? false,
                                              );
                                        },
                                      );
                                    },
                                  ),
                                )
                              : SizedBox()
                        : const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: Dimensions.paddingSizeDefault,
                              ),
                              child: CircularProgressIndicator(),
                            ),
                          ),

                    const SizedBox(height: Dimensions.paddingSizeSmall),
                    Text(
                      'Detalles adicionales (opcional)',
                      style: robotoMedium.copyWith(
                        fontSize: Dimensions.fontSizeDefault,
                      ),
                    ),
                    const SizedBox(height: Dimensions.paddingSizeSmall),

                    CustomTextFieldWidget(
                      controller: commentController,
                      hintText: 'Describe brevemente la situación...',
                      showLabelText: false,
                      maxLines: 3,
                      inputType: TextInputType.multiline,
                      inputAction: TextInputAction.done,
                      capitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: Dimensions.paddingSizeExtraLarge),

                    CustomButtonWidget(
                      buttonText: 'Contactar a Soporte',
                      fontColor: Colors.white,
                      isLoading: orderController.isLoading,
                      onPressed: () async {
                        if ((orderController.selectedParcelCancelReason !=
                                    null &&
                                orderController
                                    .selectedParcelCancelReason!
                                    .isNotEmpty) ||
                            commentController.text.isNotEmpty) {
                          String reasonText =
                              orderController.selectedParcelCancelReason?.join(
                                ', ',
                              ) ??
                              '';
                          if (commentController.text.trim().isNotEmpty) {
                            reasonText +=
                                ' - Detalles: ${commentController.text.trim()}';
                          }
                          Get.back();
                          await orderController
                              .openAdminSupportChatForCancelRequest(
                                orderId: widget.orderId,
                                cancellationReason: reasonText,
                              );
                        } else {
                          showCustomSnackBar(
                            'Por favor selecciona un motivo o escribe un comentario',
                          );
                        }
                      },
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: Dimensions.paddingSizeLarge,
                      ),
                      child: InkWell(
                        onTap: () => Get.back(),
                        child: Center(
                          child: Text(
                            'continue_delivery'.tr,
                            style: robotoMedium.copyWith(
                              fontSize: Dimensions.fontSizeLarge,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Positioned(
                top: 0,
                right: 0,
                child: InkWell(
                  onTap: () => Get.back(),
                  child: Icon(
                    Icons.clear,
                    color: Theme.of(context).disabledColor,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
