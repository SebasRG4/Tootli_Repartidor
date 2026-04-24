import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_button_widget.dart';
import 'package:sixam_mart_delivery/features/auth/controllers/auth_controller.dart';
import 'package:sixam_mart_delivery/features/profile/controllers/profile_controller.dart';
import 'package:sixam_mart_delivery/helper/route_helper.dart';
import 'package:sixam_mart_delivery/util/dimensions.dart';
import 'package:sixam_mart_delivery/util/styles.dart';

/// Panel inferior mientras el registro está pendiente de aprobación del admin
/// o hay correcciones solicitadas (`registration_revision_message`).
class PendingRegistrationPanelWidget extends StatelessWidget {
  final ScrollController scrollController;
  final String? adminRevisionMessage;
  final bool showRevisionFootnote;

  const PendingRegistrationPanelWidget({
    super.key,
    required this.scrollController,
    this.adminRevisionMessage,
    this.showRevisionFootnote = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String trimmed = (adminRevisionMessage ?? '').trim();

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
          if (trimmed.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                border: Border.all(
                  color: theme.primaryColor.withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'registration_revision_banner'.tr,
                    style: robotoBold.copyWith(
                      fontSize: Dimensions.fontSizeSmall,
                      color: theme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: Dimensions.paddingSizeExtraSmall),
                  Text(
                    trimmed,
                    style: robotoRegular.copyWith(
                      fontSize: Dimensions.fontSizeSmall,
                      color: theme.textTheme.bodyLarge?.color,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Dimensions.paddingSizeDefault),
          ],
          Text(
            showRevisionFootnote
                ? 'registration_in_progress_revision_footnote'.tr
                : 'registration_in_progress_body'.tr,
            textAlign: TextAlign.center,
            style: robotoRegular.copyWith(
              fontSize: Dimensions.fontSizeSmall,
              color: theme.hintColor,
              height: 1.35,
            ),
          ),
          const SizedBox(height: Dimensions.paddingSizeDefault),
          Center(
            child: OutlinedButton.icon(
              onPressed: () => Get.find<ProfileController>().getProfile(),
              icon: const Icon(Icons.refresh, size: 18),
              label: Text('refresh_registration_status'.tr),
            ),
          ),
          if (showRevisionFootnote) ...[
            const SizedBox(height: Dimensions.paddingSizeDefault),
            CustomButtonWidget(
              buttonText: 'registration_open_revision_form_cta'.tr,
              onPressed: () {
                Get.find<AuthController>().setRegistrationRevisionDisplay(
                  revisionRequired: true,
                  message: trimmed.isEmpty ? null : trimmed,
                );
                Get.toNamed(
                  RouteHelper.getDeliverymanRegistrationRoute(),
                  arguments: const {'registrationRevision': true},
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
