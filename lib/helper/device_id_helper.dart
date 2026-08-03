import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class DeviceIdHelper {
  static const _storage = FlutterSecureStorage();
  static const _key = 'secure_device_id';

  static Future<String> getUniqueDeviceId() async {
    try {
      String? deviceId = await _storage.read(key: _key);
      if (deviceId == null || deviceId.isEmpty) {
        deviceId = const Uuid().v4();
        await _storage.write(key: _key, value: deviceId);
      }
      return deviceId;
    } catch (e) {
      // Fallback in case of storage failure or platform-specific secure storage issues
      return 'fallback_device_id_sixam';
    }
  }
}
