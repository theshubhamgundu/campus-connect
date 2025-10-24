import 'package:meta/meta.dart';

enum CallType { audio, video }
enum CallStatus { ringing, ongoing, ended, missed, rejected, busy, failed }

class Call {
  final String id;
  final String callerId;
  final String receiverId;
  final CallType type;
  CallStatus status;
  final DateTime startTime;
  DateTime? endTime;
  final String? callSid; // For WebRTC or third-party services
  final Map<String, dynamic>? metadata;

  Call({
    required this.id,
    required this.callerId,
    required this.receiverId,
    required this.type,
    required this.status,
    required this.startTime,
    this.endTime,
    this.callSid,
    this.metadata,
  });

  Duration get duration => endTime != null 
      ? endTime!.difference(startTime)
      : DateTime.now().difference(startTime);

  bool get isIncoming => status == CallStatus.ringing;
  bool get isOutgoing => status != CallStatus.ringing;
  bool get isActive => status == CallStatus.ongoing;
  bool get isEnded => status == CallStatus.ended || 
                     status == CallStatus.missed || 
                     status == CallStatus.rejected ||
                     status == CallStatus.failed;

  factory Call.fromJson(Map<String, dynamic> json) => Call(
        id: json['id'],
        callerId: json['callerId'],
        receiverId: json['receiverId'],
        type: CallType.values.firstWhere(
          (e) => e.toString() == 'CallType.${json['type']}',
          orElse: () => CallType.audio,
        ),
        status: CallStatus.values.firstWhere(
          (e) => e.toString() == 'CallStatus.${json['status']}',
          orElse: () => CallStatus.ringing,
        ),
        startTime: DateTime.parse(json['startTime']),
        endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
        callSid: json['callSid'],
        metadata: json['metadata'] as Map<String, dynamic>?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'callerId': callerId,
        'receiverId': receiverId,
        'type': type.toString().split('.').last,
        'status': status.toString().split('.').last,
        'startTime': startTime.toIso8601String(),
        if (endTime != null) 'endTime': endTime!.toIso8601String(),
        if (callSid != null) 'callSid': callSid,
        if (metadata != null) 'metadata': metadata,
      };

  Call copyWith({
    String? id,
    String? callerId,
    String? receiverId,
    CallType? type,
    CallStatus? status,
    DateTime? startTime,
    DateTime? endTime,
    String? callSid,
    Map<String, dynamic>? metadata,
  }) {
    return Call(
      id: id ?? this.id,
      callerId: callerId ?? this.callerId,
      receiverId: receiverId ?? this.receiverId,
      type: type ?? this.type,
      status: status ?? this.status,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      callSid: callSid ?? this.callSid,
      metadata: metadata ?? this.metadata,
    );
  }
}
