import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart_delivery/features/profile/controllers/profile_controller.dart';
import 'package:sixam_mart_delivery/helper/price_converter_helper.dart';
import 'package:sixam_mart_delivery/util/dimensions.dart';
import 'package:sixam_mart_delivery/util/styles.dart';

class CashProgressWidget extends StatefulWidget {
  const CashProgressWidget({super.key});

  @override
  State<CashProgressWidget> createState() => _CashProgressWidgetState();
}

class _CashProgressWidgetState extends State<CashProgressWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ProfileController>(builder: (profileController) {
      final profile = profileController.profileModel;
      if (profile == null) return const SizedBox();

      double cashInHands = profile.cashInHands ?? 0;
      double limitPaid = profile.cashLimitForOnlyPaid ?? 0;
      double limitBlock = profile.cashLimitForTotalBlock ?? 0;

      if (limitPaid == 0) return const SizedBox(); // Si no hay limite configurado

      bool isOrange = cashInHands >= limitPaid && cashInHands < limitBlock;
      bool isRed = cashInHands >= limitBlock;
      bool forceExpanded = isOrange || isRed;

      bool expanded = _isExpanded || forceExpanded;

      Color statusColor = Colors.green;
      String statusText = 'Todo en orden';
      String subText = 'Falta ${PriceConverterHelper.convertPrice(limitPaid - cashInHands)} para límite de órdenes pagadas';

      if (isRed) {
        statusColor = Colors.red;
        statusText = 'Bloqueo Total';
        subText = 'Límite superado. Deposita efectivo para recibir órdenes.';
      } else if (isOrange) {
        statusColor = Colors.orange;
        statusText = 'Solo Órdenes Pagadas';
        subText = 'Falta ${PriceConverterHelper.convertPrice(limitBlock - cashInHands)} para bloqueo total';
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
          width: MediaQuery.of(context).size.width * 0.85,
          padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
            border: Border.all(color: statusColor.withValues(alpha: 0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
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
                      Icon(Icons.account_balance_wallet, color: statusColor, size: 20),
                      const SizedBox(width: Dimensions.paddingSizeSmall),
                      Text(
                        PriceConverterHelper.convertPrice(cashInHands),
                        style: robotoBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: statusColor),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        statusText,
                        style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: statusColor),
                      ),
                      if (!forceExpanded)
                        Icon(
                          expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          color: Theme.of(context).disabledColor,
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
                    backgroundColor: Theme.of(context).disabledColor.withValues(alpha: 0.2),
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
                      style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).disabledColor),
                    ),
                    Text(
                      PriceConverterHelper.convertPrice(limitPaid),
                      style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Colors.orange),
                    ),
                    Text(
                      PriceConverterHelper.convertPrice(limitBlock),
                      style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Colors.red),
                    ),
                  ],
                ),
                const SizedBox(height: Dimensions.paddingSizeSmall),
                Text(
                  subText,
                  style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).textTheme.bodyLarge!.color),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      );
    });
  }
}
