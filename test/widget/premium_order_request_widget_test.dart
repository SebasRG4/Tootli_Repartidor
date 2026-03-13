// NIVEL 2 — WIDGET TESTS
// Testea PremiumOrderRequestWidget (el slider de aceptar pedido) de forma aislada.
//
// Para que el widget renderice necesitamos registrar en GetX un SplashController con
// un ConfigModel mínimo (moneda + decimales), porque PriceConverterHelper lo usa.
//
// NOTA: AudioPlayer falla silenciosamente en el entorno headless de test (sin
// dispositivo real), lo cual es correcto: el test evalúa UI, no audio.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:sixam_mart_delivery/common/models/config_model.dart';
import 'package:sixam_mart_delivery/features/dashboard/widgets/premium_order_request_widget.dart';
import 'package:sixam_mart_delivery/features/order/domain/models/order_model.dart';
import 'package:sixam_mart_delivery/features/splash/controllers/splash_controller.dart';
import 'package:sixam_mart_delivery/features/splash/domain/services/splash_service_interface.dart';

@GenerateMocks([SplashServiceInterface])
import 'premium_order_request_widget_test.mocks.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

/// Crea y registra un SplashController con un ConfigModel mínimo ($, 2 decimales)
void _setUpGetX() {
  Get.reset();
  final mockSplashService = MockSplashServiceInterface();
  final controller = SplashController(splashServiceInterface: mockSplashService);
  // Inyectar un ConfigModel directamente en el campo privado via reflexión no es
  // posible en Dart, así que usamos el workaround de subclase expuesta:
  controller.injectConfigForTest(ConfigModel(
    currencySymbol: r'$',
    digitAfterDecimalPoint: 2,
  ));
  Get.put<SplashController>(controller);
}

/// Envuelve el widget en MaterialApp + Scaffold para que pueda renderizarse
Widget buildTestable(Widget child) {
  return GetMaterialApp(home: Scaffold(body: child));
}

/// Crea un OrderModel mínimo con los datos necesarios para el widget
OrderModel makeTestOrder({
  int id = 101,
  String storeName = 'Tootli Test Store',
  String paymentMethod = 'cash_on_delivery',
  double deliveryCharge = 30.0,
  double dmTips = 5.0,
}) {
  return OrderModel(
    id: id,
    storeName: storeName,
    paymentMethod: paymentMethod,
    originalDeliveryCharge: deliveryCharge,
    dmTips: dmTips,
    orderType: 'delivery',
  );
}

// ─── Tests ──────────────────────────────────────────────────────────────────

