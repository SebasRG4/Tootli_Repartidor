import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart_delivery/features/order/controllers/order_controller.dart';
import 'package:sixam_mart_delivery/features/order/domain/models/order_model.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_app_bar_widget.dart';
import 'package:flutter_mapbox_navigation/flutter_mapbox_navigation.dart';
import 'package:sixam_mart_delivery/features/order/controllers/order_location_controller.dart';

class OrderLocationScreen extends StatelessWidget {
  final OrderModel orderModel;
  final OrderController orderController;
  final int index;
  final Function onTap;
  
  const OrderLocationScreen({
    super.key, 
    required this.orderModel, 
    required this.orderController, 
    required this.index, 
    required this.onTap
  });

  @override
  Widget build(BuildContext context) {
    // Inyectar o recuperar el controlador para que GetX lo maneje
    final controller = Get.put(OrderLocationController(orderModel: orderModel));
    // Notificar al controlador si el modelo de la orden cambió (ej. de recogido a yendo al cliente)
    controller.updateOrderModel(orderModel);

    return GetBuilder<OrderLocationController>(
      builder: (controller) {
        if (controller.isMapLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return MapBoxNavigationView(
          options: controller.navigationOption,
          onRouteEvent: controller.onRouteEvent,
          onCreated: controller.onMapCreated,
        );
      },
    );
  }
}
