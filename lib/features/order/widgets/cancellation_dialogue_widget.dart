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

class _CancellationDialogueWidgetState extends State<CancellationDialogueWidget> {
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

    if (hasCatalog) {
      if (orderController.selectedCancelReasonId == null) {
        showCustomSnackBar('please_select_cancellation_reason'.tr);
        return;
      }
      await orderController.updateOrderStatus(
        OrderModel(id: widget.orderId),
        AppConstants.canceled,
        back: true,
        cancelReasonId: orderController.selectedCancelReasonId,
        cancellationDetail: _detailController.text.trim().isEmpty
            ? null
            : _detailController.text.trim(),
      );
      return;
    }

    final String free = _legacyReasonController.text.trim();
    if (free.isEmpty) {
      showCustomSnackBar('please_enter_cancellation_reason'.tr);
      return;
    }
    await orderController.updateOrderStatus(
      OrderModel(id: widget.orderId),
      AppConstants.canceled,
      back: true,
      reason: free,
      cancellationDetail: _detailController.text.trim().isEmpty
          ? null
          : _detailController.text.trim(),
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
          final List<CancellationData>? reasons = orderController.orderCancelReasons;
          final bool hasCatalog = reasons != null && reasons.isNotEmpty;
          final bool loadingReasons = reasons == null;

          return SizedBox(
            width: 500,
            height: MediaQuery.of(context).size.height * 0.72,
            child: Column(
              children: [
                Container(
                  width: 500,
                  padding: const EdgeInsets.symmetric(
                    vertical: Dimensions.paddingSizeSmall,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
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
                    children: [
                      Text(
                        'select_cancellation_reasons'.tr,
                        style: robotoMedium.copyWith(
                          color: Theme.of(context).primaryColor,
                          fontSize: Dimensions.fontSizeLarge,
                        ),
                      ),
                      const SizedBox(height: Dimensions.paddingSizeExtraSmall),
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
                            itemCount: reasons.length,
                            itemBuilder: (context, index) {
                              final r = reasons[index];
                              final bool selected =
                                  orderController.selectedCancelReasonId ==
                                  r.id;
                              return ListTile(
                                dense: true,
                                onTap: () {
                                  orderController.setSelectedCancelReason(
                                    r.id,
                                    r.reason,
                                  );
                                },
                                title: Row(
                                  children: [
                                    Icon(
                                      selected
                                          ? Icons.radio_button_checked
                                          : Icons.radio_button_off,
                                      color: Theme.of(context).primaryColor,
                                      size: 18,
                                    ),
                                    const SizedBox(
                                      width: Dimensions.paddingSizeExtraSmall,
                                    ),
                                    Expanded(
                                      child: Text(
                                        r.reason ?? '',
                                        style: robotoRegular,
                                        maxLines: 4,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
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
                        const SizedBox(height: Dimensions.paddingSizeSmall),
                        TextField(
                          controller: _detailController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'dm_cancel_detail_optional'.tr,
                            hintText: 'dm_cancel_detail_hint'.tr,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: Dimensions.paddingSizeSmall),
                        Text(
                          'dm_cancel_evidence_optional'.tr,
                          style: robotoMedium.copyWith(
                            fontSize: Dimensions.fontSizeSmall,
                          ),
                        ),
                        const SizedBox(height: Dimensions.paddingSizeExtraSmall),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: orderController.isLoading
                                  ? null
                                  : () => orderController.pickCancelEvidenceImage(
                                        isCamera: true,
                                      ),
                              icon: const Icon(Icons.photo_camera_outlined, size: 18),
                              label: Text('from_camera'.tr),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: orderController.isLoading
                                  ? null
                                  : () => orderController.pickCancelEvidenceImage(
                                        isCamera: false,
                                      ),
                              icon: const Icon(Icons.photo_library_outlined, size: 18),
                              label: Text('from_gallery'.tr),
                            ),
                          ],
                        ),
                        if (orderController.pickedCancelEvidence.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: List.generate(
                                orderController.pickedCancelEvidence.length,
                                (i) {
                                  final path =
                                      orderController.pickedCancelEvidence[i].path;
                                  return Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: Image.file(
                                          File(path),
                                          width: 64,
                                          height: 64,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      Positioned(
                                        right: -6,
                                        top: -6,
                                        child: InkWell(
                                          onTap: () => orderController
                                              .removeCancelEvidenceAt(i),
                                          child: const CircleAvatar(
                                            radius: 12,
                                            backgroundColor: Colors.black54,
                                            child: Icon(
                                              Icons.close,
                                              size: 14,
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
                        const SizedBox(height: Dimensions.paddingSizeSmall),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: orderController.isLoading
                                  ? null
                                  : () => orderController.pickCancelAudio(),
                              icon: const Icon(Icons.mic_none, size: 18),
                              label: Text('dm_cancel_attach_audio'.tr),
                            ),
                            if (orderController.cancelAudioFile != null) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  orderController.cancelAudioFile!.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: robotoRegular.copyWith(fontSize: 12),
                                ),
                              ),
                              IconButton(
                                onPressed: orderController.isLoading
                                    ? null
                                    : orderController.clearCancelAudio,
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ],
                        ),
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
                              child: CustomButtonWidget(
                                buttonText: 'cancel'.tr,
                                backgroundColor:
                                    Theme.of(context).disabledColor,
                                radius: 50,
                                onPressed: () => Get.back(),
                              ),
                            ),
                            const SizedBox(width: Dimensions.paddingSizeSmall),
                            Expanded(
                              child: CustomButtonWidget(
                                buttonText: 'submit'.tr,
                                radius: 50,
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
