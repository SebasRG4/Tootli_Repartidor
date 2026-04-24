import 'package:audioplayers/audioplayers.dart';

/// Servicio singleton que permite que NotificationHelper (sin contexto)
/// comunique un tap en notificación de pedido al DashboardScreen activo.
///
/// Resuelve el race condition background→foreground:
/// si notifyOrderRequest() se llama antes que DashboardScreen registre
/// su callback (onOrderRequestTapped), el orderId se guarda como pendiente
/// y se despacha automáticamente en cuanto el callback es registrado.
class OrderNotificationService {
  OrderNotificationService._();
  static final OrderNotificationService instance = OrderNotificationService._();

  final AudioPlayer _audioPlayer = AudioPlayer();

  /// orderId pendiente cuando el callback aún no estaba registrado
  int? _pendingOrderId;
  
  /// Lista temporal para deduplicar notificaciones concurrentes (WS + FCM)
  final List<int> _processedOrderIds = [];

  void Function(int orderId)? _onOrderRequestTapped;

  /// Whether the DashboardScreen has registered its callback
  bool get hasCallback => _onOrderRequestTapped != null;

  /// DashboardScreen llama esto en initState para registrar el listener.
  set onOrderRequestTapped(void Function(int orderId)? callback) {
    print("[OrderNotifService] 🔧 onOrderRequestTapped SET (callback is ${callback != null ? 'NOT null' : 'null'})");
    _onOrderRequestTapped = callback;
    if (callback != null && _pendingOrderId != null) {
      final id = _pendingOrderId!;
      _pendingOrderId = null;
      print("[OrderNotifService] 📦 Dispatching PENDING order $id to newly registered callback");
      Future.microtask(() => callback(id));
    }
  }

  /// Mismo audio que un pedido real (`alert_new_delivery.mp3`), sin deduplicación ni callback.
  /// Útil para la simulación UI (FAB bug) sin confundir con `notifyOrderRequest`.
  void playOrderRequestAlertSound() {
    try {
      _audioPlayer.stop().then((_) {
        _audioPlayer.play(AssetSource('alert_new_delivery.mp3'));
      });
    } catch (e) {
      print("[OrderNotifService] ⚠️ Could not play audio: $e");
    }
  }

  /// Llamado desde NotificationHelper o PusherService cuando el repartidor
  /// tiene una notificación de tipo [order_request] o [new_order].
  void notifyOrderRequest(int orderId) {
    // 🛡️ Deduplicación Híbrida: Si este orderId llegó en los últimos minutos
    // por Websocket o FCM, lo ignoramos para no repetir el Bottom Sheet ni el sonido.
    if (_processedOrderIds.contains(orderId)) {
      print("[OrderNotifService] 🚫 DUPLICATE orderId $orderId ignored (Híbrido FCM/WS).");
      return;
    }
    
    _processedOrderIds.add(orderId);
    if (_processedOrderIds.length > 50) {
      _processedOrderIds.removeAt(0); // keep memory light
    }

    print("[OrderNotifService] 📨 notifyOrderRequest($orderId) called");
    playOrderRequestAlertSound();

    print("[OrderNotifService] callback registered: ${_onOrderRequestTapped != null}");
    if (_onOrderRequestTapped != null) {
      print("[OrderNotifService] ✅ Calling _onOrderRequestTapped($orderId)");
      _onOrderRequestTapped!(orderId);
    } else {
      print("[OrderNotifService] ⚠️ No callback! Saving $orderId as pending");
      _pendingOrderId = orderId;
    }
  }

  /// Detener el sonido de notificación (llamado al aceptar o rechazar un pedido)
  void stopAudio() {
    try {
      _audioPlayer.stop();
    } catch (e) {
      print("[OrderNotifService] ⚠️ Could not stop audio: $e");
    }
  }
}
