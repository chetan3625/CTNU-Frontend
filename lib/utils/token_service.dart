import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'session_storage.dart';

class RefreshedTokens {
  final String accessToken;
  final String refreshToken;
  final String userId;
  final String username;

  const RefreshedTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.username,
  });
}

class TokenService {
  static String get _baseUrl {
    try {
      return dotenv.env['API_BASE_URL'] ?? 'https://ctnu-backend.onrender.com/api';
    } catch (_) {
      return 'https://ctnu-backend.onrender.com/api';
    }
  }

  static bool isAccessTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;

      final normalized = base64Url.normalize(parts[1]);
      final payload = jsonDecode(utf8.decode(base64Url.decode(normalized)));
      final exp = payload['exp'];
      if (exp is! num) return false;

      final expiry = DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
      return DateTime.now().isAfter(expiry.subtract(const Duration(minutes: 1)));
    } catch (_) {
      return false;
    }
  }

  static Future<RefreshedTokens?> refreshSession(String refreshToken) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint('TokenService: refresh failed (${response.statusCode})');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final accessToken = data['accessToken'] as String? ?? data['token'] as String?;
      final newRefreshToken = data['refreshToken'] as String?;
      final user = data['user'] as Map<String, dynamic>?;

      if (accessToken == null || newRefreshToken == null || user == null) {
        return null;
      }

      final userId = user['id']?.toString();
      final username = user['username'] as String?;
      if (userId == null || username == null) return null;

      await SessionStorage.save(
        accessToken: accessToken,
        refreshToken: newRefreshToken,
        userId: userId,
        username: username,
      );

      return RefreshedTokens(
        accessToken: accessToken,
        refreshToken: newRefreshToken,
        userId: userId,
        username: username,
      );
    } catch (e) {
      debugPrint('TokenService: refresh error: $e');
      return null;
    }
  }

  static Future<String?> getValidAccessToken() async {
    final session = await SessionStorage.load();

    if (session.hasAccessToken &&
        !isAccessTokenExpired(session.accessToken!)) {
      return session.accessToken;
    }

    if (!session.hasRefreshToken) return null;

    final refreshed = await refreshSession(session.refreshToken!);
    return refreshed?.accessToken;
  }
}
