class ResponseModel {
  final bool _isSuccess;
  final String? _message;
  final bool? _isRegistered;

  ResponseModel(this._isSuccess, this._message, {bool? isRegistered})
      : _isRegistered = isRegistered;

  String? get message => _message;
  bool get isSuccess => _isSuccess;
  bool? get isRegistered => _isRegistered;
}