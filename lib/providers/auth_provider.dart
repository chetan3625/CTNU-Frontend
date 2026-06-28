// lib/providers/auth_provider.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../utils/socket_config.dart';

class AuthProvider extends ChangeNotifier {
  String? _token;
  String? _userId;
  String? _username;
  socket_io.Socket? _socket;
  bool _isSocketConnected = false;

  String? get token => _token;
  String? get userId => _userId;
  String? get username => _username;
  socket_io.Socket? get socket => _socket;
  bool get isSocketConnected => _isSocketConnected;

  bool get isAuthenticated => _token != null;

  String get _baseUrl {
    try {
      return dotenv.env['API_BASE_URL'] ?? 'https://ctnu-backend.onrender.com/api';
    } catch (_) {
      return 'https://ctnu-backend.onrender.com/api';
    }
  }

  Future<void> tryAutoLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!prefs.containsKey('token')) return;

      _token = prefs.getString('token');
      _userId = prefs.getString('userId');
      _username = prefs.getString('username');

      if (_token != null) {
        _connectSocket();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error during auto login: $e');
    }
  }

  Future<void> register(String username, String email, String password) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
      }),
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Registration failed: ${resp.body}');
    }

    final data = jsonDecode(resp.body);
    if (data['token'] == null || data['user'] == null) {
      throw Exception('Registration response was invalid.');
    }

    await _persistSession(
      data['token'] as String,
      data['user']['id'].toString(),
      data['user']['username'] as String,
    );
  }

  Future<void> login(String username, String password) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Login failed: ${resp.body}');
    }

    final data = jsonDecode(resp.body);
    if (data['token'] == null || data['user'] == null) {
      throw Exception('Login response was invalid.');
    }

    await _persistSession(
      data['token'] as String,
      data['user']['id'].toString(),
      data['user']['username'] as String,
    );
  }

  Future<void> _persistSession(String token, String userId, String username) async {
    _token = token;
    _userId = userId;
    _username = username;
    _connectSocket();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);
      await prefs.setString('userId', userId);
      await prefs.setString('username', username);
    } catch (e) {
      debugPrint('Failed to save auth to shared preferences: $e');
    }

    notifyListeners();
  }

  void logout() async {
    _disconnectSocket();
    _token = null;
    _userId = null;
    _username = null;

    if (!kIsWeb) {
      try {
        FlutterBackgroundService().invoke('disconnect');
      } catch (_) {}
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token');
      await prefs.remove('userId');
      await prefs.remove('username');
    } catch (e) {
      debugPrint('Failed to clear auth from shared preferences: $e');
    }

    notifyListeners();
  }

  void connectSocket() {
    if (_token == null) return;
    if (_socket == null) {
      _connectSocket();
    } else if (!_socket!.connected) {
      debugPrint('AuthProvider: Reconnecting socket...');
      _socket!.connect();
    }
  }

  /// Fully tears down the socket so auto-reconnect cannot keep the user online.
  void disconnectSocket() {
    if (_socket == null) return;
    debugPrint('AuthProvider: Disconnecting socket');
    _disconnectSocket();
    notifyListeners();
  }

  void _disconnectSocket() {
    _isSocketConnected = false;
    _socket?.clearListeners();
    _socket?.dispose();
    _socket = null;
  }

  void _connectSocket() {
    if (_token == null) return;

    _disconnectSocket();
    _socket = SocketConfig.create(_token!);

    _socket!.onConnect((_) {
      debugPrint('AuthProvider: Socket connected');
      _isSocketConnected = true;
      notifyListeners();
    });

    _socket!.onDisconnect((_) {
      debugPrint('AuthProvider: Socket disconnected');
      _isSocketConnected = false;
      notifyListeners();
    });

    _socket!.onReconnect((_) {
      debugPrint('AuthProvider: Socket reconnected');
      _isSocketConnected = true;
      notifyListeners();
    });

    _socket!.onConnectError((err) {
      debugPrint('AuthProvider: Socket connect error: $err');
      _isSocketConnected = false;
    });

    _socket!.onError((err) => debugPrint('AuthProvider: Socket error: $err'));

    _socket!.connect();
  }
}
