import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixam_mart_delivery/api/api_client.dart';
import 'package:sixam_mart_delivery/features/auth/domain/models/delivery_man_body_model.dart';
import 'package:sixam_mart_delivery/features/auth/domain/models/register_dm_result.dart';
import 'package:sixam_mart_delivery/features/auth/domain/models/vehicle_model.dart';
import 'package:sixam_mart_delivery/features/auth/domain/repositories/auth_repository_interface.dart';
import 'package:sixam_mart_delivery/util/app_constants.dart';

class AuthRepository implements AuthRepositoryInterface {
  final ApiClient apiClient;
  final SharedPreferences sharedPreferences;
  AuthRepository({required this.apiClient, required this.sharedPreferences});

  @override
  Future<Response> login(String phone, String password) async {
    return await apiClient.postData(AppConstants.loginUri, {
      "phone": phone,
      "password": password,
    }, handleError: false);
  }

  @override
  Future<RegisterDmResult> registerDeliveryMan(
    DeliveryManBodyModel deliveryManBody,
    List<MultipartBody> multiParts,
  ) async {
    Response response = await apiClient.postMultipartData(
      AppConstants.dmRegisterUri,
      deliveryManBody.toJson(),
      multiParts,
    );
    return RegisterDmResult.fromResponse(response);
  }

  @override
  Future<bool> submitRegistrationRevision(
    DeliveryManBodyModel deliveryManBody,
    List<MultipartBody> multiParts,
    Map<String, String> revisionExtras,
  ) async {
    final Map<String, String> fields = deliveryManBody.toRevisionSubmitMap(getUserToken());
    fields.addAll(revisionExtras);
    final Response response = await apiClient.postMultipartData(
      AppConstants.dmSubmitRegistrationRevisionUri,
      fields,
      multiParts,
      handleError: false,
    );
    return response.statusCode == 200;
  }

  @override
  Future<List<VehicleModel>?> getList() async {
    List<VehicleModel>? vehicles;
    Response response = await apiClient.getData(AppConstants.vehiclesUri);
    if (response.statusCode == 200) {
      vehicles = [];
      response.body.forEach(
        (vehicle) => vehicles!.add(VehicleModel.fromJson(vehicle)),
      );
    }
    return vehicles;
  }

