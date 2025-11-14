class ChatMessage {
  final String from;
  final String to;
  final String message;
  final DateTime timestamp;

  ChatMessage({required this.from, required this.to, required this.message, required this.timestamp});

  factory ChatMessage.fromMap(Map<String, dynamic> m) {
    return ChatMessage(
      from: (m['from'] ?? '').toString(),
      to: (m['to'] ?? '').toString(),
      message: (m['message'] ?? m['text'] ?? '').toString(),
      timestamp: DateTime.tryParse((m['timestamp'] ?? m['ts'] ?? '')) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'from': from,
        'to': to,
        'message': message,
        'timestamp': timestamp.toIso8601String(),
      };
}
