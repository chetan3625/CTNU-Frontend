import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import 'package:flutter_dotenv/flutter_dotenv.dart';

String _socketUrlFromEnv() {
  try {
    if (dotenv.isInitialized) {
      return dotenv.env['SOCKET_URL'] ?? 'https://ctnu-backend.onrender.com';
    }
  } catch (_) {}
  return 'https://ctnu-backend.onrender.com';
}

socket_io.Socket _createBackgroundSocket(String token, String socketUrl) {
  return socket_io.io(
    socketUrl,
    socket_io.OptionBuilder()
        .setTransports(['websocket', 'polling'])
        .enableForceNew()
        .disableAutoConnect()
        .setAuth({'token': token})
        .enableReconnection()
        .setReconnectionAttempts(999999)
        .setReconnectionDelay(500)
        .setReconnectionDelayMax(3000)
        .setTimeout(15000)
        .build(),
  );
}

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

  bool isAppInForeground = true;
  String? activeChatUserId;
  socket_io.Socket? socket;
  String? connectedToken;

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}

  final socketUrl = _socketUrlFromEnv();

  void disconnectBackgroundSocket() {
    if (socket == null) return;
    debugPrint('Background Service: Disconnecting background socket');
    socket!.clearListeners();
    socket!.disconnect();
    socket!.dispose();
    socket = null;
    connectedToken = null;
  }

  Future<void> connectBackgroundSocket() async {
    if (isAppInForeground) {
      debugPrint('Background Service: Skipping connect — app is in foreground');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      disconnectBackgroundSocket();
      return;
    }

    if (socket != null && socket!.connected && connectedToken == token) {
      return;
    }

    disconnectBackgroundSocket();
    connectedToken = token;

    debugPrint('Background Service: Connecting background socket...');
    socket = _createBackgroundSocket(token, socketUrl);

    socket!.onConnect((_) {
      debugPrint('Background Service: Socket connected');
    });

    socket!.onDisconnect((_) {
      debugPrint('Background Service: Socket disconnected');
    });

    socket!.onConnectError((err) {
      debugPrint('Background Service: Socket connect error: $err');
    });

    socket!.on('private_message', (data) async {
      if (data == null || data is! Map) return;

      final from = data['from']?.toString();
      final prefs = await SharedPreferences.getInstance();
      final currentUserId = prefs.getString('userId');

      if (from == null || from == currentUserId) return;

      if (isAppInForeground && activeChatUserId == from) {
        debugPrint('Background Service: Suppressed notification — chat is open');
        return;
      }

      const androidDetails = AndroidNotificationDetails(
        'chetanu_chat_channel',
        'Chat Notifications',
        channelDescription: 'Notifications for new unread chat messages',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'ticker',
      );
      const platformDetails = NotificationDetails(android: androidDetails);

      await flutterLocalNotificationsPlugin.show(
        1001,
        'You Have new Calculations.',
        'Tap to check the update',
        platformDetails,
      );
    });

    socket!.connect();
  }

  service.on('setAppLifecycle').listen((event) {
    if (event == null) return;
    isAppInForeground = event['isForeground'] as bool? ?? true;
    debugPrint('Background Service: isAppInForeground=$isAppInForeground');

    if (isAppInForeground) {
      disconnectBackgroundSocket();
    } else {
      connectBackgroundSocket();
    }
  });

  service.on('setActiveChat').listen((event) {
    if (event == null) return;
    activeChatUserId = event['userId'] as String?;
    debugPrint('Background Service: activeChatUserId=$activeChatUserId');
  });

  service.on('connect').listen((event) async {
    if (!isAppInForeground) {
      await connectBackgroundSocket();
    }
  });

  service.on('disconnect').listen((event) {
    disconnectBackgroundSocket();
  });

  Timer.periodic(const Duration(seconds: 20), (timer) async {
    if (isAppInForeground) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      disconnectBackgroundSocket();
      return;
    }

    if (socket == null || !socket!.connected) {
      await connectBackgroundSocket();
    }
  });
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
