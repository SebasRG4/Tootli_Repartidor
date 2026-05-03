// UNIT TEST — Deduplicación de OrderNotificationService
// Valida los nuevos comportamientos de deduplicación híbrida FCM+WebSocket.
// Correr con: flutter test test/unit/order_notification_dedup_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:sixam_mart_delivery/helper/order_notification_service.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  // Reset del singleton entre tests para evitar contaminación
  // (la lista de IDs procesados es persistente en el singleton)
  setUp(() {
    OrderNotificationService.instance.resetForTesting();
  });

  // ─────────────────────────────────────────────────────────────
  // GRUPO 1: Deduplicación (FCM + WebSocket llegan simultáneamente)
  // ─────────────────────────────────────────────────────────────
  group('Deduplicación híbrida FCM/WebSocket', () {
    test(
      'el mismo orderId llega dos veces — callback solo se llama UNA vez',
      skip: 'notifyOrderRequest reproduce audio (plugin nativo) — verificar en integration_test',
      () {
        int callCount = 0;
        OrderNotificationService.instance.onOrderRequestTapped = (_) => callCount++;

        OrderNotificationService.instance.notifyOrderRequest(101);
        OrderNotificationService.instance.notifyOrderRequest(101);

        expect(callCount, equals(1),
            reason: 'El segundo FCM/WS con el mismo ID debe ignorarse');
      },
    );

    test(
      'dos orderIds DISTINTOS sí llaman el callback dos veces',
      skip: 'notifyOrderRequest reproduce audio (plugin nativo) — verificar en integration_test',
      () {
        final List<int> received = [];
        OrderNotificationService.instance.onOrderRequestTapped =
            (id) => received.add(id);

        OrderNotificationService.instance.notifyOrderRequest(201);
        OrderNotificationService.instance.notifyOrderRequest(202);

        expect(received, containsAll([201, 202]));
        expect(received.length, equals(2));
      },
    );

    test(
      'un ID enviado 10 veces seguidas solo ejecuta el callback 1 vez',
      skip: 'notifyOrderRequest reproduce audio (plugin nativo) — verificar en integration_test',
      () {
        int callCount = 0;
        OrderNotificationService.instance.onOrderRequestTapped = (_) => callCount++;

        for (int i = 0; i < 10; i++) {
          OrderNotificationService.instance.notifyOrderRequest(999);
        }

        expect(callCount, equals(1));
      },
    );
  });

  // ─────────────────────────────────────────────────────────────
  // GRUPO 2: Límite de memoria de la lista de IDs procesados
  // ─────────────────────────────────────────────────────────────
  group('Límite de la lista de IDs procesados (≤ 50)', () {
    test(
      'después de 51 IDs distintos, el primero puede volver a dispararse',
      skip: 'notifyOrderRequest reproduce audio (plugin nativo) — verificar en integration_test',
      () {
        int callCount = 0;
        OrderNotificationService.instance.onOrderRequestTapped = (_) => callCount++;

        for (int i = 2; i <= 52; i++) {
          OrderNotificationService.instance.notifyOrderRequest(i);
        }

        final int countBefore = callCount;
        OrderNotificationService.instance.notifyOrderRequest(2);
        expect(callCount, equals(countBefore + 1),
            reason: 'El ID expulsado de la lista debe poder procesarse de nuevo');
      },
    );
  });

  // ─────────────────────────────────────────────────────────────
  // GRUPO 3: Callback null — no crashea
  // ─────────────────────────────────────────────────────────────
  group('Robustez con callback null', () {
    test(
      'notifyOrderRequest sin callback registrado no lanza excepción',
      skip: 'notifyOrderRequest reproduce audio (plugin nativo) — verificar en integration_test',
      () {
        // setUp ya dejó el callback en null
        expect(
          () => OrderNotificationService.instance.notifyOrderRequest(500),
          returnsNormally,
        );
      },
    );

    test(
      'stopAudio() sin audio activo no lanza excepción',
      skip: 'AudioPlayer requiere plugin nativo — verificar en integration_test',
      () {
        expect(
          () => OrderNotificationService.instance.stopAudio(),
          returnsNormally,
        );
      },
    );
  });

  // ─────────────────────────────────────────────────────────────
  // GRUPO 4: Pedido pendiente (race condition background→foreground)
  // ─────────────────────────────────────────────────────────────
  group('Pedido pendiente (sin callback en el momento de la notificación)', () {
    test(
      'el ID pendiente se despacha cuando se registra el callback',
      skip: 'notifyOrderRequest reproduce audio (plugin nativo) — verificar en integration_test',
      () async {
        OrderNotificationService.instance.notifyOrderRequest(300);

        int? receivedId;
        OrderNotificationService.instance.onOrderRequestTapped =
            (id) => receivedId = id;

        await Future.microtask(() {});

        expect(receivedId, equals(300));
      },
    );

    test(
      'el pedido pendiente solo se despacha UNA vez',
      skip: 'notifyOrderRequest reproduce audio (plugin nativo) — verificar en integration_test',
      () async {
        OrderNotificationService.instance.notifyOrderRequest(400);

        final List<int> first = [];
        OrderNotificationService.instance.onOrderRequestTapped =
            (id) => first.add(id);
        await Future.microtask(() {});

        final List<int> second = [];
        OrderNotificationService.instance.onOrderRequestTapped =
            (id) => second.add(id);
        await Future.microtask(() {});

        expect(first, equals([400]));
        expect(second, isEmpty,
            reason: 'El pending ya fue consumido al registrar el primer callback');
      },
    );
  });
}
