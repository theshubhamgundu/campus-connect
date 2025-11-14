import 'package:uuid/uuid.dart';

enum UserRole { student, faculty, admin }

class User {
  final String id;
  final String userId; // Student ID or Faculty ID
  final String name;
  final String? email;
  final String? department;
  final UserRole role;
  final String? avatarUrl;
  final bool isOnline;
  final String? ipAddress;
  final DateTime? lastSeen;

  bool get isFaculty => role == UserRole.faculty;
  bool get isAdmin => role == UserRole.admin;

  User({
    String? id,
    required this.userId,
    required this.name,
    this.email,
    this.department,
    required this.role,
    this.avatarUrl,
    this.isOnline = false,
    this.ipAddress,
    this.lastSeen,
  }) : id = id ?? const Uuid().v4();

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String?,
      userId: json['userId'] as String? ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown User',
      email: json['email'] as String?,
      department: json['department'] as String?,
      role: _roleFromString(json['role'] as String?),
      avatarUrl: json['avatarUrl'] as String?,
      isOnline: json['isOnline'] as bool? ?? false,
      ipAddress: json['ipAddress'] as String?,
      lastSeen: json['lastSeen'] != null ? DateTime.tryParse(json['lastSeen'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'email': email,
      'department': department,
      'role': _roleToString(role),
      'avatarUrl': avatarUrl,
      'isOnline': isOnline,
      'ipAddress': ipAddress,
      'lastSeen': lastSeen?.toIso8601String(),
    };
  }

  User copyWith({
    String? name,
    String? email,
    String? department,
    UserRole? role,
    String? avatarUrl,
    bool? isOnline,
    String? ipAddress,
    DateTime? lastSeen,
  }) {
    return User(
      id: id,
      userId: userId,
      name: name ?? this.name,
      email: email ?? this.email,
      department: department ?? this.department,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isOnline: isOnline ?? this.isOnline,
      ipAddress: ipAddress ?? this.ipAddress,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  static UserRole _roleFromString(String? role) {
    if (role == null) return UserRole.student;
    switch (role.toLowerCase()) {
      case 'faculty':
        return UserRole.faculty;
      case 'admin':
        return UserRole.admin;
      case 'student':
      default:
        return UserRole.student;
    }
  }

  static String _roleToString(UserRole role) {
    return role.toString().split('.').last;
  }

}
