import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixam_mart_delivery/features/order/domain/models/order_model.dart';
import 'package:sixam_mart_delivery/features/order/controllers/order_controller.dart';
import 'package:sixam_mart_delivery/features/splash/controllers/splash_controller.dart';
import 'dart:io';
import 'package:sixam_mart_delivery/util/dimensions.dart';
import 'package:sixam_mart_delivery/util/styles.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_snackbar_widget.dart';
import 'package:sixam_mart_delivery/helper/route_helper.dart';
import 'package:sixam_mart_delivery/util/app_constants.dart';
import 'package:sixam_mart_delivery/features/notification/domain/models/notification_body_model.dart';
import 'package:sixam_mart_delivery/features/chat/domain/models/conversation_model.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:sixam_mart_delivery/helper/dm_call_log_verification_helper.dart';
import 'package:sixam_mart_delivery/helper/dm_contact_timer_helper.dart';
import 'package:sixam_mart_delivery/main.dart' show flutterLocalNotificationsPlugin;
import 'package:sixam_mart_delivery/common/widgets/custom_bottom_sheet_widget.dart';
import 'package:sixam_mart_delivery/features/order/widgets/cancellation_dialogue_widget.dart';
import 'package:sixam_mart_delivery/features/order/widgets/parcel_cancelation/cancellation_reason_bottom_sheet.dart';

/// QA: `true` omite la validación de proximidad (100 m tienda / 500 m cliente).
/// El API `update-order-status` no comprueba distancia; esto es solo cliente.
/// Poner en `false` antes de producción.
const bool kDisableDeliveryProximityCheckForQa = true;

/// Distancia máxima (m) al punto de entrega para iniciar el temporizador de contacto.
const double _kCustomerContactTimerProximityM = 100;

/// Llamadas al cliente (desde el botón de la app) requeridas antes de iniciar el temporizador.
const int _kCustomerContactMinCalls = 3;

/// Duración del temporizador una vez iniciado (después de proximidad + llamadas).
const int _kCustomerContactCountdownSeconds = 600;

class AcceptedOrderWidget extends StatefulWidget {
  final OrderModel orderModel;
  final String phase;
  final Function onHandover;
  final Function onPickedUp;
  final Function onDelivered;
  final String? estimatedArrivalTime;
  const AcceptedOrderWidget({
    super.key,
    required this.orderModel,
    required this.phase,
    required this.onHandover,
    required this.onPickedUp,
    required this.onDelivered,
    this.estimatedArrivalTime,
  });

  @override
  State<AcceptedOrderWidget> createState() => _AcceptedOrderWidgetState();
}

