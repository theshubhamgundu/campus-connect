import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class ServerConfig {
  // Default configuration - using localhost for development
  static const String _defaultIp = '127.0.0.1';
  static const int _defaultPort = 8083;
  static const bool _defaultUseHttps = false;
  
  // Development mode detection - always true in debug mode
  static bool get isDevelopment => kDebugMode;
  
  // Development mode detection (kept for backward compatibility)
  static bool get isDevelopmentDebug {
    bool isDev = false;
    assert(() {
      isDev = true;
      return true;
    }());
    return kDebugMode || isDev;
  }
  
  // Keys for SharedPreferences
  static const String _ipKey = 'server_ip';
  static const String _portKey = 'server_port';
  static const String _useHttpsKey = 'use_https';
  
  // Server configuration with getters and setters
  static String _serverIp = _defaultIp;
  static int _serverPort = _defaultPort;
  static bool _useHttps = _defaultUseHttps;
  static bool _isInitialized = false;
  
  // Initialize configuration from shared preferences
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      _serverIp = prefs.getString(_ipKey) ?? _defaultIp;
      _serverPort = prefs.getInt(_portKey) ?? _defaultPort;
      _useHttps = prefs.getBool(_useHttpsKey) ?? _defaultUseHttps;
      _isInitialized = true;
    } catch (e) {
      // Use defaults if there's an error
      _serverIp = _defaultIp;
      _serverPort = _defaultPort;
      _useHttps = _defaultUseHttps;
    }
  }
  
  // Save configuration to shared preferences
  static Future<bool> saveServerConfig(String ip, int port, {bool useHttps = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_ipKey, ip);
      await prefs.setInt(_portKey, port);
      await prefs.setBool(_useHttpsKey, useHttps);
      
      // Update in-memory values
      _serverIp = ip;
      _serverPort = port;
      _useHttps = useHttps;
      _isInitialized = true;
      
      return true;
    } catch (e) {
      return false;
    }
  }
  
  // Get the current server configuration
  static Future<Map<String, dynamic>> getServerConfig() async {
    if (!_isInitialized) {
      await initialize();
    }
    
    return {
      'ip': _serverIp,
      'port': _serverPort,
      'useHttps': _useHttps,
    };
  }

  // Get the base URL for API requests
  static String get baseUrl {
    final protocol = _useHttps ? 'https' : 'http';
    // For local development, use the configured IP
    if (isDevelopment) {
      return '$protocol://$_serverIp:$_serverPort';
    }
    // For production, use the domain
    return '$protocol://api.campusnet.com';
  }

  // WebSocket URL for real-time communication
  static String get webSocketUrl {
    final protocol = _useHttps ? 'wss' : 'ws';
    // For local development, use the configured IP
    if (isDevelopment) {
      // For local development, try both IP and localhost
      final urls = [
        '$protocol://$_serverIp:$_serverPort/ws',
        if (_serverIp != '127.0.0.1') '$protocol://127.0.0.1:$_serverPort/ws',
      ];
      return urls.first;
    }
    // For production, use the domain
    return '$protocol://api.campusnet.com/ws';
  }

  // Check if the current server is a local server
  static bool get isLocalServer {
    final ip = _isInitialized ? _serverIp : _defaultIp;
    if (ip == 'localhost' || ip == '127.0.0.1') return true;
    if (ip.startsWith('192.168.')) return true;
    if (ip.startsWith('10.')) return true;
    if (ip.startsWith('172.')) {
      final parts = ip.split('.');
      if (parts.length >= 2) {
        final second = int.tryParse(parts[1]) ?? -1;
        if (second >= 16 && second <= 31) return true;
      }
    }
    return false;
  }

  // Timeout duration for API requests
  static const Duration apiTimeout = Duration(seconds: 10);
  
  // Connection test timeout
  static const Duration connectionTestTimeout = Duration(seconds: 3);

  // Reconnection settings
  static const int maxReconnectAttempts = 5;
  static const Duration initialReconnectDelay = Duration(seconds: 1);
  static const Duration maxReconnectDelay = Duration(seconds: 30);
  
  // Server discovery settings
  static const List<int> commonPorts = [3000, 8000, 8080, 5000, 4000];
  
  // Reset to default configuration
  static Future<void> resetToDefaults() async {
    _serverIp = _defaultIp;
    _serverPort = _defaultPort;
    _useHttps = _defaultUseHttps;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_ipKey);
      await prefs.remove(_portKey);
      await prefs.remove(_useHttpsKey);
    } catch (e) {
      // Ignore errors during reset
    }
  }
}
