import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/group.dart';
import '../models/message.dart';
import 'connection_service.dart';
import 'chat_service_v3.dart';
import 'encryption_service.dart';

/// Enhanced Group Chat Service integrated with ChatServiceV3 and ConnectionService
class GroupChatService extends ChangeNotifier {
  late ChatServiceV3 _chatService;
  late EncryptionService _encryption;
  
  // Map of groupId -> Group
  final Map<String, Group> _groups = {};
  
  // Map of groupId -> List of messages
  final Map<String, List<Message>> _groupMessages = {};
  
  // Map of groupId -> unread count
  final Map<String, int> _groupUnreadCounts = {};
  
  // Subscription to incoming messages
  StreamSubscription? _messageSubscription;

  GroupChatService(ChatServiceV3 chatService) : _chatService = chatService {
    _encryption = EncryptionService();
  }

  /// Initialize group chat service
  Future<void> initialize() async {
    print('🎯 [GroupChatService] Initializing...');
    try {
      await _encryption.initialize();
      print('✅ [GroupChatService] Encryption initialized');
      
      // Listen for incoming group messages
      _setupMessageListener();
      print('✅ [GroupChatService] Message listener setup complete');
    } catch (e) {
      print('❌ [GroupChatService] Error during initialization: $e');
      rethrow;
    }
  }

  /// Setup listener for incoming group messages
  void _setupMessageListener() {
    print('🎯 [GroupChatService] Setting up message listener...');
    _messageSubscription = ConnectionService.instance.incomingMessages.listen((msg) {
      final type = msg['type']?.toString() ?? '';
      if (type == 'group_message') {
        _handleIncomingGroupMessage(msg);
      } else if (type == 'group_created' || type == 'group_updated') {
        _handleGroupUpdate(msg);
      } else if (type == 'group_member_joined' || type == 'group_member_left') {
        _handleGroupMemberChange(msg);
      }
    });
  }

  /// Create a new group with selected members
  Future<Group> createGroup({
    required String groupName,
    required List<String> memberIds,
    String? description,
  }) async {
    try {
      final currentUserId = ConnectionService.instance.currentUserId;
      if (currentUserId == null) {
        throw Exception('Not authenticated');
      }

      final groupId = const Uuid().v4();
      final timestamp = DateTime.now();
      
      // Include creator in members
      final allMembers = {...memberIds, currentUserId}.toList();

      print('🎯 [GroupChatService] Creating group: $groupName with members: ${allMembers.length}');

      // Create group locally
      final group = Group(
        id: groupId,
        name: groupName,
        description: description,
        memberIds: allMembers,
        createdBy: currentUserId,
        createdAt: timestamp,
      );

      // Store locally
      _groups[groupId] = group;
      _groupMessages[groupId] = [];
      _groupUnreadCounts[groupId] = 0;

      // Send to server
      final payload = {
        'type': 'group_create',
        'groupId': groupId,
        'groupName': groupName,
        'description': description ?? '',
        'memberIds': allMembers,
        'createdBy': currentUserId,
        'timestamp': timestamp.toIso8601String(),
      };

      print('🎯 [GroupChatService] Sending group_create payload...');
      ConnectionService.instance.sendMessage(payload);
      print('✅ [GroupChatService] Group created: $groupId');

      notifyListeners();
      return group;
    } catch (e) {
      print('❌ [GroupChatService] Error creating group: $e');
      rethrow;
    }
  }

  /// Send message to group
  Future<void> sendGroupMessage({
    required String groupId,
    required String messageText,
  }) async {
    try {
      final currentUserId = ConnectionService.instance.currentUserId;
      if (currentUserId == null) {
        throw Exception('Not authenticated');
      }

      if (messageText.trim().isEmpty) {
        print('⚠️ [GroupChatService] Message is empty');
        return;
      }

      final messageId = const Uuid().v4();
      final timestamp = DateTime.now();

      // Create message locally
      final message = Message(
        id: messageId,
        senderId: currentUserId,
        receiverId: groupId,  // Group ID as receiver
        text: messageText,
        timestamp: timestamp,
        status: MessageStatus.sent,
        type: MessageType.text,
      );

      // Add to memory
      if (!_groupMessages.containsKey(groupId)) {
        _groupMessages[groupId] = [];
      }
      _groupMessages[groupId]!.add(message);

      print('🎯 [GroupChatService] Sending group message to $groupId: "$messageText"');

      // Prepare payload
      final payload = {
        'type': 'group_message',
        'groupId': groupId,
        'from': currentUserId,
        'message': messageText,
        'timestamp': timestamp.toIso8601String(),
      };

      // Try to encrypt
      Map<String, dynamic> transmitPayload = payload;
      try {
        print('🎯 [GroupChatService] Encrypting group message...');
        final contentToEncrypt = {
          'message': messageText,
          'timestamp': timestamp.toIso8601String(),
        };
        final encrypted = _encryption.encryptJson(contentToEncrypt);
        transmitPayload = {
          'type': 'group_message',
          'groupId': groupId,
          'from': currentUserId,
          'iv': encrypted['iv'],
          'ciphertext': encrypted['ciphertext'],
          '__encrypted': true,
        };
        print('✅ [GroupChatService] Group message encrypted');
      } catch (e) {
        print('⚠️ [GroupChatService] Encryption failed: $e, sending plaintext');
      }

      // Send via WebSocket
      ConnectionService.instance.sendMessage(transmitPayload);
      print('✅ [GroupChatService] Group message sent to $groupId');

      notifyListeners();
    } catch (e) {
      print('❌ [GroupChatService] Error sending group message: $e');
      rethrow;
    }
  }