class _AcceptedOrderWidgetState extends State<AcceptedOrderWidget>
    with WidgetsBindingObserver {
  double _sliderValue = 0.0;
  bool _isCheckingProximity = false;

  Timer? _customerProximityPollTimer;
  Timer? _customerContactCountdownTimer;
  bool _within100mOfCustomer = false;
  int _customerTelLaunchCount = 0;
  bool _customerContactCountdownStarted = false;
  int? _customerContactSecondsRemaining;
  bool _awaitingCallReturnConfirm = false;
  /// Marca al abrir [tel:]; en Android se usa con el registro de llamadas.
  DateTime? _customerCallLaunchedAt;
  static const String _prefPrefixCalls = 'dm_cust_confirmed_call_attempts_';
  static const String _prefPrefixEndMs = 'dm_cust_contact_timer_end_ms_';
  static const String _prefPrefixStarted = 'dm_cust_contact_timer_started_';
  static const String _prefPrefixStartMs = 'dm_cust_contact_timer_start_ms_';
  static const String _prefPrefixAttemptsJson = 'dm_cust_call_attempts_json_';

  /// Hora límite del temporizador (misma lógica que en disco).
  int? _countdownDeadlineMs;
  int? _countdownStartMs;

  int? get _oid => widget.orderModel.id;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.phase == 'going_to_customer') {
      unawaited(_restoreContactTimerFromPrefs().then((_) {
        if (widget.phase == 'going_to_customer') {
          _startCustomerContactMonitoring();
        }
      }));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeLocalContactTimersOnly();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      return;
    }
    if (widget.phase != 'going_to_customer') {
      return;
    }
    if (_awaitingCallReturnConfirm) {
      _awaitingCallReturnConfirm = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        unawaited(_processCustomerCallAfterDialer());
      });
    }
    if (_customerContactCountdownStarted) {
      unawaited(_syncCountdownFromStoredDeadline());
    }
  }

  @override
  void didUpdateWidget(AcceptedOrderWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final idChanged = oldWidget.orderModel.id != widget.orderModel.id;
    final wasCustomer = oldWidget.phase == 'going_to_customer';
    final isCustomer = widget.phase == 'going_to_customer';

    if (idChanged || (wasCustomer && !isCustomer)) {
      _stopAndResetCustomerContactTimer();
    }
    if (isCustomer && (!wasCustomer || idChanged)) {
      unawaited(_restoreContactTimerFromPrefs().then((_) {
        if (mounted && widget.phase == 'going_to_customer') {
          _startCustomerContactMonitoring();
        }
      }));
    }
  }

  void _disposeLocalContactTimersOnly() {
    _customerProximityPollTimer?.cancel();
    _customerProximityPollTimer = null;
    _customerContactCountdownTimer?.cancel();
    _customerContactCountdownTimer = null;
  }

  void _stopAndResetCustomerContactTimer() {
    _awaitingCallReturnConfirm = false;
    _customerCallLaunchedAt = null;
    _countdownDeadlineMs = null;
    _countdownStartMs = null;
    unawaited(_clearContactOrderPrefs());
    _customerProximityPollTimer?.cancel();
    _customerProximityPollTimer = null;
    _customerContactCountdownTimer?.cancel();
    _customerContactCountdownTimer = null;
    _within100mOfCustomer = false;
    _customerTelLaunchCount = 0;
    _customerContactCountdownStarted = false;
    _customerContactSecondsRemaining = null;
    _syncCancelContactSnapshotToOrderController();
  }

  void _syncCancelContactSnapshotToOrderController() {
    final int? oid = widget.orderModel.id;
    if (oid == null || !Get.isRegistered<OrderController>()) return;
    Get.find<OrderController>().reportDeliveryCancelContactSnapshot(
      orderId: oid,
      phase: widget.phase,
      customerCallCount: _customerTelLaunchCount,
      within100mOfCustomer: _within100mOfCustomer,
      contactCountdownStarted: _customerContactCountdownStarted,
      contactSecondsRemaining: _customerContactSecondsRemaining,
    );
  }

  Future<void> _restoreContactTimerFromPrefs() async {
    final int? oid = _oid;
    if (oid == null) {
      return;
    }
    final SharedPreferences p = await SharedPreferences.getInstance();
    _customerTelLaunchCount = p.getInt('$_prefPrefixCalls$oid') ?? 0;
    _customerContactCountdownStarted =
        p.getBool('$_prefPrefixStarted$oid') ?? false;
    _countdownStartMs = p.getInt('$_prefPrefixStartMs$oid');
    final int? endMs = p.getInt('$_prefPrefixEndMs$oid');
    if (endMs != null && _customerContactCountdownStarted) {
      _countdownDeadlineMs = endMs;
      final int left = ((endMs - DateTime.now().millisecondsSinceEpoch) / 1000)
          .ceil()
          .clamp(0, _kCustomerContactCountdownSeconds);
      _customerContactSecondsRemaining = left;
      if (left > 0) {
        _customerContactCountdownStarted = true;
        _customerProximityPollTimer?.cancel();
        _customerProximityPollTimer = null;
        _runCountdownTicker();
        await DmContactTimerHelper.scheduleCountdownEndNotification(
          flutterLocalNotificationsPlugin,
          orderId: oid,
          deadlineMs: endMs,
          title: 'dm_contact_timer_notif_title'.tr,
          body: 'dm_contact_timer_notif_body'
              .trParams({'orderId': oid.toString()}),
        );
      } else {
        await DmContactTimerHelper.cancelEndNotification(
          flutterLocalNotificationsPlugin,
          orderId: oid,
        );
      }
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _persistCallCount() async {
    final int? oid = _oid;
    if (oid == null) {
      return;
    }
    final SharedPreferences p = await SharedPreferences.getInstance();
    await p.setInt('$_prefPrefixCalls$oid', _customerTelLaunchCount);
  }

  Future<void> _appendAndPersistCallAttempt(int attempt, int atMs) async {
    final int? oid = _oid;
    if (oid == null) {
      return;
    }
    final SharedPreferences p = await SharedPreferences.getInstance();
    final String key = '$_prefPrefixAttemptsJson$oid';
    final String? raw = p.getString(key);
    List<dynamic> list;
    if (raw != null && raw.isNotEmpty) {
      try {
        list = (jsonDecode(raw) as List<dynamic>?) ?? <dynamic>[];
      } catch (_) {
        list = <dynamic>[];
      }
    } else {
      list = <dynamic>[];
    }
    list.add(<String, int>{'a': attempt, 't': atMs});
    await p.setString(key, jsonEncode(list));
  }

  Future<void> _persistCountdownState(int startMs, int deadlineMs) async {
    final int? oid = _oid;
    if (oid == null) {
      return;
    }
    _countdownDeadlineMs = deadlineMs;
    _countdownStartMs = startMs;
    final SharedPreferences p = await SharedPreferences.getInstance();
    await p.setInt('$_prefPrefixEndMs$oid', deadlineMs);
    await p.setInt('$_prefPrefixStartMs$oid', startMs);
    await p.setBool('$_prefPrefixStarted$oid', true);
    await DmContactTimerHelper.scheduleCountdownEndNotification(
      flutterLocalNotificationsPlugin,
      orderId: oid,
      deadlineMs: deadlineMs,
      title: 'dm_contact_timer_notif_title'.tr,
      body: 'dm_contact_timer_notif_body'
          .trParams({'orderId': oid.toString()}),
    );
  }

  Future<void> _clearContactOrderPrefs() async {
    final int? oid = _oid;
    if (oid == null) {
      return;
    }
    await DmContactTimerHelper.cancelEndNotification(
      flutterLocalNotificationsPlugin,
      orderId: oid,
    );
    final SharedPreferences p = await SharedPreferences.getInstance();
    await p.remove('$_prefPrefixCalls$oid');
    await p.remove('$_prefPrefixEndMs$oid');
    await p.remove('$_prefPrefixStarted$oid');
    await p.remove('$_prefPrefixStartMs$oid');
    await p.remove('$_prefPrefixAttemptsJson$oid');
  }

  Future<void> _syncCountdownFromStoredDeadline() async {
    final int? d = _countdownDeadlineMs;
    if (d == null) {
      await _restoreContactTimerFromPrefs();
    }
    int? end = _countdownDeadlineMs;
    if (end == null) {
      final int? oid = _oid;
      if (oid == null) {
        return;
      }
      final SharedPreferences p = await SharedPreferences.getInstance();
      end = p.getInt('$_prefPrefixEndMs$oid');
      _countdownDeadlineMs = end;
      _countdownStartMs = p.getInt('$_prefPrefixStartMs$oid');
    }
    if (end == null) {
      return;
    }
    if (!mounted) {
      return;
    }
    final int left = ((end - DateTime.now().millisecondsSinceEpoch) / 1000)
        .ceil()
        .clamp(0, _kCustomerContactCountdownSeconds);
    setState(() => _customerContactSecondsRemaining = left);
    _syncCancelContactSnapshotToOrderController();
    if (left > 0) {
      _runCountdownTicker();
    }
  }

  /// Tras [tel:]: en Android, permiso de registro + comprobación; si no, o no coincide, diálogo.
  Future<void> _processCustomerCallAfterDialer() async {
    if (!mounted || widget.phase != 'going_to_customer') {
      return;
    }
    final String? target =
        widget.orderModel.deliveryAddress?.contactPersonNumber ??
            widget.orderModel.customer?.phone;

    if (DmCallLogVerificationHelper.isAndroid) {
      final bool granted = await DmCallLogVerificationHelper.ensureCallLogAccess();
      if (!granted) {
        _showCustomerCallConfirmDialog(
          hint: 'dm_customer_call_log_needs_phone_permission'.tr,
        );
        return;
      }
      final DateTime notBefore = (_customerCallLaunchedAt ?? DateTime.now())
          .subtract(const Duration(minutes: 1));
      final bool found = await DmCallLogVerificationHelper
          .hasRecentOutgoingCallTo(
        targetPhoneRaw: target,
        notBefore: notBefore,
      );
      if (found && mounted && widget.phase == 'going_to_customer') {
        showCustomSnackBar('dm_customer_call_log_detected'.tr, isError: false);
        await _applyCustomerCallAttemptConfirmed();
        return;
      }
      _showCustomerCallConfirmDialog(
        hint: 'dm_customer_call_log_not_matched'.tr,
      );
      return;
    }
    _showCustomerCallConfirmDialog();
  }

  Future<void> _applyCustomerCallAttemptConfirmed() async {
    if (!mounted || widget.phase != 'going_to_customer') {
      return;
    }
    int nextAttempt = 0;
    setState(() {
      if (_customerTelLaunchCount < 999) {
        _customerTelLaunchCount++;
      }
      nextAttempt = _customerTelLaunchCount;
    });
    final int at = DateTime.now().millisecondsSinceEpoch;
    await _persistCallCount();
    if (nextAttempt > 0 && nextAttempt <= 3) {
      await _appendAndPersistCallAttempt(nextAttempt, at);
      if (Get.isRegistered<OrderController>() && widget.orderModel.id != null) {
        Get.find<OrderController>().logCustomerCallAttemptToServer(
          widget.orderModel.id!,
          nextAttempt,
          at,
        );
      }
    }
    await _tryStartCustomerContactCountdown();
    _syncCancelContactSnapshotToOrderController();
  }

  void _showCustomerCallConfirmDialog({String? hint}) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text('dm_customer_call_confirm_title'.tr),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('dm_customer_call_confirm_body'.tr),
                if (hint != null && hint.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    hint,
                    style: robotoRegular.copyWith(
                      fontSize: 12,
                      color: Theme.of(ctx).hintColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _awaitingCallReturnConfirm = false;
              },
              child: Text('no'.tr),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                if (mounted && widget.phase == 'going_to_customer') {
                  await _applyCustomerCallAttemptConfirmed();
                }
                _awaitingCallReturnConfirm = false;
              },
              child: Text('yes'.tr),
            ),
          ],
        );
      },
    );
  }

  void _startCustomerContactMonitoring() {
    if (widget.phase != 'going_to_customer') return;
    _customerProximityPollTimer?.cancel();
    _customerProximityPollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _pollCustomerProximityForContactTimer(),
    );
    unawaited(_pollCustomerProximityForContactTimer());
    _syncCancelContactSnapshotToOrderController();
  }

  Future<void> _pollCustomerProximityForContactTimer() async {
    if (!mounted || widget.phase != 'going_to_customer') return;

    if (kDisableDeliveryProximityCheckForQa) {
      if (!_within100mOfCustomer) {
        setState(() => _within100mOfCustomer = true);
      }
      unawaited(_tryStartCustomerContactCountdown());
      _syncCancelContactSnapshotToOrderController();
      return;
    }

    final double lat =
        double.tryParse(widget.orderModel.deliveryAddress?.latitude ?? '') ??
            0;
    final double lng =
        double.tryParse(widget.orderModel.deliveryAddress?.longitude ?? '') ??
            0;
    if (lat == 0 && lng == 0) return;

    try {
      final Position p = await Geolocator.getCurrentPosition();
      final double d = Geolocator.distanceBetween(
        p.latitude,
        p.longitude,
        lat,
        lng,
      );
      final bool within = d <= _kCustomerContactTimerProximityM;
      if (within != _within100mOfCustomer) {
        setState(() => _within100mOfCustomer = within);
      }
      unawaited(_tryStartCustomerContactCountdown());
    } catch (_) {}
    _syncCancelContactSnapshotToOrderController();
  }

  Future<void> _tryStartCustomerContactCountdown() async {
    if (!mounted ||
        _customerContactCountdownStarted ||
        widget.phase != 'going_to_customer') {
      return;
    }
    if (!_within100mOfCustomer || _customerTelLaunchCount < _kCustomerContactMinCalls) {
      return;
    }
    _customerContactCountdownStarted = true;
    _customerProximityPollTimer?.cancel();
    _customerProximityPollTimer = null;
    final int startMs = DateTime.now().millisecondsSinceEpoch;
    final int deadline = startMs + const Duration(
      seconds: _kCustomerContactCountdownSeconds,
    ).inMilliseconds;
    await _persistCountdownState(startMs, deadline);
    if (!mounted) {
      return;
    }
    setState(() {
      _customerContactSecondsRemaining = _kCustomerContactCountdownSeconds;
    });
    _runCountdownTicker();
    _syncCancelContactSnapshotToOrderController();
  }

  void _runCountdownTicker() {
    _customerContactCountdownTimer?.cancel();
    _customerContactCountdownTimer =
        Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final int? end = _countdownDeadlineMs;
      if (end == null) {
        t.cancel();
        return;
      }
      final int next = ((end - DateTime.now().millisecondsSinceEpoch) / 1000)
          .ceil()
          .clamp(0, _kCustomerContactCountdownSeconds);
      setState(() => _customerContactSecondsRemaining = next);
      _syncCancelContactSnapshotToOrderController();
      if (next <= 0) {
        t.cancel();
      }
    });
  }

  String _formatMmSs(int seconds) {
    final int m = seconds ~/ 60;
    final int s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatHhMmLocal(int startMs) {
    return DateFormat('HH:mm', 'es_MX')
        .format(DateTime.fromMillisecondsSinceEpoch(startMs));
  }

  Widget _buildCustomerContactTimerCard(BuildContext context) {
    final int calls = _customerTelLaunchCount.clamp(0, 999);
    final bool callsOk = calls >= _kCustomerContactMinCalls;
    final bool locOk = _within100mOfCustomer;
    final int? sec = _customerContactSecondsRemaining;
    final bool finished = sec != null && sec <= 0 && _customerContactCountdownStarted;

    return Container(
      margin: const EdgeInsets.only(top: Dimensions.paddingSizeDefault),
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        border: Border.all(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.contact_phone_outlined, color: Theme.of(context).primaryColor, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'dm_customer_contact_timer_title'.tr,
                  style: robotoMedium.copyWith(fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _timerRequirementRow(
            context,
            done: callsOk,
            label:
                '${'dm_customer_contact_calls_label_confirmed'.tr} $calls / $_kCustomerContactMinCalls',
          ),
          const SizedBox(height: 6),
          _timerRequirementRow(
            context,
            done: locOk,
            label: locOk
                ? 'dm_customer_contact_within_100'.tr
                : 'dm_customer_contact_not_within_100'.tr,
          ),
          const SizedBox(height: 12),
          if (!_customerContactCountdownStarted)
            Text(
              'dm_customer_contact_timer_waiting'.tr,
              style: robotoRegular.copyWith(
                fontSize: 12,
                color: Theme.of(context).hintColor,
              ),
            )
          else if (finished)
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade700, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'dm_customer_contact_timer_done'.tr,
                    style: robotoMedium.copyWith(
                      fontSize: 13,
                      color: Colors.green.shade800,
                    ),
                  ),
                ),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'dm_customer_contact_timer_running'.tr,
                  style: robotoRegular.copyWith(fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatMmSs(sec ?? 0),
                  style: robotoBold.copyWith(
                    fontSize: 28,
                    color: Theme.of(context).primaryColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (_countdownStartMs != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'dm_customer_contact_timer_start_at'.trParams({
                      'time': _formatHhMmLocal(_countdownStartMs!),
                    }),
                    style: robotoRegular.copyWith(
                      fontSize: 11,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _timerRequirementRow(
    BuildContext context, {
    required bool done,
    required String label,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          done ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 18,
          color: done ? Colors.green.shade700 : Theme.of(context).hintColor,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: robotoRegular.copyWith(fontSize: 12))),
      ],
    );
  }

  void _showNavigationOptions() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Selecciona tu app de navegación',
              style: robotoBold.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavOption(
                  'Google Maps',
                  Icons.map,
                  Colors.green,
                  () => _launchNavigation('google'),
                ),
                _buildNavOption(
                  'Waze',
                  Icons.navigation,
                  Colors.blue,
                  () => _launchNavigation('waze'),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildNavOption(
    String name,
    IconData icon,
    Color color,
    Function onTap,
  ) {
    return InkWell(
      onTap: () {
        Get.back();
        onTap();
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: 8),
          Text(name, style: robotoMedium),
        ],
      ),
    );
  }

  void _launchNavigation(String app) async {
    String lat = '';
    String lng = '';

    if (widget.phase == 'going_to_store') {
      lat = widget.orderModel.storeLat ?? '0';
      lng = widget.orderModel.storeLng ?? '0';
    } else {
      lat = widget.orderModel.deliveryAddress?.latitude ?? '0';
      lng = widget.orderModel.deliveryAddress?.longitude ?? '0';
    }

    String url = '';
    if (app == 'google') {
      url =
          'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&mode=d';
    } else {
      url = 'https://waze.com/ul?ll=$lat,$lng&navigate=yes';
    }

    if (await canLaunchUrlString(url)) {
      await launchUrlString(url, mode: LaunchMode.externalApplication);
    } else {
      showCustomSnackBar('Could not launch navigation app');
    }
  }

  void _callStore() async {
    String? phone = widget.orderModel.storePhone;
    if (phone != null && phone.isNotEmpty) {
      if (await canLaunchUrlString('tel:$phone')) {
        await launchUrlString(
          'tel:$phone',
          mode: LaunchMode.externalApplication,
        );
      } else {
        showCustomSnackBar('Could not launch dialer');
      }
    } else {
      showCustomSnackBar('Phone number not found');
    }
  }

  void _callCustomer() async {
    String? phone = widget.orderModel.deliveryAddress?.contactPersonNumber ?? widget.orderModel.customer?.phone;
    if (phone != null && phone.isNotEmpty) {
      if (await canLaunchUrlString('tel:$phone')) {
        if (mounted && widget.phase == 'going_to_customer') {
          _awaitingCallReturnConfirm = true;
          _customerCallLaunchedAt = DateTime.now();
        }
        await launchUrlString(
          'tel:$phone',
          mode: LaunchMode.externalApplication,
        );
        if (mounted && widget.phase == 'going_to_customer') {
          _syncCancelContactSnapshotToOrderController();
        }
      } else {
        showCustomSnackBar('Could not launch dialer');
        _awaitingCallReturnConfirm = false;
      }
    } else {
      showCustomSnackBar('Phone number not found');
    }
  }

  void _chatWithStore() {
    Get.toNamed(
      RouteHelper.getChatRoute(
        notificationBody: NotificationBodyModel(
          orderId: widget.orderModel.id,
          vendorId: widget.orderModel.storeId,
        ),
        user: User(
          id: widget.orderModel.storeId,
          fName: widget.orderModel.storeName,
          imageFullUrl: widget.orderModel.storeLogoFullUrl,
          phone: widget.orderModel.storePhone,
        ),
      ),
    );
  }

  void _chatWithCustomer() {
    final int? oid = widget.orderModel.id;
    final bool useTootliDirectChat =
        oid != null &&
        (widget.orderModel.tootliDirectTrackable == true ||
            widget.orderModel.hasTootliDirectPublicTrackingUrl);
    if (useTootliDirectChat) {
      Get.toNamed(RouteHelper.getTootliDirectTrackingChatRoute(oid));
      return;
    }
    if (widget.orderModel.customer != null) {
      Get.toNamed(
        RouteHelper.getChatRoute(
          notificationBody: NotificationBodyModel(
            orderId: widget.orderModel.id,
            customerId: widget.orderModel.customer!.id,
          ),
          user: User(
            id: widget.orderModel.customer!.id,
            fName: widget.orderModel.customer!.fName,
            lName: widget.orderModel.customer!.lName,
            imageFullUrl: widget.orderModel.customer!.imageFullUrl,
            phone: widget.orderModel.customer!.phone,
          ),
        ),
      );
      return;
    }
    if (widget.orderModel.isGuest == true) {
      showCustomSnackBar(
        'tootli_direct_guest_chat_web_only'.tr,
        isError: false,
      );
      return;
    }
    final int? fallbackCustomerId =
        widget.orderModel.userId ?? widget.orderModel.deliveryAddress?.userId;
    if (fallbackCustomerId != null) {
      final addr = widget.orderModel.deliveryAddress;
      final String rawName = (addr?.contactPersonName ?? '').trim();
      String fName = 'Cliente';
      String lName = '';
      if (rawName.isNotEmpty) {
        final List<String> parts = rawName.split(RegExp(r'\s+'));
        fName = parts.first;
        if (parts.length > 1) {
          lName = parts.sublist(1).join(' ');
        }
      }
      Get.toNamed(
        RouteHelper.getChatRoute(
          notificationBody: NotificationBodyModel(
            orderId: widget.orderModel.id,
            customerId: fallbackCustomerId,
          ),
          user: User(
            id: fallbackCustomerId,
            fName: fName,
            lName: lName,
            imageFullUrl: '',
            phone: addr?.contactPersonNumber,
          ),
        ),
      );
      return;
    }
    showCustomSnackBar('customer_not_found'.tr, isError: true);
  }

  bool _parcelIsBeforePickup() {
    final String? s = widget.orderModel.orderStatus;
    return s == AppConstants.processing ||
        s == AppConstants.accepted ||
        s == AppConstants.confirmed ||
        s == AppConstants.handover;
  }

  void _showSupportBottomSheet() {
    final OrderController orderController = Get.find<OrderController>();
    final int? oid = widget.orderModel.id;
    if (oid == null) {
      return;
    }
    final bool isParcel = widget.orderModel.orderType == 'parcel';
    final double bottomPad = MediaQuery.of(context).viewPadding.bottom;
    
    final bool isTimerFinished = widget.phase == 'going_to_customer' &&
        _customerContactSecondsRemaining != null &&
        _customerContactSecondsRemaining! <= 0 &&
        _customerContactCountdownStarted;

    Get.bottomSheet(
      Container(
        width: double.infinity,
        padding: EdgeInsets.only(
          left: Dimensions.paddingSizeLarge,
          right: Dimensions.paddingSizeLarge,
          top: Dimensions.paddingSizeLarge,
          bottom: bottomPad + Dimensions.paddingSizeDefault,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            Container(
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).disabledColor.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 15),
            Text('Opciones de Soporte y Cancelación', style: robotoBold.copyWith(fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              'Selecciona la opción que mejor describa tu problema.',
              textAlign: TextAlign.center,
              style: robotoRegular.copyWith(
                fontSize: 12,
                color: Theme.of(context).hintColor,
              ),
            ),
            const SizedBox(height: 20),
            _buildSupportOption(
              'Cliente no responde (Enviar evidencia)',
              'Envía el contador de 10 min a Soporte para cancelar sin penalización.',
              Icons.support_agent,
              Colors.blue,
              () {
                if (isParcel) {
                  showCustomBottomSheet(
                    child: CancellationReasonBottomSheet(
                      isBeforePickup: _parcelIsBeforePickup(),
                      orderId: oid,
                    ),
                  );
                } else {
                  Get.dialog(
                    CancellationDialogueWidget(orderId: oid),
                  );
                }
              },
              isEnabled: isTimerFinished,
            ),
            const SizedBox(height: 12),
            _buildSupportOption(
              'Emergencia / Vehículo descompuesto',
              'Sube una foto de evidencia si tuviste un problema logístico.',
              Icons.cancel_outlined,
              Colors.orange.shade800,
              () {
                orderController.openAdminSupportChatForCancelRequest(
                  orderId: oid,
                  order: widget.orderModel,
                  cancellationReason: 'Accidente o emergencia (repartidor)',
                );
              },
            ),
            const SizedBox(height: 12),
            _buildSupportOption(
              'Chat General con Soporte',
              'Comunícate con soporte para cualquier otra duda.',
              Icons.chat_bubble_outline,
              Colors.teal,
              () {
                Get.toNamed(
                  RouteHelper.getChatRoute(
                    notificationBody: NotificationBodyModel(
                      type: AppConstants.admin,
                      orderId: widget.orderModel.id,
                    ),
                    user: User(
                      id: 0,
                      fName: 'Soporte',
                      lName: 'Tootli',
                      imageFullUrl: '',
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildSupportOption(
              'Emergencia (911)',
              'Llamar al 911 en caso de accidente o asalto.',
              Icons.emergency_share,
              Colors.red,
              () => launchUrlString(
                'tel:911',
                mode: LaunchMode.externalApplication,
              ),
            ),
            const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildSupportOption(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    Function onTap, {
    bool isEnabled = true,
  }) {
    return InkWell(
      onTap: isEnabled ? () {
        Get.back();
        onTap();
      } : () {
        showCustomSnackBar('Esta opción se habilitará cuando termines de esperar al cliente (10 min).', isError: true);
      },
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isEnabled ? color.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
          borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
          border: Border.all(color: isEnabled ? color.withOpacity(0.2) : Colors.grey.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isEnabled ? color.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isEnabled ? color : Colors.grey, size: 24),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: robotoBold.copyWith(fontSize: 16, color: isEnabled ? color : Colors.grey),
                  ),
                  Text(
                    subtitle,
                    style: robotoRegular.copyWith(
                      fontSize: 12,
                      color: Theme.of(context).disabledColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: isEnabled ? Theme.of(context).disabledColor : Colors.grey.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 5,
          ),
        ],
      ),
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          // Order ID and Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pedido #${widget.orderModel.id}',
                      style: robotoBold.copyWith(fontSize: 24),
                    ),
                    Text(
                      widget.phase == 'going_to_store'
                          ? 'En camino al restaurante'
                          : widget.phase == 'at_store'
                              ? 'Preparando entrega'
                              : 'En camino al cliente',
                      style: robotoRegular.copyWith(
                        color: Theme.of(context).primaryColor,
                        fontSize: 14,
                      ),
                    ),
                    if (widget.estimatedArrivalTime != null)
                      Text(
                        'Llega antes de ${widget.estimatedArrivalTime}',
                        style: robotoMedium.copyWith(
                          color: Colors.orange,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  (widget.phase == 'going_to_store' || widget.phase == 'at_store')
                      ? Icons.restaurant
                      : Icons.person_pin_circle,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _showSupportBottomSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    'SOS',
                    style: robotoBold.copyWith(
                      color: Colors.white,
                      fontSize: 11,
                      height: 1,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          if (widget.phase == 'going_to_store' || widget.phase == 'at_store')
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
              decoration: BoxDecoration(
                color: Theme.of(context).secondaryHeaderColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.orderModel.storeName ?? '',
                          style: robotoMedium.copyWith(fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          widget.orderModel.storeAddress ?? '',
                          style: robotoRegular.copyWith(
                            fontSize: 12,
                            color: Theme.of(context).disabledColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _showNavigationOptions,
                    icon: const Icon(Icons.navigation, color: Colors.blue),
                  ),
                  IconButton(
                    onPressed: _chatWithStore,
                    icon: const Icon(Icons.message, color: Colors.orange),
                  ),
                  IconButton(
                    onPressed: _callStore,
                    icon: const Icon(Icons.call, color: Colors.green),
                  ),
                ],
              ),
            ),

          // Customer Info Card (Always Visible)
          Container(
            padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 5,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.orderModel.customer?.fName ?? ''} ${widget.orderModel.customer?.lName ?? ''}',
                        style: robotoBold.copyWith(
                          fontSize: 18,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        widget.orderModel.deliveryAddress?.address ?? 'Dirección de entrega',
                        style: robotoMedium.copyWith(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (widget.phase != 'going_to_store' && widget.phase != 'at_store')
                  IconButton(
                    onPressed: _showNavigationOptions,
                    icon: const Icon(Icons.navigation, color: Colors.white),
                  ),
                IconButton(
                  onPressed: _chatWithCustomer,
                  icon: const Icon(Icons.message, color: Colors.white),
                ),
                IconButton(
                  onPressed: _callCustomer,
                  icon: const Icon(Icons.call, color: Colors.white),
                ),
              ],
            ),
          ),

          if (widget.phase == 'going_to_store' || widget.phase == 'at_store')
            GetBuilder<OrderController>(
              builder: (orderController) {
                return orderController.orderDetailsModel != null &&
                        orderController.orderDetailsModel!.isNotEmpty
                    ? Container(
                        margin: const EdgeInsets.only(top: 15),
                        padding: const EdgeInsets.all(
                          Dimensions.paddingSizeSmall,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).primaryColor.withOpacity(0.2),
                          ),
                          borderRadius: BorderRadius.circular(
                            Dimensions.radiusDefault,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Productos a recoger:',
                              style: robotoMedium.copyWith(
                                fontSize: 12,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                            const SizedBox(height: 5),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount:
                                  orderController.orderDetailsModel!.length,
                              itemBuilder: (context, index) {
                                var detail =
                                    orderController.orderDetailsModel![index];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2,
                                  ),
                                  child: Text(
                                    '${detail.quantity} x ${detail.itemDetails?.name ?? 'Producto'}',
                                    style: robotoRegular.copyWith(fontSize: 13),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      )
                    : const SizedBox(
                        height: 40,
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
              },
            ),

          if (widget.phase == 'going_to_customer')
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildCustomerContactTimerCard(context),
                GetBuilder<OrderController>(
                  builder: (orderController) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        Text(
                          'Prueba de entrega (Foto):',
                          style: robotoMedium.copyWith(fontSize: 14),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                        InkWell(
                          onTap: () => orderController.pickCameraDirectly(),
                          child: Container(
                            height: 60,
                            width: 60,
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(
                                Dimensions.radiusDefault,
                              ),
                              border: Border.all(
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                            child: Icon(
                              Icons.camera_alt,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 60,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount:
                                  orderController.pickedPrescriptions.length,
                              itemBuilder: (context, index) {
                                return Stack(
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.only(right: 10),
                                      height: 60,
                                      width: 60,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(
                                          Dimensions.radiusDefault,
                                        ),
                                        image: DecorationImage(
                                          image: FileImage(
                                            File(
                                              orderController
                                                  .pickedPrescriptions[index]
                                                  .path,
                                            ),
                                          ),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 0,
                                      right: 10,
                                      child: InkWell(
                                        onTap: () => orderController
                                            .pickPrescriptionImage(
                                              isRemove: true,
                                              isCamera:
                                                  false, // Not used when isRemove is true
                                            ),
                                        child: Container(
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (Get.find<SplashController>()
                            .configModel
                            ?.orderDeliveryVerification ??
                        false)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          Text(
                            'Código de verificación (OTP):',
                            style: robotoMedium.copyWith(fontSize: 14),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            onChanged: (value) => orderController.setOtp(value),
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: 'Ingrese el código del cliente',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  Dimensions.radiusDefault,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                      ],
                    );
                  },
                ),
              ],
            ),

          const SizedBox(height: 30),

          // Action Slider
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 60,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Center(
                  child: Text(
                    widget.phase == 'going_to_store'
                        ? 'Pedido recogido'.tr
                        : widget.phase == 'at_store'
                            ? 'on_the_way'.tr
                            : 'Entregar pedido'.tr,
                    style: robotoBold.copyWith(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 60,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 30,
                    ),
                    overlayShape: SliderComponentShape.noOverlay,
                    activeTrackColor: Colors.transparent,
                    inactiveTrackColor: Colors.transparent,
                    thumbColor: Colors.white.withOpacity(0.2),
                  ),
                  child: Slider(
                    value: _sliderValue,
                    onChanged: (value) {
                      setState(() {
                        _sliderValue = value;
                      });
                      if (value > 0.9) {
                        if (widget.phase == 'going_to_store') {
                          _checkProximityAndProceed(
                            targetLat: double.tryParse(widget.orderModel.storeLat ?? '') ?? 0,
                            targetLng: double.tryParse(widget.orderModel.storeLng ?? '') ?? 0,
                            maxDistance: 100,
                            onSuccess: () => widget.onHandover(),
                            errorMessage: 'Debes estar a menos de 100m del restaurante para recoger el pedido.',
                          );
                        } else if (widget.phase == 'at_store') {
                          widget.onPickedUp();
                        } else {
                          _checkProximityAndProceed(
                            targetLat: double.tryParse(widget.orderModel.deliveryAddress?.latitude ?? '') ?? 0,
                            targetLng: double.tryParse(widget.orderModel.deliveryAddress?.longitude ?? '') ?? 0,
                            maxDistance: 500,
                            onSuccess: () => widget.onDelivered(),
                            errorMessage: 'Debes estar a menos de 500m del cliente para entregar el pedido.',
                          );
                        }
                        setState(() {
                          _sliderValue = 0.0;
                        });
                      }
                    },
                    onChangeEnd: (value) {
                      if (value <= 0.9) {
                        setState(() {
                          _sliderValue = 0.0;
                        });
                      }
                    },
                  ),
                ),
              ),
              Positioned(
                left:
                    10 +
                    (_sliderValue * (MediaQuery.of(context).size.width - 100)),
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
      ),
    );
  }
  Future<void> _checkProximityAndProceed({
    required double targetLat,
    required double targetLng,
    required double maxDistance,
    required Function() onSuccess,
    required String errorMessage,
  }) async {
    if (_isCheckingProximity) return;
    _isCheckingProximity = true;

    try {
      if (kDisableDeliveryProximityCheckForQa) {
        onSuccess();
        return;
      }

      Position currentPosition = await Geolocator.getCurrentPosition();

      if (targetLat == 0 || targetLng == 0) {
        onSuccess();
        return;
      }

      double distance = Geolocator.distanceBetween(
        currentPosition.latitude,
        currentPosition.longitude,
        targetLat,
        targetLng,
      );

      if (distance <= maxDistance) {
        onSuccess();
      } else {
        showCustomSnackBar(
          '$errorMessage Estás a ${distance.toInt()}m.',
          isError: true,
        );
      }
    } catch (e) {
      onSuccess();
    } finally {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _isCheckingProximity = false;
          });
        }
      });
    }
  }
}
