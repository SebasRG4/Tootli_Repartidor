import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
              margin: const EdgeInsets.only(top: 10, bottom: 10),
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).disabledColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
              ),
            ),
          ),

          // Connectivity Slider (At the TOP for Offline)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Dimensions.paddingSizeDefault,
            ),
            child: SliderButton(
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
            ),
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
                  Icons.info_outline,
                  color: Theme.of(context).disabledColor,
                ),
                const SizedBox(width: Dimensions.paddingSizeSmall),
                Expanded(
                  child: Text(
                    'Conéctate para recibir pedidos',
                    style: robotoRegular.copyWith(
                      color: Theme.of(context).disabledColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: Dimensions.paddingSizeLarge),

          // Summary Cards Section
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Dimensions.paddingSizeDefault,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Resumen del día',
                  style: robotoBold.copyWith(fontSize: 18),
                ),
                const SizedBox(height: Dimensions.paddingSizeSmall),

                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        title: 'Pedidos completados',
                        value: '0',
                        icon: Icons.check_circle_outline,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: Dimensions.paddingSizeDefault),
                    Expanded(
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
                          style: robotoRegular.copyWith(fontSize: 13),
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
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: Theme.of(context).disabledColor.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: Dimensions.paddingSizeSmall),
          Text(value, style: robotoBold.copyWith(fontSize: 22)),
          Text(
            title,
            style: robotoRegular.copyWith(
              fontSize: 12,
              color: Theme.of(context).disabledColor,
            ),
          ),
        ],
      ),
    );
  }
}
