import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/message.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final String? avatarUrl;
  final String? senderName;
  final bool showAvatar;
  final bool showName;
  final VoidCallback? onCopy;
  final VoidCallback? onDelete;

  const MessageBubble({
    Key? key,
    required this.message,
    required this.isMe,
    this.avatarUrl,
    this.senderName,
    this.showAvatar = true,
    this.showName = true,
    this.onCopy,
    this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final currentUser = Provider.of<AuthProvider>(context).currentUser;
    final isCurrentUser = message.senderId == currentUser?.userId;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        mainAxisAlignment: isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isCurrentUser && showAvatar)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: CircleAvatar(
                radius: 16,
                backgroundImage: message.senderAvatarUrl != null 
                    ? NetworkImage(message.senderAvatarUrl!)
                    : null,
                child: message.senderAvatarUrl == null 
                    ? Text((message.senderName?.isNotEmpty ?? false) ? message.senderName![0].toUpperCase() : '?')
                    : null,
              ),
            ),
          Flexible(
            child: Column(
              crossAxisAlignment: 
                  isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (showName && !isCurrentUser && (message.senderName?.isNotEmpty ?? false))
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0, bottom: 2.0),
                    child: Text(
                      message.senderName ?? '',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                      ),
                    ),
                  ),
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.7,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 10.0,
                  ),
                  decoration: BoxDecoration(
                    color: isCurrentUser
                        ? (theme.colorScheme.primary.withOpacity(0.9))
                        : (isDarkMode 
                            ? Colors.grey[800] 
                            : Colors.grey[200]),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(isCurrentUser ? 16.0 : 4.0),
                      topRight: Radius.circular(isCurrentUser ? 4.0 : 16.0),
                      bottomLeft: const Radius.circular(16.0),
                      bottomRight: const Radius.circular(16.0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: isCurrentUser 
                        ? CrossAxisAlignment.end 
                        : CrossAxisAlignment.start,
                    children: [
                      if (message.text.isNotEmpty)
                        Text(
                          message.text,
                          style: TextStyle(
                            color: isCurrentUser 
                                ? Colors.white 
                                : theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatTime(message.timestamp),
                            style: TextStyle(
                              fontSize: 10,
                              color: (isCurrentUser ? Colors.white70 : theme.textTheme.bodySmall?.color)
                                  ?.withOpacity(0.7),
                            ),
                          ),
                          if (isCurrentUser) ...[
                            const SizedBox(width: 4),
                            _buildStatusIcon(message.status),
                            _buildStatusIcon(message.status),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isMe && showAvatar)
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: CircleAvatar(
                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                child: avatarUrl == null ? Text(senderName?[0] ?? '?') : null,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return const Icon(Icons.access_time, size: 12, color: Colors.white70);
      case MessageStatus.sent:
        return const Icon(Icons.check, size: 12, color: Colors.white70);
      case MessageStatus.delivered:
        return const Icon(Icons.done_all, size: 12, color: Colors.white70);
      case MessageStatus.read:
        return const Icon(Icons.done_all, size: 12, color: Colors.blue);
      case MessageStatus.error:
        return const Icon(Icons.error_outline, size: 12, color: Colors.red);
      default:
        return const SizedBox.shrink();
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
