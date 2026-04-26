import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_button_widget.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_snackbar_widget.dart';
import 'package:sixam_mart_delivery/features/order/controllers/order_controller.dart';
import 'package:sixam_mart_delivery/features/order/domain/models/order_cancellation_body.dart';
import 'package:sixam_mart_delivery/features/order/domain/models/order_model.dart';
import 'package:sixam_mart_delivery/util/app_constants.dart';
import 'package:sixam_mart_delivery/util/dimensions.dart';
import 'package:sixam_mart_delivery/util/styles.dart';

class CancellationDialogueWidget extends StatefulWidget {
  final int? orderId;
  const CancellationDialogueWidget({super.key, required this.orderId});

  @override
  State<CancellationDialogueWidget> createState() =>
      _CancellationDialogueWidgetState();
}

class _CancellationDialogueWidgetState
    extends State<CancellationDialogueWidget> {
  late final TextEditingController _detailController;
  late final TextEditingController _legacyReasonController;

  @override
  void initState() {
    super.initState();
    _detailController = TextEditingController();
    _legacyReasonController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Get.find<OrderController>().getOrderCancelReasons();
      }
    });
  }

  @override
  void dispose() {
    _detailController.dispose();
    _legacyReasonController.dispose();
    super.dispose();
  }

  Future<void> _submit(OrderController orderController) async {
    final List<CancellationData>? reasons = orderController.orderCancelReasons;
    final bool hasCatalog = reasons != null && reasons.isNotEmpty;

    if (widget.orderId == null) {
      return;
    }

    String reasonText = '';

    if (hasCatalog) {
      if (orderController.selectedCancelReasonId == null) {
        showCustomSnackBar('please_select_cancellation_reason'.tr);
        return;
      }
      final r = reasons.firstWhereOrNull(
        (element) => element.id == orderController.selectedCancelReasonId,
      );
      reasonText = r?.reason ?? '';
    } else {
      final String free = _legacyReasonController.text.trim();
      if (free.isEmpty) {
        showCustomSnackBar('please_enter_cancellation_reason'.tr);
        return;
      }
      reasonText = free;
    }

    if (_detailController.text.trim().isNotEmpty) {
      reasonText += ' - Detalles: ${_detailController.text.trim()}';
    }

    Get.back();

    await orderController.openAdminSupportChatForCancelRequest(
      orderId: widget.orderId!,
      cancellationReason: reasonText,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
      ),
      insetPadding: const EdgeInsets.all(30),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      child: GetBuilder<OrderController>(
        builder: (orderController) {
          final List<CancellationData>? reasons =
              orderController.orderCancelReasons;
          final bool hasCatalog = reasons != null && reasons.isNotEmpty;
          final bool loadingReasons = reasons == null;

          return SizedBox(
            width: 500,
            height: MediaQuery.of(context).size.height * 0.72,
            child: Column(
              children: [
                Container(
                  width: 500,
                  padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.05),
                    border: Border(
                      bottom: BorderSide(color: Colors.red.withOpacity(0.1)),
                    ),
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
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Dimensions.paddingSizeSmall,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (loadingReasons)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (hasCatalog)
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                              vertical: Dimensions.paddingSizeSmall,
                            ),
                            itemCount: reasons.length,
                            itemBuilder: (context, index) {
                              final r = reasons[index];
                              final bool selected =
                                  orderController.selectedCancelReasonId ==
                                  r.id;
                              return InkWell(
                                onTap: () {
                                  orderController.setSelectedCancelReason(
                                    r.id,
                                    r.reason,
                                  );
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 15,
                                    vertical: 12,
                                  ),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? Theme.of(
                                            context,
                                          ).primaryColor.withOpacity(0.05)
                                        : Theme.of(context).cardColor,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: selected
                                          ? Theme.of(context).primaryColor
                                          : Theme.of(
                                              context,
                                            ).disabledColor.withOpacity(0.2),
                                      width: selected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              r.reason ?? '',
                                              style: robotoRegular.copyWith(
                                                color: selected
                                                    ? Theme.of(
                                                        context,
                                                      ).primaryColor
                                                    : Theme.of(context)
                                                          .textTheme
                                                          .bodyLarge
                                                          ?.color
                                                          ?.withOpacity(0.8),
                                                fontWeight: selected
                                                    ? FontWeight.w600
                                                    : FontWeight.w400,
                                                fontSize: 14,
                                              ),
                                              maxLines: 4,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (r.exemptStrikeReview)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 4,
                                                ),
                                                child: Text(
                                                  'dm_cancel_exempt_strike_review_hint'
                                                      .tr,
                                                  style: robotoRegular.copyWith(
                                                    fontSize: 11,
                                                    color: Theme.of(
                                                      context,
                                                    ).hintColor,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (selected)
                                        Icon(
                                          Icons.check_circle,
                                          color: Theme.of(context).primaryColor,
                                          size: 22,
                                        )
                                      else
                                        Icon(
                                          Icons.radio_button_unchecked,
                                          color: Theme.of(
                                            context,
                                          ).disabledColor.withOpacity(0.5),
                                          size: 22,
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.only(
                              top: Dimensions.paddingSizeSmall,
                            ),
                            child: TextField(
                              controller: _legacyReasonController,
                              maxLines: 3,
                              decoration: InputDecoration(
                                labelText:
                                    'dm_cancel_legacy_reason_required'.tr,
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                        const SizedBox(height: Dimensions.paddingSizeDefault),
                        Text(
                          'Detalles adicionales (opcional)',
                          style: robotoMedium.copyWith(
                            fontSize: Dimensions.fontSizeDefault,
                          ),
                        ),
                        const SizedBox(height: Dimensions.paddingSizeSmall),
                        TextField(
                          controller: _detailController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'Describe brevemente la situación...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                Dimensions.radiusDefault,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: Dimensions.paddingSizeSmall),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Dimensions.fontSizeDefault,
                    vertical: Dimensions.paddingSizeSmall,
                  ),
                  child: !orderController.isLoading
                      ? Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => Get.back(),
                                child: Text(
                                  'continue_delivery'.tr,
                                  style: robotoMedium.copyWith(
                                    fontSize: Dimensions.fontSizeLarge,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: Dimensions.paddingSizeSmall),
                            Expanded(
                              child: CustomButtonWidget(
                                buttonText: 'Contactar a Soporte',

                                radius: Dimensions.radiusDefault,
                                onPressed: loadingReasons
                                    ? null
                                    : () => _submit(orderController),
                              ),
                            ),
                          ],
                        )
                      : const Center(child: CircularProgressIndicator()),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
