import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixam_mart_delivery/api/api_client.dart';
import 'package:sixam_mart_delivery/common/models/response_model.dart';
import 'package:sixam_mart_delivery/features/order/domain/models/ignore_model.dart';
import 'package:sixam_mart_delivery/features/order/domain/models/order_cancellation_body.dart';
import 'package:sixam_mart_delivery/features/order/domain/models/order_details_model.dart';
import 'package:sixam_mart_delivery/features/order/domain/models/order_model.dart';
import 'package:sixam_mart_delivery/features/order/domain/models/parcel_cancellation_reasons_model.dart';
import 'package:sixam_mart_delivery/features/order/domain/models/update_status_body_model.dart';
import 'package:sixam_mart_delivery/features/order/domain/repositories/order_repository_interface.dart';
import 'package:sixam_mart_delivery/util/app_constants.dart';
import 'package:flutter/foundation.dart';

import '../models/order_count_model.dart';

class OrderRepository implements OrderRepositoryInterface {
  final ApiClient apiClient;
  final SharedPreferences sharedPreferences;
  OrderRepository({required this.apiClient, required this.sharedPreferences});

  @override
  Future<List<CancellationData>?> getCancelReasons() async {
    List<CancellationData>? orderCancelReasons;
    final String token = _getUserToken();
    final Response response = await apiClient.getData(
      '${AppConstants.deliveryManCancelReasonsUri}$token',
    );
    if (response.statusCode == 200 && response.body is Map) {
      final Map<String, dynamic> map = Map<String, dynamic>.from(response.body as Map);
      final dynamic raw = map['reasons'];
      if (raw is List) {
        orderCancelReasons = [];
        for (final dynamic item in raw) {
          if (item is Map) {
            orderCancelReasons.add(
              CancellationData.fromJson(Map<String, dynamic>.from(item)),
            );
          }
        }
      }
    }
    return orderCancelReasons;
  }

  @override
  Future<Response> get(int? id) async {
    Response response = await apiClient.getData(
      '${AppConstants.currentOrderUri}${_getUserToken()}&order_id=$id',
    );
    return response;
  }

  @override
  Future<PaginatedOrderModel?> getCompletedOrderList(
    int offset, {
    String orderStatus = 'all',
  }) async {
    PaginatedOrderModel? paginatedOrderModel;
    Response response = await apiClient.getData(
      '${AppConstants.allOrdersUri}?token=${_getUserToken()}&offset=$offset&limit=10&order_status=$orderStatus',
    );
    if (response.statusCode == 200) {
      paginatedOrderModel = PaginatedOrderModel.fromJson(response.body);
    }
    return paginatedOrderModel;
  }

  // @override
  // Future<PaginatedOrderModel?> getCompletedOrderList(int offset) async {
  //   PaginatedOrderModel? paginatedOrderModel;
  //   Response response = await apiClient.getData('${AppConstants.allOrdersUri}?token=${_getUserToken()}&offset=$offset&limit=10&');
  //   if (response.statusCode == 200) {
  //     paginatedOrderModel = PaginatedOrderModel.fromJson(response.body);
  //   }
  //   return paginatedOrderModel;
  // }

  @override
  Future<List<OrderModel>?> getLatestOrders({bool includeRejected = false}) async {
    List<OrderModel>? latestOrderList;
    final String extra = includeRejected ? '&include_rejected=1' : '';
    Response response = await apiClient.getData(
      '${AppConstants.latestOrdersUri}${_getUserToken()}$extra',
    );
    if (response.statusCode == 200) {
      latestOrderList = [];
      response.body.forEach(
        (order) => latestOrderList!.add(OrderModel.fromJson(order)),
      );
    }
    return latestOrderList;
  }

