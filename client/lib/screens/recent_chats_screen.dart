import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/chat_service_v3.dart';
import '../services/connection_service.dart';
import 'direct_chat_screen_v2.dart';

/// Screen showing recent conversations
class RecentChatsScreen extends StatefulWidget {
  const RecentChatsScreen({Key? key}) : super(key: key);

  @override
  State<RecentChatsScreen> createState() => _RecentChatsScreenState();
}

class _RecentChatsScreenState extends State<RecentChatsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // TODO: Navigate to user picker to start new chat
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Go to Nearby to start chatting')),
              );
            },
          ),
        ],
      ),
      body: Consumer<ChatServiceV3>(
        builder: (context, chatService, _) {
          final currentUserId = ConnectionService.instance.currentUserId;
          if (currentUserId == null) {
            return Center(
              child: Text(
                'Not authenticated',
                style: TextStyle(color: Colors.grey[600]),
              ),
            );
          }

          final conversations = chatService.getConversationSummaries(currentUserId);

          if (conversations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.mail_outline,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No conversations yet',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Go to Nearby to start chatting',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: conversations.length,
            itemBuilder: (context, index) {
              final conv = conversations[index];
              return _buildConversationTile(context, conv);
            },
          );
        },
      ),
    );
  }

  Widget _buildConversationTile(
    BuildContext context,
    ConversationSummary conversation,
  ) {
    final formattedTime = _formatTime(conversation.lastMessageTime);
    
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).primaryColor,
        child: Text(
          conversation.otherUserName.isNotEmpty
              ? conversation.otherUserName[0].toUpperCase()
              : '?',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      title: Text(
        conversation.otherUserName,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        conversation.lastMessageText,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 13,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            formattedTime,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
          if (conversation.unreadCount > 0)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${conversation.unreadCount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DirectChatScreenV2(
              receiverId: conversation.otherUserId,
              receiverName: conversation.otherUserName,
            ),
          ),
        );
      },
      onLongPress: () {
        // Show context menu for delete/clear
        showModalBottomSheet(
          context: context,
          builder: (context) => Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Clear chat history'),
                  textColor: Colors.red,
                  onTap: () {
                    Navigator.pop(context);
                    _showClearConfirmation(context, conversation.otherUserId);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.close),
                  title: const Text('Cancel'),
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showClearConfirmation(BuildContext context, String otherUserId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear chat history?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // TODO: Implement clear conversation logic in ChatServiceV2
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Chat history cleared')),
              );
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final givenDay = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (givenDay == today) {
      return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (givenDay == yesterday) {
      return 'Yesterday';
    } else if (now.difference(dateTime).inDays < 7) {
      return DateFormat('E').format(dateTime); // Mon, Tue, Wed, etc.
    } else {
      return DateFormat('MMM d').format(dateTime); // Jan 15, Feb 3, etc.
    }
  }
}
