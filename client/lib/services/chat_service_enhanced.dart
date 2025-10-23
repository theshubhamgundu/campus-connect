import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/message.dart';
import '../repositories/message_repository.dart';
import 'websocket_service.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final WebSocketService _webSocketService = WebSocketService();
  final Map<String, StreamController<Message>> _messageControllers = {};
  final Map<String, StreamController<FileTransfer>> _fileTransferControllers = {};
  late final MessageRepository _messageRepository;
  bool _isInitialized = false;

  // Initialize the chat service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    final prefs = await SharedPreferences.getInstance();
    _messageRepository = MessageRepository(prefs);
    
    await _webSocketService.initialize();
    
    // Listen for incoming messages
    _webSocketService.addListener(WebSocketService.eventMessage, (data) async {
      final message = Message.fromJson(data);
      await _handleIncomingMessage(message);
    });

    // Listen for message status updates
    _webSocketService.addListener('message_status', (data) async {
      final messageId = data['messageId'] as String;
      final status = MessageStatus.values.firstWhere(
        (e) => e.toString() == 'MessageStatus.${data['status']}',
        orElse: () => MessageStatus.sent,
      );
      
      // Update message status in all relevant chat streams
      for (final controller in _messageControllers.values) {
        final message = controller.value?.firstWhere(
          (m) => m.id == messageId,
          orElse: () => null,
        );
        
        if (message != null) {
          final updatedMessage = message.copyWith(status: status);
          controller.add(updatedMessage);
          
          // Update in local storage
          final chatId = _getChatId(message.senderId, message.receiverId);
          await _messageRepository.updateMessageStatus(
            chatId, 
            messageId, 
            status,
          );
        }
      }
    });

    _isInitialized = true;
  }

  // Send a text message
  Future<Message> sendTextMessage({
    required String senderId,
    required String receiverId,
    required String text,
    String? replyToMessageId,
  }) async {
    final message = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: senderId,
      receiverId: receiverId,
      text: text,
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
      type: MessageType.text,
      replyToMessageId: replyToMessageId,
    );

    // Add to local storage immediately
    final chatId = _getChatId(senderId, receiverId);
    await _messageRepository.addMessage(chatId, message);
    
    // Update UI
    _getOrCreateMessageController(chatId).add(message);

    try {
      // Send via WebSocket
      await _webSocketService.send(
        WebSocketService.eventMessage,
        message.toJson(),
      );
      
      // Update status to sent
      final sentMessage = message.copyWith(status: MessageStatus.sent);
      await _messageRepository.updateMessageStatus(
        chatId, 
        message.id, 
        MessageStatus.sent,
      );
      _getOrCreateMessageController(chatId).add(sentMessage);
      
      return sentMessage;
    } catch (e) {
      // Update status to failed
      final failedMessage = message.copyWith(status: MessageStatus.failed);
      await _messageRepository.updateMessageStatus(
        chatId, 
        message.id, 
        MessageStatus.failed,
      );
      _getOrCreateMessageController(chatId).add(failedMessage);
      rethrow;
    }
  }

  // Send a file message
  Future<Message> sendFile({
    required String senderId,
    required String receiverId,
    required File file,
    String? replyToMessageId,
  }) async {
    final fileInfo = FileInfo(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: path.basename(file.path),
      size: await file.length(),
      mimeType: _getMimeType(file.path),
      localPath: file.path,
    );

    final message = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: senderId,
      receiverId: receiverId,
      text: 'Sending file: ${fileInfo.name}',
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
      type: _getMessageType(fileInfo.mimeType),
      replyToMessageId: replyToMessageId,
      fileInfo: fileInfo,
    );

    // Add to local storage immediately
    final chatId = _getChatId(senderId, receiverId);
    await _messageRepository.addMessage(chatId, message);
    _getOrCreateMessageController(chatId).add(message);

    try {
      // In a real app, you would upload the file to your server here
      // For now, we'll simulate a successful upload after a delay
      await Future.delayed(const Duration(seconds: 1));
      
      // Update with the server URL
      final uploadedFileInfo = fileInfo.copyWith(
        url: 'https://example.com/files/${fileInfo.id}',
      );
      
      final sentMessage = message.copyWith(
        status: MessageStatus.sent,
        fileInfo: uploadedFileInfo,
      );
      
      await _messageRepository.updateMessageStatus(
        chatId, 
        message.id, 
        MessageStatus.sent,
      );
      
      _getOrCreateMessageController(chatId).add(sentMessage);
      return sentMessage;
    } catch (e) {
      final failedMessage = message.copyWith(status: MessageStatus.failed);
      await _messageRepository.updateMessageStatus(
        chatId, 
        message.id, 
        MessageStatus.failed,
      );
      _getOrCreateMessageController(chatId).add(failedMessage);
      rethrow;
    }
  }

  // Download a file
  Future<File> downloadFile(FileInfo fileInfo) async {
    if (fileInfo.localPath != null && File(fileInfo.localPath!).existsSync()) {
      return File(fileInfo.localPath!);
    }

    if (fileInfo.url == null) {
      throw Exception('No download URL available for this file');
    }

    final response = await http.get(Uri.parse(fileInfo.url!));
    if (response.statusCode != 200) {
      throw Exception('Failed to download file: ${response.statusCode}');
    }

    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/${fileInfo.id}_${fileInfo.name}';
    final file = File(filePath);
    await file.writeAsBytes(response.bodyBytes);

    return file;
  }

  // Get message stream for a chat
  Stream<List<Message>> getMessageStream(String userId, String otherUserId) async* {
    final chatId = _getChatId(userId, otherUserId);
    
    // First, load from local storage
    final localMessages = await _messageRepository.loadMessages(chatId);
    if (localMessages.isNotEmpty) {
      yield localMessages;
    }
    
    // Then stream updates
    yield* _getOrCreateMessageController(chatId).stream;
  }

  // Mark messages as read
  Future<void> markAsRead(String userId, String otherUserId, List<String> messageIds) async {
    final chatId = _getChatId(userId, otherUserId);
    
    // Update local storage
    for (final messageId in messageIds) {
      await _messageRepository.updateMessageStatus(
        chatId, 
        messageId, 
        MessageStatus.read,
      );
    }
    
    // Notify server
    await _webSocketService.send('mark_read', {
      'messageIds': messageIds,
      'chatId': chatId,
    });
  }

  // Handle incoming message
  Future<void> _handleIncomingMessage(Message message) async {
    final chatId = _getChatId(message.senderId, message.receiverId);
    
    // Save to local storage
    await _messageRepository.addMessage(chatId, message);
    
    // Update UI
    _getOrCreateMessageController(chatId).add(message);
    
    // If it's a file message, start downloading in the background
    if (message.type != MessageType.text && message.fileInfo?.url != null) {
      _downloadFileInBackground(message);
    }
  }

  // Download file in background
  Future<void> _downloadFileInBackground(Message message) async {
    try {
      if (message.fileInfo?.url == null || message.fileInfo?.localPath != null) {
        return;
      }
      
      final file = await downloadFile(message.fileInfo!);
      
      // Update message with local path
      final updatedInfo = message.fileInfo!.copyWith(localPath: file.path);
      final updatedMessage = message.copyWith(fileInfo: updatedInfo);
      
      // Update in local storage
      final chatId = _getChatId(message.senderId, message.receiverId);
      await _messageRepository.addMessage(chatId, updatedMessage);
      
      // Update UI
      _getOrCreateMessageController(chatId).add(updatedMessage);
    } catch (e) {
      // Silently fail - we'll retry when the user tries to open the file
      debugPrint('Failed to download file in background: $e');
    }
  }

  // Helper methods
  String _getChatId(String userId1, String userId2) {
    final ids = [userId1, userId2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  String _getMimeType(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        'image/png';
      case 'gif':
        return 'image/gif';
      case 'mp4':
        return 'video/mp4';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
      case 'docx':
        return 'application/msword';
      case 'xls':
      case 'xlsx':
        return 'application/vnd.ms-excel';
      case 'ppt':
      case 'pptx':
        return 'application/vnd.ms-powerpoint';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  MessageType _getMessageType(String mimeType) {
    if (mimeType.startsWith('image/')) {
      return MessageType.image;
    } else if (mimeType.startsWith('video/')) {
      return MessageType.video;
    } else if (mimeType.startsWith('audio/')) {
      return MessageType.audio;
    } else {
      return MessageType.file;
    }
  }

  StreamController<Message> _getOrCreateMessageController(String chatId) {
    if (!_messageControllers.containsKey(chatId)) {
      _messageControllers[chatId] = StreamController<Message>.broadcast();
    }
    return _messageControllers[chatId]!;
  }

  // Clean up
  void dispose() {
    for (final controller in _messageControllers.values) {
      controller.close();
    }
    _messageControllers.clear();
  }
}
