import 'message.dart';

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

  // Aliases for compatibility
  String get title => name;
  String get lastMessageText => lastMessage;
  DateTime? get lastMessageTimestamp => lastSeen ?? createdAt;

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


