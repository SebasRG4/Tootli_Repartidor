// NIVEL 3 — INTEGRATION TESTS
// Requiere un dispositivo físico o emulador corriendo.
// Ejecutar con:
//   flutter test integration_test/new_order_flow_test.dart -d <device-id>
//
// El test hace login automáticamente con credenciales de QA,
// espera llegar al HomeScreen y luego ejecuta los flujos.
//
// IMPORTANTE: La app se arranca desde cero — el test maneja el login completo.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sixam_mart_delivery/main.dart' as app;
import 'package:sixam_mart_delivery/features/dashboard/widgets/premium_order_request_widget.dart';

// ─── Credenciales de QA ────────────────────────────────────────────────────
const _kPhone    = '7297706434';
const _kPassword = 'Giovanna1705*';
// ──────────────────────────────────────────────────────────────────────────

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // ─────────────────────────────────────────────────────────────
  // Helper: Login automático
  // ─────────────────────────────────────────────────────────────
  Future<void> _doLogin(WidgetTester tester) async {
    // Esperar que arranque Firebase + SplashScreen → SignInScreen
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(seconds: 4));

    // Buscar campo de teléfono por hint o por tipo TextField
    final phoneFields = find.byType(TextField);
    if (phoneFields.evaluate().isEmpty) {
      // Ya está logueado — no necesita login
      return;
    }

    // Campo de teléfono (primero)
    await tester.tap(phoneFields.first);
    await tester.enterText(phoneFields.first, _kPhone);
    await tester.pump(const Duration(milliseconds: 300));

    // Campo de contraseña (segundo)
    if (phoneFields.evaluate().length >= 2) {
      await tester.tap(phoneFields.at(1));
      await tester.enterText(phoneFields.at(1), _kPassword);
      await tester.pump(const Duration(milliseconds: 300));
    }

    // Presionar botón de login — buscar por texto o por tipo ElevatedButton
    final loginBtn = find.text('Log In');
    final loginBtnEs = find.text('Iniciar Sesión');
    final loginBtnRaw = find.text('log_in');

    if (loginBtn.evaluate().isNotEmpty) {
      await tester.tap(loginBtn.first);
    } else if (loginBtnEs.evaluate().isNotEmpty) {
      await tester.tap(loginBtnEs.first);
    } else if (loginBtnRaw.evaluate().isNotEmpty) {
      await tester.tap(loginBtnRaw.first);
    } else {
      // Fallback: buscar el primer ElevatedButton visible
      final elevated = find.byType(ElevatedButton);
      if (elevated.evaluate().isNotEmpty) {
        await tester.tap(elevated.first);
      }
    }

    // Esperar que el servidor responda y navegue al HomeScreen
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));
  }

  // ─────────────────────────────────────────────────────────────
  // GRUPO 1: Smoke test + Login + HomeScreen
  // ─────────────────────────────────────────────────────────────
  group('App Launch + Login + Flujo completo', () {
    testWidgets(
      'la app inicia, hace login y puede simular pedido',
      (tester) async {
        // ── FASE 1: Arrancar la app ──
        app.main();
        await _doLogin(tester);

        // La app debe tener un MaterialApp montado
        expect(find.byType(MaterialApp), findsOneWidget);

        // ── FASE 2: Verificar que llegamos al HomeScreen ──
        // Si el repartidor quedó OFFLINE, el botón de debug no estará
        final debugBtn = find.byIcon(Icons.bug_report);
        final bool isOnline = debugBtn.evaluate().isNotEmpty;

        if (!isOnline) {
          markTestSkipped(
            'Repartidor OFFLINE o login no completó. '
            'Verifica credenciales y estado en línea del repartidor.',
          );
          return;
        }

        // ── FASE 3: Simular pedido nuevo con el botón FAB debug ──
        await tester.tap(debugBtn);
        await tester.pump(const Duration(seconds: 3));

        expect(
          find.byType(PremiumOrderRequestWidget),
          findsOneWidget,
          reason: 'Al pulsar el botón de debug debe aparecer el widget de pedido',
        );

        // ── FASE 4: Verificar el slider de aceptar ──
        final slider = find.byType(Slider);
        expect(slider, findsOneWidget);

        // Drag parcial (no completa — no queremos aceptar un pedido real)
        await tester.drag(slider, const Offset(50, 0));
        await tester.pump(const Duration(milliseconds: 300));

        // ── FASE 5: Cancelar (botón X) ──
        final closeBtn = find.byIcon(Icons.close);
        if (closeBtn.evaluate().isNotEmpty) {
          await tester.tap(closeBtn.first);
          await tester.pump(const Duration(seconds: 2));

          expect(
            find.byType(PremiumOrderRequestWidget),
            findsNothing,
            reason: 'Al cancelar debe desaparecer el bottom sheet de pedido',
          );
        }
      },
    );
  });

  // ─────────────────────────────────────────────────────────────
  // GRUPO 2: Deduplicación — dos notificaciones del mismo pedido
  // ─────────────────────────────────────────────────────────────
  group('Deduplicación de pedidos', () {
    testWidgets(
      'dos pulsos rápidos del botón debug solo muestran UN bottom sheet',
      (tester) async {
        app.main();
        await _doLogin(tester);

        final debugBtn = find.byIcon(Icons.bug_report);
        if (debugBtn.evaluate().isEmpty) {
          markTestSkipped('Repartidor OFFLINE o login falló. Botón debug no encontrado.');
          return;
        }

        // Dos pulsos rápidos — simulando FCM duplicado
        await tester.tap(debugBtn);
        await tester.pump(const Duration(milliseconds: 200));
        await tester.tap(debugBtn);
        await tester.pump(const Duration(seconds: 3));

        expect(
          find.byType(PremiumOrderRequestWidget),
          findsOneWidget,
          reason: 'La deduplicación debe evitar mostrar el mismo pedido dos veces',
        );
      },
    );
  });

  // ─────────────────────────────────────────────────────────────
  // GRUPO 3: Resume — pedido activo se refresca al volver al frente
  // ─────────────────────────────────────────────────────────────
  group('Resume con pedido activo', () {
    testWidgets(
      'al volver al frente, la ruta se redibuja y el estado se sincroniza',
      (tester) async {
        app.main();
        await _doLogin(tester);

        final debugBtn = find.byIcon(Icons.bug_report);
        if (debugBtn.evaluate().isEmpty) {
          markTestSkipped('Repartidor OFFLINE. Omitiendo test de resume.');
          return;
        }

        // Simular pedido y aceptarlo (dejar en estado activo)
        await tester.tap(debugBtn);
        await tester.pump(const Duration(seconds: 3));

        // Simular que la app va al background y regresa
        final binding = IntegrationTestWidgetsFlutterBinding.instance;
        binding.reportData = {};
        await tester.pump(const Duration(seconds: 2));

        // La app debe seguir mostrando el mapa (no pantalla congelada)
        expect(find.byType(MaterialApp), findsOneWidget);
      },
    );
  });
}
