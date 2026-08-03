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
  int? _deliverymanId;

  // Stream para mensajes de chat (broadcast = múltiples listeners)
  final StreamController<dynamic> chatStreamController =
      StreamController<dynamic>.broadcast();

  // Stream para estado de conexión: true = conectado, false = desconectado
  final StreamController<bool> connectionStatusController =
      StreamController<bool>.broadcast();

  bool get isConnected => _isInitialized;

  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;

  /// Construye la URL del WebSocket desde config o fallback.
  static String _buildWsUrl() {
    try {
      final config = Get.find<SplashController>().configModel;
      if (config != null &&
          config.webSocketStatus == true &&
          (config.webSocketUri ?? '').isNotEmpty &&
          config.webSocketPort != null &&
          (config.webSocketKey ?? '').isNotEmpty) {
        final host = config.webSocketUri!
            .replaceFirst(RegExp(r'^https?://'), '')
            .split('/')
            .first;
        final port = config.webSocketPort!;
        final key = config.webSocketKey!;
        final url =
            'ws://$host:$port/app/$key?protocol=7&client=js&version=7.0.6&flash=false';
        debugPrint('[PusherService] Using config WebSocket: $url');
        return url;
      }
    } catch (_) {}
    const fallback =
        'ws://15.235.73.88:6001/app/tootli-key?protocol=7&client=js&version=8.4.0-rc2&flash=false';
    debugPrint('[PusherService] Using fallback WebSocket URL');
    return fallback;
  }

  Future<void> initPusher(int deliverymanId) async {
    _deliverymanId = deliverymanId;
    _reconnectAttempts = 0;
    await _connect();
  }

  Future<void> _connect() async {
    if (_isInitialized) return;

    try {
      final wsUrl = _buildWsUrl();
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _channel!.stream.listen(
        (message) {
          debugPrint('[PusherService] 📥 Raw: $message');
          _handleMessage(message.toString());
        },
        onDone: () {
          debugPrint('[PusherService] ⚠️ WebSocket CLOSED.');
          _isInitialized = false;
          connectionStatusController.add(false);
          _scheduleReconnect();
        },
        onError: (error) {
          debugPrint('[PusherService] ❌ WebSocket ERROR: $error');
          _isInitialized = false;
          connectionStatusController.add(false);
          _scheduleReconnect();
        },
        cancelOnError: true,
      );

      _isInitialized = true;
      debugPrint('[PusherService] ✅ WebSocket connected.');
    } catch (e) {
      debugPrint('[PusherService] Connection ERROR: $e');
      _isInitialized = false;
      connectionStatusController.add(false);
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_reconnectTimer?.isActive == true) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('[PusherService] Max reconnect attempts reached.');
      return;
    }

    // Back-off exponencial: 2s, 4s, 8s... máx 30s
    final delay = Duration(
      seconds: (_reconnectAttempts < 5)
          ? (2 << _reconnectAttempts).clamp(2, 30)
          : 30,
    );
    _reconnectAttempts++;
    debugPrint(
        '[PusherService] Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts)...');

    _reconnectTimer = Timer(delay, () async {
      if (_deliverymanId != null && !_isInitialized) {
        await _connect();
      }
    });
  }

  void _handleMessage(String message) {
    try {
      final jsonMsg = jsonDecode(message);
      final event = jsonMsg['event'];
      final dataStr = jsonMsg['data'];

      // 1. Ping → Pong para mantener conexión viva
      if (event == 'pusher:ping') {
        _channel?.sink.add(jsonEncode({'event': 'pusher:pong'}));
        return;
      }

      // 2. Conexión establecida → suscribirse al canal del repartidor
      if (event == 'pusher:connection_established') {
        debugPrint('[PusherService] Connection established. Subscribing...');
        _reconnectAttempts = 0;
        connectionStatusController.add(true);

        if (_deliverymanId != null) {
          final subscribeMsg = jsonEncode({
            'event': 'pusher:subscribe',
            'data': {'channel': 'deliveryman-$_deliverymanId'}
          });
          _channel?.sink.add(subscribeMsg);
          debugPrint(
              '[PusherService] Subscribed to deliveryman-$_deliverymanId');
        }
        return;
      }

      // 3. Suscripción confirmada
      if (event == 'pusher_internal:subscription_succeeded') {
        debugPrint('[PusherService] ✅ Subscription confirmed.');
        return;
      }

      // 4. Pedido asignado
      if (event == 'OrderAssigned') {
        final data = dataStr is String ? jsonDecode(dataStr) : dataStr;
        final orderIdStr = data['order_id'];
        if (orderIdStr != null) {
          final orderId = int.tryParse(orderIdStr.toString());
          if (orderId != null) {
            debugPrint('[PusherService] 🚀 Order received: $orderId');
            OrderNotificationService.instance.notifyOrderRequest(orderId);
          }
        }
        return;
      }

      // 5. Mensaje de chat
      if (event == 'MessageReceived' ||
          event == 'App\\Events\\MessageReceived' ||
          (event is String && event.endsWith('MessageReceived'))) {
        final data = dataStr is String ? jsonDecode(dataStr) : dataStr;
        debugPrint('[PusherService] 💬 Chat message received (event=$event)');
        if (data != null) {
          chatStreamController.add(data);
        }
        return;
      }
    } catch (e) {
      debugPrint('[PusherService] Failed to parse message: $e');
    }
  }

  /// Reconecta manualmente (útil cuando el usuario vuelve al chat).
  Future<void> reconnectIfNeeded(int deliverymanId) async {
    _deliverymanId = deliverymanId;
    if (!_isInitialized) {
      _reconnectAttempts = 0;
      await _connect();
    }
  }

  Future<void> disconnect() async {
    try {
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      _reconnectAttempts = _maxReconnectAttempts; // evitar reconexión
      debugPrint('[PusherService] 🔌 Disconnecting...');
      await _channel?.sink.close();
      _isInitialized = false;
      connectionStatusController.add(false);
      debugPrint('[PusherService] ✅ Disconnected.');
    } catch (e) {
      debugPrint('[PusherService] Disconnect ERROR: $e');
    }
  }

  /// Reinicia el contador de reconexión (útil al hacer logout/login).
  void resetReconnectAttempts() {
    _reconnectAttempts = 0;
  }
}
