import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sixam_mart_delivery/features/order/controllers/order_controller.dart';
import 'package:sixam_mart_delivery/features/address/controllers/address_controller.dart';
import 'package:sixam_mart_delivery/features/profile/controllers/profile_controller.dart';
import 'package:sixam_mart_delivery/features/splash/controllers/splash_controller.dart';
import 'package:sixam_mart_delivery/features/order/domain/models/order_model.dart';
import 'package:sixam_mart_delivery/helper/date_converter_helper.dart';
import 'package:sixam_mart_delivery/helper/price_converter_helper.dart';
import 'package:sixam_mart_delivery/helper/route_helper.dart';
import 'package:sixam_mart_delivery/util/dimensions.dart';
import 'package:sixam_mart_delivery/util/images.dart';
import 'package:sixam_mart_delivery/util/styles.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_image_widget.dart';
import 'package:sixam_mart_delivery/features/order/screens/order_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart_delivery/features/order/screens/order_location_screen.dart';

class OrderRequestWidget extends StatelessWidget {
  final OrderModel orderModel;
  final int index;
  final bool fromDetailsPage;
  final Function onTap;

  const OrderRequestWidget({
    super.key,
    required this.orderModel,
    required this.index,
    required this.onTap,
    this.fromDetailsPage = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool parcel = orderModel.orderType == 'parcel';
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    double distance = Get.find<AddressController>().getRestaurantDistance(
      LatLng(
        double.parse(
          parcel
              ? orderModel.deliveryAddress?.latitude ?? '0'
              : orderModel.storeLat ?? '0',
        ),
        double.parse(
          parcel
              ? orderModel.deliveryAddress?.longitude ?? '0'
              : orderModel.storeLng ?? '0',
        ),
      ),
    );

    final bool isCash = orderModel.paymentMethod == 'cash_on_delivery';
    final String distanceText = distance > 1000
        ? '1000+ km'
        : '${distance.toStringAsFixed(1)} km';

    return GetBuilder<OrderController>(
      builder: (orderController) {
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              children: [
                // ── Header con gradiente ─────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [const Color(0xFF1E2235), const Color(0xFF252A3D)]
                          : [const Color(0xFFF8F9FF), const Color(0xFFEEF1FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Imagen tienda / paquete
                      Container(
                        height: 52,
                        width: 52,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).primaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).primaryColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: parcel
                              ? Icon(
                                  Icons.inventory_2_rounded,
                                  color: Theme.of(context).primaryColor,
                                  size: 28,
                                )
                              : CustomImageWidget(
                                  image: orderModel.storeLogoFullUrl ?? '',
                                  height: 52,
                                  width: 52,
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Nombre + artículos + dirección
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              parcel
                                  ? orderModel.parcelCategory?.name ?? 'Paquete'
                                  : orderModel.storeName ?? 'Tienda',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: robotoBold.copyWith(fontSize: 15),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).primaryColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    parcel
                                        ? 'parcel'.tr
                                        : '${orderModel.detailsCount ?? 0} ${(orderModel.detailsCount ?? 0) > 1 ? 'items'.tr : 'item'.tr}',
                                    style: robotoMedium.copyWith(
                                      fontSize: 11,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // Badge efectivo/digital
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isCash
                                        ? Colors.orange.withValues(alpha: 0.15)
                                        : Colors.blue.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isCash
                                            ? Icons.payments_rounded
                                            : Icons.credit_card_rounded,
                                        size: 11,
                                        color: isCash
                                            ? Colors.orange[700]
                                            : Colors.blue[600],
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        isCash ? 'Efectivo' : 'Digital',
                                        style: robotoMedium.copyWith(
                                          fontSize: 10,
                                          color: isCash
                                              ? Colors.orange[700]
                                              : Colors.blue[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              parcel
                                  ? orderModel.parcelCategory?.description ?? ''
                                  : orderModel.storeAddress ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: robotoRegular.copyWith(
                                fontSize: 11,
                                color: Theme.of(context).disabledColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Columna derecha: tiempo + distancia
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Hace ${DateConverterHelper.beforeTimeFormat(orderModel.createdAt!).replaceAll('hace', '').replaceAll('ago', '').trim()}',
                            style: robotoMedium.copyWith(
                              color: Theme.of(context).primaryColor,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Theme.of(context).primaryColor,
                                  Theme.of(
                                    context,
                                  ).primaryColor.withValues(alpha: 0.75),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(
                                    context,
                                  ).primaryColor.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Text(
                                  distanceText,
                                  style: robotoBold.copyWith(
                                    fontSize: 13,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'de ti',
                                  style: robotoRegular.copyWith(
                                    fontSize: 10,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Ruta visual: tienda → cliente ────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      // Origen
                      _RoutePin(
                        icon: Icons.store_rounded,
                        color: Theme.of(context).primaryColor,
                      ),
                      // Línea punteada
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: CustomPaint(
                            painter: _DashedLinePainter(
                              color: Theme.of(
                                context,
                              ).primaryColor.withValues(alpha: 0.35),
                            ),
                            child: const SizedBox(height: 2),
                          ),
                        ),
                      ),
                      // Destino
                      _RoutePin(
                        icon: Icons.location_on_rounded,
                        color: Colors.redAccent,
                      ),
                    ],
                  ),
                ),

                // ── Dirección destino + mapa ──────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Entregar en',
                              style: robotoMedium.copyWith(
                                fontSize: 11,
                                color: Theme.of(context).disabledColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              parcel
                                  ? orderModel.receiverDetails?.address ?? ''
                                  : orderModel.deliveryAddress?.address ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: robotoMedium.copyWith(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => Get.to(
                          () => OrderLocationScreen(
                            orderModel: orderModel,
                            orderController: orderController,
                            index: index,
                            onTap: onTap,
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade600,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.map_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Ver mapa',
                                style: robotoMedium.copyWith(
                                  fontSize: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Footer: ganancias + botones ───────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1A1D2E)
                        : const Color(0xFFF4F5FB),
                    border: Border(
                      top: BorderSide(
                        color: Theme.of(
                          context,
                        ).dividerColor.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),

                  child: Row(
                    children: [
                      // Ganancias
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Ganancia neta',
                              style: robotoRegular.copyWith(
                                fontSize: 10,
                                color: Theme.of(context).disabledColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              PriceConverterHelper.convertPrice(
                                (orderModel.deliveryCharge ?? 0) +
                                    (orderModel.dmTips ?? 0),
                              ),
                              style: robotoBold.copyWith(
                                fontSize: 18,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Botón Aceptar
                      Expanded(
                        flex: 3,
                        child: _ActionButton(
                          label: 'Aceptar Pedido',
                          isPrimary: true,
                          onPressed: () {
                            orderController
                                .acceptOrder(orderModel.id, index, orderModel)
                                .then((isSuccess) {
                                  if (isSuccess) {
                                    onTap();
                                    orderModel.orderStatus =
                                        (orderModel.orderStatus == 'pending' ||
                                            orderModel.orderStatus ==
                                                'confirmed')
                                        ? 'accepted'
                                        : orderModel.orderStatus;
                                    Get.toNamed(
                                      RouteHelper.getOrderDetailsRoute(
                                        orderModel.id,
                                      ),
                                      arguments: OrderDetailsScreen(
                                        orderId: orderModel.id,
                                        isRunningOrder: true,
                                        orderIndex:
                                            orderController
                                                .currentOrderList!
                                                .length -
                                            1,
                                      ),
                                    );
                                  } else {
                                    Get.find<OrderController>().getLatestOrders(
                                      filterIgnored: false,
                                    );
                                  }
                                });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _RoutePin extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _RoutePin({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Icon(icon, size: 14, color: color),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final bool isPrimary;
  final VoidCallback onPressed;
  const _ActionButton({
    required this.label,
    required this.isPrimary,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (isPrimary) {
      return GestureDetector(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).primaryColor,
                Theme.of(context).primaryColor.withValues(alpha: 0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: robotoBold.copyWith(color: Colors.white, fontSize: 14),
            ),
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Theme.of(context).disabledColor.withValues(alpha: 0.4),
          ),
        ),
        child: Text(
          label,
          style: robotoMedium.copyWith(
            fontSize: 14,
            color: Theme.of(context).textTheme.bodyLarge!.color,
          ),
        ),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  const _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    const dashWidth = 5.0;
    const dashSpace = 4.0;
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}
