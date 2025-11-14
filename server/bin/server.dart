import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

/// Enhanced CampusNet Server with Real-Time Device Tracking
/// Features:
/// - Automatic hotspot enable/management
/// - Real-time device connection tracking
/// - Network statistics from Windows
/// - Live device list updates
/// 
/// Listens on ws://<LAN-IP>:8083/ws
/// Protocol: JSON messages with a `type` field.
/// - login: {type:"login", userId:"C123", displayName:"Alice"}
/// - message: {type:"message", to:"<userId|room:roomId>", text:"Hello"}
/// - announcement: {type:"announcement", text:"..."}
/// - fileChunk: {type:"fileChunk", fileId:"...", seq:0, eof:false, dataBase64:"..."}

class Client {
  final WebSocket socket;
  final String clientIp;
  final DateTime connectedAt;
  String? userId;
  String? displayName;
  String? role; // Student or Faculty

  Client(this.socket, this.clientIp, this.connectedAt);
  
  Map<String, dynamic> toMap() {
    return {
      'ip': clientIp,
      'userId': userId ?? 'Not logged in',
      'displayName': displayName ?? 'Anonymous',
      'role': role ?? 'N/A',
      'connectedAt': connectedAt.toIso8601String(),
      'connectionDuration': DateTime.now().difference(connectedAt).inSeconds,
    };
  }
}

class Room {
  final String roomId;
  final Set<String> members = {};
  Room(this.roomId);
}

class ServerState {
  final Map<WebSocket, Client> clients = {};
  final Map<String, WebSocket> userSocket = {};
  final Map<String, Room> rooms = {};
  final List<Map<String, dynamic>> disconnectedDevices = [];

  void addClient(WebSocket ws, String clientIp) {
    clients[ws] = Client(ws, clientIp, DateTime.now());
  }

  void removeClient(WebSocket ws) {
    final c = clients.remove(ws);
    if (c != null && c.userId != null) {
      userSocket.remove(c.userId);
      // Store disconnected device info for history
      disconnectedDevices.add({
        ...c.toMap(),
        'disconnectedAt': DateTime.now().toIso8601String(),
      });
      // Keep only last 10 disconnections
      if (disconnectedDevices.length > 10) {
        disconnectedDevices.removeAt(0);
      }
      for (final room in rooms.values) {
        room.members.remove(c.userId);
      }
    }
  }
  
  int get totalConnectedDevices => clients.length;
  int get totalLoggedInUsers => clients.values.where((c) => c.userId != null).length;
}

void _handleFileComplete(ServerState state, WebSocket ws, Map<String, dynamic> msg) {
  final fromClient = state.clients[ws];
  if (fromClient == null || fromClient.userId == null) {
    _send(ws, {'type': 'error', 'error': 'not_logged_in'});
    return;
  }
  final to = (msg['to'] ?? '').toString();
  final forward = {
    'type': 'fileComplete',
    'from': fromClient.userId,
    'to': to,
    'fileId': msg['fileId'],
    'fileName': msg['fileName'],
    'fileSize': msg['fileSize'],
    'ts': DateTime.now().toIso8601String(),
  };
  if (to.isEmpty) {
    _broadcast(state, forward);
  } else {
    _routeTo(state, to, forward);
    _send(ws, forward);
  }
}

void _handleSignal(ServerState state, WebSocket ws, Map<String, dynamic> msg) {
  final fromClient = state.clients[ws];
  if (fromClient == null || fromClient.userId == null) {
    _send(ws, {'type': 'error', 'error': 'not_logged_in'});
    return;
  }
  final to = (msg['to'] ?? '').toString();
  if (to.isEmpty) {
    _send(ws, {'type': 'error', 'error': 'invalid_target'});
    return;
  }
  final payload = Map<String, dynamic>.from(msg)
    ..['from'] = fromClient.userId
    ..['ts'] = DateTime.now().toIso8601String();
  _routeTo(state, to, payload);
}

/// Check if running with admin privileges
Future<bool> _isRunningAsAdmin() async {
  try {
    final result = await Process.run('net', ['session'], runInShell: true);
    return result.exitCode == 0;
  } catch (_) {
    return false;
  }
}

/// Get hotspot status from Windows
Future<String> _getHotspotStatus() async {
  try {
    final result = await Process.run('netsh', [
      'wlan',
      'show',
      'hostednetwork',
    ], runInShell: true);
    
    if (result.stdout.toString().contains('Status') && result.stdout.toString().contains('Started')) {
      return 'started';
    } else if (result.stdout.toString().contains('Status') && result.stdout.toString().contains('Stopped')) {
      return 'stopped';
    }
    return 'unknown';
  } catch (e) {
    return 'error: $e';
  }
}

