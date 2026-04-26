import 'dart:async' show unawaited;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:sixam_mart_delivery/common/models/response_model.dart';
import 'package:sixam_mart_delivery/features/order/domain/models/order_count_model.dart';
import 'package:sixam_mart_delivery/features/order/domain/models/parcel_cancellation_reasons_model.dart';
import 'package:sixam_mart_delivery/features/profile/controllers/profile_controller.dart';
import 'package:sixam_mart_delivery/features/splash/controllers/splash_controller.dart';
import 'package:sixam_mart_delivery/api/api_client.dart';
import 'package:sixam_mart_delivery/features/order/domain/models/order_details_model.dart';
import 'package:sixam_mart_delivery/features/order/domain/models/order_model.dart';
import 'package:sixam_mart_delivery/features/order/domain/models/update_status_body_model.dart';
import 'package:sixam_mart_delivery/features/order/domain/models/ignore_model.dart';
import 'package:sixam_mart_delivery/features/order/domain/models/order_cancellation_body.dart';
import 'package:sixam_mart_delivery/features/chat/domain/models/conversation_model.dart';
import 'package:sixam_mart_delivery/features/notification/domain/models/notification_body_model.dart';
import 'package:sixam_mart_delivery/helper/route_helper.dart';
import 'package:sixam_mart_delivery/util/app_constants.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_snackbar_widget.dart';
import 'package:get/get.dart';
import 'package:sixam_mart_delivery/features/order/domain/services/order_service_interface.dart';

class OrderController extends GetxController implements GetxService {
  final OrderServiceInterface orderServiceInterface;
  OrderController({required this.orderServiceInterface});

  List<OrderModel>? _currentOrderList;
  List<OrderModel>? get currentOrderList => _currentOrderList;

  List<OrderModel>? _completedOrderList;
  List<OrderModel>? get completedOrderList => _completedOrderList;

  List<OrderModel>? _latestOrderList;
  List<OrderModel>? get latestOrderList => _latestOrderList;

  List<OrderDetailsModel>? _orderDetailsModel;
  List<OrderDetailsModel>? get orderDetailsModel => _orderDetailsModel;

  List<IgnoreModel> _ignoredRequests = [];
  List<IgnoreModel> get ignoredRequests => _ignoredRequests;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String _otp = '';
  String get otp => _otp;

  bool _paginate = false;
  bool get paginate => _paginate;

  int? _pageSize;
  int? get pageSize => _pageSize;

  List<int> _offsetList = [];
  List<int> get offsetList => _offsetList;

  int _offset = 1;
  int get offset => _offset;

  OrderModel? _orderModel;
  OrderModel? get orderModel => _orderModel;

  String? _cancelReason = '';
  String? get cancelReason => _cancelReason;

  int? _selectedCancelReasonId;
  int? get selectedCancelReasonId => _selectedCancelReasonId;

  final List<XFile> _pickedCancelEvidence = [];
  List<XFile> get pickedCancelEvidence =>
      List<XFile>.unmodifiable(_pickedCancelEvidence);

  XFile? _cancelAudio;
  XFile? get cancelAudioFile => _cancelAudio;

  static const int maxCancelEvidencePhotos = 3;

  List<CancellationData>? _orderCancelReasons;
  List<CancellationData>? get orderCancelReasons => _orderCancelReasons;

  bool _showDeliveryImageField = false;
  bool get showDeliveryImageField => _showDeliveryImageField;

  List<XFile> _pickedPrescriptions = [];
  List<XFile> get pickedPrescriptions => _pickedPrescriptions;

  List<Reason>? _parcelCancellationReasons;
  List<Reason>? get parcelCancellationReasons => _parcelCancellationReasons;

  final List<String> _selectedParcelCancelReason = [];
  List<String>? get selectedParcelCancelReason => _selectedParcelCancelReason;

  DateTime? _selectedDate;
  DateTime? get selectedDate => _selectedDate;

  int _selectedHour = 11;
  int get selectedHour => _selectedHour;

  int _selectedMinute = 59;
  int get selectedMinute => _selectedMinute;

  String _selectedPeriod = 'PM';
  String get selectedPeriod => _selectedPeriod;

  final List<DateTime> _availableDates = [];
  List<DateTime> get availableDates => _availableDates;

