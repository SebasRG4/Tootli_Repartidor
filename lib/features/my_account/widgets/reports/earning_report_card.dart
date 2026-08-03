import 'package:flutter/material.dart';
import 'package:get/get_utils/src/extensions/internacionalization.dart';
import 'package:intl/intl.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_bottom_sheet_widget.dart';
import 'package:sixam_mart_delivery/features/my_account/controllers/my_account_controller.dart';
import 'package:sixam_mart_delivery/features/my_account/domain/models/earning_report_model.dart';
import 'package:sixam_mart_delivery/features/my_account/domain/models/loyalty_report_model.dart';
import 'package:sixam_mart_delivery/features/my_account/domain/models/referral_report_model.dart';
import 'package:sixam_mart_delivery/features/my_account/widgets/earning_history_bottom_sheet.dart';
import 'package:sixam_mart_delivery/features/my_account/widgets/loyalty_history_bottom_sheet.dart';
import 'package:sixam_mart_delivery/features/my_account/widgets/referral_history_bottom_sheet.dart';
import 'package:sixam_mart_delivery/helper/price_converter_helper.dart';
import 'package:sixam_mart_delivery/util/styles.dart';

class EarningReportCard extends StatelessWidget {
  final int index;
  final MyAccountController myAccountController;
  final Data? earning;
  final String createdAt;
  final bool showDivider;
  final RefrealEarnings? refrealEarnings;
  final LoyalityPoints? loyalityPoints;
  const EarningReportCard({
    super.key,
    required this.index,
    required this.myAccountController,
    required this.earning,
    required this.createdAt,
    required this.showDivider,
    required this.refrealEarnings,
    required this.loyalityPoints,
  });

  @override
  Widget build(BuildContext context) {
    double amount = 0;
    bool isOrder = earning != null;
    bool isReferral = refrealEarnings != null;
    bool isLoyalty = loyalityPoints != null;

    if (isOrder) {
      amount = (earning!.dmTips ?? 0) + (earning!.originalDeliveryCharge ?? 0);
    } else if (isReferral) {
      amount = refrealEarnings!.amount ?? 0;
    } else if (isLoyalty) {
      amount = loyalityPoints!.convertedAmount ?? 0;
    }

    DateTime parsedDate = DateTime.parse(createdAt).toLocal();
    String formattedDate = DateFormat('dd MMM, yyyy').format(parsedDate);
    String formattedTime = DateFormat('h:mm a').format(parsedDate);

    IconData iconData = Icons.shopping_bag_outlined;
    String mainTitle = '';
    String subtitle = '';

    if (isOrder) {
      iconData = Icons.shopping_bag_outlined;
      mainTitle = '${'order'.tr} #${earning!.order?.id}';
      subtitle = 'delivery_fee'.tr;
      if (earning?.dmTips != 0) {
        subtitle += ' & ${'delivery_tips'.tr}';
      }
    } else if (isReferral) {
      iconData = Icons.people_outline;
      mainTitle = '${'transaction_id'.tr} #${refrealEarnings!.transactionId}';
      subtitle = 'referral'.tr;
    } else if (isLoyalty) {
      iconData = Icons.stars_outlined;
      mainTitle = '${'transaction_id'.tr} #${loyalityPoints!.transactionId}';
      subtitle = loyalityPoints!.transactionType?.tr ?? '';
    }

    return InkWell(
      onTap: () {
        if (isOrder) {
          showCustomBottomSheet(child: EarningHistoryBottomSheet(data: earning));
        } else if (isReferral) {
          showCustomBottomSheet(child: ReferralHistoryBottomSheet(refrealEarnings: refrealEarnings));
        } else if (isLoyalty) {
          showCustomBottomSheet(child: LoyaltyHistoryBottomSheet(loyalityPoints: loyalityPoints));
        }
      },
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Row(
              children: [
                // Left Icon Circle
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141922),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
                  ),
                  child: Icon(
                    iconData,
                    color: const Color(0xFF5EC44B),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),

                // Transaction Details (Value and Subtitles)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Amount
                      Text(
                        PriceConverterHelper.convertPrice(amount),
                        style: robotoBold.copyWith(
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 3),
                      // Main Title (Order/Tx ID)
                      Text(
                        mainTitle,
                        style: robotoRegular.copyWith(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Subtitle (delivery fee, etc.)
                      Text(
                        subtitle,
                        style: robotoRegular.copyWith(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),

                // Date, Time and Arrow
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formattedDate,
                          style: robotoRegular.copyWith(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formattedTime,
                          style: robotoRegular.copyWith(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    // Chevron button
                    Container(
                      height: 32,
                      width: 32,
                      decoration: const BoxDecoration(
                        color: Color(0xFF141922),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chevron_right,
                        color: Colors.white70,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (showDivider)
            Divider(
              color: Colors.white.withValues(alpha: 0.05),
              height: 1,
              thickness: 1,
            ),
        ],
      ),
    );
  }
}
