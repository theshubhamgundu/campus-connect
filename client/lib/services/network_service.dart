import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class NetworkService {
  static const String _serviceType = '_campusnet._tcp';
  static const int _port = 8083;
  
  final NetworkInfo _networkInfo = NetworkInfo();
  HttpServer? _discoveryServer;
  List<User> _discoveredUsers = [];
  
  // Singleton pattern
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();
  
  // Start the local network discovery service
  Future<void> startDiscoveryService() async {
    try {
      // In a real app, this would start a mDNS service for discovery
      // For now, we'll just simulate it
      developer.log('Starting network discovery service...', name: 'NetworkService');
      
      // Get local IP address
      final ip = await _networkInfo.getWifiIP();
      if (ip == null) {
        throw Exception('Not connected to Wi-Fi');
      }
      
      developer.log('Local IP: $ip', name: 'NetworkService');
      
    } catch (e) {
      developer.log('Failed to start discovery service: $e', name: 'NetworkService');
      rethrow;
    }
  }
  
  // Discover other users on the local network
  Future<List<User>> discoverUsers() async {
    try {
      // In a real app, this would scan the local network for other CampusNet users
      // For now, we'll simulate finding some users
      return [
        User(
          userId: 'STU1001',
          name: 'John Doe',
          role: UserRole.student,
          department: 'Computer Science',
          isOnline: true,
        ),
        User(
          userId: 'FAC2001',
          name: 'Dr. Smith',
          role: UserRole.faculty,
          department: 'Computer Science',
          isOnline: true,
        ),
      ];
    } catch (e) {
      developer.log('Failed to discover users: $e', name: 'NetworkService');
      rethrow;
    }
  }
  
  // Send a friend request to another user
  Future<bool> sendFriendRequest(User user, String message) async {
    try {
      // In a real app, this would send a request to the other user's device
      // For now, we'll just simulate it
      developer.log('Sending friend request to ${user.name} (${user.userId})', name: 'NetworkService');
      await Future.delayed(const Duration(seconds: 1));
      return true;
    } catch (e) {
      developer.log('Failed to send friend request: $e', name: 'NetworkService');
      return false;
    }
  }
  
  // Accept a friend request
  Future<bool> acceptFriendRequest(String requestId) async {
    try {
      // In a real app, this would accept the friend request
      developer.log('Accepting friend request: $requestId', name: 'NetworkService');
      await Future.delayed(const Duration(seconds: 1));
      return true;
    } catch (e) {
      developer.log('Failed to accept friend request: $e', name: 'NetworkService');
      return false;
    }
  }
  
  // Get the local IP address
  Future<String?> getLocalIpAddress() async {
    try {
      return await _networkInfo.getWifiIP();
    } catch (e) {
      developer.log('Failed to get local IP address: $e', name: 'NetworkService');
      return null;
    }
  }
  
  // Clean up resources
  Future<void> dispose() async {
    await _discoveryServer?.close();
    _discoveryServer = null;
  }
}

// Global instance
final networkService = NetworkService();
