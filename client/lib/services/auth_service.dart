import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:network_info_plus/network_info_plus.dart';
import '../models/user.dart';

class AuthService {
  static const String _userKey = 'current_user';
  static const String _tokenKey = 'auth_token';
  
  final NetworkInfo _networkInfo = NetworkInfo();
  User? _currentUser;
  String? _authToken;
  
  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();
  
  // Getters
  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  String? get authToken => _authToken;
  
  // Initialize service
  Future<void> initialize() async {
    await _loadSavedUser();
  }
  
  // Sign up a new user
  Future<User> signUp({
    required String userId,
    required String name,
    required UserRole role,
    String? email,
    String? department,
  }) async {
    try {
      // In a real app, this would make an API call to your local server
      final user = User(
        userId: userId,
        name: name,
        role: role,
        email: email,
        department: department,
        isOnline: true,
      );
      
      // Save user locally
      await _saveUser(user);
      _currentUser = user;
      
      // Generate and save auth token
      _authToken = 'generated_token_${DateTime.now().millisecondsSinceEpoch}';
      await _saveAuthToken(_authToken!);
      
      return user;
    } catch (e) {
      throw Exception('Failed to sign up: ${e.toString()}');
    }
  }
  
  // Log in user
  Future<User> login(String userId) async {
    try {
      // In a real app, this would verify credentials with your local server
      // For now, we'll just create a user if they don't exist
      if (_currentUser == null) {
        throw Exception('User not found. Please sign up first.');
      }
      
      // Update user as online
      _currentUser = _currentUser!.copyWith(isOnline: true);
      await _saveUser(_currentUser!);
      
      // Generate new auth token
      _authToken = 'generated_token_${DateTime.now().millisecondsSinceEpoch}';
      await _saveAuthToken(_authToken!);
      
      return _currentUser!;
    } catch (e) {
      throw Exception('Login failed: ${e.toString()}');
    }
  }
  
  // Log out user
  Future<void> logout() async {
    if (_currentUser != null) {
      // Update user as offline
      _currentUser = _currentUser!.copyWith(isOnline: false);
      await _saveUser(_currentUser!);
    }
    
    // Clear auth token
    _authToken = null;
    await _clearAuthToken();
    
    // Clear current user
    _currentUser = null;
  }
  
  // Discover nearby users on the same network
  Future<List<User>> discoverNearbyUsers() async {
    try {
      // Get local IP address
      final String? ip = await _networkInfo.getWifiIP();
      if (ip == null) {
        throw Exception('Not connected to Wi-Fi');
      }
      
      // In a real app, this would scan the local network for other CampusNet users
      // and return a list of discovered users
      // For now, we'll return an empty list
      return [];
    } catch (e) {
      throw Exception('Failed to discover nearby users: ${e.toString()}');
    }
  }
  
  // Search for users by ID, name, or department
  Future<List<User>> searchUsers(String query) async {
    try {
      // In a real app, this would query your local server
      // For now, we'll return an empty list
      return [];
    } catch (e) {
      throw Exception('Search failed: ${e.toString()}');
    }
  }
  
  // Send friend request
  Future<void> sendFriendRequest(String userId) async {
    try {
      // In a real app, this would send a friend request to the specified user
      // through your local server
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      throw Exception('Failed to send friend request: ${e.toString()}');
    }
  }
  
  // Accept friend request
  Future<void> acceptFriendRequest(String userId) async {
    try {
      // In a real app, this would accept the friend request
      // through your local server
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      throw Exception('Failed to accept friend request: ${e.toString()}');
    }
  }
  
  // Private helper methods
  Future<void> _loadSavedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_userKey);
      if (userJson != null) {
        _currentUser = User.fromJson(userJson);
      }
      _authToken = prefs.getString(_tokenKey);
    } catch (e) {
      debugPrint('Error loading saved user: $e');
    }
  }
  
  Future<void> _saveUser(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, jsonEncode(user.toJson()));
    } catch (e) {
      debugPrint('Error saving user: $e');
    }
  }
  
  Future<void> _saveAuthToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
    } catch (e) {
      debugPrint('Error saving auth token: $e');
    }
  }
  
  Future<void> _clearAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
    } catch (e) {
      debugPrint('Error clearing auth token: $e');
    }
  }
}

// Global instance
final authService = AuthService();
