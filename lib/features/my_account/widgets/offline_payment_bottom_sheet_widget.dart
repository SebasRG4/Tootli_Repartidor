import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart_delivery/features/profile/controllers/profile_controller.dart';
import 'package:sixam_mart_delivery/features/my_account/domain/models/offline_payment_method_model.dart';
import 'package:sixam_mart_delivery/features/my_account/screens/offline_payment_screen.dart';
import 'package:sixam_mart_delivery/util/dimensions.dart';
import 'package:sixam_mart_delivery/util/styles.dart';

class OfflinePaymentBottomSheetWidget extends StatefulWidget {
  final double amount;
  const OfflinePaymentBottomSheetWidget({super.key, required this.amount});

  @override
  State<OfflinePaymentBottomSheetWidget> createState() => _OfflinePaymentBottomSheetWidgetState();
}

class _OfflinePaymentBottomSheetWidgetState extends State<OfflinePaymentBottomSheetWidget> {

  @override
  void initState() {
    super.initState();
    Get.find<ProfileController>().getOfflinePaymentMethodList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(Dimensions.radiusExtraLarge)),
      ),
      child: GetBuilder<ProfileController>(builder: (profileController) {
        return Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            height: 5, width: 50,
            decoration: BoxDecoration(
              color: Theme.of(context).disabledColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
            ),
          ),
          const SizedBox(height: Dimensions.paddingSizeLarge),

          Text('select_offline_payment_method'.tr, style: robotoBold.copyWith(fontSize: Dimensions.fontSizeLarge)),
          const SizedBox(height: Dimensions.paddingSizeLarge),

          profileController.offlinePaymentMethods != null ? profileController.offlinePaymentMethods!.isNotEmpty ? ListView.builder(
            itemCount: profileController.offlinePaymentMethods!.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              OfflinePaymentMethodModel method = profileController.offlinePaymentMethods![index];
              return InkWell(
                onTap: () {
                  Get.back();
                  Get.to(() => OfflinePaymentScreen(method: method, amount: widget.amount));
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
                  padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                    border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.1)),
                  ),
                  child: Row(children: [
                    Icon(Icons.account_balance_wallet_outlined, color: Theme.of(context).primaryColor),
                    const SizedBox(width: Dimensions.paddingSizeSmall),
                    Text(method.methodName!, style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeDefault)),
                    const Spacer(),
                    Icon(Icons.arrow_forward_ios, size: 14, color: Theme.of(context).disabledColor),
                  ]),
                ),
              );
            },
          ) : Center(child: Text('no_offline_payment_method_available'.tr)) : const Center(child: CircularProgressIndicator()),
          const SizedBox(height: Dimensions.paddingSizeLarge),
        ]);
      }),
    );
  }
}
