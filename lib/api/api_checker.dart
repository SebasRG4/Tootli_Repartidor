import 'package:sixam_mart_delivery/common/models/error_response.dart';
import 'package:sixam_mart_delivery/features/auth/controllers/auth_controller.dart';
import 'package:sixam_mart_delivery/features/profile/controllers/profile_controller.dart';
import 'package:sixam_mart_delivery/helper/route_helper.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_snackbar_widget.dart';
import 'package:get/get.dart';

class ApiChecker {
  static void checkApi(Response response) {
    if(response.statusCode == 401) {
      Get.find<AuthController>().clearSharedData();
      Get.find<ProfileController>().stopLocationRecord();
      Get.offAllNamed(RouteHelper.getSignInRoute());
    }else {
      if (response.statusCode == 403 &&
          response.body != null &&
          response.body is Map) {
        try {
          final err = ErrorResponse.fromJson(response.body);
          final String? code = err.errors?.isNotEmpty == true ? err.errors!.first.code : null;
          if (code == 'registration-pending') {
            return;
          }
        } catch (_) {}
      }
      showCustomSnackBar(response.statusText);
    }
  }
}