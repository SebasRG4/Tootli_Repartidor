import 'dart:io';

import 'package:vibration/vibration.dart';
import 'package:audio_session/audio_session.dart' hide AndroidAudioFocus;
import 'package:audioplayers/audioplayers.dart' hide AVAudioSessionCategory;
import 'package:flutter/foundation.dart';

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

  final AudioPlayer _audioPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.loop);

  /// orderId pendiente cuando el callback aún no estaba registrado
  int? _pendingOrderId;

  /// Lista temporal para deduplicar notificaciones concurrentes (WS + FCM)
  final List<int> _processedOrderIds = [];

  void Function(int orderId)? _onOrderRequestTapped;

  /// Whether the DashboardScreen has registered its callback
  bool get hasCallback => _onOrderRequestTapped != null;

  /// DashboardScreen llama esto en initState para registrar el listener.
  set onOrderRequestTapped(void Function(int orderId)? callback) {
    debugPrint(
      "[OrderNotifService] 🔧 onOrderRequestTapped SET (callback is ${callback != null ? 'NOT null' : 'null'})",
    );
    _onOrderRequestTapped = callback;
    if (callback != null && _pendingOrderId != null) {
      final id = _pendingOrderId!;
      _pendingOrderId = null;
      debugPrint(
        "[OrderNotifService] 📦 Dispatching PENDING order $id to newly registered callback",
      );
      Future.microtask(() => callback(id));
    }
  }

  /// Mismo audio que un pedido real (`alert_new_delivery.mp3`), sin deduplicación ni callback.
  /// Útil para la simulación UI (FAB bug) sin confundir con `notifyOrderRequest`.
  void playOrderRequestAlertSound() {
    _playOrderRequestAlertSoundAsync();
  }

  Future<void> _playOrderRequestAlertSoundAsync() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(
        AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.duckOthers,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          avAudioSessionRouteSharingPolicy:
              AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.music,
            flags: AndroidAudioFlags.none,
            usage: AndroidAudioUsage.alarm,
          ),
          androidAudioFocusGainType:
              AndroidAudioFocusGainType.gainTransient,
          androidWillPauseWhenDucked: true,
        ),
      );
      await session.setActive(true);
    } catch (e) {
      debugPrint("[OrderNotifService] ⚠️ AudioSession config error: $e");
    }
    try {
      await _audioPlayer.setSource(AssetSource('alert_new_delivery.mp3'));
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.resume();
      debugPrint("[OrderNotifService] 🔊 Play command sent successfully");
    } catch (e, stack) {
      debugPrint("[OrderNotifService] ❌ Could not play audio: $e");
      debugPrint("[OrderNotifService] ❌ Stack: $stack");
    }
  }

  /// Llamado desde NotificationHelper o PusherService cuando el repartidor
  /// tiene una notificación de tipo [order_request] o [new_order].
  void notifyOrderRequest(int orderId) {
    // 🛡️ Deduplicación Híbrida: Si este orderId llegó en los últimos minutos
    // por Websocket o FCM, lo ignoramos para no repetir el Bottom Sheet ni el sonido.
    if (_processedOrderIds.contains(orderId)) {
      debugPrint(
        "[OrderNotifService] 🚫 DUPLICATE orderId $orderId ignored (Híbrido FCM/WS).",
      );
      return;
    }

    _processedOrderIds.add(orderId);
    if (_processedOrderIds.length > 50) {
      _processedOrderIds.removeAt(0); // keep memory light
    }

    debugPrint("[OrderNotifService] 📨 notifyOrderRequest($orderId) called");
    playOrderRequestAlertSound();
    try {
      Vibration.vibrate(duration: 1000);
    } catch (_) {}

    debugPrint(
      "[OrderNotifService] callback registered: ${_onOrderRequestTapped != null}",
    );
    if (_onOrderRequestTapped != null) {
      debugPrint(
        "[OrderNotifService] ✅ Calling _onOrderRequestTapped($orderId)",
      );
      _onOrderRequestTapped!(orderId);
    } else {
      debugPrint(
        "[OrderNotifService] ⚠️ No callback! Saving $orderId as pending",
      );
      _pendingOrderId = orderId;
    }
  }

  /// Detener el sonido de notificación (llamado al aceptar o rechazar un pedido)
  void stopAudio() {
    try {
      _audioPlayer.stop();
    } catch (e) {
      debugPrint("[OrderNotifService] ⚠️ Could not stop audio: $e");
    }
  }

  /// Sólo para usar en tests unitarios. Limpia el estado interno del singleton.
  /// NO llamar en código de producción.
  // ignore: invalid_use_of_visible_for_testing_member
  void resetForTesting() {
    _pendingOrderId = null;
    _processedOrderIds.clear();
    _onOrderRequestTapped = null;
  }
}
