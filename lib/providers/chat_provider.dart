// lib/providers/chat_provider.dart
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import '../models/message.dart';
import '../utils/api.dart';

class ChatProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String? _activeChatUserId;
  socket_io.Socket? _socket;

  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get activeChatUserId => _activeChatUserId;

  void initializeSocketListener(socket_io.Socket? socket, String currentUserId) {
    if (_socket == socket) return;
    
    // Clean up previous listeners if any
    _socket?.off('private_message');
    
    _socket = socket;
    if (_socket == null) return;

    _socket!.on('private_message', (data) {
      final msg = ChatMessage.fromJson(data as Map<String, dynamic>);
      
      // If the message is relevant to the active chat session (either sent or received)
      if (_activeChatUserId != null &&
          ((msg.from == _activeChatUserId && msg.to == currentUserId) ||
           (msg.from == currentUserId && msg.to == _activeChatUserId))) {
        _messages.add(msg);
        notifyListeners();
      }
    });
  }

  Future<void> loadChatHistory(String token, String otherUserId) async {
    _activeChatUserId = otherUserId;
    _isLoading = true;
    _messages = [];
    notifyListeners();

    try {
      final rawMsgs = await _apiService.fetchChatHistory(token, otherUserId);
      _messages = rawMsgs
          .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error loading chat history: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void sendMessage(String content, String toUserId) {
    if (_socket == null || !_socket!.connected) {
      throw Exception('Socket is not connected. Can\'t send message.');
    }
    
    _socket!.emit('private_message', {
      'to': toUserId,
      'content': content,
    });
  }

  void clearActiveChat() {
    _activeChatUserId = null;
    _messages = [];
    notifyListeners();
  }

  @override
  void dispose() {
    _socket?.off('private_message');
    super.dispose();
  }
}
