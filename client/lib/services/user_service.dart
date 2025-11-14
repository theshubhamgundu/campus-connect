import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class UserService {
  static const String _usersKey = 'cached_users';
  
  Future<User?> getUser(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final usersJson = prefs.getString('${_usersKey}_$userId');
      
      if (usersJson != null) {
        final userMap = jsonDecode(usersJson);
        return User.fromJson(userMap);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user: $e');
      return null;
    }
  }

  Future<List<User>> searchUsers(String query) async {
    // In a real app, this would make an API call
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Return mock data for now
    return [
      User(
        userId: '1',
        name: 'John Doe',
        email: 'john@example.com',
        role: UserRole.student,
      ),
      User(
        userId: '2',
        name: 'Jane Smith',
        email: 'jane@example.com',
        role: UserRole.student,
      ),
    ].where((user) => 
      user.name.toLowerCase().contains(query.toLowerCase()) ||
      (user.email?.toLowerCase().contains(query.toLowerCase()) ?? false)
    ).toList();
  }

  Future<bool> saveUser(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(
        '${_usersKey}_${user.id}',
        jsonEncode(user.toJson()),
      );
    } catch (e) {
      debugPrint('Error saving user: $e');
      return false;
    }
  }

  Future<List<User>> getUsersByIds(List<String> userIds) async {
    final List<User> users = [];
    for (final userId in userIds) {
      final user = await getUser(userId);
      if (user != null) {
        users.add(user);
      }
    }
    return users;
  }
}
