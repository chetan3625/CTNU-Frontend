// lib/utils/api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiService {
  final String _baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:5000/api';

  Future<List<dynamic>> fetchChatHistory(String token, String otherUserId) async {
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
}
