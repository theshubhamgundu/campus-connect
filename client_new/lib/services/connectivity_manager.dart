import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:logger/logger.dart';
import 'websocket_service.dart';
import '../config/server_config.dart';

class ConnectivityManager {
  static final ConnectivityManager _instance = ConnectivityManager._internal();
  factory ConnectivityManager() => _instance;
  
  final Logger _logger = Logger();
  final WebSocketService _webSocketService = WebSocketService();
  
  StreamSubscription? _connectivitySubscription;
  Timer? _reconnectTimer;
  bool _isReconnecting = false;
  bool _shouldShowConnectivityScreen = false;
  
  // Callbacks
  Function()? onConnectionLost;
  Function()? onConnectionRestored;
  Function()? onShowConnectivityScreen;
  Function()? onHideConnectivityScreen;

  ConnectivityManager._internal();

  Future<void> initialize() async {
    _logger.i('🔌 Initializing Connectivity Manager');
    
    // Listen for connectivity changes
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen(_handleConnectivityChange);
    
    // Start monitoring connection
    _startConnectionMonitoring();
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final result = results.first;
    _logger.i('📡 Connectivity changed: $result');
    
    if (result == ConnectivityResult.wifi) {
      _checkCampusNetConnection();
    } else {
      _handleConnectionLost();
    }
  }

  Future<void> _checkCampusNetConnection() async {
    try {
      final networkInfo = NetworkInfo();
      final wifiIP = await networkInfo.getWifiIP();
      final wifiName = await networkInfo.getWifiName();
      
      _logger.i('📶 WiFi Info - IP: $wifiIP, Name: $wifiName');
      
      // Check if connected to CampusNet
      final isCampusNet = wifiName?.contains('CampusNet') == true || 
                         (wifiIP != null && wifiIP.startsWith('192.168.137.'));
      
      if (isCampusNet) {
        _logger.i('🎯 CampusNet WiFi detected!');
        await _attemptReconnection();
      } else {
        _logger.w('⚠️ Not connected to CampusNet WiFi');
        _handleConnectionLost();
      }
    } catch (e) {
      _logger.e('❌ Error checking CampusNet connection: $e');
      _handleConnectionLost();
    }
  }

  Future<void> _attemptReconnection() async {
    if (_isReconnecting) return;
    
    _isReconnecting = true;
    _logger.i('🔄 Attempting to reconnect to CampusNet server...');
    
    try {
      await _webSocketService.initialize();
      
      // Wait a moment to ensure connection is stable
      await Future.delayed(const Duration(seconds: 2));
      
      if (_webSocketService.isConnected) {
        _logger.i('✅ Successfully reconnected to CampusNet!');
        _handleConnectionRestored();
      } else {
        _logger.w('⚠️ Reconnection failed, will retry...');
        _scheduleReconnect();
      }
    } catch (e) {
      _logger.e('❌ Reconnection error: $e');
      _scheduleReconnect();
    } finally {
      _isReconnecting = false;
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (!_webSocketService.isConnected) {
        _attemptReconnection();
      }
    });
  }

  void _handleConnectionLost() {
    if (!_shouldShowConnectivityScreen) {
      _shouldShowConnectivityScreen = true;
      _logger.w('📵 Connection lost - showing connectivity screen');
      
      onConnectionLost?.call();
      onShowConnectivityScreen?.call();
    }
  }

  void _handleConnectionRestored() {
    if (_shouldShowConnectivityScreen) {
      _shouldShowConnectivityScreen = false;
      _logger.i('📶 Connection restored - hiding connectivity screen');
      
      onConnectionRestored?.call();
      onHideConnectivityScreen?.call();
      
      // Show success toast
      _showConnectionRestoredToast();
    }
    
    // Cancel any pending reconnection attempts
    _reconnectTimer?.cancel();
  }

  void _showConnectionRestoredToast() {
    // This would typically show a toast notification
    // For now, we'll just log it
    _logger.i('🎉 Connection restored! User can continue using the app.');
  }

  void _startConnectionMonitoring() {
    // Check connection status every 5 seconds
    Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!_webSocketService.isConnected && !_isReconnecting) {
        _checkCampusNetConnection();
      }
    });
  }

  // Public methods for manual connection management
  Future<void> forceReconnect() async {
    _logger.i('🔄 Manual reconnection requested');
    await _attemptReconnection();
  }

  void hideConnectivityScreen() {
    _shouldShowConnectivityScreen = false;
    onHideConnectivityScreen?.call();
  }

  bool get shouldShowConnectivityScreen => _shouldShowConnectivityScreen;
  bool get isConnected => _webSocketService.isConnected;
  bool get isReconnecting => _isReconnecting;

  Future<void> dispose() async {
    _logger.i('🔌 Disposing Connectivity Manager');
    await _connectivitySubscription?.cancel();
    _reconnectTimer?.cancel();
    await _webSocketService.dispose();
  }
}
