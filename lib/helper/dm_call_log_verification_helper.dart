import 'dart:io';

import 'package:call_log/call_log.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Comprueba [READ_CALL_LOG] (grupo "Teléfono" en [Permission.phone] en Android) y
/// busca salientes hacia [targetPhoneRaw]. iOS no tiene API pública para historial: no se usa.
class DmCallLogVerificationHelper {
  DmCallLogVerificationHelper._();

  static bool get isAndroid => !kIsWeb && Platform.isAndroid;

  /// Pide [Permission.phone], que con READ_CALL_LOG en el manifest incluye el registro de llamadas.
  static Future<bool> ensureCallLogAccess() async {
    if (!isAndroid) {
      return false;
    }
    if (await Permission.phone.isGranted) {
      return true;
    }
    final PermissionStatus s = await Permission.phone.request();
    return s.isGranted;
  }

  /// Saliente reciente a [targetPhoneRaw] (normalizado) desde [notBefore] con al menos 1 s de duración.
  static Future<bool> hasRecentOutgoingCallTo({
    required String? targetPhoneRaw,
    required DateTime notBefore,
  }) async {
    if (!isAndroid) {
      return false;
    }
    final String? want = _digitsOnly(targetPhoneRaw);
    if (want == null || want.length < 7) {
      return false;
    }
    try {
      final Iterable<CallLogEntry> rows = await CallLog.query(
        dateTimeFrom: notBefore,
        dateTimeTo: DateTime.now().add(const Duration(minutes: 1)),
        durationFrom: 1,
      );
      for (final CallLogEntry e in rows) {
        if (!_isOutgoing(e.callType)) {
          continue;
        }
        if (_numbersFuzzyMatch(e.number, want)) {
          return true;
        }
      }
    } catch (e) {
      debugPrint('[DmCallLogVerification] $e');
    }
    return false;
  }

  static bool _isOutgoing(CallType? t) {
    if (t == null) {
      return false;
    }
    return t == CallType.outgoing || t == CallType.wifiOutgoing;
  }

  static String? _digitsOnly(String? s) {
    if (s == null || s.isEmpty) {
      return null;
    }
    final String d = s.replaceAll(RegExp(r'\D'), '');
    if (d.isEmpty) {
      return null;
    }
    return d;
  }

  /// Coincidencia razonable: mismo número, sufijos (10 dígitos) o 52+código+local.
  static bool _numbersFuzzyMatch(String? logNumber, String wantDigits) {
    final String? a0 = _digitsOnly(logNumber);
    if (a0 == null) {
      return false;
    }
    if (a0 == wantDigits) {
      return true;
    }
    if (a0.length >= 7 && wantDigits.length >= 7) {
      final int take = 10;
      final String a = a0.length > take
          ? a0.substring(a0.length - take)
          : a0;
      final String w = wantDigits.length > take
          ? wantDigits.substring(wantDigits.length - take)
          : wantDigits;
      if (a == w) {
        return true;
      }
      if (a.endsWith(w) || w.endsWith(a)) {
        return a.length >= 7 && w.length >= 7;
      }
    }
    return false;
  }
}
