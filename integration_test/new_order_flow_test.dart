// NIVEL 3 — INTEGRATION TESTS
// Requiere un dispositivo físico o emulador corriendo.
// Ejecutar con:
//   flutter test integration_test/new_order_flow_test.dart -d <device-id>
//
// DISEÑO: Se lanza app.main() UNA sola vez en setUpAll para evitar que el
// SplashScreen de GetX tenga callbacks async en vuelo cuando un test termina y el
// siguiente empieza (lo que causaba el error "contextless navigation").
//
// Se usa pump(Duration) en lugar de pumpAndSettle porque la app tiene
// un timer periódico de location tracking que nunca termina.
//
// PREREQUISITO para los tests del grupo 2 y 3:
// El repartidor debe estar ONLINE y en la pantalla Home cuando se corren los tests.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sixam_mart_delivery/main.dart' as app;
import 'package:sixam_mart_delivery/features/dashboard/widgets/premium_order_request_widget.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // ─────────────────────────────────────────────────────────────
  // GRUPO 1: Smoke test — la app arranca sin crashear
  // Lanzamos app.main() UNA vez y luego hacemos todos los checks
  // en un solo testWidgets para evitar múltiples instancias del SplashScreen.
  // ─────────────────────────────────────────────────────────────
  group('App Launch + Flujo completo', () {
    testWidgets(
      'la app inicia, detecta repartidor online y puede simular pedido',
      (tester) async {
        // ---- FASE 1: Arrancar la app ----
        app.main();
        // Esperar carga inicial: Firebase, GetX, SplashScreen → HomeScreen
        await tester.pump(const Duration(seconds: 10));
        await tester.pump(const Duration(milliseconds: 500));

        // La app debe tener un MaterialApp
        expect(find.byType(MaterialApp), findsOneWidget);

        // ---- FASE 2: Verificar que llegamos al Home ----
        // (si el repartidor está offline, el botón 🐛 no estará visible)
        final debugBtn = find.byIcon(Icons.bug_report);
        final bool isOnline = debugBtn.evaluate().isNotEmpty;

        if (!isOnline) {
          // Repartidor offline: marcamos como skipped pero el smoke pasó
          markTestSkipped(
            'Repartidor OFFLINE. Tests del flujo de pedido omitidos. '
            'Para ejecutarlos completos, pon el repartidor en línea y vuelve a correr.',
          );
          return;
        }

        // ---- FASE 3: Simular pedido nuevo ----
        await tester.tap(debugBtn);
        await tester.pump(const Duration(seconds: 3));
        await tester.pump(const Duration(milliseconds: 500));

        expect(
          find.byType(PremiumOrderRequestWidget),
          findsOneWidget,
          reason: 'Al pulsar el botón de debug debe aparecer el widget de pedido',
        );

        // ---- FASE 4: Verificar el Slider ----
        final slider = find.byType(Slider);
        expect(slider, findsOneWidget);

        // Drag parcial (no completa para no aceptar el pedido)
        await tester.drag(slider, const Offset(50, 0));
        await tester.pump(const Duration(milliseconds: 300));

        // ---- FASE 5: Cancelar el pedido (botón X) ----
        final closeBtn = find.byIcon(Icons.close);
        if (closeBtn.evaluate().isNotEmpty) {
          await tester.tap(closeBtn.first);
          await tester.pump(const Duration(seconds: 2));

          expect(
            find.byType(PremiumOrderRequestWidget),
            findsNothing,
            reason: 'Al cancelar debe desaparecer el bottom sheet',
          );
        }
      },
    );
  });

  // ─────────────────────────────────────────────────────────────
  // GRUPO 2: Deduplicación — en un test separado para el botón debug
  // NOTA: Este test tiene su propio ciclo de vida intencionalmente separado
  // para verificar que los IDs se reinician entre sesiones de la app.
  // ─────────────────────────────────────────────────────────────
  group('Deduplicación de pedidos', () {
    testWidgets(
      'dos pulsos rápidos del botón debug solo muestran UN bottom sheet',
      (tester) async {
        app.main();
        await tester.pump(const Duration(seconds: 10));
        await tester.pump(const Duration(milliseconds: 500));

        final debugBtn = find.byIcon(Icons.bug_report);
        if (debugBtn.evaluate().isEmpty) {
          markTestSkipped('Repartidor OFFLINE. Botón de debug no encontrado.');
          return;
        }

        // Dos pulsos rápidos simulando duplicado de FCM
        await tester.tap(debugBtn);
        await tester.pump(const Duration(milliseconds: 200));
        await tester.tap(debugBtn);
        await tester.pump(const Duration(seconds: 3));
        await tester.pump(const Duration(milliseconds: 500));

        expect(
          find.byType(PremiumOrderRequestWidget),
          findsOneWidget,
          reason: 'La deduplicación debe evitar mostrar el mismo pedido dos veces',
        );
      },
    );
  });
}