  @override
  Future<ResponseModel> updateOrderStatus(
    UpdateStatusBodyModel updateStatusBody,
    List<MultipartBody> proofAttachment,
  ) async {
    updateStatusBody.token = _getUserToken();
    ResponseModel responseModel;

    Map<String, String> data;

    final String otpField = updateStatusBody.otp ?? '';

    double? lat;
    double? lng;
    try {
      final Position locationResult = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 3),
      );
      lat = locationResult.latitude;
      lng = locationResult.longitude;
    } catch (_) {}

    if (updateStatusBody.isParcel ?? false) {
      data = {
        '_method': 'put',
        'token': updateStatusBody.token!,
        'order_id': updateStatusBody.orderId.toString(),
        'status': updateStatusBody.status.toString(),
        'otp': otpField,
        'reason': updateStatusBody.reasons.toString(),
        'note': updateStatusBody.comment ?? '',
      };
    } else {
      data = {
        '_method': 'put',
        'token': updateStatusBody.token!,
        'order_id': updateStatusBody.orderId.toString(),
        'status': updateStatusBody.status.toString(),
        'otp': otpField,
        'reason': updateStatusBody.reason ?? '',
      };
      if (lat != null && lng != null) {
        data['lat'] = lat.toString();
        data['lng'] = lng.toString();
      }
      if (updateStatusBody.status == AppConstants.canceled) {
        if (updateStatusBody.cancelReasonId != null) {
          data['cancel_reason_id'] = updateStatusBody.cancelReasonId.toString();
        }
        final String detail = updateStatusBody.cancellationDetail?.trim() ?? '';
        if (detail.isNotEmpty) {
          data['cancellation_detail'] = detail;
        }
        if (updateStatusBody.cancelLat != null &&
            updateStatusBody.cancelLng != null) {
          data['cancel_lat'] = updateStatusBody.cancelLat!;
          data['cancel_lng'] = updateStatusBody.cancelLng!;
        }
      }
    }

    final Response response = await apiClient.postMultipartData(
      AppConstants.updateOrderStatusUri,
      data,
      proofAttachment,
      handleError: false,
    );
    if (response.statusCode == 200) {
      final dynamic body = response.body;
      final String msg = body is Map && body['message'] != null
          ? body['message'].toString()
          : 'OK';
      responseModel = ResponseModel(true, msg);
    } else {
      String? errorMessage = response.statusText;
      final dynamic body = response.body;
      if (body is Map && body['errors'] is List && (body['errors'] as List).isNotEmpty) {
        final dynamic first = (body['errors'] as List).first;
        if (first is Map) {
          errorMessage = first['message'] as String? ?? errorMessage;
        }
      }
      responseModel = ResponseModel(false, errorMessage ?? 'Error');
    }
    return responseModel;
  }

  @override
  Future<ResponseModel> ignoreOrderApi(int orderId) async {
    Response response = await apiClient.postData(AppConstants.ignoreOrderUri, {"order_id": orderId});
    if (response.statusCode == 200) {
      return ResponseModel(true, response.body['message']);
    } else {
      return ResponseModel(false, response.statusText);
    }
  }

  @override
  Future<List<OrderDetailsModel>?> getOrderDetails(int? orderID) async {
    List<OrderDetailsModel>? orderDetailsModel;
    Response response = await apiClient.getData(
      '${AppConstants.orderDetailsUri}${_getUserToken()}&order_id=$orderID',
    );
    if (response.statusCode == 200) {
      try {
        sharedPreferences.setString('order_details_cache_${orderID}', jsonEncode(response.body));
      } catch (e) {
        debugPrint('Failed to save order details to cache: $e');
      }
      orderDetailsModel = [];
      response.body.forEach((orderDetails) {
        try {
          orderDetailsModel!.add(OrderDetailsModel.fromJson(orderDetails));
        } catch (e, stacktrace) {
          debugPrint('Error parsing OrderDetails: $e');
          debugPrint('Stacktrace: $stacktrace');
          debugPrint('JSON data: $orderDetails');
        }
      });
    } else {
      try {
        String? cachedJson = sharedPreferences.getString('order_details_cache_${orderID}');
        if (cachedJson != null && cachedJson.isNotEmpty) {
          final decoded = jsonDecode(cachedJson);
          if (decoded is List) {
            orderDetailsModel = [];
            for (var orderDetails in decoded) {
              orderDetailsModel.add(OrderDetailsModel.fromJson(orderDetails));
            }
          }
        }
      } catch (e) {
        debugPrint('Failed to read order details from cache: $e');
      }
    }
    return orderDetailsModel;
  }

  @override
  Future<ResponseModel> acceptOrder(int? orderID) async {
    ResponseModel responseModel;
    final Position locationResult = await Geolocator.getCurrentPosition();
    Response response = await apiClient.postData(AppConstants.acceptOrderUri, {
      "_method": "put",
      'token': _getUserToken(),
      'order_id': orderID,
      'lat': locationResult.latitude,
      'lng': locationResult.longitude,
    }, handleError: false);
    if (response.statusCode == 200) {
      responseModel = ResponseModel(true, response.body['message']);
    } else {
      String? errorMessage;
      final body = response.body;
      if (body is Map && body['errors'] is List && (body['errors'] as List).isNotEmpty) {
        final first = (body['errors'] as List).first;
        if (first is Map) {
          errorMessage = first['message'] as String?;
          final mk = (first['message_key'] as String?) ?? (first['code'] as String?);
          if ((errorMessage == null || errorMessage.isEmpty) && mk != null && mk.isNotEmpty) {
            final localized = 'accept_order_error_$mk'.tr;
            if (localized != 'accept_order_error_$mk') {
              errorMessage = localized;
            }
          }
        }
      }
      responseModel = ResponseModel(false, errorMessage ?? response.statusText);
    }
    return responseModel;
  }

  @override
  List<IgnoreModel> getIgnoreList() {
    List<IgnoreModel> ignoreList = [];
    List<String> stringList =
        sharedPreferences.getStringList(AppConstants.ignoreList) ?? [];
    for (var ignore in stringList) {
      ignoreList.add(IgnoreModel.fromJson(jsonDecode(ignore)));
    }
    return ignoreList;
  }

  @override
  void setIgnoreList(List<IgnoreModel> ignoreList) {
    List<String> stringList = [];
    for (var ignore in ignoreList) {
      stringList.add(jsonEncode(ignore.toJson()));
    }
    sharedPreferences.setStringList(AppConstants.ignoreList, stringList);
  }

  String _getUserToken() {
    return sharedPreferences.getString(AppConstants.token) ?? "";
  }

  @override
  Future<ParcelCancellationReasonsModel?> getParcelCancellationReasons({
    required bool isBeforePickup,
  }) async {
    ParcelCancellationReasonsModel? cancellationReasonsModel;
    Response response = await apiClient.getData(
      '${AppConstants.getParcelCancellationReasons}?limit=25&offset=1&user_type=customer&cancellation_type=${isBeforePickup ? 'before_pickup' : 'after_pickup'}',
    );
    if (response.statusCode == 200) {
      cancellationReasonsModel = ParcelCancellationReasonsModel.fromJson(
        response.body,
      );
    }
    return cancellationReasonsModel;
  }

  @override
  Future<bool> addParcelReturnDate({
    required int orderId,
    required String returnDate,
  }) async {
    Map<String, dynamic> data = {
      'token': _getUserToken(),
      'order_id': orderId,
      'return_date': returnDate,
    };
    Response response = await apiClient.postData(
      AppConstants.addParcelReturnDate,
      data,
    );
    return response.statusCode == 200;
  }

  @override
  Future<bool> submitParcelReturn({
    required int orderId,
    required String orderStatus,
    required int returnOtp,
  }) async {
    Map<String, dynamic> data = {
      'order_id': orderId,
      'order_status': orderStatus,
      'return_otp': returnOtp,
      'token': _getUserToken(),
    };
    Response response = await apiClient.postData(
      AppConstants.parcelReturn,
      data,
    );
    return response.statusCode == 200;
  }

  @override
  Future<PaginatedOrderModel?> getCurrentOrders(
    int offset, {
    String orderStatus = 'all',
  }) async {
    PaginatedOrderModel? paginatedOrderModel;
    Response response = await apiClient.getData(
      '${AppConstants.currentOrdersUri + _getUserToken()}&offset=$offset&limit=10&order_status=$orderStatus',
    );
    if (response.statusCode == 200) {
      try {
        sharedPreferences.setString('current_orders_cache_${orderStatus}', jsonEncode(response.body));
      } catch (e) {
        debugPrint('Failed to save current orders to cache: $e');
      }
      if (response.body is List) {
        paginatedOrderModel = PaginatedOrderModel(
          orders: (response.body as List)
              .map((order) => OrderModel.fromJson(order))
              .toList(),
          totalSize: (response.body as List).length,
          offset: offset.toString(),
          limit: '10',
        );
      } else {
        paginatedOrderModel = PaginatedOrderModel.fromJson(response.body);
      }
    } else {
      try {
        String? cachedJson = sharedPreferences.getString('current_orders_cache_${orderStatus}');
        if (cachedJson != null && cachedJson.isNotEmpty) {
          final decoded = jsonDecode(cachedJson);
          if (decoded is List) {
            paginatedOrderModel = PaginatedOrderModel(
              orders: decoded.map((order) => OrderModel.fromJson(order)).toList(),
              totalSize: decoded.length,
              offset: offset.toString(),
              limit: '10',
            );
          } else {
            paginatedOrderModel = PaginatedOrderModel.fromJson(decoded);
          }
        }
      } catch (e) {
        debugPrint('Failed to read current orders from cache: $e');
      }
    }
    return paginatedOrderModel;
  }

  @override
  Future<List<OrderCountModel>?> getOrderCount(String type) async {
    List<OrderCountModel>? orderCountList;
    Response response = await apiClient.getData(
      '${AppConstants.orderCount}?type=$type&token=${_getUserToken()}',
    );
    if (response.statusCode == 200) {
      orderCountList = (response.body as List)
          .map((item) => OrderCountModel.fromJson(item))
          .toList();
    }
    return orderCountList;
  }

  @override
  Future add(value) {
    throw UnimplementedError();
  }

  @override
  Future delete(int? id) {
    throw UnimplementedError();
  }

  @override
  Future update(Map<String, dynamic> body) {
    throw UnimplementedError();
  }

  @override
  Future<dynamic> getList() {
    throw UnimplementedError();
  }

  @override
  Future<void> logCustomerCallAttempt({
    required int orderId,
    required int attemptNumber,
    required int confirmedAtMs,
  }) async {
    if (_getUserToken().isEmpty) {
      return;
    }
    await apiClient.postData(
      AppConstants.logCustomerCallAttemptUri,
      {
        'token': _getUserToken(),
        'order_id': orderId,
        'attempt_number': attemptNumber,
        'confirmed_at_ms': confirmedAtMs,
      },
      handleError: false,
    );
  }

  @override
  Future<int> getOrderCallsCount(int orderId) async {
    if (_getUserToken().isEmpty) {
      return 0;
    }
    Response response = await apiClient.getData(
      '${AppConstants.orderCallsCountUri}?token=${_getUserToken()}&order_id=$orderId',
    );
    if (response.statusCode == 200 && response.body is Map) {
      return response.body['calls_count'] ?? 0;
    }
    return 0;
  }

  @override
  Future<Response> getOptimizedRoute(double lat, double lng) async {
    return await apiClient.getData(
      '${AppConstants.optimizedRouteUri}?token=${_getUserToken()}&latitude=$lat&longitude=$lng',
    );
  }

  @override
  Future<ResponseModel> uploadReceiptPhotos(int orderId, List<MultipartBody> photos) async {
    Map<String, String> data = {
      'order_id': orderId.toString(),
      'token': _getUserToken(),
    };
    Response response = await apiClient.postMultipartData(
      AppConstants.parcelReceiptPhotoUri,
      data,
      photos,
      handleError: false,
    );
    if (response.statusCode == 200) {
      final dynamic body = response.body;
      final String msg = body is Map && body['message'] != null
          ? body['message'].toString()
          : 'OK';
      return ResponseModel(true, msg);
    } else {
      String? errorMessage = response.statusText;
      final dynamic body = response.body;
      if (body is Map && body['errors'] is List && (body['errors'] as List).isNotEmpty) {
        final dynamic first = (body['errors'] as List).first;
        if (first is Map) {
          errorMessage = first['message'] as String? ?? errorMessage;
        }
      }
      return ResponseModel(false, errorMessage ?? 'Error');
    }
  }
}
