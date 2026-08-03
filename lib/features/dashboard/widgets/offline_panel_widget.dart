import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart_delivery/features/profile/controllers/profile_controller.dart';
import 'package:sixam_mart_delivery/helper/route_helper.dart';
import 'package:sixam_mart_delivery/util/dimensions.dart';
import 'package:sixam_mart_delivery/util/styles.dart';
import 'package:sixam_mart_delivery/features/order/widgets/slider_button_widget.dart';

class OfflinePanelWidget extends StatelessWidget {
  final VoidCallback onConnect;
  final ScrollController scrollController;
  const OfflinePanelWidget({
    super.key,
    required this.onConnect,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ProfileController>(
      builder: (profileController) {
        final String kycStatus = profileController.profileModel?.identityVerified ?? 'none';
        final bool isKycApproved = kycStatus == 'approved';

        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0C0E12), // Dark sheet background
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 15,
                offset: Offset(0, -5),
              ),
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.zero,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 10),
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              // Connectivity Section (Slider if approved, Banner/Button if pending or missing)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimensions.paddingSizeDefault,
                ),
                child: isKycApproved
                    ? SliderButton(
                        action: onConnect,
                        label: Text(
                          'conectarse'.tr,
                          style: robotoMedium.copyWith(
                            color: Colors.white,
                            fontSize: Dimensions.fontSizeLarge,
                          ),
                        ),
                        dismissThresholds: 0.5,
                        dismissible: false,
                        shimmer: true,
                        width: context.width - 40,
                        height: 55,
                        buttonSize: 50,
                        radius: 15,
                        icon: const Center(
                          child: Icon(
                            Icons.double_arrow_sharp,
                            color: Colors.green,
                            size: 25,
                          ),
                        ),
                        buttonColor: Colors.white,
                        backgroundColor: Colors.green,
                        highlightedColor: Colors.white,
                        baseColor: Colors.white,
                      )
                    : _buildKycBlockedCard(context, kycStatus),
              ),

              const SizedBox(height: Dimensions.paddingSizeExtraLarge),

              // Offline Status Info
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimensions.paddingSizeDefault,
                ),
                child: Row(
                  children: [
                    Icon(
                      isKycApproved ? Icons.info_outline : Icons.lock_clock_outlined,
                      color: isKycApproved ? Colors.white38 : const Color(0xFFD97706),
                    ),
                    const SizedBox(width: Dimensions.paddingSizeSmall),
                    Expanded(
                      child: Text(
                        isKycApproved
                            ? 'Conéctate para recibir pedidos'
                            : (kycStatus == 'pending'
                                ? 'Tu verificación de identidad está en revisión por el equipo.'
                                : 'Completa tu verificación para poder conectarte.'),
                        style: robotoRegular.copyWith(
                          color: isKycApproved ? Colors.white54 : const Color(0xFFFBBF24),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: Dimensions.paddingSizeLarge),

              // Summary Cards Section (Daily Summary)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimensions.paddingSizeDefault,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Resumen del día',
                      style: robotoBold.copyWith(fontSize: 18, color: Colors.white),
                    ),
                    const SizedBox(height: Dimensions.paddingSizeSmall),

                    Row(
                      children: [
                        const Expanded(
                          child: _SummaryCard(
                            title: 'Pedidos completados',
                            value: '0',
                            icon: Icons.check_circle_outline,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(width: Dimensions.paddingSizeDefault),
                        const Expanded(
                          child: _SummaryCard(
                            title: 'Ganancias estimadas',
                            value: '\$0.00',
                            icon: Icons.account_balance_wallet_outlined,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: Dimensions.paddingSizeExtraLarge),

              // Tip Banner
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimensions.paddingSizeDefault,
                ),
                child: Container(
                  padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lightbulb_outline, color: Colors.orange),
                      const SizedBox(width: Dimensions.paddingSizeDefault),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Consejo del día',
                              style: robotoBold.copyWith(
                                color: Colors.orange[800],
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Revisa tus zonas de calor en el mapa',
                              style: robotoRegular.copyWith(fontSize: 13, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: Dimensions.paddingSizeExtraLarge),
              const SizedBox(height: 50), // Bottom padding
            ],
          ),
        );
      },
    );
  }

  Widget _buildKycBlockedCard(BuildContext context, String kycStatus) {
    final bool isPending = kycStatus == 'pending';
    final Color cardBg = isPending ? const Color(0xFF231805) : const Color(0xFF280B0B);
    final Color borderColor = isPending ? const Color(0xFFD97706) : const Color(0xFFEF4444);
    final IconData icon = isPending ? Icons.pending_actions_rounded : Icons.shield_rounded;
    final String title = isPending ? 'Verificación en proceso' : 'Verificación requerida';
    final String subtitle = isPending
        ? 'Tus documentos están en revisión. Puedes explorar el mapa mientras esperas.'
        : 'Para conectarte y recibir pedidos debes subir tu INE y Selfie.';
    final String buttonText = isPending ? 'Revisar estado de KYC' : 'Verificar Identidad Ahora';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: borderColor.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: borderColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: borderColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: robotoBold.copyWith(color: Colors.white, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: robotoRegular.copyWith(color: Colors.white70, fontSize: 12, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: TextButton(
              onPressed: () => Get.toNamed(RouteHelper.getDmKycRoute()),
              style: TextButton.styleFrom(
                backgroundColor: borderColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    buttonText,
                    style: robotoBold.copyWith(color: Colors.white, fontSize: 14),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      decoration: BoxDecoration(
        color: const Color(0xFF141922),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: Dimensions.paddingSizeSmall),
          Text(value, style: robotoBold.copyWith(fontSize: 22, color: Colors.white)),
          Text(
            title,
            style: robotoRegular.copyWith(
              fontSize: 12,
              color: Colors.white54,
            ),
          ),
        ],
      ),
    );
  }
}
