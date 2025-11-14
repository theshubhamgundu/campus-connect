# CampusNet Server

A simple LAN-only WebSocket server for CampusNet communication with automatic WiFi hotspot.

## Quick Start

### Option 1: Using the Batch File (Recommended)
1. Double-click `start_server.bat`
2. Click "Yes" when prompted for admin privileges
3. The server will automatically:
   - Enable Mobile Hotspot (SSID: **CampusNet**, Password: **CampusNet2025**)
   - Start listening on `ws://0.0.0.0:8083/ws`
   - Broadcast discovery on UDP port 8082

### Option 2: Command Line
```bash
cd server
dart run bin/server.dart
```

## Mobile Client Setup

1. **On your mobile phone**:
   - Go to WiFi settings
   - Look for and connect to **"CampusNet"** network
   - Password: **CampusNet2025**

2. **Launch the CampusNet app**:
   - The app will auto-discover the server via UDP broadcast
   - Connection will be automatic once connected to the WiFi
   - Sign up or log in with your Student ID / Faculty ID

## Server Features

- **Auto Hotspot**: Automatically enables Windows Mobile Hotspot on startup
- **WebSocket Communication**: Real-time messaging via WebSocket (port 8083)
- **UDP Discovery**: Auto-discovery broadcast on port 8082
- **User Management**: Login/logout with Student ID / Faculty ID
- **Messaging**: Direct messages and group chats
- **File Transfer**: File sharing with chunked transfer
- **Video/Audio Calls**: WebRTC signaling support
- **Presence**: Online/offline status tracking

## Network Configuration

| Feature | Configuration |
|---------|---------------|
| **WebSocket Port** | 8083 |
| **UDP Discovery** | 8082 |
| **Protocol** | ws:// (WebSocket) |
| **Hotspot SSID** | CampusNet |
| **Hotspot Password** | CampusNet2025 |
| **Network Type** | LAN only |

## Installation

1. Copy `campusnet_server.exe` to your desired location
2. Run the executable to start the server

## Usage

### Starting the Server
```bash
campusnet_server.exe
```

The server will start and listen on `ws://0.0.0.0:8083/ws`

### Server Features

- **WebSocket Communication**: Real-time messaging via WebSocket
- **User Management**: Login/logout with user IDs and display names
- **Messaging**: Direct messages and room-based group messaging
- **File Transfer**: Support for file sharing with chunked transfer
- **Announcements**: Broadcast messages to all connected users
- **Presence**: Online/offline status tracking

### Protocol

The server uses JSON messages with a `type` field:

#### Login
```json
{
  "type": "login",
  "userId": "C123",
  "displayName": "Alice"
}
```

#### Send Message
```json
{
  "type": "message",
  "to": "C456",
  "text": "Hello!"
}
```

#### Room Message
```json
{
  "type": "message",
  "to": "room:general",
  "text": "Hello everyone!"
}
```

#### File Transfer
```json
{
  "type": "fileMeta",
  "to": "C456",
  "fileId": "file123",
  "name": "document.pdf",
  "size": 1024,
  "mime": "application/pdf"
}
```

#### File Chunk
```json
{
  "type": "fileChunk",
  "to": "C456",
  "fileId": "file123",
  "seq": 0,
  "eof": false,
  "dataBase64": "base64encodeddata..."
}
```

#### Announcement
```json
{
  "type": "announcement",
  "text": "Server maintenance in 5 minutes"
}
```

#### Who's Online
```json
{
  "type": "who"
}
```

### Network Configuration

- **Port**: 8083
- **Protocol**: WebSocket (ws://)
- **Endpoint**: `/ws`
- **Network**: LAN only (binds to 0.0.0.0)

### Firewall

Make sure to allow the server through Windows Firewall:
1. Open Windows Defender Firewall
2. Click "Allow an app or feature through Windows Defender Firewall"
3. Add `campusnet_server.exe` and allow it for both private and public networks

### Troubleshooting

- **Port already in use**: Make sure no other application is using port 8083
- **Connection refused**: Check firewall settings
- **Server not starting**: Run as administrator if needed

## Development

To rebuild the server from source:
```bash
cd server
dart pub get
dart compile exe bin/server.dart -o campusnet_server.exe
```

## License

This is a simple LAN communication server for educational purposes.
