class UserInfo {
  final String userId;
  final String name;
  final String role;
  final String ip;

  UserInfo({required this.userId, required this.name, required this.role, required this.ip});

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      userId: json['userId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      ip: json['ip']?.toString() ?? '',
    );
  }
}
