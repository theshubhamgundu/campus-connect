import 'package:flutter/foundation.dart';
import '../models/message.dart';
import '../models/stored_message.dart';
import 'connection_service.dart';
import 'message_storage_service.dart';

/// Conversation summary for recent chats list
class ConversationSummary {
  final String otherUserId;
  final String otherUserName;
  final String lastMessageText;
  final DateTime lastMessageTime;
  final int unreadCount;

  ConversationSummary({
    required this.otherUserId,
    required this.otherUserName,
    required this.lastMessageText,
    required this.lastMessageTime,
    this.unreadCount = 0,
  });
}

/// Enhanced ChatService with central message storage and persistence
class ChatServiceV2 extends ChangeNotifier {
  // Map of conversationId -> List of messages
  final Map<String, List<Message>> _conversations = {};

  // Map of userId -> user name (enrichment for UI)
  final Map<String, String> _userNames = {};

  // Track unread counts per conversation
  final Map<String, int> _unreadCounts = {};
  
  // Reference to persistent storage
  final _storage = MessageStorageService();

  /// Generate a conversation ID from two user IDs (order-independent)
  static String conversationIdFor(String userA, String userB) {
    final ids = [userA, userB]..sort();
    return ids.join('_');
  }

  /// Initialize by loading persisted messages and setting up WebSocket listener
  Future<void> initialize() async {
    try {
      // Initialize storage
      await _storage.initialize();
      
      // Load all stored conversations into memory
      final currentUserId = ConnectionService.instance.currentUserId;
      if (currentUserId != null) {
        await _loadStoredConversations(currentUserId);
        print('✅ ChatServiceV2: Loaded stored conversations into memory');
      }
      
      // Set up WebSocket listener for incoming messages
      ConnectionService.instance.incomingMessages.listen((msg) {
        final type = msg['type']?.toString() ?? '';
        if (type == 'chat_message') {
          _handleIncomingChatMessage(msg);
        } else if (type == 'file_chunk') {
          _handleIncomingFileChunk(msg);
        } else if (type == 'call_request' || type == 'call_answer' || type == 'call_end') {
          _handleCallEvent(msg);
        }
      });
    } catch (e) {
      debugPrint('Error initializing ChatServiceV2: $e');
    }
  }

  /// Load all stored conversations from Hive into memory
  Future<void> _loadStoredConversations(String currentUserId) async {
    try {
      final partners = _storage.getAllConversationPartners(currentUserId);
      
      for (final partnerId in partners) {
        final storedMessages = _storage.getConversation(currentUserId, partnerId);
        final convId = conversationIdFor(currentUserId, partnerId);
        
        final messages = storedMessages.map((stored) {
          return Message(
            id: stored.id,
            senderId: stored.fromUserId,
            receiverId: stored.toUserId,
            text: stored.text,
            timestamp: stored.timestamp,
            status: MessageStatus.delivered,
            type: MessageType.text,
            metadata: stored.metadata,
          );
        }).toList();
        
        _conversations[convId] = messages;
      }
      
      print('💾 Loaded ${_conversations.length} conversations from storage');
    } catch (e) {
      debugPrint('Error loading stored conversations: $e');
    }
  }

