import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/group.dart';
import '../models/message.dart';
import '../config/server_config.dart';
import 'package:logger/logger.dart';
import 'dart:convert';

class GroupService {
  final WebSocketChannel _channel;
  final Logger _logger = Logger();
  final Map<String, Group> _groups = {};
  final Map<String, List<Message>> _groupMessages = {};
  final Map<String, StreamController<Group>> _groupControllers = {};
  final Map<String, StreamController<List<Message>>> _messageControllers = {};
  final String _userId;
  
  GroupService(this._channel, this._userId);
  
  // Initialize the service
  Future<void> initialize() async {
    await _loadCachedGroups();
    _setupMessageHandlers();
  }
  
  // Get a stream of groups
  Stream<Group> watchGroup(String groupId) {
    _groupControllers[groupId] ??= StreamController<Group>.broadcast();
    return _groupControllers[groupId]!.stream;
  }
  
  // Get a stream of messages for a group
  Stream<List<Message>> watchMessages(String groupId) {
    _messageControllers[groupId] ??= StreamController<List<Message>>.broadcast();
    return _messageControllers[groupId]!.stream;
  }
  
  // Create a new group
  Future<Group> createGroup({
    required String name,
    String? description,
    bool isPrivate = false,
    List<String> memberIds = const [],
  }) async {
    final requestId = DateTime.now().millisecondsSinceEpoch.toString();
    final completer = Completer<Group>();
    
    final subscription = _channel.stream.listen((message) {
      try {
        final data = jsonDecode(message);
        if (data['requestId'] == requestId) {
          subscription.cancel();
          if (data['error'] != null) {
            completer.completeError(Exception(data['error']['message']));
          } else {
            final group = Group.fromJson(data['group']);
            _updateGroup(group);
            completer.complete(group);
          }
        }
      } catch (e) {
        _logger.e('Error creating group', e);
        subscription.cancel();
        completer.completeError(e);
      }
    });
    
    _channel.sink.add(jsonEncode({
      'event': 'create_group',
      'requestId': requestId,
      'data': {
        'name': name,
        'description': description,
        'isPrivate': isPrivate,
        'memberIds': [...memberIds, _userId],
      },
    }));
    
    return completer.future;
  }
  
  // Send a message to a group
  Future<Message> sendMessage({
    required String groupId,
    required String content,
    MessageType type = MessageType.text,
    Map<String, dynamic>? metadata,
  }) async {
    final requestId = DateTime.now().millisecondsSinceEpoch.toString();
    final completer = Completer<Message>();
    
    final subscription = _channel.stream.listen((message) {
      try {
        final data = jsonDecode(message);
        if (data['requestId'] == requestId) {
          subscription.cancel();
          if (data['error'] != null) {
            completer.completeError(Exception(data['error']['message']));
          } else {
            final message = Message.fromJson(data['message']);
            _addMessage(groupId, message);
            completer.complete(message);
          }
        }
      } catch (e) {
        _logger.e('Error sending message', e);
        subscription.cancel();
        completer.completeError(e);
      }
    });
    
    _channel.sink.add(jsonEncode({
      'event': 'send_message',
      'requestId': requestId,
      'data': {
        'groupId': groupId,
        'content': content,
        'type': type.toString().split('.').last,
        'metadata': metadata,
      },
    }));
    
    return completer.future;
  }
  
  // Add a member to a group
  Future<void> addMember(String groupId, String userId) async {
    final requestId = DateTime.now().millisecondsSinceEpoch.toString();
    final completer = Completer<void>();
    
    final subscription = _channel.stream.listen((message) {
      try {
        final data = jsonDecode(message);
        if (data['requestId'] == requestId) {
          subscription.cancel();
          if (data['error'] != null) {
            completer.completeError(Exception(data['error']['message']));
          } else {
            final group = Group.fromJson(data['group']);
            _updateGroup(group);
            completer.complete();
          }
        }
      } catch (e) {
        _logger.e('Error adding member', e);
        subscription.cancel();
        completer.completeError(e);
      }
    });
    
    _channel.sink.add(jsonEncode({
      'event': 'add_member',
      'requestId': requestId,
      'data': {
        'groupId': groupId,
        'userId': userId,
      },
    }));
    
    return completer.future;
  }
  
  // Load more messages for a group
  Future<List<Message>> loadMoreMessages(String groupId, {int limit = 20, String? beforeMessageId}) async {
    final requestId = DateTime.now().millisecondsSinceEpoch.toString();
    final completer = Completer<List<Message>>();
    
    final subscription = _channel.stream.listen((message) {
      try {
        final data = jsonDecode(message);
        if (data['requestId'] == requestId) {
          subscription.cancel();
          if (data['error'] != null) {
            completer.completeError(Exception(data['error']['message']));
          } else {
            final messages = (data['messages'] as List)
                .map((m) => Message.fromJson(m))
                .toList();
            _addMessages(groupId, messages, atStart: true);
            completer.complete(messages);
          }
        }
      } catch (e) {
        _logger.e('Error loading messages', e);
        subscription.cancel();
        completer.completeError(e);
      }
    });
    
    _channel.sink.add(jsonEncode({
      'event': 'load_messages',
      'requestId': requestId,
      'data': {
        'groupId': groupId,
        'limit': limit,
        if (beforeMessageId != null) 'beforeMessageId': beforeMessageId,
      },
    }));
    
    return completer.future;
  }
  
