// lib/utils/api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'error_handler.dart';

class ApiService {
  String get _baseUrl {
    try {
      return dotenv.env['API_BASE_URL'] ?? 'https://ctnu-backend.onrender.com/api';
    } catch (_) {
      return 'https://ctnu-backend.onrender.com/api';
    }
  }

  Future<List<dynamic>> fetchChatHistory(
    String token,
    String otherUserId,
  ) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/chats/history/$otherUserId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    } else {
      throw Exception('Failed to load chat history');
    }
  }

  Future<List<dynamic>> searchUsers(
    String token,
    String query,
  ) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/users/search?username=$query'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    } else {
      throw Exception('Failed to search users');
    }
  }

  Future<List<dynamic>> fetchRecentChats(String token) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/chats/recent'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    } else {
      throw Exception('Failed to load recent chats');
    }
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
