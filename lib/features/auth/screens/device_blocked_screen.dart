import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:sixam_mart_delivery/features/splash/controllers/splash_controller.dart';
import 'package:sixam_mart_delivery/util/dimensions.dart';
import 'package:sixam_mart_delivery/util/styles.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_app_bar_widget.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_button_widget.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_snackbar_widget.dart';

class DeviceBlockedScreen extends StatefulWidget {
  final String? phone;
  final bool lostNumber;
  const DeviceBlockedScreen({super.key, this.phone, this.lostNumber = false});

  @override
  State<DeviceBlockedScreen> createState() => _DeviceBlockedScreenState();
}

class _DeviceBlockedScreenState extends State<DeviceBlockedScreen> {
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.lostNumber) {
      _messageController.text = 'Hola, mi cuenta de repartidor (${widget.phone ?? ""}) está registrada en otro celular, pero ya no tengo acceso a mi número telefónico anterior para recibir el SMS de verificación. Necesito ayuda de soporte para actualizar mi número o vincular este nuevo dispositivo. Gracias.';
    } else {
      _messageController.text = 'Hola, mi cuenta de repartidor (${widget.phone ?? ""}) está registrada en otro celular y necesito vincularla a este nuevo dispositivo para poder iniciar sesión. Agradezco su apoyo.';
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _launchWhatsApp() async {
    final String rawPhone = Get.find<SplashController>().configModel?.phone ?? '+527297706434';
    // Clean phone number (keep digits only)
    String cleanPhone = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.isEmpty) {
      cleanPhone = '527297706434';
    }

    final String text = Uri.encodeComponent(_messageController.text.trim());
    final String url = 'https://wa.me/$cleanPhone?text=$text';

    if (await canLaunchUrlString(url)) {
      await launchUrlString(url, mode: LaunchMode.externalApplication);
    } else {
      showCustomSnackBar('${'can_not_launch'.tr} WhatsApp');
    }
  }

  Future<void> _callSupport() async {
    final String supportPhone = Get.find<SplashController>().configModel?.phone ?? '+527297706434';
    final String url = 'tel:$supportPhone';
    if (await canLaunchUrlString(url)) {
      await launchUrlString(url, mode: LaunchMode.externalApplication);
    } else {
      showCustomSnackBar('${'can_not_launch'.tr} $supportPhone');
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: CustomAppBarWidget(
        title: 'Acceso Restringido'.tr,
        isBackButtonExist: true,
        onBackPressed: () => Get.back(),
      ),
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).scaffoldBackgroundColor,
                Theme.of(context).cardColor.withValues(alpha: 0.2),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: Dimensions.paddingSizeLarge,
                vertical: Dimensions.paddingSizeExtraLarge,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // padlock animated-like icon
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.red.shade300, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.shade500.withValues(alpha: 0.1),
                            blurRadius: 16,
                            spreadRadius: 4,
                          )
                        ]
                      ),
                      child: Icon(
                        Icons.phonelink_lock_rounded,
                        size: 80,
                        color: Colors.red.shade600,
                      ),
                    ),
                    const SizedBox(height: Dimensions.paddingSizeExtraLarge),

                    // Title
                    Text(
                      'Dispositivo No Autorizado'.tr,
                      textAlign: TextAlign.center,
                      style: robotoBold.copyWith(
                        fontSize: Dimensions.fontSizeOverLarge,
                        color: Colors.red.shade700,
                      ),
                    ),
                    const SizedBox(height: Dimensions.paddingSizeDefault),

                    // Explanation Text
                    Container(
                      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                        border: Border.all(
                          color: Theme.of(context).disabledColor.withValues(alpha: 0.1),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'Tu cuenta está registrada con otro celular. Por favor, contacta a soporte para autorizar este dispositivo.'
                            .tr,
                        textAlign: TextAlign.center,
                        style: robotoMedium.copyWith(
                          fontSize: Dimensions.fontSizeLarge,
                          height: 1.4,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                    ),
                    const SizedBox(height: Dimensions.paddingSizeExtraLarge),

                    // Chat message compose area
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
                        child: Text(
                          'Mensaje para soporte:'.tr,
                          style: robotoMedium.copyWith(
                            fontSize: Dimensions.fontSizeDefault,
                            color: Theme.of(context).disabledColor,
                          ),
                        ),
                      ),
                    ),

                    TextField(
                      controller: _messageController,
                      maxLines: 4,
                      keyboardType: TextInputType.multiline,
                      style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeDefault),
                      decoration: InputDecoration(
                        hintText: 'Describe tu solicitud aquí...'.tr,
                        fillColor: Theme.of(context).cardColor,
                        filled: true,
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 1.5),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                          borderSide: BorderSide(color: Theme.of(context).disabledColor.withValues(alpha: 0.3), width: 1),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                        ),
                      ),
                    ),
                    const SizedBox(height: Dimensions.paddingSizeExtraLarge),

                    // WhatsApp Action Button
                    Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF25D366),
                            Color(0xFF075E54),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF25D366).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _launchWhatsApp,
                        icon: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 22),
                        label: Text(
                          'Contactar por WhatsApp'.tr,
                          style: robotoBold.copyWith(
                            color: Colors.white,
                            fontSize: Dimensions.fontSizeLarge,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: Dimensions.paddingSizeDefault),

                    // Phone Call Action Button
                    CustomButtonWidget(
                      buttonText: 'Llamar a Soporte'.tr,
                      icon: Icons.phone,
                      backgroundColor: Theme.of(context).disabledColor.withValues(alpha: 0.15),
                      fontColor: Theme.of(context).textTheme.bodyLarge?.color,
                      onPressed: _callSupport,
                    ),
                    const SizedBox(height: Dimensions.paddingSizeOverLarge),

                    // Back to login
                    TextButton(
                      onPressed: () => Get.back(),
                      child: Text(
                        'Volver al Inicio de Sesión'.tr,
                        style: robotoBold.copyWith(
                          color: Theme.of(context).primaryColor,
                          fontSize: Dimensions.fontSizeDefault,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