  // Mark messages as read
  Future<void> markAsRead(String groupId, List<String> messageIds) async {
    _channel.sink.add(jsonEncode({
      'event': 'mark_read',
      'data': {
        'groupId': groupId,
        'messageIds': messageIds,
      },
    }));
  }
  
  // Delete a group
  Future<void> deleteGroup(String groupId) async {
    final requestId = DateTime.now().millisecondsSinceEpoch.toString();
    final completer = Completer<void>();
    
    final subscription = _channel.stream.listen((message) {
      try {
        final data = jsonDecode(message);
        if (data['requestId'] == requestId) {
          subscription.cancel();
          if (data['error'] != null) {
            completer.completeError(Exception(data['error']['message']));
          } else {
            _groups.remove(groupId);
            _groupMessages.remove(groupId);
            _groupControllers[groupId]?.close();
            _messageControllers[groupId]?.close();
            _saveGroupsToCache();
            completer.complete();
          }
        }
      } catch (e) {
        _logger.e('Error deleting group', e);
        subscription.cancel();
        completer.completeError(e);
      }
    });
    
    _channel.sink.add(jsonEncode({
      'event': 'delete_group',
      'requestId': requestId,
      'data': {
        'groupId': groupId,
      },
    }));
    
    return completer.future;
  }
  
  // Private methods
  void _setupMessageHandlers() {
    _channel.stream.listen((message) {
      try {
        final data = jsonDecode(message);
        
        switch (data['event']) {
          case 'group_updated':
            final group = Group.fromJson(data['group']);
            _updateGroup(group);
            break;
            
          case 'new_message':
            final message = Message.fromJson(data['message']);
            _addMessage(data['groupId'], message);
            break;
            
          case 'member_added':
            final group = Group.fromJson(data['group']);
            _updateGroup(group);
            break;
            
          case 'member_removed':
            final group = Group.fromJson(data['group']);
            _updateGroup(group);
            break;
        }
      } catch (e) {
        _logger.e('Error handling message', e);
      }
    });
  }
  
  void _updateGroup(Group group) {
    _groups[group.id] = group;
    _groupControllers[group.id]?.add(group);
    _saveGroupsToCache();
  }
  
  void _addMessage(String groupId, Message message) {
    _groupMessages[groupId] ??= [];
    _groupMessages[groupId]!.add(message);
    _messageControllers[groupId]?.add(_groupMessages[groupId]!);
    
    // Update last message in group
    final group = _groups[groupId];
    if (group != null) {
      _updateGroup(group.copyWith(
        lastMessage: message,
        unreadCount: group.unreadCount + 1,
      ));
    }
    
    _saveMessagesToCache();
  }
  
  void _addMessages(String groupId, List<Message> messages, {bool atStart = false}) {
    _groupMessages[groupId] ??= [];
    
    if (atStart) {
      _groupMessages[groupId]!.insertAll(0, messages);
    } else {
      _groupMessages[groupId]!.addAll(messages);
    }
    
    _messageControllers[groupId]?.add(_groupMessages[groupId]!);
    _saveMessagesToCache();
  }
  
  Future<void> _loadCachedGroups() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final groupsJson = prefs.getStringList('cached_groups') ?? [];
      
      for (final groupJson in groupsJson) {
        try {
          final group = Group.fromJson(jsonDecode(groupJson));
          _groups[group.id] = group;
        } catch (e) {
          _logger.e('Error parsing cached group', e);
        }
      }
      
      // Load cached messages
      final messagesJson = prefs.getString('cached_group_messages') ?? '{}';
      final messagesMap = jsonDecode(messagesJson) as Map<String, dynamic>;
      
      for (final entry in messagesMap.entries) {
        try {
          final messages = (entry.value as List)
              .map((m) => Message.fromJson(m))
              .toList();
          _groupMessages[entry.key] = messages;
        } catch (e) {
          _logger.e('Error parsing cached messages for group ${entry.key}', e);
        }
      }
    } catch (e) {
      _logger.e('Error loading cached data', e);
    }
  }
  
  Future<void> _saveGroupsToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final groupsJson = _groups.values
          .map((group) => jsonEncode(group.toJson()))
          .toList();
      await prefs.setStringList('cached_groups', groupsJson);
    } catch (e) {
      _logger.e('Error saving groups to cache', e);
    }
  }
  
  Future<void> _saveMessagesToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final messagesMap = <String, dynamic>{};
      
      _groupMessages.forEach((groupId, messages) {
        messagesMap[groupId] = messages.map((m) => m.toJson()).toList();
      });
      
      await prefs.setString('cached_group_messages', jsonEncode(messagesMap));
    } catch (e) {
      _logger.e('Error saving messages to cache', e);
    }
  }
  
  @override
  void dispose() {
    for (final controller in _groupControllers.values) {
      controller.close();
    }
    
    for (final controller in _messageControllers.values) {
      controller.close();
    }
    
    _saveGroupsToCache();
    _saveMessagesToCache();
  }
}
