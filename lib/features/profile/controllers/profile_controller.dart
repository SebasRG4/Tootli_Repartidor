import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sixam_mart_delivery/common/models/response_model.dart';
import 'package:sixam_mart_delivery/common/widgets/confirmation_dialog_widget.dart';
import 'package:sixam_mart_delivery/util/images.dart';
import 'package:sixam_mart_delivery/features/auth/controllers/auth_controller.dart';
import 'package:sixam_mart_delivery/features/splash/controllers/splash_controller.dart';
import 'package:sixam_mart_delivery/features/address/domain/models/record_location_body_model.dart';
import 'package:sixam_mart_delivery/features/profile/domain/models/profile_model.dart';
import 'package:sixam_mart_delivery/helper/route_helper.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_snackbar_widget.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sixam_mart_delivery/helper/notification_helper.dart';
import 'package:sixam_mart_delivery/features/profile/domain/services/profile_service_interface.dart';
import 'package:sixam_mart_delivery/features/my_account/domain/models/offline_payment_method_model.dart';
import 'package:permission_handler/permission_handler.dart';

class ProfileController extends GetxController implements GetxService {
  final ProfileServiceInterface profileServiceInterface;
  ProfileController({required this.profileServiceInterface});

  ProfileModel? _profileModel;
  ProfileModel? get profileModel => _profileModel;
  set profileModel(ProfileModel? model) {
    _profileModel = model;
    update();
  }

  /// Cualquier registro aún en estado `pending`: panel inferior, drawer limitado, sin pedidos.
  bool get isPendingRegistrationDashboard {
    final ProfileModel? m = _profileModel;
    return m != null && m.applicationStatus == 'pending';
  }

  /// Solo la fase “esperando primera revisión” (sin correcciones abiertas): sí enviar ubicación al backend.
  bool get isPendingRegistrationBrowse {
    final ProfileModel? m = _profileModel;
    if (m == null) return false;
    if (!isPendingRegistrationDashboard) return false;
    if (m.registrationRevisionRequired == true) return false;
    if (m.pendingRegistrationBrowse == true) return true;
    return m.applicationStatus == 'pending';
  }

  /// Enviar coordenadas al backend mientras no está en línea (p. ej. registro pendiente o desconectado aprobado).
  bool _sendLocationToBackendWhileInactive() {
    final ProfileModel? m = _profileModel;
    if (m == null) return false;
    if (isPendingRegistrationBrowse) return true;
    if (m.applicationStatus == 'approved') return true;
    return false;
  }

  bool _isLoading = false;
  bool get isLoading => _isLoading;
  bool _isUpdatingActiveStatus = false;

  XFile? _pickedFile;
  XFile? get pickedFile => _pickedFile;

  RecordLocationBodyModel? _recordLocation;
  RecordLocationBodyModel? get recordLocationBody => _recordLocation;

  Timer? _timer;

  bool _backgroundNotification = true;
  bool get backgroundNotification => _backgroundNotification;

  Future<void> getProfile() async {
    ProfileModel? profileModel = await profileServiceInterface.getProfileInfo();
    if (profileModel != null) {
      _profileModel = profileModel;
      debugPrint(
        "[ProfileController] 👤 Profile loaded: ID=${_profileModel!.id}, Name=${_profileModel!.fName}",
      );
      debugPrint(
        "   - Active: ${_profileModel!.active}, Zone ID: ${_profileModel!.zoneId}",
      );
      debugPrint(
        "   - Vehicle ID: ${_profileModel!}, Status: ${_profileModel!.applicationStatus}",
      );

      if (_profileModel!.active == 1) {
        profileServiceInterface.checkPermission(() => startLocationRecord());
      } else {
        stopLocationRecord();
        profileServiceInterface.checkPermission(
          () => startMapLocationWhileInactive(),
        );
      }
    }
    update();
  }

