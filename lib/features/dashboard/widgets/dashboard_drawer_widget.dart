import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart_delivery/features/auth/controllers/auth_controller.dart';
import 'package:sixam_mart_delivery/features/profile/controllers/profile_controller.dart';
import 'package:sixam_mart_delivery/helper/pusher_service.dart';
import 'package:sixam_mart_delivery/helper/route_helper.dart';
import 'package:sixam_mart_delivery/util/dimensions.dart';
import 'package:sixam_mart_delivery/util/images.dart';
import 'package:sixam_mart_delivery/util/styles.dart';

const Color _kDrawerHeaderDeep = Color(0xFF0D1F14);
const Color _kStatTileBg = Color(0xFF242428);

/// Menú lateral del dashboard: cabecera con gradiente, resumen y navegación tipo tarjeta.
class DashboardDrawerWidget extends StatelessWidget {
  final ProfileController profileController;
  final int pageIndex;
  final void Function(int page) onSelectPage;
  final bool isPendingRegistrationBrowse;

  const DashboardDrawerWidget({
    super.key,
    required this.profileController,
    required this.pageIndex,
    required this.onSelectPage,
    this.isPendingRegistrationBrowse = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.primaryColor;
    final surface = theme.scaffoldBackgroundColor;
    final name = profileController.profileModel?.fName ?? '';
    final email = profileController.profileModel?.email ?? '';
    final String phone = profileController.profileModel?.phone ?? '';
    final imageUrl = profileController.profileModel?.imageFullUrl;

    return Drawer(
      width: (MediaQuery.sizeOf(context).width * 0.88).clamp(280.0, 340.0),
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DrawerHeader(
              primary: primary,
              name: name,
              email: email,
              phone: phone,
              showPhoneLine: isPendingRegistrationBrowse,
              imageUrl: imageUrl,
              showNotifications: !isPendingRegistrationBrowse,
              onNotifications: () {
                Get.back();
                Get.toNamed(RouteHelper.getNotificationRoute());
              },
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  Dimensions.paddingSizeDefault,
                  Dimensions.paddingSizeDefault,
                  Dimensions.paddingSizeDefault,
                  0,
                ),
                children: [
                  if (isPendingRegistrationBrowse) ...[
                    _LogoutButton(
                      onTap: () {
                        Get.back();
                        Get.find<AuthController>().clearSharedData();
                        Get.find<ProfileController>().stopLocationRecord();
                        PusherService.instance.disconnect();
                        Get.offAllNamed(RouteHelper.getSignInRoute());
                      },
                    ),
                    SizedBox(height: MediaQuery.paddingOf(context).bottom + 8),
                  ] else ...[
                  Text(
                    'drawer_summary'.tr,
                    style: robotoMedium.copyWith(
                      fontSize: Dimensions.fontSizeSmall,
                      color: theme.hintColor,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: Dimensions.paddingSizeSmall),
                  Row(
                    children: [
                      Expanded(
                        child: _StatChip(
                          label: 'drawer_rating'.tr,
                          value:
                              '${profileController.profileModel?.avgRating ?? 0}',
                          icon: Icons.star_rounded,
                          iconColor: const Color(0xFFFFB74D),
                          background: _kStatTileBg,
                        ),
                      ),
                      const SizedBox(width: Dimensions.paddingSizeSmall),
                      Expanded(
                        child: _StatChip(
                          label: 'today'.tr,
                          value:
                              '${profileController.profileModel?.todaysOrderCount ?? 0}',
                          icon: Icons.today_rounded,
                          iconColor: const Color(0xFF64B5F6),
                          background: _kStatTileBg,
                        ),
                      ),
                      const SizedBox(width: Dimensions.paddingSizeSmall),
                      Expanded(
                        child: _StatChip(
                          label: 'week'.tr,
                          value:
                              '${profileController.profileModel?.thisWeekOrderCount ?? 0}',
                          icon: Icons.date_range_rounded,
                          iconColor: const Color(0xFF81C784),
                          background: _kStatTileBg,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Dimensions.paddingSizeLarge),
                  _NavTile(
                    icon: Icons.home_rounded,
                    label: 'home'.tr,
                    selected: pageIndex == 0,
                    primary: primary,
                    onTap: () => onSelectPage(0),
                  ),
                  _NavTile(
                    icon: Icons.dynamic_feed_rounded,
                    label: 'centro_de_pedidos'.tr,
                    selected: pageIndex == 1,
                    primary: primary,
                    onTap: () => onSelectPage(1),
                  ),
                  _NavTile(
                    icon: Icons.shopping_bag_outlined,
                    label: 'orders'.tr,
                    selected: pageIndex == 2,
                    primary: primary,
                    onTap: () => onSelectPage(2),
                  ),
                  _NavTile(
                    icon: Icons.person_outline_rounded,
                    label: 'profile'.tr,
                    selected: pageIndex == 3,
                    primary: primary,
                    onTap: () => onSelectPage(3),
                  ),
                  _NavTile(
                    icon: Icons.military_tech_outlined,
                    label: 'missions'.tr,
                    selected: false,
                    primary: primary,
                    onTap: () {
                      Get.back();
                      Get.toNamed(RouteHelper.getMissionRoute());
                    },
                  ),
                  const SizedBox(height: Dimensions.paddingSizeLarge),
                  Divider(
                    height: 1,
                    color: theme.dividerColor.withValues(alpha: 0.35),
                  ),
                  const SizedBox(height: Dimensions.paddingSizeSmall),
                  _LogoutButton(
                    onTap: () {
                      Get.back();
                      Get.find<AuthController>().clearSharedData();
                      Get.find<ProfileController>().stopLocationRecord();
                      PusherService.instance.disconnect();
                      Get.offAllNamed(RouteHelper.getSignInRoute());
                    },
                  ),
                  SizedBox(height: MediaQuery.paddingOf(context).bottom + 8),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  final Color primary;
  final String name;
  final String email;
  final String phone;
  final bool showPhoneLine;
  final String? imageUrl;
  final bool showNotifications;
  final VoidCallback onNotifications;

  const _DrawerHeader({
    required this.primary,
    required this.name,
    required this.email,
    this.phone = '',
    this.showPhoneLine = false,
    required this.imageUrl,
    this.showNotifications = true,
    required this.onNotifications,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          Dimensions.paddingSizeDefault,
          Dimensions.paddingSizeSmall,
          Dimensions.paddingSizeSmall,
          Dimensions.paddingSizeLarge,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              primary,
              _kDrawerHeaderDeep,
            ],
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
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
            const SizedBox(width: Dimensions.paddingSizeDefault),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isEmpty ? '…' : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: robotoBold.copyWith(
                      fontSize: Dimensions.fontSizeLarge,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (showPhoneLine && phone.isNotEmpty) ...[
                    Text(
                      phone,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: robotoMedium.copyWith(
                        fontSize: Dimensions.fontSizeDefault,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    if (email.isNotEmpty) const SizedBox(height: 4),
                  ],
                  if (email.isNotEmpty)
                    Text(
                      email,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: robotoRegular.copyWith(
                        fontSize: Dimensions.fontSizeSmall,
                        color: Colors.white.withValues(alpha: 0.88),
                        height: 1.25,
                      ),
                    ),
                  if (!showPhoneLine && email.isEmpty && phone.isNotEmpty)
                    Text(
                      phone,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: robotoRegular.copyWith(
                        fontSize: Dimensions.fontSizeSmall,
                        color: Colors.white.withValues(alpha: 0.88),
                        height: 1.25,
                      ),
                    ),
                  if (showPhoneLine) ...[
                    const SizedBox(height: 8),
                    Text(
                      'registration_in_progress_title'.tr,
                      style: robotoMedium.copyWith(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.85),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (showNotifications)
              IconButton(
                onPressed: onNotifications,
                tooltip: 'drawer_notifications'.tr,
                style: IconButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                ),
                icon: const Icon(Icons.notifications_none_rounded),
              )
            else
              const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color background;

  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: Dimensions.paddingSizeSmall,
        horizontal: 4,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: robotoBold.copyWith(
              fontSize: Dimensions.fontSizeLarge,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: robotoRegular.copyWith(
              fontSize: 9,
              height: 1.1,
              color: Theme.of(context).hintColor,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color primary;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = selected
        ? primary.withValues(alpha: 0.14)
        : Colors.transparent;
    final fg = selected ? primary : theme.textTheme.bodyLarge?.color;
    final iconBg = selected
        ? primary.withValues(alpha: 0.22)
        : const Color(0xFF2C2C30);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Dimensions.paddingSizeSmall,
              vertical: 12,
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: selected ? primary : theme.hintColor),
                ),
                const SizedBox(width: Dimensions.paddingSizeDefault),
                Expanded(
                  child: Text(
                    label,
                    style: robotoMedium.copyWith(
                      fontSize: Dimensions.fontSizeDefault,
                      color: fg,
                    ),
                  ),
                ),
                if (selected)
                  Icon(Icons.chevron_right_rounded, color: primary, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  final VoidCallback onTap;

  const _LogoutButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;

    return Material(
      color: error.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Dimensions.paddingSizeDefault,
            vertical: 14,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.logout_rounded, color: error, size: 22),
              ),
              const SizedBox(width: Dimensions.paddingSizeDefault),
              Expanded(
                child: Text(
                  'logout'.tr,
                  style: robotoMedium.copyWith(
                    fontSize: Dimensions.fontSizeDefault,
                    color: error,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
