import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sixam_mart_delivery/features/auth/controllers/auth_controller.dart';
import 'package:sixam_mart_delivery/features/chat/controllers/chat_controller.dart';
import 'package:sixam_mart_delivery/features/dashboard/screens/dashboard_screen.dart';
import 'package:sixam_mart_delivery/features/notification/controllers/notification_controller.dart';
import 'package:sixam_mart_delivery/features/order/controllers/order_controller.dart';
import 'package:sixam_mart_delivery/features/notification/domain/models/notification_body_model.dart';
import 'package:sixam_mart_delivery/helper/custom_print_helper.dart';
import 'package:sixam_mart_delivery/helper/route_helper.dart';
import 'package:sixam_mart_delivery/util/app_constants.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:sixam_mart_delivery/helper/order_notification_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationHelper {
  static Future<void> initialize(
    FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin,
  ) async {
    var androidInitialize = const AndroidInitializationSettings(
      'notification_icon',
    );
    var iOSInitialize = const DarwinInitializationSettings();
    var initializationsSettings = InitializationSettings(
      android: androidInitialize,
      iOS: iOSInitialize,
    );
    flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()!
        .requestNotificationsPermission();
    flutterLocalNotificationsPlugin.initialize(
      initializationsSettings,
      onDidReceiveNotificationResponse: (load) async {
        try {
          if (load.payload!.isNotEmpty) {
            NotificationBodyModel payload = NotificationBodyModel.fromJson(
              jsonDecode(load.payload!),
            );

            final Map<NotificationType, Function> notificationActions = {
              NotificationType.order: () => Get.toNamed(
                RouteHelper.getOrderDetailsRoute(
                  payload.orderId,
                  fromNotification: true,
                ),
              ),
              NotificationType.order_request: () {
                final orderId = payload.orderId;
                if (orderId != null) {
                  OrderNotificationService.instance.notifyOrderRequest(orderId);
                }
              },
              NotificationType.block: () =>
                  Get.offAllNamed(RouteHelper.getSignInRoute()),
              NotificationType.unblock: () =>
                  Get.offAllNamed(RouteHelper.getSignInRoute()),
              NotificationType.otp: () => null,
              NotificationType.unassign: () =>
                  Get.to(const DashboardScreen(pageIndex: 1)),
              NotificationType.message: () => Get.toNamed(
                RouteHelper.getChatRoute(
                  notificationBody: payload,
                  conversationId: payload.conversationId,
                  fromNotification: true,
                ),
              ),
              NotificationType.withdraw: () =>
                  Get.toNamed(RouteHelper.getMyAccountRoute()),
              NotificationType.general: () => Get.toNamed(
                RouteHelper.getNotificationRoute(fromNotification: true),
              ),
            };

            notificationActions[payload.notificationType]?.call();
          }
        } catch (_) {}
        return;
      },
    );

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        print("onMessage message type:${message.data['type']}");
        print("onMessage message:${message.data}");
      }

      if (message.data['type'] == 'message' &&
          Get.currentRoute.startsWith(RouteHelper.chatScreen)) {
        if (Get.find<AuthController>().isLoggedIn()) {
          Get.find<ChatController>().getConversationList(1);
          if (Get.find<ChatController>().messageModel!.conversation!.id
                  .toString() ==
              message.data['conversation_id'].toString()) {
            Get.find<ChatController>().getMessages(
              1,
              NotificationBodyModel(
                notificationType: NotificationType.message,
                customerId: message.data['sender_type'] == AppConstants.user
                    ? 0
                    : null,
                vendorId: message.data['sender_type'] == AppConstants.vendor
                    ? 0
                    : null,
              ),
              null,
              int.parse(message.data['conversation_id'].toString()),
            );
          } else {
            NotificationHelper.showNotification(
              message,
              flutterLocalNotificationsPlugin,
            );
          }
        }
      } else if (message.data['type'] == 'message' &&
          Get.currentRoute.startsWith(RouteHelper.conversationListScreen)) {
        if (Get.find<AuthController>().isLoggedIn()) {
          Get.find<ChatController>().getConversationList(1);
        }
        NotificationHelper.showNotification(
          message,
          flutterLocalNotificationsPlugin,
        );
      } else if (message.data['type'] == 'otp') {
        NotificationHelper.showNotification(
          message,
          flutterLocalNotificationsPlugin,
        );
      } else if (message.data['type'] == 'deliveryman_referral') {
        NotificationHelper.showNotification(
          message,
          flutterLocalNotificationsPlugin,
        );
      } else {
        String? type = message.data['type'];

        if (type != 'assign' &&
            type != 'new_order' &&
            type != 'order_request') {
          NotificationHelper.showNotification(
            message,
            flutterLocalNotificationsPlugin,
          );
          Get.find<OrderController>().getRunningOrders(1, status: 'all');
          Get.find<OrderController>().getOrderCount(
            Get.find<OrderController>().orderType,
          );
          Get.find<OrderController>().getLatestOrders();
          Get.find<NotificationController>().getNotificationList();
        }
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) {
        print("onOpenApp message type:${message.data['type']}");
      }
      try {
        if (message.data.isNotEmpty) {
          NotificationBodyModel notificationBody = convertNotification(
            message.data,
          )!;

          final Map<NotificationType, Function> notificationActions = {
            NotificationType.order: () => Get.toNamed(
              RouteHelper.getOrderDetailsRoute(
                int.parse(message.data['order_id']),
                fromNotification: true,
              ),
            ),
            NotificationType.order_request: () {
                final orderId = int.tryParse(
                  message.data['order_id']?.toString() ?? '',
                );
                if (orderId != null) {
                  OrderNotificationService.instance.notifyOrderRequest(orderId);
                }
              },
            NotificationType.block: () =>
                Get.offAllNamed(RouteHelper.getSignInRoute()),
            NotificationType.unblock: () =>
                Get.offAllNamed(RouteHelper.getSignInRoute()),
            NotificationType.otp: () => null,
            NotificationType.unassign: () =>
                Get.to(const DashboardScreen(pageIndex: 1)),
            NotificationType.message: () => Get.toNamed(
              RouteHelper.getChatRoute(
                notificationBody: notificationBody,
                conversationId: notificationBody.conversationId,
                fromNotification: true,
              ),
            ),
            NotificationType.withdraw: () =>
                Get.toNamed(RouteHelper.getMyAccountRoute()),
            NotificationType.general: () => Get.toNamed(
              RouteHelper.getNotificationRoute(fromNotification: true),
            ),
          };

          notificationActions[notificationBody.notificationType]?.call();
        }
      } catch (_) {}
    });
  }

  static final AudioPlayer _audioPlayer = AudioPlayer();

  /// Start Persistent Location Service
  @pragma('vm:entry-point')
  static Future<ServiceRequestResult> startLocationService() async {
    if (await FlutterForegroundTask.isRunningService) {
      return FlutterForegroundTask.restartService();
    } else {
      return FlutterForegroundTask.startService(
        serviceId: 257,
        notificationTitle: 'Tootli operativo',
        notificationText: 'Rastreando ubicación en tiempo real',
        callback: locationStartCallback,
      );
    }
  }

  /// Start Foreground Service
  @pragma('vm:entry-point')
  static Future<ServiceRequestResult> startService(
    String? orderId,
    NotificationType notificationType,
  ) async {
    if (orderId != null) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('latest_order_request_id', orderId);
    }
    if (await FlutterForegroundTask.isRunningService) {
      return FlutterForegroundTask.restartService();
    } else {
      return FlutterForegroundTask.startService(
        serviceId: 256,
        notificationTitle: notificationType == NotificationType.order_request
            ? 'Order Notification'
            : 'Has sido asignado a un nuevo pedido ($orderId)',
        notificationText: notificationType == NotificationType.order_request
            ? 'Nueva solicitud de pedido.'
            : 'Abre la app para ver los detalles.',
        callback: startCallback,
      );
    }
  }

  /// Stop Foreground Service
  @pragma('vm:entry-point')
  static Future<ServiceRequestResult> stopService() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      customPrint('Audio stop error: $e');
    }
    return FlutterForegroundTask.stopService();
  }

  static Future<void> showNotification(
    RemoteMessage message,
    FlutterLocalNotificationsPlugin fln,
  ) async {
    if (!GetPlatform.isIOS) {
      String? title;
      String? body;
      String? image;
      NotificationBodyModel? notificationBody = convertNotification(
        message.data,
      );

      title = message.data['title'];
      body = message.data['body'];
      image =
          (message.data['image'] != null && message.data['image'].isNotEmpty)
          ? message.data['image'].startsWith('http')
                ? message.data['image']
                : '${AppConstants.baseUrl}/storage/app/public/notification/${message.data['image']}'
          : null;

      if (image != null && image.isNotEmpty) {
        try {
          await showBigPictureNotificationHiddenLargeIcon(
            title,
            body,
            notificationBody,
            image,
            fln,
          );
        } catch (e) {
          await showBigTextNotification(title, body!, notificationBody, fln);
        }
      } else {
        await showBigTextNotification(title, body!, notificationBody, fln);
      }
    }
  }

  static Future<void> showTextNotification(
    String title,
    String body,
    NotificationBodyModel notificationBody,
    FlutterLocalNotificationsPlugin fln,
  ) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          '6ammart',
          AppConstants.appName,
          playSound: true,
          importance: Importance.max,
          priority: Priority.max,
          sound: RawResourceAndroidNotificationSound('notification'),
        );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );
    await fln.show(
      0,
      title,
      body,
      platformChannelSpecifics,
      payload: jsonEncode(notificationBody.toJson()),
    );
  }

  static Future<void> showBigTextNotification(
    String? title,
    String body,
    NotificationBodyModel? notificationBody,
    FlutterLocalNotificationsPlugin fln,
  ) async {
    BigTextStyleInformation bigTextStyleInformation = BigTextStyleInformation(
      body,
      htmlFormatBigText: true,
      contentTitle: title,
      htmlFormatContentTitle: true,
    );
    AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          '6ammart',
          AppConstants.appName,
          importance: Importance.max,
          styleInformation: bigTextStyleInformation,
          priority: Priority.max,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound('notification'),
        );
    NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );
    await fln.show(
      0,
      title,
      body,
      platformChannelSpecifics,
      payload: notificationBody != null
          ? jsonEncode(notificationBody.toJson())
          : null,
    );
  }

  static Future<void> showBigPictureNotificationHiddenLargeIcon(
    String? title,
    String? body,
    NotificationBodyModel? notificationBody,
    String image,
    FlutterLocalNotificationsPlugin fln,
  ) async {
    final String largeIconPath = await _downloadAndSaveFile(image, 'largeIcon');
    final String bigPicturePath = await _downloadAndSaveFile(
      image,
      'bigPicture',
    );
    final BigPictureStyleInformation bigPictureStyleInformation =
        BigPictureStyleInformation(
          FilePathAndroidBitmap(bigPicturePath),
          hideExpandedLargeIcon: true,
          contentTitle: title,
          htmlFormatContentTitle: true,
          summaryText: body,
          htmlFormatSummaryText: true,
        );
    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          '6ammart',
          AppConstants.appName,
          largeIcon: FilePathAndroidBitmap(largeIconPath),
          priority: Priority.max,
          playSound: true,
          styleInformation: bigPictureStyleInformation,
          importance: Importance.max,
          sound: const RawResourceAndroidNotificationSound('notification'),
        );
    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );
    await fln.show(
      0,
      title,
      body,
      platformChannelSpecifics,
      payload: notificationBody != null
          ? jsonEncode(notificationBody.toJson())
          : null,
    );
  }

  static Future<String> _downloadAndSaveFile(
    String url,
    String fileName,
  ) async {
    final Directory directory = await getApplicationDocumentsDirectory();
    final String filePath = '${directory.path}/$fileName';
    final http.Response response = await http.get(Uri.parse(url));
    final File file = File(filePath);
    await file.writeAsBytes(response.bodyBytes);
    return filePath;
  }

  static NotificationBodyModel? convertNotification(Map<String, dynamic> data) {
    final type = data['type'];
    final orderId = data['order_id'];

    switch (type) {
      case 'cash_collect':
        return NotificationBodyModel(
          notificationType: NotificationType.general,
        );
      case 'unassign':
        return NotificationBodyModel(
          notificationType: NotificationType.unassign,
        );
      case 'order_status':
        return NotificationBodyModel(
          orderId: int.parse(orderId),
          notificationType: NotificationType.order,
        );
      case 'new_order':
      case 'order_request':
        return NotificationBodyModel(
          orderId: int.parse(orderId),
          notificationType: NotificationType.order_request,
        );
      case 'block':
        return NotificationBodyModel(notificationType: NotificationType.block);
      case 'unblock':
        return NotificationBodyModel(
          notificationType: NotificationType.unblock,
        );
      case 'otp':
        return NotificationBodyModel(notificationType: NotificationType.otp);
      case 'message':
        return _handleMessageNotification(data);
      case 'withdraw':
        return NotificationBodyModel(
          notificationType: NotificationType.withdraw,
        );
      case 'deliveryman_referral':
        return NotificationBodyModel(
          notificationType: NotificationType.general,
        );
      default:
        return NotificationBodyModel(
          notificationType: NotificationType.general,
        );
    }
  }

  static NotificationBodyModel _handleMessageNotification(
    Map<String, dynamic> data,
  ) {
    final conversationId = data['conversation_id'];
    final senderType = data['sender_type'];

    return NotificationBodyModel(
      conversationId: (conversationId != null && conversationId.isNotEmpty)
          ? int.parse(conversationId)
          : null,
      notificationType: NotificationType.message,
      type: senderType == AppConstants.user
          ? AppConstants.user
          : AppConstants.vendor,
    );
  }
}

