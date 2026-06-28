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
      id: json['_id'].toString(),
      from: json['from'].toString(),
      to: json['to'].toString(),
      content: json['content'] as String,
      timestamp: _parseTimestamp(json['timestamp']),
    );
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value is String) {
      return DateTime.parse(value).toLocal();
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true).toLocal();
    }
    return DateTime.now();
  }
}
