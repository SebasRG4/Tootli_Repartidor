import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart_delivery/util/dimensions.dart';
import 'package:sixam_mart_delivery/util/styles.dart';
import 'package:sixam_mart_delivery/features/address/controllers/address_controller.dart';
import 'package:sixam_mart_delivery/features/mission/controllers/mission_controller.dart';
import 'package:sixam_mart_delivery/features/mission/domain/models/mission_model.dart';
import 'package:sixam_mart_delivery/helper/route_helper.dart';
import 'package:sixam_mart_delivery/helper/price_converter_helper.dart';

class OnlinePanelWidget extends StatelessWidget {
  final VoidCallback onDisconnect;
  final ScrollController scrollController;
  const OnlinePanelWidget({
    super.key,
    required this.onDisconnect,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
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
              margin: const EdgeInsets.only(top: 10, bottom: 5),
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).disabledColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
              ),
            ),
          ),

          // Header: Buscando pedidos
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Dimensions.paddingSizeDefault,
              vertical: Dimensions.paddingSizeSmall,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.tune,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
                const SizedBox(width: Dimensions.paddingSizeDefault),
                Expanded(
                  child: Center(
                    child: Text(
                      'Buscando pedidos',
                      style: robotoBold.copyWith(
                        fontSize: 22,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                  ),
                ),
                _AnimatedDots(),
              ],
            ),
          ),

          const SizedBox(height: Dimensions.paddingSizeSmall),

          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Dimensions.paddingSizeDefault,
            ),
            child: Column(
              children: [
                // Zone Limit Details Blue Bar
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Dimensions.paddingSizeDefault,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue[700],
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(15),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Ver detalles de bonos'.tr,
                        style: robotoMedium.copyWith(
                          color: Colors.white,
                          fontSize: Dimensions.fontSizeSmall,
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white,
                        size: 14,
                      ),
                    ],
                  ),
                ),

                // Incentive Card 1: Bonus per Order
                GetBuilder<AddressController>(
                  builder: (addressController) {
                    double maxIncentive = 0;
                    if (addressController.gridList != null &&
                        addressController.gridList!.isNotEmpty) {
                      for (var grid in addressController.gridList!) {
                        double surge =
                            double.tryParse(grid['surge_amount'].toString()) ??
                            0;
                        if (surge > maxIncentive) {
                          maxIncentive = surge;
                        }
                      }
                    }

                    return maxIncentive > 0
                        ? Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(
                                  Dimensions.paddingSizeDefault,
                                ),
                                decoration: BoxDecoration(
                                  color: Get.isDarkMode
                                      ? Colors.grey[900]
                                      : Colors.grey[100],
                                  borderRadius: const BorderRadius.vertical(
                                    bottom: Radius.circular(15),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    _IconCircle(
                                      icon: Icons.attach_money,
                                      color: Colors.blue,
                                    ),
                                    const SizedBox(
                                      width: Dimensions.paddingSizeDefault,
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          RichText(
                                            text: TextSpan(
                                              children: [
                                                TextSpan(
                                                  text: '+MXN\$ ',
                                                  style: robotoMedium.copyWith(
                                                    fontSize: 14,
                                                    color: Theme.of(context)
                                                        .textTheme
                                                        .bodyLarge
                                                        ?.color,
                                                  ),
                                                ),
                                                TextSpan(
                                                  text: maxIncentive
                                                      .toStringAsFixed(0),
                                                  style: robotoBold.copyWith(
                                                    fontSize: 24,
                                                    color: Theme.of(context)
                                                        .textTheme
                                                        .bodyLarge
                                                        ?.color,
                                                  ),
                                                ),
                                                TextSpan(
                                                  text: ' /Pedido',
                                                  style: robotoRegular.copyWith(
                                                    fontSize: 14,
                                                    color: Theme.of(context)
                                                        .textTheme
                                                        .bodyLarge
                                                        ?.color,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            'Zona de alta demanda detectada',
                                            style: robotoRegular.copyWith(
                                              fontSize: 12,
                                              color: Theme.of(
                                                context,
                                              ).disabledColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(
                                height: Dimensions.paddingSizeDefault,
                              ),

                              // Incentive Card 2: Search Reward
                              Container(
                                padding: const EdgeInsets.all(
                                  Dimensions.paddingSizeDefault,
                                ),
                                decoration: BoxDecoration(
                                  color: Get.isDarkMode
                                      ? Colors.grey[900]
                                      : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Row(
                                  children: [
                                    _IconCircle(
                                      icon: Icons.bolt,
                                      color: Colors.deepPurple,
                                    ),
                                    const SizedBox(
                                      width: Dimensions.paddingSizeDefault,
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          RichText(
                                            text: TextSpan(
                                              children: [
                                                TextSpan(
                                                  text: '+MXN\$ ',
                                                  style: robotoMedium.copyWith(
                                                    fontSize: 14,
                                                    color: Theme.of(context)
                                                        .textTheme
                                                        .bodyLarge
                                                        ?.color,
                                                  ),
                                                ),
                                                TextSpan(
                                                  text: (maxIncentive * 1.5)
                                                      .toStringAsFixed(0),
                                                  style: robotoBold.copyWith(
                                                    fontSize: 24,
                                                    color: Theme.of(context)
                                                        .textTheme
                                                        .bodyLarge
                                                        ?.color,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            'Potencial con multiplicador',
                                            style: robotoRegular.copyWith(
                                              fontSize: 12,
                                              color: Theme.of(
                                                context,
                                              ).disabledColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      'acelerador_de_recompensa'.tr,
                                      style: robotoMedium.copyWith(
                                        color: Colors.deepPurple,
                                        fontSize: 14,
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : const SizedBox();
                  },
                ),

                const SizedBox(height: Dimensions.paddingSizeSmall),

                // Missions Section
                GetBuilder<MissionController>(
                  builder: (missionController) {
                    if (missionController.missionList == null) {
                      missionController.getMissionList();
                    }

                    List<MissionModel> activeMissions =
                        missionController.missionList
                            ?.where(
                              (m) =>
                                  m.status == 1 &&
                                  (m.isCompleted == false ||
                                      m.isCompleted == null),
                            )
                            .toList() ??
                        [];

                    return activeMissions.isNotEmpty
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'driver_missions'.tr,
                                    style: robotoBold.copyWith(
                                      fontSize: Dimensions.fontSizeDefault,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () => Get.toNamed(
                                      RouteHelper.getMissionRoute(),
                                    ),
                                    child: Text(
                                      'ver_todas'.tr,
                                      style: robotoMedium.copyWith(
                                        fontSize: Dimensions.fontSizeSmall,
                                        color: Colors.blue,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(
                                height: Dimensions.paddingSizeExtraSmall,
                              ),
                              SizedBox(
                                height: 100,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: activeMissions.length,
                                  itemBuilder: (context, index) {
                                    final mission = activeMissions[index];
                                    double progress =
                                        (mission.currentProgress ?? 0) /
                                        (mission.targetOrders ?? 1);
                                    return Container(
                                      width: 200,
                                      margin: EdgeInsets.only(
                                        right: Dimensions.paddingSizeSmall,
                                      ),
                                      padding: const EdgeInsets.all(
                                        Dimensions.paddingSizeSmall,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(
                                          context,
                                        ).primaryColor.withValues(alpha: 0.05),
                                        borderRadius: BorderRadius.circular(15),
                                        border: Border.all(
                                          color: Theme.of(
                                            context,
                                          ).primaryColor.withValues(alpha: 0.1),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            mission.title ?? '',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: robotoMedium.copyWith(
                                              fontSize:
                                                  Dimensions.fontSizeSmall,
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              Dimensions.radiusSmall,
                                            ),
                                            child: LinearProgressIndicator(
                                              value: progress > 1
                                                  ? 1
                                                  : progress,
                                              minHeight: 8,
                                              backgroundColor: Theme.of(context)
                                                  .disabledColor
                                                  .withValues(alpha: 0.2),
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    Theme.of(
                                                      context,
                                                    ).primaryColor,
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                '${mission.currentProgress}/${mission.targetOrders}',
                                                style: robotoRegular.copyWith(
                                                  fontSize: 10,
                                                  color: Theme.of(
                                                    context,
                                                  ).disabledColor,
                                                ),
                                              ),
                                              Text(
                                                '+${PriceConverterHelper.convertPrice(mission.rewardAmount)}',
                                                style: robotoBold.copyWith(
                                                  fontSize: 10,
                                                  color: Theme.of(
                                                    context,
                                                  ).primaryColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          )
                        : const SizedBox();
                  },
                ),

                const SizedBox(height: Dimensions.paddingSizeDefault),

                // Promo Banner
                Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      colors: [Colors.orange, Colors.deepOrange],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(
                          Dimensions.paddingSizeDefault,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.shopping_bag,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'elige_y_compra'.tr,
                                  style: robotoMedium.copyWith(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'acelerador_de_recompensa'.tr,
                              style: robotoBold.copyWith(
                                color: Colors.white,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'conoce_mas'.tr,
                                style: robotoMedium.copyWith(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        right: 10,
                        bottom: 10,
                        top: 10,
                        child: Icon(
                          Icons.rocket_launch,
                          size: 80,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: Dimensions.paddingSizeDefault),

                // Disconnect Button
                Padding(
                  padding: const EdgeInsets.only(
                    bottom: Dimensions.paddingSizeDefault,
                  ),
                  child: ElevatedButton(
                    onPressed: onDisconnect,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 2,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.double_arrow, color: Colors.white),
                        const SizedBox(width: Dimensions.paddingSizeSmall),
                        Text(
                          'desconectarse'.tr.toUpperCase(),
                          style: robotoBold.copyWith(
                            color: Colors.white,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IconCircle extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _IconCircle({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

class _AnimatedDots extends StatefulWidget {
  @override
  State<_AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<_AnimatedDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _dotCount = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _controller.addListener(() {
      int newCount = (_controller.value * 4).floor();
      if (newCount != _dotCount) {
        setState(() {
          _dotCount = newCount;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      child: Text('.' * _dotCount, style: robotoBold.copyWith(fontSize: 22)),
    );
  }
}
