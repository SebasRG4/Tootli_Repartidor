class TripModel {
  int? id;
  int? customerId;
  String? customerName;
  String? customerPhone;
  String? customerImage;
  
  double? pickupLat;
  double? pickupLng;
  String? pickupAddress;
  
  double? destinationLat;
  double? destinationLng;
  String? destinationAddress;
  
  double? estimatedPrice;
  double? estimatedDistance; // in km
  String? tripStatus; // pending, accepted, arriving, ongoing, completed, cancelled
  
  String? createdAt;

  TripModel({
    this.id,
    this.customerId,
    this.customerName,
    this.customerPhone,
    this.customerImage,
    this.pickupLat,
    this.pickupLng,
    this.pickupAddress,
    this.destinationLat,
    this.destinationLng,
    this.destinationAddress,
    this.estimatedPrice,
    this.estimatedDistance,
    this.tripStatus,
    this.createdAt,
  });

  TripModel.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    customerId = json['customer_id'];
    customerName = json['customer_name'] ?? json['user_name'];
    customerPhone = json['customer_phone'] ?? json['user_phone'];
    customerImage = json['customer_image'];
    
    pickupLat = json['pickup_lat'] != null ? double.tryParse(json['pickup_lat'].toString()) : null;
    pickupLng = json['pickup_lng'] != null ? double.tryParse(json['pickup_lng'].toString()) : null;
    pickupAddress = json['pickup_address'];
    
    destinationLat = json['destination_lat'] != null ? double.tryParse(json['destination_lat'].toString()) : null;
    destinationLng = json['destination_lng'] != null ? double.tryParse(json['destination_lng'].toString()) : null;
    destinationAddress = json['destination_address'];
    
    estimatedPrice = json['estimated_price'] != null ? double.tryParse(json['estimated_price'].toString()) : null;
    estimatedDistance = json['estimated_distance'] != null ? double.tryParse(json['estimated_distance'].toString()) : null;
    
    tripStatus = json['trip_status'] ?? json['status'];
    createdAt = json['created_at'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['customer_id'] = customerId;
    data['customer_name'] = customerName;
    data['customer_phone'] = customerPhone;
    data['customer_image'] = customerImage;
    data['pickup_lat'] = pickupLat;
    data['pickup_lng'] = pickupLng;
    data['pickup_address'] = pickupAddress;
    data['destination_lat'] = destinationLat;
    data['destination_lng'] = destinationLng;
    data['destination_address'] = destinationAddress;
    data['estimated_price'] = estimatedPrice;
    data['estimated_distance'] = estimatedDistance;
    data['trip_status'] = tripStatus;
    data['created_at'] = createdAt;
    return data;
  }
}
