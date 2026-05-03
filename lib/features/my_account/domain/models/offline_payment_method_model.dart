class OfflinePaymentMethodModel {
  int? id;
  String? methodName;
  List<MethodFields>? methodFields;
  List<MethodInformations>? methodInformations;

  OfflinePaymentMethodModel(
      {this.id,
      this.methodName,
      this.methodFields,
      this.methodInformations});

  OfflinePaymentMethodModel.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    methodName = json['method_name'];
    if (json['method_fields'] != null) {
      methodFields = <MethodFields>[];
      json['method_fields'].forEach((v) {
        methodFields!.add(MethodFields.fromJson(v));
      });
    }
    if (json['method_informations'] != null) {
      methodInformations = <MethodInformations>[];
      json['method_informations'].forEach((v) {
        methodInformations!.add(MethodInformations.fromJson(v));
      });
    }
  }
}

class MethodFields {
  String? inputName;
  String? inputData;

  MethodFields({this.inputName, this.inputData});

  MethodFields.fromJson(Map<String, dynamic> json) {
    inputName = json['input_name'];
    inputData = json['input_data'];
  }
}

class MethodInformations {
  String? customerInput;
  String? customerPlaceholder;
  int? isRequired;

  MethodInformations(
      {this.customerInput, this.customerPlaceholder, this.isRequired});

  MethodInformations.fromJson(Map<String, dynamic> json) {
    customerInput = json['customer_input'];
    customerPlaceholder = json['customer_placeholder'];
    isRequired = json['is_required'];
  }
}
