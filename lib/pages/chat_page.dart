// lib/pages/chat_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../models/message.dart';
import '../widgets/chat_emoji_picker.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _textScrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  Timer? _typingTimer;
  bool _isTyping = false;
  bool _emojiShowing = false;
  bool _initialized = false;
  late String _otherUserId;
  late String _otherUsername;
  int _lastMessageCount = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      _otherUserId = args['id'] as String;
      _otherUsername = args['username'] as String;

      final auth = Provider.of<AuthProvider>(context, listen: false);
      final chat = Provider.of<ChatProvider>(context, listen: false);

      // Fetch historical messages (socket listeners are attached globally)
      if (auth.token != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            chat.loadChatHistory(auth.token!, _otherUserId).then((_) {
              _lastMessageCount = chat.messages.length;
              _scrollToBottom(immediate: true);
            });
          }
        });
      }

      _initialized = true;
    }
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    // Avoid accessing provider if context is no longer active, but we can safely access listen:false
    try {
      final chat = Provider.of<ChatProvider>(context, listen: false);
      chat.clearActiveChat();
    } catch (_) {}

    _scrollController.dispose();
    _textScrollController.dispose();
    _focusNode.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _toggleEmojiPicker() {
    setState(() {
      _emojiShowing = !_emojiShowing;
      if (_emojiShowing) {
        _focusNode.unfocus();
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _focusNode.requestFocus();
        });
      }
    });
  }

  void _hideEmojiPicker() {
    if (!_emojiShowing) return;
    setState(() => _emojiShowing = false);
  }

  void _onTextChanged(String text) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.socket == null) return;

    if (!_isTyping) {
      _isTyping = true;
      auth.socket!.emit('typing', {
        'to': _otherUserId,
        'isTyping': true,
      });
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      _isTyping = false;
      auth.socket!.emit('typing', {
        'to': _otherUserId,
        'isTyping': false,
      });
    });
  }

  String _formatLastSeen(DateTime? lastSeen) {
    if (lastSeen == null) return 'Last seen recently';
    final now = DateTime.now();
    final diff = now.difference(lastSeen);
    
    if (diff.inMinutes < 1) {
      return 'Last seen just now';
    } else if (diff.inHours < 1) {
      final mins = diff.inMinutes;
      return 'Last seen $mins ${mins == 1 ? 'minute' : 'minutes'} ago';
    } else if (diff.inDays < 1) {
      final hrs = diff.inHours;
      return 'Last seen $hrs ${hrs == 1 ? 'hour' : 'hours'} ago';
    } else {
      final days = diff.inDays;
      return 'Last seen $days ${days == 1 ? 'day' : 'days'} ago';
    }
  }

  void _scrollToBottom({bool immediate = false}) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        if (immediate) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        } else {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final chat = Provider.of<ChatProvider>(context, listen: false);
    if (auth.userId == null) return;

    try {
      chat.sendMessage(text, _otherUserId, auth.userId!);
      _messageController.clear();
      _hideEmojiPicker();
      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send message: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final chat = Provider.of<ChatProvider>(context);
    final theme = Theme.of(context);

    // Auto-scroll when new messages arrive
    if (chat.messages.length != _lastMessageCount) {
      final isNewMessageAdded = chat.messages.length > _lastMessageCount;
      _lastMessageCount = chat.messages.length;
      if (isNewMessageAdded) {
        _scrollToBottom();
      }
    }
 
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: theme.colorScheme.secondary.withValues(
                alpha: 0.2,
              ),
              radius: 18,
              child: Text(
                _otherUsername.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  color: theme.colorScheme.secondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _otherUsername,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    chat.isOtherUserTyping
                        ? 'Typing...'
                        : (chat.isActiveUserOnline
                            ? 'Online'
                            : _formatLastSeen(chat.activeUserLastSeen)),
                    style: TextStyle(
                      fontSize: 11,
                      color: chat.isOtherUserTyping
                          ? theme.colorScheme.secondary
                          : (chat.isActiveUserOnline
                              ? Colors.greenAccent
                              : Colors.white38),
                      fontWeight: chat.isOtherUserTyping || chat.isActiveUserOnline
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Chat messages area
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, chat, child) {
                if (chat.isLoading && chat.messages.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (chat.messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 48,
                          color: Colors.white24,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No messages yet.',
                          style: TextStyle(color: Colors.white38),
                        ),
                        Text(
                          'Send a message to start the conversation!',
                          style: TextStyle(color: Colors.white24, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  itemCount: chat.messages.length,
                  itemBuilder: (context, index) {
                    final msg = chat.messages[index];
                    final isMe = msg.from == auth.userId;
                    return KeyedSubtree(
                      key: ValueKey(msg.id),
                      child: _buildMessageBubble(msg, isMe, theme),
                    );
                  },
                );
              },
            ),
          ),

          // Message input bar
          _buildMessageInput(theme),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isMe, ThemeData theme) {
    final localTime = msg.timestamp.toLocal();
    final timeStr =
        "${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}";

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe ? theme.colorScheme.primary : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          border: isMe ? null : Border.all(color: const Color(0xFF2C2C2C)),
        ),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              msg.content,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              timeStr,
              style: TextStyle(
                color: isMe ? Colors.white70 : Colors.white38,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput(ThemeData theme) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1F1F1F),
        border: Border(top: BorderSide(color: Color(0xFF2C2C2C))),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: _toggleEmojiPicker,
                    icon: Icon(
                      _emojiShowing
                          ? Icons.keyboard_rounded
                          : Icons.emoji_emotions_outlined,
                      color: Colors.white54,
                    ),
                    tooltip: _emojiShowing ? 'Keyboard' : 'Emoji',
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF121212),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFF2C2C2C)),
                      ),
                      child: TextField(
                        controller: _messageController,
                        focusNode: _focusNode,
                        scrollController: _textScrollController,
                        onChanged: _onTextChanged,
                        onTap: _hideEmojiPicker,
                        minLines: 1,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          filled: false,
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.primary,
                    radius: 24,
                    child: IconButton(
                      icon: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
            if (_emojiShowing)
              ChatEmojiPicker(
                textController: _messageController,
                scrollController: _textScrollController,
                onEmojiSelected: () => _onTextChanged(_messageController.text),
              ),
          ],
        ),
      ),
    );
  }
}