/// Enable Windows Mobile Hotspot with robust error handling
Future<bool> _enableMobileHotspot() async {
  try {
    print('🔌 Configuring Mobile Hotspot...');
    print('   SSID: CampusNet');
    print('   Password: CampusNet2025');
    
    // Check admin privileges
    final isAdmin = await _isRunningAsAdmin();
    if (!isAdmin) {
      print('⚠️  WARNING: This server is NOT running with administrator privileges');
      print('   Hotspot may not start automatically.');
      print('   Please run this server as Administrator (Run as Administrator)');
      print('');
    }
    
    // Set hosted network configuration
    print('📋 Setting hosted network configuration...');
    final configResult = await Process.run('netsh', [
      'wlan',
      'set',
      'hostednetwork',
      'mode=allow',
      'ssid=CampusNet',
      'key=CampusNet2025',
    ], runInShell: true);
    
    if (configResult.exitCode == 0) {
      print('✓ Hotspot configuration updated');
    } else {
      print('⚠️  Could not set configuration: ${configResult.stderr}');
    }
    
    // Wait a bit for configuration to apply
    await Future.delayed(const Duration(milliseconds: 800));
    
    // Start the hosted network
    print('🚀 Starting hosted network...');
    final startResult = await Process.run('netsh', [
      'wlan',
      'start',
      'hostednetwork',
    ], runInShell: true);
    
    if (startResult.exitCode == 0) {
      print('✓ Mobile Hotspot STARTED successfully');
      print('  📱 WiFi Network: CampusNet');
      print('  🔐 Password: CampusNet2025');
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Check status to confirm
      final status = await _getHotspotStatus();
      if (status == 'started') {
        print('  ✓ Status: RUNNING');
        return true;
      }
    } else {
      final stderr = startResult.stderr.toString().toLowerCase();
      if (stderr.contains('already') || stderr.contains('running')) {
        print('✓ Hotspot already running');
        final status = await _getHotspotStatus();
        if (status == 'started') {
          print('  ✓ Status: RUNNING');
          return true;
        }
      } else if (stderr.contains('admin') || stderr.contains('privilege')) {
        print('❌ ADMIN PRIVILEGES REQUIRED');
        print('   Please restart this server with Administrator access');
        return false;
      } else {
        print('⚠️  Start command result: ${startResult.stderr}');
      }
    }
    return false;
  } catch (e) {
    print('❌ Error enabling hotspot: $e');
    print('   Please enable it manually from Settings > Network & Internet > Mobile hotspot');
    return false;
  }
}

/// Display real-time connected devices (from Windows network)
Future<List<Map<String, dynamic>>> _getConnectedDevices([ServerState? state]) async {
  // Strict ARP-only scanner targeted to Windows Mobile Hotspot (192.168.137.x)
  // Steps:
  // 1) Refresh ARP cache (try to delete and ping hotspot gateway)
  // 2) Read `arp -a` output
  // 3) Parse and filter only valid hotspot client IPs

  Future<void> _refreshArpCache() async {
    try {
      // Delete ARP cache entries (best-effort, may require admin)
      await Process.run('arp', ['-d'], runInShell: true);
    } catch (_) {
      // ignore
    }
    try {
      // Ping the hotspot gateway to force ARP population
      await Process.run('ping', ['-n', '1', '192.168.137.1'], runInShell: true);
    } catch (_) {
      // ignore
    }
    // small delay to let ARP table update
    await Future.delayed(const Duration(milliseconds: 300));
  }

  final results = <Map<String, dynamic>>[];

  // Refresh ARP entries first
  await _refreshArpCache();

  try {
    final arp = await Process.run('arp', ['-a'], runInShell: true);
    final out = arp.stdout.toString();
    final lines = out.split(RegExp(r'\r?\n'));

    // Regex: IP, whitespace, MAC, whitespace, type
    final arpRe = RegExp(r"(\d+\.\d+\.\d+\.\d+)\s+([0-9a-fA-F:-]{11,17})\s+(\w+)");

    for (final line in lines) {
      final m = arpRe.firstMatch(line);
      if (m == null) continue;
      final ip = m.group(1)!.trim();
      var mac = m.group(2)!.trim().toLowerCase();
      final type = m.group(3)!.trim().toLowerCase();

      // Normalize MAC to hyphen-separated lower-case (xx-xx-...)
      mac = mac.replaceAll(':', '-').replaceAll('.', '-');
      mac = mac.split('-').map((p) => p.padLeft(2, '0')).join('-');

      // Filtering rules (only accept real hotspot clients)
      // - IP must be in 192.168.137.2..192.168.137.254
      // - Exclude 192.168.137.1 (gateway) and 192.168.137.255
      // - Exclude multicast (224.*, 239.*), broadcast 255.255.255.255, and 10.* addresses

      if (!ip.startsWith('192.168.137.')) continue;
      if (ip == '192.168.137.1') continue;
      if (ip == '192.168.137.255') continue;
      if (ip == '255.255.255.255') continue;
      if (ip.startsWith('224.') || ip.startsWith('239.')) continue;
      if (ip.startsWith('10.')) continue;

      // Validate last octet range 2..254
      final parts = ip.split('.');
      if (parts.length != 4) continue;
      final last = int.tryParse(parts[3]) ?? -1;
      if (last < 2 || last > 254) continue;

      // Only include entries that are not incomplete (type may be "dynamic" or "static")
      if (type.isEmpty) continue;

      results.add({
        'ip': ip,
        'mac': mac,
        'status': 'reachable',
      });
    }
  } catch (e) {
    // If arp fails, return empty list
  }

  return results;
}