  @override
  Future<Response> updateToken() async {
    String? deviceToken;
    if (GetPlatform.isIOS) {
      FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      NotificationSettings settings = await FirebaseMessaging.instance
          .requestPermission(
            alert: true,
            announcement: false,
            badge: true,
            carPlay: false,
            criticalAlert: false,
            provisional: false,
            sound: true,
          );
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        deviceToken = await _saveDeviceToken();
      }
    } else {
      deviceToken = await _saveDeviceToken();
    }
    if (!GetPlatform.isWeb) {
      try {
        await FirebaseMessaging.instance.subscribeToTopic(AppConstants.topic);
        final zoneTopic = sharedPreferences.getString(AppConstants.zoneTopic);
        final vehicleTopic = sharedPreferences.getString(AppConstants.vehicleWiseTopic);
        if (zoneTopic != null && zoneTopic.isNotEmpty) {
          await FirebaseMessaging.instance.subscribeToTopic(zoneTopic);
        }
        if (vehicleTopic != null && vehicleTopic.isNotEmpty) {
          await FirebaseMessaging.instance.subscribeToTopic(vehicleTopic);
        }
      } catch (e) {
        debugPrint('FCM subscribeToTopic error (safe to ignore on simulator): $e');
      }
    }
    return await apiClient.postData(AppConstants.tokenUri, {
      "_method": "put",
      "token": getUserToken(),
      "fcm_token": deviceToken,
    }, handleError: false);
  }

  Future<String?> _saveDeviceToken() async {
    String? deviceToken = '';
    if (!GetPlatform.isWeb) {
      try {
        deviceToken = (await FirebaseMessaging.instance.getToken())!;
      } catch (e) {
        debugPrint('----Error getting device token----- $e');
      }
    }
    debugPrint('----Device Token----- $deviceToken');
    return deviceToken;
  }

  @override
  Future<bool> saveUserToken(
    String token,
    String zoneTopic,
    String vehicleWiseTopic,
  ) async {
    apiClient.token = token;
    apiClient.updateHeader(
      token,
      AppConstants.languages[0].languageCode!,
    );
    sharedPreferences.setString(AppConstants.zoneTopic, zoneTopic);
    sharedPreferences.setString(
      AppConstants.vehicleWiseTopic,
      vehicleWiseTopic,
    );

    return await sharedPreferences.setString(AppConstants.token, token);
  }

  @override
  String getUserToken() {
    return sharedPreferences.getString(AppConstants.token) ?? "";
  }

  @override
  bool isLoggedIn() {
    return sharedPreferences.containsKey(AppConstants.token);
  }

  @override
  Future<bool> clearSharedData() async {
    if (!GetPlatform.isWeb) {
      try {
        await FirebaseMessaging.instance.unsubscribeFromTopic(AppConstants.topic);
        final zoneTopic = sharedPreferences.getString(AppConstants.zoneTopic);
        final vehicleTopic = sharedPreferences.getString(AppConstants.vehicleWiseTopic);
        if (zoneTopic != null && zoneTopic.isNotEmpty) {
          await FirebaseMessaging.instance.unsubscribeFromTopic(zoneTopic);
        }
        if (vehicleTopic != null && vehicleTopic.isNotEmpty) {
          await FirebaseMessaging.instance.unsubscribeFromTopic(vehicleTopic);
        }
      } catch (e) {
        debugPrint('FCM unsubscribeFromTopic error (safe to ignore on simulator): $e');
      }
      apiClient.postData(AppConstants.tokenUri, {
        "_method": "put",
        "token": getUserToken(),
      }, handleError: false);
    }
    await sharedPreferences.remove(AppConstants.token);
    await sharedPreferences.setStringList(AppConstants.ignoreList, []);
    await sharedPreferences.remove(AppConstants.userAddress);
    apiClient.updateHeader(null, null);
    return true;
  }

  @override
  Future<void> saveUserNumberAndPassword(
    String number,
    String password,
    String countryDialCode,
    String countryCode,
  ) async {
    try {
      await sharedPreferences.setString(AppConstants.userPassword, password);
      await sharedPreferences.setString(AppConstants.userNumber, number);
      await sharedPreferences.setString(
        AppConstants.userCountryDialCode,
        countryDialCode,
      );
      await sharedPreferences.setString(
        AppConstants.userCountryCode,
        countryCode,
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  String getUserNumber() {
    return sharedPreferences.getString(AppConstants.userNumber) ?? "";
  }

  @override
  String getUserCountryDialCode() {
    return sharedPreferences.getString(AppConstants.userCountryDialCode) ?? "";
  }

  @override
  String getUserCountryCode() {
    return sharedPreferences.getString(AppConstants.userCountryCode) ?? "";
  }

  @override
  String getUserPassword() {
    return sharedPreferences.getString(AppConstants.userPassword) ?? "";
  }

  @override
  bool isNotificationActive() {
    return sharedPreferences.getBool(AppConstants.notification) ?? true;
  }

  @override
  Future<void> setNotificationActive(bool isActive) async {
    if (isActive) {
      updateToken();
    } else {
      if (!GetPlatform.isWeb) {
        apiClient.postData(AppConstants.tokenUri, {
          "_method": "put",
          "token": getUserToken(),
        }, handleError: false);
        try {
          await FirebaseMessaging.instance.unsubscribeFromTopic(AppConstants.topic);
          final zoneTopic = sharedPreferences.getString(AppConstants.zoneTopic);
          final vehicleTopic = sharedPreferences.getString(AppConstants.vehicleWiseTopic);
          if (zoneTopic != null && zoneTopic.isNotEmpty) {
            await FirebaseMessaging.instance.unsubscribeFromTopic(zoneTopic);
          }
          if (vehicleTopic != null && vehicleTopic.isNotEmpty) {
            await FirebaseMessaging.instance.unsubscribeFromTopic(vehicleTopic);
          }
        } catch (e) {
          debugPrint('FCM unsubscribeFromTopic error (safe to ignore on simulator): $e');
        }
      }
    }
    sharedPreferences.setBool(AppConstants.notification, isActive);
  }

  @override
  Future<bool> clearUserNumberAndPassword() async {
    await sharedPreferences.remove(AppConstants.userPassword);
    await sharedPreferences.remove(AppConstants.userCountryDialCode);
    await sharedPreferences.remove(AppConstants.userCountryCode);
    return await sharedPreferences.remove(AppConstants.userNumber);
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
  Future get(int? id) {
    throw UnimplementedError();
  }

  @override
  Future update(Map<String, dynamic> body) {
    throw UnimplementedError();
  }
}
