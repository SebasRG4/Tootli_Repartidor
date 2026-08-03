import 'package:flutter/material.dart';
import 'package:sixam_mart_delivery/features/order/domain/models/order_model.dart';
import 'package:sixam_mart_delivery/util/dimensions.dart';
import 'package:sixam_mart_delivery/util/styles.dart';
import 'package:url_launcher/url_launcher.dart';

class CompactOrderWidget extends StatelessWidget {
  final List<OrderModel> activeOrders;
  final String phase;
  final Function(OrderModel) onHandover;
  final Function(OrderModel) onPickedUp;
  final Function(OrderModel) onDelivered;
  final Function(OrderModel) onOrderReleased;

  const CompactOrderWidget({
    Key? key,
    required this.activeOrders,
    required this.phase,
    required this.onHandover,
    required this.onPickedUp,
    required this.onDelivered,
    required this.onOrderReleased,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (activeOrders.isEmpty) return const SizedBox();

    final order = activeOrders.first;
    bool isRide = order.orderType == 'taxi' || order.orderType == 'parcel' || order.storeName == null;

    // Determine target name based on phase and type
    String name = "";
    String price = "\$${order.orderAmount?.toStringAsFixed(2) ?? '0.00'}";
    
    if (phase == 'going_to_store') {
      name = isRide ? (order.deliveryAddress?.contactPersonName ?? 'Usuario') : (order.storeName ?? 'Restaurante');
    } else {
      name = isRide ? (order.receiverDetails?.contactPersonName ?? 'Usuario Final') : (order.deliveryAddress?.contactPersonName ?? 'Cliente');
    }

    // Determine Action Text
    String actionText = "";
    if (phase == 'going_to_store') {
      actionText = isRide ? 'Llegué con el usuario' : 'Llegué al restaurante';
    } else if (phase == 'at_store') {
      actionText = isRide ? 'Iniciar viaje' : 'Pedido Recogido';
    } else {
      actionText = isRide ? 'Llegué al destino' : 'Entregar Pedido';
    }

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 15,
            offset: Offset(0, -5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Profile Info
          Row(
            children: [
              // Avatar
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[200],
                ),
                child: const Icon(Icons.person, color: Colors.grey),
              ),
              const SizedBox(width: 15),
              // Name & Rating
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: robotoMedium.copyWith(fontSize: 16, color: Colors.black87),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.star, color: Colors.orange, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '5.0', // Hardcoded rating for now
                          style: robotoRegular.copyWith(fontSize: 14, color: Colors.black54),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      price,
                      style: robotoBold.copyWith(fontSize: 18, color: const Color(0xFFF37B21)), // Orange color
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Row 2: Call & Chat Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final phone = order.deliveryAddress?.contactPersonNumber;
                    if (phone != null && phone.isNotEmpty) {
                      final Uri launchUri = Uri(scheme: 'tel', path: phone);
                      await launchUrl(launchUri);
                    }
                  },
                  icon: const Icon(Icons.phone_outlined, color: Colors.black87),
                  label: Text('Call', style: robotoMedium.copyWith(color: Colors.black87)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    side: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.chat_bubble_outline, color: Colors.black87),
                  label: Text('Chat', style: robotoMedium.copyWith(color: Colors.black87)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    side: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),

          // Row 3: Time & Distance
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  alignment: Alignment.center,
                  child: Text('-- min. to reach', style: robotoMedium.copyWith(color: Colors.black54)),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  alignment: Alignment.center,
                  child: Text('-- km away', style: robotoMedium.copyWith(color: Colors.black54)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Row 4: Cancel & Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => onOrderReleased(order),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    side: const BorderSide(color: Color(0xFFF37B21)),
                  ),
                  child: Text(
                    isRide ? 'Cancel Ride' : 'Cancel Order',
                    style: robotoMedium.copyWith(color: const Color(0xFFF37B21), fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    if (phase == 'going_to_store') {
                      onHandover(order);
                    } else if (phase == 'at_store') {
                      onPickedUp(order);
                    } else {
                      onDelivered(order);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    backgroundColor: const Color(0xFFF37B21),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: Text(
                    actionText,
                    style: robotoMedium.copyWith(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
