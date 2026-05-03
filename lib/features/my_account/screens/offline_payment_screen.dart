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
  final TextEditingController _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.amount.toStringAsFixed(2);
    for (var info in widget.method.methodInformations!) {
      _controllers[info.customerInput!] = TextEditingController();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
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
                      width: double.infinity,
                      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                        border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.2)),
                      ),
                      child: Column(children: [
                        const Text('Deuda total', style: robotoRegular),
                        const SizedBox(height: Dimensions.paddingSizeExtraSmall),
                        Text(
                          widget.amount.toStringAsFixed(2),
                          style: robotoBold.copyWith(fontSize: Dimensions.fontSizeOverLarge, color: Theme.of(context).primaryColor),
                        ),
                      ]),
                    ),
                    const SizedBox(height: Dimensions.paddingSizeDefault),

                    Row(children: [
                      _QuickAmountButton(
                        label: 'Pagar todo',
                        onTap: () => setState(() => _amountController.text = widget.amount.toStringAsFixed(2)),
                      ),
                      const SizedBox(width: Dimensions.paddingSizeSmall),
                      _QuickAmountButton(
                        label: 'Pagar la mitad',
                        onTap: () => setState(() => _amountController.text = (widget.amount / 2).toStringAsFixed(2)),
                      ),
                      const SizedBox(width: Dimensions.paddingSizeSmall),
                      _QuickAmountButton(
                        label: 'Otro monto',
                        onTap: () => setState(() => _amountController.clear()),
                      ),
                    ]),
                    const SizedBox(height: Dimensions.paddingSizeLarge),

                    CustomTextFieldWidget(
                      labelText: 'Monto del pago',
                      hintText: 'Monto del pago',
                      controller: _amountController,
                      inputType: TextInputType.number,
                      isRequired: true,
                      showTitle: true,
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
                buttonText: 'Enviar pago',
                onPressed: () {
                  bool isValid = true;
                  if(_amountController.text.isEmpty) {
                    showCustomSnackBar('Ingrese un monto válido');
                    isValid = false;
                  }
                  if(isValid) {
                    for (var info in widget.method.methodInformations!) {
                      if (info.isRequired == 1 && _controllers[info.customerInput!]!.text.isEmpty) {
                        showCustomSnackBar('${info.customerPlaceholder!} es obligatorio');
                        isValid = false;
                        break;
                      }
                    }
                  }

                  if (isValid) {
                    Map<String, String> data = {
                      'method_id': widget.method.id.toString(),
                      'amount': _amountController.text,
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

class _QuickAmountButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickAmountButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: Dimensions.paddingSizeSmall),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
            border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.5)),
          ),
          child: Text(label, textAlign: TextAlign.center, style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall)),
        ),
      ),
    );
  }
}
