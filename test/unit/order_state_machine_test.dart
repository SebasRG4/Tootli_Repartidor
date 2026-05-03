// UNIT TEST — Máquina de estados del flujo de pedido
// Valida las reglas de transición de _orderPhase y los estados terminales
// sin necesidad de UI, GetX, Firebase, ni dispositivo.
// Correr con: flutter test test/unit/order_state_machine_test.dart

import 'dart:math';
import 'package:flutter_test/flutter_test.dart';

// ─────────────────────────────────────────────────────────────
// Lógica extraída de HomeScreen para testear de forma pura.
// Refleja exactamente la lógica de restoreActiveOrder y _onAppResumed.
// ─────────────────────────────────────────────────────────────

/// Determina la fase de entrega según el `orderStatus` del servidor.
/// Refleja la lógica de [HomeScreenState.restoreActiveOrder] y [_onAppResumed].
String resolveOrderPhase(String orderStatus) {
  if (orderStatus == 'picked_up') {
    return 'going_to_customer';
  } else if (orderStatus == 'delivered' ||
      orderStatus == 'canceled' ||
      orderStatus == 'returned' ||
      orderStatus == 'failed') {
    return 'terminal';
  } else {
    // handover, processing, confirmed, pending, etc.
    return 'going_to_store';
  }
}

/// Detecta si un estado es terminal (pedido ya no activo).
/// Refleja el guard de [HomeScreenState._onAppResumed].
bool isTerminalStatus(String status) {
  const terminal = {'delivered', 'canceled', 'returned', 'failed'};
  return terminal.contains(status);
}

/// Haversine — refleja exactamente [HomeScreenState._calculateDistance].
double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
  var p = 0.017453292519943295;
  var c = cos;
  var a = 0.5 -
      c((lat2 - lat1) * p) / 2 +
      c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
  return 12742 * asin(sqrt(a)) * 1000; // metros
}

void main() {
  // ─────────────────────────────────────────────────────────────
  // GRUPO 1: Resolución de fase a partir del orderStatus
  // ─────────────────────────────────────────────────────────────
  group('resolveOrderPhase — lógica de restoreActiveOrder', () {
    test('picked_up → going_to_customer', () {
      expect(resolveOrderPhase('picked_up'), equals('going_to_customer'));
    });

    test('handover → going_to_store', () {
      expect(resolveOrderPhase('handover'), equals('going_to_store'));
    });

    test('processing → going_to_store', () {
      expect(resolveOrderPhase('processing'), equals('going_to_store'));
    });

    test('confirmed → going_to_store', () {
      expect(resolveOrderPhase('confirmed'), equals('going_to_store'));
    });

    test('pending → going_to_store (fallback seguro)', () {
      expect(resolveOrderPhase('pending'), equals('going_to_store'));
    });

    test('estado desconocido → going_to_store (sin crash)', () {
      expect(resolveOrderPhase('estado_inventado_123'), equals('going_to_store'));
    });

    test('delivered → terminal', () {
      expect(resolveOrderPhase('delivered'), equals('terminal'));
    });

    test('canceled → terminal', () {
      expect(resolveOrderPhase('canceled'), equals('terminal'));
    });

    test('returned → terminal', () {
      expect(resolveOrderPhase('returned'), equals('terminal'));
    });

    test('failed → terminal', () {
      expect(resolveOrderPhase('failed'), equals('terminal'));
    });
  });

  // ─────────────────────────────────────────────────────────────
  // GRUPO 2: Detección de estados terminales (_onAppResumed guard)
  // ─────────────────────────────────────────────────────────────
  group('isTerminalStatus — guard de _onAppResumed', () {
    test('delivered es terminal', () => expect(isTerminalStatus('delivered'), isTrue));
    test('canceled es terminal', () => expect(isTerminalStatus('canceled'), isTrue));
    test('returned es terminal', () => expect(isTerminalStatus('returned'), isTrue));
    test('failed es terminal', () => expect(isTerminalStatus('failed'), isTrue));
    test('picked_up NO es terminal', () => expect(isTerminalStatus('picked_up'), isFalse));
    test('handover NO es terminal', () => expect(isTerminalStatus('handover'), isFalse));
    test('string vacío NO es terminal', () => expect(isTerminalStatus(''), isFalse));
  });

  // ─────────────────────────────────────────────────────────────
  // GRUPO 3: Fórmula Haversine (_calculateDistance)
  // ─────────────────────────────────────────────────────────────
  group('calculateDistance — Haversine', () {
    test('misma coordenada = 0 metros', () {
      final d = calculateDistance(19.4326, -99.1332, 19.4326, -99.1332);
      expect(d, closeTo(0, 0.001));
    });

    test('Ciudad de México → Guadalajara ≈ 460 km', () {
      // CDMX: 19.4326° N, 99.1332° W
      // GDL:  20.6597° N, 103.3496° W
      final d = calculateDistance(19.4326, -99.1332, 20.6597, -103.3496);
      // ~460 km en metros
      expect(d, greaterThan(400000));
      expect(d, lessThan(520000));
    });

    test('1 manzana (~100m) retorna valor razonable', () {
      // Desplazamiento de ~0.001 grados lat ≈ 111 metros
      final d = calculateDistance(19.4326, -99.1332, 19.4336, -99.1332);
      expect(d, greaterThan(50));
      expect(d, lessThan(200));
    });

    test('valores negativos (coordenadas inversas) no causan NaN', () {
      final d = calculateDistance(-33.8688, 151.2093, -37.8136, 144.9631);
      expect(d.isNaN, isFalse);
      expect(d.isInfinite, isFalse);
      expect(d, greaterThan(0));
    });
  });
}
