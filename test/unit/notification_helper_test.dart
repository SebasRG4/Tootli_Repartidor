// NIVEL 1 — UNIT TESTS
// Testea la lógica pura de NotificationHelper.convertNotification y
// OrderNotificationService sin ninguna dependencia de UI, Firebase o GetX.

import 'package:flutter_test/flutter_test.dart';
import 'package:sixam_mart_delivery/helper/notification_helper.dart';
import 'package:sixam_mart_delivery/helper/order_notification_service.dart';
import 'package:sixam_mart_delivery/features/notification/domain/models/notification_body_model.dart';

void main() {
  // ─────────────────────────────────────────────────────────────
  // GRUPO 1: convertNotification
  // ─────────────────────────────────────────────────────────────
  group('NotificationHelper.convertNotification', () {
    // ── new_order ──────────────────────────────────────────────
    group('tipo new_order', () {
      test('retorna null si order_id falta (Fix #4 - crashea sin este fix)', () {
        final result = NotificationHelper.convertNotification({
          'type': 'new_order',
          // SIN order_id
        });
        expect(result, isNull,
            reason: 'Sin order_id no se puede construir el modelo');
      });

      test('retorna null si order_id es string no numérico', () {
        final result = NotificationHelper.convertNotification({
          'type': 'new_order',
          'order_id': 'abc-xyz',
        });
        expect(result, isNull);
      });

      test('retorna null si order_id es cadena vacía', () {
        final result = NotificationHelper.convertNotification({
          'type': 'new_order',
          'order_id': '',
        });
        expect(result, isNull);
      });

      test('parsea correctamente un order_id numérico válido', () {
        final result = NotificationHelper.convertNotification({
          'type': 'new_order',
          'order_id': '42',
        });
        expect(result, isNotNull);
        expect(result!.orderId, equals(42));
        expect(result.notificationType, equals(NotificationType.order_request));
      });

      test('order_id como int (no string) también funciona', () {
        final result = NotificationHelper.convertNotification({
          'type': 'new_order',
          'order_id': 99,
        });
        expect(result, isNotNull);
        expect(result!.orderId, equals(99));
      });
    });

    // ── order_request ──────────────────────────────────────────
    group('tipo order_request', () {
      test('retorna null si order_id falta', () {
        final result = NotificationHelper.convertNotification({
          'type': 'order_request',
        });
        expect(result, isNull);
      });

      test('mapea a NotificationType.order_request con ID válido', () {
        final result = NotificationHelper.convertNotification({
          'type': 'order_request',
          'order_id': '123',
        });
        expect(result?.notificationType, equals(NotificationType.order_request));
        expect(result?.orderId, equals(123));
      });
    });

    // ── order_status ───────────────────────────────────────────
    group('tipo order_status', () {
      test('retorna null si order_id falta', () {
        final result = NotificationHelper.convertNotification({
          'type': 'order_status',
        });
        expect(result, isNull);
      });

      test('mapea a NotificationType.order con ID válido', () {
        final result = NotificationHelper.convertNotification({
          'type': 'order_status',
          'order_id': '55',
        });
        expect(result?.notificationType, equals(NotificationType.order));
        expect(result?.orderId, equals(55));
      });
    });

    // ── tipos sin order_id ─────────────────────────────────────
    group('tipos que no necesitan order_id', () {
      test('block retorna NotificationType.block', () {
        final result = NotificationHelper.convertNotification({'type': 'block'});
        expect(result?.notificationType, equals(NotificationType.block));
      });

      test('unblock retorna NotificationType.unblock', () {
        final result = NotificationHelper.convertNotification({'type': 'unblock'});
        expect(result?.notificationType, equals(NotificationType.unblock));
      });

      test('otp retorna NotificationType.otp', () {
        final result = NotificationHelper.convertNotification({'type': 'otp'});
        expect(result?.notificationType, equals(NotificationType.otp));
      });

      test('withdraw retorna NotificationType.withdraw', () {
        final result =
            NotificationHelper.convertNotification({'type': 'withdraw'});
        expect(result?.notificationType, equals(NotificationType.withdraw));
      });

      test('tipo desconocido retorna general (no crashea)', () {
        final result = NotificationHelper.convertNotification({
          'type': 'tipo_que_no_existe_en_el_enum',
        });
        expect(result?.notificationType, equals(NotificationType.general));
      });

      test('data vacío retorna general (no crashea)', () {
        final result = NotificationHelper.convertNotification({});
        expect(result?.notificationType, equals(NotificationType.general));
      });
    });
  });

  // ─────────────────────────────────────────────────────────────
  // GRUPO 2: OrderNotificationService
  // ─────────────────────────────────────────────────────────────
  group('OrderNotificationService', () {
    // Reset el singleton entre tests para que no haya contaminación
    setUp(() {
      OrderNotificationService.instance.onOrderRequestTapped = null;
    });

    test('llama al callback inmediatamente si ya está registrado', () {
      int? receivedId;
      OrderNotificationService.instance.onOrderRequestTapped =
          (id) => receivedId = id;

      OrderNotificationService.instance.notifyOrderRequest(42);

      expect(receivedId, equals(42));
    });

    test('guarda el pedido como pendiente si el callback aún no está registrado', () async {
      // Notificar ANTES de registrar (race condition típico de background→foreground)
      OrderNotificationService.instance.notifyOrderRequest(99);

      int? receivedId;
      // Al registrar el callback, debería despacharse el ID pendiente
      OrderNotificationService.instance.onOrderRequestTapped =
          (id) => receivedId = id;

      // El despacho es con Future.microtask, esperamos un frame
      await Future.microtask(() {});

      expect(receivedId, equals(99),
          reason: 'El ID pendiente debe despacharse al registrar el callback');
    });

    test('el pending se limpia después de despacharse', () async {
      OrderNotificationService.instance.notifyOrderRequest(77);

      final List<int> received = [];
      OrderNotificationService.instance.onOrderRequestTapped =
          (id) => received.add(id);

      await Future.microtask(() {});

      // Registrar un segundo callback — NO debe recibir el 77 de nuevo
      final List<int> received2 = [];
      OrderNotificationService.instance.onOrderRequestTapped =
          (id) => received2.add(id);

      await Future.microtask(() {});

      expect(received, equals([77]));
      expect(received2, isEmpty,
          reason: 'El pending ya fue consumido, no debe redespacharse');
    });

    test('callback null no dispara llamada', () {
      OrderNotificationService.instance.onOrderRequestTapped = null;
      // No debe lanzar ninguna excepción
      expect(
        () => OrderNotificationService.instance.notifyOrderRequest(1),
        returnsNormally,
      );
    });
  });
}
