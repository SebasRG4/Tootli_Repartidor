class MissionModel {
  int? id;
  String? title;
  String? description;
  int? targetOrders;
  double? rewardAmount;
  String? startDate;
  String? endDate;
  int? zoneId;
  int? status;
  int? currentProgress;
  bool? isCompleted;

  MissionModel({
    this.id,
    this.title,
    this.description,
    this.targetOrders,
    this.rewardAmount,
    this.startDate,
    this.endDate,
    this.zoneId,
    this.status,
    this.currentProgress,
    this.isCompleted,
  });

  MissionModel.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    title = json['title'];
    description = json['description'];
    targetOrders = json['target_orders'];
    rewardAmount = json['reward_amount']?.toDouble();
    startDate = json['start_date'];
    endDate = json['end_date'];
    zoneId = json['zone_id'];
    status = json['status'];
    currentProgress = json['current_progress'];
    isCompleted = json['is_completed'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['title'] = title;
    data['description'] = description;
    data['target_orders'] = targetOrders;
    data['reward_amount'] = rewardAmount;
    data['start_date'] = startDate;
    data['end_date'] = endDate;
    data['zone_id'] = zoneId;
    data['status'] = status;
    data['current_progress'] = currentProgress;
    data['is_completed'] = isCompleted;
    return data;
  }
}
