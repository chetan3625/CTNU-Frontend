// lib/models/message.dart
class ChatMessage {
  final String id;
  final String from;
  final String to;
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.from,
    required this.to,
    required this.content,
    required this.timestamp,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['_id'] as String,
      from: json['from'] as String,
      to: json['to'] as String,
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}
