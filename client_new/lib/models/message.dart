import 'package:meta/meta.dart';

enum MessageType { text, image, video, audio, file, location, contact }
enum MessageStatus { sending, sent, delivered, read, failed }

class Message {
  final String id;
  final String senderId;
  final String receiverId;
  final String text;
  final DateTime timestamp;
  MessageStatus status;
  final MessageType type;
  final String? replyToMessageId;
  final FileInfo? fileInfo;
  final Map<String, dynamic>? metadata;

  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.timestamp,
    this.status = MessageStatus.sent,
    this.type = MessageType.text,
    this.replyToMessageId,
    this.fileInfo,
    this.metadata,
  });

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id'],
        senderId: json['senderId'],
        receiverId: json['receiverId'],
        text: json['text'] ?? '',
        timestamp: DateTime.parse(json['timestamp']),
        status: MessageStatus.values.firstWhere(
          (e) => e.toString() == 'MessageStatus.${json['status']}',
          orElse: () => MessageStatus.sent,
        ),
        type: MessageType.values.firstWhere(
          (e) => e.toString() == 'MessageType.${json['type']}',
          orElse: () => MessageType.text,
        ),
        replyToMessageId: json['replyToMessageId'],
        fileInfo: json['fileInfo'] != null 
            ? FileInfo.fromJson(json['fileInfo']) 
            : null,
        metadata: json['metadata'] as Map<String, dynamic>?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'senderId': senderId,
        'receiverId': receiverId,
        'text': text,
        'timestamp': timestamp.toIso8601String(),
        'status': status.toString().split('.').last,
        'type': type.toString().split('.').last,
        if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
        if (fileInfo != null) 'fileInfo': fileInfo!.toJson(),
        if (metadata != null) 'metadata': metadata,
      };
}

class FileInfo {
  final String id;
  final String name;
  final int size;
  final String mimeType;
  final String? url;
  final String? localPath;
  final int? width;
  final int? height;
  final int? duration;
  final String? thumbnailUrl;

  FileInfo({
    required this.id,
    required this.name,
    required this.size,
    required this.mimeType,
    this.url,
    this.localPath,
    this.width,
    this.height,
    this.duration,
    this.thumbnailUrl,
  });

  factory FileInfo.fromJson(Map<String, dynamic> json) => FileInfo(
        id: json['id'],
        name: json['name'],
        size: json['size'],
        mimeType: json['mimeType'],
        url: json['url'],
        localPath: json['localPath'],
        width: json['width'],
        height: json['height'],
        duration: json['duration'],
        thumbnailUrl: json['thumbnailUrl'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'size': size,
        'mimeType': mimeType,
        if (url != null) 'url': url,
        if (localPath != null) 'localPath': localPath,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
        if (duration != null) 'duration': duration,
        if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      };
}
