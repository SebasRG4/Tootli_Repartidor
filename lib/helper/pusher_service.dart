import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:sixam_mart_delivery/helper/order_notification_service.dart';

class PusherService {
  PusherService._();
  static final PusherService instance = PusherService._();

  WebSocketChannel? _channel;
  bool _isInitialized = false;

  Future<void> initPusher(int deliverymanId) async {
    if (_isInitialized) return;

    try {
      // Connect to Soketi WebSocket using native Pusher Protocol V7
      const String wsUrl = "ws://15.235.73.88:6001/app/tootli-key?protocol=7&client=js&version=8.4.0-rc2&flash=false";
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

      // When connection is established, subscribe to the channel
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
      // Handle custom events
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

