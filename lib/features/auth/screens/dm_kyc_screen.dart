import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:metamap_plugin_flutter/metamap_plugin_flutter.dart';
import 'package:metamap_plugin_flutter/Result.dart';
import 'package:sixam_mart_delivery/api/api_client.dart';
import 'package:sixam_mart_delivery/features/profile/controllers/profile_controller.dart';
import 'package:sixam_mart_delivery/helper/route_helper.dart';
import 'package:sixam_mart_delivery/util/styles.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_snackbar_widget.dart';

class KycIntroScreen extends StatefulWidget {
  const KycIntroScreen({super.key});

  @override
  State<KycIntroScreen> createState() => _KycIntroScreenState();
}

class _KycIntroScreenState extends State<KycIntroScreen> {
  bool _isProcessing = false;

  // MetaMap Webflow config
  final String _clientId = "6a557f10d8866787c25766cc"; // Client ID real
  final String _flowId = "6a557f10d8866787c25766ca"; // Flow ID real

  Future<void> _startNativeVerification() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    final user = Get.find<ProfileController>().profileModel;
    // Si venimos del registro, no estamos logueados, pero pasamos el teléfono por argumentos.
    final String uniqueId = (Get.arguments != null && Get.arguments['phone'] != null)
        ? Get.arguments['phone']
        : (user?.phone ?? user?.id?.toString() ?? '0');

    // Metadata a enviar
    final Map<String, dynamic> metadata = {
      "userId": uniqueId,
      "user_id": uniqueId,
    };

