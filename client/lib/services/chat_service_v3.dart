import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/message.dart';
import '../models/stored_message.dart';
import 'connection_service.dart';
import 'message_storage_service.dart';
import 'encryption_service.dart';
import 'package:uuid/uuid.dart';

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

/// Enhanced ChatService with encryption, persistence, and file support
class ChatServiceV3 extends ChangeNotifier {
  // Map of conversationId -> List of messages
  final Map<String, List<Message>> _conversations = {};

  // Map of userId -> user name (enrichment for UI)
  final Map<String, String> _userNames = {};

  // Track unread counts per conversation
  final Map<String, int> _unreadCounts = {};

  // Reference to persistent storage
  final _storage = MessageStorageService();

  // Reference to encryption service
  final _encryption = EncryptionService();

  const ChatServiceV3();

  /// Generate a conversation ID from two user IDs (order-independent)
  static String conversationIdFor(String userA, String userB) {
    final ids = [userA, userB]..sort();
    return ids.join('_');
  }

  /// Initialize by loading persisted messages and setting up WebSocket listener
  Future<void> initialize() async {
    try {
      // Initialize encryption
      await _encryption.initialize();
      print('✅ Encryption initialized');

      // Initialize storage
      await _storage.initialize();
      print('✅ Storage initialized');

      // Load all stored conversations into memory
      final currentUserId = ConnectionService.instance.currentUserId;
      if (currentUserId != null) {
        await _loadStoredConversations(currentUserId);
        print('✅ ChatServiceV3: Loaded stored conversations into memory');
      }

      // Set up WebSocket listener for incoming messages
      ConnectionService.instance.incomingMessages.listen((msg) {
        final type = msg['type']?.toString() ?? '';
        if (type == 'chat_message') {
          _handleIncomingChatMessage(msg);
        } else if (type == 'file_message') {
          _handleIncomingFileMessage(msg);
        } else if (type == 'call_offer' || type == 'call_answer' || type == 'call_reject' || type == 'call_end') {
          _handleCallEvent(msg);
        }
      });
    } catch (e) {
      debugPrint('Error initializing ChatServiceV3: $e');
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
            type: stored.messageType == 'file' ? MessageType.file : MessageType.text,
            metadata: stored.metadata,
          );
        }).toList();

        _conversations[convId] = messages;
      }

      notifyListeners();
      print('💾 Loaded ${_conversations.length} conversations from storage');
    } catch (e) {
      debugPrint('Error loading stored conversations: $e');
    }
  }

  /// Handle incoming chat message from WebSocket (encrypted)
  void _handleIncomingChatMessage(Map<String, dynamic> msg) {
    try {
      final from = msg['from']?.toString() ?? '';
      final to = msg['to']?.toString() ?? '';
      String text = '';
      String messageId = const Uuid().v4();

      final currentUserId = ConnectionService.instance.currentUserId;
      final isMine = from == currentUserId;

      // Decrypt if encrypted
      if (EncryptionService.isEncrypted(msg)) {
        try {
          final decrypted = _encryption.decryptJson(msg);
          text = decrypted['text']?.toString() ?? '';
        } catch (e) {
          debugPrint('⚠️ Failed to decrypt message: $e');
          text = '[Encrypted message - decryption failed]';
        }
      } else {
        text = msg['message']?.toString() ?? msg['text']?.toString() ?? '';
      }

      if (from.isEmpty || to.isEmpty || text.isEmpty) return;

      final timestamp = msg['timestamp'] != null
          ? DateTime.tryParse(msg['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now();

      // Create message model
      final message = Message(
        id: messageId,
        senderId: from,
        receiverId: to,
        text: text,
        timestamp: timestamp,
        status: MessageStatus.delivered,
        type: MessageType.text,
      );

      // Add to memory
      addMessage(message);

      // Persist to Hive (decrypted for display)
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

      print('📨 Message received: $from → $to');
    } catch (e) {
      debugPrint('Error handling incoming chat message: $e');
    }
  }

  /// Handle incoming file message
  void _handleIncomingFileMessage(Map<String, dynamic> msg) {
    try {
      final from = msg['from']?.toString() ?? '';
      final to = msg['to']?.toString() ?? '';
      final fileName = msg['fileName']?.toString() ?? 'file';
      final fileType = msg['fileType']?.toString() ?? 'application/octet-stream';
      final currentUserId = ConnectionService.instance.currentUserId;
      final isMine = from == currentUserId;

      if (from.isEmpty || to.isEmpty) return;

      String fileDataBase64 = '';

      // Decrypt if encrypted
      if (EncryptionService.isEncrypted(msg)) {
        try {
          final decrypted = _encryption.decryptJson(msg);
          fileDataBase64 = decrypted['fileData']?.toString() ?? '';
        } catch (e) {
          debugPrint('⚠️ Failed to decrypt file: $e');
        }
      } else {
        fileDataBase64 = msg['fileData']?.toString() ?? '';
      }

      if (fileDataBase64.isEmpty) return;

      final timestamp = msg['timestamp'] != null
          ? DateTime.tryParse(msg['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now();

      // Create message with file metadata
      final message = Message(
        id: const Uuid().v4(),
        senderId: from,
        receiverId: to,
        text: '📎 $fileName',
        timestamp: timestamp,
        status: MessageStatus.delivered,
        type: MessageType.file,
        metadata: {
          'fileName': fileName,
          'fileType': fileType,
          'fileData': fileDataBase64, // Store base64 encoded decrypted data
        },
      );

      addMessage(message);

      // Persist to Hive
      final stored = StoredMessage(
        id: message.id,
        fromUserId: from,
        toUserId: to,
        text: '📎 $fileName',
        timestamp: timestamp,
        isMine: isMine,
        messageType: 'file',
        metadata: {
          'fileName': fileName,
          'fileType': fileType,
          'fileData': fileDataBase64,
        },
      );
      _storage.saveMessage(stored);

      // Track unread
      if (!isMine) {
        final convId = conversationIdFor(from, to);
        _unreadCounts[convId] = (_unreadCounts[convId] ?? 0) + 1;
        notifyListeners();
      }

      print('📁 File received: $fileName from $from');
    } catch (e) {
      debugPrint('Error handling file message: $e');
    }
  }

  /// Handle call events
  void _handleCallEvent(Map<String, dynamic> msg) {
    try {
      final type = msg['type']?.toString() ?? '';
      final from = msg['from']?.toString() ?? '';
      final to = msg['to']?.toString() ?? '';

      if (from.isEmpty || to.isEmpty) return;

      // Call events are handled by CallService, just log here
      print('📞 Call event: $type from $from to $to');
    } catch (e) {
      debugPrint('Error handling call event: $e');
    }
  }

  /// Send a text message (encrypted)
  Future<void> sendMessage({
    required String toUserId,
    required String messageText,
  }) async {
    try {
      if (messageText.trim().isEmpty) return;

      final currentUserId = ConnectionService.instance.currentUserId;
      if (currentUserId == null) {
        throw Exception('Not authenticated');
      }

      final messageId = const Uuid().v4();
      final timestamp = DateTime.now();

      // Create message locally first
      final message = Message(
        id: messageId,
        senderId: currentUserId,
        receiverId: toUserId,
        text: messageText,
        timestamp: timestamp,
        status: MessageStatus.pending,
        type: MessageType.text,
      );

      // Add to memory immediately for UI
      addMessage(message);

      // Persist to Hive
      final stored = StoredMessage(
        id: messageId,
        fromUserId: currentUserId,
        toUserId: toUserId,
        text: messageText,
        timestamp: timestamp,
        isMine: true,
        messageType: 'text',
      );
      await _storage.saveMessage(stored);

      // Prepare payload for transmission
      final payload = {
        'type': 'chat_message',
        'from': currentUserId,
        'to': toUserId,
        'message': messageText,
        'timestamp': timestamp.toIso8601String(),
      };

      // Encrypt the payload
      final encrypted = _encryption.encryptJson(payload);
      final transmitPayload = {
        'type': 'chat_message',
        'from': currentUserId,
        'to': toUserId,
        'iv': encrypted['iv'],
        'ciphertext': encrypted['ciphertext'],
        'timestamp': timestamp.toIso8601String(),
      };

      // Send via WebSocket
      ConnectionService.instance.sendMessage(transmitPayload);

      print('✉️ Message sent (encrypted): $currentUserId → $toUserId');
    } catch (e) {
      debugPrint('Error sending message: $e');
    }
  }

  /// Send a file message (encrypted)
  Future<void> sendFile({
    required String toUserId,
    required String fileName,
    required String fileType,
    required String fileDataBase64,
  }) async {
    try {
      final currentUserId = ConnectionService.instance.currentUserId;
      if (currentUserId == null) {
        throw Exception('Not authenticated');
      }

      final messageId = const Uuid().v4();
      final timestamp = DateTime.now();

      // Create message locally first
      final message = Message(
        id: messageId,
        senderId: currentUserId,
        receiverId: toUserId,
        text: '📎 $fileName',
        timestamp: timestamp,
        status: MessageStatus.pending,
        type: MessageType.file,
        metadata: {
          'fileName': fileName,
          'fileType': fileType,
          'fileData': fileDataBase64,
        },
      );

      addMessage(message);

      // Persist to Hive
      final stored = StoredMessage(
        id: messageId,
        fromUserId: currentUserId,
        toUserId: toUserId,
        text: '📎 $fileName',
        timestamp: timestamp,
        isMine: true,
        messageType: 'file',
        metadata: {
          'fileName': fileName,
          'fileType': fileType,
          'fileData': fileDataBase64,
        },
      );
      await _storage.saveMessage(stored);

      // Prepare payload
      final payload = {
        'type': 'file_message',
        'from': currentUserId,
        'to': toUserId,
        'fileName': fileName,
        'fileType': fileType,
        'fileData': fileDataBase64,
        'timestamp': timestamp.toIso8601String(),
      };

      // Encrypt
      final encrypted = _encryption.encryptJson(payload);
      final transmitPayload = {
        'type': 'file_message',
        'from': currentUserId,
        'to': toUserId,
        'fileName': fileName, // Send plaintext so recipient knows what file it is
        'fileType': fileType,
        'iv': encrypted['iv'],
        'ciphertext': encrypted['ciphertext'],
        'timestamp': timestamp.toIso8601String(),
      };

      // Send via WebSocket
      ConnectionService.instance.sendMessage(transmitPayload);

      print('📤 File sent (encrypted): $fileName to $toUserId');
    } catch (e) {
      debugPrint('Error sending file: $e');
    }
  }

  /// Add message to memory and notify listeners
  void addMessage(Message message) {
    final currentUserId = ConnectionService.instance.currentUserId;
    if (currentUserId == null) return;

    final convId = conversationIdFor(message.senderId, message.receiverId);
    _conversations.putIfAbsent(convId, () => []);
    _conversations[convId]!.add(message);
    notifyListeners();
  }

  /// Get messages for a conversation
  List<Message> messagesFor(String userA, String userB) {
    final convId = conversationIdFor(userA, userB);
    return _conversations[convId] ?? [];
  }

  /// Get all conversation summaries
  List<ConversationSummary> getConversationSummaries(String currentUserId) {
    final summaries = <ConversationSummary>[];

    for (final entry in _conversations.entries) {
      if (entry.value.isEmpty) continue;

      final messages = entry.value;
      final lastMsg = messages.last;
      final otherUserId = lastMsg.senderId == currentUserId ? lastMsg.receiverId : lastMsg.senderId;

      summaries.add(ConversationSummary(
        otherUserId: otherUserId,
        otherUserName: _userNames[otherUserId] ?? otherUserId,
        lastMessageText: lastMsg.text,
        lastMessageTime: lastMsg.timestamp,
        unreadCount: _unreadCounts[entry.key] ?? 0,
      ));
    }

    // Sort by last message time descending
    summaries.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
    return summaries;
  }

  /// Mark conversation as read
  void markAsRead(String userA, String userB) {
    final convId = conversationIdFor(userA, userB);
    _unreadCounts[convId] = 0;
    notifyListeners();
  }

  /// Update user name for enrichment
  void setUserName(String userId, String name) {
    _userNames[userId] = name;
    notifyListeners();
  }

  /// Clear all data (logout)
  Future<void> clearAll() async {
    _conversations.clear();
    _userNames.clear();
    _unreadCounts.clear();
    await _storage.clearAll();
    notifyListeners();
  }
}