/// Display device dashboard in console
Future<void> _printDeviceDashboard(ServerState state) async {
  print('');
  print('╔═══════════════════════════════════════════════════════════╗');
  print('║  📊 CONNECTED DEVICES DASHBOARD                          ║');
  print('╚═══════════════════════════════════════════════════════════╝');
  
  final devices = await _getConnectedDevices(state);
  
  if (devices.isEmpty) {
    print('  No devices connected yet');
  } else {
    print('  Total Devices: ${devices.length} | Logged In: ${state.totalLoggedInUsers}');
    print('');
    print('  ┌────────────────────────────────────────────────────────┐');
    for (var i = 0; i < devices.length; i++) {
      final device = devices[i];
      final icon = device['type'] == 'connected' ? '🔗' : '📡';
      final status = device['status'] ?? 'unknown';
      final statusIcon = status == 'logged_in' ? '✓' : status == 'connecting' ? '⏳' : '?';
      
      print('  │ $icon [$statusIcon] ${device['ip']}');
      print('  │    User: ${device['userId']}');
      print('  │    Device: ${device['name']}');
      if (device['role'] != 'N/A') {
        print('  │    Role: ${device['role']}');
      }
      if (device['type'] == 'connected') {
        print('  │    Uptime: ${device['uptime']}');
      }
      if (i < devices.length - 1) {
        print('  │');
      }
    }
    print('  └────────────────────────────────────────────────────────┘');
  }
  
  print('');
}

/// Perform a lightweight ping sweep on the hotspot subnet to populate ARP
Future<void> _populateArpFromPing(ServerState state) async {
  try {
    final interfaces = await NetworkInterface.list();
    String? hotspotIp;
    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        if (addr.type == InternetAddressType.IPv4 &&
            !addr.address.startsWith('127.') &&
            (iface.name.toLowerCase().contains('wlan') ||
                iface.name.toLowerCase().contains('wifi') ||
                iface.name.toLowerCase().contains('hotspot') ||
                iface.name.toLowerCase().contains('host'))) {
          hotspotIp = addr.address;
          break;
        }
      }
      if (hotspotIp != null) break;
    }

    if (hotspotIp == null) return;

    final parts = hotspotIp.split('.');
    if (parts.length < 4) return;
    final prefix = '${parts[0]}.${parts[1]}.${parts[2]}.';

    // Ping a limited range to populate ARP table (1..30)
    final futures = <Future>[];
    for (var i = 2; i <= 30; i++) {
      final ip = '$prefix$i';
      futures.add(Process.run('ping', ['-n', '1', '-w', '150', ip], runInShell: true));
    }
    // Await but don't fail hard on errors
    try {
      await Future.wait(futures);
    } catch (_) {}
  } catch (_) {
    // ignore
  }
}

/// Periodic device monitoring (updates every 15 seconds)
void _startDeviceMonitor(ServerState state) {
  // Run initial scan without blocking the main isolate
  _spawnArpScanAndPrint(state);

  // Periodic scan - run in a spawned isolate to avoid blocking WebSocket handling
  Timer.periodic(const Duration(seconds: 15), (_) {
    _spawnArpScanAndPrint(state);
  });
}