/// Background FCM message handler
@pragma('vm:entry-point')
Future<void> myBackgroundMessageHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  customPrint("onBackground: ${message.data}");

  final notificationBody = NotificationHelper.convertNotification(message.data);

  if (notificationBody != null &&
      (notificationBody.notificationType == NotificationType.order ||
          notificationBody.notificationType ==
              NotificationType.order_request)) {
    FlutterForegroundTask.initCommunicationPort();
    await _initService();
    await NotificationHelper.startService(
      notificationBody.orderId?.toString(),
      notificationBody.notificationType!,
    );
  }
}

/// Initialize Foreground Service
@pragma('vm:entry-point')
Future<void> _initService() async {
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: '6ammart',
      channelName: 'Foreground Service Notification',
      channelDescription:
          'This notification appears when the foreground service is running.',
      onlyAlertOnce: false,
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: false,
      playSound: false,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.repeat(5000),
      autoRunOnBoot: false,
      autoRunOnMyPackageReplaced: false,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );
}

/// Foreground Service entry point
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(MyTaskHandler());
}

/// Foreground Service Task Handler
class MyTaskHandler extends TaskHandler {
  AudioPlayer? _localPlayer;

  void _playAudio() {
    _localPlayer?.play(AssetSource('alert_new_delivery.mp3'));
  }

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _localPlayer = AudioPlayer();
    _playAudio();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    _playAudio();
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _localPlayer?.dispose();
    await NotificationHelper.stopService();
  }

  @override
  void onReceiveData(Object data) {
    _playAudio();
  }

  @override
  void onNotificationButtonPressed(String id) async {
    customPrint('onNotificationButtonPressed: $id');
    if (id == '1') {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final orderIdStr = prefs.getString('latest_order_request_id');
      if (orderIdStr != null) {
        final orderId = int.tryParse(orderIdStr);
        if (orderId != null) {
          OrderNotificationService.instance.notifyOrderRequest(orderId);
        }
        await prefs.remove('latest_order_request_id');
      }
      FlutterForegroundTask.launchApp('/');
    }
    NotificationHelper.stopService();
  }

  @override
  void onNotificationPressed() async {
    customPrint('onNotificationPressed');
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final orderIdStr = prefs.getString('latest_order_request_id');
    if (orderIdStr != null) {
      final orderId = int.tryParse(orderIdStr);
      if (orderId != null) {
        OrderNotificationService.instance.notifyOrderRequest(orderId);
      }
      await prefs.remove('latest_order_request_id');
    }
    FlutterForegroundTask.launchApp('/');
    NotificationHelper.stopService();
  }

  @override
  void onNotificationDismissed() {
    FlutterForegroundTask.updateService(
      notificationTitle: 'You got a new order!',
      notificationText: 'Open app and check order details.',
    );
  }
}

@pragma('vm:entry-point')
void locationStartCallback() {
  FlutterForegroundTask.setTaskHandler(LocationTaskHandler());
}

class LocationTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {
    _recordLocation();
  }

  Future<void> _recordLocation() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString(AppConstants.token);
      if (token == null || token.isEmpty) return;

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      );

      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}${AppConstants.recordLocationUri}'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'token': token,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'location': 'Background Update',
        }),
      );

      debugPrint('Background Location update: ${response.statusCode}');
    } catch (e) {
      debugPrint('Background Location error: $e');
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}
