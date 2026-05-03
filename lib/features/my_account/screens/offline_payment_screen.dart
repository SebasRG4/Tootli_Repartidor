import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_app_bar_widget.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_button_widget.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_snackbar_widget.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_text_field_widget.dart';
import 'package:sixam_mart_delivery/features/profile/controllers/profile_controller.dart';
import 'package:sixam_mart_delivery/features/my_account/domain/models/offline_payment_method_model.dart';
import 'package:sixam_mart_delivery/util/dimensions.dart';
import 'package:sixam_mart_delivery/util/styles.dart';

class OfflinePaymentScreen extends StatefulWidget {
  final OfflinePaymentMethodModel method;
  final double amount;
  const OfflinePaymentScreen({super.key, required this.method, required this.amount});

  @override
  State<OfflinePaymentScreen> createState() => _OfflinePaymentScreenState();
}

class _OfflinePaymentScreenState extends State<OfflinePaymentScreen> {
  final Map<String, TextEditingController> _controllers = {};
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    for (var info in widget.method.methodInformations!) {
      _controllers[info.customerInput!] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBarWidget(title: widget.method.methodName!),
      body: SafeArea(
        child: GetBuilder<ProfileController>(builder: (profileController) {
          return Column(children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
                child: Form(
                  key: _formKey,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                      ),
                      child: Column(children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text('payment_amount'.tr, style: robotoRegular),
                          Text(widget.amount.toStringAsFixed(2), style: robotoBold.copyWith(color: Theme.of(context).primaryColor)),
                        ]),
                      ]),
                    ),
                    const SizedBox(height: Dimensions.paddingSizeLarge),

                    if (widget.method.methodFields != null && widget.method.methodFields!.isNotEmpty) ...[
                      Text('payment_instructions'.tr, style: robotoMedium),
                      const SizedBox(height: Dimensions.paddingSizeSmall),
                      ListView.builder(
                        itemCount: widget.method.methodFields!.length,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeExtraSmall),
                            child: Row(children: [
                              const Icon(Icons.circle, size: 8),
                              const SizedBox(width: Dimensions.paddingSizeSmall),
                              Text('${widget.method.methodFields![index].inputName!}: ${widget.method.methodFields![index].inputData!}', style: robotoRegular),
                            ]),
                          );
                        },
                      ),
                      const SizedBox(height: Dimensions.paddingSizeLarge),
                    ],

                    Text('fill_the_form_below'.tr, style: robotoMedium),
                    const SizedBox(height: Dimensions.paddingSizeSmall),

                    ListView.builder(
                      itemCount: widget.method.methodInformations!.length,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemBuilder: (context, index) {
                        MethodInformations info = widget.method.methodInformations![index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeDefault),
                          child: CustomTextFieldWidget(
                            labelText: info.customerPlaceholder!,
                            hintText: info.customerPlaceholder!,
                            controller: _controllers[info.customerInput!],
                            isRequired: info.isRequired == 1,
                            showTitle: true,
                          ),
                        );
                      },
                    ),
                  ]),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
              child: !profileController.isLoading ? CustomButtonWidget(
                buttonText: 'submit'.tr,
                onPressed: () {
                  bool isValid = true;
                  for (var info in widget.method.methodInformations!) {
                    if (info.isRequired == 1 && _controllers[info.customerInput!]!.text.isEmpty) {
                      showCustomSnackBar('${info.customerPlaceholder!} ${'is_required'.tr}');
                      isValid = false;
                      break;
                    }
                  }

                  if (isValid) {
                    Map<String, String> data = {
                      'method_id': widget.method.id.toString(),
                      'amount': widget.amount.toString(),
                    };
                    _controllers.forEach((key, controller) {
                      data[key] = controller.text;
                    });
                    profileController.makeOfflinePayment(data).then((response) {
                      if (response.isSuccess) {
                        Get.back();
                        showCustomSnackBar(response.message, isError: false);
                      } else {
                        showCustomSnackBar(response.message);
                      }
                    });
                  }
                },
              ) : const Center(child: CircularProgressIndicator()),
            ),
          ]);
        }),
      ),
    );
  }
}
