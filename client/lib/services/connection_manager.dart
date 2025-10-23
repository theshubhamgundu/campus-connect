import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:provider/provider.dart';

enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  serverUnreachable,
  noInternet,
}

class ConnectionManager with ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  final InternetConnectionChecker _connectionChecker = InternetConnectionChecker();
  
  StreamSubscription? _connectivitySubscription;
  StreamSubscription? _connectionSubscription;
  
  ConnectionStatus _status = ConnectionStatus.disconnected;
  bool _hasInternet = false;
  
  ConnectionStatus get status => _status;
  bool get isConnected => _status == ConnectionStatus.connected;
  bool get hasInternet => _hasInternet;
  
  // Singleton pattern
  static final ConnectionManager _instance = ConnectionManager._internal();
  factory ConnectionManager() => _instance;
  ConnectionManager._internal() {
    _init();
  }
  
  void _init() async {
    // Initial connectivity check
    await _checkConnectivity();
    
    // Listen to connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((_) {
      _checkConnectivity();
    });
    
    // Listen to internet connection changes
    _connectionSubscription = _connectionChecker.onStatusChange.listen((status) {
      _hasInternet = status == InternetConnectionStatus.connected;
      _updateConnectionStatus();
      notifyListeners();
    });
  }
  
  Future<void> _checkConnectivity() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      _hasInternet = await _connectionChecker.hasConnection;
      _updateConnectionStatus();
      notifyListeners();
    } catch (e) {
      _status = ConnectionStatus.disconnected;
      notifyListeners();
    }
  }
  
  void _updateConnectionStatus() {
    if (!_hasInternet) {
      _status = ConnectionStatus.noInternet;
    } else if (_status != ConnectionStatus.connected) {
      _status = ConnectionStatus.connected;
    }
  }
  
  void updateServerConnection(bool isConnected) {
    if (isConnected) {
      _status = ConnectionStatus.connected;
    } else if (_hasInternet) {
      _status = ConnectionStatus.serverUnreachable;
    } else {
      _status = ConnectionStatus.noInternet;
    }
    notifyListeners();
  }
  
  void setConnecting() {
    if (_status != ConnectionStatus.connecting) {
      _status = ConnectionStatus.connecting;
      notifyListeners();
    }
  }
  
  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectionSubscription?.cancel();
    super.dispose();
  }
  
  // Helper method to get the status message
  static String getStatusMessage(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        return 'Connected';
      case ConnectionStatus.connecting:
        return 'Connecting...';
      case ConnectionStatus.disconnected:
        return 'Disconnected';
      case ConnectionStatus.serverUnreachable:
        return 'Server unavailable';
      case ConnectionStatus.noInternet:
        return 'No internet connection';
    }
  }
  
  // Helper method to get the status color
  static int getStatusColor(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        return 0xFF4CAF50; // Green
      case ConnectionStatus.connecting:
        return 0xFFFFC107; // Amber
      case ConnectionStatus.disconnected:
      case ConnectionStatus.serverUnreachable:
      case ConnectionStatus.noInternet:
        return 0xFFF44336; // Red
    }
  }
}

// Provider extension for easy access
extension ConnectionManagerExtension on BuildContext {
  ConnectionManager get connectionManager => read<ConnectionManager>();
  
  // Helper methods for connection status
  bool get isConnected => connectionManager.isConnected;
  bool get hasInternet => connectionManager.hasInternet;
  ConnectionStatus get connectionStatus => connectionManager.status;
  
  // Helper methods for UI
  String get connectionStatusMessage => 
      ConnectionManager.getStatusMessage(connectionStatus);
      
  int get connectionStatusColor => 
      ConnectionManager.getStatusColor(connectionStatus);
}
