import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'websocket_service.dart';
import '../models/message.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final WebSocketService _webSocketService = WebSocketService();
  final Map<String, StreamController<Message>> _messageControllers = {};
  final Map<String, StreamController<FileTransfer>> _fileTransferControllers = {};

  // Initialize the chat service
  Future<void> initialize() async {
    await _webSocketService.initialize();
    
    // Listen for incoming messages from server (type: 'message')
    _webSocketService.addListener('message', (data) {
      try {
        // If payload is already our client format
        if (data is Map<String, dynamic> && data.containsKey('senderId')) {
          final message = Message.fromJson(data as Map<String, dynamic>);
          _handleIncomingMessage(message);
          return;
        }
        // Server format: {type:'message', from, to, text, ts}
        final from = (data['from'] ?? '') as String;
        final to = (data['to'] ?? '') as String;
        final text = (data['text'] ?? '') as String;
        final ts = (data['ts'] ?? DateTime.now().toIso8601String()) as String;
        if (from.isEmpty || to.isEmpty) return;
        final msg = Message(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          senderId: from,
          receiverId: to,
          text: text,
          timestamp: DateTime.tryParse(ts) ?? DateTime.now(),
          status: MessageStatus.sent,
          type: MessageType.text,
        );
        _handleIncomingMessage(msg);
      } catch (_) {}
    });

    // Listen for file transfers
    _webSocketService.addListener('file_chunk', (data) {
      _handleFileChunk(data);
    });

    _webSocketService.addListener('file_complete', (data) {
      _handleFileComplete(data);
    });
  }

  // Send a text message
  Future<void> sendMessage({
    required String receiverId,
    required String text,
    String? replyToMessageId,
  }) async {
    final message = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: _webSocketService.userId!,
      receiverId: receiverId,
      text: text,
      timestamp: DateTime.now(),
      status: MessageStatus.sent,
      type: MessageType.text,
      replyToMessageId: replyToMessageId,
    );

    await _webSocketService.sendType('message', {
      'to': receiverId,
      'text': text,
    });

    // Update local state
    _handleIncomingMessage(message);
  }

  // Send a file
  Future<void> sendFile({
    required String receiverId,
    required String fileName,
    required Uint8List fileData,
    String? caption,
  }) async {
    final fileId = DateTime.now().millisecondsSinceEpoch.toString();
    final message = Message(
      id: fileId,
      senderId: _webSocketService.userId!,
      receiverId: receiverId,
      text: caption ?? '',
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
      type: MessageType.file,
      fileInfo: FileInfo(
        id: fileId,
        name: fileName,
        size: fileData.length,
        mimeType: _getMimeType(fileName),
      ),
    );

    // First, send the message with file metadata
    await _webSocketService.send(
      WebSocketService.eventMessage,
      message.toJson(),
    );

    // Then send the file in chunks
    await _webSocketService.sendFile(
      fileId,
      fileName,
      fileData,
      receiverId: receiverId,
      onProgress: (sent, total) {
        // Update progress in the UI
        final progress = (sent / total * 100).toInt();
        _updateFileTransferProgress(fileId, progress);
      },
    );

    // Update status to sent
    message.status = MessageStatus.sent;
    _handleIncomingMessage(message);
  }

  // Handle incoming messages
  void _handleIncomingMessage(Message message) {
    final chatId = _getChatId(message.senderId, message.receiverId);
    if (!_messageControllers.containsKey(chatId)) {
      _messageControllers[chatId] = StreamController<Message>.broadcast();
    }
    _messageControllers[chatId]!.add(message);
  }

  // Handle incoming calls
  void _handleIncomingCall(Call call) {
    final callId = call.id;
    if (!_callControllers.containsKey(callId)) {
      _callControllers[callId] = StreamController<Call>.broadcast();
    }
    _callControllers[callId]!.add(call);
  }

  // Handle file chunks
  void _handleFileChunk(Map<String, dynamic> data) {
    final fileId = data['fileId'] as String;
    final chunkIndex = data['chunkIndex'] as int;
    final totalChunks = data['totalChunks'] as int;
    final chunkData = base64Decode(data['data'] as String);

    if (!_fileTransferControllers.containsKey(fileId)) {
      _fileTransferControllers[fileId] = StreamController<FileTransfer>.broadcast();
    }

    _fileTransferControllers[fileId]!.add(FileTransfer(
      fileId: fileId,
      chunkIndex: chunkIndex,
      totalChunks: totalChunks,
      data: chunkData,
    ));
  }

  // Handle file transfer completion
  void _handleFileComplete(Map<String, dynamic> data) {
    final fileId = data['fileId'] as String;
    _fileTransferControllers[fileId]?.add(FileTransfer.complete(
      fileId: fileId,
      fileName: data['fileName'] as String,
      fileSize: data['fileSize'] as int,
    ));
  }

  // Update file transfer progress
  void _updateFileTransferProgress(String fileId, int progress) {
    if (_fileTransferControllers.containsKey(fileId)) {
      _fileTransferControllers[fileId]!.add(FileTransfer.progress(
        fileId: fileId,
        progress: progress,
      ));
    }
  }

  // Get message stream for a chat
  Stream<Message> getMessageStream(String userId, String otherUserId) {
    final chatId = _getChatId(userId, otherUserId);
    if (!_messageControllers.containsKey(chatId)) {
      _messageControllers[chatId] = StreamController<Message>.broadcast();
    }
    return _messageControllers[chatId]!.stream;
  }

  // Get file transfer stream
  Stream<FileTransfer> getFileTransferStream(String fileId) {
    if (!_fileTransferControllers.containsKey(fileId)) {
      _fileTransferControllers[fileId] = StreamController<FileTransfer>.broadcast();
    }
    return _fileTransferControllers[fileId]!.stream;
  }

  // Helper methods
  String _getChatId(String userId1, String userId2) {
    final parts = [userId1, userId2]..sort();
    return parts.join(':');
  }

  String _getMimeType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
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
      case 'mp3':
        return 'audio/mpeg';
      case 'mp4':
        return 'video/mp4';
      default:
        return 'application/octet-stream';
    }
  }

  // Clean up
  Future<void> dispose() async {
    for (final controller in _messageControllers.values) {
      await controller.close();
    }
    for (final controller in _callControllers.values) {
      await controller.close();
    }
    for (final controller in _fileTransferControllers.values) {
      await controller.close();
    }
    _messageControllers.clear();
    _callControllers.clear();
    _fileTransferControllers.clear();
    await _webSocketService.dispose();
  }
}