  Future<bool> updateUserInfo(
    ProfileModel updateUserModel,
    String token,
  ) async {
    _isLoading = true;
    update();
    ResponseModel responseModel = await profileServiceInterface.updateProfile(
      updateUserModel,
      _pickedFile,
      token,
    );
    _isLoading = false;
    if (responseModel.isSuccess) {
      _profileModel = updateUserModel;
      Get.back();
      showCustomSnackBar(responseModel.message, isError: false);
    } else {
      showCustomSnackBar(responseModel.message, isError: true);
    }
    update();
    return responseModel.isSuccess;
  }

  void pickImage() async {
    _pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    update();
  }

  void initData() {
    _pickedFile = null;
  }

  Future<bool> updateActiveStatus({bool back = true}) async {
    if (_isUpdatingActiveStatus) {
      debugPrint('[ProfileController] 🛑 updateActiveStatus ya está en ejecución. Ignorando llamada duplicada.');
      return false;
    }
    _isUpdatingActiveStatus = true;
    update();

    try {
      // SALVAVIDAS: Validar permisos críticos antes de permitir ponerse en línea (Ubicación Permitir Siempre y Notificaciones)
      if (_profileModel != null && _profileModel!.active == 0) {
        final LocationPermission locPermission = await Geolocator.checkPermission();
        final notifStatus = await Permission.notification.status;
        
        debugPrint('[ProfileController] 📍 Location Status (Geolocator): $locPermission, 🔔 Notification Status: $notifStatus');
        
        final bool isLocationGranted = locPermission == LocationPermission.always;
        final bool isNotificationGranted = notifStatus.isGranted || notifStatus.isProvisional || notifStatus.isLimited;
        
        if (!isLocationGranted || !isNotificationGranted) {
          Get.dialog(
            ConfirmationDialogWidget(
              icon: Images.warning,
              title: 'Permisos requeridos'.tr,
              description: 'Debes otorgar permisos de Ubicación (Permitir siempre) y Notificaciones para recibir pedidos. ¿Deseas abrir la configuración para activarlos?'.tr,
              onYesPressed: () async {
                Get.back();
                await openAppSettings();
              },
            ),
          );
          return false; // Bloquea el cambio a online
        }

        if (_profileModel!.identityVerified != 'approved') {
          Get.dialog(
            ConfirmationDialogWidget(
              icon: Images.warning,
              title: 'Verificación requerida'.tr,
              description: 'Debes completar tu verificación de identidad (INE y Selfie) para poder recibir pedidos.'.tr,
              onYesPressed: () {
                Get.back();
                Get.toNamed(RouteHelper.getDmKycRoute());
              },
            ),
          );
          return false; // Bloquea el cambio a online
        }
      }

      ResponseModel responseModel = await profileServiceInterface
          .updateActiveStatus();
      if (responseModel.isSuccess) {
        if (back) {
          Get.back();
        }
        _profileModel!.active = _profileModel!.active == 0 ? 1 : 0;
        showCustomSnackBar(responseModel.message, isError: false);
        if (_profileModel!.active == 1) {
          profileServiceInterface.checkPermission(() => startLocationRecord());
          Future.delayed(const Duration(milliseconds: 200), () {
            Get.dialog(
              ConfirmationDialogWidget(
                icon: Images.warning,
                title: 'Atención Repartidor'.tr,
                description: 'Revisa tu vehiculo, medidas de seguriodad y llevar cambio suficiente para pagar o dar cambio'.tr,
                hasCancel: false,
                onYesPressed: () {
                  Get.back();
                },
              ),
              barrierDismissible: false,
            );
          });
        } else {
          stopLocationRecord();
          profileServiceInterface.checkPermission(
            () => startMapLocationWhileInactive(),
          );
        }
      } else {
        if (isPendingRegistrationDashboard) {
          showCustomSnackBar('registration_in_progress_title'.tr, isError: false);
        } else {
          showCustomSnackBar(responseModel.message, isError: true);
        }
      }
      return responseModel.isSuccess;
    } catch (e) {
      debugPrint('[ProfileController] ❌ Error en updateActiveStatus: $e');
      return false;
    } finally {
      _isUpdatingActiveStatus = false;
      update();
    }
  }

