import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:logger/logger.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import '../config/server_config.dart';
import 'identity_service.dart';

typedef MessageCallback = void Function(dynamic data);
typedef FileProgressCallback = void Function(int sent, int total);

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;

  WebSocketService._internal();

  final Logger _logger = Logger(
    printer: PrettyPrinter(methodCount: 0, errorMethodCount: 5, lineLength: 80, colors: true),
  );

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  StreamSubscription? _connectivitySubscription;

  final StreamController<dynamic> _messageController = StreamController<dynamic>.broadcast();
  final StreamController<bool> _connectionStateController = StreamController<bool>.broadcast();

  final List<Map<String, dynamic>> _messageQueue = [];
  final Map<String, List<MessageCallback>> _listeners = {};
  final Map<String, Completer<dynamic>> _pendingRequests = {};

  String? _userId;
  bool _isConnected = false;
  bool _isConnecting = false;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  DateTime _lastHeartbeat = DateTime.fromMillisecondsSinceEpoch(0);

  // File receive buffers
  final Map<String, Map<int, Uint8List>> _fileChunks = {};
  final Map<String, Map<String, dynamic>> _fileMeta = {};

  // Public streams
  Stream<dynamic> get messageStream => _messageController.stream;
  Stream<bool> get connectionState => _connectionStateController.stream;
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;

  // Initialize and attempt connection when on CampusNet Wi‑Fi
  Future<void> initialize() async {
    if (_isConnected || _isConnecting) return;
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('userId');
    // Derive a default userId from device IP if none stored yet
    if (_userId == null || _userId!.isEmpty) {
      try {
        final networkInfo = NetworkInfo();
        final wifiIP = await networkInfo.getWifiIP();
        if (wifiIP != null && wifiIP.isNotEmpty) {
          _userId = 'ip:$wifiIP';
          await prefs.setString('userId', _userId!);
        }

  // Send a raw server message with top-level 'type' (e.g., type: 'message')
  Future<void> sendType(String type, Map<String, dynamic> fields) async {
    final map = {'type': type, ...fields};
    if (!_isConnected) {
      _enqueue(type, map, waitForResponse: false);
      _scheduleReconnect();
      return;
    }
    _channel!.sink.add(jsonEncode(map));
  }
      } catch (_) {}
    }
    _setupNetworkListeners();
    await _checkNetworkAndConnect();
  }

  Future<void> connect() async {
    await initialize();
  }

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    await _subscription?.cancel();
    await _channel?.sink.close(status.normalClosure);
    _subscription = null;
    _channel = null;
    _isConnected = false;
    _isConnecting = false;
    _connectionStateController.add(false);
    _notifyConnectionStatus(false, message: 'Disconnected from CampusNet');
  }

  void _setupNetworkListeners() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) async {
      if (result == ConnectivityResult.wifi) {
        await _checkNetworkAndConnect();
      } else {
        await disconnect();
      }
    });
  }

  Future<void> _checkNetworkAndConnect() async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity != ConnectivityResult.wifi) {
        _notifyConnectionStatus(false, message: 'Please connect to CampusNet Wi‑Fi');
        return;
      }

      // Ensure we are on a private LAN (e.g., 192.168.137.x hotspot)
      final networkInfo = NetworkInfo();
      final wifiIP = await networkInfo.getWifiIP();
      if (wifiIP == null ||
          !(wifiIP.startsWith('192.168.') || wifiIP.startsWith('10.') || wifiIP.startsWith('172.'))) {
        _notifyConnectionStatus(false, message: 'Please connect to CampusNet Wi‑Fi');
        return;
      }

      if (!_isConnected && !_isConnecting) {
        await _openChannel();
      }
    } catch (e, st) {
      _logger.e('Network check failed', error: e, stackTrace: st);
      _notifyConnectionStatus(false, message: 'Network error. Retrying...');
      _scheduleReconnect();
    }
  }

  Future<void> _openChannel() async {
    _isConnecting = true;
    final url = Uri.parse('${ServerConfig.webSocketUrl}?userId=${Uri.encodeQueryComponent(_userId ?? '')}&device=flutter&v=1');
    _logger.i('Connecting to $url');
    try {
      // Close any existing channel
      await _subscription?.cancel();
      await _channel?.sink.close(status.goingAway);

      final channel = WebSocketChannel.connect(url);
      try { await channel.ready; } catch (_) {}

      _channel = channel;
      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: true,
      );

      _isConnected = true;
      _isConnecting = false;
      _reconnectAttempts = 0;
      _connectionStateController.add(true);
      _notifyConnectionStatus(true, message: 'Connected to CampusNet');
      _startHeartbeat();
      _drainQueue();
      _logger.i('WebSocket connected');

      // Send login handshake expected by server
      try {
        final identity = IdentityService.identityPayload(userId: _userId ?? '');
        final payload = {
          'type': 'login',
          'userId': identity['userId'],
          'displayName': identity['displayName'],
        };
        _channel?.sink.add(jsonEncode(payload));
      } catch (e) {
        _logger.w('Failed to send login handshake: $e');
      }
    } catch (e, st) {
      _isConnecting = false;
      _logger.e('WebSocket connect failed', error: e, stackTrace: st);
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic message) {
    try {
      if (message == null) return;
      if (message == 'ping') { _channel?.sink.add('pong'); _lastHeartbeat = DateTime.now(); return; }
      if (message == 'pong') { _lastHeartbeat = DateTime.now(); return; }

      final data = jsonDecode(message);
      // Support both {type: ...} (server) and {event: ..., data: ...}
      final event = (data['type'] ?? data['event']) as String?;
      final payload = data.containsKey('data') ? data['data'] : data;
      final requestId = data['requestId'];

      if (event == 'heartbeat') { _lastHeartbeat = DateTime.now(); return; }

      if (requestId != null && _pendingRequests.containsKey(requestId)) {
        if (data['error'] != null) {
          _pendingRequests.remove(requestId)?.completeError(data['error']);
        } else {
          _pendingRequests.remove(requestId)?.complete(payload);
        }
        return;
      }

      // Handle file transfer receive
      if (event == 'file_chunk') {
        _handleIncomingFileChunk(payload);
        return;
      }
      if (event == 'file_complete') {
        unawaited(_finalizeIncomingFile(payload));
        return;
      }

      if (event != null && _listeners.containsKey(event)) {
        for (final cb in List<MessageCallback>.from(_listeners[event]!)) {
          cb(payload);
        }
      }

      _messageController.add(data);
    } catch (e, st) {
      _logger.e('Message handling error', error: e, stackTrace: st);
    }
  }

  void _onError(dynamic error) {
    _logger.e('WebSocket error: $error');
    _handleDisconnect();
  }

  void _onDone() {
    _logger.w('WebSocket closed');
    _handleDisconnect();
  }

  void _handleDisconnect() {
    if (!_isConnected && !_isConnecting) return;
    _isConnected = false;
    _isConnecting = false;
    _heartbeatTimer?.cancel();
    _connectionStateController.add(false);
    _notifyConnectionStatus(false, message: 'Reconnecting to CampusNet...');
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_isConnected || _isConnecting) return;
    if (_reconnectAttempts >= ServerConfig.maxReconnectAttempts) {
      _logger.w('Max reconnection attempts reached');
      return;
    }
    _reconnectTimer?.cancel();
    _reconnectAttempts++;
    final delay = Duration(seconds: min(30, (1 << _reconnectAttempts))) + Duration(milliseconds: Random().nextInt(500));
    _logger.i('Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts)');
    _reconnectTimer = Timer(delay, _checkNetworkAndConnect);
  }

  // Public manual reconnect trigger for UI Retry
  Future<void> reconnect() async {
    if (_isConnecting) return;
    _reconnectTimer?.cancel();
    _reconnectAttempts = 0;
    await _checkNetworkAndConnect();
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _lastHeartbeat = DateTime.now();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_isConnected) { _heartbeatTimer?.cancel(); return; }
      try {
        // Send a simple ping string; server ignores non-JSON or can respond with pong if implemented
        _channel?.sink.add('ping');
      } catch (e) {
        _logger.e('Heartbeat send failed: $e');
        _handleDisconnect();
      }
    });
  }

  // Public send API
  Future<dynamic> send(String event, dynamic data, {bool waitForResponse = false}) async {
    if (!_isConnected) {
      _enqueue(event, data, waitForResponse: waitForResponse);
      _scheduleReconnect();
      if (waitForResponse) throw SocketException('Not connected');
      return null;
    }

    final requestId = waitForResponse ? DateTime.now().microsecondsSinceEpoch.toString() : null;
    final message = {
      'event': event,
      'data': data,
      'requestId': requestId,
      'timestamp': DateTime.now().toIso8601String(),
    };

    _channel!.sink.add(jsonEncode(message));
    if (requestId == null) return null;

    final completer = Completer<dynamic>();
    _pendingRequests[requestId] = completer;
    Timer(const Duration(seconds: 10), () {
      if (_pendingRequests.remove(requestId) != null && !completer.isCompleted) {
        completer.completeError(TimeoutException('No response from server'));
      }
    });
    return completer.future;
  }

  // File send in chunks (server protocol: fileMeta then fileChunk)
  Future<void> sendFile(String fileId, String fileName, Uint8List data, {required String receiverId, FileProgressCallback? onProgress}) async {
    const chunkSize = 16 * 1024;
    final total = data.length;
    // Send metadata first
    final meta = {
      'type': 'fileMeta',
      'to': receiverId,
      'fileId': fileId,
      'name': fileName,
      'size': total,
      'mime': 'application/octet-stream',
    };
    _channel?.sink.add(jsonEncode(meta));

    var sent = 0;
    var seq = 0;
    for (var i = 0; i < total; i += chunkSize) {
      final end = min(i + chunkSize, total);
      final chunk = data.sublist(i, end);
      final eof = end >= total;
      final message = {
        'type': 'fileChunk',
        'to': receiverId,
        'fileId': fileId,
        'seq': seq,
        'eof': eof,
        'dataBase64': base64Encode(chunk),
      };
      _channel?.sink.add(jsonEncode(message));
      sent = end;
      seq++;
      onProgress?.call(sent, total);
      await Future.delayed(const Duration(milliseconds: 2));
    }
  }

  // Listener helpers
  void addListener(String event, MessageCallback callback) {
    _listeners.putIfAbsent(event, () => []).add(callback);
  }

  void removeListener(String event, MessageCallback callback) {
    _listeners[event]?.remove(callback);
    if (_listeners[event]?.isEmpty == true) _listeners.remove(event);
  }

  void _notifyConnectionStatus(bool isConnected, {String? message}) {
    if (_listeners.containsKey('connection')) {
      for (final cb in List<MessageCallback>.from(_listeners['connection']!)) {
        cb({'isConnected': isConnected, 'message': message, 'server': ServerConfig.baseUrl});
      }
    }
  }

  void _enqueue(String event, dynamic data, {bool waitForResponse = false}) {
    _messageQueue.add({'event': event, 'data': data, 'waitForResponse': waitForResponse, 'timestamp': DateTime.now().toIso8601String()});
  }

  void _drainQueue() async {
    while (_isConnected && _messageQueue.isNotEmpty) {
      final m = _messageQueue.removeAt(0);
      try {
        await send(m['event'] as String, m['data'], waitForResponse: m['waitForResponse'] == true);
        await Future.delayed(const Duration(milliseconds: 50));
      } catch (e) {
        _logger.w('Queue send failed; re-enqueue');
        _messageQueue.insert(0, m);
        break;
      }
    }
  }

  void _handleIncomingFileChunk(dynamic payload) {
    if (payload == null) return;
    try {
      final String fileId = payload['fileId']?.toString() ?? '';
      final String fileName = payload['fileName']?.toString() ?? 'file.bin';
      final int chunkIndex = payload['chunkIndex'] is int
          ? payload['chunkIndex']
          : int.tryParse(payload['chunkIndex']?.toString() ?? '0') ?? 0;
      final int totalChunks = payload['totalChunks'] is int
          ? payload['totalChunks']
          : int.tryParse(payload['totalChunks']?.toString() ?? '0') ?? 0;
      final String b64 = payload['data']?.toString() ?? '';

      if (fileId.isEmpty || b64.isEmpty) return;

      _fileMeta.putIfAbsent(fileId, () => {'fileName': fileName, 'totalChunks': totalChunks});
      final chunks = _fileChunks.putIfAbsent(fileId, () => <int, Uint8List>{});
      chunks[chunkIndex] = base64Decode(b64);
    } catch (e, st) {
      _logger.e('Failed to handle file_chunk', error: e, stackTrace: st);
    }
  }

  Future<void> _finalizeIncomingFile(dynamic payload) async {
    if (payload == null) return;
    try {
      final String fileId = payload['fileId']?.toString() ?? '';
      if (fileId.isEmpty) return;

      final meta = _fileMeta[fileId] ?? {};
      final String fileName = meta['fileName']?.toString() ?? payload['fileName']?.toString() ?? 'file.bin';
      final int totalChunks = meta['totalChunks'] is int
          ? meta['totalChunks']
          : int.tryParse(meta['totalChunks']?.toString() ?? payload['totalChunks']?.toString() ?? '0') ?? 0;
      final chunks = _fileChunks[fileId] ?? {};

      if (totalChunks == 0 || chunks.length != totalChunks) {
        _logger.w('File not complete yet: $fileId (${chunks.length}/$totalChunks)');
        return;
      }

      final buffer = BytesBuilder(copy: false);
      for (var i = 0; i < totalChunks; i++) {
        final part = chunks[i];
        if (part == null) {
          _logger.w('Missing chunk $i for $fileId');
          return;
        }
        buffer.add(part);
      }

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(buffer.takeBytes(), flush: true);

      _fileChunks.remove(fileId);
      _fileMeta.remove(fileId);

      // Notify listeners
      if (_listeners.containsKey('file_saved')) {
        for (final cb in List<MessageCallback>.from(_listeners['file_saved']!)) {
          cb({'fileId': fileId, 'fileName': fileName, 'path': file.path});
        }
      }
    } catch (e, st) {
      _logger.e('Failed to finalize file', error: e, stackTrace: st);
    }
  }
}
