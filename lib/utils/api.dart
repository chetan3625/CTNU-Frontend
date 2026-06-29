// lib/utils/api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'error_handler.dart';
import 'token_service.dart';

typedef AccessTokenResolver = Future<String?> Function();
typedef RefreshSessionHandler = Future<bool> Function();

class ApiService {
  static AccessTokenResolver? _globalAccessTokenResolver;
  static RefreshSessionHandler? _globalRefreshSessionHandler;

  AccessTokenResolver? resolveAccessToken;
  RefreshSessionHandler? refreshSession;

  ApiService({
    this.resolveAccessToken,
    this.refreshSession,
  });

  static void configureAuth({
    required AccessTokenResolver accessTokenResolver,
    required RefreshSessionHandler refreshSession,
  }) {
    _globalAccessTokenResolver = accessTokenResolver;
    _globalRefreshSessionHandler = refreshSession;
  }

  AccessTokenResolver? get _tokenResolver =>
      resolveAccessToken ?? _globalAccessTokenResolver;

  RefreshSessionHandler? get _refreshHandler =>
      refreshSession ?? _globalRefreshSessionHandler;

  String get _baseUrl {
    try {
      return dotenv.env['API_BASE_URL'] ?? 'https://ctnu-backend.onrender.com/api';
    } catch (_) {
      return 'https://ctnu-backend.onrender.com/api';
    }
  }

  Future<String> _requireAccessToken([String? token]) async {
    if (token != null && !TokenService.isAccessTokenExpired(token)) {
      return token;
    }

    final resolved = await _tokenResolver?.call();
    if (resolved != null && !TokenService.isAccessTokenExpired(resolved)) {
      return resolved;
    }

    final refreshed = await TokenService.getValidAccessToken();
    if (refreshed != null) return refreshed;

    throw Exception('Not authenticated');
  }

  Future<http.Response> _authorizedGet(String path, {String? token}) async {
    var accessToken = await _requireAccessToken(token);
    var response = await http.get(
      Uri.parse('$_baseUrl$path'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 401 || response.statusCode == 403) {
      final didRefresh = await _refreshHandler?.call() ?? false;
      if (didRefresh) {
        accessToken = await _requireAccessToken();
        response = await http.get(
          Uri.parse('$_baseUrl$path'),
          headers: {'Authorization': 'Bearer $accessToken'},
        );
      }
    }

    return response;
  }

  Future<List<dynamic>> fetchChatHistory(
    String token,
    String otherUserId,
  ) async {
    final response = await _authorizedGet('/chats/history/$otherUserId', token: token);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    throw Exception('Failed to load chat history');
  }

  Future<List<dynamic>> searchUsers(
    String token,
    String query,
  ) async {
    final response = await _authorizedGet(
      '/users/search?username=$query',
      token: token,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    throw Exception('Failed to search users');
  }

  Future<List<dynamic>> fetchRecentChats(String token) async {
    final response = await _authorizedGet('/chats/recent', token: token);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    throw Exception('Failed to load recent chats');
  }

  Future<void> runWithErrorHandling(
    BuildContext context,
    Future<void> Function() request,
  ) async {
    try {
      await request();
    } catch (error) {
      if (!context.mounted) return;
      AppErrorHandler.showError(
        context,
        error,
        fallbackMessage: 'Request failed.',
      );
    }
  }
}