/// Spawn an Isolate to run the ARP scan and send devices back to the main isolate
void _spawnArpScanAndPrint(ServerState state) async {
  final receive = ReceivePort();
  try {
    await Isolate.spawn(_arpScanIsolateEntry, receive.sendPort);
    final msg = await receive.first;
    if (msg is List) {
      final devices = List<Map<String, dynamic>>.from(msg.cast<Map>());
      await _printDeviceDashboardWithDevices(state, devices);
    }
  } catch (e) {
    // Fallback to running on main isolate (safer than crashing)
    await _populateArpFromPing(state);
    await _printDeviceDashboard(state);
  } finally {
    receive.close();
  }
}

/// Entry point for isolate: performs ARP scan and returns the device list
void _arpScanIsolateEntry(SendPort sendPort) async {
  try {
    final devices = await _getConnectedDevices(null);
    sendPort.send(devices);
  } catch (e) {
    sendPort.send(<Map<String, dynamic>>[]);
  }
}

/// Print dashboard given devices (used when devices are already computed)
Future<void> _printDeviceDashboardWithDevices(ServerState state, List<Map<String, dynamic>> devices) async {
  print('');
  print('╔═══════════════════════════════════════════════════════════╗');
  print('║  📊 CONNECTED DEVICES DASHBOARD                          ║');
  print('╚═══════════════════════════════════════════════════════════╝');
  if (devices.isEmpty) {
    print('  No devices connected yet');
  } else {
    print('  Total Devices: ${devices.length} | Logged In: ${state.totalLoggedInUsers}');
    print('');
    print('  ┌────────────────────────────────────────────────────────┐');
    for (var i = 0; i < devices.length; i++) {
      final device = devices[i];
      final icon = device['type'] == 'connected' ? '🔗' : '📡';
      final status = device['status'] ?? 'unknown';
      final statusIcon = status == 'logged_in' ? '✓' : status == 'connecting' ? '⏳' : '?';
      print('  │ $icon [$statusIcon] ${device['ip']}');
      print('  │    MAC: ${device['mac']}');
      if (i < devices.length - 1) {
        print('  │');
      }
    }
    print('  └────────────────────────────────────────────────────────┘');
  }
  print('');
}

/// UDP Discovery Listener
/// Listens on port 8082 for client discovery requests
/// Responds with server address and WebSocket port
Future<void> _startUdpDiscoveryListener(int wsPort) async {
  try {
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 8082);
    print('✓ UDP discovery listener started on port 8082');
    
    // Get server's local IP address once at startup
    String serverIp = '192.168.137.1'; // sensible default for Windows hotspot
    try {
      final interfaces = await NetworkInterface.list();
      // Prefer any IPv4 address in the hotspot range 192.168.137.*
      String? preferred;
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (addr.type != InternetAddressType.IPv4) continue;
          final a = addr.address;
          if (a.startsWith('192.168.137.')) {
            // Prefer .1 if present (typical hotspot gateway)
            if (a.endsWith('.1')) {
              preferred = a;
              break;
            }
            preferred ??= a;
          }
        }
        if (preferred != null && preferred.endsWith('.1')) break;
      }
      if (preferred != null) {
        serverIp = preferred;
        print('  Hotspot IP detected: $serverIp');
      } else {
        // Fallback: choose first non-loopback IPv4
        for (final interface in interfaces) {
          for (final addr in interface.addresses) {
            if (addr.type == InternetAddressType.IPv4 && !addr.address.startsWith('127.')) {
              serverIp = addr.address;
              break;
            }
          }
          if (!serverIp.startsWith('127.')) break;
        }
        print('  Using detected IP: $serverIp');
      }
      print('✓ Server will respond with IP: $serverIp');
    } catch (e) {
      print('⚠️  Could not detect server IP, using fallback: $e');
    }
    
    // Listen for incoming discovery requests
    socket.listen((event) {
      if (event == RawSocketEvent.read) {
        final datagram = socket.receive();
        if (datagram != null) {
          try {
            final message = utf8.decode(datagram.data);
            final data = jsonDecode(message) as Map<String, dynamic>;
            
            // Check if this is a server discovery request
            if (data['type'] == 'server_discovery_request') {
              final clientAddress = datagram.address;
              
              // Send discovery response back to client
              final response = jsonEncode({
                'type': 'server_discovery_response',
                'address': serverIp,
                'port': wsPort,
                'timestamp': DateTime.now().toIso8601String(),
              });
              
              socket.send(
                utf8.encode(response),
                clientAddress,
                datagram.port,
              );
              print('📨 Sent discovery response to ${datagram.address}:${datagram.port}');
            }
          } catch (e) {
            // Ignore malformed messages silently
          }
        }
      }
    });

    // Optional: Broadcast server availability periodically (can be enabled for aggressive discovery)
    // Timer.periodic(Duration(seconds: 10), (_) {
    //   final broadcast = jsonEncode({'type': 'server_heartbeat', 'address': serverIp, 'port': wsPort});
    //   socket.send(utf8.encode(broadcast), InternetAddress('255.255.255.255'), 8082);
    // });
    
  } catch (e) {
    print('❌ Error starting UDP discovery listener: $e');
  }
}

