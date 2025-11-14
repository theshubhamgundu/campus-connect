import 'package:flutter/material.dart';
import '../services/websocket_service.dart';
import '../services/chat_service.dart';
import 'package:intl/intl.dart';
import 'chat_screen.dart';
import '../models/chat.dart';
import '../widgets/placeholder_image.dart';


class ChatsScreen extends StatelessWidget {
  const ChatsScreen({Key? key}) : super(key: key);

  // This would normally come from your data source
  List<Chat> get chats {
    return [
      Chat(
        id: '1',
        name: 'John Doe',
        lastMessage: 'Hey, how are you doing?',
        time: '10:30 AM',
        avatar: '',
        isOnline: true,
        unreadCount: 2,
      ),
      Chat(
        id: '2',
        name: 'Jane Smith',
        lastMessage: 'Meeting at 3 PM',
        time: 'Yesterday',
        avatar: '',
      ),
      // Add more dummy data as needed
    ];
  }

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
                backgroundColor: Colors.grey.shade200,
                child: ClipOval(
                  child: PlaceholderImage(
                    assetPath: chat.avatar,
                    width: 50,
                    height: 50,
                  ),
                ),
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
                builder: (context) => ChatScreen(
                  chat: chat,
                  onSendMessage: (message) {
                    ChatService().sendMessage(
                      receiverId: chat.id,
                      text: message.text,
                    );
                  },
                  onSendImage: (file) {
                    // Handle sending image
                  },
                  onSendFile: (file) {
                    // Handle sending file
                  },
                  onUpdateProfile: (name, status) {
                    // Handle profile update
                  },
                  currentUserId: WebSocketService().userId ?? 'unknown',
                ),
              ),
            );
          },
        );
      },
    );
  }
}
