import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:logger/logger.dart';

class ServerDiscoveryService {
  static const String _discoveryBroadcastPort = '8082';
  static const String _discoveryUdpPort = 8081;
  static const int _discoveryTimeout = 5000; // 5 seconds
  
  final Logger _logger = Logger();
  RawDatagramSocket? _udpSocket;
  ServerSocket? _serverSocket;
  Timer? _discoveryTimer;
  
  String? _serverAddress;
  int? _serverPort;
  bool _isDiscovering = false;
  
  // Getters
  String? get serverAddress => _serverAddress;
  int? get serverPort => _serverPort;
  bool get isDiscovering => _isDiscovering;
  bool get hasDiscoveredServer => _serverAddress != null && _serverPort != null;
  
  /// Start listening for discovery broadcasts from the server
  Future<String?> discoverServer({
    String? configuredServerIp,
    int configuredServerPort = 8083,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      _isDiscovering = true;
      _logger.i('Starting server discovery...');
      
      // If configured IP is provided, try that first
      if (configuredServerIp != null && configuredServerIp.isNotEmpty) {
        final result = await _verifyServerConnection(
          configuredServerIp, 
          configuredServerPort,
          timeout: timeout,
        );
        if (result) {
          _serverAddress = configuredServerIp;
          _serverPort = configuredServerPort;
          _logger.i('Connected to configured server: $_serverAddress:$_serverPort');
          _isDiscovering = false;
          return '$_serverAddress:$_serverPort';
        }
      }
      
      // Try UDP broadcast discovery
      _logger.i('Attempting UDP broadcast discovery...');
      final discoveredServer = await _performUdpBroadcastDiscovery(timeout);
      if (discoveredServer != null) {
        _logger.i('Server discovered via UDP: $discoveredServer');
        _isDiscovering = false;
        return discoveredServer;
      }
      
      _logger.w('Server discovery failed - no server found');
      _isDiscovering = false;
      return null;
      
    } catch (e, stackTrace) {
      _logger.e('Server discovery error', e, stackTrace);
      _isDiscovering = false;
      return null;
    }
  }
  
  /// Perform UDP broadcast discovery
  Future<String?> _performUdpBroadcastDiscovery(Duration timeout) async {
    try {
      _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _udpSocket!.broadcastEnabled = true;
      
      final completer = Completer<String?>();
      final subscription = _udpSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _udpSocket!.receive();
          if (datagram != null) {
            try {
              final message = String.fromCharCodes(datagram.data);
              final json = jsonDecode(message) as Map<String, dynamic>;
              
              if (json['type'] == 'server_discovery_response') {
                final serverAddress = json['address'] as String?;
                final serverPort = json['port'] as int? ?? 8083;
                
                if (serverAddress != null) {
                  _serverAddress = serverAddress;
                  _serverPort = serverPort;
                  _logger.i('Discovered server: $serverAddress:$serverPort');
                  
                  if (!completer.isCompleted) {
                    completer.complete('$serverAddress:$serverPort');
                  }
                }
              }
            } catch (e) {
              _logger.w('Error parsing discovery message: $e');
            }
          }
        }
      });
      
      // Send broadcast discovery request
      try {
        const discoveryMessage = '{"type":"server_discovery_request"}';
        _udpSocket!.send(
          utf8.encode(discoveryMessage),
          InternetAddress('255.255.255.255'),
          int.parse(_discoveryBroadcastPort),
        );
        _logger.d('Sent UDP broadcast discovery request');
      } catch (e) {
        _logger.w('Error sending broadcast: $e');
      }
      
      // Wait for response or timeout
      final result = await completer.future
          .timeout(timeout, onTimeout: () => null);
      
      subscription.cancel();
      await _udpSocket?.close();
      _udpSocket = null;
      
      return result;
      
    } catch (e, stackTrace) {
      _logger.e('UDP broadcast discovery error', e, stackTrace);
      await _udpSocket?.close();
      _udpSocket = null;
      return null;
    }
  }
  
  /// Verify server connection by attempting TCP handshake
  Future<bool> _verifyServerConnection(
    String address,
    int port, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    try {
      final socket = await Socket.connect(address, port)
          .timeout(timeout, onTimeout: () => throw SocketException('Connection timeout'));
      
      // Send a ping message to verify server
      socket.write('{"type":"ping"}\n');
      await socket.flush();
      
      // Wait for pong response
      final response = await socket.first.timeout(timeout);
      socket.close();
      
      return response.isNotEmpty;
      
    } catch (e) {
      _logger.d('Server connection verification failed for $address:$port - $e');
      return false;
    }
  }
  
  /// Get full server URL
  String? getServerUrl() {
    if (_serverAddress != null && _serverPort != null) {
      return 'ws://$_serverAddress:$_serverPort';
    }
    return null;
  }
  
  /// Start autodiscovery polling (for periodic rediscovery)
  void startAutodiscovery({
    Duration interval = const Duration(minutes: 1),
    String? configuredServerIp,
    int configuredServerPort = 8083,
  }) {
    _discoveryTimer?.cancel();
    _discoveryTimer = Timer.periodic(interval, (_) {
      discoverServer(
        configuredServerIp: configuredServerIp,
        configuredServerPort: configuredServerPort,
      );
    });
  }
  
  /// Stop autodiscovery polling
  void stopAutodiscovery() {
    _discoveryTimer?.cancel();
    _discoveryTimer = null;
  }
  
  /// Cleanup resources
  Future<void> dispose() async {
    stopAutodiscovery();
    await _udpSocket?.close();
    await _serverSocket?.close();
  }
}
