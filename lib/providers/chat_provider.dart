// lib/providers/chat_provider.dart
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
  String? _currentUserId;
  bool _listenersAttached = false;
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

  String _id(dynamic value) => value?.toString() ?? '';

  DateTime? _parseLastSeen(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      return DateTime.tryParse(value)?.toLocal();
    }
    return null;
  }

  void _applyUserStatus(String statusUserId, bool isOnline, DateTime? lastSeen) {
    for (int i = 0; i < _recentChats.length; i++) {
      if (_id(_recentChats[i]['_id']) == statusUserId) {
        _recentChats[i]['isOnline'] = isOnline;
        if (lastSeen != null) {
          _recentChats[i]['lastSeen'] = lastSeen.toUtc().toIso8601String();
        }
        break;
      }
    }

    if (_activeChatUserId == statusUserId) {
      _isActiveUserOnline = isOnline;
      if (lastSeen != null || isOnline) {
        _activeUserLastSeen = isOnline ? null : (lastSeen ?? _activeUserLastSeen);
      }
    }
  }

  void _upsertRecentChatFromMessage(ChatMessage msg, {required bool incrementUnread}) {
    final otherUserId = _id(msg.from) == _currentUserId ? _id(msg.to) : _id(msg.from);
    final existingIndex = _recentChats.indexWhere(
      (chat) => _id(chat['_id']) == otherUserId,
    );

    final preview = {
      'lastMessage': msg.content,
      'lastMessageAt': msg.timestamp.toUtc().toIso8601String(),
    };

    if (existingIndex >= 0) {
      final chat = Map<String, dynamic>.from(_recentChats[existingIndex] as Map);
      chat.addAll(preview);
      if (incrementUnread) {
        chat['unreadCount'] = (chat['unreadCount'] as int? ?? 0) + 1;
      }
      _recentChats.removeAt(existingIndex);
      _recentChats.insert(0, chat);
      return;
    }

    loadRecentChats();
  }

  bool _isMessageForActiveChat(ChatMessage msg) {
    if (_activeChatUserId == null || _currentUserId == null) return false;
    final from = _id(msg.from);
    final to = _id(msg.to);
    return (from == _activeChatUserId && to == _currentUserId) ||
        (from == _currentUserId && to == _activeChatUserId);
  }

  void _addOrUpdateMessage(ChatMessage msg) {
    final existingIndex = _messages.indexWhere((m) => m.id == msg.id);
    if (existingIndex >= 0) {
      _messages[existingIndex] = msg;
      return;
    }

    final pendingIndex = _messages.indexWhere(
      (m) =>
          m.id.startsWith('pending_') &&
          m.from == msg.from &&
          m.to == msg.to &&
          m.content == msg.content,
    );
    if (pendingIndex >= 0) {
      _messages[pendingIndex] = msg;
      return;
    }

    _messages.add(msg);
  }

  void initializeSocketListener(socket_io.Socket? socket, String currentUserId) {
    if (socket == null) {
      _detachSocketListeners();
      return;
    }

    if (_socket == socket && _currentUserId == currentUserId && _listenersAttached) {
      return;
    }

    _detachSocketListeners();
    _socket = socket;
    _currentUserId = currentUserId;
    _listenersAttached = true;

    _socket!.on('connect', (_) {
      debugPrint('ChatProvider: Socket connected — syncing state');
      if (_token != null && _activeChatUserId != null) {
        _socket!.emit('get_user_status', {'userId': _activeChatUserId});
        _socket!.emit('mark_chat_read', {'otherUserId': _activeChatUserId});
        loadChatHistory(_token!, _activeChatUserId!, silent: true);
      }
      loadRecentChats();
    });

    _socket!.on('user_status', (data) {
      if (data is! Map) return;
      final statusUserId = _id(data['userId']);
      final isOnline = data['isOnline'] == true;
      final lastSeen = _parseLastSeen(data['lastSeen']);
      _applyUserStatus(statusUserId, isOnline, lastSeen);
      notifyListeners();
    });

    _socket!.on('private_message', (data) {
      if (data is! Map) return;
      final msg = ChatMessage.fromJson(Map<String, dynamic>.from(data));

      if (_isMessageForActiveChat(msg)) {
        _addOrUpdateMessage(msg);

        if (_id(msg.from) == _activeChatUserId) {
          _socket?.emit('mark_as_read', {'messageId': msg.id});
          for (int i = 0; i < _recentChats.length; i++) {
            if (_id(_recentChats[i]['_id']) == _activeChatUserId) {
              _recentChats[i]['unreadCount'] = 0;
              break;
            }
          }
        }

        notifyListeners();
        return;
      }

      final isIncoming = _id(msg.from) != _currentUserId;
      _upsertRecentChatFromMessage(msg, incrementUnread: isIncoming);
      notifyListeners();
    });

    _socket!.on('typing', (data) {
      if (data is! Map) return;
      final fromId = _id(data['from']);
      final isTyping = data['isTyping'] == true;
      if (_activeChatUserId == fromId) {
        if (_isOtherUserTyping != isTyping) {
          _isOtherUserTyping = isTyping;
          notifyListeners();
        }
      }
    });
  }

  void _detachSocketListeners() {
    _socket?.off('connect');
    _socket?.off('private_message');
    _socket?.off('typing');
    _socket?.off('user_status');
    _listenersAttached = false;
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

  Future<void> loadChatHistory(
    String token,
    String otherUserId, {
    bool silent = false,
  }) async {
    final isSameChat = _activeChatUserId == otherUserId;
    _activeChatUserId = otherUserId;

    if (!kIsWeb) {
      try {
        FlutterBackgroundService().invoke('setActiveChat', {'userId': otherUserId});
      } catch (_) {}
    }

    _isOtherUserTyping = false;
    if (!isSameChat) {
      _isActiveUserOnline = false;
      _activeUserLastSeen = null;
    }

    for (final chat in _recentChats) {
      if (_id(chat['_id']) == otherUserId) {
        _isActiveUserOnline = chat['isOnline'] as bool? ?? false;
        _activeUserLastSeen = _parseLastSeen(chat['lastSeen']);
        break;
      }
    }

    if (_socket != null && _socket!.connected) {
      _socket!.emit('get_user_status', {'userId': otherUserId});
      _socket!.emit('mark_chat_read', {'otherUserId': otherUserId});
    }

    if (!silent || !isSameChat) {
      _isLoading = !silent;
      if (!isSameChat) {
        _messages = [];
      }
      notifyListeners();
    }

    try {
      final rawMsgs = await _apiService.fetchChatHistory(token, otherUserId);
      final fetched = rawMsgs
          .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
          .toList();

      if (silent && isSameChat) {
        final existingIds = _messages.map((m) => m.id).toSet();
        for (final msg in fetched) {
          if (!existingIds.contains(msg.id)) {
            _messages.add(msg);
          }
        }
        _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      } else {
        _messages = fetched;
      }

      for (int i = 0; i < _recentChats.length; i++) {
        if (_id(_recentChats[i]['_id']) == otherUserId) {
          _recentChats[i]['unreadCount'] = 0;
          break;
        }
      }
    } catch (e) {
      debugPrint('Error loading chat history: $e');
      if (!silent) rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void sendMessage(String content, String toUserId, String currentUserId) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;

    if (_socket == null || !_socket!.connected) {
      throw Exception('Not connected. Message will send when connection restores.');
    }

    final tempId = 'pending_${DateTime.now().microsecondsSinceEpoch}';
    final optimistic = ChatMessage(
      id: tempId,
      from: currentUserId,
      to: toUserId,
      content: trimmed,
      timestamp: DateTime.now(),
    );

    _addOrUpdateMessage(optimistic);
    _upsertRecentChatFromMessage(optimistic, incrementUnread: false);
    notifyListeners();

    _socket!.emit('private_message', {
      'to': toUserId,
      'content': trimmed,
      'clientTempId': tempId,
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
    _detachSocketListeners();
    super.dispose();
  }
}
