import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/chat_message.dart';
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

  // Current user info (set by init)
  String? _userId;
  String? _name;
  String? _role;
  String _deviceName = 'Android Device';

  // Reconnect control
  bool _shouldReconnect = true;
  Timer? _reconnectTimer;

  // Simple outgoing queue (string JSONs) when disconnected
  final List<String> _outgoingQueue = [];

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

    // Discover server (UDP) with 5s timeout
    serverIp = await discoverServer(timeout: const Duration(seconds: 5));
    serverIp ??= '192.168.137.1';

    print('ConnectionService: discovery result: $serverIp');

    // Connect websocket and send login
    await _connectWebSocket();
  }

  // Public getter for current user id
  String? get currentUserId => _userId;

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
    if (_ws != null) {
      print('WebSocket: already connected or connecting');
      return;
    }

    final url = 'ws://$serverIp:8083/ws';
    _setStatus(ConnectionStatus.connecting);

    try {
      print('Connecting to WebSocket: $url');
      _ws = await WebSocket.connect(url);

      print('Connected to WebSocket');
      _setStatus(ConnectionStatus.connected);

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
        _onDisconnected();
      }, onError: (err) {
        print('WebSocket error: $err');
        _onDisconnected();
      });
    } catch (e) {
      print('WebSocket connect failed: $e');
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
    // jittered backoff between 3-5 seconds
    const minMs = 3000;
    const maxMs = 5000;
    final wait = minMs + (DateTime.now().millisecondsSinceEpoch % (maxMs - minMs));
    print('Scheduling reconnect in ${wait}ms');
    _reconnectTimer = Timer(Duration(milliseconds: wait), () async {
      if (!_shouldReconnect) return;
      if (serverIp == null) {
        serverIp = await discoverServer(timeout: const Duration(seconds: 5)) ?? '192.168.137.1';
      }
      await _connectWebSocket();
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

      if (type == 'message' || type == 'chat') {
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
  Future<List<dynamic>> fetchOnlineUsersRaw({Duration timeout = const Duration(seconds: 5)}) async {
    // If websocket is not connected, return empty list immediately
    if (_ws == null || connectionStatus.value != ConnectionStatus.connected) {
      return <dynamic>[];
    }

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

  Future<List<OnlineUser>> fetchOnlineUsers({Duration timeout = const Duration(seconds: 5)}) async {
    final raw = await fetchOnlineUsersRaw(timeout: timeout);
    final List<OnlineUser> out = [];
    for (final u in raw) {
      try {
        out.add(OnlineUser.fromJson(Map<String, dynamic>.from(u as Map)));
      } catch (_) {}
    }
    return out;
  }

  void _sendRaw(String jsonStr) {
    if (_ws != null) {
      try {
        _ws!.add(jsonStr);
      } catch (e) {
        print('Send failed, queueing message: $e');
        _outgoingQueue.add(jsonStr);
      }
    } else {
      _outgoingQueue.add(jsonStr);
    }
  }

  /// Send chat message to specific userId. Non-blocking; queues if disconnected.
  Future<void> sendChatMessage(String toUserId, String message) async {
    final payload = {
      'type': 'chat',
      'from': _userId ?? 'unknown',
      'to': toUserId,
      'message': message,
      'timestamp': DateTime.now().toIso8601String(),
    };
    final jsonStr = jsonEncode(payload);
    _sendRaw(jsonStr);
    print('Sent chat to $toUserId: $message');
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
