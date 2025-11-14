import 'package:flutter/material.dart';
import 'user.dart';
import 'message.dart';

class Group {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final List<String> memberIds;
  final List<User> members;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final String createdBy;
  final DateTime? updatedAt;
  final Message? lastMessage;
  final int unreadCount;
  final bool isPrivate;

  Group({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    required this.memberIds,
    List<User>? members,
    this.metadata,
    DateTime? createdAt,
    required this.createdBy,
    this.updatedAt,
    this.lastMessage,
    this.unreadCount = 0,
    this.isPrivate = false,
  }) : members = members ?? [],
       createdAt = createdAt ?? DateTime.now();

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
      memberIds: List<String>.from((json['memberIds'] as List<dynamic>?)?.map((e) => e.toString()) ?? []),
      members: (json['members'] as List<dynamic>?)
          ?.map((member) => User.fromJson(member as Map<String, dynamic>))
          .toList() ?? [],
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'] as String) : null,
      createdBy: json['createdBy'] as String? ?? '',
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'] as String) : null,
      lastMessage: json['lastMessage'] != null ? Message.fromJson(json['lastMessage']) : null,
      unreadCount: json['unreadCount'] ?? 0,
      isPrivate: json['isPrivate'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (description != null) 'description': description,
      if (imageUrl != null) 'imageUrl': imageUrl,
      'memberIds': memberIds,
      if (metadata != null) 'metadata': metadata,
      'createdAt': createdAt.toIso8601String(),
      'createdBy': createdBy,
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      if (lastMessage != null) 'lastMessage': lastMessage!.toJson(),
      'unreadCount': unreadCount,
      'isPrivate': isPrivate,
    };
  }

  Group copyWith({
    String? id,
    String? name,
    String? description,
    String? imageUrl,
    List<String>? memberIds,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    String? createdBy,
    DateTime? updatedAt,
    Message? lastMessage,
    int? unreadCount,
    bool? isPrivate,
  }) {
    return Group(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      memberIds: memberIds ?? this.memberIds,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      updatedAt: updatedAt ?? this.updatedAt,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      isPrivate: isPrivate ?? this.isPrivate,
    );
  }

  // Helper methods
  bool isMember(String userId) => memberIds.contains(userId);
  
  bool get hasUnread => unreadCount > 0;
  
  String get displayName => name;
  
  String get subtitle {
    if (lastMessage != null) {
      return '${lastMessage!.senderName}: ${lastMessage!.content}';
    }
    return description ?? '${memberIds.length} members';
  }
  
  String get timeAgo {
    if (lastMessage == null) return '';
    final now = DateTime.now();
    final difference = now.difference(lastMessage!.timestamp);
    
    if (difference.inDays > 7) {
      return '${(difference.inDays / 7).floor()}w';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'Now';
    }
  }
}
