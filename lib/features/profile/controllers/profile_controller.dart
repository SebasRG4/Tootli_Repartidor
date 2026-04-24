import 'dart:async';
import 'package:sixam_mart_delivery/common/models/response_model.dart';
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
import 'package:sixam_mart_delivery/helper/profile_selfie_composer.dart';

class ProfileController extends GetxController implements GetxService {
  final ProfileServiceInterface profileServiceInterface;
  ProfileController({required this.profileServiceInterface});

  ProfileModel? _profileModel;
  ProfileModel? get profileModel => _profileModel;

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
      if (_profileModel!.active == 1) {
        profileServiceInterface.checkPermission(() => startLocationRecord());
      } else {
        stopLocationRecord();
        profileServiceInterface.checkPermission(() => startMapLocationWhileInactive());
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
    _pickedFile = await ProfileSelfieComposer.pickComposedProfileSelfie();
    update();
  }

  void initData() {
    _pickedFile = null;
  }

  Future<bool> updateActiveStatus({bool back = true}) async {
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
      } else {
        stopLocationRecord();
        profileServiceInterface.checkPermission(() => startMapLocationWhileInactive());
      }
    } else {
      if (isPendingRegistrationDashboard) {
        showCustomSnackBar('registration_in_progress_title'.tr, isError: false);
      } else {
        showCustomSnackBar(responseModel.message, isError: true);
      }
    }
    update();
    return responseModel.isSuccess;
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

      if (Get.find<SplashController>().configModel!.webSocketStatus!) {
        await profileServiceInterface.recordWebSocketLocation(_recordLocation!);
      } else {
        await profileServiceInterface.recordLocation(_recordLocation!);
      }
    } catch (e) {
      // ignore
    }
  }

  void setBackgroundNotificationActive(bool isActive) {
    _backgroundNotification = isActive;
    update();
  }
}