Future<void> main(List<String> args) async {
  final state = ServerState();
  final port = 8083;
  
  // Print startup banner
  print('');
  print('╔═══════════════════════════════════════════════════════════╗');
  print('║           🚀 CampusNet Server Initializing...              ║');
  print('╚═══════════════════════════════════════════════════════════╝');
  print('');
  
  // Enable Mobile Hotspot on startup
  final hotspotEnabled = await _enableMobileHotspot();
  print('');
  
  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  
  print('✓ WebSocket Server initialized');
  print('  Port: $port');
  print('  Address: ws://0.0.0.0:$port/ws');
  print('');

  // Detect and print available network interfaces
  String? hotspotIp;
  try {
    final interfaces = await NetworkInterface.list();
    print('📊 Network Configuration:');
    for (final interface in interfaces) {
      if (interface.addresses.isNotEmpty) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4) {
            bool isHotspot = false;
            if (interface.name.toLowerCase().contains('wlan') || 
                interface.name.toLowerCase().contains('wifi') ||
                interface.name.toLowerCase().contains('hotspot') ||
                interface.name.toLowerCase().contains('local area connection* ')) {
              print('  ✓ ${interface.name}');
              print('    └─ IPv4: ${addr.address}');
              print('    └─ Type: ${hotspotEnabled ? 'Hotspot (CampusNet)' : 'WiFi/Network'}');
              isHotspot = true;
              if (hotspotEnabled) {
                hotspotIp = addr.address;
              }
            } else if (!interface.name.toLowerCase().contains('loopback')) {
              print('  ○ ${interface.name}');
              print('    └─ IPv4: ${addr.address}');
            }
            break;
          }
        }
      }
    }
    print('');
  } catch (e) {
    print('ℹ️  Could not detect network interfaces: $e');
  }

  print('✓ UDP Discovery listener');
  print('  Port: 8082');
  print('  Status: Listening for client discovery requests');
  print('');
  
  // Start UDP discovery listener in background
  _startUdpDiscoveryListener(port);
  
  // Start device monitor (updates every 30 seconds)
  _startDeviceMonitor(state);
  
  print('╔═══════════════════════════════════════════════════════════╗');
  print('║  ✓ CampusNet Server is READY                             ║');
  print('║  Waiting for client connections...                       ║');
  if (hotspotEnabled) {
    print('║  📱 Hotspot: CampusNet is ACTIVE                         ║');
  } else {
    print('║  ⚠️  Hotspot Status: Check admin privileges             ║');
  }
  print('║  Press Ctrl+C to stop                                    ║');
  print('╚═══════════════════════════════════════════════════════════╝');
  print('');

  await for (final request in server) {
    if (request.uri.path == '/ws') {
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        WebSocketTransformer.upgrade(request).then((WebSocket websocket) {
          final clientIp = request.connectionInfo?.remoteAddress.address ?? 'unknown';
          print('🔗 New WebSocket connection from $clientIp');
          state.addClient(websocket, clientIp);
          _handleSocket(state, websocket, clientIp);
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
}

void _handleSocket(ServerState state, WebSocket ws, String clientIp) {
  print('');
  print('┌─ 🔗 NEW CONNECTION ─────────────────────────────');
  print('│  IP Address: $clientIp');
  print('│  Timestamp: ${DateTime.now().toIso8601String()}');
  print('│  Status: Waiting for login...');
  print('│  Total Connected: ${state.totalConnectedDevices + 1}');
  print('└─────────────────────────────────────────────────');
  
  ws.listen((data) {
    try {
      // Handle raw ping/pong text frames
      if (data is String && (data == 'ping' || data == 'pong')) {
        if (data == 'ping') ws.add('pong');
        return;
      }

      final msg = _parseJson(data);
      if (msg == null) return;
      final type = msg['type'];
      switch (type) {
        case 'login':
          _handleLogin(state, ws, msg, clientIp);
          break;
        case 'message':
          _handleMessage(state, ws, msg);
          break;
        case 'announcement':
          _handleAnnouncement(state, ws, msg);
          break;
        case 'who':
          _handleWho(state, ws);
          break;
        case 'typing':
          _handleTyping(state, ws, msg);
          break;
        case 'join':
          _handleJoin(state, ws, msg);
          break;
        case 'leave':
          _handleLeave(state, ws, msg);
          break;
        case 'fileMeta':
          _handleFileMeta(state, ws, msg);
          break;
        case 'fileChunk':
          _handleFileChunk(state, ws, msg);
          break;
        case 'fileComplete':
          _handleFileComplete(state, ws, msg);
          break;
        case 'get_online_users':
          _handleGetOnlineUsers(state, ws);
          break;
        // WebRTC signaling pass-through for LAN calls
        case 'call_invite':
        case 'call_accept':
        case 'call_reject':
        case 'call_end':
        case 'webrtc_offer':
        case 'webrtc_answer':
        case 'webrtc_ice':
          _handleSignal(state, ws, msg);
          break;
        default:
          _send(ws, {
            'type': 'error',
            'error': 'unknown_type',
            'detail': 'Unsupported type: $type',
          });
      }
    } catch (e) {
      _send(ws, {'type': 'error', 'error': 'exception', 'detail': e.toString()});
    }
  }, onDone: () {
    final c = state.clients[ws];
    final userId = c?.userId ?? 'anonymous';
    final displayName = c?.displayName ?? 'Unknown Device';
    final role = c?.role ?? 'N/A';
    
    print('');
    print('┌─ ❌ DEVICE DISCONNECTED ────────────────────────');
    print('│  IP Address: $clientIp');
    print('│  User ID: $userId');
    print('│  Name: $displayName');
    print('│  Role: $role');
    print('│  Timestamp: ${DateTime.now().toIso8601String()}');
    print('│  Remaining Devices: ${state.totalConnectedDevices - 1}');
    print('└─────────────────────────────────────────────────');
    
    state.removeClient(ws);
    
    if (userId != 'anonymous') {
      _broadcast(state, {
        'type': 'presence',
        'event': 'offline',
        'userId': userId,
      });
    }
  }, onError: (err) {
    final c = state.clients[ws];
    final userId = c?.userId ?? 'anonymous';
    final displayName = c?.displayName ?? 'Unknown Device';
    
    print('');
    print('┌─ ⚠️  CONNECTION ERROR ──────────────────────────');
    print('│  IP Address: $clientIp');
    print('│  User ID: $userId');
    print('│  Name: $displayName');
    print('│  Error: $err');
    print('│  Timestamp: ${DateTime.now().toIso8601String()}');
    print('└─────────────────────────────────────────────────');
    
    state.removeClient(ws);
    
    if (userId != 'anonymous') {
      _broadcast(state, {
        'type': 'presence',
        'event': 'offline',
        'userId': userId,
      });
    }
  });
}

Map<String, dynamic>? _parseJson(dynamic data) {
  if (data is String) {
    return jsonDecode(data) as Map<String, dynamic>;
  } else if (data is List<int>) {
    return jsonDecode(utf8.decode(data)) as Map<String, dynamic>;
  }
  return null;
}

void _send(WebSocket ws, Map<String, dynamic> json) {
  ws.add(jsonEncode(json));
}

void _broadcast(ServerState state, Map<String, dynamic> json) {
  final encoded = jsonEncode(json);
  for (final c in state.clients.values) {
    c.socket.add(encoded);
  }
}

void _handleLogin(ServerState state, WebSocket ws, Map<String, dynamic> msg, String clientIp) {
  final userId = (msg['userId'] ?? '').toString().trim();
  final displayName = (msg['displayName'] ?? userId).toString().trim();
  final role = (msg['role'] ?? 'Student').toString().trim();
  
  if (userId.isEmpty) {
    _send(ws, {'type': 'loginAck', 'ok': false, 'reason': 'missing_userId'});
    print('⚠️  Login failed: Missing user ID from $clientIp');
    return;
  }
  
  final client = state.clients[ws]!;
  client.userId = userId;
  client.displayName = displayName;
  client.role = role;
  state.userSocket[userId] = ws;

  print('');
  print('┌─ ✓ LOGIN SUCCESSFUL ───────────────────────────');
  print('│  User ID: $userId');
  print('│  Name: $displayName');
  print('│  Role: $role');
  print('│  IP Address: $clientIp');
  print('│  Connected At: ${DateTime.now().toIso8601String()}');
  print('│  Total Users Online: ${state.totalLoggedInUsers}');
  print('│  Total Connected: ${state.totalConnectedDevices}');
  print('└─────────────────────────────────────────────────');

  _send(ws, {
    'type': 'loginAck',
    'ok': true,
    'userId': userId,
    'displayName': displayName,
    'role': role,
  });

  // Inform others
  _broadcast(state, {
    'type': 'presence',
    'event': 'online',
    'userId': userId,
    'displayName': displayName,
    'role': role,
  });
}

void _handleMessage(ServerState state, WebSocket ws, Map<String, dynamic> msg) {
  final fromClient = state.clients[ws];
  if (fromClient == null || fromClient.userId == null) {
    _send(ws, {'type': 'error', 'error': 'not_logged_in'});
    return;
  }
  final from = fromClient.userId!;
  final to = (msg['to'] ?? '').toString();
  final text = (msg['text'] ?? '').toString();
  if (to.isEmpty || text.isEmpty) {
    _send(ws, {'type': 'error', 'error': 'invalid_message'});
    return;
  }
  final payload = {
    'type': 'message',
    'from': from,
    'to': to,
    'text': text,
    'ts': DateTime.now().toIso8601String(),
  };
  if (to.startsWith('room:')) {
    final roomId = to.substring('room:'.length);
    final room = state.rooms.putIfAbsent(roomId, () => Room(roomId));
    room.members.add(from); // auto-join sender
    for (final member in room.members) {
      final s = state.userSocket[member];
      if (s != null) s.add(jsonEncode(payload));
    }
  } else {
    final target = state.userSocket[to];
    if (target != null) {
      target.add(jsonEncode(payload));
    }
    // echo back to sender for confirmation/UI
    _send(ws, payload);
  }
}

void _handleTyping(ServerState state, WebSocket ws, Map<String, dynamic> msg) {
  final fromClient = state.clients[ws];
  if (fromClient == null || fromClient.userId == null) {
    _send(ws, {'type': 'error', 'error': 'not_logged_in'});
    return;
  }
  final from = fromClient.userId!;
  final to = (msg['to'] ?? '').toString();
  final isTyping = msg['isTyping'] == true;
  if (to.isEmpty) {
    _send(ws, {'type': 'error', 'error': 'invalid_typing'});
    return;
  }
  final payload = {
    'type': 'typing',
    'from': from,
    'to': to,
    'isTyping': isTyping,
    'ts': DateTime.now().toIso8601String(),
  };
  _routeTo(state, to, payload);
}

void _handleJoin(ServerState state, WebSocket ws, Map<String, dynamic> msg) {
  final fromClient = state.clients[ws];
  if (fromClient == null || fromClient.userId == null) {
    _send(ws, {'type': 'error', 'error': 'not_logged_in'});
    return;
  }
  final roomId = (msg['roomId'] ?? '').toString();
  if (roomId.isEmpty) {
    _send(ws, {'type': 'error', 'error': 'invalid_room'});
    return;
  }
  final room = state.rooms.putIfAbsent(roomId, () => Room(roomId));
  room.members.add(fromClient.userId!);
  _send(ws, {'type': 'joinAck', 'ok': true, 'roomId': roomId});
}

void _handleLeave(ServerState state, WebSocket ws, Map<String, dynamic> msg) {
  final fromClient = state.clients[ws];
  if (fromClient == null || fromClient.userId == null) {
    _send(ws, {'type': 'error', 'error': 'not_logged_in'});
    return;
  }
  final roomId = (msg['roomId'] ?? '').toString();
  if (roomId.isEmpty) {
    _send(ws, {'type': 'error', 'error': 'invalid_room'});
    return;
  }
  final room = state.rooms[roomId];
  room?.members.remove(fromClient.userId!);
  _send(ws, {'type': 'leaveAck', 'ok': true, 'roomId': roomId});
}

void _handleAnnouncement(ServerState state, WebSocket ws, Map<String, dynamic> msg) {
  final fromClient = state.clients[ws];
  if (fromClient == null || fromClient.userId == null) {
    _send(ws, {'type': 'error', 'error': 'not_logged_in'});
    return;
  }
  final text = (msg['text'] ?? '').toString();
  if (text.isEmpty) {
    _send(ws, {'type': 'error', 'error': 'invalid_announcement'});
    return;
  }
  _broadcast(state, {
    'type': 'announcement',
    'from': fromClient.userId,
    'text': text,
    'ts': DateTime.now().toIso8601String(),
  });
}

void _handleWho(ServerState state, WebSocket ws) {
  final fromClient = state.clients[ws];
  if (fromClient == null || fromClient.userId == null) {
    _send(ws, {'type': 'error', 'error': 'not_logged_in'});
    return;
  }
  
  final onlineUsers = <Map<String, dynamic>>[];
  for (final client in state.clients.values) {
    if (client.userId != null) {
      onlineUsers.add({
        'userId': client.userId,
        'displayName': client.displayName ?? client.userId,
      });
    }
  }
  
  _send(ws, {
    'type': 'who',
    'users': onlineUsers,
  });
}

void _handleGetOnlineUsers(ServerState state, WebSocket ws) {
  final fromClient = state.clients[ws];
  if (fromClient == null || fromClient.userId == null) {
    _send(ws, {'type': 'error', 'error': 'not_logged_in'});
    return;
  }

  final onlineUsers = <Map<String, dynamic>>[];
  for (final client in state.clients.values) {
    if (client.userId != null) {
      onlineUsers.add({
        'userId': client.userId,
        'name': client.displayName ?? client.userId,
        'role': client.role ?? 'student',
        'ip': client.clientIp,
      });
    }
  }

  _send(ws, {
    'type': 'online_users',
    'users': onlineUsers,
  });
  print('📨 Responded to get_online_users (count: ${onlineUsers.length})');
}

void _routeTo(ServerState state, String to, Map<String, dynamic> payload) {
  if (to.startsWith('room:')) {
    final roomId = to.substring('room:'.length);
    final room = state.rooms.putIfAbsent(roomId, () => Room(roomId));
    for (final member in room.members) {
      final s = state.userSocket[member];
      if (s != null) s.add(jsonEncode(payload));
    }
  } else {
    final target = state.userSocket[to];
    if (target != null) {
      target.add(jsonEncode(payload));
    }
  }
}

void _handleFileMeta(ServerState state, WebSocket ws, Map<String, dynamic> msg) {
  final fromClient = state.clients[ws];
  if (fromClient == null || fromClient.userId == null) {
    _send(ws, {'type': 'error', 'error': 'not_logged_in'});
    return;
  }
  final to = (msg['to'] ?? '').toString();
  final fileId = (msg['fileId'] ?? '').toString();
  if (fileId.isEmpty) {
    _send(ws, {'type': 'error', 'error': 'invalid_file_meta'});
    return;
  }
  final payload = {
    'type': 'fileMeta',
    'from': fromClient.userId,
    'to': to,
    'fileId': fileId,
    'name': msg['name'],
    'size': msg['size'],
    'mime': msg['mime'],
    'ts': DateTime.now().toIso8601String(),
  };
  if (to.isEmpty) {
    _broadcast(state, payload);
  } else {
    if (to.startsWith('room:')) {
      final roomId = to.substring('room:'.length);
      final room = state.rooms.putIfAbsent(roomId, () => Room(roomId));
      room.members.add(fromClient.userId!);
    }
    _routeTo(state, to, payload);
    _send(ws, payload);
  }
}

void _handleFileChunk(ServerState state, WebSocket ws, Map<String, dynamic> msg) {
  final fromClient = state.clients[ws];
  if (fromClient == null || fromClient.userId == null) {
    _send(ws, {'type': 'error', 'error': 'not_logged_in'});
    return;
  }
  final to = (msg['to'] ?? '').toString();
  final forward = {
    'type': 'fileChunk',
    'from': fromClient.userId,
    'to': to,
    'fileId': msg['fileId'],
    'seq': msg['seq'],
    'eof': msg['eof'] ?? false,
    'dataBase64': msg['dataBase64'],
    'ts': DateTime.now().toIso8601String(),
  };
  if (to.isEmpty) {
    _broadcast(state, forward);
  } else {
    if (to.startsWith('room:')) {
      final roomId = to.substring('room:'.length);
      final room = state.rooms.putIfAbsent(roomId, () => Room(roomId));
      room.members.add(fromClient.userId!);
    }
    _routeTo(state, to, forward);
    _send(ws, forward);
  }
}
