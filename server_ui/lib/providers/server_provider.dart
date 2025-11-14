import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class ServerProvider extends ChangeNotifier {
  HttpServer? _server;
  bool _isRunning = false;
  int _port = 8083;
  String _status = 'Stopped';
  List<ClientInfo> _connectedClients = [];
  List<ServerLog> _logs = [];
  int _totalConnections = 0;
  int _totalMessages = 0;

  // Getters
  bool get isRunning => _isRunning;
  int get port => _port;
  String get status => _status;
  List<ClientInfo> get connectedClients => _connectedClients;
  List<ServerLog> get logs => _logs;
  int get totalConnections => _totalConnections;
  int get totalMessages => _totalMessages;

  void setPort(int port) {
    if (!_isRunning) {
      _port = port;
      notifyListeners();
    }
  }

  Future<void> startServer() async {
    if (_isRunning) return;

    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, _port);
      _isRunning = true;
      _status = 'Running';
      _addLog('Server started on port $_port', LogType.info);
      notifyListeners();

      // Handle incoming connections
      _server!.listen((HttpRequest request) {
        _handleRequest(request);
      });
    } catch (e) {
      _addLog('Failed to start server: $e', LogType.error);
      notifyListeners();
    }
  }

  Future<void> stopServer() async {
    if (!_isRunning) return;

    try {
      await _server?.close();
      _server = null;
      _isRunning = false;
      _status = 'Stopped';
      _connectedClients.clear();
      _addLog('Server stopped', LogType.info);
      notifyListeners();
    } catch (e) {
      _addLog('Error stopping server: $e', LogType.error);
      notifyListeners();
    }
  }

  void _handleRequest(HttpRequest request) {
    if (request.uri.path == '/ws') {
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        WebSocketTransformer.upgrade(request).then((WebSocket websocket) {
          _handleWebSocket(websocket);
        });
      } else {
        request.response
          ..statusCode = HttpStatus.badRequest
          ..write('WebSocket endpoint is /ws')
          ..close();
      }
    } else {
      request.response
        ..statusCode = HttpStatus.notFound
        ..write('Not Found')
        ..close();
    }
  }

  void _handleWebSocket(WebSocket websocket) {
    final clientInfo = ClientInfo(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      address: websocket.remoteAddress.address,
      connectedAt: DateTime.now(),
    );
    
    _connectedClients.add(clientInfo);
    _totalConnections++;
    _addLog('Client connected: ${clientInfo.address}', LogType.info);
    notifyListeners();

    websocket.listen((data) {
      _totalMessages++;
      _addLog('Message received from ${clientInfo.address}', LogType.message);
      notifyListeners();
    }, onDone: () {
      _connectedClients.remove(clientInfo);
      _addLog('Client disconnected: ${clientInfo.address}', LogType.info);
      notifyListeners();
    }, onError: (error) {
      _connectedClients.remove(clientInfo);
      _addLog('Client error: $error', LogType.error);
      notifyListeners();
    });
  }

  void _addLog(String message, LogType type) {
    _logs.insert(0, ServerLog(
      message: message,
      type: type,
      timestamp: DateTime.now(),
    ));
    
    // Keep only last 100 logs
    if (_logs.length > 100) {
      _logs = _logs.take(100).toList();
    }
    
    notifyListeners();
  }

  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  void disconnectClient(String clientId) {
    _connectedClients.removeWhere((client) => client.id == clientId);
    notifyListeners();
  }
}

class ClientInfo {
  final String id;
  final String address;
  final DateTime connectedAt;

  ClientInfo({
    required this.id,
    required this.address,
    required this.connectedAt,
  });
}

class ServerLog {
  final String message;
  final LogType type;
  final DateTime timestamp;

  ServerLog({
    required this.message,
    required this.type,
    required this.timestamp,
  });
}

enum LogType {
  info,
  error,
  warning,
  message,
}
