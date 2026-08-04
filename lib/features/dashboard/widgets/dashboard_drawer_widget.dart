import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart_delivery/features/auth/controllers/auth_controller.dart';
import 'package:sixam_mart_delivery/features/profile/controllers/profile_controller.dart';
import 'package:sixam_mart_delivery/helper/pusher_service.dart';
import 'package:sixam_mart_delivery/helper/route_helper.dart';
import 'package:sixam_mart_delivery/util/images.dart';
import 'package:sixam_mart_delivery/util/styles.dart';

class DashboardDrawerWidget extends StatelessWidget {
  final ProfileController profileController;
  final int pageIndex;
  final void Function(int page) onSelectPage;
  final bool isPendingRegistrationDashboard;

  const DashboardDrawerWidget({
    super.key,
    required this.profileController,
    required this.pageIndex,
    required this.onSelectPage,
    this.isPendingRegistrationDashboard = false,
  });

  @override
  Widget build(BuildContext context) {
    final String firstName = profileController.profileModel?.fName ?? '';
    final String lastName = profileController.profileModel?.lName ?? '';
    final String fullName = '$firstName $lastName'.trim();
    final String displayName = fullName.isEmpty ? 'Usuario' : fullName;
    final String? imageUrl = profileController.profileModel?.imageFullUrl;

    return Drawer(
      width: (MediaQuery.sizeOf(context).width * 0.80).clamp(270.0, 320.0),
      backgroundColor: const Color(0xFF003822),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            // Encabezado del Perfil del Conductor
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Foto de perfil circular
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24, width: 2),
                    ),
                    child: ClipOval(
                      child: (imageUrl?.isNotEmpty ?? false)
                          ? Image.network(
                              imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  Image.asset(Images.placeholder, fit: BoxFit.cover),
                            )
                          : Image.asset(Images.placeholder, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Nombre del Usuario
                  Text(
                    displayName,
                    style: robotoBold.copyWith(
                      fontSize: 22,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // Pastilla "Nivel 1 · 0 XP"
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF134E35),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Nivel 1 · 0 XP',
                      style: robotoMedium.copyWith(
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Lista de Opciones del Menú
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                children: [
                  _DrawerMenuItem(
                    icon: Icons.person_outline_rounded,
                    label: 'Perfil',
                    onTap: () {
                      Get.back();
                      onSelectPage(3);
                    },
                  ),
                  _DrawerMenuItem(
                    icon: Icons.star_outline_rounded,
                    label: 'Insignias y niveles',
                    onTap: () {
                      Get.back();
                      Get.toNamed(RouteHelper.getMissionRoute());
                    },
                  ),
                  _DrawerMenuItem(
                    icon: Icons.bar_chart_rounded,
                    label: 'Ganancias',
                    onTap: () {
                      Get.back();
                      onSelectPage(4);
                    },
                  ),
                  _DrawerMenuItem(
                    icon: Icons.attach_money_rounded,
                    label: 'Billetera',
                    onTap: () {
                      Get.back();
                      Get.toNamed(RouteHelper.getDisbursementRoute());
                    },
                  ),
                  _DrawerMenuItem(
                    icon: Icons.access_time_rounded,
                    label: 'Historial de viajes',
                    onTap: () {
                      Get.back();
                      onSelectPage(2);
                    },
                  ),
                  _DrawerMenuItem(
                    icon: Icons.info_outline_rounded,
                    label: 'Información bancaria',
                    onTap: () {
                      Get.back();
                      Get.toNamed(RouteHelper.getDisbursementRoute());
                    },
                  ),
                  _DrawerMenuItem(
                    icon: Icons.settings_outlined,
                    label: 'Ajustes',
                    onTap: () {
                      Get.back();
                      Get.toNamed(RouteHelper.getUpdateProfileRoute());
                    },
                  ),
                  _DrawerMenuItem(
                    icon: Icons.info_outline_rounded,
                    label: 'Acerca de',
                    onTap: () {
                      Get.back();
                      Get.toNamed(RouteHelper.getTermsRoute());
                    },
                  ),
                  _DrawerMenuItem(
                    icon: Icons.lock_outline_rounded,
                    label: 'Política de privacidad',
                    onTap: () {
                      Get.back();
                      Get.toNamed(RouteHelper.getPrivacyRoute());
                    },
                  ),
                  _DrawerMenuItem(
                    icon: Icons.description_outlined,
                    label: 'Términos y condiciones',
                    onTap: () {
                      Get.back();
                      Get.toNamed(RouteHelper.getTermsRoute());
                    },
                  ),
                  _DrawerMenuItem(
                    icon: Icons.power_settings_new_rounded,
                    label: 'Cerrar sesión',
                    onTap: () {
                      Get.back();
                      Get.find<AuthController>().clearSharedData();
                      Get.find<ProfileController>().stopLocationRecord();
                      PusherService.instance.disconnect();
                      Get.offAllNamed(RouteHelper.getSignInRoute());
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DrawerMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: Colors.white10,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
          child: Row(
            children: [
              Icon(
                icon,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: robotoMedium.copyWith(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