  Future deleteDriver() async {
    _isLoading = true;
    update();
    ResponseModel responseModel = await profileServiceInterface.deleteDriver();
    _isLoading = false;
    if (responseModel.isSuccess) {
      showCustomSnackBar(responseModel.message, isError: false);
      Get.find<AuthController>().clearSharedData();
      stopLocationRecord();
      Get.offAllNamed(RouteHelper.getSignInRoute());
    } else {
      Get.back();
      showCustomSnackBar(responseModel.message, isError: true);
    }
  }

  void startLocationRecord() {
    _timer?.cancel();
    NotificationHelper.startLocationService();
    recordLocation(sendToServer: true);
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      recordLocation(sendToServer: true);
    });
  }

  /// GPS para centrar el mapa cuando el repartidor no está en línea (desconectado o registro pendiente).
  void startMapLocationWhileInactive() {
    _timer?.cancel();
    final bool send = _sendLocationToBackendWhileInactive();
    if (send) {
      NotificationHelper.startLocationService();
    }
    recordLocation(sendToServer: send);
    _timer = Timer.periodic(Duration(seconds: send ? 30 : 20), (timer) {
      recordLocation(sendToServer: send);
    });
  }

  void stopLocationRecord() {
    _timer?.cancel();
    NotificationHelper.stopService();
  }

  Future<void> recordLocation({bool sendToServer = true}) async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final Position locationResult = await Geolocator.getCurrentPosition();

      // Anti-Fraud: Mock Location Detection (COO operational mandate)
      // Solo se activa en Release para permitir pruebas y desarrollo (Simulador / Fake GPS)
      if (locationResult.isMocked) {
        if (kReleaseMode) {
          stopLocationRecord();
          if (_profileModel != null && _profileModel!.active == 1) {
            await updateActiveStatus(back: false);
          }
          showCustomSnackBar('mock_location_detected'.tr, isError: true);
          return;
        } else {
          debugPrint('[ProfileController] 📍 Mock location detected but IGNORED in debug mode to allow testing.');
        }
      }

      String address = await profileServiceInterface.addressPlaceMark(
        locationResult,
      );

      _recordLocation = RecordLocationBodyModel(
        location: address,
        latitude: locationResult.latitude,
        longitude: locationResult.longitude,
      );
      update();

      if (!sendToServer) {
        return;
      }

      final configModel = Get.find<SplashController>().configModel;
      if (configModel != null && configModel.webSocketStatus == true) {
        await profileServiceInterface.recordWebSocketLocation(_recordLocation!);
      }
      // Siempre persistir por HTTP: el rastreo web (Tootli Directo) lee delivery_histories;
      // con solo WebSocket la ubicación puede no llegar a BD si Reverb no procesa el evento.
      await profileServiceInterface.recordLocation(_recordLocation!);
    } catch (e) {
      // ignore
    }
  }

  void setBackgroundNotificationActive(bool isActive) {
    _backgroundNotification = isActive;
    update();
  }

  List<OfflinePaymentMethodModel>? _offlinePaymentMethods;
  List<OfflinePaymentMethodModel>? get offlinePaymentMethods =>
      _offlinePaymentMethods;

  Future<void> getOfflinePaymentMethodList() async {
    Response response = await profileServiceInterface
        .getOfflinePaymentMethodList();
    if (response.statusCode == 200) {
      _offlinePaymentMethods = [];
      response.body.forEach(
        (method) => _offlinePaymentMethods!.add(
          OfflinePaymentMethodModel.fromJson(method),
        ),
      );
    }
    update();
  }

  Future<ResponseModel> makeOfflinePayment(Map<String, String> data) async {
    _isLoading = true;
    update();
    ResponseModel responseModel = await profileServiceInterface
        .makeOfflinePayment(data);
    if (responseModel.isSuccess) {
      getProfile();
    }
    _isLoading = false;
    update();
    return responseModel;
  }
}
