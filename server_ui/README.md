# CampusNet Server UI

A modern, web-based server management interface for CampusNet with real-time monitoring and control capabilities.

## Features

### 🎨 Modern Web Interface
- **Responsive Design**: Works on desktop, tablet, and mobile devices
- **Real-time Updates**: Live server status and client monitoring
- **Beautiful UI**: Modern gradient design with glassmorphism effects
- **Dark Theme**: Easy on the eyes with terminal-style logs

### 📊 Server Monitoring
- **Real-time Status**: Server running/stopped status with visual indicators
- **Connection Statistics**: Total connections, active clients, messages sent
- **Uptime Tracking**: Server uptime with precise time display
- **Live Logs**: Real-time server logs with color-coded message types

### 👥 Client Management
- **Connected Clients**: Live list of connected clients with IP addresses
- **Connection Duration**: How long each client has been connected
- **Client Details**: IP address, connection time, and status

### 🔧 Server Controls
- **Start/Stop Server**: Easy server control with visual feedback
- **Port Configuration**: Configurable server port (default: 8083)
- **WebSocket URL**: Display of server WebSocket endpoint

## Installation

### Prerequisites
- **Node.js** (version 14 or higher)
- **npm** (comes with Node.js)

### Quick Start

1. **Download the server files** to your desired location

2. **Run the installer**:
   ```bash
   # Double-click start_server_ui.bat
   # OR run manually:
   npm install
   npm start
   ```

3. **Access the web interface**:
   - Open your browser
   - Navigate to `http://localhost:3000`
   - The server will be running on `ws://localhost:3000/ws`

## Usage

### Starting the Server
1. Run `start_server_ui.bat` or `npm start`
2. Open your browser to `http://localhost:3000`
3. Click "Start Server" to begin accepting connections
4. The WebSocket endpoint will be available at `ws://localhost:3000/ws`

### Web Interface Features

#### Server Controls
- **Port Configuration**: Change the server port before starting
- **Start/Stop Buttons**: Control server state with visual feedback
- **Status Indicator**: Real-time server status with color coding

#### Statistics Dashboard
- **Connected Clients**: Number of currently connected clients
- **Total Connections**: Total number of connections since server start
- **Messages Sent**: Total messages processed by the server
- **Uptime**: How long the server has been running

#### Client Management
- **Live Client List**: See all connected clients in real-time
- **Connection Details**: IP address and connection duration
- **Client Status**: Visual indicators for client health

#### Server Logs
- **Real-time Logging**: Live server activity logs
- **Color-coded Messages**: Different colors for info, error, warning, and success
- **Timestamp**: Precise timing for each log entry
- **Auto-scroll**: Latest logs appear at the top

## WebSocket Protocol

The server implements the CampusNet WebSocket protocol:

### Message Types

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

## Configuration

### Environment Variables
- `PORT`: Server port (default: 3000)
- `NODE_ENV`: Environment mode (development/production)

### Server Settings
- **Default Port**: 3000 (web interface) / 8083 (WebSocket)
- **Max Connections**: No limit (configurable)
- **Log Retention**: Last 100 log entries
- **Client Timeout**: No automatic timeout

## Troubleshooting

### Common Issues

#### "Node.js is not installed"
- Download and install Node.js from https://nodejs.org/
- Make sure Node.js is added to your system PATH

#### "Port already in use"
- Change the port in the web interface
- Or stop other services using the same port

#### "Cannot connect to server"
- Check firewall settings
- Ensure the port is not blocked
- Verify the server is running

#### "WebSocket connection failed"
- Check if the server is running
- Verify the WebSocket URL is correct
- Check browser console for errors

### Firewall Configuration
1. Open Windows Defender Firewall
2. Click "Allow an app or feature through Windows Defender Firewall"
3. Add Node.js and allow it for both private and public networks
4. Allow the specific port (3000) if needed

## Development

### Running in Development Mode
```bash
npm run dev
```

### Project Structure
```
server_ui/
├── web/
│   ├── index.html          # Main web interface
│   └── assets/
│       └── images/
│           └── app_icon.png
├── server.js              # Node.js server
├── package.json           # Dependencies
├── start_server_ui.bat    # Windows startup script
└── README.md             # This file
```

### Customization
- **UI Colors**: Modify CSS variables in `index.html`
- **Server Logic**: Edit `server.js` for custom behavior
- **Port Configuration**: Change default port in `server.js`

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For issues and questions:
1. Check the troubleshooting section
2. Review the server logs in the web interface
3. Check the browser console for errors
4. Ensure all prerequisites are installed

---

**CampusNet Server UI** - Modern server management for CampusNet communication platform.