import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/online_user.dart';

enum ConnectionStatus { connecting, connected, disconnected }

/// Singleton service that handles UDP discovery, WebSocket connection,
/// login, send/receive chat messages and reconnection logic.
class ConnectionService {
  ConnectionService._private();
  static final ConnectionService instance = ConnectionService._private();

  // Public connection status notifier for UI
  final ValueNotifier<ConnectionStatus> connectionStatus =
      ValueNotifier(ConnectionStatus.disconnected);

  // Incoming parsed message stream
  final StreamController<Map<String, dynamic>> _incomingController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get incomingMessages => _incomingController.stream;

  WebSocket? _ws;
  String? serverIp;
  String? _localDeviceIp;

  // Current user info (set by init)
  String? _userId;
  String? _name;
  String? _role;
  String _deviceName = 'Android Device';

  // Reconnect control - FIX #1: Only reconnect on actual errors
  bool _shouldReconnect = true;
  Timer? _reconnectTimer;
  bool _isConnecting = false; // Prevent simultaneous connection attempts

  // Simple outgoing queue (string JSONs) when disconnected
  final List<String> _outgoingQueue = [];

  // FIX #9: Track last online users fetch time to prevent spam
  DateTime _lastOnlineUsersFetch = DateTime.fromMillisecondsSinceEpoch(0);
  static const int _onlineUsersFetchIntervalMs = 30000; // 30 seconds minimum

  // Initialize connection service after user logs in locally
  Future<void> init({
    required String userId,
    required String name,
    required String role,
    String? deviceName,
  }) async {
    _userId = userId;
    _name = name;
    _role = role;
    if (deviceName != null) _deviceName = deviceName;

    print('ConnectionService: init for $_userId ($_role)');

    // Get local device IP
    _localDeviceIp = await _getLocalIp();
    print('ConnectionService: local device IP: $_localDeviceIp');

    // Discover server (UDP) with 5s timeout
    serverIp = await discoverServer(timeout: const Duration(seconds: 5));
    serverIp ??= '192.168.137.1';

    print('ConnectionService: discovery result: $serverIp');

    // Connect websocket and send login
    await _connectWebSocket();
  }

  // Public getter for current user id
  String? get currentUserId => _userId;

  // Public getter for current user name
  String? get currentUserName => _name;

  // Public getter for current user role
  String? get currentUserRole => _role;

  // Public getter for local device IP
  String? get localDeviceIp => _localDeviceIp;

