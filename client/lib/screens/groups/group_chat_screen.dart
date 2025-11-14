import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart'; // For Clipboard
import '../../models/group.dart';
import '../../models/message.dart';
import '../../services/group_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/chat/message_bubble.dart';
import '../../widgets/chat/chat_input.dart';

class GroupChatScreen extends StatefulWidget {
  final Group group;

  const GroupChatScreen({
    Key? key,
    required this.group,
  }) : super(key: key);

  @override
  _GroupChatScreenState createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();
  bool _isLoading = true;
  bool _isSending = false;
  List<Message> _messages = [];
  StreamSubscription<dynamic>? _messagesSubscription;
  StreamSubscription<dynamic>? _typingSubscription;
  Map<String, bool> _typingUsers = {};
  bool _showScrollToBottom = false;
  final FocusNode _focusNode = FocusNode();
  final GlobalKey _messageListKey = GlobalKey();
  late GroupService _groupService;
  bool _isConnected = true;

  @override
  void initState() {
    super.initState();
    _groupService = Provider.of<GroupService>(context, listen: false);
    _loadMessages();
    _scrollController.addListener(_onScroll);
    _focusNode.addListener(_onFocusChange);
    _subscribeToMessages();
  }
  
  void _subscribeToMessages() {
    _messagesSubscription = _groupService.watchMessages(widget.group.id).listen((messages) {
      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoading = false;
        });
        _scrollToBottom();
      }
    });
  }
  
  void _onCopyMessage(Message message) {
    Clipboard.setData(ClipboardData(text: message.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Message copied to clipboard')),
    );
  }
  
  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      _scrollToBottom();
    }
  }
  
  void _onScroll() {
    if (_scrollController.position.pixels > 200) {
      if (!_showScrollToBottom) {
        setState(() => _showScrollToBottom = true);
      }
    } else {
      if (_showScrollToBottom) {
        setState(() => _showScrollToBottom = false);
      }
    }
  }
  
  void _scrollToBottom({bool animate = true}) {
    if (_scrollController.hasClients) {
      if (animate) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        });
      }
    }
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _typingSubscription?.cancel();
    _scrollController.dispose();
    _messageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      setState(() => _isLoading = true);
      final messages = await _groupService.getMessages(widget.group.id);
      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoading = false;
        });
        _scrollToBottom(animate: false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load messages: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _loadOlderMessages() async {
    if (_isLoading || _messages.isEmpty) return;

    final firstMessage = _messages.first;
    
    try {
      setState(() {
        _isLoading = true;
      });

      final olderMessages = await _groupService.loadMessages(
        widget.group.id,
        limit: 20,
        offset: 0,
      );

      if (mounted && olderMessages.isNotEmpty) {
        setState(() {
          _messages.insertAll(0, olderMessages);
        });
        
        // Maintain scroll position
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(_scrollController.position.maxScrollExtent * 0.1);
          }
        });
      }
    } catch (e) {
      _showError('Failed to load older messages');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    setState(() => _isSending = true);

    try {
      await _groupService.sendMessage(
        groupId: widget.group.id,
        content: text,
        type: MessageType.text,
      );
      
      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      _showError('Failed to send message');
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _handleAttachment() {
    // TODO: Implement attachment picker
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Photo or Video'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement photo/video picker
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file),
              title: const Text('Document'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement document picker
              },
            ),
            ListTile(
              leading: const Icon(Icons.mic),
              title: const Text('Audio'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement audio recording
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _markMessagesAsRead() async {
    final currentUserId = Provider.of<AuthProvider>(context, listen: false).currentUser?.userId;
    if (currentUserId == null) return;
    
    final unreadMessages = _messages.where((msg) => 
      msg.status != MessageStatus.read && 
      msg.senderId != currentUserId
    ).toList();

    if (unreadMessages.isNotEmpty) {
      try {
        await _groupService.markAsRead(
          widget.group.id,
          unreadMessages.map((msg) => msg.id).toList(),
        );
        
        // Update local message status
        setState(() {
          for (var msg in _messages) {
            if (unreadMessages.any((m) => m.id == msg.id)) {
              msg.status = MessageStatus.read;
            }
          }
        });
      } catch (e) {
        debugPrint('Error marking messages as read: $e');
      }
    }
  }

  void _showMessageOptions(Message message) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy'),
              onTap: () {
                Navigator.pop(context);
                _onCopyMessage(message);
              },
            ),
            if (message.senderId == currentUserId)
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Delete'),
                onTap: () {
                  Navigator.pop(context);
                  _onDeleteMessage(message);
                },
              ),
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement reply
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onDeleteMessage(Message message) async {
    try {
      await _groupService.deleteMessage(widget.group.id, message.id);
      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m.id == message.id);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete message: $e')),
        );
      }
    }
  }

  void _handleTypingStatus(bool isTyping) {
    _sendTypingStatus(isTyping);
  }

  void _sendTypingStatus(bool isTyping) {
    _groupService.sendTypingStatus(widget.group.id, isTyping);
  }

  String _getTypingText() {
    final typingUserIds = _typingUsers.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    if (typingUserIds.isEmpty) return '';

    // Get user names (in a real app, you would fetch these from your user service)
    final userNames = typingUserIds.map((id) => 'User ${id.substring(0, 4)}').toList();

    if (userNames.length == 1) {
      return '${userNames[0]} is typing...';
    } else if (userNames.length == 2) {
      return '${userNames[0]} and ${userNames[1]} are typing...';
    } else {
      return '${userNames[0]}, ${userNames[1]}, and ${userNames.length - 2} others are typing...';
    }
  }

  Widget _buildConnectionStatus() {
    if (_isConnected) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      color: Colors.orange,
      child: const Center(
        child: Text(
          'Connecting...',
          style: TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<AuthProvider>(context, listen: false).currentUser;
    
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.group.name),
            if (_typingUsers.isNotEmpty)
              Text(
                _getTypingText(),
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              // TODO: Show group info
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (!_isConnected) _buildConnectionStatus(),
          Expanded(
            child: Stack(
              children: [
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _messages.isEmpty
                        ? const Center(child: Text('No messages yet'))
                        : ListView.builder(
                            key: _messageListKey,
                            controller: _scrollController,
                            reverse: true,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final message = _messages[index];
                              final isMe = message.senderId == currentUser?.userId;
                              
                              return MessageBubble(
                                message: message,
                                isMe: isMe,
                                onCopy: () => _onCopyMessage(message),
                                onDelete: isMe ? () => _onDeleteMessage(message) : null,
                              );
                            },
                          ),
                if (_showScrollToBottom)
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: FloatingActionButton.small(
                      onPressed: _scrollToBottom,
                      child: const Icon(Icons.arrow_downward),
                    ),
                  ),
              ],
            ),
          ),
          ChatInput(
            onSend: _sendMessage,
            onAttachmentPressed: _handleAttachment,
            onTyping: _handleTypingStatus,
            focusNode: _focusNode,
            controller: _messageController,
          ),
        ],
      ),
    );
  }

  String get currentUserId {
    // Get the current user ID from auth provider
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    return authProvider.currentUser?.id ?? 'anonymous';
  }
}
