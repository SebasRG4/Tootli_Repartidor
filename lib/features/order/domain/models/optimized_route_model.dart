class OptimizedRouteModel {
  List<RoutePoint>? sequence;

  OptimizedRouteModel({this.sequence});

  OptimizedRouteModel.fromJson(Map<String, dynamic> json) {
    if (json['sequence'] != null) {
      sequence = <RoutePoint>[];
      json['sequence'].forEach((v) {
        sequence!.add(RoutePoint.fromJson(v));
      });
    }
  }
}

class RoutePoint {
  String? id;
  String? type; // "pickup" or "delivery"
  int? orderId;
  double? latitude;
  double? longitude;
  double? waitTime;

  RoutePoint({this.id, this.type, this.orderId, this.latitude, this.longitude, this.waitTime});

  RoutePoint.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    type = json['type'];
    orderId = json['order_id'];
    latitude = json['latitude']?.toDouble();
    longitude = json['longitude']?.toDouble();
    waitTime = json['wait_time']?.toDouble();
  }
}
