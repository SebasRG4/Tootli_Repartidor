import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:sixam_mart_delivery/helper/order_notification_service.dart';
import 'package:sixam_mart_delivery/features/splash/controllers/splash_controller.dart';

class PusherService {
  PusherService._();
  static final PusherService instance = PusherService._();

  WebSocketChannel? _channel;
  bool _isInitialized = false;

  final StreamController<dynamic> chatStreamController = StreamController<dynamic>.broadcast();

  /// Construye la URL del WebSocket: prioriza config del API, fallback a valor por defecto.
  static String _buildWsUrl() {
    try {
      final config = Get.find<SplashController>().configModel;
      if (config != null &&
          config.webSocketStatus == true &&
          (config.webSocketUri ?? '').isNotEmpty &&
          config.webSocketPort != null &&
          (config.webSocketKey ?? '').isNotEmpty) {
        final host = config.webSocketUri!.replaceFirst(RegExp(r'^https?://'), '').split('/').first;
        final port = config.webSocketPort!;
        final key = config.webSocketKey!;
        final url = 'ws://$host:$port/app/$key?protocol=7&client=js&version=8.4.0-rc2&flash=false';
        debugPrint("[PusherService] Using config WebSocket: ws://$host:$port");
        return url;
      }
    } catch (_) {}
    const fallback = "ws://15.235.73.88:6001/app/tootli-key?protocol=7&client=js&version=8.4.0-rc2&flash=false";
    debugPrint("[PusherService] Using fallback WebSocket URL");
    return fallback;
  }

  Future<void> initPusher(int deliverymanId) async {
    if (_isInitialized) return;

    try {
      final wsUrl = _buildWsUrl();
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _channel!.stream.listen(
        (message) {
          _handleMessage(message.toString(), deliverymanId);
        },
        onDone: () {
          debugPrint("[PusherService] WebSocket closed.");
          _isInitialized = false;
        },
        onError: (error) {
          debugPrint("[PusherService] WebSocket ERROR: $error");
          _isInitialized = false;
        },
      );

      _isInitialized = true;
      debugPrint("[PusherService] Successfully started WebSocket stream to Soketi.");
    } catch (e) {
      debugPrint("[PusherService] ERROR: $e");
    }
  }

  void _handleMessage(String message, int deliverymanId) {
    try {
      final jsonMsg = jsonDecode(message);
      final event = jsonMsg['event'];
      final dataStr = jsonMsg['data'];

      // 1. Respond to Pusher/Soketi Ping to keep connection alive
      if (event == "pusher:ping") {
        _channel?.sink.add(jsonEncode({"event": "pusher:pong"}));
        return;
      }

      // 2. Handle connection established
      if (event == "pusher:connection_established") {
        debugPrint("[PusherService] Connection established, sending subscription...");
        final subscribeMsg = jsonEncode({
          "event": "pusher:subscribe",
          "data": {
            "channel": "deliveryman-$deliverymanId"
          }
        });
        _channel?.sink.add(subscribeMsg);
      } 
      // 3. Handle custom events
      else if (event == "OrderAssigned") {
        final data = dataStr is String ? jsonDecode(dataStr) : dataStr;
        final orderIdStr = data['order_id'];
        if (orderIdStr != null) {
          final orderId = int.tryParse(orderIdStr.toString());
          if (orderId != null) {
            debugPrint("[PusherService] 🚀 Received WebSocket order: $orderId");
            OrderNotificationService.instance.notifyOrderRequest(orderId);
          }
        }
      }
      // MessageReceived: Laravel broadcastAs() = 'MessageReceived'; Soketi puede enviar tal cual o con namespace
      else if (event == "MessageReceived" ||
          event == "App\\Events\\MessageReceived" ||
          (event is String && event.endsWith("MessageReceived"))) {
        final data = dataStr is String ? jsonDecode(dataStr) : dataStr;
        debugPrint("[PusherService] 💬 Received Chat Message (event=$event)");
        if (data != null) chatStreamController.add(data);
      }
    } catch (e) {
      debugPrint("[PusherService] Failed to parse message: $e");
    }
  }

  Future<void> disconnect() async {
    try {
      await _channel?.sink.close();
      _isInitialized = false;
      debugPrint("[PusherService] Disconnected.");
    } catch (e) {
      debugPrint("[PusherService] Disconnect ERROR: $e");
    }
  }
}

