import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Simple LAN-only WebSocket server for CampusNet.
/// Listens on ws://<LAN-IP>:8083/ws
/// Protocol: JSON messages with a `type` field.
/// - login: {type:"login", userId:"C123", displayName:"Alice"}
/// - message: {type:"message", to:"<userId|room:roomId>", text:"Hello"}
/// - announcement: {type:"announcement", text:"..."}
/// - fileChunk: {type:"fileChunk", fileId:"...", seq:0, eof:false, dataBase64:"..."}

class Client {
  final WebSocket socket;
  String? userId;
  String? displayName;

  Client(this.socket);
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

  void addClient(WebSocket ws) {
    clients[ws] = Client(ws);
  }

  void removeClient(WebSocket ws) {
    final c = clients.remove(ws);
    if (c != null && c.userId != null) {
      userSocket.remove(c.userId);
      for (final room in rooms.values) {
        room.members.remove(c.userId);
      }
    }
  }
}

Future<void> main(List<String> args) async {
  final state = ServerState();
  final port = 8083;
  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  print('CampusNet server listening on ws://0.0.0.0:$port/ws');

  await for (final request in server) {
    if (request.uri.path == '/ws') {
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        WebSocketTransformer.upgrade(request).then((WebSocket websocket) {
          state.addClient(websocket);
          _handleSocket(state, websocket);
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

void _handleSocket(ServerState state, WebSocket ws) {
  ws.listen((data) {
    try {
      final msg = _parseJson(data);
      if (msg == null) return;
      final type = msg['type'];
      switch (type) {
        case 'login':
          _handleLogin(state, ws, msg);
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
        case 'fileMeta':
          _handleFileMeta(state, ws, msg);
          break;
        case 'fileChunk':
          _handleFileChunk(state, ws, msg);
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
    final userId = c?.userId;
    state.removeClient(ws);
    if (userId != null) {
      _broadcast(state, {
        'type': 'presence',
        'event': 'offline',
        'userId': userId,
      });
    }
  }, onError: (err) {
    final c = state.clients[ws];
    final userId = c?.userId;
    state.removeClient(ws);
    if (userId != null) {
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

void _handleLogin(ServerState state, WebSocket ws, Map<String, dynamic> msg) {
  final userId = (msg['userId'] ?? '').toString().trim();
  final displayName = (msg['displayName'] ?? userId).toString().trim();
  if (userId.isEmpty) {
    _send(ws, {'type': 'loginAck', 'ok': false, 'reason': 'missing_userId'});
    return;
  }
  final client = state.clients[ws]!;
  client.userId = userId;
  client.displayName = displayName;
  state.userSocket[userId] = ws;

  _send(ws, {
    'type': 'loginAck',
    'ok': true,
    'userId': userId,
    'displayName': displayName,
  });

  // Inform others
  _broadcast(state, {
    'type': 'presence',
    'event': 'online',
    'userId': userId,
    'displayName': displayName,
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
