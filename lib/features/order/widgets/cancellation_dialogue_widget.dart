import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_button_widget.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_snackbar_widget.dart';
import 'package:sixam_mart_delivery/features/order/controllers/order_controller.dart';
import 'package:sixam_mart_delivery/features/order/domain/models/order_cancellation_body.dart';
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
        borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      child: GetBuilder<OrderController>(
        builder: (orderController) {
          final List<CancellationData>? reasons =
              orderController.orderCancelReasons;
          final bool hasCatalog = reasons != null && reasons.isNotEmpty;
          final bool loadingReasons = reasons == null;

          return Container(
            width: 500,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Premium Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 24,
                    horizontal: 20,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.red.shade700, Colors.red.shade500],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.report_problem_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Solicitar Cancelación'.toUpperCase(),
                        style: robotoBold.copyWith(
                          fontSize: 20,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'El equipo de soporte evaluará tu solicitud',
                        style: robotoRegular.copyWith(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),

                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Selecciona el motivo:',
                          style: robotoMedium.copyWith(
                            fontSize: 16,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                        const SizedBox(height: 16),

                        if (loadingReasons)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (hasCatalog)
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: reasons.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 12),
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
                                borderRadius: BorderRadius.circular(15),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? Theme.of(
                                            context,
                                          ).primaryColor.withOpacity(0.08)
                                        : Theme.of(context).cardColor,
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(
                                      color: selected
                                          ? Theme.of(context).primaryColor
                                          : Theme.of(
                                              context,
                                            ).disabledColor.withOpacity(0.1),
                                      width: selected ? 2 : 1,
                                    ),
                                    boxShadow: selected
                                        ? [
                                            BoxShadow(
                                              color: Theme.of(
                                                context,
                                              ).primaryColor.withOpacity(0.1),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              r.reason ?? '',
                                              style: robotoMedium.copyWith(
                                                color: selected
                                                    ? Theme.of(
                                                        context,
                                                      ).primaryColor
                                                    : Theme.of(context)
                                                          .textTheme
                                                          .bodyLarge
                                                          ?.color,
                                                fontSize: 15,
                                              ),
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
                                                    color:
                                                        Colors.green.shade600,
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Icon(
                                        selected
                                            ? Icons.check_circle_rounded
                                            : Icons.circle_outlined,
                                        color: selected
                                            ? Theme.of(context).primaryColor
                                            : Theme.of(
                                                context,
                                              ).disabledColor.withOpacity(0.3),
                                        size: 24,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          )
                        else
                          TextField(
                            controller: _legacyReasonController,
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText: 'Escribe el motivo aquí...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Theme.of(
                                context,
                              ).disabledColor.withOpacity(0.05),
                            ),
                          ),

                        const SizedBox(height: 24),
                        Text(
                          'Detalles adicionales (Opcional)',
                          style: robotoMedium.copyWith(fontSize: 16),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _detailController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText:
                                'Ej. Accidente vehicular, llanta ponchada...',
                            hintStyle: robotoRegular.copyWith(
                              color: Theme.of(context).hintColor,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Theme.of(
                                  context,
                                ).disabledColor.withOpacity(0.2),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Theme.of(context).primaryColor,
                                width: 2,
                              ),
                            ),
                            filled: true,
                            fillColor: Theme.of(context).cardColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Footer Buttons
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: !orderController.isLoading
                      ? Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Get.back(),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  side: BorderSide(
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                                child: Text(
                                  'Volver'.tr,
                                  style: robotoBold.copyWith(
                                    color: Theme.of(context).primaryColor,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: CustomButtonWidget(
                                buttonText: 'Enviar Solicitud',
                                height: 50,
                                radius: 12,

                                onPressed: loadingReasons
                                    ? null
                                    : () => _submit(orderController),
                              ),
                            ),
                          ],
                        )
                      : const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
