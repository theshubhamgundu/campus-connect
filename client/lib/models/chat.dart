class Chat {
  final String id;
  String name;
  String lastMessage;
  final String time;
  String avatar;
  bool isOnline;
  int unreadCount;
  List<Message>? messages;
  String? email;
  String? phone;
  String? status;
  DateTime? lastSeen;
  bool isGroup;
  List<Map<String, dynamic>>? members;
  String? createdBy;
  DateTime? createdAt;

  Chat({
    required this.id,
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.avatar,
    this.isOnline = false,
    this.unreadCount = 0,
    this.messages,
    this.email,
    this.phone,
    this.status = 'Hey there! I am using CampusNet',
    this.lastSeen,
    this.isGroup = false,
    this.members,
    this.createdBy,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'lastMessage': lastMessage,
      'time': time,
      'avatar': avatar,
      'isOnline': isOnline,
      'unreadCount': unreadCount,
      'email': email,
      'phone': phone,
      'status': status,
      'lastSeen': lastSeen?.toIso8601String(),
      'isGroup': isGroup,
      'members': members,
      'createdBy': createdBy,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  factory Chat.fromMap(Map<String, dynamic> map) {
    return Chat(
      id: map['id'],
      name: map['name'],
      lastMessage: map['lastMessage'] ?? '',
      time: map['time'] ?? '',
      avatar: map['avatar'] ?? '',
      isOnline: map['isOnline'] ?? false,
      unreadCount: map['unreadCount'] ?? 0,
      email: map['email'],
      phone: map['phone'],
      status: map['status'] ?? 'Hey there! I am using CampusNet',
      lastSeen: map['lastSeen'] != null ? DateTime.parse(map['lastSeen']) : null,
      isGroup: map['isGroup'] ?? false,
      members: map['members'] != null ? List<Map<String, dynamic>>.from(map['members']) : null,
      createdBy: map['createdBy'],
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : null,
    );
  }
}

class Message {
  final String id;
  final String senderId;
  final String text;
  final String type; // 'text', 'image', 'file', 'audio', 'video', 'location'
  final DateTime timestamp;
  final bool isRead;
  final String? filePath;
  final int? fileSize;
  final String? fileName;
  final String? mimeType;
  final Map<String, dynamic>? metadata;
  final String? replyToMessageId;
  final Message? replyToMessage;
  final Map<String, String>? reactions;

  Message({
    required this.id,
    required this.senderId,
    required this.text,
    this.type = 'text',
    DateTime? timestamp,
    this.isRead = false,
    this.filePath,
    this.fileSize,
    this.fileName,
    this.mimeType,
    this.metadata,
    this.replyToMessageId,
    this.replyToMessage,
    this.reactions,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isMe => senderId == 'me'; // Replace 'me' with actual current user ID

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'text': text,
      'type': type,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'filePath': filePath,
      'fileSize': fileSize,
      'fileName': fileName,
      'mimeType': mimeType,
      'metadata': metadata,
      'replyToMessageId': replyToMessageId,
      'reactions': reactions,
    };
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'],
      senderId: map['senderId'],
      text: map['text'],
      type: map['type'] ?? 'text',
      timestamp: DateTime.parse(map['timestamp']),
      isRead: map['isRead'] ?? false,
      filePath: map['filePath'],
      fileSize: map['fileSize'],
      fileName: map['fileName'],
      mimeType: map['mimeType'],
      metadata: map['metadata'] != null ? Map<String, dynamic>.from(map['metadata']) : null,
      replyToMessageId: map['replyToMessageId'],
      reactions: map['reactions'] != null ? Map<String, String>.from(map['reactions']) : null,
    );
  }
}
