import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart_delivery/util/dimensions.dart';
import 'package:sixam_mart_delivery/util/styles.dart';

/// Panel inferior mientras el registro está pendiente de aprobación del admin.
class PendingRegistrationPanelWidget extends StatelessWidget {
  final ScrollController scrollController;

  const PendingRegistrationPanelWidget({
    super.key,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(
          Dimensions.paddingSizeLarge,
          Dimensions.paddingSizeDefault,
          Dimensions.paddingSizeLarge,
          Dimensions.paddingSizeLarge,
        ),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: Dimensions.paddingSizeDefault),
              decoration: BoxDecoration(
                color: theme.dividerColor.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Icon(Icons.hourglass_top_rounded, size: 40, color: theme.primaryColor),
          const SizedBox(height: Dimensions.paddingSizeSmall),
          Text(
            'registration_in_progress_title'.tr,
            textAlign: TextAlign.center,
            style: robotoBold.copyWith(
              fontSize: Dimensions.fontSizeLarge,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: Dimensions.paddingSizeSmall),
          Text(
            'registration_in_progress_body'.tr,
            textAlign: TextAlign.center,
            style: robotoRegular.copyWith(
              fontSize: Dimensions.fontSizeSmall,
              color: theme.hintColor,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
