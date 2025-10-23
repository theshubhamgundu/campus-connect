import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/message.dart';

class MessageRepository {
  static const String _messagesKey = 'cached_messages';
  final SharedPreferences _prefs;

  MessageRepository(this._prefs);

  // Save messages to local storage
  Future<void> saveMessages(String chatId, List<Message> messages) async {
    try {
      final messagesMap = {
        for (var msg in messages) msg.id: msg.toJson(),
      };
      await _prefs.setString('${_messagesKey}_$chatId', jsonEncode(messagesMap));
    } catch (e) {
      throw Exception('Failed to save messages: $e');
    }
  }

  // Load messages from local storage
  Future<List<Message>> loadMessages(String chatId) async {
    try {
      final messagesJson = _prefs.getString('${_messagesKey}_$chatId');
      if (messagesJson == null) return [];
      
      final messagesMap = Map<String, dynamic>.from(
        jsonDecode(messagesJson) as Map,
      );
      
      return messagesMap.values
          .map((msgJson) => Message.fromJson(msgJson))
          .toList();
    } catch (e) {
      throw Exception('Failed to load messages: $e');
    }
  }

  // Add a single message
  Future<void> addMessage(String chatId, Message message) async {
    try {
      final messages = await loadMessages(chatId);
      messages.add(message);
      await saveMessages(chatId, messages);
    } catch (e) {
      throw Exception('Failed to add message: $e');
    }
  }

  // Update message status
  Future<void> updateMessageStatus(
    String chatId, 
    String messageId, 
    MessageStatus status,
  ) async {
    try {
      final messages = await loadMessages(chatId);
      final index = messages.indexWhere((msg) => msg.id == messageId);
      if (index != -1) {
        messages[index] = messages[index].copyWith(status: status);
        await saveMessages(chatId, messages);
      }
    } catch (e) {
      throw Exception('Failed to update message status: $e');
    }
  }

  // Get message by ID
  Future<Message?> getMessage(String chatId, String messageId) async {
    try {
      final messages = await loadMessages(chatId);
      return messages.firstWhere((msg) => msg.id == messageId);
    } catch (e) {
      return null;
    }
  }

  // Clear all messages for a chat
  Future<void> clearChatHistory(String chatId) async {
    try {
      await _prefs.remove('${_messagesKey}_$chatId');
    } catch (e) {
      throw Exception('Failed to clear chat history: $e');
    }
  }

  // Get last message for a chat
  Future<Message?> getLastMessage(String chatId) async {
    try {
      final messages = await loadMessages(chatId);
      if (messages.isEmpty) return null;
      return messages.last;
    } catch (e) {
      return null;
    }
  }
}
