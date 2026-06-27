// lib/providers/auth_provider.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;

class AuthProvider extends ChangeNotifier {
  String? _token;
  String? _userId;
  String? _username;
  socket_io.Socket? _socket;

  String? get token => _token;
  String? get userId => _userId;
  String? get username => _username;
  socket_io.Socket? get socket => _socket;

  bool get isAuthenticated => _token != null;

  String get _baseUrl {
    try {
      return dotenv.env['API_BASE_URL'] ?? 'https://ctnu-backend.onrender.com/api';
    } catch (_) {
      return 'https://ctnu-backend.onrender.com/api';
    }
  }

  String get _socketUrl {
    try {
      return dotenv.env['SOCKET_URL'] ?? 'https://ctnu-backend.onrender.com';
    } catch (_) {
      return 'https://ctnu-backend.onrender.com';
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

    _token = data['token'];
    _userId = data['user']['id'];
    _username = data['user']['username'];
    _connectSocket();
    notifyListeners();
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

    _token = data['token'];
    _userId = data['user']['id'];
    _username = data['user']['username'];
    _connectSocket();
    notifyListeners();
  }

  void logout() {
    _token = null;
    _userId = null;
    _username = null;
    _socket?.dispose();
    _socket = null;
    notifyListeners();
  }

  void _connectSocket() {
    if (_token == null) return;
    _socket = socket_io.io(
      _socketUrl,
      socket_io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': _token})
          .disableAutoConnect()
          .build(),
    );
    _socket!.connect();
    _socket!.onConnect((_) => debugPrint('Socket connected'));
    _socket!.onDisconnect((_) => debugPrint('Socket disconnected'));
    _socket!.onConnectError((err) => debugPrint('Socket connect error: $err'));
    _socket!.onError((err) => debugPrint('Socket error: $err'));
  }
}
