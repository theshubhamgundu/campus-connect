import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/group.dart';
import '../../models/message.dart';
import '../../services/group_service.dart';
import '../../widgets/chat/message_bubble.dart';
import '../../widgets/chat/chat_input.dart';
import 'group_members_screen.dart';

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
  StreamSubscription? _messagesSubscription;
  StreamSubscription? _typingSubscription;
  Map<String, bool> _typingUsers = {};
  bool _showScrollToBottom = false;
  final FocusNode _focusNode = FocusNode();
  final GlobalKey _messageListKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _scrollController.addListener(_onScroll);
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _messageController.dispose();
    _messagesSubscription?.cancel();
    _typingSubscription?.cancel();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      // User stopped typing
      _sendTypingStatus(false);
    }
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.offset;
      
      setState(() {
        _showScrollToBottom = currentScroll < maxScroll - 100;
      });

      // Load older messages when near the top
      if (_scrollController.position.pixels < 200) {
        _loadOlderMessages();
      }
    }
  }

  Future<void> _loadMessages() async {
    final groupService = Provider.of<GroupService>(context, listen: false);
    
    try {
      // Load initial batch of messages
      final messages = await groupService.loadMessages(
        widget.group.id,
        limit: 50,
      );
      
      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoading = false;
        });
        _scrollToBottom(animate: false);
      }

      // Listen for new messages
      _messagesSubscription = groupService
          .watchMessages(widget.group.id)
          .listen((messages) {
        if (mounted) {
          setState(() {
            _messages = messages;
          });
          _scrollToBottom();
        }
      });

      // Listen for typing indicators
      _typingSubscription = groupService
          .watchTypingStatus(widget.group.id)
          .listen((typingUsers) {
        if (mounted) {
          setState(() {
            _typingUsers = typingUsers;
          });
        }
      });

      // Mark messages as read
      _markMessagesAsRead();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showError('Failed to load messages');
      }
    }
  }

  Future<void> _loadOlderMessages() async {
    if (_isLoading || _messages.isEmpty) return;

    final groupService = Provider.of<GroupService>(context, listen: false);
    final firstMessage = _messages.first;
    
    try {
      setState(() {
        _isLoading = true;
      });

      final olderMessages = await groupService.loadMessages(
        widget.group.id,
        limit: 20,
        beforeMessageId: firstMessage.id,
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

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty || _isSending) return;

    final groupService = Provider.of<GroupService>(context, listen: false);
    
    setState(() {
      _isSending = true;
    });

    try {
      await groupService.sendMessage(
        groupId: widget.group.id,
        content: messageText,
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _markMessagesAsRead() async {
    final unreadMessages = _messages
        .where((msg) => !msg.isRead && msg.senderId != currentUserId)
        .toList();

    if (unreadMessages.isNotEmpty) {
      final groupService = Provider.of<GroupService>(context, listen: false);
      await groupService.markAsRead(
        widget.group.id,
        unreadMessages.map((msg) => msg.id).toList(),
      );
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
                Clipboard.setData(ClipboardData(text: message.content));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Message copied')),
                );
              },
            ),
            if (message.senderId == currentUserId)
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Delete'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(message);
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

  Future<void> _deleteMessage(Message message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text('Are you sure you want to delete this message?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'DELETE',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final groupService = Provider.of<GroupService>(context, listen: false);
        await groupService.deleteMessage(widget.group.id, message.id);
      } catch (e) {
        _showError('Failed to delete message');
      }
    }
  }

  void _handleTypingStatus(bool isTyping) {
    _sendTypingStatus(isTyping);
  }

  void _sendTypingStatus(bool isTyping) {
    final groupService = Provider.of<GroupService>(context, listen: false);
    groupService.sendTypingStatus(widget.group.id, isTyping);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.group.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (_typingUsers.isNotEmpty)
              Text(
                _getTypingText(),
                style: theme.textTheme.bodySmall,
              )
            else
              StreamBuilder<int?>(
                stream: Stream.periodic(const Duration(seconds: 30)),
                builder: (context, _) {
                  final onlineCount = 1; // Replace with actual online count
                  return Text(
                    '${widget.group.memberIds.length} members • $onlineCount online',
                    style: theme.textTheme.bodySmall,
                  );
                },
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.people),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GroupMembersScreen(group: widget.group),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'info':
                  // TODO: Show group info
                  break;
                case 'media':
                  // TODO: Show shared media
                  break;
                case 'mute':
                  // TODO: Mute notifications
                  break;
                case 'exit':
                  // TODO: Exit group
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'info',
                child: Text('Group Info'),
              ),
              const PopupMenuItem(
                value: 'media',
                child: Text('Shared Media'),
              ),
              const PopupMenuItem(
                value: 'mute',
                child: Text('Mute Notifications'),
              ),
              const PopupMenuItem(
                value: 'exit',
                child: Text('Exit Group', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading && _messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.forum_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No messages yet',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Send a message to start the conversation',
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : Stack(
                        children: [
                          GestureDetector(
                            onTap: () {
                              // Dismiss keyboard when tapping on messages
                              FocusScope.of(context).unfocus();
                            },
                            child: ListView.builder(
                              key: _messageListKey,
                              controller: _scrollController,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: _messages.length,
                              itemBuilder: (context, index) {
                                final message = _messages[index];
                                final isMe = message.senderId == currentUserId;
                                final showAvatar = index == 0 ||
                                    _messages[index - 1].senderId !=
                                        message.senderId;
                                final showTime = index == _messages.length - 1 ||
                                    _messages[index + 1].senderId !=
                                        message.senderId;

                                return MessageBubble(
                                  message: message,
                                  isMe: isMe,
                                  showAvatar: showAvatar,
                                  showTime: showTime,
                                  onLongPress: () => _showMessageOptions(message),
                                );
                              },
                            ),
                          ),
                          if (_showScrollToBottom)
                            Positioned(
                              right: 16,
                              bottom: 16,
                              child: FloatingActionButton.small(
                                onPressed: _scrollToBottom,
                                child: const Icon(Icons.arrow_downward),
                              ),
                            ),
                        ],
                      ),
          ),
          ChatInput(
            controller: _messageController,
            onSend: _sendMessage,
            onAttachment: _handleAttachment,
            onTyping: _handleTypingStatus,
            focusNode: _focusNode,
            isSending: _isSending,
          ),
        ],
      ),
    );
  }
}

// TODO: Replace with actual current user ID
String get currentUserId => 'current-user-id';
