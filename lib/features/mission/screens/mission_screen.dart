import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_app_bar_widget.dart';
import 'package:sixam_mart_delivery/features/mission/controllers/mission_controller.dart';
import 'package:sixam_mart_delivery/features/mission/widgets/mission_card_widget.dart';
import 'package:sixam_mart_delivery/util/dimensions.dart';
import 'package:sixam_mart_delivery/util/styles.dart';

class MissionScreen extends StatefulWidget {
  const MissionScreen({super.key});

  @override
  State<MissionScreen> createState() => _MissionScreenState();
}

class _MissionScreenState extends State<MissionScreen> {
  @override
  void initState() {
    super.initState();
    Get.find<MissionController>().getMissionList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBarWidget(title: 'driver_missions'.tr),
      body: GetBuilder<MissionController>(
        builder: (missionController) {
          return missionController.missionList != null
              ? missionController.missionList!.isNotEmpty
                    ? RefreshIndicator(
                        onRefresh: () async {
                          await missionController.getMissionList();
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.all(
                            Dimensions.paddingSizeSmall,
                          ),
                          itemCount: missionController.missionList!.length,
                          itemBuilder: (context, index) {
                            return MissionCardWidget(
                              mission: missionController.missionList![index],
                            );
                          },
                        ),
                      )
                    : Center(
                        child: Text('no_mission_found'.tr, style: robotoMedium),
                      )
              : const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}
