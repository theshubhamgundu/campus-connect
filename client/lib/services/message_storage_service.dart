import 'package:hive_flutter/hive_flutter.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/stored_message.dart';

/// Service for persistent message storage using Hive
class MessageStorageService {
  static final MessageStorageService _instance = MessageStorageService._internal();
  
  factory MessageStorageService() {
    return _instance;
  }
  
  MessageStorageService._internal();

  late Box<StoredMessage> _messagesBox;
  bool _initialized = false;

  /// Initialize Hive and open message box
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Initialize Hive with app documents directory
      await Hive.initFlutter('campusnet');
      
      // Register adapter for StoredMessage
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(StoredMessageAdapter());
      }

      // Open messages box
      _messagesBox = await Hive.openBox<StoredMessage>('messages');
      _initialized = true;
      
      print('✅ MessageStorageService initialized');
    } catch (e) {
      print('❌ Error initializing MessageStorageService: $e');
      rethrow;
    }
  }

  /// Save a message to local storage
  Future<void> saveMessage(StoredMessage message) async {
    try {
      await _messagesBox.add(message);
      print('💾 Message saved: ${message.fromUserId} → ${message.toUserId}');
    } catch (e) {
      print('❌ Error saving message: $e');
    }
  }

  /// Get all messages for a conversation (between two users)
  List<StoredMessage> getConversation(String userA, String userB) {
    try {
      final convId = StoredMessage.getConversationId(userA, userB);
      
      final messages = _messagesBox.values.where((msg) {
        final msgConvId = StoredMessage.getConversationId(msg.fromUserId, msg.toUserId);
        return msgConvId == convId;
      }).toList();
      
      // Sort by timestamp ascending
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      
      return messages;
    } catch (e) {
      print('❌ Error loading conversation: $e');
      return [];
    }
  }

  /// Get all unique conversations (list of user IDs I've chatted with)
  List<String> getAllConversationPartners(String currentUserId) {
    try {
      final partners = <String>{};
      
      for (final msg in _messagesBox.values) {
        if (msg.fromUserId == currentUserId) {
          partners.add(msg.toUserId);
        } else if (msg.toUserId == currentUserId) {
          partners.add(msg.fromUserId);
        }
      }
      
      return partners.toList();
    } catch (e) {
      print('❌ Error getting conversation partners: $e');
      return [];
    }
  }

  /// Get last message for a conversation
  StoredMessage? getLastMessage(String userA, String userB) {
    try {
      final conversation = getConversation(userA, userB);
      return conversation.isEmpty ? null : conversation.last;
    } catch (e) {
      print('❌ Error getting last message: $e');
      return null;
    }
  }

  /// Clear all messages (for testing/logout)
  Future<void> clearAll() async {
    try {
      await _messagesBox.clear();
      print('🗑️  All messages cleared');
    } catch (e) {
      print('❌ Error clearing messages: $e');
    }
  }

  /// Clear specific conversation
  Future<void> clearConversation(String userA, String userB) async {
    try {
      final convId = StoredMessage.getConversationId(userA, userB);
      final keysToDelete = <int>[];
      
      int index = 0;
      for (final msg in _messagesBox.values) {
        final msgConvId = StoredMessage.getConversationId(msg.fromUserId, msg.toUserId);
        if (msgConvId == convId) {
          keysToDelete.add(index);
        }
        index++;
      }
      
      for (final key in keysToDelete.reversed) {
        await _messagesBox.deleteAt(key);
      }
      
      print('🗑️  Conversation cleared: $userA ↔ $userB');
    } catch (e) {
      print('❌ Error clearing conversation: $e');
    }
  }

  /// Get conversation count for analytics
  int getConversationCount() {
    return _messagesBox.length;
  }
}
