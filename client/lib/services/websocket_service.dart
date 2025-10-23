import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform, SocketException;
import 'dart:math';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:logger/logger.dart';
import '../config/server_config.dart';
import '../exceptions/server_exception.dart';

typedef MessageCallback = void Function(dynamic data);
typedef FileProgressCallback = void Function(int sent, int total);

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  
  final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 50,
      colors: true,
      printEmojis: true,
    ),
  );
  
  WebSocketService._internal() {
    _logger.d('WebSocketService initialized');
  }
  
  // Connection state
  bool _isConnected = false;
  bool _isConnecting = false;
  int _reconnectAttempts = 0;
  DateTime _lastHeartbeat = DateTime.now();
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  
  // Message queue for when offline
  final List<Map<String, dynamic>> _messageQueue = [];
  bool _isProcessingQueue = false;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  bool _isConnected = false;
  final Map<String, List<MessageCallback>> _listeners = {};
  final Map<String, Completer<dynamic>> _pendingRequests = {};
  String? _userId;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;

  // WebSocket events
  static const String eventMessage = 'message';
  static const String eventCall = 'call';
  static const String eventFile = 'file';
  static const String eventTyping = 'typing';
  static const String eventOnline = 'online';
  static const String eventError = 'error';

  // Initialize WebSocket connection
  Future<void> initialize() async {
    if (_isConnected) return;

    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('userId');

    // Check network connectivity and attempt to connect
    await _checkNetworkAndConnect();
    
    // Set up listeners for network changes
    _setupNetworkListeners();
  }

  // Check network and connect if on CampusNet
  Future<void> _checkNetworkAndConnect() async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity == ConnectivityResult.wifi) {
        final networkInfo = NetworkInfo();
        String? wifiIP;
        
        try {
          wifiIP = await networkInfo.getWifiIP();
        } catch (e) {
          debugPrint('Error getting WiFi IP: $e');
          _notifyConnectionStatus(false, message: 'Network error. Please check your connection');
          return;
        }
        
        // Check if connected to CampusNet WiFi
        if (wifiIP != null && wifiIP.startsWith('192.168.137.')) {
          await _connect();
          _setupReconnection();
        } else {
          _notifyConnectionStatus(false, message: 'Please connect to CampusNet WiFi (${ServerConfig.serverIp})');
        }
      } else {
        _notifyConnectionStatus(false, message: 'Please connect to CampusNet WiFi (${ServerConfig.serverIp})');
      }
    } catch (e) {
      debugPrint('Error in network check: $e');
      _notifyConnectionStatus(false, message: 'Connection error. Retrying...');
      // Retry after delay
      await Future.delayed(const Duration(seconds: 2));
      if (!_isConnected) {
        await _checkNetworkAndConnect();
      }
    }
  }

  // Set up network change listeners
  void _setupNetworkListeners() {
    // Listen for network state changes
    Connectivity().onConnectivityChanged.listen((result) async {
      if (result == ConnectivityResult.wifi) {
        await _checkNetworkAndConnect();
      } else {
        _handleDisconnect();
        _notifyConnectionStatus(false, message: 'Please connect to CampusNet WiFi');
      }
    });
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
      _subscription = _channel!.stream.listen(
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
      await _subscription?.cancel();
      await _channel?.sink.close(status.goingAway);
    } catch (e, stackTrace) {
      _logger.e('Error during disconnect', error: e, stackTrace: stackTrace);
    } finally {
      _subscription = null;
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
      if (_isConnected) {
        if (DateTime.now().difference(_lastHeartbeat) > const Duration(seconds: 60)) {
          debugPrint('No heartbeat received, reconnecting...');
          _handleDisconnect();
          return;
        }
        _sendHeartbeat();
      } else {
        timer.cancel();
      }
    });
  }
  
  Future<void> _sendHeartbeat() async {
    try {
      await _channel?.sink.add(jsonEncode({
        'event': 'heartbeat',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      }));
    } catch (e) {
      debugPrint('Error sending heartbeat: $e');
      _handleDisconnect();
    }
  }

  void _setupReconnection() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer.periodic(
      const Duration(seconds: 5),
      (timer) async {
        if (!_isConnected && _reconnectAttempts < ServerConfig.maxReconnectAttempts) {
          _reconnectAttempts++;
          print('Attempting to reconnect... ($_reconnectAttempts/${ServerConfig.maxReconnectAttempts})');
          await _connect();
        } else if (_reconnectAttempts >= ServerConfig.maxReconnectAttempts) {
          timer.cancel();
          print('Max reconnection attempts reached');
        }
      },
    );
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
            ServerException(data['error']['code'] ?? 'UNKNOWN_ERROR', data['error']['message'] ?? 'An error occurred'),
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
            debugPrint('Error in $event listener: $e');
            debugPrint('Stack trace: $stackTrace');
          }
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Error handling WebSocket message: $e');
      debugPrint('Message: $message');
      debugPrint('Stack trace: $stackTrace');
      
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
  
  Future<void> _waitForConnection() async {
    if (_isConnected) return;
    
    final completer = Complever<void>();
    final timer = Timer(const Duration(seconds: 10), () {
      if (!completer.isCompleted) {
        completer.completeError(TimeoutException('Connection timeout'));
      }
    });
    
    void checkConnection() {
      if (_isConnected) {
        timer.cancel();
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    }
    
    addConnectionListener(checkConnection);
    await completer.future;
    removeConnectionListener(checkConnection);
  }
  
  void addConnectionListener(MessageCallback callback) {
    addListener('connection', callback);
  }
  
  void removeConnectionListener(MessageCallback callback) {
    removeListener('connection', callback);
  }

  void _handleError(dynamic error) {
    print('WebSocket error: $error');
    _handleDisconnect();
  }

  void _handleDisconnect() {
    if (_isConnected || _isConnecting) {
      _logger.w('WebSocket disconnected');
      
      // Clean up resources
      _isConnected = false;
      _isConnecting = false;
      _heartbeatTimer?.cancel();
      _subscription?.cancel();
      
      // Notify listeners about disconnection
      final isFinalAttempt = _reconnectAttempts >= ServerConfig.maxReconnectAttempts;
      _notifyConnectionStatus(
        false, 
        message: isFinalAttempt 
            ? '⚠️ Connection Lost — Please check your WiFi connection (${ServerConfig.serverIp})'
            : 'Reconnecting to CampusNet... (${_reconnectAttempts + 1}/${ServerConfig.maxReconnectAttempts})',
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
        
        if (_reconnectAttempts < ServerConfig.maxReconnectAttempts) {
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
    _messageQueue.add({
      'event': event,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
      'waitForResponse': waitForResponse,
    });
    _logger.d('Message queued. Queue size: ${_messageQueue.length}');
  }
  
  Future<void> _processMessageQueue() async {
    if (_messageQueue.isEmpty || _isProcessingQueue || !_isConnected) {
      return;
    }
    
    _isProcessingQueue = true;
    
    try {
      _logger.d('Processing message queue (${_messageQueue.length} items)');
      
      // Process messages in chunks to avoid blocking
      final messagesToProcess = List<Map<String, dynamic>>.from(_messageQueue);
      _messageQueue.clear();
      
      for (final message in messagesToProcess) {
        try {
          if (message['waitForResponse'] == true) {
            await _sendWithRetry(
              message['event'], 
              message['data'],
              maxRetries: 2,
            );
          } else {
            await _sendMessage(message['event'], message['data']);
          }
          await Future.delayed(const Duration(milliseconds: 100)); // Rate limiting
        } catch (e) {
          _logger.e('Error processing queued message', error: e);
          // Re-queue failed messages for next attempt
          _messageQueue.add(message);
        }
      }
    } finally {
      _isProcessingQueue = false;
      
      // If there are still messages in the queue, schedule another processing run
      if (_messageQueue.isNotEmpty) {
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

  // Send a file in chunks
  Future<void> sendFile(String fileId, String fileName, Uint8List fileData, 
      {required String receiverId, FileProgressCallback? onProgress}) async {
    const chunkSize = 16 * 1024; // 16KB chunks
    final totalChunks = (fileData.length / chunkSize).ceil();
    
    for (var i = 0; i < totalChunks; i++) {
      final start = i * chunkSize;
      final end = (i + 1) * chunkSize > fileData.length 
          ? fileData.length 
          : (i + 1) * chunkSize;
          
      final chunk = fileData.sublist(start, end);
      
      await send('file_chunk', {
        'fileId': fileId,
        'fileName': fileName,
        'chunkIndex': i,
        'totalChunks': totalChunks,
        'data': base64Encode(chunk),
        'receiverId': receiverId,
      });
      
      onProgress?.call(end, fileData.length);
    }
    
    // Notify that file transfer is complete
    await send('file_complete', {
      'fileId': fileId,
      'fileName': fileName,
      'fileSize': fileData.length,
      'receiverId': receiverId,
    });
  }

  // Handle incoming calls
  void handleIncomingCall(dynamic payload) {
    // This would be implemented based on your call handling logic
    // You would typically show an incoming call UI here
    if (_listeners.containsKey(eventCall)) {
      for (final callback in _listeners[eventCall]!) {
        callback(payload);
      }
    }
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
    _subscription?.cancel();
    await _channel?.sink.close();
    _isConnected = false;
    _listeners.clear();
    _pendingRequests.clear();
  }

  // Getters
  bool get isConnected => _isConnected;
  String? get userId => _userId;
}
