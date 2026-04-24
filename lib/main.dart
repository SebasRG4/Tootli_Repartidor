import 'dart:async';
import 'package:flutter/services.dart';
import 'package:sixam_mart_delivery/features/auth/controllers/auth_controller.dart';
import 'package:sixam_mart_delivery/features/language/controllers/language_controller.dart';
import 'package:sixam_mart_delivery/features/splash/controllers/splash_controller.dart';
import 'package:sixam_mart_delivery/common/controllers/theme_controller.dart';
import 'package:sixam_mart_delivery/features/notification/domain/models/notification_body_model.dart';
import 'package:sixam_mart_delivery/helper/notification_helper.dart';
import 'package:sixam_mart_delivery/helper/route_helper.dart';
import 'package:sixam_mart_delivery/theme/dark_theme.dart';
import 'package:sixam_mart_delivery/theme/light_theme.dart';
import 'package:sixam_mart_delivery/util/app_constants.dart';
import 'package:sixam_mart_delivery/util/messages.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'helper/get_di.dart' as di;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();

  if (GetPlatform.isAndroid) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyA-o6RpcHXEHwHyKECCTDjKL0trpZEMqhw",
        appId: "1:475625875675:android:f834bb6f2e87e95e8cc4fe",
        messagingSenderId: "475625875675",
        projectId: "tootli-74a7c",
      ),
    );
  } else {
    await Firebase.initializeApp();
  }

  Map<String, Map<String, String>> languages = await di.init();

  NotificationBodyModel? body;
  try {
    if (GetPlatform.isMobile) {
      final RemoteMessage? remoteMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (remoteMessage != null) {
        body = NotificationHelper.convertNotification(remoteMessage.data);
      }

      // IMPORTANTE: Solicitar permisos antes de inicializar para asegurar que el token se genere correctamente.
      await FirebaseMessaging.instance.requestPermission(
        alert: true, announcement: false, badge: true, carPlay: false,
        criticalAlert: false, provisional: false, sound: true,
      );

      await NotificationHelper.initialize(flutterLocalNotificationsPlugin);
      FirebaseMessaging.onBackgroundMessage(myBackgroundMessageHandler);

      // Asegurar que el FCM token siempre se mantenga actualizado en backend.
      // Si Firebase rota el token, lo guardamos y notificamos al servidor
      // sin necesidad de que el repartidor cierre y vuelva a iniciar sesión.
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        debugPrint('----Device Token REFRESHED----- $newToken');
        if (Get.isRegistered<AuthController>() &&
            Get.find<AuthController>().isLoggedIn()) {
          // updateToken volverá a leer el token actual de FCM y lo mandará al backend.
          await Get.find<AuthController>().updateToken();
        }
      });
    }
  } catch (_) {}

  runApp(MyApp(languages: languages, body: body));
}

class MyApp extends StatelessWidget {
  final Map<String, Map<String, String>>? languages;
  final NotificationBodyModel? body;
  const MyApp({super.key, required this.languages, this.body});

  void _route() {
    Get.find<SplashController>().getConfigData().then((bool isSuccess) async {
      if (isSuccess) {
        if (Get.find<AuthController>().isLoggedIn()) {
          Get.find<AuthController>().updateToken();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (GetPlatform.isWeb) {
      Get.find<SplashController>().initSharedData();
      _route();
    }

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    return GetBuilder<ThemeController>(
      builder: (themeController) {
        return GetBuilder<LocalizationController>(
          builder: (localizeController) {
            return GetBuilder<SplashController>(
              builder: (splashController) {
                return (GetPlatform.isWeb &&
                        splashController.configModel == null)
                    ? const SizedBox()
                    : GetMaterialApp(
                        title: AppConstants.appName,
                        debugShowCheckedModeBanner: false,
                        navigatorKey: Get.key,
                        theme: themeController.darkTheme ? dark : light,
                        locale: localizeController.locale,
                        translations: Messages(languages: languages),
                        fallbackLocale: Locale(
                          AppConstants.languages[0].languageCode!,
                          AppConstants.languages[0].countryCode ?? 'MX',
                        ),
                        initialRoute: RouteHelper.getSplashRoute(body),
                        getPages: RouteHelper.routes,
                        defaultTransition: Transition.topLevel,
                        transitionDuration: const Duration(milliseconds: 500),
                        builder: (BuildContext context, widget) {
                          return MediaQuery(
                            data: MediaQuery.of(context).copyWith(
                              textScaler: const TextScaler.linear(1.0),
                            ),
                            child: Material(
                              child: SafeArea(
                                top: false,
                                bottom: GetPlatform.isAndroid,
                                child: Stack(children: [widget!]),
                              ),
                            ),
                          );
                        },
                      );
              },
            );
          },
        );
      },
    );
  }
}
