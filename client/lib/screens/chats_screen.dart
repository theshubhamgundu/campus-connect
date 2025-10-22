import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'chat_screen.dart';

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
  
  // For group chats
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
  
  // Convert to map for storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'lastMessage': lastMessage,
      'time': time,
      'avatar': avatar,
      'isOnline': isOnline,
      'unreadCount': unreadCount,
      'messages': messages?.map((msg) => msg.toMap()).toList(),
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
  
  // Create from map
  factory Chat.fromMap(Map<String, dynamic> map) {
    return Chat(
      id: map['id'],
      name: map['name'],
      lastMessage: map['lastMessage'] ?? '',
      time: map['time'] ?? '',
      avatar: map['avatar'] ?? '',
      isOnline: map['isOnline'] ?? false,
      unreadCount: map['unreadCount'] ?? 0,
      messages: map['messages'] != null 
          ? (map['messages'] as List).map((msg) => Message.fromMap(msg)).toList()
          : null,
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
  
  // For replies
  final String? replyToMessageId;
  final Message? replyToMessage;
  
  // For reactions
  final Map<String, String>? reactions; // userId -> emoji

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
  
  bool get isMe => senderId == 'me'; // You'll need to replace 'me' with actual current user ID
  
  // Convert to map for storage
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
  
  // Create from map
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
  
  // Create a copy with some fields updated
  Message copyWith({
    String? id,
    String? senderId,
    String? text,
    String? type,
    DateTime? timestamp,
    bool? isRead,
    String? filePath,
    int? fileSize,
    String? fileName,
    String? mimeType,
    Map<String, dynamic>? metadata,
    String? replyToMessageId,
    Message? replyToMessage,
    Map<String, String>? reactions,
  }) {
    return Message(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      text: text ?? this.text,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      filePath: filePath ?? this.filePath,
      fileSize: fileSize ?? this.fileSize,
      fileName: fileName ?? this.fileName,
      mimeType: mimeType ?? this.mimeType,
      metadata: metadata ?? this.metadata,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyToMessage: replyToMessage ?? this.replyToMessage,
      reactions: reactions ?? this.reactions,
    );
  }
}

class ChatsScreen extends StatelessWidget {
  const ChatsScreen({Key? key}) : super(key: key);

  // This would normally come from your data source
  final List<Chat> chats = const [
    Chat(
      id: '1',
      name: 'John Doe',
      lastMessage: 'Hey, how are you doing?',
      time: '10:30 AM',
      avatar: 'assets/images/avatar1.png',
      isOnline: true,
      unreadCount: 2,
    ),
    Chat(
      id: '2',
      name: 'Jane Smith',
      lastMessage: 'Meeting at 3 PM',
      time: 'Yesterday',
      avatar: 'assets/images/avatar2.png',
    ),
    // Add more dummy data as needed
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: chats.length,
      itemBuilder: (context, index) {
        final chat = chats[index];
        return ListTile(
          leading: Stack(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundImage: AssetImage(chat.avatar),
                child: chat.avatar.isEmpty ? Text(chat.name[0]) : null,
              ),
              if (chat.isOnline)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          title: Text(
            chat.name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            chat.lastMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                chat.time,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              if (chat.unreadCount > 0)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFF128C7E),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${chat.unreadCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatScreen(chat: chat),
              ),
            );
          },
        );
      },
    );
  }
}
