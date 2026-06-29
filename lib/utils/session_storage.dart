import 'package:shared_preferences/shared_preferences.dart';

class StoredSession {
  final String? accessToken;
  final String? refreshToken;
  final String? userId;
  final String? username;

  const StoredSession({
    this.accessToken,
    this.refreshToken,
    this.userId,
    this.username,
  });

  bool get hasRefreshToken => refreshToken != null && refreshToken!.isNotEmpty;
  bool get hasAccessToken => accessToken != null && accessToken!.isNotEmpty;
}

class SessionStorage {
  static const accessTokenKey = 'token';
  static const refreshTokenKey = 'refreshToken';
  static const userIdKey = 'userId';
  static const usernameKey = 'username';

  static Future<StoredSession> load() async {
    final prefs = await SharedPreferences.getInstance();
    return StoredSession(
      accessToken: prefs.getString(accessTokenKey),
      refreshToken: prefs.getString(refreshTokenKey),
      userId: prefs.getString(userIdKey),
      username: prefs.getString(usernameKey),
    );
  }

  static Future<void> save({
    required String accessToken,
    required String refreshToken,
    required String userId,
    required String username,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(accessTokenKey, accessToken);
    await prefs.setString(refreshTokenKey, refreshToken);
    await prefs.setString(userIdKey, userId);
    await prefs.setString(usernameKey, username);
  }

  static Future<void> updateAccessToken(String accessToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(accessTokenKey, accessToken);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(accessTokenKey);
    await prefs.remove(refreshTokenKey);
    await prefs.remove(userIdKey);
    await prefs.remove(usernameKey);
  }
}
