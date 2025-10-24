import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/server_config.dart';

typedef MessageCallback = void Function(dynamic data);
typedef FileProgressCallback = void Function(int bytesSent, int totalBytes);

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  
  final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 50,
      colors: true,
    ),
  );

  WebSocketChannel? _channel;
  final StreamController<dynamic> _messageController = 
      StreamController<dynamic>.broadcast();
  final StreamController<bool> _connectionStateController = 
      StreamController<bool>.broadcast();
  final List<dynamic> _messageQueue = [];
  
  bool _isConnected = false;
  bool _isConnecting = false;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectDelay = Duration(seconds: 2);
  String? _url;
  StreamSubscription? _connectivitySubscription;
  String? _userId;
  DateTime? _lastHeartbeat;
  String? _lastError;

  // Message queue for when offline
  final List<Map<String, dynamic>> _offlineMessageQueue = [];
  bool _isProcessingQueue = false;

  // Event listeners
  final Map<String, List<MessageCallback>> _listeners = {};
  final Map<String, Completer<dynamic>> _pendingRequests = {};

  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  String? get lastError => _lastError;
  Stream<dynamic> get messageStream => _messageController.stream;
  Stream<bool> get connectionState => _connectionStateController.stream;

  WebSocketService._internal() {
    _initConnectivityListener();
  }

  void _initConnectivityListener() {
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      final result = results.first;
      _logger.i('Connectivity changed: $result');
      if (result == ConnectivityResult.wifi) {
        if (!_isConnected && !_isConnecting) {
          _checkNetworkAndConnect();
        }
      } else {
        _handleDisconnect();
        _notifyConnectionStatus(false, message: 'Please connect to CampusNet WiFi');
      }
    });
  }

  Future<void> initialize() async {
    if (_isConnected) return;

    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('userId');

    // Check network connectivity and attempt to connect
    await _checkNetworkAndConnect();
  }

  Future<void> _checkNetworkAndConnect() async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity == ConnectivityResult.wifi) {
        final networkInfo = NetworkInfo();
        String? wifiIP;
        
        try {
          wifiIP = await networkInfo.getWifiIP();
        } catch (e) {
          _logger.e('Error getting WiFi IP: $e');
          _notifyConnectionStatus(false, message: 'Network error. Please check your connection');
          return;
        }
        
        // Check if connected to CampusNet WiFi (your hotspot)
        if (wifiIP != null && wifiIP.startsWith('192.168.137.')) {
          await _connect();
        } else {
          _notifyConnectionStatus(false, message: 'Please connect to CampusNet WiFi (${ServerConfig.serverIp})');
        }
      } else {
        _notifyConnectionStatus(false, message: 'Please connect to CampusNet WiFi (${ServerConfig.serverIp})');
      }
    } catch (e) {
      _logger.e('Error in network check: $e');
      _notifyConnectionStatus(false, message: 'Connection error. Retrying...');
      // Retry after delay
      await Future.delayed(const Duration(seconds: 2));
      if (!_isConnected) {
        await _checkNetworkAndConnect();
      }
    }
  }

  Future<void> _connect() async {
    if (_isConnecting) return;
    _isConnecting = true;
    
    try {
      _logger.i('🔌 Connecting to WebSocket at ${ServerConfig.webSocketUrl}');
      
      // Close any existing connection
      await _disconnect();
      
      // Create new connection with timeout
      final completer = Completer<WebSocketChannel>();
      final timer = Timer(const Duration(seconds: 10), () {
        if (!completer.isCompleted) {
          completer.completeError(TimeoutException('Connection timeout'));
        }
      });
      
      // Initialize WebSocket connection
      try {
        final channel = WebSocketChannel.connect(
          Uri.parse('${ServerConfig.webSocketUrl}?userId=$_userId&device=flutter&v=1.0'),
        );
        
        // Wait for the connection to be established
        await channel.ready;
        timer.cancel();
        
        if (!completer.isCompleted) {
          completer.complete(channel);
        }
      } catch (e) {
        timer.cancel();
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
        rethrow;
      }
      
      // Get the connected channel
      _channel = await completer.future;
      
      // Set up listeners
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
        cancelOnError: true,
      );

      // Connection established
      _isConnected = true;
      _isConnecting = false;
      _reconnectAttempts = 0;
      _lastHeartbeat = DateTime.now();
      _startHeartbeat();
      
      _notifyConnectionStatus(true, message: 'Connected to CampusNet');
      _logger.i('✅ WebSocket connected successfully');
      
      // Process any queued messages
      _processMessageQueue();
      
    } catch (e, stackTrace) {
      _isConnecting = false;
      _logger.e('❌ WebSocket connection error', error: e, stackTrace: stackTrace);
      _handleDisconnect();
      rethrow;
    }
  }
  
  Future<void> _disconnect() async {
    try {
      _logger.d('Disconnecting WebSocket...');
      await _channel?.sink.close(status.goingAway);
    } catch (e, stackTrace) {
      _logger.e('Error during disconnect', error: e, stackTrace: stackTrace);
    } finally {
      _channel = null;
      _isConnected = false;
      _isConnecting = false;
      _heartbeatTimer?.cancel();
      _logger.d('WebSocket disconnected');
    }
  }
  
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!_isConnected) {
        timer.cancel();
        return;
      }
      
      // Check if we've missed too many heartbeats
      if (DateTime.now().difference(_lastHeartbeat!) > const Duration(seconds: 90)) {
        _logger.w('Missed too many heartbeats, reconnecting...');
        _handleDisconnect();
        return;
      }
      
      try {
        // Send heartbeat
        _channel?.sink.add(jsonEncode({
          'event': 'heartbeat',
          'data': {'timestamp': DateTime.now().millisecondsSinceEpoch},
        }));
      } catch (e) {
        _logger.e('Failed to send heartbeat: $e');
        _handleError(e);
      }
    });
  }

  void _handleMessage(dynamic message) {
    try {
      if (message == null) return;
      
      // Handle ping/pong
      if (message == 'ping') {
        _channel?.sink.add('pong');
        _lastHeartbeat = DateTime.now();
        return;
      } else if (message == 'pong') {
        _lastHeartbeat = DateTime.now();
        return;
      }
      
      // Parse JSON message
      final data = jsonDecode(message);
      final String? event = data['event'];
      final dynamic payload = data['data'];
      final String? requestId = data['requestId'];
      
      if (event == 'heartbeat') {
        _lastHeartbeat = DateTime.now();
        return;
      }

      // Handle response to a specific request
      if (requestId != null && _pendingRequests.containsKey(requestId)) {
        if (data['error'] != null) {
          _pendingRequests[requestId]!.completeError(
            SocketException(data['error']['message'] ?? 'Server error'),
          );
        } else {
          _pendingRequests[requestId]!.complete(payload);
        }
        _pendingRequests.remove(requestId);
        return;
      }

      // Notify all listeners for this event
      if (event != null && _listeners.containsKey(event)) {
        for (final callback in List<MessageCallback>.from(_listeners[event]!)) {
          try {
            callback(payload);
          } catch (e, stackTrace) {
            _logger.e('Error in $event listener', error: e, stackTrace: stackTrace);
          }
        }
      }

      // Also send to message stream
      _messageController.add(data);
    } catch (e, stackTrace) {
      _logger.e('Error handling WebSocket message', error: e, stackTrace: stackTrace);
      
      // Notify error listeners
      if (_listeners.containsKey('error')) {
        for (final callback in _listeners['error']!) {
          callback({
            'error': 'MESSAGE_PROCESSING_ERROR',
            'message': 'Failed to process message: ${e.toString()}',
            'originalMessage': message,
          });
        }
      }
    }
  }

  void _handleError(dynamic error) {
    _logger.e('WebSocket error: $error');
    _lastError = error.toString();
    _handleDisconnect();
  }

  void _handleDisconnect() {
    if (_isConnected || _isConnecting) {
      _logger.w('WebSocket disconnected');
      
      // Clean up resources
      _isConnected = false;
      _isConnecting = false;
      _heartbeatTimer?.cancel();
      
      // Notify listeners about disconnection
      final isFinalAttempt = _reconnectAttempts >= _maxReconnectAttempts;
      _notifyConnectionStatus(
        false, 
        message: isFinalAttempt 
            ? '⚠️ Connection Lost — Please check your WiFi connection (${ServerConfig.serverIp})'
            : 'Reconnecting to CampusNet... (${_reconnectAttempts + 1}/$_maxReconnectAttempts)',
      );
      
      // Attempt to reconnect if under max attempts
      if (!isFinalAttempt) {
        _reconnectAttempts++;
        final delay = Duration(seconds: _calculateBackoff(_reconnectAttempts));
        _logger.i('Will attempt to reconnect in ${delay.inSeconds} seconds...');
        Future.delayed(delay, _checkNetworkAndConnect);
      } else {
        _logger.w('Max reconnection attempts reached');
      }
    }
  }
  
  int _calculateBackoff(int attempt) {
    // Exponential backoff with jitter
    final baseDelay = 1;
    final maxDelay = 30; // 30 seconds max delay
    final delay = (baseDelay * pow(2, attempt - 1)).toInt();
    final jitter = Random().nextInt(3); // Add 0-2 seconds of jitter
    return min(delay + jitter, maxDelay);
  }

  void _notifyConnectionStatus(bool isConnected, {String? message}) {
    if (_listeners.containsKey('connection')) {
      for (final callback in _listeners['connection']!) {
        callback({
          'isConnected': isConnected,
          'message': message ?? (isConnected ? 'Connected to CampusNet' : 'Disconnected from CampusNet'),
          'serverIp': ServerConfig.serverIp,
        });
      }
    }
    _connectionStateController.add(isConnected);
  }

  // Send a message through WebSocket with retry logic
  Future<dynamic> send(
    String event, 
    dynamic data, {
    bool waitForResponse = false,
    int maxRetries = 2,
    bool queueIfOffline = true,
  }) async {
    if (!_isConnected) {
      if (queueIfOffline) {
        // Queue the message if we're offline
        _enqueueMessage(event, data, waitForResponse: waitForResponse);
        
        if (_reconnectAttempts < _maxReconnectAttempts) {
          await _checkNetworkAndConnect();
        }
        
        if (waitForResponse) {
          throw SocketException('Message queued for delivery when online');
        }
        return null;
      } else {
        throw SocketException('Not connected to CampusNet');
      }
    }
    
    try {
      // If this is a critical message, ensure it's delivered
      if (waitForResponse) {
        return await _sendWithRetry(event, data, maxRetries);
      }
      
      // For non-critical messages, just send without waiting for response
      return _sendMessage(event, data);
    } catch (e) {
      _logger.e('Error sending message', error: e);
      rethrow;
    }
  }
  
  void _enqueueMessage(String event, dynamic data, {bool waitForResponse = false}) {
    _offlineMessageQueue.add({
      'event': event,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
      'waitForResponse': waitForResponse,
    });
    _logger.d('Message queued. Queue size: ${_offlineMessageQueue.length}');
  }
  
  Future<void> _processMessageQueue() async {
    if (_offlineMessageQueue.isEmpty || _isProcessingQueue || !_isConnected) {
      return;
    }
    
    _isProcessingQueue = true;
    
    try {
      _logger.d('Processing message queue (${_offlineMessageQueue.length} items)');
      
      // Process messages in chunks to avoid blocking
      final messagesToProcess = List<Map<String, dynamic>>.from(_offlineMessageQueue);
      _offlineMessageQueue.clear();
      
      for (final message in messagesToProcess) {
        try {
          if (message['waitForResponse'] == true) {
            await _sendWithRetry(
              message['event'], 
              message['data'],
              2,
            );
          } else {
            await _sendMessage(message['event'], message['data']);
          }
          await Future.delayed(const Duration(milliseconds: 100)); // Rate limiting
        } catch (e) {
          _logger.e('Error processing queued message', error: e);
          // Re-queue failed messages for next attempt
          _offlineMessageQueue.add(message);
        }
      }
    } finally {
      _isProcessingQueue = false;
      
      // If there are still messages in the queue, schedule another processing run
      if (_offlineMessageQueue.isNotEmpty) {
        Future.delayed(const Duration(seconds: 1), _processMessageQueue);
      }
    }
  }
  
  Future<dynamic> _sendWithRetry(String event, dynamic data, int maxRetries) async {
    int attempt = 0;
    dynamic lastError;
    
    while (attempt <= maxRetries) {
      try {
        _logger.d('Sending message (attempt ${attempt + 1}/$maxRetries): $event');
        
        final response = await _sendMessage(event, data, waitForResponse: true)
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () => throw TimeoutException('Request timed out'),
            );
            
        _logger.d('Message sent successfully: $event');
        return response;
        
      } catch (e, stackTrace) {
        attempt++;
        lastError = e;
        
        if (attempt > maxRetries) {
          _logger.e('Failed after $maxRetries retries for $event', 
                   error: e, stackTrace: stackTrace);
          rethrow;
        }
        
        // Calculate backoff with jitter
        final backoff = Duration(milliseconds: 1000 * pow(2, attempt).toInt());
        final jitter = Duration(milliseconds: Random().nextInt(1000));
        final delay = backoff + jitter;
        
        _logger.w('Retry $attempt/$maxRetries for $event in ${delay.inMilliseconds}ms', 
                 error: e);
        
        // Try to reconnect if needed
        if (!_isConnected) {
          await _checkNetworkAndConnect();
          // Wait a bit after reconnection attempt
          await Future.delayed(const Duration(seconds: 1));
        } else {
          await Future.delayed(delay);
        }
      }
    }
    
    throw lastError ?? Exception('Failed after $maxRetries retries');
  }
  
  Future<dynamic> _sendMessage(String event, dynamic data, {bool waitForResponse = false}) async {
    if (!_isConnected) {
      throw SocketException('Not connected to CampusNet');
    }

    final String requestId = DateTime.now().millisecondsSinceEpoch.toString();
    final message = {
      'event': event,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
      'requestId': waitForResponse ? requestId : null,
    };

    _channel!.sink.add(jsonEncode(message));

    if (waitForResponse) {
      final completer = Completer<dynamic>();
      _pendingRequests[requestId] = completer;
      
      // Set a timeout for the response
      Future.delayed(const Duration(seconds: 10), () {
        if (_pendingRequests.containsKey(requestId)) {
          _pendingRequests.remove(requestId);
          if (!completer.isCompleted) {
            completer.completeError(TimeoutException('No response from server'));
          }
        }
      });

      return completer.future;
    }

    return null;
  }

  // Add a listener for a specific event
  void addListener(String event, MessageCallback callback) {
    if (!_listeners.containsKey(event)) {
      _listeners[event] = [];
    }
    _listeners[event]!.add(callback);
  }

  // Remove a listener
  void removeListener(String event, MessageCallback callback) {
    if (_listeners.containsKey(event)) {
      _listeners[event]!.remove(callback);
      if (_listeners[event]!.isEmpty) {
        _listeners.remove(event);
      }
    }
  }

  // Clean up resources
  Future<void> dispose() async {
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _connectivitySubscription?.cancel();
    await _channel?.sink.close();
    _isConnected = false;
    _listeners.clear();
    _pendingRequests.clear();
    _messageController.close();
    _connectionStateController.close();
  }
}