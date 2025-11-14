import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/chat.dart';
import '../services/chat_service.dart';
import 'chat_screen.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatSearchDelegate extends SearchDelegate<String> {
  final List<Chat> chats;

  _ChatSearchDelegate(this.chats);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    final results = chats.where((chat) {
      return chat.title.toLowerCase().contains(query.toLowerCase()) ||
          (chat.lastMessageText?.toLowerCase().contains(query.toLowerCase()) ?? false);
    }).toList();

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final chat = results[index];
        return ListTile(
          title: Text(chat.title),
          subtitle: Text(chat.lastMessageText ?? ''),
          onTap: () {
            close(context, chat.id);
          },
        );
      },
    );
  }
}

class _ChatsScreenState extends State<ChatsScreen> {
  final List<Chat> _chats = [];
  bool _isLoading = true;
  String? _error;
  late ChatService _chatService;
  StreamSubscription? _chatsSubscription;

  @override
  void initState() {
    super.initState();
    _chatService = ChatService();
    _loadChats();
  }

  @override
  void dispose() {
    _chatsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadChats() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      _chatsSubscription = _chatService.watchChats().listen((chats) {
        if (mounted) {
          setState(() {
            _chats.clear();
            _chats.addAll(chats);
            _isLoading = false;
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load chats';
          _isLoading = false;
        });
      }
    }
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return DateFormat('MMM d, y').format(dateTime);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Widget _buildChatItem(Chat chat) {
    return ListTile(
      leading: CircleAvatar(
        child: Text(chat.title[0].toUpperCase()),
      ),
      title: Text(chat.title),
      subtitle: Text(
        chat.lastMessageText ?? 'No messages yet',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatTime(chat.lastMessageTimestamp),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (chat.unreadCount > 0)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${chat.unreadCount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      onTap: () {
        // TODO: Implement chat screen navigation
        // Navigator.push(
        //   context,
        //   MaterialPageRoute(
        //     builder: (context) => ChatScreen(chatId: chat.id),
        //   ),
        // );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: _ChatSearchDelegate(_chats),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _loadChats,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _chats.isEmpty
                  ? const Center(child: Text('No chats yet'))
                  : ListView.builder(
                      itemCount: _chats.length,
                      itemBuilder: (context, index) {
                        return _buildChatItem(_chats[index]);
                      },
                    ),
    );
  }
}
