import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart_delivery/util/dimensions.dart';
import 'package:sixam_mart_delivery/util/styles.dart';
import 'package:sixam_mart_delivery/features/address/controllers/address_controller.dart';
import 'package:sixam_mart_delivery/features/mission/controllers/mission_controller.dart';
import 'package:sixam_mart_delivery/features/mission/domain/models/mission_model.dart';
import 'package:sixam_mart_delivery/helper/route_helper.dart';
import 'package:sixam_mart_delivery/helper/price_converter_helper.dart';
import 'package:sixam_mart_delivery/features/order/controllers/order_controller.dart';
import 'package:sixam_mart_delivery/features/profile/controllers/profile_controller.dart';
import 'package:sixam_mart_delivery/features/my_account/widgets/offline_payment_bottom_sheet_widget.dart';
import 'package:sixam_mart_delivery/util/images.dart';

class OnlinePanelWidget extends StatelessWidget {
  final VoidCallback onDisconnect;
  final ScrollController scrollController;
  final VoidCallback? onGoToOrderCenter;
  const OnlinePanelWidget({
    super.key,
    required this.onDisconnect,
    required this.scrollController,
    this.onGoToOrderCenter,
  });

  @override
  Widget build(BuildContext context) {
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
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // Order Center Button (only when there are available orders)
          GetBuilder<OrderController>(
            builder: (orderController) {
              final hasOrders = orderController.latestOrderList != null &&
                  orderController.latestOrderList!.isNotEmpty;
              if (!hasOrders) return const SizedBox.shrink();
              final count = orderController.latestOrderList!.length;
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimensions.paddingSizeDefault,
                  vertical: 6,
                ),
                child: _OrderCenterButton(
                  count: count,
                  onTap: onGoToOrderCenter,
                ),
              );
            },
          ),

          // Header Status: Buscando pedidos / Bloqueo por efectivo
          GetBuilder<ProfileController>(
            builder: (profileController) {
              final profile = profileController.profileModel;
              final double cash = profile?.cashInHands ?? 0;
              final double limitBlock = profile?.cashLimitForTotalBlock ?? 0;
              final double limitPaid = profile?.cashLimitForOnlyPaid ?? 0;

              final bool isBlocked = limitBlock > 0 && cash >= limitBlock;
              final bool isWarning = !isBlocked && limitPaid > 0 && cash >= limitPaid;

              if (isBlocked) {
                return _CashBlockedHeader(
                  cashInHands: cash,
                  limitBlock: limitBlock,
                  isHardBlock: true,
                );
              } else if (isWarning) {
                return _CashBlockedHeader(
                  cashInHands: cash,
                  limitBlock: limitPaid,
                  isHardBlock: false,
                );
              }

              // Normal status: buscando pedidos (Mockup alignment with overlapping motorcycle)
              return Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: Dimensions.paddingSizeDefault,
                  vertical: Dimensions.paddingSizeSmall,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF141922),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Row(
                      children: [
                        // Green radar icon
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF5EC44B).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.gps_fixed,
                            color: Color(0xFF5EC44B),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Buscando pedidos',
                                    style: robotoBold.copyWith(
                                      fontSize: 20,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    height: 8,
                                    width: 8,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF5EC44B),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Te avisaremos cuando haya uno disponible',
                                style: robotoRegular.copyWith(
                                  fontSize: 12,
                                  color: Colors.white54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Spacer to make room for motorcycle overlap
                        const SizedBox(width: 70),
                      ],
                    ),
                    // Overlapping motorcycle delivery image
                    Positioned(
                      right: -25,
                      top: -45,
                      bottom: -20,
                      child: Image.asset(
                        Images.motorcycle,
                        width: 120,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Dimensions.paddingSizeDefault,
            ),
            child: Column(
              children: [
                // Ver detalles de bonos (Mockup styled card)
                GestureDetector(
                  onTap: onGoToOrderCenter,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F2642), // Dark blue background
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF2196F3).withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Blue gift/bonus icon box
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2196F3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.card_giftcard,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ver detalles de bonos',
                                style: robotoBold.copyWith(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Descubre y activa tus bonos',
                                style: robotoRegular.copyWith(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Blue chevron button
                        Container(
                          height: 32,
                          width: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2196F3).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.chevron_right,
                            color: Color(0xFF2196F3),
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Dimensions.paddingSizeSmall),

                // Incentive Card 1 & 2 (Only if maxIncentive > 0, in a clean dark container)
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
                                  color: const Color(0xFF141922),
                                  borderRadius: const BorderRadius.vertical(
                                    bottom: Radius.circular(15),
                                  ),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
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
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                TextSpan(
                                                  text: maxIncentive
                                                      .toStringAsFixed(0),
                                                  style: robotoBold.copyWith(
                                                    fontSize: 24,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                TextSpan(
                                                  text: ' /Pedido',
                                                  style: robotoRegular.copyWith(
                                                    fontSize: 14,
                                                    color: Colors.white70,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            'Zona de alta demanda detectada',
                                            style: robotoRegular.copyWith(
                                              fontSize: 12,
                                              color: Colors.white38,
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
                                  color: const Color(0xFF141922),
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
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
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                TextSpan(
                                                  text: (maxIncentive * 1.5)
                                                      .toStringAsFixed(0),
                                                  style: robotoBold.copyWith(
                                                    fontSize: 24,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            'Potencial con multiplicador',
                                            style: robotoRegular.copyWith(
                                              fontSize: 12,
                                              color: Colors.white38,
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

                // Missions Section (Dark Theme Compliant)
                GetBuilder<MissionController>(
                  builder: (missionController) {
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
                                        color: const Color(0xFF141922),
                                        borderRadius: BorderRadius.circular(15),
                                        border: Border.all(
                                          color: Colors.white.withValues(alpha: 0.05),
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
                                              color: Colors.white,
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
                                              backgroundColor: Colors.white10,
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
                                                  color: Colors.white54,
                                                ),
                                              ),
                                              Text(
                                                '+${PriceConverterHelper.convertPrice(mission.rewardAmount ?? 0)}',
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

                // Orange Gradient Reward Booster Banner (Mockup rocket card design)
                Container(
                  height: 130,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF5211), Color(0xFFFFB74D)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF5211).withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // ⭐ Elige y compra
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'elige_y_compra'.tr,
                                    style: robotoMedium.copyWith(
                                      color: Colors.white,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'acelerador_de_recompensa'.tr,
                              style: robotoBold.copyWith(
                                color: Colors.white,
                                fontSize: 20,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Aumenta tus ganancias hoy mismo',
                              style: robotoRegular.copyWith(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Rocket icon/graphic
                      Positioned(
                        right: 50,
                        bottom: 0,
                        top: 0,
                        child: Center(
                          child: Icon(
                            Icons.rocket_launch,
                            size: 65,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                      // Chevron right circular button
                      Positioned(
                        right: 16,
                        bottom: 0,
                        top: 0,
                        child: Center(
                          child: Container(
                            height: 36,
                            width: 36,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.chevron_right,
                              color: Colors.black87,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: Dimensions.paddingSizeDefault),

                // Disconnect Button (Red outline premium style)
                Padding(
                  padding: const EdgeInsets.only(
                    bottom: Dimensions.paddingSizeDefault,
                  ),
                  child: OutlinedButton(
                    onPressed: onDisconnect,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent, width: 1.2),
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.power_settings_new, color: Colors.redAccent, size: 22),
                        const SizedBox(width: Dimensions.paddingSizeSmall),
                        Text(
                          'desconectarse'.tr.toUpperCase(),
                          style: robotoBold.copyWith(
                            color: Colors.redAccent,
                            fontSize: 16,
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

class _CashBlockedHeader extends StatelessWidget {
  final double cashInHands;
  final double limitBlock;
  final bool isHardBlock;

  const _CashBlockedHeader({
    required this.cashInHands,
    required this.limitBlock,
    required this.isHardBlock,
  });

  @override
  Widget build(BuildContext context) {
    final Color statusColor = isHardBlock ? Colors.red : Colors.orange;
    final String title = isHardBlock ? 'Bloqueo Total' : 'Solo Órdenes Pagadas';
    final String subtitle = isHardBlock
        ? 'Límite superado. Deposita efectivo para recibir órdenes.'
        : 'Límite parcial alcanzado. No recibirás pedidos en efectivo.';

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeDefault,
        vertical: Dimensions.paddingSizeSmall,
      ),
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: statusColor.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isHardBlock ? Icons.block : Icons.warning_amber_rounded,
                color: statusColor,
                size: 24,
              ),
              const SizedBox(width: Dimensions.paddingSizeSmall),
              Expanded(
                child: Text(
                  title,
                  style: robotoBold.copyWith(
                    fontSize: 18,
                    color: statusColor,
                  ),
                ),
              ),
              Text(
                PriceConverterHelper.convertPrice(cashInHands),
                style: robotoBold.copyWith(
                  fontSize: 18,
                  color: statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: Dimensions.paddingSizeSmall),
          Text(
            subtitle,
            style: robotoRegular.copyWith(
              fontSize: 13,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: Dimensions.paddingSizeDefault),
          InkWell(
            onTap: () {
              showModalBottomSheet(
                isScrollControlled: true,
                useRootNavigator: true,
                context: context,
                backgroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(Dimensions.radiusExtraLarge),
                    topRight: Radius.circular(Dimensions.radiusExtraLarge),
                  ),
                ),
                builder: (context) {
                  return ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.8,
                    ),
                    child: OfflinePaymentBottomSheetWidget(
                      amount: cashInHands,
                    ),
                  );
                },
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                vertical: Dimensions.paddingSizeSmall,
              ),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
              ),
              alignment: Alignment.center,
              child: Text(
                'Pagar Ahora',
                style: robotoMedium.copyWith(
                  color: Colors.white,
                  fontSize: Dimensions.fontSizeSmall,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderCenterButton extends StatefulWidget {
  final int count;
  final VoidCallback? onTap;
  const _OrderCenterButton({required this.count, this.onTap});

  @override
  State<_OrderCenterButton> createState() => _OrderCenterButtonState();
}

class _OrderCenterButtonState extends State<_OrderCenterButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF2196F3).withValues(alpha: 0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2196F3).withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icono con fondo azul
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2196F3).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.inbox_rounded,
                color: Color(0xFF2196F3),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            // Textos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Centro de pedidos',
                    style: robotoBold.copyWith(
                      fontSize: 15,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    widget.count == 1
                        ? '1 pedido disponible para tomar'
                        : '${widget.count} pedidos disponibles para tomar',
                    style: robotoRegular.copyWith(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            // Badge rojo con pulso
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: child,
                );
              },
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.5),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    widget.count > 9 ? '9+' : '${widget.count}',
                    style: robotoBold.copyWith(
                      color: Colors.white,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_ios,
              color: Color(0xFF2196F3),
              size: 14,
            ),
          ],
        ),
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
