import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import 'package:async/async.dart';

import '../models/group.dart';
import '../models/message.dart';
import '../models/user.dart';

class GroupService {
  final WebSocketChannel? _channel;
  final Logger _logger = Logger();
  final Map<String, Group> _groups = {};
  final Map<String, List<Message>> _groupMessages = {};
  final Map<String, StreamController<Group>> _groupControllers = {};
  final Map<String, StreamController<List<Message>>> _messageControllers = {};
  final Map<String, StreamSubscription<dynamic>> _subscriptions = {};
  final String _userId;
  
  GroupService(WebSocketChannel? channel, this._userId) : _channel = channel {
    if (_channel != null) {
      _setupMessageHandlers();
    }
  }
  
  // Initialize the service
  Future<void> initialize() async {
    await _loadCachedGroups();
    if (_channel != null) {
      _setupMessageHandlers();
    }
  }

  // Load cached groups from local storage
  Future<void> _loadCachedGroups() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedGroupsJson = prefs.getString('cached_groups');
      final cachedMessagesJson = prefs.getString('cached_messages');
      
      if (cachedGroupsJson != null) {
        final groupsList = jsonDecode(cachedGroupsJson) as List;
        for (final groupJson in groupsList) {
          try {
            final group = Group.fromJson(groupJson as Map<String, dynamic>);
            _groups[group.id] = group;
          } catch (e) {
            _logger.e('Error parsing cached group: $e');
          }
        }
        _logger.i('Loaded ${_groups.length} groups from cache');
      }
    } catch (e) {
      _logger.e('Error parsing cached groups: $e');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedMessagesJson = prefs.getString('cached_messages');
      if (cachedMessagesJson != null) {
        final messagesMap = jsonDecode(cachedMessagesJson) as Map<String, dynamic>;
        for (final groupId in messagesMap.keys) {
          try {
            final messagesList = (messagesMap[groupId] as List)
                .map((m) => Message.fromJson(m as Map<String, dynamic>))
                .toList();
            _groupMessages[groupId] = messagesList;
          } catch (e) {
            _logger.e('Error parsing messages for group $groupId: $e');
          }
        }
        _logger.i('Loaded messages for ${_groupMessages.length} groups from cache');
      }
    } catch (e) {
      _logger.e('Error parsing cached messages: $e');
    }
  }
  
  // Set up WebSocket message handlers
  void _setupMessageHandlers() {
    if (_channel == null) return;
    
    _subscriptions['main'] = _channel!.stream.listen(
      (message) {
        try {
          final data = jsonDecode(message);
          if (data['type'] == 'message') {
            final message = Message.fromJson(data['message'] as Map<String, dynamic>);
            _addMessageToGroup(data['groupId'] as String, [message]);
          } else if (data['type'] == 'group_updated') {
            final group = Group.fromJson(data['group']);
            _updateGroup(group);
          }
        } catch (e) {
          _logger.e('Error handling message: $e');
        }
      },
      onError: (error) => _logger.e('WebSocket error: $error'),
      onDone: () => _logger.i('WebSocket connection closed'),
    );
  }
  
  // Update a group in the local cache
  void _updateGroup(Group group) {
    _groups[group.id] = group;
    _groupControllers[group.id]?.add(group);
  }

  // Add messages to a group
  void _addMessageToGroup(String groupId, List<Message> messages) {
    if (!_groupMessages.containsKey(groupId)) {
      _groupMessages[groupId] = [];
    }
    _groupMessages[groupId]!.addAll(messages);
    _messageControllers[groupId]?.add(_groupMessages[groupId]!);
    
    // Update last message in group if we have messages
    if (messages.isNotEmpty) {
      final group = _groups[groupId];
      if (group != null) {
        _updateGroup(group.copyWith(
          lastMessage: messages.last,
          unreadCount: group.unreadCount + messages.length,
        ));
      }
    }
  }
  
  // Get a stream of all groups
  Stream<List<Group>> get groupStream {
    final controller = StreamController<List<Group>>.broadcast();
    
    // Initial value
    controller.add(_groups.values.toList());
    
    // Listen to updates
    final subscription = StreamGroup.merge(
      _groupControllers.values.map((c) => c.stream)
    ).listen((_) {
      if (!controller.isClosed) {
        controller.add(_groups.values.toList());
      }
    });
    
    // Clean up
    controller.onCancel = () {
      subscription.cancel();
    };
    
    return controller.stream;
  }
  
  // Get a stream for a specific group
  Stream<Group> watchGroup(String groupId) {
    _groupControllers[groupId] ??= StreamController<Group>.broadcast();
    return _groupControllers[groupId]!.stream;
  }
  
  // Get a stream of messages for a group
  Stream<List<Message>> watchMessages(String groupId) {
    _messageControllers[groupId] ??= StreamController<List<Message>>.broadcast();
    return _messageControllers[groupId]!.stream;
  }
  
  // Get user's groups
  Future<List<Group>> getUserGroups() async {
    if (_groups.isNotEmpty) {
      return _groups.values.toList();
    }
    
    // In a real app, this would fetch from the server
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Return empty list if no groups found
    return [];
  }
  
  // Delete a group
  Future<void> deleteGroup(String groupId) async {
    if (_channel == null) {
      _groups.remove(groupId);
      _groupMessages.remove(groupId);
      _groupControllers[groupId]?.close();
      _groupControllers.remove(groupId);
      _messageControllers[groupId]?.close();
      _messageControllers.remove(groupId);
      return;
    }
    
    final requestId = const Uuid().v4();
    final completer = Completer<void>();
    
    final subscription = _channel!.stream.listen((message) {
      try {
        final data = jsonDecode(message);
        if (data['requestId'] == requestId) {
          _subscriptions.remove(requestId)?.cancel();
          if (data['error'] != null) {
            completer.completeError(Exception(data['error']['message']));
          } else {
            _groups.remove(groupId);
            _groupMessages.remove(groupId);
            _groupControllers[groupId]?.close();
            _groupControllers.remove(groupId);
            _messageControllers[groupId]?.close();
            _messageControllers.remove(groupId);
            completer.complete();
          }
        }
      } catch (e) {
        _logger.e('Error in deleteGroup response', error: e);
        _subscriptions.remove(requestId)?.cancel();
        completer.completeError(e);
      }
    });
    
    _subscriptions[requestId] = subscription;
    
    _channel!.sink.add(jsonEncode({
      'event': 'delete_group',
      'requestId': requestId,
      'data': {'groupId': groupId},
    }));
    
    return completer.future;
  }
  
  // Create a new group
  Future<Group> createGroup({
    required String name,
    String? description,
    bool isPrivate = false,
    List<String> memberIds = const [],
    File? imageFile,
  }) async {
    if (_channel == null) {
      // Mock implementation for testing
      final newGroup = Group(
        id: const Uuid().v4(),
        name: name,
        description: description,
        memberIds: [...memberIds, _userId],
        members: [],
        createdAt: DateTime.now(),
        createdBy: _userId,
        isPrivate: isPrivate,
      );
      _updateGroup(newGroup);
      return newGroup;
    }

    final requestId = const Uuid().v4();
    final completer = Completer<Group>();
    
    final subscription = _channel!.stream.listen(
      (message) {
        try {
          final data = jsonDecode(message);
          if (data['requestId'] == requestId) {
            _subscriptions.remove(requestId)?.cancel();
            if (data['error'] != null) {
              completer.completeError(Exception(data['error']['message']));
            } else {
              final group = Group.fromJson(data['group'] as Map<String, dynamic>);
              _updateGroup(group);
              completer.complete(group);
            }
          }
        } catch (e) {
          _logger.e('Error creating group: $e');
          _subscriptions.remove(requestId)?.cancel();
          completer.completeError(e);
        }
      },
      onError: (error) {
        _logger.e('WebSocket error in createGroup: $error');
        _subscriptions.remove(requestId)?.cancel();
        completer.completeError(error);
      },
      cancelOnError: true,
    );
    
    _subscriptions[requestId] = subscription;
    
    _channel!.sink.add(jsonEncode({
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
  
  // Update an existing group
  Future<Group> updateGroup({
    required String groupId,
    required String name,
    String? description,
    bool? isPrivate,
    List<String>? members,
    File? imageFile,
  }) async {
    final existingGroup = _groups[groupId];
    if (existingGroup == null) {
      throw Exception('Group not found');
    }

    if (_channel == null) {
      // Mock implementation for testing
      final updatedGroup = existingGroup.copyWith(
        name: name,
        description: description ?? existingGroup.description,
        isPrivate: isPrivate ?? existingGroup.isPrivate,
        memberIds: members ?? existingGroup.memberIds,
        updatedAt: DateTime.now(),
      );
      
      _updateGroup(updatedGroup);
      return updatedGroup;
    }

    final requestId = const Uuid().v4();
    final completer = Completer<Group>();
    
    final subscription = _channel!.stream.listen(
      (message) {
        try {
          final data = jsonDecode(message);
          if (data['requestId'] == requestId) {
            _subscriptions.remove(requestId)?.cancel();
            if (data['error'] != null) {
              completer.completeError(Exception(data['error']['message']));
            } else {
              final group = Group.fromJson(data['group'] as Map<String, dynamic>);
              _updateGroup(group);
              completer.complete(group);
            }
          }
        } catch (e) {
          _logger.e('Error updating group: $e');
          _subscriptions.remove(requestId)?.cancel();
          completer.completeError(e);
        }
      },
      onError: (error) {
        _logger.e('WebSocket error in updateGroup: $error');
        _subscriptions.remove(requestId)?.cancel();
        completer.completeError(error);
      },
      cancelOnError: true,
    );
    
    _subscriptions[requestId] = subscription;
    
    _channel!.sink.add(jsonEncode({
      'event': 'update_group',
      'requestId': requestId,
      'data': {
        'groupId': groupId,
        'name': name,
        if (description != null) 'description': description,
        if (isPrivate != null) 'isPrivate': isPrivate,
        if (members != null) 'memberIds': members,
      },
    }));
    
    return completer.future;
  }

  // Get messages for a group
  Future<List<Message>> getMessages(String groupId, {int limit = 50}) async {
    if (_groupMessages.containsKey(groupId)) {
      return _groupMessages[groupId]!;
    }
    
    // Return empty list if no messages
    return [];
  }

  // Delete a message
  Future<void> deleteMessage(String groupId, String messageId) async {
    if (_channel == null) {
      if (_groupMessages.containsKey(groupId)) {
        _groupMessages[groupId]!.removeWhere((m) => m.id == messageId);
        _messageControllers[groupId]?.add(_groupMessages[groupId]!);
      }
      return;
    }
    
    final requestId = const Uuid().v4();
    final completer = Completer<void>();
    
    final subscription = _channel!.stream.listen(
      (message) {
        try {
          final data = jsonDecode(message);
          if (data['requestId'] == requestId) {
            _subscriptions.remove(requestId)?.cancel();
            if (data['error'] != null) {
              completer.completeError(Exception(data['error']['message']));
            } else {
              if (_groupMessages.containsKey(groupId)) {
                _groupMessages[groupId]!.removeWhere((m) => m.id == messageId);
                _messageControllers[groupId]?.add(_groupMessages[groupId]!);
              }
              completer.complete();
            }
          }
        } catch (e) {
          _logger.e('Error deleting message: $e');
          _subscriptions.remove(requestId)?.cancel();
          completer.completeError(e);
        }
      },
      onError: (error) => completer.completeError(error),
      cancelOnError: true,
    );
    
    _subscriptions[requestId] = subscription;
    
    _channel!.sink.add(jsonEncode({
      'event': 'delete_message',
      'requestId': requestId,
      'data': {'groupId': groupId, 'messageId': messageId},
    }));
    
    return completer.future;
  }

  // Send typing status
  void sendTypingStatus(String groupId, bool isTyping) {
    if (_channel == null) return;
    
    _channel!.sink.add(jsonEncode({
      'event': 'typing_status',
      'data': {
        'groupId': groupId,
        'isTyping': isTyping,
        'userId': _userId,
      },
    }));
  }

  // Leave a group
  Future<void> leaveGroup(String groupId) async {
    if (_channel == null) {
      _groups.remove(groupId);
      _groupMessages.remove(groupId);
      _groupControllers[groupId]?.close();
      _groupControllers.remove(groupId);
      _messageControllers[groupId]?.close();
      _messageControllers.remove(groupId);
      return;
    }
    
    final requestId = const Uuid().v4();
    final completer = Completer<void>();
    
    final subscription = _channel!.stream.listen(
      (message) {
        try {
          final data = jsonDecode(message);
          if (data['requestId'] == requestId) {
            _subscriptions.remove(requestId)?.cancel();
            if (data['error'] != null) {
              completer.completeError(Exception(data['error']['message']));
            } else {
              _groups.remove(groupId);
              _groupMessages.remove(groupId);
              _groupControllers[groupId]?.close();
              _groupControllers.remove(groupId);
              _messageControllers[groupId]?.close();
              _messageControllers.remove(groupId);
              completer.complete();
            }
          }
        } catch (e) {
          _logger.e('Error leaving group: $e');
          _subscriptions.remove(requestId)?.cancel();
          completer.completeError(e);
        }
      },
      onError: (error) => completer.completeError(error),
      cancelOnError: true,
    );
    
    _subscriptions[requestId] = subscription;
    
    _channel!.sink.add(jsonEncode({
      'event': 'leave_group',
      'requestId': requestId,
      'data': {'groupId': groupId},
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
    if (_channel == null) {
      // Mock implementation for testing
      final message = Message(
        id: const Uuid().v4(),
        senderId: _userId,
        receiverId: groupId, // Using groupId as receiverId for group messages
        text: content,
        timestamp: DateTime.now(),
        status: MessageStatus.sent,
        type: type,
        metadata: metadata,
      );
      _addMessageToGroup(groupId, [message]);
      return message;
    }

    final requestId = const Uuid().v4();
    final completer = Completer<Message>();
    
    final subscription = _channel!.stream.listen(
      (message) {
        try {
          final data = jsonDecode(message);
          if (data['requestId'] == requestId) {
            _subscriptions.remove(requestId)?.cancel();
            if (data['error'] != null) {
              completer.completeError(Exception(data['error']['message']));
            } else {
              final message = Message.fromJson(data['message'] as Map<String, dynamic>);
              _addMessageToGroup(groupId, [message]);
              completer.complete(message);
            }
          }
        } catch (e) {
          _logger.e('Error sending message: $e');
          _subscriptions.remove(requestId)?.cancel();
          completer.completeError(e);
        }
      },
      onError: (error) {
        _logger.e('WebSocket error in sendMessage: $error');
        _subscriptions.remove(requestId)?.cancel();
        completer.completeError(error);
      },
      cancelOnError: true,
    );
    
    _subscriptions[requestId] = subscription;
    
    _channel!.sink.add(jsonEncode({
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
    if (_channel == null) {
      // Mock implementation for testing
      final group = _groups[groupId];
      if (group != null) {
        final updatedGroup = group.copyWith(
          memberIds: [...group.memberIds, userId],
        );
        _updateGroup(updatedGroup);
      }
      return;
    }

    final requestId = const Uuid().v4();
    final completer = Completer<void>();
    
    final subscription = _channel!.stream.listen(
      (message) {
        try {
          final data = jsonDecode(message);
          if (data['requestId'] == requestId) {
            _subscriptions.remove(requestId)?.cancel();
            if (data['error'] != null) {
              completer.completeError(Exception(data['error']['message']));
            } else {
              final group = Group.fromJson(data['group'] as Map<String, dynamic>);
              _updateGroup(group);
              completer.complete();
            }
          }
        } catch (e) {
          _logger.e('Error adding member: $e');
          _subscriptions.remove(requestId)?.cancel();
          completer.completeError(e);
        }
      },
      onError: (error) {
        _logger.e('WebSocket error in addMember: $error');
        _subscriptions.remove(requestId)?.cancel();
        completer.completeError(error);
      },
      cancelOnError: true,
    );
    
    _subscriptions[requestId] = subscription;
    
    _channel!.sink.add(jsonEncode({
      'event': 'add_member',
      'requestId': requestId,
      'data': {
        'groupId': groupId,
        'userId': userId,
      },
    }));
    
    return completer.future;
  }
  
  // Load messages for a group
  Future<List<Message>> loadMessages(String groupId, {int limit = 50, int offset = 0}) async {
    if (_channel == null) {
      // Mock implementation for testing
      final messages = List<Message>.generate(10, (index) => Message(
        id: 'msg_$groupId-$index',
        senderId: 'user_$index',
        receiverId: groupId,
        text: 'Test message $index',
        timestamp: DateTime.now().subtract(Duration(hours: index)),
        status: MessageStatus.delivered,
      ));
      _addMessageToGroup(groupId, messages);
      return messages;
    }
      // In a real app, this would fetch messages from the server
      // For now, we'll return some dummy data
      final messages = List<Message>.generate(10, (index) => Message(
        id: 'msg_${groupId}_${offset + index}',
        senderId: 'user_${index % 3}',
        receiverId: groupId,
        text: 'Older message ${offset + index + 1}',
        timestamp: DateTime.now().subtract(Duration(hours: index)),
        status: MessageStatus.delivered,
      ));
      
      _addMessagesToGroup(groupId, messages);
      return messages;
  }

  // Load more messages for a group
  Future<List<Message>> loadMoreMessages(String groupId, {int limit = 20, String? beforeMessageId}) async {
    if (_channel == null) {
      // Mock implementation for testing
      final messages = List.generate(limit, (index) => Message(
        id: 'msg_${const Uuid().v4()}',
        text: 'Older message ${index + 1}',
        senderId: index % 2 == 0 ? _userId : 'user_${index + 1}',
        receiverId: groupId,
        type: MessageType.text,
        status: MessageStatus.delivered,
        timestamp: DateTime.now().subtract(Duration(hours: index + 1)),
      ));
      _addMessagesToGroup(groupId, messages, atStart: true);
      return messages;
    }

    final requestId = const Uuid().v4();
    final completer = Completer<List<Message>>();
    
    final subscription = _channel!.stream.listen(
      (message) {
        try {
          final data = jsonDecode(message);
          if (data['requestId'] == requestId) {
            _subscriptions.remove(requestId)?.cancel();
            if (data['error'] != null) {
              completer.completeError(Exception(data['error']['message']));
            } else {
              final messages = (data['messages'] as List)
                  .map((m) => Message.fromJson(m as Map<String, dynamic>))
                  .toList();
              _addMessagesToGroup(groupId, messages, atStart: true);
              completer.complete(messages);
            }
          }
        } catch (e) {
          _logger.e('Error loading messages: $e');
          _subscriptions.remove(requestId)?.cancel();
          completer.completeError(e);
        }
      },
      onError: (error) {
        _logger.e('WebSocket error in loadMoreMessages: $error');
        _subscriptions.remove(requestId)?.cancel();
        completer.completeError(error);
      },
      cancelOnError: true,
    );
    
    _subscriptions[requestId] = subscription;
    
    _channel!.sink.add(jsonEncode({
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
    if (_channel == null) {
      // Mock implementation for testing
      final group = _groups[groupId];
      if (group != null) {
        _updateGroup(group.copyWith(
          unreadCount: 0,
        ));
      }
      return;
    }

    _channel!.sink.add(jsonEncode({
      'event': 'mark_read',
      'data': {
        'groupId': groupId,
        'messageIds': messageIds,
      },
    }));
  }

  // Private methods
  void _addMessagesToGroup(String groupId, List<Message> messages, {bool atStart = false}) {
    _groupMessages[groupId] ??= [];
    
    if (atStart) {
      _groupMessages[groupId]!.insertAll(0, messages);
    } else {
      _groupMessages[groupId]!.addAll(messages);
    }
    
    _messageControllers[groupId]?.add(_groupMessages[groupId]!);
    _saveMessagesToCache();
  }
  
  Future<void> _saveGroupsToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final groupsList = _groups.values.map((group) => group.toJson()).toList();
      await prefs.setString('cached_groups', jsonEncode(groupsList));
      _logger.d('Saved ${groupsList.length} groups to cache');
    } catch (e) {
      _logger.e('Error saving groups to cache: $e');
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
      _logger.d('Saved messages for ${messagesMap.length} groups to cache');
    } catch (e) {
      _logger.e('Error saving messages to cache: $e');
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
