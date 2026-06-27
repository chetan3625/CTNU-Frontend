// lib/providers/auth_provider.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class AuthProvider extends ChangeNotifier {
  String? _token;
  String? _username;
  IO.Socket? _socket;

  String? get token => _token;
  String? get username => _username;
  IO.Socket? get socket => _socket;

  bool get isAuthenticated => _token != null;

  final String _baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:5000/api';

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
    final data = jsonDecode(resp.body);
    _token = data['token'];
    _username = data['user']['username'];
    _connectSocket();
    notifyListeners();
  }

  Future<void> login(String username, String password) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );
    final data = jsonDecode(resp.body);
    _token = data['token'];
    _username = data['user']['username'];
    _connectSocket();
    notifyListeners();
  }

  void logout() {
    _token = null;
    _username = null;
    _socket?.dispose();
    _socket = null;
    notifyListeners();
  }

  void _connectSocket() {
    if (_token == null) return;
    _socket = IO.io(
      dotenv.env['SOCKET_URL'] ?? 'http://localhost:5000',
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setExtraHeaders({'Authorization': 'Bearer $_token'})
          .build(),
    );
    _socket!.auth = {'token': _token};
    _socket!.connect();
    _socket!.onConnect((_) => debugPrint('Socket connected'));
    _socket!.onDisconnect((_) => debugPrint('Socket disconnected'));
  }
}
