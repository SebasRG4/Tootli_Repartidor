import 'package:get/get.dart';

/// Resultado del registro de repartidor (API puede incluir token para sesión inmediata).
class RegisterDmResult {
  final bool success;
  final bool legacyHttpOkWithoutToken;
  final String? token;
  final String zoneTopic;
  final String topic;

  const RegisterDmResult({
    required this.success,
    this.legacyHttpOkWithoutToken = false,
    this.token,
    this.zoneTopic = '',
    this.topic = '',
  });

  factory RegisterDmResult.fromResponse(Response response) {
    if (response.statusCode != 200 || response.body is! Map) {
      return const RegisterDmResult(success: false);
    }
    final Map<String, dynamic> m = Map<String, dynamic>.from(response.body as Map);
    final String? token = m['token']?.toString();
    if (token != null && token.isNotEmpty) {
      return RegisterDmResult(
        success: true,
        token: token,
        zoneTopic: m['zone_topic']?.toString() ?? '',
        topic: m['topic']?.toString() ?? '',
      );
    }
    return const RegisterDmResult(
      success: false,
      legacyHttpOkWithoutToken: true,
    );
  }
}