  /// Handle incoming group message
  void _handleIncomingGroupMessage(Map<String, dynamic> msg) {
    try {
      final groupId = msg['groupId']?.toString() ?? '';
      final from = msg['from']?.toString() ?? '';
      String messageText = '';
      
      final currentUserId = ConnectionService.instance.currentUserId;
      final isMine = from == currentUserId;

      // Check if encrypted
      final isEncrypted = msg['__encrypted'] == true || (msg.containsKey('iv') && msg.containsKey('ciphertext'));

      if (isEncrypted) {
        try {
          print('🎯 [GroupChatService] Decrypting group message from $from...');
          final decrypted = _encryption.decryptJson(msg);
          messageText = decrypted['message']?.toString() ?? '';
          print('✅ [GroupChatService] Group message decrypted');
        } catch (e) {
          print('⚠️ [GroupChatService] Failed to decrypt group message: $e');
          messageText = '[Encrypted message - decryption failed]';
        }
      } else {
        messageText = msg['message']?.toString() ?? '';
        print('🎯 [GroupChatService] Plaintext group message received');
      }

      if (groupId.isEmpty || from.isEmpty || messageText.isEmpty) return;

      final timestamp = msg['timestamp'] != null
          ? DateTime.tryParse(msg['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now();

      // Create message
      final message = Message(
        id: const Uuid().v4(),
        senderId: from,
        receiverId: groupId,
        text: messageText,
        timestamp: timestamp,
        status: MessageStatus.delivered,
        type: MessageType.text,
      );

      // Add to memory
      if (!_groupMessages.containsKey(groupId)) {
        _groupMessages[groupId] = [];
      }
      _groupMessages[groupId]!.add(message);

      // Track unread if not from me
      if (!isMine) {
        _groupUnreadCounts[groupId] = (_groupUnreadCounts[groupId] ?? 0) + 1;
      }

      print('📨 [GroupChatService] Group message received from $from in group $groupId');
      notifyListeners();
    } catch (e) {
      print('❌ [GroupChatService] Error handling incoming group message: $e');
    }
  }

  /// Handle group updates (created, updated)
  void _handleGroupUpdate(Map<String, dynamic> msg) {
    try {
      final groupId = msg['groupId']?.toString() ?? '';
      final groupName = msg['groupName']?.toString() ?? 'Group';
      final memberIds = List<String>.from(msg['memberIds'] as List? ?? []);
      
      final group = Group(
        id: groupId,
        name: groupName,
        memberIds: memberIds,
        createdBy: msg['createdBy']?.toString() ?? '',
        createdAt: msg['createdAt'] != null 
            ? DateTime.tryParse(msg['createdAt'].toString()) ?? DateTime.now()
            : DateTime.now(),
      );

      _groups[groupId] = group;
      print('🎯 [GroupChatService] Group updated: $groupId - $groupName (${memberIds.length} members)');
      notifyListeners();
    } catch (e) {
      print('❌ [GroupChatService] Error handling group update: $e');
    }
  }

  /// Handle group member changes
  void _handleGroupMemberChange(Map<String, dynamic> msg) {
    try {
      final type = msg['type']?.toString() ?? '';
      final groupId = msg['groupId']?.toString() ?? '';
      final userId = msg['userId']?.toString() ?? '';
      
      final group = _groups[groupId];
      if (group != null) {
        if (type == 'group_member_joined') {
          if (!group.memberIds.contains(userId)) {
            group.memberIds.add(userId);
            print('🎯 [GroupChatService] Member joined: $userId joined group $groupId');
          }
        } else if (type == 'group_member_left') {
          group.memberIds.remove(userId);
          print('🎯 [GroupChatService] Member left: $userId left group $groupId');
        }
        notifyListeners();
      }
    } catch (e) {
      print('❌ [GroupChatService] Error handling group member change: $e');
    }
  }

  /// Get all groups
  List<Group> getAllGroups() => _groups.values.toList();

  /// Get group by ID
  Group? getGroup(String groupId) => _groups[groupId];

  /// Get messages for group
  List<Message> getGroupMessages(String groupId) => _groupMessages[groupId] ?? [];

  /// Get unread count for group
  int getGroupUnreadCount(String groupId) => _groupUnreadCounts[groupId] ?? 0;

  /// Mark group messages as read
  void markGroupAsRead(String groupId) {
    _groupUnreadCounts[groupId] = 0;
    notifyListeners();
  }

  /// Add member to group
  Future<void> addMemberToGroup(String groupId, String userId) async {
    try {
      final payload = {
        'type': 'group_add_member',
        'groupId': groupId,
        'userId': userId,
      };
      ConnectionService.instance.sendMessage(payload);
      print('🎯 [GroupChatService] Adding member $userId to group $groupId');
    } catch (e) {
      print('❌ [GroupChatService] Error adding member: $e');
      rethrow;
    }
  }

  /// Leave group
  Future<void> leaveGroup(String groupId) async {
    try {
      final currentUserId = ConnectionService.instance.currentUserId;
      if (currentUserId == null) throw Exception('Not authenticated');

      final payload = {
        'type': 'group_leave',
        'groupId': groupId,
        'userId': currentUserId,
      };
      ConnectionService.instance.sendMessage(payload);
      
      _groups.remove(groupId);
      _groupMessages.remove(groupId);
      _groupUnreadCounts.remove(groupId);
      
      print('🎯 [GroupChatService] Left group $groupId');
      notifyListeners();
    } catch (e) {
      print('❌ [GroupChatService] Error leaving group: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    super.dispose();
  }
}
