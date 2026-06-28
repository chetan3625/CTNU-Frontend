// lib/providers/chat_provider.dart
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter/foundation.dart';
import '../models/message.dart';
import '../utils/api.dart';

class ChatProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  List<ChatMessage> _messages = [];
  List<dynamic> _recentChats = [];
  bool _isLoading = false;
  bool _isLoadingRecent = false;
  String? _activeChatUserId;
  socket_io.Socket? _socket;
  String? _token;
  bool _isOtherUserTyping = false;
  bool _isActiveUserOnline = false;
  DateTime? _activeUserLastSeen;

  List<ChatMessage> get messages => _messages;
  List<dynamic> get recentChats => _recentChats;
  bool get isLoading => _isLoading;
  bool get isLoadingRecent => _isLoadingRecent;
  String? get activeChatUserId => _activeChatUserId;
  bool get isOtherUserTyping => _isOtherUserTyping;
  bool get isActiveUserOnline => _isActiveUserOnline;
  DateTime? get activeUserLastSeen => _activeUserLastSeen;

  void updateToken(String? token) {
    _token = token;
  }

  Future<void> loadRecentChats() async {
    if (_token == null) return;
    _isLoadingRecent = true;
    notifyListeners();
    try {
      _recentChats = await _apiService.fetchRecentChats(_token!);
    } catch (e) {
      debugPrint('Error loading recent chats: $e');
    } finally {
      _isLoadingRecent = false;
      notifyListeners();
    }
  }

  void initializeSocketListener(socket_io.Socket? socket, String currentUserId) {
    if (_socket == socket) return;
    
    // Clean up previous listeners
    _socket?.off('private_message');
    _socket?.off('typing');
    _socket?.off('user_status');
    
    _socket = socket;
    if (_socket == null) return;

    _socket!.on('user_status', (data) {
      final statusUserId = data['userId'] as String;
      final isOnline = data['isOnline'] as bool;
      final lastSeenStr = data['lastSeen'] as String?;
      
      // Update recent chats list status in real-time
      for (int i = 0; i < _recentChats.length; i++) {
        if (_recentChats[i]['_id'] == statusUserId) {
          _recentChats[i]['isOnline'] = isOnline;
          if (lastSeenStr != null) {
            _recentChats[i]['lastSeen'] = lastSeenStr;
          }
          break;
        }
      }

      if (_activeChatUserId == statusUserId) {
        _isActiveUserOnline = isOnline;
        if (lastSeenStr != null) {
          _activeUserLastSeen = DateTime.tryParse(lastSeenStr);
        }
        notifyListeners();
      } else {
        notifyListeners();
      }
    });

    _socket!.on('private_message', (data) {
      final msg = ChatMessage.fromJson(data as Map<String, dynamic>);
      
      // If the message is relevant to the active chat session
      if (_activeChatUserId != null &&
          ((msg.from == _activeChatUserId && msg.to == currentUserId) ||
           (msg.from == currentUserId && msg.to == _activeChatUserId))) {
        _messages.add(msg);
        
        // If we received a message in the active chat, mark it as read on the backend
        if (msg.from == _activeChatUserId) {
          _socket!.emit('mark_as_read', {
            'messageId': msg.id,
            'from': msg.from,
          });
        }
        notifyListeners();
      } else {
        // Increment unread count in recent chats
        bool found = false;
        for (int i = 0; i < _recentChats.length; i++) {
          if (_recentChats[i]['_id'] == msg.from) {
            _recentChats[i]['unreadCount'] = (_recentChats[i]['unreadCount'] ?? 0) + 1;
            // Bubble to the top of the list
            final chat = _recentChats.removeAt(i);
            _recentChats.insert(0, chat);
            found = true;
            break;
          }
        }
        if (!found) {
          // If the user isn't in our recent list, refresh the list
          loadRecentChats();
        } else {
          notifyListeners();
        }
      }
    });

    _socket!.on('typing', (data) {
      final fromId = data['from'] as String;
      final isTyping = data['isTyping'] as bool;
      if (_activeChatUserId == fromId) {
        _isOtherUserTyping = isTyping;
        notifyListeners();
      }
    });
  }

  Future<void> loadChatHistory(String token, String otherUserId) async {
    _activeChatUserId = otherUserId;
    if (!kIsWeb) {
      try {
        FlutterBackgroundService().invoke('setActiveChat', {'userId': otherUserId});
      } catch (_) {}
    }
    _isOtherUserTyping = false;
    _isActiveUserOnline = false;
    _activeUserLastSeen = null;

    // Load initial online/last seen status from recent chats list cache if present
    for (final chat in _recentChats) {
      if (chat['_id'] == otherUserId) {
        _isActiveUserOnline = chat['isOnline'] as bool? ?? false;
        final lastSeenStr = chat['lastSeen'] as String?;
        if (lastSeenStr != null) {
          _activeUserLastSeen = DateTime.tryParse(lastSeenStr);
        }
        break;
      }
    }

    // Request fresh status from socket
    if (_socket != null && _socket!.connected) {
      _socket!.emit('get_user_status', {'userId': otherUserId});
    }

    _isLoading = true;
    _messages = [];
    notifyListeners();

    try {
      final rawMsgs = await _apiService.fetchChatHistory(token, otherUserId);
      _messages = rawMsgs
          .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
          .toList();
      
      // Since history marked all messages as read, clear unread count for this user in recent list
      for (int i = 0; i < _recentChats.length; i++) {
        if (_recentChats[i]['_id'] == otherUserId) {
          _recentChats[i]['unreadCount'] = 0;
          break;
        }
      }
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
    if (!kIsWeb) {
      try {
        FlutterBackgroundService().invoke('setActiveChat', {'userId': null});
      } catch (_) {}
    }
    _isOtherUserTyping = false;
    _isActiveUserOnline = false;
    _activeUserLastSeen = null;
    _messages = [];
    notifyListeners();
  }

  @override
  void dispose() {
    _socket?.off('private_message');
    _socket?.off('typing');
    _socket?.off('user_status');
    super.dispose();
  }
}
