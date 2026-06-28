import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  try {
    const initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  } catch (e, stack) {
    debugPrint('Background Service: Notification initialization error: $e');
    debugPrint(stack.toString());
  }

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // Tracks whether the UI is visible — used only to suppress duplicate notifications.
  bool isAppInForeground = true;
  String? activeChatUserId;

  service.on('setAppLifecycle').listen((event) {
    if (event == null) return;
    isAppInForeground = event['isForeground'] as bool? ?? true;
    debugPrint('Background Service: isAppInForeground=$isAppInForeground');
  });

  service.on('setActiveChat').listen((event) {
    if (event == null) return;
    activeChatUserId = event['userId'] as String?;
    debugPrint('Background Service: activeChatUserId=$activeChatUserId');
  });

  // No socket here — a background socket was keeping users falsely "online".
  // Chat presence is owned exclusively by the foreground app socket.
  // Unread notifications when the app is closed are handled by Workmanager.
}

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'chetanu_bg_service_channel',
    'Calculator Background Service',
    description: 'Keeps calculator sync service active',
    importance: Importance.low,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  const AndroidNotificationChannel chatChannel = AndroidNotificationChannel(
    'chetanu_chat_channel',
    'Chat Notifications',
    description: 'Notifications for new unread chat messages',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(chatChannel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'chetanu_bg_service_channel',
      initialNotificationTitle: 'Calculator Service',
      initialNotificationContent: 'Sync active',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: (ServiceInstance service) {
        return true;
      },
    ),
  );

  await service.startService();
}
