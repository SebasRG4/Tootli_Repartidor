class OrderCancellationBody {
  int? totalSize;
  String? limit;
  String? offset;
  List<CancellationData>? reasons;

  OrderCancellationBody({this.totalSize, this.limit, this.offset, this.reasons});

  OrderCancellationBody.fromJson(Map<String, dynamic> json) {
    totalSize = json['total_size'];
    limit = json['limit'];
    offset = json['offset'];
    if (json['data'] != null) {
      reasons = <CancellationData>[];
      json['data'].forEach((v) {
        reasons!.add(CancellationData.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['total_size'] = totalSize;
    data['limit'] = limit;
    data['offset'] = offset;
    if (reasons != null) {
      data['reasons'] = reasons!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class CancellationData {
  int? id;
  String? reason;
  String? userType;
  int? status;
  String? createdAt;
  String? updatedAt;
  /// Backend: motivo marcado como exento de cola de revisión de strike (p. ej. accidente).
  bool exemptStrikeReview = false;

  CancellationData({
    this.id,
    this.reason,
    this.userType,
    this.status,
    this.createdAt,
    this.updatedAt,
    this.exemptStrikeReview = false,
  });

  CancellationData.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    reason = json['reason'];
    userType = json['user_type'];
    status = json['status'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    exemptStrikeReview = json['exempt_strike_review'] == true ||
        json['exempt_strike_review'] == 1;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['reason'] = reason;
    data['user_type'] = userType;
    data['status'] = status;
    data['created_at'] = createdAt;
    data['updated_at'] = updatedAt;
    data['exempt_strike_review'] = exemptStrikeReview;
    return data;
  }
}