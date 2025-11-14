class OnlineUser {
  final String userId;
  final String name;
  final String role;
  final String ip;

  OnlineUser({required this.userId, required this.name, required this.role, required this.ip});

  factory OnlineUser.fromJson(Map<String, dynamic> json) {
    return OnlineUser(
      userId: json['userId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      ip: json['ip']?.toString() ?? '',
    );
  }
}
