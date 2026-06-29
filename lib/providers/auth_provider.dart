// lib/providers/auth_provider.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import 'package:flutter_background_service/flutter_background_service.dart';
import '../utils/session_storage.dart';
import '../utils/token_service.dart';
import '../utils/socket_config.dart';

class AuthProvider extends ChangeNotifier {
  String? _token;
  String? _refreshToken;
  String? _userId;
  String? _username;
  socket_io.Socket? _socket;
  bool _isSocketConnected = false;
  bool _isRefreshing = false;

  String? get token => _token;
  String? get refreshToken => _refreshToken;
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
    if (_token != null) return;

    try {
      final session = await SessionStorage.load();
      if (!session.hasRefreshToken && !session.hasAccessToken) return;

      if (session.hasAccessToken &&
          !TokenService.isAccessTokenExpired(session.accessToken!)) {
        await _applySession(
          accessToken: session.accessToken!,
          refreshToken: session.refreshToken,
          userId: session.userId,
          username: session.username,
        );
        return;
      }

      if (!session.hasRefreshToken) {
        await SessionStorage.clear();
        return;
      }

      if (session.hasRefreshToken) {
        final refreshed = await TokenService.refreshSession(session.refreshToken!);
        if (refreshed == null) {
          await SessionStorage.clear();
          return;
        }

        await _applySession(
          accessToken: refreshed.accessToken,
          refreshToken: refreshed.refreshToken,
          userId: refreshed.userId,
          username: refreshed.username,
        );
      }
    } catch (e) {
      debugPrint('Error during auto login: $e');
    }
  }

  Future<bool> refreshAccessToken() async {
    if (_isRefreshing) return _token != null;
    if (_refreshToken == null) return false;

    _isRefreshing = true;
    try {
      final refreshed = await TokenService.refreshSession(_refreshToken!);
      if (refreshed == null) {
        await _clearSession(notify: true);
        return false;
      }

      _token = refreshed.accessToken;
      _refreshToken = refreshed.refreshToken;
      _userId = refreshed.userId;
      _username = refreshed.username;
      _connectSocket();
      notifyListeners();
      return true;
    } finally {
      _isRefreshing = false;
    }
  }

  Future<String?> getValidAccessToken() async {
    if (_token != null && !TokenService.isAccessTokenExpired(_token!)) {
      return _token;
    }
    final refreshed = await refreshAccessToken();
    return refreshed ? _token : null;
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

    await _handleAuthResponse(jsonDecode(resp.body) as Map<String, dynamic>);
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

    await _handleAuthResponse(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  Future<void> _handleAuthResponse(Map<String, dynamic> data) async {
    final accessToken = data['accessToken'] as String? ?? data['token'] as String?;
    final refreshToken = data['refreshToken'] as String?;
    final user = data['user'] as Map<String, dynamic>?;

    if (accessToken == null || user == null) {
      throw Exception('Authentication response was invalid.');
    }

    if (refreshToken == null) {
      throw Exception('Authentication response missing refresh token.');
    }

    await _persistSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      userId: user['id'].toString(),
      username: user['username'] as String,
    );
  }

  Future<void> _persistSession({
    required String accessToken,
    required String refreshToken,
    required String userId,
    required String username,
  }) async {
    try {
      await SessionStorage.save(
        accessToken: accessToken,
        refreshToken: refreshToken,
        userId: userId,
        username: username,
      );
    } catch (e) {
      debugPrint('Failed to save auth to shared preferences: $e');
      throw Exception('Could not save login session on this device.');
    }

    await _applySession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      userId: userId,
      username: username,
    );
  }

  Future<void> _applySession({
    required String accessToken,
    String? refreshToken,
    String? userId,
    String? username,
  }) async {
    _token = accessToken;
    _refreshToken = refreshToken ?? _refreshToken;
    _userId = userId ?? _userId;
    _username = username ?? _username;
    _connectSocket();

    if (!kIsWeb) {
      try {
        FlutterBackgroundService().invoke('connect');
      } catch (_) {}
    }

    notifyListeners();
  }

  void logout() async {
    final refreshToken = _refreshToken;
    await _clearSession(notify: false);

    if (refreshToken != null) {
      try {
        await http.post(
          Uri.parse('$_baseUrl/auth/logout'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refreshToken': refreshToken}),
        );
      } catch (e) {
        debugPrint('Failed to revoke refresh token: $e');
      }
    }

    notifyListeners();
  }

  Future<void> _clearSession({required bool notify}) async {
    _disconnectSocket();
    _token = null;
    _refreshToken = null;
    _userId = null;
    _username = null;

    if (!kIsWeb) {
      try {
        FlutterBackgroundService().invoke('disconnect');
      } catch (_) {}
    }

    try {
      await SessionStorage.clear();
    } catch (e) {
      debugPrint('Failed to clear auth from shared preferences: $e');
    }

    if (notify) notifyListeners();
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

  void disconnectSocket() {
    if (_socket == null) return;
    debugPrint('AuthProvider: Disconnecting socket');
    _disconnectSocket();
    notifyListeners();
  }

  void _disconnectSocket() {
    _isSocketConnected = false;
    final socket = _socket;
    _socket = null;
    if (socket == null) return;
    socket.clearListeners();
    socket.disconnect();
    socket.dispose();
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