  List<OrderCountModel>? _currentOrderCountList;
  List<OrderCountModel>? get currentOrderCountList => _currentOrderCountList;

  List<OrderCountModel>? _historyOrderCountList;
  List<OrderCountModel>? get historyOrderCountList => _historyOrderCountList;

  String _selectedHistoryStatus = 'all';
  String get selectedHistoryStatus => _selectedHistoryStatus;

  String _selectedRunningStatus = 'all';
  String get selectedRunningStatus => _selectedRunningStatus;

  String _orderType = 'current';
  String get orderType => _orderType;

  void changeDeliveryImageStatus({bool isUpdate = true}) {
    _showDeliveryImageField = !_showDeliveryImageField;
    if (isUpdate) {
      update();
    }
  }

  void pickPrescriptionImage({
    required bool isRemove,
    required bool isCamera,
  }) async {
    if (isRemove) {
      _pickedPrescriptions = [];
    } else {
      XFile? xFile = await ImagePicker().pickImage(
        source: isCamera ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 50,
      );
      if (xFile != null) {
        _pickedPrescriptions.add(xFile);
        if (Get.isDialogOpen!) {
          Get.back();
        }
      }
      update();
    }
  }

  /// Abre la cámara directamente para tomar la foto de prueba de entrega.
  /// Evita cualquier selector de galería/cámara.
  Future<void> pickCameraDirectly() async {
    final ImagePicker picker = ImagePicker();
    final XFile? xFile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 50,
    );
    if (xFile != null) {
      _pickedPrescriptions.add(xFile);
      update();
    }
  }

  void initLoading() {
    _isLoading = false;
    update();
  }

  void resetDmCancellationSheet() {
    _selectedCancelReasonId = null;
    _cancelReason = '';
    _pickedCancelEvidence.clear();
    _cancelAudio = null;
    update();
  }

  void setSelectedCancelReason(int? id, String? reasonLabel) {
    _selectedCancelReasonId = id;
    _cancelReason = reasonLabel ?? '';
    update();
  }

  void pickCancelEvidenceImage({required bool isCamera}) async {
    if (_pickedCancelEvidence.length >= maxCancelEvidencePhotos) {
      showCustomSnackBar('dm_cancel_evidence_max_photos'.tr, isError: true);
      return;
    }
    final XFile? xFile = await ImagePicker().pickImage(
      source: isCamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 70,
    );
    if (xFile != null) {
      _pickedCancelEvidence.add(xFile);
      update();
    }
  }

  void removeCancelEvidenceAt(int index) {
    if (index >= 0 && index < _pickedCancelEvidence.length) {
      _pickedCancelEvidence.removeAt(index);
      update();
    }
  }

  Future<void> pickCancelAudio() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );
    if (result != null && result.files.single.path != null) {
      _cancelAudio = XFile(result.files.single.path!);
      update();
    }
  }

  void clearCancelAudio() {
    _cancelAudio = null;
    update();
  }

  Future<void> getOrderCancelReasons() async {
    resetDmCancellationSheet();
    _orderCancelReasons = null;
    update();
    final List<CancellationData>? orderCancelReasons =
        await orderServiceInterface.getCancelReasons();
    _orderCancelReasons = [];
    if (orderCancelReasons != null) {
      _orderCancelReasons!.addAll(orderCancelReasons);
    }
    update();
  }

  Future<void> getOrderWithId(int? orderId) async {
    _orderModel = null;
    Response response = await orderServiceInterface.getOrderWithId(orderId);
    if (response.statusCode == 200) {
      _orderModel = OrderModel.fromJson(response.body);

      debugPrint(_orderModel.toString());
    } else {
      Navigator.pop(Get.context!);
      await Get.find<OrderController>().getRunningOrders(offset);
    }
    update();
  }

  /// Versión segura de getOrderWithId sin efectos secundarios.
  /// Úsala cuando sólo necesites obtener el modelo para mostrarlo (p.ej. notificaciones).
  Future<OrderModel?> fetchOrderForNotification(int orderId) async {
    Response response = await orderServiceInterface.getOrderWithId(orderId);
    if (response.statusCode == 200) {
      return OrderModel.fromJson(response.body);
    }
    return null;
  }

  Future<void> getCompletedOrders(
    int offset, {
    bool willUpdate = true,
    String? status,
  }) async {
    String orderStatus = status ?? _selectedHistoryStatus;

    if (offset == 1) {
      _offsetList = [];
      _offset = 1;
      _completedOrderList = null;
      if (willUpdate) {
        update();
      }
    }
    if (!_offsetList.contains(offset)) {
      _offsetList.add(offset);
      PaginatedOrderModel? paginatedOrderModel = await orderServiceInterface
          .getCompletedOrderList(offset, orderStatus: orderStatus);
      if (paginatedOrderModel != null) {
        if (offset == 1) {
          _completedOrderList = [];
        }
        _completedOrderList!.addAll(paginatedOrderModel.orders!);
        _pageSize = paginatedOrderModel.totalSize;
        _paginate = false;
        update();
      }
    } else {
      if (_paginate) {
        _paginate = false;
        update();
      }
    }
  }

  void showBottomLoader() {
    _paginate = true;
    update();
  }

  void setOffset(int offset) {
    _offset = offset;
  }

  Future<void> getRunningOrders(
    int offset, {
    bool willUpdate = true,
    String? status,
  }) async {
    String orderStatus = status ?? _selectedRunningStatus;
    if (status != null) {
      _selectedRunningStatus = status;
    }

    if (offset == 1) {
      _offsetList = [];
      _offset = 1;
      _completedOrderList = null;
      if (willUpdate) {
        update();
      }
    }
    if (!_offsetList.contains(offset)) {
      _offsetList.add(offset);
      PaginatedOrderModel? paginatedOrderModel = await orderServiceInterface
          .getCurrentOrders(offset, orderStatus: orderStatus);
      if (paginatedOrderModel != null) {
        if (offset == 1) {
          _currentOrderList = [];
        }
        _currentOrderList!.addAll(paginatedOrderModel.orders!);
        _pageSize = paginatedOrderModel.totalSize;
        _paginate = false;
        update();
      } else {
        if (_paginate) {
          _paginate = false;
          update();
        }
      }
    }
  }

  Future<void> getLatestOrders() async {
    List<OrderModel>? latestOrderList = await orderServiceInterface
        .getLatestOrders();
    if (latestOrderList != null) {
      _latestOrderList = [];
      List<int?> ignoredIdList = orderServiceInterface.prepareIgnoreIdList(
        _ignoredRequests,
      );
      _latestOrderList!.addAll(
        orderServiceInterface.processLatestOrders(
          latestOrderList,
          ignoredIdList,
        ),
      );
    }
    update();
  }

  Future<bool> updateOrderStatus(
    OrderModel currentOrder,
    String status, {
    bool back = false,
    String? reason,
    bool? parcel = false,
    bool gotoDashboard = false,
    List<String>? reasons,
    String? comment,
    bool stopOtherDataCall = false,
    int? cancelReasonId,
    String? cancellationDetail,
  }) async {
    _isLoading = true;
    update();
    final bool isParcel = parcel ?? false;
    final bool isStoreCancel =
        status == AppConstants.canceled && !isParcel;

    List<MultipartBody> multiParts = orderServiceInterface
        .prepareOrderProofImages(_pickedPrescriptions);
    if (isStoreCancel) {
      multiParts = [...multiParts, ...orderServiceInterface.prepareCancelEvidenceImages(_pickedCancelEvidence)];
      if (_cancelAudio != null) {
        multiParts.add(MultipartBody('cancel_audio', _cancelAudio));
      }
    }

    String? cancelLat;
    String? cancelLng;
    if (isStoreCancel) {
      try {
        final Position p = await Geolocator.getCurrentPosition();
        cancelLat = p.latitude.toString();
        cancelLng = p.longitude.toString();
      } catch (_) {}
    }

    final UpdateStatusBodyModel updateStatusBody = UpdateStatusBodyModel(
      orderId: currentOrder.id,
      status: status,
      reason: reason,
      otp:
          status == AppConstants.delivered ||
              (isParcel && status == AppConstants.pickedUp)
          ? _otp
          : null,
      isParcel: parcel,
      comment: comment,
      reasons: reasons,
      cancelReasonId: isStoreCancel ? cancelReasonId : null,
      cancellationDetail: isStoreCancel ? cancellationDetail : null,
      cancelLat: isStoreCancel ? cancelLat : null,
      cancelLng: isStoreCancel ? cancelLng : null,
    );
    final ResponseModel responseModel =
        await orderServiceInterface.updateOrderStatus(
      updateStatusBody,
      multiParts,
    );

    if (responseModel.isSuccess) {
      _pickedPrescriptions = [];
      _pickedCancelEvidence.clear();
      _cancelAudio = null;
      _selectedCancelReasonId = null;
      _cancelReason = '';

      if (Get.isDialogOpen == true) {
        Get.back(result: true);
      }
      if (Get.isBottomSheetOpen == true) {
        Get.back(result: true);
      }
      if (back) {
        Get.back();
      }
      if (gotoDashboard) {
        Get.offAllNamed(RouteHelper.getInitialRoute(fromOrderDetails: true));
      }
      if (!stopOtherDataCall) {
        Get.find<ProfileController>().getProfile();

        final List<String> autoResetStatuses = ['picked_up'];
        if (autoResetStatuses.contains(currentOrder.orderStatus) &&
            _selectedRunningStatus != 'all') {
          _selectedRunningStatus = 'all';
        }

        getRunningOrders(offset);
        getOrderCount('current');
        currentOrder.orderStatus = status;
      }
      showCustomSnackBar(
        responseModel.message,
        isError: false,
        getXSnackBar: false,
      );
    } else {
      showCustomSnackBar(
        responseModel.message,
        isError: true,
        getXSnackBar: false,
      );
    }
    _isLoading = false;
    update();
    return responseModel.isSuccess;
  }

  Future<bool> ignoreOrderApi(int orderId) async {
    _isLoading = true;
    update();
    ResponseModel responseModel = await orderServiceInterface.ignoreOrderApi(orderId);
    if (responseModel.isSuccess) {
      Get.back(); // close the bottom sheet
      Get.find<ProfileController>().getProfile();
      getRunningOrders(1);
    } else {
      showCustomSnackBar(responseModel.message);
    }
    _isLoading = false;
    update();
    return responseModel.isSuccess;
  }

  Future<void> getOrderDetails(int? orderID, bool parcel) async {
    if (parcel) {
      _orderDetailsModel = [];
    } else {
      _orderDetailsModel = null;
      List<OrderDetailsModel>? orderDetailsModel = await orderServiceInterface
          .getOrderDetails(orderID);
      if (orderDetailsModel != null) {
        _orderDetailsModel = [];
        _orderDetailsModel!.addAll(orderDetailsModel);
      } else {
        _orderDetailsModel = [];
      }
      update();
    }
  }

  Future<bool> acceptOrder(
    int? orderID,
    int index,
    OrderModel orderModel,
  ) async {
    _isLoading = true;
    update();
    ResponseModel responseModel = await orderServiceInterface.acceptOrder(
      orderID,
    );
    // NOTA: No llamamos Get.back() aquí porque el flujo actual usa un bottom sheet
    // embebido en el Scaffold (no una ruta propia). Llamarlo cerraría la pantalla equivocada.
    if (responseModel.isSuccess) {
      if (_latestOrderList != null &&
          _latestOrderList!.isNotEmpty &&
          index < _latestOrderList!.length) {
        _latestOrderList!.removeAt(index);
      }
      // Inicializar la lista si es null para evitar crash
      _currentOrderList ??= [];
      _currentOrderList!.add(orderModel);
    } else {
      showCustomSnackBar(responseModel.message, isError: true);
    }
    _isLoading = false;
    update();
    return responseModel.isSuccess;
  }

  void getIgnoreList() {
    _ignoredRequests = [];
    _ignoredRequests.addAll(orderServiceInterface.getIgnoreList());
  }

  void ignoreOrder(int index) {
    if (_latestOrderList != null &&
        _latestOrderList!.isNotEmpty &&
        index < _latestOrderList!.length) {
      _ignoredRequests.add(
        IgnoreModel(id: _latestOrderList![index].id, time: DateTime.now()),
      );
      _latestOrderList!.removeAt(index);
      orderServiceInterface.setIgnoreList(_ignoredRequests);
    }
    update();
  }

  void removeFromIgnoreList() {
    List<IgnoreModel> tempList = orderServiceInterface.tempList(
      Get.find<SplashController>().currentTime,
      _ignoredRequests,
    );
    _ignoredRequests = [];
    _ignoredRequests.addAll(tempList);
    orderServiceInterface.setIgnoreList(_ignoredRequests);
  }

  void setOtp(String otp) {
    _otp = otp;
    if (otp != '') {
      update();
    }
  }

  Future<void> getParcelCancellationReasons({
    required bool isBeforePickup,
  }) async {
    _parcelCancellationReasons = null;
    ParcelCancellationReasonsModel? parcelCancellationReasons =
        await orderServiceInterface.getParcelCancellationReasons(
          isBeforePickup: isBeforePickup,
        );
    if (parcelCancellationReasons != null) {
      _parcelCancellationReasons = [];
      _parcelCancellationReasons!.addAll(parcelCancellationReasons.data!);
    }
    update();
  }

  void toggleParcelCancelReason(String reason, bool isSelected) {
    if (isSelected) {
      if (!_selectedParcelCancelReason.contains(reason)) {
        _selectedParcelCancelReason.add(reason);
      }
    } else {
      _selectedParcelCancelReason.remove(reason);
    }
    update();
  }

  bool isReasonSelected(String reason) {
    return _selectedParcelCancelReason.contains(reason);
  }

  void clearSelectedParcelCancelReason() {
    _selectedParcelCancelReason.clear();
  }

  String get selectedTimeFormatted {
    return '${_selectedHour.toString().padLeft(2, '0')}:${_selectedMinute.toString().padLeft(2, '0')} $_selectedPeriod';
  }

  DateTime? get selectedDateTime {
    if (_selectedDate == null) return null;

    int hour24 = _selectedHour;
    if (_selectedPeriod == 'PM' && _selectedHour != 12) {
      hour24 += 12;
    } else if (_selectedPeriod == 'AM' && _selectedHour == 12) {
      hour24 = 0;
    }

    return DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      hour24,
      _selectedMinute,
    );
  }

  void initializeDates(String canceledDateTimeString, int returnDays) {
    try {
      // Parse canceled datetime
      DateTime canceledDateTime = DateTime.parse(canceledDateTimeString);

      // Generate available dates (from canceled date to canceled date + returnDays)
      _availableDates.clear();
      DateTime currentDate = DateTime.now();

      for (int i = 0; i <= returnDays; i++) {
        DateTime availableDate = DateTime(
          canceledDateTime.year,
          canceledDateTime.month,
          canceledDateTime.day + i,
        );

        // Only add dates that are today or in the future
        if (availableDate.isAfter(
              currentDate.subtract(const Duration(days: 1)),
            ) ||
            _isSameDay(availableDate, currentDate)) {
          _availableDates.add(availableDate);
        }
      }

      // Set default selected date to the first available date
      if (_availableDates.isNotEmpty) {
        _selectedDate = _availableDates.first;
      }

      update();
    } catch (e) {
      debugPrint('Error parsing canceled datetime: $e');
    }
  }

  void selectDate(DateTime date) {
    if (_availableDates.contains(date)) {
      _selectedDate = date;
      update();
    }
  }

  void selectHour(int hour) {
    if (hour >= 1 && hour <= 12) {
      _selectedHour = hour;
      update();
    }
  }

  void selectMinute(int minute) {
    if (minute >= 0 && minute <= 59) {
      _selectedMinute = minute;
      update();
    }
  }

  void selectPeriod(String period) {
    if (period == 'AM' || period == 'PM') {
      _selectedPeriod = period;
      update();
    }
  }

  bool isDateSelected(DateTime date) {
    return _selectedDate != null && _isSameDay(_selectedDate!, date);
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  String formatDate(DateTime date) {
    return DateFormat('MMM dd').format(date);
  }

  String formatDateWithDay(DateTime date) {
    return DateFormat('EEE, MMM dd').format(date);
  }

  bool canSubmit() {
    return _selectedDate != null;
  }

  void reset() {
    _selectedDate = null;
    _selectedHour = 11;
    _selectedMinute = 59;
    _selectedPeriod = 'PM';
    _availableDates.clear();
    update();
  }

  Future<void> addParcelReturnDate({
    required int orderId,
    required String returnDate,
  }) async {
    _isLoading = true;
    update();

    await orderServiceInterface.addParcelReturnDate(
      orderId: orderId,
      returnDate: returnDate,
    );
    getOrderWithId(orderId);

    _isLoading = false;
    update();
  }

  Future<void> submitParcelReturn({required int orderId}) async {
    _isLoading = true;
    update();

    bool isSuccess = await orderServiceInterface.submitParcelReturn(
      orderId: orderId,
      orderStatus: 'returned',
      returnOtp: int.parse(_otp),
    );
    if (isSuccess) {
      getOrderWithId(orderId);

      if (Get.isDialogOpen!) {
        Get.back();
      }
      showCustomSnackBar('parcel_returned_successfully'.tr, isError: false);
    }

    _isLoading = false;
    update();
  }

  List<OrderCountModel> get filteredOrderCountList {
    if (_currentOrderCountList == null) return [];
    return _currentOrderCountList!
        .where((status) => (status.count ?? 0) > 0)
        .toList();
  }

  List<OrderCountModel> get filteredHistoryOrderCountList {
    if (_historyOrderCountList == null) return [];
    return _historyOrderCountList!
        .where((status) => (status.count ?? 0) > 0)
        .toList();
  }

  Future<void> getOrderCount(String type) async {
    _isLoading = true;
    _orderType = type;
    List<OrderCountModel>? response = await orderServiceInterface.getOrderCount(
      type,
    );
    if (response != null && response.isNotEmpty) {
      if (_orderType == 'current') {
        _currentOrderCountList = response;
      } else if (_orderType == 'history') {
        _historyOrderCountList = response;
      }
    } else {
      if (_orderType == 'current') {
        _currentOrderCountList = [];
      } else if (_orderType == 'history') {
        _historyOrderCountList = [];
      }
    }
    _isLoading = false;
  }

  void setHistoryOrderStatus(String status) {
    _selectedHistoryStatus = status;
    update();
    getCompletedOrders(1, status: status);
  }

  void setRunningOrderStatus(String status) {
    _selectedRunningStatus = status;
    update();
    getRunningOrders(1, status: status);
  }

  // --- Contexto cancelación: timer contacto cliente (mapa) + chat soporte ---

  int? _cancelContactSnapshotOrderId;
  String _cancelContactSnapshotPhase = '';
  int _cancelContactSnapshotCalls = 0;
  bool _cancelContactSnapshotWithin100m = false;
  bool _cancelContactSnapshotCountdownStarted = false;
  int? _cancelContactSnapshotSecondsRemaining;
  String? _cancelSupportPrefillQueued;

  void logCustomerCallAttemptToServer(
    int orderId,
    int attemptNumber,
    int confirmedAtMs,
  ) {
    unawaited(
      orderServiceInterface.logCustomerCallAttempt(
        orderId: orderId,
        attemptNumber: attemptNumber,
        confirmedAtMs: confirmedAtMs,
      ),
    );
  }

  void reportDeliveryCancelContactSnapshot({
    required int? orderId,
    required String phase,
    required int customerCallCount,
    required bool within100mOfCustomer,
    required bool contactCountdownStarted,
    int? contactSecondsRemaining,
  }) {
    if (orderId == null) return;
    if (phase != 'going_to_customer') {
      if (_cancelContactSnapshotOrderId == orderId) {
        _cancelContactSnapshotOrderId = null;
        _cancelContactSnapshotPhase = '';
        _cancelContactSnapshotCalls = 0;
        _cancelContactSnapshotWithin100m = false;
        _cancelContactSnapshotCountdownStarted = false;
        _cancelContactSnapshotSecondsRemaining = null;
      }
      return;
    }
    _cancelContactSnapshotOrderId = orderId;
    _cancelContactSnapshotPhase = phase;
    _cancelContactSnapshotCalls = customerCallCount;
    _cancelContactSnapshotWithin100m = within100mOfCustomer;
    _cancelContactSnapshotCountdownStarted = contactCountdownStarted;
    _cancelContactSnapshotSecondsRemaining = contactSecondsRemaining;
  }

  String? consumeCancelSupportPrefill() {
    final String? s = _cancelSupportPrefillQueued;
    _cancelSupportPrefillQueued = null;
    return s;
  }

  static String _mmSsFromSeconds(int totalSeconds) {
    final int m = totalSeconds ~/ 60;
    final int s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _buildCancelSupportPrefillMessage({
    required int orderId,
    OrderModel? order,
    double? dmLat,
    double? dmLng,
    String? cancellationReason,
  }) {
    final StringBuffer buf = StringBuffer();
    buf.writeln('dm_cancel_support_message_header'.tr);
    buf.writeln('');
    buf.writeln('${'dm_cancel_support_order_label'.tr}: #$orderId');
    final String orderType = order?.orderType ?? '';
    buf.writeln('${'dm_cancel_support_order_type_label'.tr}: $orderType');

    final String addr = order?.orderType == 'parcel'
        ? (order?.receiverDetails?.address ??
            order?.deliveryAddress?.address ??
            '—')
        : (order?.deliveryAddress?.address ?? '—');
    buf.writeln('${'dm_cancel_support_address_label'.tr}: $addr');

    if (dmLat != null && dmLng != null) {
      buf.writeln(
        '${'dm_cancel_support_dm_location_label'.tr}: ${dmLat.toStringAsFixed(6)}, ${dmLng.toStringAsFixed(6)}',
      );
    } else {
      buf.writeln(
        '${'dm_cancel_support_dm_location_label'.tr}: ${'dm_cancel_support_dm_location_na'.tr}',
      );
    }

    final bool snapshotForThisOrder = _cancelContactSnapshotOrderId != null &&
        _cancelContactSnapshotOrderId == orderId;
    final bool isParcel = order?.orderType == 'parcel';

    if (cancellationReason != null && cancellationReason.isNotEmpty) {
      buf.writeln('');
      buf.writeln('Motivo de cancelación solicitado: $cancellationReason');
    }

    buf.writeln('');
    buf.writeln('${'dm_cancel_support_contact_rules_title'.tr}:');
    if (isParcel || !snapshotForThisOrder) {
      buf.writeln('dm_cancel_support_timer_na'.tr);
    } else {
      buf.writeln(
        '${'dm_cancel_support_route_phase_label'.tr}: $_cancelContactSnapshotPhase',
      );
      buf.writeln(
        '${'dm_cancel_support_calls_label'.tr}: $_cancelContactSnapshotCalls / 3',
      );
      buf.writeln(
        '${'dm_cancel_support_within_100m_label'.tr}: ${_cancelContactSnapshotWithin100m ? 'dm_cancel_support_yes'.tr : 'dm_cancel_support_no'.tr}',
      );
      if (!_cancelContactSnapshotCountdownStarted) {
        buf.writeln('dm_cancel_support_timer_not_started'.tr);
      } else if ((_cancelContactSnapshotSecondsRemaining ?? 1) <= 0) {
        buf.writeln('dm_cancel_support_timer_done'.tr);
      } else {
        buf.writeln(
          '${'dm_cancel_support_timer_running'.tr}: ${_mmSsFromSeconds(_cancelContactSnapshotSecondsRemaining ?? 0)}',
        );
      }
    }

    buf.writeln('');
    buf.write('dm_cancel_support_footer'.tr);
    return buf.toString();
  }

  /// Abre chat con administración con datos del pedido y reglas de contacto; al cerrar el chat ejecuta [afterReturn].
  Future<void> openAdminSupportChatForCancelRequest({
    required int orderId,
    OrderModel? order,
    VoidCallback? afterReturn,
    String? cancellationReason,
  }) async {
    double? dmLat;
    double? dmLng;
    try {
      final Position p = await Geolocator.getCurrentPosition();
      dmLat = p.latitude;
      dmLng = p.longitude;
    } catch (_) {
      try {
        final r = Get.find<ProfileController>().recordLocationBody;
        dmLat = r?.latitude;
        dmLng = r?.longitude;
      } catch (_) {}
    }

    _cancelSupportPrefillQueued = _buildCancelSupportPrefillMessage(
      orderId: orderId,
      order: order,
      dmLat: dmLat,
      dmLng: dmLng,
      cancellationReason: cancellationReason,
    );

    final String route = RouteHelper.getChatRoute(
      notificationBody: NotificationBodyModel(
        type: AppConstants.admin,
        orderId: orderId,
      ),
      user: User(
        id: 0,
        fName: 'Soporte',
        lName: 'Tootli',
        imageFullUrl: '',
      ),
    );

    await Get.toNamed(route);
    _cancelSupportPrefillQueued = null;

    if (afterReturn != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        afterReturn();
      });
    }
  }
}
