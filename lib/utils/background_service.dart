import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import 'package:flutter_dotenv/flutter_dotenv.dart';

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  try {
    const initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    debugPrint('Background Service: Notifications initialized successfully');
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

  bool isAppInForeground = false;
  String? activeChatUserId;

  service.on('setAppLifecycle').listen((event) {
    if (event != null) {
      isAppInForeground = event['isForeground'] as bool? ?? false;
      debugPrint('Background Service: isAppInForeground updated to $isAppInForeground');
    }
  });

  service.on('setActiveChat').listen((event) {
    if (event != null) {
      activeChatUserId = event['userId'] as String?;
      debugPrint('Background Service: activeChatUserId updated to $activeChatUserId');
    }
  });

  socket_io.Socket? socket;

  void connectSocket(String token, String socketUrl) {
    if (socket != null && socket!.connected) {
      debugPrint('Background Socket is already connected');
      return;
    }
    
    debugPrint('Background Service: Connecting socket...');
    socket = socket_io.io(
      socketUrl,
      socket_io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .build(),
    );
    
    socket!.connect();

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
      debugPrint('Background Service: Received private message: $data');
      if (data == null) return;
      
      final from = data['from'] as String?;
      
      // Load current user's ID to avoid notifying for outgoing messages
      final prefs = await SharedPreferences.getInstance();
      final currentUserId = prefs.getString('userId');

      if (from != null && from != currentUserId) {
        bool shouldNotify = true;
        
        // If app is in foreground and active chat is the sender, do not notify
        if (isAppInForeground && activeChatUserId == from) {
          shouldNotify = false;
          debugPrint('Background Service: Muting notification because chat with $from is open in foreground');
        }
        
        if (shouldNotify) {
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
            1001, // Notification ID
            'You Have new Calculations.', // Custom requested text
            'Tap to check the update',
            platformDetails,
          );
          debugPrint('Background Service: Showed notification: You Have new Calculations.');
        }
      }
    });
  }

  // Load environment variables and initial connection
  try {
    String socketUrl = 'https://ctnu-backend.onrender.com';
    try {
      await dotenv.load(fileName: '.env');
      if (dotenv.isInitialized) {
        socketUrl = dotenv.env['SOCKET_URL'] ?? 'https://ctnu-backend.onrender.com';
      }
    } catch (_) {}
    
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    
    if (token != null) {
      connectSocket(token, socketUrl);
    }

    service.on('connect').listen((event) async {
      final freshPrefs = await SharedPreferences.getInstance();
      final freshToken = freshPrefs.getString('token');
      if (freshToken != null) {
        connectSocket(freshToken, socketUrl);
      }
    });

    service.on('disconnect').listen((event) {
      debugPrint('Background Service: Disconnecting socket on request');
      socket?.disconnect();
      socket = null;
    });

    // periodic check to keep socket alive if disconnected
    Timer.periodic(const Duration(seconds: 30), (timer) async {
      final freshPrefs = await SharedPreferences.getInstance();
      final freshToken = freshPrefs.getString('token');
      if (freshToken == null) {
        if (socket != null) {
          debugPrint('Background Service: Logging out background socket');
          socket?.disconnect();
          socket = null;
        }
      } else {
        if (socket == null || !socket!.connected) {
          connectSocket(freshToken, socketUrl);
        }
      }
    });

  } catch (e, stack) {
    debugPrint('Background Service error in initialization: $e');
    debugPrint(stack.toString());
  }
}

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();
  
  // Create notifications channel for foreground service on Android
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'chetanu_bg_service_channel', // id
    'Calculator Background Service', // title
    description: 'Keeps calculator sync service active', // description
    importance: Importance.low, // low importance so it is quiet
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

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