    try {
      // Lanzar flujo nativo de MetaMap y esperar resultado por Future
      final Result result = await MetaMapFlutter.showMetaMapFlow(
        clientId: _clientId,
        flowId: _flowId,
        metadata: metadata,
      );

      if (result is ResultSuccess) {
        // Notificar a nuestra API el inicio de la verificación con el ID devuelto
        await _notifyStartVerification(result.verificationId);
        showCustomSnackBar(
          'Documentos enviados correctamente. Tu identidad está en revisión.',
          isError: false,
        );

        if (Get.arguments != null && Get.arguments['phone'] != null) {
          // Venimos del registro
          Get.offAllNamed(RouteHelper.getDmRegistrationSuccessRoute());
        } else {
          // Refrescar perfil del usuario y cerrar
          await Get.find<ProfileController>().getProfile();
          if (mounted) Navigator.pop(context);
        }
      } else if (result is ResultCancelled) {
        showCustomSnackBar(
          'Verificación cancelada por el usuario.',
          isError: true,
        );
      }
    } catch (e) {
      showCustomSnackBar(
        'Ocurrió un error al abrir la verificación: $e',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _handleBackNavigation() {
    if (Get.previousRoute.isNotEmpty && Get.previousRoute != RouteHelper.dmKyc) {
      Get.back();
    } else {
      Get.offAllNamed(RouteHelper.getSignInRoute());
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackNavigation();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(
            'Verificación de identidad',
            style: robotoBold.copyWith(fontSize: 18, color: Colors.black),
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.black,
              size: 20,
            ),
            onPressed: _handleBackNavigation,
          ),
        ),
      body: GetBuilder<ProfileController>(
        builder: (profileController) {
          final String status;
          final bool isUnauthenticated = (Get.arguments != null && Get.arguments['phone'] != null);
          
          if (isUnauthenticated) {
            status = 'none';
          } else {
            status = profileController.profileModel?.identityVerified ?? 'none';
          }

          return SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 16.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 10),
                        // Circular badge based on status
                        _buildShieldBadge(status),
                        const SizedBox(height: 32),

                        // Main Title
                        Text(
                          _getStatusTitle(status),
                          style: robotoBold.copyWith(
                            fontSize: 24,
                            color: const Color(0xFF1D2125),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),

                        // Subtitle / Description
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text(
                            _getStatusDescription(status),
                            style: robotoRegular.copyWith(
                              fontSize: 15,
                              color: const Color(0xFF626F84),
                              height: 1.45,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Requirement steps card (only show if none or rejected)
                        if (status == 'none' || status == 'rejected') ...[
                          _buildRequirementCard(),
                          const SizedBox(height: 24),
                        ],
                      ],
                    ),
                  ),
                ),

                // Bottom actions section
                Padding(
                  padding: const EdgeInsets.fromLTRB(24.0, 8.0, 24.0, 16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Action Button
                      if (status == 'none' || status == 'rejected')
                        _buildActionButton(
                          text: status == 'rejected'
                              ? 'Reintentar verificación'
                              : 'Verificar identidad',
                          isLoading: _isProcessing,
                          onPressed: _startNativeVerification,
                          color: const Color(0xFF006A4E),
                          showChevron: true,
                        )
                      else if (status == 'pending')
                        _buildActionButton(
                          text: 'Actualizar estado',
                          isLoading: _isProcessing,
                          onPressed: () async {
                            setState(() => _isProcessing = true);
                            await profileController.getProfile();
                            setState(() => _isProcessing = false);
                            showCustomSnackBar(
                              'Estado del perfil actualizado.',
                              isError: false,
                            );
                          },
                          color: const Color(0xFFD97706),
                          showChevron: false,
                        )
                      else
                        _buildActionButton(
                          text: 'Entendido',
                          isLoading: _isProcessing,
                          onPressed: _handleBackNavigation,
                          color: const Color(0xFF006A4E),
                          showChevron: false,
                        ),

                      const SizedBox(height: 20),

                      // Encrypted disclaimer footer
                      _buildFooter(),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
  }

  Widget _buildShieldBadge(String status) {
    Color outerRingColor = const Color(0xFFEBF7F0);
    Color dotColor = const Color(0xFF00875A);
    Color shieldColor = const Color(0xFF00875A);
    IconData centerIcon = Icons.shield_rounded;
    Color centerIconColor = Colors.white;
    bool showCheckmark = true;

    if (status == 'pending') {
      outerRingColor = const Color(0xFFFEF3C7);
      dotColor = const Color(0xFFD97706);
      shieldColor = const Color(0xFFD97706);
      centerIcon = Icons.pending_actions_rounded;
      showCheckmark = false;
    } else if (status == 'rejected') {
      outerRingColor = const Color(0xFFFEE2E2);
      dotColor = const Color(0xFFDC2626);
      shieldColor = const Color(0xFFDC2626);
      centerIcon = Icons.gpp_bad_rounded;
      showCheckmark = false;
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer thin border circle
        Container(
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: status == 'pending'
                  ? const Color(0xFFFDE68A).withOpacity(0.4)
                  : status == 'rejected'
                  ? const Color(0xFFFECACA).withOpacity(0.4)
                  : const Color(0xFFEBF7F0),
              width: 1.5,
            ),
          ),
        ),
        // Small decorative status dot on outer border
        Positioned(
          right: 21,
          top: 45,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
        ),
        // Inner circle background
        Container(
          width: 124,
          height: 124,
          decoration: BoxDecoration(
            color: outerRingColor,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(centerIcon, color: shieldColor, size: 72),
                if (showCheckmark)
                  const Positioned(
                    bottom: 22,
                    child: Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 26,
                      weight: 3.0,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRequirementCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F2F4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        children: [
          _buildCardItem(
            icon: Icons.badge_outlined,
            title: 'INE',
            subtitle: 'Frente y reverso',
          ),
          const Divider(color: Color(0xFFF1F2F4), height: 1, thickness: 1),
          _buildCardItem(
            icon: Icons.sentiment_satisfied_alt_outlined,
            title: 'Selfie',
            subtitle: 'Confirma que eres el titular',
          ),
          const Divider(color: Color(0xFFF1F2F4), height: 1, thickness: 1),
          _buildCardItem(
            icon: Icons.watch_later_outlined,
            title: 'Tiempo estimado',
            subtitle: 'Menos de 1 minuto',
          ),
        ],
      ),
    );
  }

  Widget _buildCardItem({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14.0),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Color(0xFFEBF7F0),
              shape: BoxShape.circle,
            ),
            child:
                const Icon(
                      Icons
                          .shield_rounded, // fallback container styling or custom icon
                    ) ==
                    null
                ? null
                : Icon(icon, color: const Color(0xFF00875A), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: robotoBold.copyWith(
                    fontSize: 16,
                    color: const Color(0xFF1D2125),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: robotoRegular.copyWith(
                    fontSize: 14,
                    color: const Color(0xFF626F84),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String text,
    required Color color,
    required VoidCallback? onPressed,
    bool isLoading = false,
    bool showChevron = true,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: TextButton(
        onPressed: isLoading ? null : onPressed,
        style: TextButton.styleFrom(
          backgroundColor: onPressed == null ? const Color(0xFF93A2AE) : color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.zero,
        ),
        child: isLoading
            ? const Center(
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 2.5,
                  ),
                ),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: Text(
                        text,
                        textAlign: TextAlign.center,
                        style: robotoBold.copyWith(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    if (showChevron)
                      const Align(
                        alignment: Alignment.centerRight,
                        child: Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildFooter() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: Color(0xFFEBF7F0),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.lock_outline_rounded,
            color: Color(0xFF00875A),
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Text(
              'Tus documentos están protegidos mediante cifrado y solo se utilizan para verificar tu identidad.',
              style: robotoRegular.copyWith(
                fontSize: 12,
                color: const Color(0xFF626F84),
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _getStatusTitle(String status) {
    switch (status) {
      case 'pending':
        return 'Tu verificación está en proceso';
      case 'approved':
        return '¡Identidad Verificada!';
      case 'rejected':
        return 'Verificación Rechazada';
      default:
        return 'Protege tu cuenta';
    }
  }

  String _getStatusDescription(String status) {
    switch (status) {
      case 'pending':
        return 'Nuestro equipo o el proveedor automático están validando tu INE y selfie. Esto suele tardar unos minutos. Te notificaremos al terminar.';
      case 'approved':
        return 'Excelente. Tu perfil esta verificado. Ya puedes usar el método de pago en efectivo.';
      case 'rejected':
        return 'Lamentablemente no pudimos validar tus documentos. Asegúrate de tomar fotos claras, legibles y que tu selfie tenga buena luz. Por favor, reintenta el proceso.';
      default:
        return 'Para habilitar los pagos en efectivo necesitamos verificar tu identidad.';
    }
  }

  /// Registra en nuestro backend que el usuario inició o finalizó el flujo de verificación
  Future<void> _notifyStartVerification(String verificationId) async {
    try {
      final apiClient = Get.find<ApiClient>();
      await apiClient.postData('/api/v1/delivery-man/kyc/start', {
        'verification_id': verificationId,
      });
    } catch (e) {
      // Ignorar errores menores de logs
    }
  }
}