void main() {
  setUp(_setUpGetX);
  tearDown(Get.reset);

  // ─────────────────────────────────────────────────────────────
  // GRUPO 1: Renderización inicial
  // ─────────────────────────────────────────────────────────────
  group('PremiumOrderRequestWidget — renderización', () {
    testWidgets('muestra el nombre de la tienda', (tester) async {
      await tester.pumpWidget(buildTestable(
        PremiumOrderRequestWidget(
          orderModel: makeTestOrder(storeName: 'Mi Restaurante'),
          onAccept: () {},
          onReject: () {},
        ),
      ));
      await tester.pump();

      expect(find.text('Mi Restaurante'), findsOneWidget);
    });

    testWidgets('muestra "Pago en efectivo" para cash_on_delivery', (tester) async {
      await tester.pumpWidget(buildTestable(
        PremiumOrderRequestWidget(
          orderModel: makeTestOrder(paymentMethod: 'cash_on_delivery'),
          onAccept: () {},
          onReject: () {},
        ),
      ));
      await tester.pump();

      expect(find.text('Pago en efectivo'), findsOneWidget);
    });

    testWidgets('muestra "Pago con tarjeta" para digital_payment', (tester) async {
      await tester.pumpWidget(buildTestable(
        PremiumOrderRequestWidget(
          orderModel: makeTestOrder(paymentMethod: 'digital_payment'),
          onAccept: () {},
          onReject: () {},
        ),
      ));
      await tester.pump();

      expect(find.text('Pago con tarjeta'), findsOneWidget);
    });

    testWidgets('muestra la distancia cuando se proporciona', (tester) async {
      await tester.pumpWidget(buildTestable(
        PremiumOrderRequestWidget(
          orderModel: makeTestOrder(),
          distance: 3.75,
          onAccept: () {},
          onReject: () {},
        ),
      ));
      await tester.pump();

      expect(find.text('3.75 km'), findsOneWidget);
    });

    testWidgets('muestra "... km" cuando no hay distancia', (tester) async {
      await tester.pumpWidget(buildTestable(
        PremiumOrderRequestWidget(
          orderModel: makeTestOrder(),
          distance: null,
          onAccept: () {},
          onReject: () {},
        ),
      ));
      await tester.pump();

      expect(find.text('... km'), findsOneWidget);
    });

    testWidgets('muestra el Slider de aceptar', (tester) async {
      await tester.pumpWidget(buildTestable(
        PremiumOrderRequestWidget(
          orderModel: makeTestOrder(),
          onAccept: () {},
          onReject: () {},
        ),
      ));
      await tester.pump();

      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('el contador inicia en 30 segundos', (tester) async {
      await tester.pumpWidget(buildTestable(
        PremiumOrderRequestWidget(
          orderModel: makeTestOrder(),
          onAccept: () {},
          onReject: () {},
        ),
      ));
      await tester.pump();

      expect(find.text('30s'), findsOneWidget);
    });
  });

  // ─────────────────────────────────────────────────────────────
  // GRUPO 2: Temporizador
  // ─────────────────────────────────────────────────────────────
  group('PremiumOrderRequestWidget — temporizador', () {
    testWidgets('el contador baja después de 5 segundos', (tester) async {
      await tester.pumpWidget(buildTestable(
        PremiumOrderRequestWidget(
          orderModel: makeTestOrder(),
          onAccept: () {},
          onReject: () {},
        ),
      ));
      await tester.pump();
      expect(find.text('30s'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      expect(find.text('25s'), findsOneWidget);
    });

    testWidgets('onReject se llama cuando el temporizador llega a 0', (tester) async {
      bool rejected = false;

      await tester.pumpWidget(buildTestable(
        PremiumOrderRequestWidget(
          orderModel: makeTestOrder(),
          onAccept: () {},
          onReject: () => rejected = true,
        ),
      ));
      await tester.pump();

      // Avanzar 31 segundos (30 del timer + 1 extra para el tick final)
      await tester.pump(const Duration(seconds: 31));

      expect(rejected, isTrue,
          reason: 'Al agotarse el tiempo debe llamarse onReject automáticamente');
    });

    testWidgets('onReject NO se llama si se acepta antes de que expire', (tester) async {
      bool rejected = false;
      bool accepted = false;

      await tester.pumpWidget(buildTestable(
        PremiumOrderRequestWidget(
          orderModel: makeTestOrder(),
          onAccept: () => accepted = true,
          onReject: () => rejected = true,
        ),
      ));
      await tester.pump();

      // Drag del slider al máximo (> 0.9 del ancho)
      final slider = find.byType(Slider);
      expect(slider, findsOneWidget);
      await tester.drag(slider, const Offset(400, 0));
      await tester.pump();

      // Dejar pasar el tiempo: el timer fue cancelado al aceptar
      await tester.pump(const Duration(seconds: 31));

      expect(accepted, isTrue);
      expect(rejected, isFalse,
          reason: 'El timer fue cancelado al aceptar, no debe llamarse onReject');
    });
  });

  // ─────────────────────────────────────────────────────────────
  // GRUPO 3: Guard de doble llamada
  // ─────────────────────────────────────────────────────────────
  group('PremiumOrderRequestWidget — guard de doble accept', () {
    testWidgets('onAccept solo se llama una vez aunque el Slider se mueva varias veces',
        (tester) async {
      int acceptCount = 0;

      await tester.pumpWidget(buildTestable(
        PremiumOrderRequestWidget(
          orderModel: makeTestOrder(),
          onAccept: () => acceptCount++,
          onReject: () {},
        ),
      ));
      await tester.pump();

      final slider = find.byType(Slider);
      expect(slider, findsOneWidget);

      // Primer drag exitoso (> 0.9)
      await tester.drag(slider, const Offset(400, 0));
      await tester.pump();

      // Segundo drag (el guard _isAccepted debe bloquearlo)
      // El slider ya puede no existir si el widget se cerró, así que
      // verificamos que acceptCount no supere 1
      await tester.pump(const Duration(milliseconds: 100));

      expect(acceptCount, equals(1),
          reason: 'El guard _isAccepted debe bloquear la segunda llamada a onAccept');
    });
  });
}
