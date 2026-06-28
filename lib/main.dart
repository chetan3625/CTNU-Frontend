// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'pages/auth_page.dart';
import 'pages/home_page.dart';
import 'pages/chat_page.dart';
import 'pages/calculator_page.dart';
import 'utils/api.dart';
import 'utils/background_service.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter/foundation.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) return true;

      final apiService = ApiService();
      final recentChats = await apiService.fetchRecentChats(token);
      
      int totalUnread = 0;
      List<String> unreadSenders = [];
      for (final chat in recentChats) {
        final unreadCount = chat['unreadCount'] as int? ?? 0;
        if (unreadCount > 0) {
          totalUnread += unreadCount;
          unreadSenders.add(chat['username'] as String? ?? 'Unknown');
        }
      }

      final lastTotalUnread = prefs.getInt('last_total_unread') ?? 0;
      if (totalUnread > lastTotalUnread) {
        final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
        const initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/launcher_icon');
        const initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
        
        await flutterLocalNotificationsPlugin.initialize(initializationSettings);

        const androidPlatformChannelSpecifics = AndroidNotificationDetails(
          'chetanu_chat_channel',
          'Chat Notifications',
          channelDescription: 'Notifications for new unread chat messages',
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'ticker',
        );
        const platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);

        String body = '';
        if (unreadSenders.length == 1) {
          body = 'New message from ${unreadSenders.first}';
        } else {
          body = 'New messages from ${unreadSenders.join(', ')}';
        }

        await flutterLocalNotificationsPlugin.show(
          0,
          'Chetanu Chat',
          body,
          platformChannelSpecifics,
        );
      }
      await prefs.setInt('last_total_unread', totalUnread);
    } catch (e) {
      debugPrint('Error in Workmanager background task: $e');
    }
    return true;
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    debugPrint('No .env file found; continuing with defaults.');
  }

  if (!kIsWeb) {
    // Initialize Background Service
    try {
      await initializeBackgroundService();
      
      // Request permission for local notifications on Android 13+
      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('Failed to initialize background service or request permissions: $e');
    }

    // Initialize Workmanager background synchronization
    try {
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: false,
      );
      await Workmanager().registerPeriodicTask(
        "chetanu_bg_sync",
        "fetch_unread_messages",
        frequency: const Duration(minutes: 15),
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
      );
    } catch (e) {
      debugPrint('Failed to initialize Workmanager: $e');
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, ChatProvider>(
          create: (_) => ChatProvider(),
          update: (_, auth, chat) {
            chat!.updateToken(auth.token);
            if (auth.isAuthenticated && auth.socket != null && auth.userId != null) {
              chat.initializeSocketListener(auth.socket, auth.userId!);
            }
            return chat;
          },
        ),
      ],
      child: LifecycleObserver(
        child: MaterialApp(
          title: 'Chetanu',
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF6C63FF),
              secondary: Color(0xFF03DAC6),
              surface: Color(0xFF121212),
            ),
            scaffoldBackgroundColor: const Color(0xFF121212),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF1F1F1F),
              elevation: 0,
              centerTitle: true,
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFF2A2A2A),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF333333)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 1.5),
              ),
              labelStyle: const TextStyle(color: Colors.white70),
              floatingLabelStyle: const TextStyle(color: Color(0xFF6C63FF)),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          initialRoute: '/',
          routes: {
            '/': (context) => const CalculatorPage(),
            '/auth_gate': (context) => const AuthGate(),
            '/home': (context) => const HomePage(),
            '/chat': (context) => const ChatPage(),
          },
        ),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.tryAutoLogin();
    if (mounted) {
      setState(() {
        _checked = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final auth = Provider.of<AuthProvider>(context);
    if (auth.isAuthenticated) {
      return const HomePage();
    } else {
      return const AuthPage();
    }
  }
}

class LifecycleObserver extends StatefulWidget {
  final Widget child;
  const LifecycleObserver({super.key, required this.child});

  @override
  State<LifecycleObserver> createState() => _LifecycleObserverState();
}

class _LifecycleObserverState extends State<LifecycleObserver> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateLifecycle(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isForeground = state == AppLifecycleState.resumed;
    _updateLifecycle(isForeground);
  }

  void _updateLifecycle(bool isForeground) {
    if (kIsWeb) return;
    try {
      FlutterBackgroundService().invoke('setAppLifecycle', {'isForeground': isForeground});
    } catch (e) {
      debugPrint('Failed to send lifecycle to background service: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
