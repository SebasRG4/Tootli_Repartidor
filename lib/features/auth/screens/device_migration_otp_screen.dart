import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:sixam_mart_delivery/features/auth/controllers/auth_controller.dart';
import 'package:sixam_mart_delivery/features/profile/controllers/profile_controller.dart';
import 'package:sixam_mart_delivery/helper/route_helper.dart';
import 'package:sixam_mart_delivery/util/dimensions.dart';
import 'package:sixam_mart_delivery/util/images.dart';
import 'package:sixam_mart_delivery/util/styles.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_app_bar_widget.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_button_widget.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_snackbar_widget.dart';

class DeviceMigrationOtpScreen extends StatefulWidget {
  final String phone;
  final String password;
  const DeviceMigrationOtpScreen({super.key, required this.phone, required this.password});

  @override
  DeviceMigrationOtpScreenState createState() => DeviceMigrationOtpScreenState();
}

class DeviceMigrationOtpScreenState extends State<DeviceMigrationOtpScreen> {
  Timer? _timer;
  int _seconds = 60;
  bool _isError = false;
  String _otp = '';

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _seconds = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _seconds = _seconds - 1;
      if (_seconds == 0) {
        timer.cancel();
        _timer?.cancel();
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBarWidget(title: 'device_migration_title'.tr),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
            child: SizedBox(
              width: 1170,
              child: GetBuilder<AuthController>(builder: (authController) {
                return Column(children: [
                  Image.asset(Images.verification, height: 150),
                  const SizedBox(height: Dimensions.paddingSizeLarge),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeOverLarge),
                    child: Text(
                      'enter_the_migration_otp'.tr,
                      style: robotoRegular.copyWith(color: Theme.of(context).disabledColor),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 30),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
                    child: PinCodeTextField(
                      length: 6,
                      appContext: context,
                      keyboardType: TextInputType.number,
                      animationType: AnimationType.slide,
                      pinTheme: PinTheme(
                        shape: PinCodeFieldShape.box,
                        fieldHeight: 60,
                        fieldWidth: 50,
                        borderWidth: 0.3,
                        activeBorderWidth: 0.5,
                        disabledBorderWidth: 0.5,
                        selectedBorderWidth: 0.5,
                        inactiveBorderWidth: 0.5,
                        borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                        selectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.5),
                        selectedFillColor: Theme.of(context).cardColor,
                        inactiveFillColor: Theme.of(context).cardColor,
                        inactiveColor: Theme.of(context).disabledColor.withValues(alpha: 0.5),
                        activeColor: _isError ? Colors.red : Theme.of(context).disabledColor,
                        activeFillColor: Theme.of(context).cardColor,
                      ),
                      animationDuration: const Duration(milliseconds: 300),
                      backgroundColor: Colors.transparent,
                      enableActiveFill: true,
                      onChanged: (value) {
                        _otp = value;
                        setState(() {
                          _isError = false;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: Dimensions.paddingSizeLarge),
                  if (_isError) ...[
                    Text(
                      'invalid_otp_try_again'.tr,
                      style: robotoMedium.copyWith(color: Colors.red),
                    ),
                    const SizedBox(height: Dimensions.paddingSizeLarge),
                  ],
                  !authController.isLoading
                      ? CustomButtonWidget(
                          buttonText: 'verify_migration'.tr,
                          onPressed: _otp.length != 6
                              ? null
                              : () {
                                  authController.verifyDeviceMigration(widget.phone, widget.password, _otp).then((status) async {
                                    if (status.isSuccess) {
                                      await Get.find<ProfileController>().getProfile();
                                      Get.offAllNamed(RouteHelper.getInitialRoute());
                                    } else {
                                      setState(() {
                                        _isError = true;
                                      });
                                      showCustomSnackBar(status.message);
                                    }
                                  });
                                },
                        )
                      : const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: Dimensions.paddingSizeLarge),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(
                      'did_not_receive_the_code'.tr,
                      style: robotoRegular.copyWith(color: Theme.of(context).disabledColor),
                    ),
                    _seconds < 1
                        ? TextButton(
                            onPressed: () {
                              authController.requestDeviceMigrationOtp(widget.phone, widget.password).then((status) {
                                if (status.isSuccess) {
                                  _startTimer();
                                  showCustomSnackBar('device_migration_otp_sent'.tr, isError: false);
                                } else {
                                  showCustomSnackBar(status.message);
                                }
                              });
                            },
                            child: Text('resend_otp'.tr),
                          )
                        : Text(
                            '${'resend_otp'.tr} ($_seconds)',
                            style: robotoMedium.copyWith(color: Theme.of(context).disabledColor),
                          ),
                  ]),
                  const SizedBox(height: Dimensions.paddingSizeExtraLarge),
                  TextButton(
                    onPressed: () {
                      Get.toNamed(RouteHelper.getDeviceBlockedRoute(phone: widget.phone, lostNumber: true));
                    },
                    child: Text(
                      '¿Perdiste tu número o necesitas ayuda? Contactar a Soporte'.tr,
                      style: robotoBold.copyWith(
                        color: Theme.of(context).primaryColor,
                        fontSize: Dimensions.fontSizeDefault,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ]);
              }),
            ),
          ),
        ),
      ),
    );
  }
}
