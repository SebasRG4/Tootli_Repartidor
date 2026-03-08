import 'package:flutter/material.dart';
import 'package:sixam_mart_delivery/features/mission/domain/models/mission_model.dart';
import 'package:sixam_mart_delivery/util/dimensions.dart';
import 'package:sixam_mart_delivery/util/styles.dart';
import 'package:get/get.dart';

class MissionCardWidget extends StatelessWidget {
  final MissionModel mission;
  const MissionCardWidget({super.key, required this.mission});

  @override
  Widget build(BuildContext context) {
    double progress =
        (mission.currentProgress ?? 0) / (mission.targetOrders ?? 1);
    if (progress > 1) progress = 1;

    return Container(
      margin: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  mission.title ?? '',
                  style: robotoBold.copyWith(
                    fontSize: Dimensions.fontSizeLarge,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimensions.paddingSizeSmall,
                  vertical: Dimensions.paddingSizeExtraSmall,
                ),
                decoration: BoxDecoration(
                  color: mission.isCompleted == true
                      ? Colors.green.withValues(alpha: 0.1)
                      : Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
                ),
                child: Text(
                  mission.isCompleted == true
                      ? 'completed'.tr
                      : 'in_progress'.tr,
                  style: robotoMedium.copyWith(
                    fontSize: Dimensions.fontSizeExtraSmall,
                    color: mission.isCompleted == true
                        ? Colors.green
                        : Theme.of(context).primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Dimensions.paddingSizeExtraSmall),
          Text(
            mission.description ?? '',
            style: robotoRegular.copyWith(
              fontSize: Dimensions.fontSizeSmall,
              color: Theme.of(context).disabledColor,
            ),
          ),
          const SizedBox(height: Dimensions.paddingSizeDefault),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${'target'.tr}: ${mission.targetOrders} ${'orders'.tr}',
                style: robotoMedium.copyWith(
                  fontSize: Dimensions.fontSizeSmall,
                ),
              ),
              Text(
                '${'reward'.tr}: \$${mission.rewardAmount}',
                style: robotoBold.copyWith(
                  fontSize: Dimensions.fontSizeDefault,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: Dimensions.paddingSizeSmall),
          Stack(
            children: [
              Container(
                height: 10,
                width: double.maxFinite,
                decoration: BoxDecoration(
                  color: Theme.of(context).disabledColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
                ),
              ),
              FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).primaryColor,
                        Theme.of(context).primaryColor.withValues(alpha: 0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Dimensions.paddingSizeExtraSmall),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${mission.currentProgress} / ${mission.targetOrders}',
              style: robotoRegular.copyWith(
                fontSize: Dimensions.fontSizeExtraSmall,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