  /// Get local device IP address by connecting to a remote address
  /// (doesn't actually send data, just determines which local IP would be used)
  Future<String?> _getLocalIp() async {
    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.send(utf8.encode(''), InternetAddress('192.168.137.1'), 8082);
      final address = socket.address.address;
      socket.close();
      return address;
    } catch (e) {
      print('Failed to get local IP: $e');
      return null;
    }
  }

  /// UDP discovery. Sends a JSON discovery packet to broadcast port 8082 and
  /// waits for a response. Falls back to null on timeout.
  Future<String?> discoverServer({Duration timeout = const Duration(seconds: 5)}) async {
    print('Discovery started...');
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    } catch (e) {
      print('Discovery: socket bind failed: $e');
      return null;
    }

    final completer = Completer<String?>();

    void cleanup() {
      try {
        socket?.close();
      } catch (_) {}
    }

    socket.listen((RawSocketEvent event) {
      if (event == RawSocketEvent.read) {
        final datagram = socket!.receive();
        if (datagram == null) return;
        try {
          final msg = utf8.decode(datagram.data);
          // Try parse JSON response
          try {
            final parsed = jsonDecode(msg) as Map<String, dynamic>;
            if (parsed.containsKey('address')) {
              final addr = parsed['address'].toString();
              if (!completer.isCompleted) completer.complete(addr);
              return;
            }
          } catch (_) {
            // not JSON, fall back to sender address
          }

          // otherwise use datagram.sender
          if (!completer.isCompleted) completer.complete(datagram.address.address);
        } catch (e) {
          if (!completer.isCompleted) completer.complete(null);
        } finally {
          cleanup();
        }
      }
    });

    // Send discovery packet as JSON expected by server
    final payload = jsonEncode({'type': 'server_discovery_request'});
    try {
      // broadcast to 255.255.255.255
      socket.send(utf8.encode(payload), InternetAddress('255.255.255.255'), 8082);
      // Also send directly to common hotspot gateway in case broadcast is blocked
      socket.send(utf8.encode(payload), InternetAddress('192.168.137.1'), 8082);
    } catch (e) {
      print('Discovery: send error: $e');
    }

    // Timeout
    try {
      final result = await completer.future.timeout(timeout);
      print('Discovery result: $result');
      return result;
    } catch (e) {
      print('Discovery timed out');
      cleanup();
      return null;
    }
  }

  Future<void> _connectWebSocket() async {
    if (serverIp == null) {
      print('WebSocket: serverIp is null, cannot connect');
      return;
    }
    
    // FIX #1: Prevent multiple simultaneous connection attempts
    if (_isConnecting) {
      print('WebSocket: Already connecting, skipping duplicate attempt');
      return;
    }
    
    if (_ws != null) {
      print('WebSocket: Already connected, skipping');
      return;
    }

    _isConnecting = true;
    final url = 'ws://$serverIp:8083/ws';
    _setStatus(ConnectionStatus.connecting);

    try {
      print('Connecting to WebSocket: $url');
      _ws = await WebSocket.connect(url);

      print('Connected to WebSocket');
      _setStatus(ConnectionStatus.connected);
      _isConnecting = false;

      // send login immediately
      _sendLogin();

      // flush queue
      while (_outgoingQueue.isNotEmpty) {
        final json = _outgoingQueue.removeAt(0);
        _sendRaw(json);
      }

      _ws?.listen((dynamic data) {
        _handleRawMessage(data);
      }, onDone: () {
        print('WebSocket done');
        _isConnecting = false;
        _onDisconnected();
      }, onError: (err) {
        print('WebSocket error: $err');
        _isConnecting = false;
        _onDisconnected();
      });
    } catch (e) {
      print('WebSocket connect failed: $e');
      _isConnecting = false;
      _onDisconnected();
    }
  }

  void _onDisconnected() {
    _ws = null;
    _setStatus(ConnectionStatus.disconnected);
    if (_shouldReconnect) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    // FIX #1: Only reconnect if enabled
    // Jittered backoff between 3-5 seconds
    const minMs = 3000;
    const maxMs = 5000;
    final wait = minMs + (DateTime.now().millisecondsSinceEpoch % (maxMs - minMs));
    print('Scheduling reconnect in ${wait}ms (will only attempt once on error)');
    _reconnectTimer = Timer(Duration(milliseconds: wait), () async {
      if (!_shouldReconnect) return;
      if (serverIp == null) {
        serverIp = await discoverServer(timeout: const Duration(seconds: 5)) ?? '192.168.137.1';
      }
      // Only attempt reconnect if not already connected or connecting
      if (_ws == null && !_isConnecting) {
        await _connectWebSocket();
      }
    });
  }

  void _setStatus(ConnectionStatus s) {
    if (connectionStatus.value != s) {
      connectionStatus.value = s;
      print('Connection status: $s');
    }
  }

  void _handleRawMessage(dynamic data) {
    try {
      String txt;
      if (data is String) {
        txt = data;
      } else if (data is List<int>) {
        txt = utf8.decode(data);
      } else {
        txt = data.toString();
      }
      final parsed = jsonDecode(txt) as Map<String, dynamic>;
      final type = parsed['type']?.toString() ?? '';

      if (type == 'message' || type == 'chat' || type == 'chat_message') {
        // normalize incoming chat
        _incomingController.add(parsed);
        print('Incoming message from ${parsed['from']}: ${parsed['text'] ?? parsed['message']}');
      } else {
        // other types
        _incomingController.add(parsed);
        print('Incoming event: $type');
      }
    } catch (e) {
      print('Failed to parse incoming WS message: $e');
    }
  }

  Future<void> _sendLogin() async {
    if (_ws == null) {
      print('Login deferred: websocket not connected');
      return;
    }
    final login = {
      'type': 'login',
      'userId': _userId ?? '',
      'displayName': _name ?? _userId ?? '',
      'role': _role ?? 'student',
      'deviceName': _deviceName,
    };
    final jsonStr = jsonEncode(login);
    print('Login sent for user: ${_userId}');
    _sendRaw(jsonStr);
  }

  /// Request online users list from server and wait for response.
  /// FIX #9: Throttled - only request every 30 seconds at minimum
  /// skipThrottle: If true, bypass throttle (for group creation UI that needs immediate response)
  Future<List<dynamic>> fetchOnlineUsersRaw({Duration timeout = const Duration(seconds: 5), bool skipThrottle = false}) async {
    // If websocket is not connected, return empty list immediately
    if (_ws == null || connectionStatus.value != ConnectionStatus.connected) {
      return <dynamic>[];
    }

    // FIX #9: Prevent spam - throttle to once per 30 seconds (unless skipThrottle=true)
    if (!skipThrottle) {
      final now = DateTime.now();
      final msSinceLastFetch = now.difference(_lastOnlineUsersFetch).inMilliseconds;
      if (msSinceLastFetch < _onlineUsersFetchIntervalMs) {
        print('Throttled: Skipping online users fetch (last was ${msSinceLastFetch}ms ago)');
        return <dynamic>[];
      }
    }
    _lastOnlineUsersFetch = DateTime.now();

    final completer = Completer<List<dynamic>>();
    StreamSubscription? sub;
    sub = incomingMessages.listen((msg) {
      try {
        if (msg['type'] == 'online_users') {
          final users = msg['users'] as List<dynamic>? ?? [];
          if (!completer.isCompleted) completer.complete(users);
        }
      } catch (e) {
        if (!completer.isCompleted) completer.complete(<dynamic>[]);
      }
    });

    // Send request
    final request = jsonEncode({'type': 'get_online_users'});
    _sendRaw(request);

    try {
      final users = await completer.future.timeout(timeout);
      return users;
    } catch (e) {
      if (!completer.isCompleted) completer.complete(<dynamic>[]);
      return <dynamic>[];
    } finally {
      await sub?.cancel();
    }
  }

  Future<List<OnlineUser>> fetchOnlineUsers({Duration timeout = const Duration(seconds: 5), bool skipThrottle = false}) async {
    final raw = await fetchOnlineUsersRaw(timeout: timeout, skipThrottle: skipThrottle);
    final List<OnlineUser> out = [];
    for (final u in raw) {
      try {
        out.add(OnlineUser.fromJson(Map<String, dynamic>.from(u as Map)));
      } catch (_) {}
    }
    return out;
  }

  void _sendRaw(String jsonStr) {
    print('🟡 [_sendRaw] Called');
    print('🟡 [_sendRaw]   WebSocket: ${_ws != null ? 'connected' : 'null'}');
    print('🟡 [_sendRaw]   Status: ${connectionStatus.value}');
    print('🟡 [_sendRaw]   JSON length: ${jsonStr.length} bytes');
    print('🟡 [_sendRaw]   First 80 chars: ${jsonStr.substring(0, jsonStr.length > 80 ? 80 : jsonStr.length)}');
    
    if (_ws != null) {
      try {
        print('🟡 [_sendRaw] WebSocket is connected, calling add()...');
        _ws!.add(jsonStr);
        print('🟡 [_sendRaw] ✅ WebSocket.add() succeeded - MESSAGE SENT!');
      } catch (e) {
        print('🟡 [_sendRaw] ❌ WebSocket.add() failed: $e');
        print('🟡 [_sendRaw] Queueing message for retry');
        _outgoingQueue.add(jsonStr);
      }
    } else {
      print('🟡 [_sendRaw] ⚠️ WebSocket is null, queueing message');
      _outgoingQueue.add(jsonStr);
      print('🟡 [_sendRaw]   Queue now has ${_outgoingQueue.length} messages');
    }
  }

  /// Send chat message to specific userId. Non-blocking; queues if disconnected.
  Future<void> sendChatMessage(String toUserId, String message) async {
    final payload = {
      'type': 'chat_message',
      'from': _userId ?? 'unknown',
      'to': toUserId,
      'message': message,
      'timestamp': DateTime.now().toIso8601String(),
    };
    final jsonStr = jsonEncode(payload);
    _sendRaw(jsonStr);
    print('Sent chat to $toUserId: $message');
  }

  /// Send raw JSON message (public interface for custom message types)
  void sendMessage(Map<String, dynamic> payload) {
    print('\n🔵 [ConnectionService.sendMessage] ============================================');
    print('🔵 [ConnectionService] CALLED with payload:');
    print('🔵 [ConnectionService]   Type: ${payload['type']}');
    print('🔵 [ConnectionService]   Keys: ${payload.keys.toList()}');
    
    if (payload['type'] == 'chat_message') {
      print('🔵 [ConnectionService]   from: ${payload['from']}');
      print('🔵 [ConnectionService]   to: ${payload['to']}');
      print('🔵 [ConnectionService]   message: ${payload['message']}');
      print('🔵 [ConnectionService]   has iv: ${payload.containsKey('iv')}');
      print('🔵 [ConnectionService]   has ciphertext: ${payload.containsKey('ciphertext')}');
    }
    
    print('🔵 [ConnectionService] WebSocket state: _ws=${_ws != null ? 'connected' : 'null'}');
    print('🔵 [ConnectionService] Connection status: ${connectionStatus.value}');
    
    final jsonStr = jsonEncode(payload);
    print('🔵 [ConnectionService] JSON encoded (${jsonStr.length} bytes)');
    print('🔵 [ConnectionService] Calling _sendRaw()...');
    _sendRaw(jsonStr);
    print('🔵 [ConnectionService] _sendRaw() returned');
    print('🔵 [ConnectionService] ============================================\n');
  }

  /// Forcefully close connection (e.g., on logout)
  Future<void> close({bool stopReconnect = true}) async {
    _shouldReconnect = !stopReconnect ? true : false;
    _reconnectTimer?.cancel();
    try {
      await _ws?.close();
    } catch (_) {}
    _ws = null;
    _setStatus(ConnectionStatus.disconnected);
  }

  /// Connect directly to a given server IP (skips discovery)
  Future<void> connectTo(String ip) async {
    serverIp = ip;
    await _connectWebSocket();
  }

  void dispose() {
    _incomingController.close();
    _reconnectTimer?.cancel();
  }
}
