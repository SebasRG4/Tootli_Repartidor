import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart_delivery/features/profile/controllers/profile_controller.dart';
import 'package:sixam_mart_delivery/helper/price_converter_helper.dart';
import 'package:sixam_mart_delivery/util/dimensions.dart';
import 'package:sixam_mart_delivery/util/styles.dart';
import 'package:sixam_mart_delivery/features/my_account/widgets/offline_payment_bottom_sheet_widget.dart';

class CashProgressWidget extends StatefulWidget {
  const CashProgressWidget({super.key});

  @override
  State<CashProgressWidget> createState() => _CashProgressWidgetState();
}

class _CashProgressWidgetState extends State<CashProgressWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ProfileController>(
      builder: (profileController) {
        final profile = profileController.profileModel;
        if (profile == null) return const SizedBox();

        double cashInHands = profile.cashInHands ?? 0;
        double limitPaid = profile.cashLimitForOnlyPaid ?? 0;
        double limitBlock = profile.cashLimitForTotalBlock ?? 0;

        if (limitPaid == 0) {
          return const SizedBox(); // Si no hay limite configurado
        }

        bool isOrange = cashInHands >= limitPaid && cashInHands < limitBlock;
        bool isRed = cashInHands >= limitBlock;
        bool forceExpanded = isOrange || isRed;

        bool expanded = _isExpanded || forceExpanded;

        Color statusColor = Colors.green;
        String statusText = 'Todo en orden';
        String subText =
            'Falta ${PriceConverterHelper.convertPrice(limitPaid - cashInHands)} para límite de órdenes pagadas';

        if (isRed) {
          statusColor = Colors.red;
          statusText = 'Bloqueo Total';
          subText = 'Límite superado. Deposita efectivo para recibir órdenes.';
        } else if (isOrange) {
          statusColor = Colors.orange;
          statusText = 'Solo Órdenes Pagadas';
          subText =
              'Falta ${PriceConverterHelper.convertPrice(limitBlock - cashInHands)} para bloqueo total';
        }

        double progress = 0;
        if (limitBlock > 0) {
          progress = cashInHands / limitBlock;
          if (progress > 1.0) progress = 1.0;
        }

        return GestureDetector(
          onTap: () {
            if (!forceExpanded) {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            decoration: BoxDecoration(
              color: const Color(0xFF0F161E), // Dark container background
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: statusColor,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.account_balance_wallet_outlined,
                            color: statusColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Balance',
                              style: robotoRegular.copyWith(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              PriceConverterHelper.convertPrice(cashInHands),
                              style: robotoBold.copyWith(
                                fontSize: 22,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          statusText,
                          style: robotoMedium.copyWith(
                            fontSize: 14,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          color: statusColor,
                          size: 20,
                        ),
                      ],
                    ),
                  ],
                ),

                if (expanded) ...[
                  const SizedBox(height: Dimensions.paddingSizeDefault),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: Dimensions.paddingSizeSmall),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '0',
                        style: robotoRegular.copyWith(
                          fontSize: Dimensions.fontSizeExtraSmall,
                          color: Colors.white38,
                        ),
                      ),
                      Text(
                        PriceConverterHelper.convertPrice(limitPaid),
                        style: robotoRegular.copyWith(
                          fontSize: Dimensions.fontSizeExtraSmall,
                          color: Colors.orange,
                        ),
                      ),
                      Text(
                        PriceConverterHelper.convertPrice(limitBlock),
                        style: robotoRegular.copyWith(
                          fontSize: Dimensions.fontSizeExtraSmall,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Dimensions.paddingSizeSmall),
                  Text(
                    subText,
                    style: robotoRegular.copyWith(
                      fontSize: Dimensions.fontSizeSmall,
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (cashInHands > 0) ...[
                    const SizedBox(height: Dimensions.paddingSizeDefault),
                    InkWell(
                      onTap: () {
                        showModalBottomSheet(
                          isScrollControlled: true,
                          useRootNavigator: true,
                          context: context,
                          backgroundColor: Colors.white,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(
                                Dimensions.radiusExtraLarge,
                              ),
                              topRight: Radius.circular(
                                Dimensions.radiusExtraLarge,
                              ),
                            ),
                          ),
                          builder: (context) {
                            return ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight:
                                    MediaQuery.of(context).size.height * 0.8,
                              ),
                              child: OfflinePaymentBottomSheetWidget(
                                amount: cashInHands,
                              ),
                            );
                          },
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: Dimensions.paddingSizeSmall,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          borderRadius: BorderRadius.circular(
                            Dimensions.radiusSmall,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Pagar',
                          style: robotoMedium.copyWith(
                            color: Colors.white,
                            fontSize: Dimensions.fontSizeSmall,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