  /// Handle incoming chat message from WebSocket
  void _handleIncomingChatMessage(Map<String, dynamic> msg) {
    try {
      final from = msg['from']?.toString() ?? '';
      final to = msg['to']?.toString() ?? '';
      final text = msg['message']?.toString() ?? '';
      final timestamp = msg['timestamp'] != null
          ? DateTime.tryParse(msg['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now();

      if (from.isEmpty || to.isEmpty) return;

      final currentUserId = ConnectionService.instance.currentUserId;
      final isMine = from == currentUserId;

      // Create message model
      final message = Message(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        senderId: from,
        receiverId: to,
        text: text,
        timestamp: timestamp,
        status: MessageStatus.delivered,
        type: MessageType.text,
      );

      // Add to memory
      addMessage(message);

      // Persist to Hive
      final stored = StoredMessage(
        id: message.id,
        fromUserId: from,
        toUserId: to,
        text: text,
        timestamp: timestamp,
        isMine: isMine,
        messageType: 'text',
      );
      _storage.saveMessage(stored);

      // Track unread if not from me
      if (!isMine) {
        final convId = conversationIdFor(from, to);
        _unreadCounts[convId] = (_unreadCounts[convId] ?? 0) + 1;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error handling incoming chat_message: $e');
    }
  }

  /// Handle incoming file chunk from WebSocket
  void _handleIncomingFileChunk(Map<String, dynamic> msg) {
    try {
      final from = msg['from']?.toString() ?? '';
      final to = msg['to']?.toString() ?? '';
      final fileName = msg['fileName']?.toString() ?? 'file';
      
      // For now, store as a file message
      // Actual file reassembly would happen in a file service
      final message = Message(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        senderId: from,
        receiverId: to,
        text: '[FILE] $fileName',
        timestamp: DateTime.now(),
        status: MessageStatus.delivered,
        type: MessageType.file,
        metadata: {'fileName': fileName},
      );

      addMessage(message);
      
      // Persist
      final stored = StoredMessage(
        id: message.id,
        fromUserId: from,
        toUserId: to,
        text: '[FILE] $fileName',
        timestamp: DateTime.now(),
        isMine: false,
        messageType: 'file',
        metadata: {'fileName': fileName},
      );
      _storage.saveMessage(stored);
    } catch (e) {
      debugPrint('Error handling file_chunk: $e');
    }
  }

  /// Handle call events (request, answer, end)
  void _handleCallEvent(Map<String, dynamic> msg) {
    try {
      final type = msg['type']?.toString() ?? '';
      final from = msg['from']?.toString() ?? '';
      final to = msg['to']?.toString() ?? '';
      
      // Create call event message
      final eventText = type == 'call_request'
          ? '[CALL] Incoming call'
          : type == 'call_answer'
              ? '[CALL] Call ${msg['accepted'] == true ? 'accepted' : 'rejected'}'
              : '[CALL] Call ended';

      final message = Message(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        senderId: from,
        receiverId: to,
        text: eventText,
        timestamp: DateTime.now(),
        status: MessageStatus.delivered,
        type: MessageType.text,
        metadata: {'callEvent': type, 'eventDetails': msg},
      );

      addMessage(message);
      
      // Persist
      final stored = StoredMessage(
        id: message.id,
        fromUserId: from,
        toUserId: to,
        text: eventText,
        timestamp: DateTime.now(),
        isMine: false,
        messageType: 'call_event',
        metadata: {'callEvent': type, 'eventDetails': msg},
      );
      _storage.saveMessage(stored);
    } catch (e) {
      debugPrint('Error handling call event: $e');
    }
  }

  /// Add a message to the conversation (for both sent and received)
  void addMessage(Message msg) {
    final convId = conversationIdFor(msg.senderId, msg.receiverId);
    if (!_conversations.containsKey(convId)) {
      _conversations[convId] = [];
    }
    _conversations[convId]!.add(msg);
    notifyListeners();
  }

  /// Get all messages for a conversation between two users
  List<Message> messagesFor(String userA, String userB) {
    final convId = conversationIdFor(userA, userB);
    return _conversations[convId] ?? [];
  }

  /// Get recent conversations (for ChatsScreen)
  List<ConversationSummary> get recentConversations {
    final summaries = <ConversationSummary>[];

    for (final entry in _conversations.entries) {
      final convId = entry.key;
      final messages = entry.value;

      if (messages.isEmpty) continue;

      final lastMsg = messages.last;
      final otherUserId =
          lastMsg.senderId == ConnectionService.instance.currentUserId
              ? lastMsg.receiverId
              : lastMsg.senderId;

      final summary = ConversationSummary(
        otherUserId: otherUserId,
        otherUserName: _userNames[otherUserId] ?? otherUserId,
        lastMessageText: lastMsg.text,
        lastMessageTime: lastMsg.timestamp,
        unreadCount: _unreadCounts[convId] ?? 0,
      );
      summaries.add(summary);
    }

    // Sort by timestamp descending (most recent first)
    summaries.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
    return summaries;
  }

  /// Mark all messages in a conversation as read
  void markAsRead(String userA, String userB) {
    final convId = conversationIdFor(userA, userB);
    _unreadCounts[convId] = 0;
    notifyListeners();
  }

  /// Enrich user info (store user name for later display)
  void setUserInfo(String userId, String userName) {
    _userNames[userId] = userName;
  }

  /// Send a message (creates local message, updates service, then sends via WebSocket)
  Future<void> sendMessage({
    required String toUserId,
    required String messageText,
  }) async {
    final currentUserId = ConnectionService.instance.currentUserId;
    if (currentUserId == null || currentUserId.isEmpty) {
      throw Exception('Current user not authenticated');
    }

    // Create local message immediately
    final message = Message(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      senderId: currentUserId,
      receiverId: toUserId,
      text: messageText,
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
      type: MessageType.text,
    );

    // Add to local storage
    addMessage(message);
    
    // Persist to Hive
    final stored = StoredMessage(
      id: message.id,
      fromUserId: currentUserId,
      toUserId: toUserId,
      text: messageText,
      timestamp: DateTime.now(),
      isMine: true,
      messageType: 'text',
    );
    await _storage.saveMessage(stored);

    // Send via WebSocket
    try {
      await ConnectionService.instance.sendChatMessage(toUserId, messageText);
      // Update status to sent (server will send back when delivered)
      message.status = MessageStatus.sent;
      notifyListeners();
    } catch (e) {
      message.status = MessageStatus.failed;
      notifyListeners();
      rethrow;
    }
  }

  /// Clear all conversations (for testing or logout)
  void clear() {
    _conversations.clear();
    _unreadCounts.clear();
    notifyListeners();
  }

  /// Get total unread count across all conversations
  int get totalUnreadCount {
    return _unreadCounts.values.fold(0, (sum, count) => sum + count);
  }
}
