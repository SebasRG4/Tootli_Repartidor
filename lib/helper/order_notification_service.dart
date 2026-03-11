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

  /// orderId pendiente cuando el callback aún no estaba registrado
  int? _pendingOrderId;

  void Function(int orderId)? _onOrderRequestTapped;

  /// DashboardScreen llama esto en initState para registrar el listener.
  set onOrderRequestTapped(void Function(int orderId)? callback) {
    _onOrderRequestTapped = callback;
    // Si llegó una notificación antes de que el callback estuviera listo, procesarla ahora
    if (callback != null && _pendingOrderId != null) {
      final id = _pendingOrderId!;
      _pendingOrderId = null;
      Future.microtask(() => callback(id));
    }
  }

  /// Llamado desde NotificationHelper cuando el repartidor toca una notificación
  /// de tipo [order_request] o [new_order].
  void notifyOrderRequest(int orderId) {
    if (_onOrderRequestTapped != null) {
      _onOrderRequestTapped!(orderId);
    } else {
      // Guardar para cuando DashboardScreen se inicialice y registre el callback
      _pendingOrderId = orderId;
    }
  }
}
