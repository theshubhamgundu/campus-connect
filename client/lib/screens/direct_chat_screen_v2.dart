import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/chat_service_v2.dart';
import '../services/connection_service.dart';
import '../services/call_service.dart';
import '../models/message.dart';
import 'incoming_call_screen.dart';

/// Updated DirectChatScreen that uses ChatServiceV2 for persistent message storage
class DirectChatScreenV2 extends StatefulWidget {
  final String receiverId;
  final String receiverName;

  const DirectChatScreenV2({
    Key? key,
    required this.receiverId,
    required this.receiverName,
  }) : super(key: key);

  @override
  State<DirectChatScreenV2> createState() => _DirectChatScreenV2State();
}

class _DirectChatScreenV2State extends State<DirectChatScreenV2> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _checkConnection();
    // Mark messages as read when entering this conversation
    Future.microtask(() {
      final chatService = Provider.of<ChatServiceV2>(context, listen: false);
      final currentUserId = ConnectionService.instance.currentUserId;
      if (currentUserId != null) {
        chatService.markAsRead(currentUserId, widget.receiverId);
      }
    });
  }

  void _checkConnection() {
    final status = ConnectionService.instance.connectionStatus.value;
    setState(() => _isConnected = status == ConnectionStatus.connected);

    // Subscribe to connection status changes
    ConnectionService.instance.connectionStatus.addListener(_checkConnection);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    ConnectionService.instance.connectionStatus.removeListener(_checkConnection);
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    try {
      final chatService = Provider.of<ChatServiceV2>(context, listen: false);
      await chatService.sendMessage(
        toUserId: widget.receiverId,
        messageText: text,
      );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ConnectionService.instance.currentUserId;
    
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.receiverName),
            Text(
              widget.receiverId,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        elevation: 0,
        actions: [
          // Call button
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: _isConnected
                ? () {
                    final callService = CallService();
                    callService.sendCallRequest(
                      widget.receiverId,
                      widget.receiverName,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Calling ${widget.receiverName}...')),
                    );
                  }
                : null,
            tooltip: 'Call',
          ),
          // File share button
          IconButton(
            icon: const Icon(Icons.attach_file),
            onPressed: _isConnected ? () => _showFileShareOptions() : null,
            tooltip: 'Share file',
          ),
        ],
      ),
      body: Column(
        children: [
          // Connection status banner
          if (!_isConnected)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.orange,
              child: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Not connected to server',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          // Messages list from ChatService
          Expanded(
            child: Consumer<ChatServiceV2>(
              builder: (context, chatService, _) {
                if (currentUserId == null) {
                  return const Center(child: Text('User not authenticated'));
                }

                final messages = chatService.messagesFor(currentUserId, widget.receiverId);

                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'No messages yet\nStart the conversation!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  );
                }

                // Auto-scroll when new messages arrive
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: messages.length,
                  itemBuilder: (ctx, i) {
                    final msg = messages[i];
                    final isFromMe = msg.senderId == currentUserId;
                    return _buildMessageBubble(msg, isFromMe);
                  },
                );
              },
            ),
          ),
          // Message input
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(
                top: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 16,
                      ),
                    ),
                    minLines: 1,
                    maxLines: 3,
                    enabled: _isConnected,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _isConnected ? _sendMessage : null,
                  color: Theme.of(context).primaryColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message msg, bool isFromMe) {
    return Align(
      alignment: isFromMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isFromMe ? Theme.of(context).primaryColor : Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment:
              isFromMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              msg.text,
              style: TextStyle(
                color: isFromMe ? Colors.white : Colors.black,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${msg.timestamp.hour}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                color: isFromMe ? Colors.white70 : Colors.grey[600],
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFileShareOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Share Image'),
              onTap: () {
                Navigator.pop(ctx);
                _shareImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.description),
              title: const Text('Share Document'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Document sharing coming soon')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.location_on),
              title: const Text('Share Location'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Location sharing coming soon')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _shareImage() {
    // Placeholder for image sharing functionality
    // In a real app, you would:
    // 1. Use image_picker to select an image
    // 2. Convert to base64
    // 3. Send via WebSocket with file_metadata + file_chunk messages
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Image sharing coming soon')),
    );
  }
}
