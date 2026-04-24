import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_snackbar_widget.dart';
import 'package:sixam_mart_delivery/features/auth/screens/profile_selfie_camera_screen.dart';

export 'package:sixam_mart_delivery/helper/profile_selfie_processing.dart'
    show ProfileSelfieProcessing;

/// Flujo de selfie de perfil: permisos + pantalla con guía + procesado (ver [ProfileSelfieProcessing]).
class ProfileSelfieComposer {
  ProfileSelfieComposer._();

  /// Abre la cámara frontal con marco guía, segmenta y devuelve un JPEG listo para subir.
  static Future<XFile?> pickComposedProfileSelfie() async {
    if (kIsWeb) {
      showCustomSnackBar('profile_selfie_mobile_only'.tr, isError: true);
      return null;
    }
    if (!Platform.isAndroid && !Platform.isIOS) {
      showCustomSnackBar('profile_selfie_mobile_only'.tr, isError: true);
      return null;
    }

    final cam = await Permission.camera.request();
    if (!cam.isGranted) {
      showCustomSnackBar('profile_selfie_camera_denied'.tr, isError: true);
      return null;
    }

    // Deja que el frame de permisos / navegación cierre antes del plugin de cámara (iOS Pigeon).
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final XFile? composed = await Get.to<XFile?>(
      () => const ProfileSelfieCameraScreen(),
      fullscreenDialog: true,
      transition: Transition.fadeIn,
    );
    return composed;
  }
}
