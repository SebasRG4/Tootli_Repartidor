class DeliveryManBodyModel {
  String? fName;
  String? lName;
  String? phone;
  String? email;
  String? password;
  String? identityType;
  String? identityNumber;
  String? earning;
  String? zoneId;
  String? vehicleId;
  String? referCode;

  DeliveryManBodyModel({
    this.fName,
    this.lName,
    this.phone,
    this.email,
    this.password,
    this.identityType,
    this.identityNumber,
    this.earning,
    this.zoneId,
    this.vehicleId,
    this.referCode,
  });

  DeliveryManBodyModel.fromJson(Map<String, dynamic> json) {
    fName = json['f_name'];
    lName = json['l_name'];
    phone = json['phone'];
    email = json['email'];
    password = json['password'];
    identityType = json['identity_type'];
    identityNumber = json['identity_number'];
    earning = json['earning'];
    zoneId = json['zone_id'];
    vehicleId = json['vehicle_id'];
    referCode = json['referral_code'];
  }

  Map<String, String> toJson() {
    final Map<String, String> data = <String, String>{};
    data['f_name'] = fName!;
    data['l_name'] = lName!;
    data['phone'] = phone!;
    data['email'] = email!;
    data['password'] = password!;
    data['identity_type'] = identityType!;
    data['identity_number'] = identityNumber!;
    data['earning'] = earning!;
    data['zone_id'] = zoneId!;
    data['vehicle_id'] = vehicleId!;
    if(referCode != null && referCode!.isNotEmpty) {
      data['referral_code'] = referCode!;
    }
    return data;
  }

  /// Reenvío de solicitud (token + campos; contraseña solo si se cambia).
  Map<String, String> toRevisionSubmitMap(String token) {
    final Map<String, String> data = <String, String>{
      'token': token,
      'f_name': fName ?? '',
      'l_name': lName ?? '',
      'phone': phone ?? '',
      'email': email ?? '',
      'identity_type': identityType ?? '',
      'identity_number': identityNumber ?? '',
      'earning': earning ?? '',
      'zone_id': zoneId ?? '',
      'vehicle_id': vehicleId ?? '',
    };
    if (password != null && password!.isNotEmpty) {
      data['password'] = password!;
    }
    if (referCode != null && referCode!.isNotEmpty) {
      data['referral_code'] = referCode!;
    }
    return data;
  }
}