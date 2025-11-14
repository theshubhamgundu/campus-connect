import 'dart:async';
import 'package:flutter/material.dart';
import '../services/connection_service.dart';

class DirectChatScreen extends StatefulWidget {
  final String receiverId;
  final String receiverName;
  final String receiverIp;

  const DirectChatScreen({
    Key? key,
    required this.receiverId,
    required this.receiverName,
    required this.receiverIp,
  }) : super(key: key);

  @override
  _DirectChatScreenState createState() => _DirectChatScreenState();
}

class Message {
  final String from;
  final String to;
  final String text;
  final DateTime timestamp;
  final bool isFromMe;

  Message({
    required this.from,
    required this.to,
    required this.text,
    required this.timestamp,
    required this.isFromMe,
  });
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<Message> _messages = [];
  final ScrollController _scrollController = ScrollController();
  late StreamSubscription _messageSubscription;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _checkConnection();
    _listenToMessages();
  }

  void _checkConnection() {
    final status = ConnectionService.instance.connectionStatus.value;
    setState(() => _isConnected = status == ConnectionStatus.connected);
  }

  void _listenToMessages() {
    _messageSubscription =
        ConnectionService.instance.incomingMessages.listen((msg) {
      final type = msg['type']?.toString() ?? '';
      final from = msg['from']?.toString() ?? '';
      final to = msg['to']?.toString() ?? '';

      // Check if this message is for this conversation
      final currentUserId = ConnectionService.instance.currentUserId;
      if (type == 'chat_message' &&
          ((from == widget.receiverId && to == currentUserId) ||
              (from == currentUserId && to == widget.receiverId))) {
        final text = msg['message']?.toString() ?? '';
        final timestamp = msg['timestamp'] != null
            ? DateTime.tryParse(msg['timestamp'].toString())
            : DateTime.now();

        final message = Message(
          from: from,
          to: to,
          text: text,
          timestamp: timestamp ?? DateTime.now(),
          isFromMe: from == currentUserId,
        );

        setState(() {
          _messages.add(message);
          _scrollToBottom();
        });
      }
    });
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

    // Send via WebSocket
    await ConnectionService.instance.sendChatMessage(widget.receiverId, text);

    // Add to local UI immediately
    final currentUserId = ConnectionService.instance.currentUserId;
    final message = Message(
      from: currentUserId ?? 'unknown',
      to: widget.receiverId,
      text: text,
      timestamp: DateTime.now(),
      isFromMe: true,
    );

    setState(() {
      _messages.add(message);
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _messageSubscription.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.receiverName),
            Text(
              widget.receiverIp,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        elevation: 0,
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
          // Messages list
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Text(
                      'No messages yet\nStart the conversation!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: _messages.length,
                    itemBuilder: (ctx, i) {
                      final msg = _messages[i];
                      return _buildMessageBubble(msg);
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

  Widget _buildMessageBubble(Message msg) {
    return Align(
      alignment: msg.isFromMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: msg.isFromMe
              ? Theme.of(context).primaryColor
              : Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: msg.isFromMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              msg.text,
              style: TextStyle(
                color: msg.isFromMe ? Colors.white : Colors.black,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${msg.timestamp.hour}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                color: msg.isFromMe ? Colors.white70 : Colors.grey[600],
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
