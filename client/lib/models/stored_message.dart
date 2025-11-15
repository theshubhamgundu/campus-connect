import 'package:hive/hive.dart';

part 'stored_message.g.dart';

@HiveType(typeId: 0)
class StoredMessage {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String fromUserId;

  @HiveField(2)
  final String toUserId;

  @HiveField(3)
  final String text;

  @HiveField(4)
  final DateTime timestamp;

  @HiveField(5)
  final bool isMine;

  @HiveField(6)
  final String messageType; // 'text', 'file', 'call_event'

  @HiveField(7)
  final Map<String, dynamic>? metadata; // For file info, call details, etc.

  StoredMessage({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.text,
    required this.timestamp,
    required this.isMine,
    this.messageType = 'text',
    this.metadata,
  });

  factory StoredMessage.fromJson(Map<String, dynamic> json) {
    return StoredMessage(
      id: json['id'] as String? ?? '',
      fromUserId: json['fromUserId'] as String? ?? json['from'] as String? ?? '',
      toUserId: json['toUserId'] as String? ?? json['to'] as String? ?? '',
      text: json['text'] as String? ?? json['message'] as String? ?? '',
      timestamp: json['timestamp'] is String
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : (json['timestamp'] as DateTime?) ?? DateTime.now(),
      isMine: json['isMine'] as bool? ?? false,
      messageType: json['messageType'] as String? ?? 'text',
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'isMine': isMine,
      'messageType': messageType,
      'metadata': metadata,
    };
  }

  /// Get conversation ID (sorted pair of userIds) - must match ChatServiceV3.conversationIdFor
  static String getConversationId(String userA, String userB) {
    final ids = [userA, userB]..sort();
    return ids.join('_');
  }
}
