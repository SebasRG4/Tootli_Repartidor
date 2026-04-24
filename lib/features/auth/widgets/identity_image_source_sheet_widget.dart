import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart_delivery/util/dimensions.dart';
import 'package:sixam_mart_delivery/util/styles.dart';

/// Galería o cámara para fotos de identidad en el registro de repartidor.
class IdentityImageSourceSheetWidget extends StatelessWidget {
  final VoidCallback onGallery;
  final VoidCallback? onCamera;

  const IdentityImageSourceSheetWidget({
    super.key,
    required this.onGallery,
    this.onCamera,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool dual = onCamera != null;

    return Container(
      width: 500,
      padding: const EdgeInsets.symmetric(vertical: Dimensions.paddingSizeDefault),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(Dimensions.radiusExtraLarge)),
        color: theme.cardColor,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 4,
            width: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
              color: theme.disabledColor,
            ),
          ),
          const SizedBox(height: Dimensions.paddingSizeDefault),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeLarge),
            child: Text(
              'identity_image_source_title'.tr,
              textAlign: TextAlign.center,
              style: robotoMedium.copyWith(
                fontSize: Dimensions.fontSizeDefault,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
          ),
          const SizedBox(height: Dimensions.paddingSizeLarge),
          if (dual)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _OptionTile(
                  icon: Icons.camera_alt_outlined,
                  label: 'from_camera'.tr,
                  onTap: onCamera!,
                ),
                _OptionTile(
                  icon: Icons.photo_library_outlined,
                  label: 'from_gallery'.tr,
                  onTap: onGallery,
                ),
              ],
            )
          else
            _OptionTile(
              icon: Icons.photo_library_outlined,
              label: 'from_gallery'.tr,
              onTap: onGallery,
            ),
          SizedBox(height: MediaQuery.paddingOf(context).bottom + Dimensions.paddingSizeSmall),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primary.withValues(alpha: 0.2),
              ),
              child: Icon(icon, size: 45, color: primary),
            ),
            const SizedBox(height: Dimensions.paddingSizeSmall),
            Text(label, style: robotoMedium),
          ],
        ),
      ),
    );
  }
}
